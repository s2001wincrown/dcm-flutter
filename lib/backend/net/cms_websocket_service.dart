import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/content_sync_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/proto/websocket_def.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum CmsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

typedef CmsMessageHandler = void Function(
  MessageWrapper message,
  GeneratedMessage? payload,
);

class CmsWebSocketService {
  CmsWebSocketService({
    WebSocketChannel Function(Uri uri)? channelFactory,
    Map<CommandType, CmsMessageHandler> handlers = const {},
    this.initialReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectAttempts,
    this.reconnectJitter = const Duration(seconds: 1),
  })  : _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _handlers = Map.unmodifiable(handlers);

  static const heartbeatInterval = Duration(seconds: 30);
  static const heartbeatResponseTimeout = Duration(seconds: 90);
  static const maxReconnectDelay = Duration(seconds: 60);

  final WebSocketChannel Function(Uri uri) _channelFactory;
  final Map<CommandType, CmsMessageHandler> _handlers;
  final Duration initialReconnectDelay;
  final int? maxReconnectAttempts;
  final Duration reconnectJitter;
  final _messages = StreamController<MessageWrapper>.broadcast();
  final _connectionStates = StreamController<CmsConnectionState>.broadcast();
  final _random = Random();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _reconnectTimer;
  Future<void>? _connectFuture;
  DateTime? _lastHeartbeatAt;
  int _reconnectAttempt = 0;
  int _generation = 0;
  bool _stopped = true;
  bool _disposed = false;
  bool _syncActionScheduled = false;
  bool _syncActionRequested = false;
  CmsConnectionState _state = CmsConnectionState.disconnected;

  Stream<MessageWrapper> get messages => _messages.stream;
  Stream<CmsConnectionState> get connectionStates => _connectionStates.stream;
  CmsConnectionState get connectionState => _state;

  Future<void> connect() async {
    if (_disposed) {
      return;
    }
    _stopped = false;
    if (_channel != null || _connectFuture != null) {
      return _connectFuture ?? Future<void>.value();
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _publishState(CmsConnectionState.connecting);
    final future = _connect();
    _connectFuture = future;
    try {
      await future;
    } finally {
      if (identical(_connectFuture, future)) {
        _connectFuture = null;
      }
    }
  }

  Future<void> _connect() async {
    final uri = _buildUri();
    final generation = ++_generation;
    WebSocketChannel? channel;
    try {
      logD('CMS WebSocket connecting: ${_displayUri(uri)}', syncTag);
      channel = _channelFactory(uri);
      _channel = channel;
      await channel.ready;
      if (_disposed || _stopped || generation != _generation) {
        await channel.sink.close();
        return;
      }

      _lastHeartbeatAt = DateTime.now();
      _reconnectAttempt = 0;
      _publishState(CmsConnectionState.connected);
      _subscription = channel.stream.listen(
        (event) => _handleEvent(event, generation),
        onError: (Object error, StackTrace stackTrace) {
          logW('CMS WebSocket error: ${error.runtimeType}', syncTag);
          unawaited(_handleDisconnect(generation));
        },
        onDone: () => unawaited(_handleDisconnect(generation)),
        cancelOnError: false,
      );
      _startHeartbeat(generation);
      logI('CMS WebSocket connected: ${uri.host}${uri.path}', syncTag);
    } catch (error, stackTrace) {
      if (generation == _generation) {
        _channel = null;
        try {
          await channel?.sink.close();
        } catch (_) {}
        logW('CMS WebSocket connection failed: ${_describeError(error)}',
            syncTag);
        logD('CMS WebSocket connection stack: $stackTrace', syncTag);
        _publishState(CmsConnectionState.failed);
        if (!_stopped && !_disposed) {
          _scheduleReconnect();
        }
      }
    }
  }

  void send(MessageWrapper message) {
    final channel = _channel;
    if (channel == null || _stopped || _disposed) {
      throw StateError('CMS WebSocket is not connected');
    }
    channel.sink.add(Uint8List.fromList(message.writeToBuffer()));
  }

  void sendHeartbeat(String playerId, String status) {
    final heartbeat = Heartbeat()
      ..playerId = playerId
      ..status = status;
    send(
      MessageWrapper(
        command: CommandType.CMD_HEARTBEAT,
        protocolId: ProtocolId.PROTOCOL_QC,
        payload: heartbeat.writeToBuffer(),
        timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  void sendCommand(CommandType command, GeneratedMessage payload) {
    send(
      MessageWrapper(
        command: command,
        protocolId: ProtocolId.PROTOCOL_QC,
        payload: payload.writeToBuffer(),
        timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  void _handleEvent(Object? event, int generation) {
    if (generation != _generation) {
      return;
    }
    try {
      if (event is! List<int> || event.isEmpty) {
        throw const FormatException(
            'CMS WebSocket frame must be non-empty binary data');
      }
      final message = MessageWrapper.fromBuffer(event);
      _dispatch(message);
    } catch (error) {
      logW('Invalid CMS WebSocket message: $error', syncTag);
    }
  }

  void _dispatch(MessageWrapper message) {
    switch (message.command) {
      case CommandType.CMD_HEARTBEAT:
        _notify(message, Heartbeat.fromBuffer(message.payload));
        _lastHeartbeatAt = DateTime.now();
        break;
      case CommandType.CMD_DCM_CONTENT:
        final content = DcmContent.fromBuffer(message.payload);
        _enqueueDcmContent(content);
        _notify(message, content);
        break;
      case CommandType.CMD_AH_SENDER:
        _notify(message, AhSender.fromBuffer(message.payload));
        break;
      case CommandType.CMD_AH_MESSAGE:
        _notify(message, MessageInfo.fromBuffer(message.payload));
        break;
      case CommandType.CMD_EVENT_MESSAGE:
        _notify(message, DcmEventInfo.fromBuffer(message.payload));
        break;
      case CommandType.CMD_PLAYER_STATUS:
        _notify(message, PlayerStatus.fromBuffer(message.payload));
        break;
      case CommandType.CMD_TRANSFER_STATUS:
        _notify(message, TransferStatus.fromBuffer(message.payload));
        break;
      case CommandType.CMD_REQUEST_SYNC_TIME:
      case CommandType.CMD_REGISTER_UPDATE:
      case CommandType.CMD_REQUEST_DCM_CONTENT:
      case CommandType.CMD_REGISTER:
      case CommandType.CMD_RESET_TASKS:
      case CommandType.CMD_RESET_SETTINGS:
      case CommandType.CMD_RESET_TRANSFER:
      case CommandType.CMD_WEATHER:
      case CommandType.CMD_CONTENT_LIST:
      case CommandType.CMD_MONITOR:
      case CommandType.CMD_RESET_DCM_PLAYER:
      case CommandType.CMD_RESET_HOST:
      case CommandType.CMD_SMS_CONTROL:
      case CommandType.CMD_SHUTDOWN:
      case CommandType.CMD_UNIQUE_NAME:
      case CommandType.CMD_CONNECTION:
      case CommandType.CMD_LIGHT_BOX:
      case CommandType.CMD_REFRESH:
      case CommandType.CMD_DISK_CLEAN:
        logD('CMS WebSocket command: ${message.command}', syncTag);
        _notify(message, null);
        break;
      case CommandType.CMD_UNKNOWN:
        logW('Ignoring unknown CMS WebSocket command', syncTag);
        return;
    }
    if (!_messages.isClosed) {
      _messages.add(message);
    }
  }

  void _enqueueDcmContent(DcmContent content) {
    if (content.task.isEmpty) {
      logW('Ignoring CMS DCM content without task id', syncTag);
      return;
    }
    final task = PlayerJobItem()
      ..strJobItem = content.task
      ..strFtpTime = content.ftpTime
      ..strTimeOuts = content.timeout
      ..strStartFtpTime = content.startFtpTime
      ..strOtherInfo = jsonEncode({
        'filePath': content.filePath,
        'pid': content.pid,
        'includeToday': content.includeToday,
      })
      ..dwSyncContent = content.ftpContent
      ..nSyncPeriod = content.period
      ..nRetries = content.retries
      ..dwJobType = content.immediate ? JobItemType.eMANUAL : JobItemType.eAUTO
      ..bReplaceFile = content.allContent;
    if (content.validity.isNotEmpty) {
      task.dtValidity = DateTime.tryParse(content.validity);
    }
    if (PlayerTaskFile.updateTask(task)) {
      unawaited(PlayerTaskFile.writeTaskFile());
      _requestContentSync();
    }
  }

  void _requestContentSync() {
    _syncActionRequested = true;
    if (_syncActionScheduled || _disposed) {
      return;
    }
    _syncActionScheduled = true;
    Timer.run(() async {
      try {
        do {
          _syncActionRequested = false;
          await ContentSyncService().startSyncAction();
        } while (_syncActionRequested && !_disposed);
      } catch (error, stackTrace) {
        logW('CMS content sync start failed: $error', syncTag);
        logD('CMS content sync start stack: $stackTrace', syncTag);
      } finally {
        _syncActionScheduled = false;
      }
    });
  }

  void _notify(MessageWrapper message, GeneratedMessage? payload) {
    final handler = _handlers[message.command];
    if (handler != null) {
      try {
        handler(message, payload);
      } catch (error, stackTrace) {
        logW('CMS WebSocket command handler failed: $error', syncTag);
        logD('CMS WebSocket handler stack: $stackTrace', syncTag);
      }
    }
  }

  void _startHeartbeat(int generation) {
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _lastHeartbeatAt = DateTime.now();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (generation != _generation || _stopped || _disposed) {
        return;
      }
      try {
        sendHeartbeat(globalPlayer.strUniqueName, 'online');
      } catch (_) {
        unawaited(_handleDisconnect(generation));
      }
    });
    _heartbeatTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (generation != _generation || _stopped || _disposed) {
        return;
      }
      final lastHeartbeatAt = _lastHeartbeatAt;
      if (lastHeartbeatAt != null &&
          DateTime.now().difference(lastHeartbeatAt) >=
              heartbeatResponseTimeout) {
        unawaited(_handleDisconnect(generation));
      }
    });
  }

  Future<void> _handleDisconnect(int generation) async {
    if (generation != _generation) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
    _publishState(CmsConnectionState.disconnected);
    if (!_stopped && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_stopped || _disposed || _reconnectTimer != null || _channel != null) {
      return;
    }
    final maxAttempts = maxReconnectAttempts;
    if (maxAttempts != null && _reconnectAttempt >= maxAttempts) {
      _publishState(CmsConnectionState.failed);
      _stopped = true;
      return;
    }
    final exponentialDelay = initialReconnectDelay.inMilliseconds *
        (1 << min(_reconnectAttempt, 30));
    final delayMilliseconds = min(
      exponentialDelay,
      maxReconnectDelay.inMilliseconds,
    );
    _reconnectAttempt++;
    final jitter = reconnectJitter.inMilliseconds == 0
        ? 0
        : _random.nextInt(reconnectJitter.inMilliseconds + 1);
    _reconnectTimer = Timer(
      Duration(milliseconds: delayMilliseconds + jitter),
      () {
        _reconnectTimer = null;
        _publishState(CmsConnectionState.reconnecting);
        unawaited(connect());
      },
    );
  }

  Future<void> disconnect({bool reconnect = false}) async {
    _stopped = !reconnect;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _generation++;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
    _publishState(CmsConnectionState.disconnected);
    if (reconnect && !_disposed) {
      _scheduleReconnect();
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect();
    await _messages.close();
    await _connectionStates.close();
  }

  void _publishState(CmsConnectionState state) {
    _state = state;
    if (!_connectionStates.isClosed) {
      _connectionStates.add(state);
    }
  }

  Uri _buildUri() {
    if (AppGlobal.cmsUrl.isEmpty) {
      throw StateError('AppGlobal.cmsUrl is empty');
    }
    if (AppGlobal.cmsToken.isEmpty) {
      throw StateError('AppGlobal.cmsToken is empty');
    }
    final baseUri = Uri.parse(AppGlobal.cmsUrl);
    final scheme = switch (baseUri.scheme.toLowerCase()) {
      'http' => 'ws',
      'https' => 'wss',
      'ws' || 'wss' => baseUri.scheme.toLowerCase(),
      _ => throw StateError('Unsupported CMS URL scheme: ${baseUri.scheme}'),
    };
    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final query = <String, String>{
      ...baseUri.queryParameters,
      'uniqueName': globalPlayer.strUniqueName,
      'token': AppGlobal.cmsToken,
    };
    final uri = Uri(
      scheme: scheme,
      userInfo: baseUri.userInfo,
      host: baseUri.host,
      port: baseUri.port,
      path: '$basePath/ws',
      queryParameters: query,
    );
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      throw StateError('Invalid WebSocket URI scheme: ${uri.scheme}');
    }
    return uri;
  }

  String _displayUri(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port${uri.path}';
  }

  String _describeError(Object error) {
    final text = error.toString();
    final sanitized = text.replaceAllMapped(
      RegExp(r'([?&]token=)[^&#\s]+'),
      (match) => '${match.group(1)}***',
    );
    return '${error.runtimeType}: $sanitized';
  }
}
