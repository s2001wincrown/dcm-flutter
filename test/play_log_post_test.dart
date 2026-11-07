import 'package:dcm/backend/net/play_log_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayLogPostService', () {
    test('parses hex log post flags and enables matching uploads', () {
      PlayLogPostService.processLogPostFlag(0x00000002); // AH play log

      expect(PlayLogPostService.isEnabled(PlayLogPostFlag.ahPlayLog), isTrue);
      expect(PlayLogPostService.isEnabled(PlayLogPostFlag.playLog), isFalse);
    });

    test('builds a player log request payload', () {
      final payload = PlayLogPostService.buildPlayerLogRequest(
          'UniqueKey=abc123',
          'dtLastSyncTime=2026-07-11 12:00:00',
          PlayLogPostFlag.playerLog2,
          'player-001',
          'Player A');

      expect(payload, contains('UniqueKey=abc123'));
      expect(payload, contains('dtLastSyncTime=2026-07-11 12:00:00'));
      expect(payload, contains('strUniqueName=player-001'));
      expect(payload, contains('strPlayer=Player A'));
    });
  });
}
