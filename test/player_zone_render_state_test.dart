import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video zones remain retryable until a video controller is ready',
      () async {
    final logDirectory =
        await Directory.systemTemp.createTemp('dcm_player_zone_render_');
    initFileLogger(logDirectory.path);

    try {
      for (final contentType in [cVIDEOTYPE, cSTREAMINGTYPE]) {
        final zone = PlayerZoneImpl()
          ..setZoneData(ZoneData()..nZoneType = contentType);

        final widget = zone.renderZone();

        expect(widget, isA<Container>());
        expect(zone.isPlaying(), isFalse);
        expect(zone.isRendering(), isFalse);
      }
    } finally {
      try {
        await logDirectory.delete(recursive: true);
      } catch (_) {}
    }
  });
}
