import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/services/playlist_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timed AH episode catalogue selection', () {
    late Directory tempDirectory;
    late String originalOpenPath;
    late int originalAHConflictMode;

    setUp(() {
      tempDirectory =
          Directory.systemTemp.createTempSync('dcm_ah_episode_test_');
      originalOpenPath = AppGlobal.openPath;
      originalAHConflictMode = AppGlobal.processAHConflict;
      AppGlobal.openPath = tempDirectory.path;
      AppGlobal.processAHConflict = 0;
    });

    tearDown(() {
      AppGlobal.openPath = originalOpenPath;
      AppGlobal.processAHConflict = originalAHConflictMode;
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test('playFileList selects an active timed item with group loop enabled',
        () {
      const catalogueName = 'local-insert.dcm';
      final cataloguePath = Utils.getFilePath(catalogueName, cDCMFILETYPE);
      File(cataloguePath).writeAsStringSync('local catalogue fixture');

      final now = DateTime.now();
      final timedItem = EventItemData()
        ..uiID = 3
        ..nItemType = EventItemType.insert
        ..bIsTimeSchedule = true
        ..dtStart = '${now.hour.toString().padLeft(2, '0')}:00:00'
        ..dtEnd = '${((now.hour + 1) % 24).toString().padLeft(2, '0')}:59:59'
        ..strDCMFile = catalogueName;
      final eventFile = EventFileData()
        ..nGroupLoop = 1
        ..dtStart = DateTime(now.year, now.month, now.day)
        ..dtEnd = DateTime(now.year, now.month, now.day, 23, 59, 59)
        ..lstPlayList = [
          EventItemData()..uiID = 0,
          EventItemData()..uiID = 1,
          EventItemData()..uiID = 2,
          timedItem,
        ];
      final playlist = PlayList(ScheduleList())..eventFile = eventFile;

      final result = playlist.playFileList();

      expect(result.status, isTrue);
      expect(result.strDCMFile, catalogueName);
      expect(playlist.ahPlaylistZone.getDCMFile, catalogueName);
      expect(playlist.ahPlaylistZone.getPlayFile, timedItem.uiID);
    });

    test('selects an existing file from an active timed group', () {
      const catalogueName = 'group-insert.dcm';
      final cataloguePath = Utils.getFilePath(catalogueName, cDCMFILETYPE);
      File(cataloguePath).writeAsStringSync('local group catalogue fixture');

      final timedGroup = EventItemData()
        ..uiID = 4
        ..nItemType = EventItemType.group
        ..bIsGroup = true
        ..bIsTimeSchedule = true
        ..arrDCMFile = [catalogueName];
      final eventFile = EventFileData()..nGroupLoop = 1;
      final playlist = PlayList(ScheduleList())
        ..eventFile = eventFile
        ..isPlayEpisode = true
        ..currEpisode = timedGroup.uiID;

      final result = playlist.validPlayListData(timedGroup);

      expect(result.status, isTrue);
      expect(result.strDCMFile, catalogueName);
      expect(playlist.ahPlaylistZone.getDCMFile, catalogueName);
      expect(playlist.ahPlaylistZone.getPlayFile, timedGroup.uiID);
    });
  });
}
