import 'dart:async';

import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
import 'package:flutter/services.dart';

/// 一块物理/逻辑显示器。
///
/// Android 上由 [DisplayManager] 枚举得到；每个 Display 拥有独立的坐标空间，
/// 所以 [rect] 始终从 (0, 0) 起算，尺寸即该 Display 自身的分辨率。
class MultiScreenDisplay {
  final int displayId;

  /// 稳定输出序号（主屏固定 0，扩展屏从 1 开始）。由原生按显示器
  /// 名称 + 分辨率持久化分配，与拔插顺序无关。
  final int output;
  final String name;
  final Size size;
  final double devicePixelRatio;
  final int rotation;
  final bool isPrimary;
  final bool isPresentationSupported;

  const MultiScreenDisplay({
    required this.displayId,
    required this.output,
    required this.name,
    required this.size,
    required this.devicePixelRatio,
    required this.rotation,
    required this.isPrimary,
    required this.isPresentationSupported,
  });

  Rect get rect => Rect.fromLTWH(0, 0, size.width, size.height);

  factory MultiScreenDisplay.fromMap(Map<Object?, Object?> map,
      {int fallbackOutput = 0}) {
    final width = (map['width'] as num?)?.toDouble() ?? 0;
    final height = (map['height'] as num?)?.toDouble() ?? 0;
    final densityDpi = (map['densityDpi'] as num?)?.toDouble() ?? 160;
    return MultiScreenDisplay(
      displayId: (map['displayId'] as num?)?.toInt() ?? 0,
      output: (map['output'] as num?)?.toInt() ?? fallbackOutput,
      name: map['name'] as String? ?? '',
      size: Size(width, height),
      devicePixelRatio: densityDpi / 160.0,
      rotation: (map['rotation'] as num?)?.toInt() ?? 0,
      isPrimary: map['isPrimary'] as bool? ?? false,
      isPresentationSupported:
          map['isPresentationSupported'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'Display(id: $displayId, output: $output, name: "$name", '
      'size: ${size.width.toInt()}x${size.height.toInt()}, '
      'dpr: ${devicePixelRatio.toStringAsFixed(2)}, rotation: $rotation, '
      'primary: $isPrimary)';
}

enum MultiScreenAction { added, removed, changed }

class MultiScreenEvent {
  final MultiScreenAction action;
  final int displayId;
  final List<MultiScreenDisplay> displays;

  const MultiScreenEvent(this.action, this.displayId, this.displays);

  @override
  String toString() =>
      'MultiScreenEvent(${action.name}, displayId: $displayId, total: ${displays.length})';
}

/// 多显示器枚举与热插拔监听。
///
/// 目前仅 Android 通过原生 [DisplayManager] 提供数据；桌面端继续使用
/// nativeapi 的 DisplayManager（见 AppSkinSetting._getMonitorInfo）。
class MultiScreenService {
  MultiScreenService._();

  static final MultiScreenService instance = MultiScreenService._();

  static const MethodChannel _channel = MethodChannel('dcm/multiscreen');

  final StreamController<MultiScreenEvent> _eventController =
      StreamController<MultiScreenEvent>.broadcast();

  List<MultiScreenDisplay> _displays = const [];
  bool _initialized = false;

  /// 原生通道是否可用（阶段 1 仅 Android）。
  bool get isSupported => !PlatformUtils.isWeb && PlatformUtils.isAndroid;

  List<MultiScreenDisplay> get displays => _displays;

  bool get hasMultipleDisplays => _displays.length > 1;

  Stream<MultiScreenEvent> get onDisplaysChanged => _eventController.stream;

  MultiScreenDisplay? get primary {
    for (final display in _displays) {
      if (display.isPrimary) return display;
    }
    return _displays.isEmpty ? null : _displays.first;
  }

  /// 按稳定输出序号取显示器。
  MultiScreenDisplay? displayAt(int output) {
    if (output < 0) return null;
    for (final display in _displays) {
      if (display.output == output) return display;
    }
    return null;
  }

  /// 初始化并完成首次枚举。重复调用无副作用。
  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    await refresh();
    logI(
        'MultiScreenService - initialized, displays: ${_displays.length}, '
        '${_displays.map((d) => d.displayId).toList()}');
  }

  /// 重新枚举显示器列表。
  Future<List<MultiScreenDisplay>> refresh() async {
    if (!isSupported) return _displays;
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getDisplays');
      _displays = _parseDisplays(raw ?? const []);
    } on PlatformException catch (error, stackTrace) {
      logE('MultiScreenService - getDisplays failed: ${error.message}', error,
          stackTrace);
    } on MissingPluginException {
      logW('MultiScreenService - native channel is not implemented');
    }
    return _displays;
  }

  /// 解析原生返回的显示器列表，按稳定输出序号排序。
  ///
  /// 旧版本原生不带 `output` 字段时按列表下标补齐，保证兼容。
  List<MultiScreenDisplay> _parseDisplays(List<Object?> raw) {
    final maps = raw.whereType<Map<Object?, Object?>>().toList(growable: false);
    final parsed = <MultiScreenDisplay>[];
    for (var i = 0; i < maps.length; i++) {
      parsed.add(MultiScreenDisplay.fromMap(maps[i], fallbackOutput: i));
    }
    parsed.sort((a, b) => a.output.compareTo(b.output));
    return List<MultiScreenDisplay>.unmodifiable(parsed);
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    _channel.setMethodCallHandler(null);
    await _eventController.close();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onDisplayEvent') return null;

    final args = call.arguments as Map<Object?, Object?>? ?? const {};
    final actionName = args['action'] as String? ?? 'changed';
    final displayId = (args['displayId'] as num?)?.toInt() ?? -1;
    final action = MultiScreenAction.values.firstWhere(
      (item) => item.name == actionName,
      orElse: () => MultiScreenAction.changed,
    );

    final rawDisplays = args['displays'] as List<Object?>? ?? const [];
    if (rawDisplays.isNotEmpty) {
      _displays = _parseDisplays(rawDisplays);
    } else {
      await refresh();
    }

    logI('MultiScreenService - $action, displayId: $displayId, '
        'displays: ${_displays.length}');
    if (!_eventController.isClosed) {
      _eventController.add(MultiScreenEvent(action, displayId, _displays));
    }
    return null;
  }
}
