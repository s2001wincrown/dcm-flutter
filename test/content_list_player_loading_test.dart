import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/services/content_list_player_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty content list is not finished while it is loading', () {
    final player = ContentListPlayerImpl(cDIRECTPLAYTYPE, 1)
      ..setIsLoading(true);

    final result = player.isPlayFinish(PlayFinish.eNOTFINISH);

    expect(result.status, isFalse);
    expect(result.nFinish, PlayFinish.eCONTENTSTARTING);
  });

  test('empty content list completes only after loading is cleared', () {
    final player = ContentListPlayerImpl(cDIRECTPLAYTYPE, 1)
      ..setIsLoading(true);

    expect(player.isPlayFinish(PlayFinish.eNOTFINISH).status, isFalse);

    player.setIsLoading(false);
    expect(player.isPlayFinish(PlayFinish.eNOTFINISH).status, isTrue);
  });
}
