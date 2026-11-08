import 'dart:async';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/player_time_sync.dart';
import 'package:dcm/backend/utils/log_utils.dart';

/// 服务器时钟：维护「服务器时间 - 本地时间」偏移，用于多播放器同步开播。
///
/// 与 [PlayerTimeSync.setSystemTime] 不同，这里不修改系统时间（Android 需要
/// root、Windows 需要管理员），只在内存中保存偏移量。偏移来源：
/// 1. WebSocket 消息里 MessageWrapper.timestamp（服务器发送时刻）；
/// 2. 配置了 AppGlobal.timeServerUrl 时，可主动 NTP 校时精化。
class ServerClock {
  ServerClock._();
  static final ServerClock instance = ServerClock._();

  static const Duration _minRefineInterval = Duration(seconds: 10);

  Duration _offset = Duration.zero;
  bool _hasEstimate = false;
  DateTime? _lastRefinedAt;

  /// 是否已有服务器时间估算。
  bool get hasEstimate => _hasEstimate;

  /// 当前服务器时间偏移。
  Duration get offset => _offset;

  /// 当前估算的服务器时间。
  DateTime now() => DateTime.now().add(_offset);

  /// 用收到的服务器时间戳更新偏移估算。
  ///
  /// 假设上行/下行延迟对称：offset = serverSentAt - localReceivedAt，
  /// 误差约为单向延迟（局域网 <10ms）。多次更新取最小延迟对应的一次
  /// （无法直接测延迟，用平滑收敛近似）。
  void updateFromServerTimestamp(int serverTimestampMs) {
    if (serverTimestampMs <= 0) return;
    final localNow = DateTime.now().millisecondsSinceEpoch;
    final sample = serverTimestampMs - localNow;

    if (!_hasEstimate) {
      _offset = Duration(milliseconds: sample);
      _hasEstimate = true;
      _lastRefinedAt = DateTime.now();
      logI('ServerClock - first offset estimate: ${sample}ms');
      return;
    }

    // 指数平滑收敛，抑制单条消息的网络抖动。
    final current = _offset.inMilliseconds;
    final refined = (current * 0.7 + sample * 0.3).round();
    _offset = Duration(milliseconds: refined);
    _lastRefinedAt = DateTime.now();
  }

  /// 通过 NTP 服务器精化偏移（不修改系统时间，无需 root）。
  Future<void> refineFromNtp() async {
    if (AppGlobal.timeServerUrl.trim().isEmpty) return;
    final last = _lastRefinedAt;
    if (last != null &&
        DateTime.now().difference(last) < _minRefineInterval) {
      return;
    }
    try {
      final serverTime =
          await PlayerTimeSync.getServerTime(AppGlobal.timeServerUrl);
      final localNow = DateTime.now();
      _offset = serverTime.toLocal().difference(localNow);
      _hasEstimate = true;
      _lastRefinedAt = DateTime.now();
      logI('ServerClock - NTP refined offset: ${_offset.inMilliseconds}ms');
    } catch (error) {
      logW('ServerClock - NTP refine failed: $error');
    }
  }

  /// 计算距离服务器时刻 [serverTimestampMs] 还有多久。
  /// 已过期时返回负值。
  Duration delayUntil(int serverTimestampMs) {
    final target =
        DateTime.fromMillisecondsSinceEpoch(serverTimestampMs);
    return target.difference(now());
  }
}
