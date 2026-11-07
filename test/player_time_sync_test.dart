import 'dart:io';
import 'dart:typed_data';

import 'package:dcm/backend/net/player_time_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerTimeSync', () {
    test('queries an NTP server and estimates current UTC time', () async {
      final server =
          await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final request = server.receive();
        if (request == null) {
          return;
        }

        final response = Uint8List(48)
          ..[0] = 0x24
          ..[1] = 1;
        response.setRange(24, 32, request.data.sublist(40, 48));
        _writeTimestamp(response, 32, DateTime.now().toUtc());
        _writeTimestamp(response, 40, DateTime.now().toUtc());
        server.send(response, request.address, request.port);
      });

      final before = DateTime.now().toUtc();
      final synchronizedTime = await PlayerTimeSync.getServerTime(
        'ntp://127.0.0.1:${server.port}',
      );
      final after = DateTime.now().toUtc();

      expect(synchronizedTime.isUtc, isTrue);
      expect(
          synchronizedTime.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(synchronizedTime.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });

    test('rejects empty and non-NTP server URLs', () async {
      await expectLater(
        PlayerTimeSync.getServerTime(''),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        PlayerTimeSync.getServerTime('https://example.com'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

void _writeTimestamp(Uint8List packet, int offset, DateTime utcTime) {
  const ntpEpochOffsetSeconds = 2208988800;
  final milliseconds = utcTime.millisecondsSinceEpoch;
  final seconds = milliseconds ~/ 1000 + ntpEpochOffsetSeconds;
  final fraction = (milliseconds.remainder(1000) * 0x100000000) ~/ 1000;
  _writeUint32(packet, offset, seconds);
  _writeUint32(packet, offset + 4, fraction);
}

void _writeUint32(Uint8List packet, int offset, int value) {
  packet[offset] = (value >> 24) & 0xff;
  packet[offset + 1] = (value >> 16) & 0xff;
  packet[offset + 2] = (value >> 8) & 0xff;
  packet[offset + 3] = value & 0xff;
}
