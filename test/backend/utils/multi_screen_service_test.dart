import 'dart:ui' show Rect, Size;

import 'package:dcm/backend/utils/multi_screen_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiScreenDisplay.fromMap', () {
    test('converts physical pixels to Flutter logical pixels', () {
      final display = MultiScreenDisplay.fromMap({
        'displayId': 3,
        'output': 1,
        'width': 3840,
        'height': 2160,
        'densityDpi': 320,
      });

      expect(display.size, const Size(1920, 1080));
      expect(display.devicePixelRatio, 2);
      expect(display.rect, const Rect.fromLTWH(0, 0, 1920, 1080));
    });

    test('uses a safe ratio when density is invalid', () {
      final display = MultiScreenDisplay.fromMap({
        'width': 1920,
        'height': 1080,
        'densityDpi': 0,
      });

      expect(display.size, const Size(1920, 1080));
      expect(display.devicePixelRatio, 1);
    });
  });
}
