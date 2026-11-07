import 'dart:ui';

import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/floating_player_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FloatingPlayerImpl', () {
    late FloatingPlayerImpl player;
    late ProductData product;

    setUp(() {
      product = ProductData()
        ..strProductDesc = ''
        ..lstZone = [
          ZoneData()
            ..nZoneID = 0
            ..strZoneFile = 'first.jpg',
          ZoneData()
            ..nZoneID = 1
            ..strZoneFile = 'second.jpg',
        ];
      player = FloatingPlayerImpl.fromProduct(product, true);
    });

    test('maps product zones into the player rectangle', () {
      player.setWindowRect(const Rect.fromLTWH(10, 20, 100, 80));

      expect(
        player.scaleToVW(0),
        const Rect.fromLTRB(10, 60, 110, 100),
      );
      expect(
        player.scaleToVW(1),
        const Rect.fromLTRB(10, 20, 110, 60),
      );
    });

    test('treats regular product zones as immediately playable', () {
      expect(player.isValidForPlay(), isTrue);
      expect(player.isTimeForPlay(product), isTrue);
      expect(player.isOutdated(product), isFalse);
    });

    test('returns the active player rectangle and zone configuration', () {
      player.setZone(42);
      player.setWindowRect(const Rect.fromLTWH(5, 8, 320, 180));

      expect(player.zone, 42);
      expect(player.getZone(), 42);
      expect(player.playerRect, const Rect.fromLTWH(5, 8, 320, 180));
    });
  });
}
