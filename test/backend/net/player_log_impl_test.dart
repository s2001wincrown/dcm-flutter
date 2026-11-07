import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/player_log_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late String previousFtpSettingPath;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('player_log_impl_');
    previousFtpSettingPath = AppGlobal.ftpSettingPath;
    AppGlobal.ftpSettingPath = tempDirectory.path;
    initFileLogger(tempDirectory.path);
    PlayerLogImpl.lstTaskInfo.clear();
    PlayerLogImpl.bIsDirty = false;
  });

  tearDown(() async {
    AppGlobal.ftpSettingPath = previousFtpSettingPath;
    PlayerLogImpl.lstTaskInfo.clear();
    PlayerLogImpl.bIsDirty = false;
    await tempDirectory.delete(recursive: true);
  });

  group('PlayerLogImpl task tracking', () {
    test('expires tasks and deduplicates task names without regard to case',
        () async {
      PlayerLogImpl.lstTaskInfo.add(
        TaskInfo('reusable-task',
            DateTime.now().subtract(const Duration(seconds: 1))),
      );

      expect(PlayerLogImpl.isNewTask('REUSABLE-TASK'), isTrue);
      expect(PlayerLogImpl.isNewTask('reusable-task'), isFalse);
      expect(PlayerLogImpl.lstTaskInfo, hasLength(1));
      expect(
        PlayerLogImpl.lstTaskInfo.single.receivedAt.isAfter(DateTime.now()),
        isTrue,
      );

      expect(await PlayerLogImpl.saveTaskLog(), isTrue);
    });

    test('serializes concurrent duplicate checks and awaits persistence',
        () async {
      final results = await Future.wait([
        PlayerLogImpl.isNewTaskSave('same-task'),
        PlayerLogImpl.isNewTaskSave('SAME-TASK'),
      ]);

      expect(results.where((isNew) => isNew), hasLength(1));
      expect(PlayerLogImpl.lstTaskInfo, hasLength(1));
      expect(
          File('${tempDirectory.path}${Platform.pathSeparator}tasklog.xml')
              .existsSync(),
          isTrue);
      expect(PlayerLogImpl.bIsDirty, isFalse);
    });

    test('reloading does not append duplicates or extend task validity',
        () async {
      expect(await PlayerLogImpl.isNewTaskSave('persistent-task'), isTrue);
      final originalValidity = PlayerLogImpl.lstTaskInfo.single.receivedAt;

      expect(await PlayerLogImpl.loadFTPLog(), isTrue);
      final firstLoadValidity = PlayerLogImpl.lstTaskInfo.single.receivedAt;
      expect(await PlayerLogImpl.loadFTPLog(), isTrue);
      final secondLoadValidity = PlayerLogImpl.lstTaskInfo.single.receivedAt;

      expect(PlayerLogImpl.lstTaskInfo, hasLength(1));
      expect(
        firstLoadValidity.difference(originalValidity).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        secondLoadValidity.difference(firstLoadValidity).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });
  });
}
