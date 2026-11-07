import 'package:dcm/backend/net/packet.dart';
import 'package:dcm/backend/net/netdef.dart';

Future<void> main() async {
  final p = Packet.fromString('hello',
      protocol: ProtocolId.qc.value, opcode: NetCommand.registerUpdate.value);
  final bytes = p.getPacket();
  print('packet bytes: $bytes');
  print('packet len: ${bytes.length}');
  print('orig pBuffer: ${p.getDataBuffer()!.toList()}');
  final parsed = PacketTcpServer.parsePacket(bytes);
  print('parsed pBuffer: ${parsed?.getDataBuffer()!.toList()}');
  print('parsed size: ${parsed?.getPacketSize()}');
  print('parsed opcode: ${parsed?.getOpCode()}');
  print('parsed protocol: ${parsed?.getProtocol()}');
}
