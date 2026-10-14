import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class PlayerTimeSync {
  static const int _ntpEpochOffsetSeconds = 2208988800;
  static const int _packetLength = 48;

  static Future<DateTime> getServerTime(
    String serverUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = _parseServerUri(serverUrl);
    final addresses = await InternetAddress.lookup(uri.host);
    if (addresses.isEmpty) {
      throw SocketException('No IP address found for ${uri.host}');
    }

    final address = addresses.first;
    final bindAddress = address.type == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4;
    final socket = await RawDatagramSocket.bind(bindAddress, 0);
    final response = Completer<Datagram>();
    final subscription = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null && !response.isCompleted) {
          response.complete(datagram);
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      if (!response.isCompleted) {
        response.completeError(error, stackTrace);
      }
    });
    try {
      final request = _createRequestPacket(DateTime.now().toUtc());
      final stopwatch = Stopwatch()..start();
      socket.send(request, address, uri.port);
      final datagram = await response.future.timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException('NTP server ${uri.host} did not respond'),
      );
      stopwatch.stop();

      if (datagram.address.address != address.address ||
          datagram.port != uri.port) {
        throw const FormatException(
            'NTP response came from an unexpected host');
      }
      _validateResponse(datagram.data, request);
      return _readTimestamp(datagram.data, 40)
          .add(Duration(microseconds: stopwatch.elapsedMicroseconds ~/ 2));
    } finally {
      await subscription.cancel();
      socket.close();
    }
  }

  static Future<void> setSystemTime(DateTime utcTime) async {
    final milliseconds = utcTime.toUtc().millisecondsSinceEpoch;
    final seconds = milliseconds ~/ 1000;
    final fractionalMilliseconds = milliseconds.remainder(1000).abs();
    final timestamp =
        '@$seconds.${fractionalMilliseconds.toString().padLeft(3, '0')}';

    if (Platform.isWindows) {
      await _runSystemCommand('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Set-Date -Date ([DateTimeOffset]::FromUnixTimeMilliseconds($milliseconds).LocalDateTime)',
      ]);
    } else if (Platform.isAndroid) {
      await _runSystemCommand('su', ['-c', 'date -u -s $timestamp']);
    } else if (Platform.isLinux) {
      await _runSystemCommand('date', ['-u', '--set=$timestamp']);
    } else {
      throw UnsupportedError(
          'Setting the system clock is not supported on ${Platform.operatingSystem}.');
    }
  }

  static Uri _parseServerUri(String serverUrl) {
    final value = serverUrl.trim();
    if (value.isEmpty) {
      throw const FormatException('NTP server URL is empty');
    }

    final uri = Uri.tryParse(value.contains('://') ? value : 'ntp://$value');
    if (uri == null ||
        uri.scheme != 'ntp' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty && uri.path != '/' ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException('Invalid NTP server URL: $serverUrl');
    }

    final port = uri.hasPort ? uri.port : 123;
    if (port < 1 || port > 65535) {
      throw FormatException('Invalid NTP server port: $port');
    }
    return uri.replace(port: port);
  }

  static Uint8List _createRequestPacket(DateTime utcTime) {
    final packet = Uint8List(_packetLength);
    packet[0] = 0x23;
    _writeTimestamp(packet, 40, utcTime);
    return packet;
  }

  static void _writeTimestamp(Uint8List packet, int offset, DateTime utcTime) {
    final milliseconds = utcTime.toUtc().millisecondsSinceEpoch;
    final seconds = milliseconds ~/ 1000 + _ntpEpochOffsetSeconds;
    final remainingMilliseconds = milliseconds.remainder(1000).abs();
    final fraction = (remainingMilliseconds * 0x100000000) ~/ 1000;
    _writeUint32(packet, offset, seconds);
    _writeUint32(packet, offset + 4, fraction);
  }

  static void _validateResponse(List<int> packet, List<int> request) {
    if (packet.length < _packetLength) {
      throw const FormatException('NTP response is shorter than 48 bytes');
    }

    final leapIndicator = packet[0] >> 6;
    final version = (packet[0] >> 3) & 0x07;
    final mode = packet[0] & 0x07;
    if (leapIndicator == 3 ||
        (version != 3 && version != 4) ||
        mode != 4 ||
        packet[1] == 0 ||
        packet[1] > 15) {
      throw const FormatException('NTP server returned an invalid response');
    }

    for (var i = 0; i < 8; i++) {
      if (packet[24 + i] != request[40 + i]) {
        throw const FormatException('NTP response does not match the request');
      }
    }

    if (packet.sublist(40, 48).every((byte) => byte == 0)) {
      throw const FormatException('NTP response has no transmit timestamp');
    }
  }

  static DateTime _readTimestamp(List<int> packet, int offset) {
    final seconds = _readUint32(packet, offset);
    final fraction = _readUint32(packet, offset + 4);
    final milliseconds = (seconds - _ntpEpochOffsetSeconds) * 1000 +
        ((fraction * 1000) ~/ 0x100000000);
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static int _readUint32(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static void _writeUint32(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 24) & 0xff;
    bytes[offset + 1] = (value >> 16) & 0xff;
    bytes[offset + 2] = (value >> 8) & 0xff;
    bytes[offset + 3] = value & 0xff;
  }

  static Future<void> _runSystemCommand(
      String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      final output = '${result.stderr}\n${result.stdout}'.trim();
      throw ProcessException(
        executable,
        arguments,
        output.isEmpty ? 'Command exited with ${result.exitCode}' : output,
        result.exitCode,
      );
    }
  }
}
