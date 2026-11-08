import 'dart:math';

import 'package:dcm/widgets/slideshow_transition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('random slideshow effect can select every declared effect', () {
    final random = Random(42);
    final selected = {
      for (var i = 0; i < 1000; i++) randomSlideshowEffect(random),
    };

    expect(selected, containsAll(SlideshowEffect.values));
  });
}
