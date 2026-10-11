import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class AppWatchdog {
  static const String _childArg = '--app-watchdog-child';
  static const String _portArg = '--app-watchdog-port=';
  static const String _noWatchdogArg = '--app-watchdog-no';
  static const String _tokenEnvironmentKey = 'DCM_APP_WATCHDOG_TOKEN';
  static const Duration _healthCheckInterval = Duration(seconds: 1);
  static const Duration _frameRequestInterval = Duration(seconds: 5);
  static const int _portBase = 20000;
  static const int _portRange = 40000;

  static ServerSocket? _instanceServer;
  static Socket? _parentSocket;
  static Completer<void>? _userExitAcknowledged;
  static Timer? _frameTimer;
  static bool _timingsCallbackRegistered = false;

  static Future<bool> runParentIfNeeded(List<String> arguments) async {
    if (kDebugMode || !_isWatchdogSupported()) {
      return false;
    }

    if (_hasNoWatchdogFlag(arguments)) {
      return false;
    }

    if (_isWatchdogChild(arguments)) {
      await _connectToParent(arguments);
      return false;
    }

    final server = await _reserveInstanceServer();
    if (server == null) {
      _log('another player instance is already running.');
      return true;
    }
    _instanceServer = server;

    final executable = Platform.resolvedExecutable;
    final token = _newToken();
    _listenForChild(server, token);
    if (!File(executable).existsSync()) {
      _log('executable not found: $executable. Running without a supervisor.');
      return false;
    }

    return _runParent(arguments, server, token, executable);
  }

  static bool _isWatchdogChild(List<String> args) => args.contains(_childArg);

  static bool _hasNoWatchdogFlag(List<String> args) =>
      args.contains(_noWatchdogArg);

  static bool _isWatchdogSupported() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static void _log(String message) {
    try {
      stderr.writeln('AppWatchdog: $message');
    } on FileSystemException catch (error) {
      debugPrint('AppWatchdog: $message (stderr unavailable: $error)');
    }
  }

  static int _portSeed() {
    var hash = 0x811c9dc5;
    final executable = Platform.resolvedExecutable
        .split(RegExp(r'[/\\]'))
        .last
        .toLowerCase()
        .codeUnits;
    for (final byte in executable) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash % _portRange;
  }

  static Future<ServerSocket?> _reserveInstanceServer() async {
    final seed = _portSeed();
    for (var offset = 0; offset < 64; offset++) {
      final port = _portBase + ((seed + offset) % _portRange);
      try {
        return await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: false,
        );
      } on SocketException {
        if (await _isExistingPlayerServer(port)) {
          return null;
        }
      }
    }

    _log('could not reserve a single-instance endpoint.');
    return null;
  }

  static Future<bool> _isExistingPlayerServer(int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 250),
      );
      socket.write('PROBE\n');
      final response = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(milliseconds: 250));
      return response == 'DCM_ACTIVE';
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on FormatException {
      return false;
    } finally {
      await socket?.close();
    }
  }

  static String _newToken() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static void _listenForChild(ServerSocket server, String token) {
    server.listen(
      (socket) => unawaited(_handleConnection(socket, token)),
      onError: (Object error, StackTrace stackTrace) {
        _log('instance listener failed: $error\n$stackTrace');
      },
    );
  }

  static Future<void> _handleConnection(Socket socket, String token) async {
    StreamSubscription<String>? subscription;
    final ready = Completer<void>();
    var authenticated = false;
    try {
      subscription = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line == 'PROBE') {
            authenticated = true;
            socket.write('DCM_ACTIVE\n');
            if (!ready.isCompleted) ready.complete();
            unawaited(socket.close());
            return;
          }
          if (!authenticated) {
            if (line == 'HELLO:$token' || line == 'MONITOR:$token') {
              authenticated = true;
              if (line.startsWith('HELLO:')) {
                _healthSocket = socket;
                socket.write('READY\n');
              }
              if (!ready.isCompleted) ready.complete();
            } else {
              unawaited(socket.close());
            }
            return;
          }
          if (line == 'USER_EXIT') {
            _userRequestedExit = true;
            _userExitRequestedAt = DateTime.now();
            socket.write('USER_EXIT_ACK\n');
          } else if (line == 'USER_EXIT_ACK' &&
              identical(_parentSocket, socket)) {
            final acknowledged = _userExitAcknowledged;
            if (acknowledged != null && !acknowledged.isCompleted) {
              acknowledged.complete();
            }
          } else if (line == 'FRAME' && identical(_healthSocket, socket)) {
            _lastUiFrameAt = DateTime.now();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!ready.isCompleted) ready.completeError(error, stackTrace);
        },
        onDone: () {
          if (identical(_healthSocket, socket)) {
            _healthSocket = null;
            _lastUiFrameAt = null;
          }
        },
      );

      await ready.future.timeout(const Duration(seconds: 5));
    } on Object catch (error, stackTrace) {
      _log('child health connection failed: $error\n$stackTrace');
      await socket.close();
    } finally {
      if (!authenticated) {
        await subscription?.cancel();
      }
    }
  }

  static Socket? _healthSocket;
  static DateTime? _lastUiFrameAt;
  static bool _userRequestedExit = false;
  static DateTime? _userExitRequestedAt;

  static Future<void> _releaseServer(ServerSocket server) async {
    if (identical(_instanceServer, server)) {
      _instanceServer = null;
    }
    await server.close();
  }

  static Future<bool> _runParent(
    List<String> arguments,
    ServerSocket server,
    String token,
    String executable,
  ) async {
    final childArgs = <String>[
      ...Platform.executableArguments,
      if (Platform.script
          .toFilePath(windows: Platform.isWindows)
          .endsWith('.dart'))
        Platform.script.toFilePath(windows: Platform.isWindows),
      ...arguments.where(
        (argument) => argument != _childArg && !argument.startsWith(_portArg),
      ),
      _childArg,
      '$_portArg${server.port}',
    ];
    final childEnvironment = Map<String, String>.from(Platform.environment)
      ..[_tokenEnvironmentKey] = token;
    final restartPolicy = AppWatchdogRestartPolicy();

    while (true) {
      final startedAt = DateTime.now();
      _lastUiFrameAt = null;
      _userRequestedExit = false;
      _userExitRequestedAt = null;
      late final Process child;
      try {
        child = await Process.start(
          executable,
          childArgs,
          environment: childEnvironment,
          mode: ProcessStartMode.inheritStdio,
        );
      } on ProcessException catch (error, stackTrace) {
        _log('failed to start child process: $error\n$stackTrace');
        _log(
            'running without a supervisor; single-instance lock remains active.');
        return false;
      }

      final childExit = Completer<int>();
      child.exitCode.then(childExit.complete, onError: childExit.completeError);
      var unhealthyExit = false;
      while (true) {
        final result = await Future.any<Object>([
          childExit.future.then<Object>(_ChildExited.new),
          Future<void>.delayed(_healthCheckInterval)
              .then<Object>((_) => const _HealthCheckTick()),
        ]);

        if (result is _ChildExited) {
          if (!unhealthyExit &&
              AppWatchdogHealthPolicy.shouldRestartAfterExit(
                result.exitCode,
                userRequestedExit: _userRequestedExit,
              )) {
            break;
          } else {
            _log('child exited normally with code ${result.exitCode}.');
            await _releaseServer(server);
            return true;
          }
        }

        if (_userRequestedExit) {
          final requestedAt = _userExitRequestedAt ?? DateTime.now();
          if (DateTime.now().difference(requestedAt) >=
              const Duration(seconds: 10)) {
            _log('user requested exit; terminating the child.');
            await _terminateChild(child, childExit);
            break;
          }
          continue;
        }

        final now = DateTime.now();
        final lastFrameAt = _lastUiFrameAt;
        final isUnresponsive = AppWatchdogHealthPolicy.isUiUnresponsive(
          now: now,
          childStartedAt: startedAt,
          lastUiFrameAt: lastFrameAt,
        );
        if (!isUnresponsive) {
          continue;
        }

        unhealthyExit = true;
        _log('UI heartbeat timed out. Terminating child ${child.pid}.');
        await _terminateChild(child, childExit);
        break;
      }

      if (_userRequestedExit) {
        _log('child exit was requested by the user; not restarting.');
        await _releaseServer(server);
        return true;
      }

      if (unhealthyExit) {
        await childExit.future;
      }

      final delay = restartPolicy.recordFailure(
        DateTime.now().difference(startedAt),
      );
      _log('restarting child in ${delay.inSeconds}s.');
      await Future<void>.delayed(delay);
    }
  }

  static Future<void> _terminateChild(
    Process child,
    Completer<int> childExit,
  ) async {
    child.kill();
    final stopped = await Future.any<bool>([
      childExit.future.then((_) => true),
      Future<void>.delayed(const Duration(seconds: 5)).then((_) => false),
    ]);
    if (!stopped) {
      _log('child did not stop after termination request; forcing exit.');
      if (!Platform.isWindows) {
        child.kill(ProcessSignal.sigkill);
      } else {
        child.kill();
      }
      await childExit.future;
    }
  }

  static Future<void> _connectToParent(List<String> arguments) async {
    final portArgument = arguments
        .where((argument) => argument.startsWith(_portArg))
        .firstOrNull;
    final port = int.tryParse(portArgument?.substring(_portArg.length) ?? '');
    final token = Platform.environment[_tokenEnvironmentKey];
    if (port == null || token == null || token.isEmpty) {
      _log('watchdog parent connection details are missing; stopping child.');
      exit(70);
    }

    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 5),
      );
      final ready = Completer<void>();
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line == 'READY' && !ready.isCompleted) ready.complete();
          if (line == 'USER_EXIT_ACK') {
            final acknowledged = _userExitAcknowledged;
            if (acknowledged != null && !acknowledged.isCompleted) {
              acknowledged.complete();
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!ready.isCompleted) ready.completeError(error, stackTrace);
        },
        onDone: () {
          if (identical(_parentSocket, socket)) {
            _log('watchdog parent terminated; stopping child.');
            exit(0);
          }
        },
      );
      socket.write('HELLO:$token\n');
      await ready.future.timeout(const Duration(seconds: 5));
      _parentSocket = socket;
      try {
        await Isolate.spawn<List<Object>>(
          _watchParent,
          [port, token],
          debugName: 'app-watchdog-parent-monitor',
        );
      } on Object catch (error, stackTrace) {
        _log('independent parent monitor unavailable: $error\n$stackTrace');
      }
    } on Object catch (error, stackTrace) {
      _log('could not connect to watchdog parent: $error\n$stackTrace');
      exit(70);
    }
  }

  static Future<void> _watchParent(List<Object> arguments) async {
    final port = arguments[0] as int;
    final token = arguments[1] as String;
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.write('MONITOR:$token\n');
      await socket.flush();
      await socket.listen((_) {}).asFuture<void>();
      _log('watchdog parent terminated; stopping child.');
      exit(0);
    } on Object catch (error, stackTrace) {
      _log('parent monitor failed: $error\n$stackTrace');
      exit(70);
    }
  }

  static void startUiHeartbeat() {
    if (_parentSocket == null || _frameTimer != null) return;
    if (!_timingsCallbackRegistered) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _timingsCallbackRegistered = true;
    }
    _requestUiFrame();
    _frameTimer = Timer.periodic(
      _frameRequestInterval,
      (_) => _requestUiFrame(),
    );
  }

  static void _requestUiFrame() {
    if (_parentSocket != null) {
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  static void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    try {
      _parentSocket?.write('FRAME\n');
    } on Object catch (error, stackTrace) {
      _log('failed to send UI heartbeat: $error\n$stackTrace');
    }
  }

  static Future<void> markUserExit() async {
    final socket = _parentSocket;
    if (socket == null) return;
    final acknowledged = Completer<void>();
    _userExitAcknowledged = acknowledged;
    try {
      socket.write('USER_EXIT\n');
      await socket.flush();
      await acknowledged.future.timeout(const Duration(seconds: 2));
    } on Object catch (error, stackTrace) {
      _log('user exit supervisor acknowledgment failed: $error\n$stackTrace');
    } finally {
      if (identical(_userExitAcknowledged, acknowledged)) {
        _userExitAcknowledged = null;
      }
    }
  }
}

class AppWatchdogHealthPolicy {
  static const Duration startupGrace = Duration(minutes: 2);
  static const Duration uiHangTimeout = Duration(seconds: 30);

  static bool isUiUnresponsive({
    required DateTime now,
    required DateTime childStartedAt,
    required DateTime? lastUiFrameAt,
  }) {
    if (lastUiFrameAt == null) {
      return now.difference(childStartedAt) >= startupGrace;
    }
    return now.difference(lastUiFrameAt) >= uiHangTimeout;
  }

  static bool shouldRestartAfterExit(
    int exitCode, {
    bool userRequestedExit = false,
  }) {
    return exitCode != 0 && !userRequestedExit;
  }
}

class AppWatchdogRestartPolicy {
  static const Duration stableRuntime = Duration(minutes: 1);
  static const Duration baseDelay = Duration(seconds: 3);
  static const Duration maxDelay = Duration(minutes: 1);

  int _consecutiveFailures = 0;

  Duration recordFailure(Duration childRuntime) {
    if (childRuntime >= stableRuntime) {
      _consecutiveFailures = 0;
    }

    final exponent = _consecutiveFailures.clamp(0, 5);
    final delaySeconds =
        (baseDelay.inSeconds * (1 << exponent)).clamp(0, maxDelay.inSeconds);
    _consecutiveFailures++;
    return Duration(seconds: delaySeconds);
  }
}

class _ChildExited {
  const _ChildExited(this.exitCode);

  final int exitCode;
}

class _HealthCheckTick {
  const _HealthCheckTick();
}
