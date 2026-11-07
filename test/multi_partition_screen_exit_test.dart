import 'dart:io';

import 'package:dcm/pages/multi_partition_screen.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoContentPlayerScreenProvider extends PlayerScreenProvider {
  @override
  Future<void> playImm() async {}

  @override
  bool isValidForPlay() => false;
}

void main() {
  testWidgets('double tap opens menu when there is no content to play',
      (tester) async {
    initFileLogger(Directory.systemTemp.path);
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerScreenProvider>(
        create: (_) => _NoContentPlayerScreenProvider(),
        child: const MaterialApp(home: DigitalSignageScreen()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(100, 100));
    await tester.pump();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  group('shouldTriggerDoubleTapExit', () {
    test('returns false when widget is not mounted', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final lastTap = now.subtract(const Duration(milliseconds: 100));

      expect(
        shouldTriggerDoubleTapExit(
          now: now,
          lastTap: lastTap,
          window: const Duration(milliseconds: 300),
          mounted: false,
          isExiting: false,
        ),
        isFalse,
      );
    });

    test('returns true for taps within the double tap window', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final lastTap = now.subtract(const Duration(milliseconds: 100));

      expect(
        shouldTriggerDoubleTapExit(
          now: now,
          lastTap: lastTap,
          window: const Duration(milliseconds: 300),
          mounted: true,
          isExiting: false,
        ),
        isTrue,
      );
    });

    test('returns false when exiting is already in progress', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final lastTap = now.subtract(const Duration(milliseconds: 100));

      expect(
        shouldTriggerDoubleTapExit(
          now: now,
          lastTap: lastTap,
          window: const Duration(milliseconds: 300),
          mounted: true,
          isExiting: true,
        ),
        isFalse,
      );
    });
  });
}
