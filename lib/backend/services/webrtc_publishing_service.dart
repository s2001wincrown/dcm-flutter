import 'dart:async';

import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC 屏幕推流状态。
enum RtcPublishState { idle, starting, capturing, publishing, stopped, error }

/// WebRTC 屏幕推流服务：屏幕捕获 + WebRTC PeerConnection + 信令。
///
/// 信令通道通过 CMS WebSocket，不额外开 WebSocket 连接。
///
/// 采集统一使用 flutter_webrtc 的 [navigator.mediaDevices.getDisplayMedia]：
/// - 桌面 (Windows/macOS/Linux)：原生桌面采集（WGC / ScreenCaptureKit / PipeWire）
/// - Android：flutter_webrtc 内置 MediaProjection 授权 + ScreenCapturerAndroid，
///   推流前需先启动 mediaProjection 类型前台服务（Android 14+ 强制要求）。
///
/// 使用流程（播放器视角，作为 SDP 接收方 / answerer）：
/// 1. CMS 下发 CMD_WEBRTC_START → startCapture
/// 2. CMS 下发 CMD_WEBRTC_OFFER → setRemoteDescription + createAnswer + 发回
/// 3. CMS 下发 CMD_WEBRTC_ICE → addCandidate
/// 4. 本机 onIceCandidate → 发 CMD_WEBRTC_ICE 给 CMS
/// 5. CMS 下发 CMD_WEBRTC_STOP → close
///
/// 注：本实现让播放器做 answerer（更简单的 CMS 管理模型）。
class WebRtcPublishingService {
  WebRtcPublishingService._();
  static final WebRtcPublishingService instance = WebRtcPublishingService._();

  static const MethodChannel _channel = MethodChannel('dcm/webrtc_projection');

  final _stateController = StreamController<RtcPublishState>.broadcast();
  Stream<RtcPublishState> get state => _stateController.stream;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  DesktopCapturerSource? _desktopSource;
  String _targetId = '';
  RtcPublishState _currentState = RtcPublishState.idle;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  /// offer 可能早于 PeerConnection 就绪（Android 授权弹窗耗时），先缓存。
  RTCSessionDescription? _pendingOffer;

  RtcPublishState get currentState => _currentState;

  static const _stunServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  final _pcConfig = {
    'iceServers': _stunServers,
  };

  void _setState(RtcPublishState s) {
    _currentState = s;
    _stateController.add(s);
  }

  // ==========================================================================
  // 屏幕采集
  // ==========================================================================

  /// 启动屏幕捕获。[displayId] 为目标显示器索引；-1 或 null 表示主屏（仅桌面生效）。
  ///
  /// Android 首次调用会弹出系统屏幕录制授权框，授权后同一会话内不再重复弹窗。
  Future<void> startCapture({
    required String targetId,
    int? displayId,
    int? width,
    int? height,
    int frameRate = 30,
    bool withAudio = false,
  }) async {
    if (_currentState == RtcPublishState.capturing ||
        _currentState == RtcPublishState.publishing) {
      logW('WebRtc - already capturing, ignore startCapture');
      return;
    }
    _targetId = targetId;
    _setState(RtcPublishState.starting);
    try {
      await _acquireLocalStream(
        displayId: displayId,
        width: width,
        height: height,
        frameRate: frameRate,
        withAudio: withAudio,
      );
      _setState(RtcPublishState.capturing);
      await _createPeerConnection();
      _setState(RtcPublishState.publishing);
      logI('WebRtc - capture started, target=$targetId');
    } catch (error, stack) {
      _setState(RtcPublishState.error);
      logE('WebRtc - startCapture failed', error, stack);
      await _cleanupStream();
    }
  }

  Future<void> _acquireLocalStream({
    int? displayId,
    int? width,
    int? height,
    required int frameRate,
    required bool withAudio,
  }) async {
    if (PlatformUtils.isAndroid) {
      // Android 14+ 要求调用 MediaProjection 前必须有 mediaProjection 前台服务。
      // flutter_webrtc 只负责采集，不托管前台服务，故由本插件代为启动。
      await _channel.invokeMethod<bool>('startService');
    }

    final Map<String, dynamic> video = {
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'frameRate': frameRate,
    };

    if (PlatformUtils.isDesktop) {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen],
      );
      if (sources.isEmpty) {
        throw StateError('No screen source available on this desktop');
      }
      int idx = displayId ?? -1;
      if (idx < 0 || idx >= sources.length) idx = 0;
      _desktopSource = sources[idx];
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'audio': withAudio,
        'video': {
          ...video,
          'deviceId': {'exact': _desktopSource!.id},
          'mandatory': {'chromeMediaSource': 'desktop'},
        },
      });
      logI('WebRtc - desktop capture: source=${_desktopSource!.name}, '
          'displays=${sources.length}');
    } else {
      // Android：flutter_webrtc 内部弹 MediaProjection 授权并创建 VideoTrack。
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': video,
      });
      logI('WebRtc - android capture started');
    }
  }

  // ==========================================================================
  // PeerConnection + 信令
  // ==========================================================================

  Future<void> _createPeerConnection() async {
    // 只销毁旧的 PeerConnection，不能动刚采集到的本地流。
    await _disposePeerConnection();
    final pc = await createPeerConnection(_pcConfig);
    _pc = pc;

    // 直接把整个本地流加进去
    if (_localStream != null) {
      await pc.addStream(_localStream!);
    }

    pc.onIceCandidate = (candidate) {
      _emitIceCandidate(candidate);
    };
    pc.onConnectionState = (state) {
      logI('WebRtc - pc state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        // 不自动清理，让上层决定
      }
    };
    pc.onIceConnectionState = (state) {
      logI('WebRtc - ice state: $state');
    };
    // 监控场景通常不需要接收远端 track（播放器只推不拉），
    // 但 CMS 可能用它来回显低延迟预览。
    pc.onAddTrack = (stream, track) {
      logI('WebRtc - got remote track: ${track.kind}');
    };
    pc.onRemoveTrack = (stream, track) {
      logI('WebRtc - remote track removed: ${track.kind}');
    };

    // 把之前可能收到的远端 ICE candidates 补上
    for (final c in _pendingRemoteCandidates) {
      await pc.addCandidate(c);
    }
    _pendingRemoteCandidates.clear();

    // 若 offer 早于 PeerConnection 就绪，现在补处理
    final pending = _pendingOffer;
    if (pending != null) {
      _pendingOffer = null;
      await handleRemoteOffer(pending);
    }
  }

  Future<void> _disposePeerConnection() async {
    _pendingRemoteCandidates.clear();
    try {
      await _pc?.dispose();
    } catch (_) {}
    _pc = null;
  }

  /// CMS 下发 offer（播放器做 answerer）。
  Future<void> handleRemoteOffer(RTCSessionDescription offer) async {
    final pc = _pc;
    if (pc == null) {
      logW('WebRtc - pc not ready, queue offer until it is');
      _pendingOffer = offer;
      return;
    }
    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer({});
    await pc.setLocalDescription(answer);
    _emitSdp('answer', answer);
    logI('WebRtc - answered remote offer');
  }

  /// CMS 下发 answer（播放器做 offerer 的反向场景，当前 MVP 不默认使用）。
  Future<void> handleRemoteAnswer(RTCSessionDescription answer) async {
    final pc = _pc;
    if (pc == null) return;
    await pc.setRemoteDescription(answer);
    logI('WebRtc - remote answer applied');
  }

  /// CMS 下发 ICE candidate。
  Future<void> addRemoteIceCandidate(RTCIceCandidate candidate) async {
    final pc = _pc;
    if (pc == null) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    await pc.addCandidate(candidate);
  }

  // ==========================================================================
  // 向外发送（通过 CMS WebSocket）
  // ==========================================================================

  /// 播放器做 offerer 时主动发起（当前 MVP 默认做 answerer，留给 future）。
  Future<RTCSessionDescription?> createLocalOffer() async {
    final pc = _pc;
    if (pc == null) return null;
    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);
    _emitSdp('offer', offer);
    return offer;
  }

  void _emitSdp(String type, RTCSessionDescription desc) {
    _EmitSignaling.instance.emitSdp(
      targetId: _targetId,
      type: type,
      sdp: desc.sdp ?? '',
    );
  }

  void _emitIceCandidate(RTCIceCandidate candidate) {
    _EmitSignaling.instance.emitIce(
      targetId: _targetId,
      candidate: candidate.candidate ?? '',
      sdpMid: candidate.sdpMid ?? '',
      sdpMLineIndex: candidate.sdpMLineIndex,
    );
  }

  // ==========================================================================
  // 停止 / 清理
  // ==========================================================================

  Future<void> close() async {
    _pendingOffer = null;
    await _disposePeerConnection();
    await _cleanupStream();
    _desktopSource = null;
    if (PlatformUtils.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('stopService');
      } catch (_) {}
    }
    if (_currentState != RtcPublishState.idle &&
        _currentState != RtcPublishState.stopped) {
      _setState(RtcPublishState.stopped);
    }
  }

  Future<void> _cleanupStream() async {
    try {
      final tracks = _localStream?.getTracks() ?? const [];
      for (final t in tracks) {
        try {
          await t.stop();
        } catch (_) {}
      }
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
  }
}

/// 信令发送桥：由 CMS WebSocket 层注册发送函数，WebRTC 服务层只回调这里。
class _EmitSignaling {
  _EmitSignaling._();
  static final _EmitSignaling instance = _EmitSignaling._();

  void Function({
    required String targetId,
    required String type,
    required String sdp,
  })? onSdp;

  void Function({
    required String targetId,
    required String candidate,
    required String sdpMid,
    required int? sdpMLineIndex,
  })? onIce;

  void emitSdp({
    required String targetId,
    required String type,
    required String sdp,
  }) {
    onSdp?.call(targetId: targetId, type: type, sdp: sdp);
  }

  void emitIce({
    required String targetId,
    required String candidate,
    required String sdpMid,
    required int? sdpMLineIndex,
  }) {
    onIce?.call(
      targetId: targetId,
      candidate: candidate,
      sdpMid: sdpMid,
      sdpMLineIndex: sdpMLineIndex,
    );
  }
}

/// 让 CMS WebSocket 层注册发送回调。
void registerWebRtcSignalingEmitters({
  required void Function({
    required String targetId,
    required String type,
    required String sdp,
  }) onSdp,
  required void Function({
    required String targetId,
    required String candidate,
    required String sdpMid,
    required int? sdpMLineIndex,
  }) onIce,
}) {
  _EmitSignaling.instance.onSdp = onSdp;
  _EmitSignaling.instance.onIce = onIce;
}
