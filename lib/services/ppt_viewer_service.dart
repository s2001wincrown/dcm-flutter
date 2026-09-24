import 'package:flutter/services.dart';

class PptViewerService {
  static const _channel = MethodChannel('dcm/ppt_viewer');

  static Future<bool> start({
    required String viewerPath,
    required String filePath,
  }) async {
    return await _channel.invokeMethod<bool>('start', <String, String>{
          'viewerPath': viewerPath,
          'filePath': filePath,
        }) ??
        false;
  }

  static Future<void> resize({
    required int left,
    required int top,
    required int width,
    required int height,
  }) async {
    await _channel.invokeMethod<void>('resize', <String, int>{
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}
