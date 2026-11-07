import 'package:dcm/backend/net/netdef.dart';
import 'package:dcm/backend/net/packet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PacketTcpServer', () {
    test('parses a packet from raw bytes', () {
      final original = Packet.fromString(
        'hello',
        protocol: ProtocolId.qc.value,
        opcode: NetCommand.registerUpdate.value,
      );

      final bytes = original.getPacket();
      final parsed = PacketTcpServer.parsePacket(bytes);

      expect(parsed, isNotNull);
      expect(parsed!.getOpCode(), original.getOpCode());
      expect(parsed.getProtocol(), original.getProtocol());
      expect(parsed.getPacketSize(), original.getPacketSize());
      expect(
          parsed.getDataBuffer()!.toList(), original.getDataBuffer()!.toList());
    });

    test('parses a packet from a byte buffer split across chunks', () {
      final original = Packet.fromString(
        'hello world',
        protocol: ProtocolId.ah.value,
        opcode: NetCommand.ahMessage.value,
      );

      final bytes = original.getPacket();
      final firstChunk = bytes.sublist(0, 4);
      final secondChunk = bytes.sublist(4);

      final parser = PacketTcpServer.createParser();
      final firstParse = parser.feed(firstChunk);
      expect(firstParse, isNull);

      final secondParse = parser.feed(secondChunk);
      expect(secondParse, isNotNull);
      expect(secondParse!.getOpCode(), original.getOpCode());
      expect(secondParse.getProtocol(), original.getProtocol());
      expect(secondParse.getPacketSize(), original.getPacketSize());
      expect(secondParse.getDataBuffer()!.toList(),
          original.getDataBuffer()!.toList());
    });
  });
}
