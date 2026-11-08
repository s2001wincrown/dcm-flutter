import 'package:dcm/proto/websocket_def.pb.dart';
import 'package:fixnum/fixnum.dart';

void main() {
  // SyncPlayCommand 编解码
  final cmd = SyncPlayCommand(
    content: 'test.dcm',
    startTime: Int64(1730000000000),
    tolerance: 3000,
  );
  final decoded = SyncPlayCommand.fromBuffer(cmd.writeToBuffer());
  assert(decoded.content == 'test.dcm');
  assert(decoded.startTime.toInt() == 1730000000000);
  assert(decoded.tolerance == 3000);

  // MessageWrapper 包装 CMD_SYNC_PLAY(27)
  final wrapper = MessageWrapper(
    command: CommandType.CMD_SYNC_PLAY,
    protocolId: ProtocolId.PROTOCOL_QC,
    payload: cmd.writeToBuffer(),
    timestamp: Int64(1730000000000),
  );
  final w2 = MessageWrapper.fromBuffer(wrapper.writeToBuffer());
  assert(w2.command == CommandType.CMD_SYNC_PLAY);
  assert(w2.command.value == 27);
  assert(CommandType.valueOf(27) == CommandType.CMD_SYNC_PLAY);
  final p2 = SyncPlayCommand.fromBuffer(w2.payload);
  assert(p2.content == 'test.dcm' && p2.startTime.toInt() == 1730000000000);

  // 默认字段为空时的解码
  final empty = SyncPlayCommand.fromBuffer(SyncPlayCommand().writeToBuffer());
  assert(empty.content.isEmpty && empty.startTime == Int64.ZERO && empty.tolerance == 0);

  print('sync_play proto roundtrip: OK');
}
