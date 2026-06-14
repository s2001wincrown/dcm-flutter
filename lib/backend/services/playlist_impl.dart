// playlist_item.dart
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xml_settings/event_date_file.dart';
import 'package:dcm/backend/xml_settings/eventfile_impl.dart';
import 'package:dcm/backend/xml_settings/room_date_file.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

enum PlayMethod {
  crossPlaylist,
  perOutputPlaylist,
  sequencePlaylist,
  ahPlaylist,
}

class AHSchedule {
  AHSchedule(this.itemID, this.uiTimeID, this.dtStart, this.dtEnd);

  int itemID;
  int uiTimeID;
  DateTime dtStart;
  DateTime dtEnd;
}

class PlaylistZoneItem {
  late int zoneId;
  late String zoneFile;
  late int zoneType;
  late int contentListIndex;
  late int contentListTotal;
  late double position;

  PlaylistZoneItem({
    required this.zoneId,
    required this.zoneFile,
    required this.zoneType,
    required this.contentListIndex,
    required this.contentListTotal,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
        'zoneId': zoneId,
        'zoneFile': zoneFile,
        'zoneType': zoneType,
        'contentListIndex': contentListIndex,
        'contentListTotal': contentListTotal,
        'position': position,
      };

  factory PlaylistZoneItem.fromJson(Map<String, dynamic> json) =>
      PlaylistZoneItem(
        zoneId: json['zoneId'],
        zoneFile: json['zoneFile'],
        zoneType: json['zoneType'],
        contentListIndex: json['contentListIndex'],
        contentListTotal: json['contentListTotal'],
        position: json['position'].toDouble(),
      );

  void dumpPlaylistZoneItem() {
    logD(
        'DumpPlaylistZoneItem; ZoneID: $zoneId; ContentList Index: $contentListIndex; Content Total Item: $contentListTotal; strZoneFile: $zoneFile; ZoneType: $zoneType');
  }
}

class PlaylistZone {
  final List<PlaylistZoneItem> _playlistZone = [];
  String dcmFile = '';
  int playFile = -1;
  int playProduct = 0;
  int currPlay = -1;
  int playTimes = 0;

  int get count => _playlistZone.length;
  String get getDCMFile => dcmFile;

  void setDCMFile(String file) {
    dcmFile = file;
  }

  void setPlayFile(int file) {
    playFile = file;
  }

  int get getPlayFile => playFile;

  void setPlayProduct(int product) {
    playProduct = product;
  }

  int get getPlayProduct => playProduct;

  void setCurrPlay(int play) {
    currPlay = play;
  }

  int get getCurrPlay => currPlay;

  void setPlayTimes([int times = -1]) {
    if (times == -1) {
      playTimes++;
    } else {
      playTimes = times;
    }
  }

  int get getPlayTimes => playTimes;

  bool incrementProductIndex(int maxProduct) {
    _playlistZone.clear();
    playProduct++;
    if (playProduct == maxProduct) {
      playProduct = 0;
      return false;
    }
    return true;
  }

  void incrementContentListIndex() {
    for (var item in _playlistZone) {
      if (item.zoneType == cDIRECTPLAYTYPE) {
        item.contentListIndex++;
      }
    }
  }

  bool getContentListIndex(int zone, int index) {
    for (var item in _playlistZone) {
      if (item.zoneId == zone) {
        index = item.contentListIndex;
        return true;
      }
    }
    return false;
  }

  bool getPlayDuration(int zone, double duration) {
    for (var item in _playlistZone) {
      if (item.zoneId == zone) {
        duration = item.position;
        return true;
      }
    }
    return false;
  }

  void setContentListIndex(int zone, int index, [int total = 0]) {
    for (var item in _playlistZone) {
      if (item.zoneId == zone) {
        item.contentListIndex = index;
        if (total != 0) {
          item.contentListTotal = total;
        }
        break;
      }
    }
  }

  void setPlayDuration(int zone, double duration) {
    for (var item in _playlistZone) {
      if (item.zoneId == zone) {
        item.position = duration;
        break;
      }
    }
  }

  void emptyPlaylistZone() {
    _playlistZone.clear();
  }

  void addPlaylistZone(int itemId, String zoneFile, int zoneType,
      int contentList, int contentListTotal, double pos) {
    _playlistZone.add(PlaylistZoneItem(
      zoneId: itemId,
      zoneFile: zoneFile,
      zoneType: zoneType,
      contentListIndex: contentList,
      contentListTotal: contentListTotal,
      position: pos,
    ));
  }

  void resetPlaylistZone() {
    emptyPlaylistZone();
    dcmFile = '';
    playFile = 0;
    playProduct = 0;
    currPlay = 0;
    playTimes = 0;
  }

  void resetPlayIndex() {
    playProduct = 0;
    currPlay = 0;
    emptyPlaylistZone();
  }

  void initPlaylistZone(ProductData? product) {
    emptyPlaylistZone();
    if (product != null) {
      for (var zone in product.lstZone) {
        addPlaylistZone(
          zone.nZoneID,
          zone.strZoneFile,
          zone.nZoneType,
          0,
          0,
          0.0,
        );
      }
    }
  }

  void dumpPlaylistZone() {
    logD(
        'DumpPlaylistZone; PlayFile: $playFile; CurrPlay: $currPlay; PlayProduct: $playProduct; DCMFile: $dcmFile; PlayTimes: $playTimes');
    for (var pPlaylistZone in _playlistZone) {
      pPlaylistZone.dumpPlaylistZoneItem();
    }
  }
}

// playlist.dart
class PlayList {
  String company = '';
  String strEvent = '';
  String uniqueName = '';
  String controlEvent = '';

  bool isPlayEpisode = false;
  bool isAHPlaying = false;
  bool deviceControl = false;
  bool controlPlay = false;
  bool swapEvent = false;
  bool writeLog = true;
  bool isLoadState = false;
  bool ahPlaylist = false;

  int groupIndex = 0;
  int currTime = 0;
  int currGroup = -1;
  int currEpisode = -1;

  EventFileData eventFile = EventFileData();
  PlaylistZone playlistZone = PlaylistZone();
  PlaylistZone ahPlaylistZone = PlaylistZone();

  DateTime startDateTime = DateTime.now();
  DateTime startEpisodeDateTime = DateTime.now();
  Duration ahAdjust = const Duration(
      days: 0, hours: 0, minutes: 0, seconds: 0, milliseconds: 0);

  int playedDuration = 0;
  AHSchedule? pAHSchedule;

  ScheduleList pSchedule;

  //Ad-hoc schedule item operation
  List<AHSchedule>? oAHSchedules; // AHSchedule Item temporary storage

  PlayList(this.pSchedule) {
    initStatus();
  }

  void initStatus() {
    isPlayEpisode = false;
    isAHPlaying = false;

    currEpisode = -1;
    currTime = -1;
    currGroup = -1;
    groupIndex = 0;

    playedDuration = 0;
    playlistZone.resetPlaylistZone();
    ahPlaylistZone.resetPlaylistZone();

    ahAdjust = const Duration(
        days: 0, hours: 0, minutes: 0, seconds: 0, milliseconds: 0);
    startDateTime = DateTime.now();
    startEpisodeDateTime = DateTime.now();
  }

  PlaylistZone getPlaylistZone([bool? ahPlaying]) {
    if (ahPlaying == null) {
      return isAHPlaying ? ahPlaylistZone : playlistZone;
    } else {
      return ahPlaying ? ahPlaylistZone : playlistZone;
    }
  }

  bool isTimeForPlayNextGroup() {
    if (isPlayEpisode) {
      return false;
    }

    EventItemData? pPlayListData =
        eventFile.getEventItem(getPlaylistZone().getPlayFile);
    if (pPlayListData != null) {
      if (!pPlayListData.isNormalGroupItem()) {
        return false;
      }

      if (isTimeForPlayNormalGroup(pPlayListData)) {
        return false;
      }
    }

    return true;
  }

  bool isTimeForPlay(DateTime dtStart) {
    if (isPlayEpisode) {
      return false;
    }

    DateTime dtStartTime;
    DateTime dtEnd;
    dtStartTime = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        eventFile.dtStart!.hour,
        eventFile.dtStart!.minute,
        eventFile.dtStart!.second);
    Duration dts = eventFile.dtEnd!.difference(eventFile.dtStart!);
    if (dtStartTime
        .subtract(const Duration(days: 1))
        .add(dts)
        .isAfter(startDateTime)) {
      dtStartTime = dtStartTime.subtract(const Duration(days: 1));
    }

    dtEnd = dtStartTime.add(dts);
    /*dtEnd.SetDateTime(dtStart.GetYear(), dtStart.GetMonth(), dtStart.GetDay(),
      dtEnd.GetHour(), dtEnd.GetMinute(), 59);*/
    if (dtEnd.compareTo(startDateTime) <= 0) {
      dtStartTime = dtStartTime.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }

    if (dtStart.compareTo(dtStartTime) >= 0 && dtStart.isBefore(dtEnd)) {
      return true;
    }

    return false;
  }

  ({bool status, int? nFlag}) isTimeForLoadEpisode(DateTime dtStart) {
    if (DCMGlobal.processAHConflict == 0) {
      if (eventFile.bIsTimeSchedule) {
        if (isTimeForPlayEpisode(dtStart)) {
          /*nCurrPlayFile = nPlayFile;
          nKeepCurrPlay = nCurrPlay;
          nCurrProduct = nPlayProduct;
          nPlayProduct = 0;*/
          return (status: true, nFlag: 1);
        }
        if (isTimeForStopEpisode(dtStart)) {
          //bIsAHPlaying = true;
          //bIsStopEpisode = !isTimeForPlayEpisode(dtStart);
          isTimeForPlayEpisode(dtStart);
          /*if (!bIsStopEpisode)
          {
            //nPlayProduct = nCurrProduct;
            nPlayFile = 0;
            nCurrPlay = 0;
            nPlayProduct = 0;
          }*/
          return (status: true, nFlag: 0);
        }
      }
    } else {
      if (eventFile.bIsTimeSchedule) {
        //DateTime dtAHTime;
        //CheckAHSchedule(dtStart, dtAHTime);
        if (isTimeForStopEpisode(dtStart)) {
          logD(
              'CPlayList::IsTimeForLoadEpisode: curr Episode: $currEpisode - curr time range: $currTime; current playlist: $strEvent');
          //bIsStopEpisode = !isTimeForPlayEpisode(dtStart);
          isTimeForPlayEpisode(dtStart);
          return (status: true, nFlag: 0); //bIsStopEpisode ? 0 : 1;
        }
      }
    }

    return (status: false, nFlag: null);
  }

  bool isTimeForLoad() {
    if (swapEvent) {
      swapEvent = false;

      return true;
    }
    return false;
  }

  bool isTimeForEnd(DateTime dtCurr) {
    DateTime dtEnd;
    DateTime dtStart;
    Duration dts = differenceTime(eventFile.dtStart, eventFile.dtEnd);
    dtStart = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        eventFile.dtStart!.hour,
        eventFile.dtStart!.minute,
        eventFile.dtStart!.second);
    DateTime dtTime = dtStart.subtract(const Duration(days: 1)).add(dts);
    if (dtTime.isAfter(startDateTime)) {
      if (dtCurr.isBefore(dtTime)) {
        dtStart = dtStart.subtract(const Duration(days: 1));
      }
    }
    //Duration dts1 = m_dtStartDateTime - dtStart;
    dtEnd = dtStart.add(dts); //m_dtStartDateTime + (dts - dts1);

    if (dtEnd.compareTo(startDateTime) <= 0) {
      dtStart = dtStart.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }

    if (dtEnd.compareTo(dtCurr) <= 0) {
      //return IsReLoadEvent();
      return true;
    }

    return false;
  }

  ({DateTime? dtStart, DateTime? dtEnd}) getPlayRange(DateTime dtCurr) {
    Duration dts = differenceTime(eventFile.dtStart, eventFile.dtEnd);
    var dtStart = DateTime(
        dtCurr.year,
        dtCurr.month,
        dtCurr.day,
        eventFile.dtStart!.hour,
        eventFile.dtStart!.minute,
        eventFile.dtStart!.second);
    //CString dtTime1 = dtStart.Format('%Y/%m/%d %H:%M:%S');
    if (dtStart.subtract(const Duration(days: 1)).add(dts).isAfter(dtCurr)) {
      dtStart = dtStart.subtract(const Duration(days: 1));
    }
    //CString dtTime2 = dtStart.Format('%Y/%m/%d %H:%M:%S');
    var dtEnd = dtStart.add(dts);
    //CString dtTime3 = dtEnd.Format('%Y/%m/%d %H:%M:%S');

    if (dtEnd.compareTo(dtCurr) <= 0) {
      dtStart = dtStart.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }
    //CString dtTime4 = dtStart.Format('%Y/%m/%d %H:%M:%S');
    //CString dtTime5 = dtEnd.Format('%Y/%m/%d %H:%M:%S');
    return (dtStart: dtStart, dtEnd: dtEnd);
  }

  bool isTimeForStop(DateTime dtCurr) {
    if (ahPlaylist) {
      return checkForStopEpisode(dtCurr);
    }

    DateTime dtEnd;
    DateTime dtStart;
    Duration dts = eventFile.dtEnd!.difference(eventFile.dtStart!);
    dtStart = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        eventFile.dtStart!.hour,
        eventFile.dtStart!.minute,
        eventFile.dtStart!.second);
    logD(
        '${eventFile.strScheduleName} CPlayList::IsTimeForStop dtStart: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart)}');
    if (dtStart
        .subtract(const Duration(days: 1))
        .add(dts)
        .isAfter(startDateTime)) {
      dtStart = dtStart.subtract(const Duration(days: 1));
    }
    logD(
        '${eventFile.strScheduleName} CPlayList::IsTimeForStop dtStart: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart)}');

    //Duration dts1 = dtStartDateTime - dtStart;
    dtEnd = dtStart.add(dts); //dtStartDateTime + (dts - dts1);
    logD(
        '${eventFile.strScheduleName} CPlayList::IsTimeForStop dtEnd: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtEnd)}');

    if (dtEnd.compareTo(startDateTime) <= 0) {
      dtStart = dtStart.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }

    if (!pSchedule!.isEndTime(dtCurr)) {
      if (dtEnd.compareTo(dtCurr) <= 0) {
        DateTime dtStartDateTime = dtEnd.add(const Duration(seconds: 1));
        if (isTimeForStart(dtCurr, dtStartDateTime)) {
          return false;
        }

        logD(
            '${eventFile.strScheduleName} CPlayList::IsTimeForStop true dtEnd: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtEnd)}');
        //bWriteLog = true;
        //return IsReLoadEvent();
        return true;
      }
    }

    return false;
  }

  ({bool timeForPlay, DateTime? dtStartTime}) isTimeForStartPlay(
      DateTime dtStart, DateTime dtStartTime) {
    if (ahPlaylist) {
      if (isPlayEpisode) {
        return (timeForPlay: true, dtStartTime: startEpisodeDateTime);
      } else {
        // 检查插播时间表
        var result = checkAHSchedule(dtStart);
        return (
          timeForPlay: result.isPlayEpisode,
          dtStartTime: result.dtStartTime
        );
      }
    } else {
      //DateTime dtStartTime;
      DateTime dtEnd;
      dtStartTime = DateTime(
          startDateTime.year,
          startDateTime.month,
          startDateTime.day,
          eventFile.dtStart!.hour,
          eventFile.dtStart!.minute,
          eventFile.dtStart!.second);
      Duration dts = eventFile.dtEnd!.difference(eventFile.dtStart!);
      logD(
          '${eventFile.strScheduleName} IsTimeForStart dtStartTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStartTime)}');

      DateTime dtTime = dtStartTime.subtract(const Duration(days: 1)).add(dts);
      logD(
          '${eventFile.strScheduleName} IsTimeForStart dtTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtTime)}');
      if (dtTime.isAfter(startDateTime)) {
        if (dtStart.compareTo(dtTime) <= 0) {
          dtStartTime = dtStartTime.subtract(const Duration(days: 1));
        }
      }
      logD(
          '${eventFile.strScheduleName} IsTimeForStart dtStartTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStartTime)}');

      dtEnd = dtStartTime.add(dts);
      logD(
          '${eventFile.strScheduleName} IsTimeForStart dtEnd: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtEnd)}');
      if (dtEnd.compareTo(startDateTime) <= 0) {
        dtStartTime = dtStartTime.add(const Duration(days: 1));
        dtEnd = dtEnd.add(const Duration(days: 1));
      }

      if (dtStart.compareTo(dtStartTime) >= 0 && dtStart.isBefore(dtEnd)) {
        /*int nFlag = -1;
        IsTimeForLoadEpisode(dtStart, nFlag);
        WriteMessage(MSG_INFO, 'CPlayList::IsTimeForStartPlay Curr playlist:%s!!!', strEvent);*/

        return (timeForPlay: true, dtStartTime: dtStartTime);
      } else if (dtStart.compareTo(dtStartTime) >= 0 &&
          dtStart.compareTo(dtEnd) >= 0) {
        if (!pSchedule!.isEndTime(dtStart)) {
          DateTime dtStartDateTime = dtEnd.add(const Duration(seconds: 1));
          if (isTimeForStart(dtStart, dtStartDateTime)) {
            /*int nFlag = -1;
            IsTimeForLoadEpisode(dtStart, nFlag);
            WriteMessage(MSG_INFO, 'CPlayList::IsTimeForStartPlay Curr playlist:%s!!!', strEvent);*/

            return (timeForPlay: true, dtStartTime: dtStartTime);
          }
        }
      }
      return (timeForPlay: false, dtStartTime: null);
    }
  }

  bool isTimeForStart(DateTime dtStart, DateTime dtStartDateTime) {
    DateTime dtStartTime;
    DateTime dtEnd;

    dtStartTime = DateTime(
        dtStartDateTime.year,
        dtStartDateTime.month,
        dtStartDateTime.day,
        eventFile.dtStart!.hour,
        eventFile.dtStart!.minute,
        eventFile.dtStart!.second);
    Duration dts = eventFile.dtEnd!.difference(eventFile.dtStart!);

    DateTime dtTime = dtStartTime.subtract(const Duration(days: 1)).add(dts);
    if (dtTime.isAfter(dtStartDateTime)) {
      if (dtStart.compareTo(dtTime) <= 0) {
        dtStartTime = dtStartTime.subtract(const Duration(days: 1));
      }
    }
    dtEnd = dtStartTime.add(dts);
    if (dtEnd.compareTo(dtStartDateTime) <= 0) {
      dtStartTime = dtStartTime.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }

    if (dtStart.compareTo(dtStartTime) >= 0 && dtStart.isBefore(dtEnd)) {
      isTimeForLoadEpisode(dtStart);

      return true;
    }
    return false;
  }

  bool loadPlayList(
      {String plName = 'dcmplay', String? uniqueName, String? company}) {
    this.company = company ?? '';
    strEvent = plName;
    this.uniqueName = uniqueName ?? plName;

    bool bLoad = true;
    EventFileImpl fileImpl = EventFileImpl();
    if (!fileImpl.loadFromXML(plName, eventFile)) {
      bLoad = fileImpl.loadPlayList(eventFile, plName);
    }
    if (bLoad) {
      genEventDisplayAH();
    }

    return bLoad;
  }

  bool getFirstAHFile(StringBuffer strDCMFile) {
    return validPlayFileList(playlistZone.getPlayFile, strDCMFile);
  }

  bool returnPlayNormalItem(StringBuffer strDCMFile) {
    logD(
        'CPlayList::ReturnPlayNormalItem; Playlist: $strEvent; IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
    playlistZone.dumpPlaylistZone();
    ahPlaylistZone.dumpPlaylistZone();

    isAHPlaying = false;
    int nCurrPlayFile = playlistZone.getPlayFile;
    if (nCurrPlayFile >= eventFile.getCount()) {
      nCurrPlayFile = 0;
      playlistZone.resetPlaylistZone();
    } else {
      //if (g_Global.m_dwLoopMethod == 0)
      if ((DCMGlobal.loopMethod & settingRETURNBRKPTS) == 0) {
        playlistZone.resetPlaylistZone();
        nCurrPlayFile = 0;
      }
    }

    if (validPlayFileList(nCurrPlayFile, strDCMFile)) {
      if (playlistZone.getPlayFile != nCurrPlayFile) {
        playlistZone.resetPlayIndex();
      }

      logD(
          'CPlayList::ReturnPlayNormalItem1; Playlist: $strEvent; IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
      playlistZone.dumpPlaylistZone();
      ahPlaylistZone.dumpPlaylistZone();

      return true;
    }

    logD(
        'CPlayList::ReturnPlayNormalItem2; Playlist: $strEvent; IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
    playlistZone.dumpPlaylistZone();
    ahPlaylistZone.dumpPlaylistZone();

    return false;
  }

  bool startPlayAHItem(StringBuffer strDCMFile) {
    isAHPlaying = true;
    ahPlaylistZone.resetPlaylistZone();
    int nPlayFile = currEpisode;
    if (validPlayFileList(nPlayFile, strDCMFile)) {
      return true;
    }

    return false;
  }

  bool playFileList(StringBuffer dcmFile) {
    playlistZone.resetPlaylistZone();
    ahPlaylistZone.resetPlaylistZone();

    var dtStart = DateTime.now();
    var nPlayFile = 0;

    if (isTimeForPlayEpisode(dtStart)) {
      nPlayFile = currEpisode;
    }

    if (validPlayFileList(nPlayFile, dcmFile)) {
      isAHPlaying = isPlayEpisode;
      getPlaylistZone().setDCMFile(dcmFile.toString());
      return true;
    }

    return false;
  }

  bool validPlayFileList(int nStart, StringBuffer dcmFile) {
    // 验证播放文件列表
    int nPlayFile = -1;
    for (int i = nStart; i < eventFile.getCount(); i++) {
      for (var pPlayListData in eventFile.lstPlayList!) {
        if (pPlayListData.uiID == i) {
          if (validPlayListData(pPlayListData, dcmFile)) {
            nPlayFile = i;
            break;
          }
        }
      }

      if (nPlayFile != -1) break;
    }

    bool bValid = true;
    if (nPlayFile == -1) {
      nPlayFile = 0;
      bValid = false;
    }

    getPlaylistZone(isPlayEpisode).setPlayFile(nPlayFile);
    return bValid;
  }

  bool validPlayListData(EventItemData data, StringBuffer dcmFile) {
    if (!isPlayEpisode) {
      var nCurrPlay = playlistZone.getCurrPlay;
      if (eventFile.isNormalGroupLoop()) {
        if (currGroup != -1 && currGroup != data.uiID && nCurrPlay == 0) {
          writeLog = true;
        }
        if (data.isNormalGroupItem() && isTimeForPlayNormalGroup(data)) {
          // 获取DCM文件
          if (data.getDCMFile(dcmFile, nCurrPlay, company)) {
            playlistZone.setCurrPlay(nCurrPlay);
            playlistZone.setDCMFile(dcmFile.toString());
            playlistZone.setPlayFile(data.uiID);
            currGroup = data.uiID;
            groupIndex = data.uiGroupID;
            return true;
          }
        }
      } else {
        if (!data.bIsTimeSchedule && data.isDCMFileExist(0, company)) {
          dcmFile.write(data.strDCMFile);
          playlistZone.setDCMFile(data.strDCMFile);
          playlistZone.setPlayFile(data.uiID);
          return true;
        }
      }
    } else {
      // 插播逻辑
      if (data.bIsTimeSchedule) {
        var nCurrPlay = ahPlaylistZone.getCurrPlay;

        if (eventFile.nGroupLoop == 0) {
          if (data.bIsGroup) {
            if (data.uiID == currEpisode &&
                data.getDCMFile(dcmFile, nCurrPlay, company)) {
              ahPlaylistZone.setCurrPlay(nCurrPlay);
              ahPlaylistZone.setDCMFile(dcmFile.toString());
              ahPlaylistZone.setPlayFile(data.uiID);
              return true;
            }
          } else {
            if (data.isDCMFileExist(0, company)) {
              dcmFile.write(data.strDCMFile);
              ahPlaylistZone.setDCMFile(data.strDCMFile);
              ahPlaylistZone.setPlayFile(data.uiID);
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  bool isTimeForPlayNormalGroup(EventItemData playListData) {
    var dtStart = DateTime.now();

    var startStr = playListData.dtStart;
    var endStr = playListData.dtEnd;

    if (startStr == '00:00:00' && endStr == '00:00:00') {
      return false;
    }

    var dtAll = getActualDateTime();
    DateTime dtStartTime = stringToTime(startDateTime, startStr, ':');
    DateTime dtEndTime = stringToTime(startDateTime, endStr, ':');
    if (dtEndTime.compareTo(dtStartTime) <= 0) {
      dtEndTime = dtEndTime.add(const Duration(days: 1));
    }
    if (dtStartTime.isBefore(dtAll.key) && dtEndTime.isAfter(dtAll.key)) {
      dtStartTime = dtAll.key;
    }
    if (dtEndTime.isAfter(dtAll.value) && dtStartTime.isBefore(dtAll.value)) {
      dtEndTime = dtAll.value;
    }
    if (dtStart.compareTo(dtStartTime) >= 0 && dtStart.isBefore(dtEndTime)) {
      return true;
    }

    return false; // 需要根据实际逻辑实现
  }

  bool playNextFile(StringBuffer dcmFile) {
    var nCurrPlay = getPlaylistZone(isAHPlaying).getCurrPlay;
    if (!isPlayFileFinished(dcmFile, nCurrPlay)) {
      getPlaylistZone(isAHPlaying).setDCMFile(dcmFile.toString());
      getPlaylistZone(isAHPlaying).setCurrPlay(nCurrPlay);
      return true;
    }

    var nPlayFile = getPlaylistZone(isAHPlaying).getPlayFile;

    nPlayFile++;
    if (eventFile.getCount() <= nPlayFile) {
      if (playFileList(dcmFile)) {
        return true;
      }
    } else {
      if (!validPlayFileList(nPlayFile, dcmFile)) {
        nPlayFile = 0;
        getPlaylistZone(isAHPlaying).resetPlaylistZone();
      }
    }

    if (validPlayFileList(nPlayFile, dcmFile)) {
      getPlaylistZone(isAHPlaying).setDCMFile(dcmFile.toString());
      return true;
    }

    return false;
  }

  bool isPlayFileFinished(StringBuffer dcmFile, int nCurrPlay) {
    if (!isAHPlaying) {
      var nPlayFile = playlistZone.getPlayFile;
      var playListData = eventFile.getEventItem(nPlayFile);

      if (playListData != null) {
        if (playListData.isNormalGroupItem() &&
            isTimeForPlayNormalGroup(playListData)) {
          var finished = playListData.playNextFile(dcmFile, nCurrPlay);

          if (nCurrPlay == -1) {
            writeLog = true;
          }

          return !finished;
        }
      }
    } else {
      var nPlayFile = ahPlaylistZone.getPlayFile;
      var playListData = eventFile.getEventItem(nPlayFile);

      if (playListData != null) {
        if (playListData.bIsTimeSchedule && playListData.bIsGroup) {
          return !playListData.playNextFile(dcmFile, nCurrPlay);
        }
      }
    }

    return true;
  }

  bool playNextGroup(StringBuffer strDCMFile) {
    int nPlayFile = getPlaylistZone(false).getPlayFile;
    if (eventFile.getCount() <= nPlayFile) {
      if (playFileList(strDCMFile)) {
        return true;
      }
    } else {
      if (!validPlayFileList(nPlayFile, strDCMFile)) {
        nPlayFile = 0;
        getPlaylistZone(false).resetPlaylistZone();
      }
    }
    if (validPlayFileList(nPlayFile, strDCMFile)) {
      getPlaylistZone(false).setDCMFile(strDCMFile.toString());

      return true;
    }

    return false;
  }

  bool playCurrFile(StringBuffer strDCMFile) {
    logD(
        'CPlayList::PlayCurrFile first: ${getPlaylistZone(true).getCurrPlay} - ${getPlaylistZone(false).getCurrPlay}');
    int nPlayFile = getPlaylistZone(isPlayEpisode).getPlayFile;
    if (eventFile.getCount() <= nPlayFile) {
      if (playFileList(strDCMFile)) return true;
    } else {
      if ((DCMGlobal.loopMethod & settingRETURNBRKPTS) == 0) {
        getPlaylistZone(isPlayEpisode).resetPlaylistZone();
        nPlayFile = 0;
      }

      if (!validPlayFileList(nPlayFile, strDCMFile)) {
        getPlaylistZone(isPlayEpisode).resetPlaylistZone();
        nPlayFile = 0;
      }
    }

    logD(
        'CPlayList::PlayCurrFile second: ${getPlaylistZone(true).getCurrPlay} - ${getPlaylistZone(false).getCurrPlay}');
    if (validPlayFileList(nPlayFile, strDCMFile)) {
      getPlaylistZone(isPlayEpisode).setDCMFile(strDCMFile.toString());
      isAHPlaying = isPlayEpisode;

      return true;
    }

    return false;
  }

  String getPlayFile() {
    StringBuffer dcmFile = StringBuffer();
    validPlayFileList(0, dcmFile);
    return dcmFile.toString();
  }

  int get count => eventFile.getCount();

  void setPlayTimes([int nPlayTimes = 0]) {
    if (nPlayTimes < 0) {
      getPlaylistZone().setPlayTimes(0);
    } else {
      getPlaylistZone().setPlayTimes();
    }
  }

  bool getPlayTimes() {
    var playListData = eventFile.getEventItem(getPlaylistZone().getPlayFile);
    if (playListData != null) {
      if (playListData.arrDCMFile!.length <= getPlaylistZone().getPlayTimes) {
        getPlaylistZone().setPlayTimes(0);
        return true;
      }
    }
    return false;
  }

  void writePlaylistLog([bool bWriteLog = true]) {
    if (writeLog && !isPlayEpisode && !ahPlaylist) {
      writeLog = false;
      // 记录播放日志
    }
  }

  bool isTimeExpired(DateTime dtCurr, DateTime dtFrom, DateTime dtTo) {
    if (dtCurr.isAfter(dtTo) || comparePlayDateTime(dtCurr, dtTo)) {
      return true;
    }

    if (dtCurr.isBefore(dtFrom)) {
      return true;
    }

    return false;
  }

  bool isDuringPlaybackTime(
      DateTime dtCurr, DateTime dtStartTime, DateTime dtEndTime) {
    if (dtCurr.isBefore(dtStartTime)) {
      return false;
    }

    //if (dtStart >= dtStartTime && dtStart < dtEndTime)
    return (dtCurr
            .add(const Duration(seconds: cPLAYINGDURATION * 2))
            .compareTo(dtEndTime) <=
        0);
  }

  Pair<DateTime, DateTime> getActualDateTime() {
    DateTime dtStart = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        eventFile.dtStart!.hour,
        eventFile.dtStart!.minute,
        eventFile.dtStart!.second);
    var dts = eventFile.dtEnd!.difference(eventFile.dtStart!);
    DateTime dtEnd = dtStart.add(dts);

    return Pair(dtStart, dtEnd);
  }

  void savePlayedDuration(DateTime dtStart) {
    playedDuration = dtStart.difference(startEpisodeDateTime).inSeconds;
  }

  void adjustAHTime(DateTime dtStart) {
    if (DCMGlobal.processAHConflict == 0) {
      if (!isPlayEpisode) {
        return;
      }

      ahAdjust = dtStart.difference(startEpisodeDateTime);
      startEpisodeDateTime = dtStart;
    } else {
      if (isPlayEpisode && pAHSchedule != null) {
        DateTime dtEndTime;
        DateTime dtStartTime;
        if (eventFile.nGroupLoop == 0) {
          if (eventFile.isComplexAH()) {
            EventItemData? pPlayListData =
                eventFile.getEventItem(pAHSchedule!.itemID);
            if (pPlayListData != null) {
              for (int i = 0; i < pPlayListData.arrTimeItems!.length; i++) {
                if (i == pAHSchedule!.uiTimeID) {
                  String strStart = pPlayListData.arrTimeItems![i].dtStart;
                  String strEnd = pPlayListData.arrTimeItems![i].dtEnd;
                  var result = getActualEpisodeDateTime(
                      startEpisodeDateTime, strStart, strEnd, false);
                  if (result.status) {
                    dtStartTime = result.dtStart!;
                    dtEndTime = result.dtEnd!;
                    double dbDuration = 0.00;
                    if (playedDuration > cPLAYINGINTERVAL) {
                      dbDuration = Utils.calcItemDuration(
                          pPlayListData, playedDuration.toDouble());
                    }
                    startEpisodeDateTime = dtStart.subtract(
                        Duration(microseconds: (dbDuration * 1000000).round()));
                    ahAdjust = startEpisodeDateTime.difference(dtStartTime);
                    break;
                  }
                }
              }
            }
          }
        } else {
          EventItemData? pPlayListData =
              eventFile.getEventItem(pAHSchedule!.itemID);
          if (pPlayListData != null) {
            var result = getActualEpisodeDateTime(
                dtStart, pPlayListData.dtStart, pPlayListData.dtEnd, false);
            if (result.status) {
              dtStartTime = result.dtStart!;
              dtEndTime = result.dtEnd!;
              double dbDuration = 0.00;
              if (playedDuration > cPLAYINGINTERVAL) {
                dbDuration = Utils.calcItemDuration(
                    pPlayListData, playedDuration.toDouble());
              }
              startEpisodeDateTime = dtStart.subtract(
                  Duration(milliseconds: (dbDuration * 1000).toInt()));
              ahAdjust = startEpisodeDateTime.difference(dtStartTime);
            }
          }
        }
      }
    }
  }

  ({bool status, DateTime? dtStart, DateTime? dtEnd}) getActualEpisodeDateTime(
      DateTime dtRelative, String strStart, String strEnd,
      [bool bAdjust = true]) {
    if (strStart == '00:00:00' && strEnd == '00:00:00') {
      return (status: false, dtStart: null, dtEnd: null);
    }

    var dtAll = getActualDateTime();
    DateTime dtStart = stringToTime(dtRelative, strStart, ':');
    if (bAdjust) {
      dtStart = dtStart.add(ahAdjust);
    }

    DateTime dtEnd = stringToTime(dtRelative, strEnd, ':');
    if (bAdjust) {
      dtEnd = dtEnd.add(ahAdjust);
    }

    if (dtEnd.compareTo(dtStart) <= 0) {
      dtEnd = dtEnd.add(const Duration(days: 1));
    }
    if (dtStart.isBefore(dtAll.key) && dtEnd.isAfter(dtAll.key)) {
      dtStart = dtAll.key;
    }
    if (dtEnd.isAfter(dtAll.value) && dtStart.isBefore(dtAll.value)) {
      dtEnd = dtAll.value;
    }
    return (status: true, dtStart: dtStart, dtEnd: dtEnd);
  }

  bool playNextPlaylist(StringBuffer strDCMFile) {
    if (!ahPlaylist && isPlayEpisode) {
      if (validPlayFileList(currEpisode, strDCMFile)) {
        isAHPlaying = isPlayEpisode;
        logD(
            'CPlayList::PlayNextPlaylist1; Playlist: $strEvent; isPlayEpisode: $isPlayEpisode - IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
        playlistZone.dumpPlaylistZone();
        ahPlaylistZone.dumpPlaylistZone();

        return true;
      }
    }

    DateTime dtStart = DateTime.now();
    bool bIsTimeForPlayEpisode = isTimeForPlayEpisode(dtStart);
    logD(
        'CPlayList::PlayNextPlaylist1; Playlist: $strEvent; IsTimeForPlayEpisode: $bIsTimeForPlayEpisode - IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
    playlistZone.dumpPlaylistZone();
    ahPlaylistZone.dumpPlaylistZone();
    if (!ahPlaylist) {
      if (bIsTimeForPlayEpisode) {
        ahPlaylistZone.resetPlaylistZone();
      }
    } else {
      ahPlaylistZone.resetPlaylistZone();
    }

    int nPlayFile = getPlaylistZone(bIsTimeForPlayEpisode).getPlayFile;
    if (bIsTimeForPlayEpisode) {
      nPlayFile = currEpisode;
    }
    //bool bPlay = false;
    if (validPlayFileList(nPlayFile, strDCMFile)) {
      if (getPlaylistZone(bIsTimeForPlayEpisode).getPlayFile != nPlayFile) {
        getPlaylistZone(bIsTimeForPlayEpisode).resetPlayIndex();
      }
      getPlaylistZone(bIsTimeForPlayEpisode).setDCMFile(strDCMFile.toString());
      isAHPlaying = isPlayEpisode;
      logD(
          'CPlayList::PlayNextPlaylist2; Playlist: $strEvent; IsTimeForPlayEpisode: $bIsTimeForPlayEpisode - IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
      playlistZone.dumpPlaylistZone();
      ahPlaylistZone.dumpPlaylistZone();

      return true;
    }

    if (validPlayFileList(0, strDCMFile)) {
      getPlaylistZone(bIsTimeForPlayEpisode).resetPlayIndex();
      getPlaylistZone(bIsTimeForPlayEpisode).setDCMFile(strDCMFile.toString());
      isAHPlaying = isPlayEpisode;

      logD(
          'CPlayList::PlayNextPlaylist3; Playlist: $strEvent; IsTimeForPlayEpisode: $bIsTimeForPlayEpisode - IsAHPlaylist:$ahPlaylist; IsPlayingEpisode:$isAHPlaying\n\r');
      playlistZone.dumpPlaylistZone();
      ahPlaylistZone.dumpPlaylistZone();

      return true;
    }

    return false;
  }

  bool isPlayingNormalGroup() {
    EventItemData? pPlayListData =
        eventFile.getEventItem(getPlaylistZone().getPlayFile);
    if (pPlayListData != null) {
      return pPlayListData.isNormalGroupItem();
    }

    return false;
  }

  void playNextProduct(int maxProduct, [bool isPlayEpisode = false]) {
    if (ahPlaylist) return;

    if (!getPlaylistZone(isPlayEpisode).incrementProductIndex(maxProduct)) {
      var nCurrPlay = getPlaylistZone(isPlayEpisode).getCurrPlay;
      var nPlayFile = getPlaylistZone(isPlayEpisode).getPlayFile;

      if (!isPlayEpisode) {
        var playListData = eventFile.getEventItem(nPlayFile);
        if (playListData != null) {
          if (playListData.isNormalGroupItem() &&
              isTimeForPlayNormalGroup(playListData)) {
            StringBuffer dcmFile = StringBuffer();
            if (playListData.playNextFile(dcmFile, nCurrPlay)) {
              getPlaylistZone(isPlayEpisode).setDCMFile(dcmFile.toString());
              getPlaylistZone(isPlayEpisode).setCurrPlay(nCurrPlay);
            }
            if (nCurrPlay == -1) {
              writeLog = true;
            } else {
              return;
            }
          }
        }
      } else {
        var playListData = eventFile.getEventItem(nPlayFile);
        if (playListData != null) {
          if (playListData.bIsTimeSchedule && playListData.bIsGroup) {
            StringBuffer dcmFile = StringBuffer();
            if (playListData.playNextFile(dcmFile, nCurrPlay)) {
              getPlaylistZone(isPlayEpisode).setDCMFile(dcmFile.toString());
              getPlaylistZone(isPlayEpisode).setCurrPlay(nCurrPlay);
              return;
            }
          }
        }
      }
    }
  }

  bool getContentListIndex(int nZone, int nIndex) {
    if (!isAHPlaying) {
      return playlistZone.getContentListIndex(nZone, nIndex);
    } else {
      return ahPlaylistZone.getContentListIndex(nZone, nIndex);
    }
  }

  bool getPlayDuration(int nZone, double dbDuration) {
    if (!isAHPlaying) {
      return playlistZone.getPlayDuration(nZone, dbDuration);
    } else {
      return ahPlaylistZone.getPlayDuration(nZone, dbDuration);
    }
  }

  void setContentListIndex(int nZone, int nIndex, [int nTotal = 0]) {
    if (!isAHPlaying) {
      playlistZone.setContentListIndex(nZone, nIndex, nTotal);
    } else {
      ahPlaylistZone.setContentListIndex(nZone, nIndex, nTotal);
    }
  }

  void incrementContentListIndex(bool bIsAH) {
    getPlaylistZone(bIsAH).incrementContentListIndex();
  }

  void setPlayDuration(int nZone, double dbDuration) {
    if (!isAHPlaying) {
      playlistZone.setPlayDuration(nZone, dbDuration);
    } else {
      ahPlaylistZone.setPlayDuration(nZone, dbDuration);
    }
  }

  void swapPlayList() {
    EventFileImpl fileImpl = EventFileImpl();
    String strDCMFile = strEvent;
    if (controlPlay) {
      strDCMFile = controlEvent;
    }
    if (!fileImpl.loadFromXML(strDCMFile, eventFile)) {
      fileImpl.loadPlayList(eventFile, strDCMFile);
    }
  }

  ({bool isPlayEpisode, DateTime? dtStartTime}) checkAHSchedule(
      DateTime dtStart) {
    //startEpisodeDateTime = dtStart;
    DateTime dtStartTime;
    DateTime dtEndTime;
    if (eventFile.isComplexAH()) {
      for (var pPlayListData in eventFile.lstPlayList!) {
        if (!pPlayListData.bIsTimeSchedule) {
          continue;
        }

        if (pPlayListData.isInsertItem()) {
          var result = getActualEpisodeDateTime(startEpisodeDateTime,
              pPlayListData.dtStart, pPlayListData.dtEnd, false);
          if (result.status) {
            dtStartTime = result.dtStart!;
            dtEndTime = result.dtEnd!;
            if (dtStart.compareTo(dtStartTime) >= 0 &&
                dtStart.isBefore(dtEndTime)) {
              if (addAHSchedule(
                  pPlayListData.uiID, 0, dtStartTime, dtEndTime)) {
                break;
              }
            }
          }
        } else {
          if (pPlayListData.arrDCMFile == null ||
              pPlayListData.arrDCMFile!.isEmpty) {
            continue;
          }

          for (int i = 0; i < pPlayListData.arrTimeItems!.length; i++) {
            String strStart = pPlayListData.arrTimeItems![i].dtStart;
            String strEnd = pPlayListData.arrTimeItems![i].dtEnd;
            var result = getActualEpisodeDateTime(
                startEpisodeDateTime, strStart, strEnd, false);
            if (result.status) {
              dtStartTime = result.dtStart!;
              dtEndTime = result.dtEnd!;
              if (dtStart.compareTo(dtStartTime) >= 0 &&
                  dtStart.isBefore(dtEndTime)) {
                if (!isInAHScheduleList(
                    pPlayListData.uiID, i, dtStartTime, dtEndTime)) {
                  if (pPlayListData.nItemType == EventItemType.rtGroup) {
                    /*IntegrityCheck integrityCheck = IntegrityCheck();
                    if (!integrityCheck.integrityCheckEventItem(pPlayListData)) {
                      continue;
                    }*/
                    continue;
                  }

                  if (addAHSchedule(
                      pPlayListData.uiID, i, dtStartTime, dtEndTime)) {
                    logD(
                        'AHSchedule Item ID:\'${pPlayListData.uiID}\'; ItemType: \'${pPlayListData.nItemType}\' Add to queue successfully');
                    break;
                  }
                }
              }
            }
          }
        }
      }
    } else {
      var result = getActualEpisodeDateTime(startEpisodeDateTime,
          eventFile.strStartTime2, eventFile.strEndTime2, false);
      if (result.status) {
        dtStartTime = result.dtStart!;
        dtEndTime = result.dtEnd!;
        if (dtStart.compareTo(dtStartTime) >= 0 &&
            dtStart.isBefore(dtEndTime)) {
          addAHSchedule(0, 0, dtStartTime, dtEndTime);
        }
      }
    }

    if (pAHSchedule != null) {
      dtStartTime = pAHSchedule!.dtStart;
      return (isPlayEpisode: true, dtStartTime: dtStartTime);
    }

    if (getAHScheduleCount() > 0) {
      AHSchedule pAHSchedule = oAHSchedules!.first;
      dtStartTime = pAHSchedule.dtStart;

      return (isPlayEpisode: true, dtStartTime: dtStartTime);
    }

    return (isPlayEpisode: false, dtStartTime: null);
  }

  bool addAHSchedule(
      int itemID, int uiTimeID, DateTime dtStart, DateTime dtEnd) {
    if (pAHSchedule != null &&
        pAHSchedule!.itemID == itemID &&
        pAHSchedule!.uiTimeID == uiTimeID &&
        pAHSchedule!.dtStart == dtStart &&
        pAHSchedule!.dtEnd == dtEnd) {
      return false;
    }

    var pos = oAHSchedules!.iterator;
    while (pos.moveNext()) {
      AHSchedule pAHSchedule = pos.current;
      if (pAHSchedule.itemID == itemID &&
          pAHSchedule.uiTimeID == uiTimeID &&
          pAHSchedule.dtStart == dtStart &&
          pAHSchedule.dtEnd == dtEnd) {
        return false;
      }
    }

    logD(
        '$itemID AddAHSchedule dtStartTime: ${DateFormat('yyyyMMddHHmmss').format(dtStart)}');

    oAHSchedules?.add(AHSchedule(itemID, uiTimeID, dtStart, dtEnd));

    return true;
  }

  bool isInAHScheduleList(
      int itemID, int uiTimeID, DateTime dtStart, DateTime dtEnd) {
    if (pAHSchedule != null &&
        pAHSchedule!.itemID == itemID &&
        pAHSchedule!.uiTimeID == uiTimeID &&
        pAHSchedule!.dtStart == dtStart &&
        pAHSchedule!.dtEnd == dtEnd) {
      return true;
    }

    var pos = oAHSchedules!.iterator;
    while (pos.moveNext()) {
      AHSchedule pAHSchedule = pos.current;
      if (pAHSchedule.itemID == itemID &&
          pAHSchedule.uiTimeID == uiTimeID &&
          pAHSchedule.dtStart == dtStart &&
          pAHSchedule.dtEnd == dtEnd) {
        return true;
      }
    }

    return false;
  }

  AHSchedule? getAHSchedule() {
    AHSchedule? pAHSchedule;
    if (oAHSchedules != null && oAHSchedules!.isNotEmpty) {
      pAHSchedule = oAHSchedules!.removeAt(0);
    }

    return pAHSchedule;
  }

  int getAHScheduleCount() {
    int nCount = 0;
    if (oAHSchedules != null) {
      nCount = oAHSchedules!.length;
    }

    return nCount;
  }

  bool isTimeForPlayEpisode(DateTime dtStart) {
    if (DCMGlobal.processAHConflict == 1) {
      checkAHSchedule(dtStart);
    }

    if (isPlayEpisode) {
      return false;
    }

    if (DCMGlobal.processAHConflict == 0) {
      //startEpisodeDateTime = dtStart;
      DateTime dtStartTime;
      DateTime dtEndTime;
      if (eventFile.nGroupLoop == 0) {
        if (eventFile.isComplexAH()) {
          for (var pPlayListData in eventFile.lstPlayList!) {
            if (pPlayListData.bIsTimeSchedule &&
                pPlayListData.arrTimeItems != null) {
              for (int i = 0; i < pPlayListData.arrTimeItems!.length; i++) {
                String strStart = pPlayListData.arrTimeItems![i].dtStart;
                String strEnd = pPlayListData.arrTimeItems![i].dtEnd;
                var result =
                    getActualEpisodeDateTime(dtStart, strStart, strEnd, false);
                if (result.status) {
                  dtStartTime = result.dtStart!;
                  dtEndTime = result.dtEnd!;
                  //if (dtStart >= dtStartTime && dtStart < dtEndTime)
                  if (isDuringPlaybackTime(dtStart, dtStartTime, dtEndTime)) {
                    startEpisodeDateTime = dtStartTime;
                    currTime = i;
                    currEpisode = pPlayListData.uiID;
                    isPlayEpisode = true;
                    //AddAHSchedule(currEpisode, currTime, dtStartTime, dtEndTime);
                    //ahAdjust = DateTimeSpan(0.00);
                    return true;
                  }
                }
              }
            }
          }
        } else {
          var result = getActualEpisodeDateTime(
              dtStart, eventFile.strStartTime2, eventFile.strEndTime2, false);
          if (result.status) {
            dtStartTime = result.dtStart!;
            dtEndTime = result.dtEnd!;
            //if (dtStart >= dtStartTime && dtStart < dtEndTime)
            if (isDuringPlaybackTime(dtStart, dtStartTime, dtEndTime)) {
              startEpisodeDateTime = dtStartTime;
              isPlayEpisode = true;
              //AddAHSchedule(0, 0, dtStartTime, dtEndTime);
              //ahAdjust = DateTimeSpan(0.00);
              return true;
            }
          }
        }
      } else {
        for (var pPlayListData in eventFile.lstPlayList!) {
          if (pPlayListData.bIsTimeSchedule) {
            var result = getActualEpisodeDateTime(startEpisodeDateTime,
                pPlayListData.dtStart, pPlayListData.dtEnd, false);
            if (result.status) {
              dtStartTime = result.dtStart!;
              dtEndTime = result.dtEnd!;
              //if (dtStart >= dtStartTime && dtStart < dtEndTime)
              if (isDuringPlaybackTime(dtStart, dtStartTime, dtEndTime)) {
                startEpisodeDateTime = dtStartTime;
                currEpisode = pPlayListData.uiID;
                isPlayEpisode = true;
                //AddAHSchedule(currEpisode, 0, dtStartTime, dtEndTime);
                //ahAdjust = DateTimeSpan(0.00);
                return true;
              }
            }
          }
        }
      }
    } else {
      //AHSchedule pAHSchedule = getAHSchedule();
      pAHSchedule = getAHSchedule();
      if (pAHSchedule == null) {
        return false;
      }

      logD(
          '${pAHSchedule!.itemID} IsTimeForPlayEpisode dtStartTime: ${DateFormat('yyyyMMddHHmmss').format(pAHSchedule!.dtStart)}');

      DateTime dtEndTime;
      DateTime dtStartTime;
      bool bExisted = false;
      if (eventFile.isComplexAH()) {
        EventItemData? pPlayListData =
            eventFile.getEventItem(pAHSchedule!.itemID);
        if (pPlayListData != null) {
          if (pPlayListData.isInsertItem()) {
            var result = getActualEpisodeDateTime(startEpisodeDateTime,
                pPlayListData.dtStart, pPlayListData.dtEnd, false);
            if (result.status) {
              dtStartTime = result.dtStart!;
              dtEndTime = result.dtEnd!;
              ahAdjust = dtStart.difference(dtStartTime);
              startEpisodeDateTime = dtStart;
              currEpisode = pPlayListData.uiID;
              isPlayEpisode = true;
            }
          } else {
            for (int i = 0; i < pPlayListData.arrTimeItems!.length; i++) {
              if (i == pAHSchedule!.uiTimeID) {
                //startEpisodeDateTime = pAHSchedule!.dtStart;
                //AdjustAHTime(dtStart);
                String strStart = pPlayListData.arrTimeItems![i].dtStart;
                String strEnd = pPlayListData.arrTimeItems![i].dtEnd;
                var result = getActualEpisodeDateTime(
                    startEpisodeDateTime, strStart, strEnd, false);
                if (result.status) {
                  dtStartTime = result.dtStart!;
                  dtEndTime = result.dtEnd!;
                  ahAdjust =
                      dtStart.difference(dtStartTime); //pAHSchedule!.dtStart
                  //SAFE_DELETE(pAHSchedule);
                  startEpisodeDateTime = dtStart;
                  currTime = i;
                  currEpisode = pPlayListData.uiID;
                  isPlayEpisode = true;
                  break;
                }
              }
            }
          }
        }
      } else {
        var result = getActualEpisodeDateTime(startEpisodeDateTime,
            eventFile.strStartTime2, eventFile.strEndTime2, false);
        if (result.status) {
          dtStartTime = result.dtStart!;
          dtEndTime = result.dtEnd!;

          ahAdjust = dtStart.difference(dtStartTime);
          startEpisodeDateTime = dtStart;
          isPlayEpisode = true;
        }
      }
    }

    return isPlayEpisode;
  }

  bool isTimeForStopEpisode(DateTime dtStart) {
    if (!isPlayEpisode) {
      return false;
    }

    logD('CPlayList::IsTimeForStopEpisode second: $currEpisode - $currTime');
    if (!eventFile.bIsTimeSchedule) {
      resetEpisodeStatus();

      return true;
    }

    if (DCMGlobal.processAHConflict == 0) {
      DateTime dtEndTime;
      DateTime dtStartTime;
      bool bExisted = false;
      if (eventFile.nGroupLoop == 0) {
        if (eventFile.isComplexAH()) {
          EventItemData? pPlayListData = eventFile.getEventItem(currEpisode);
          if (pPlayListData != null) {
            bExisted = true;
            if (currTime != -1) {
              if (currTime >= pPlayListData.arrTimeItems!.length) {
                resetEpisodeStatus();

                return true;
              }
              String strStart = pPlayListData.arrTimeItems![currTime].dtStart;
              String strEnd = pPlayListData.arrTimeItems![currTime].dtEnd;
              var result = getActualEpisodeDateTime(
                  startEpisodeDateTime, strStart, strEnd, false);
              if (result.status) {
                dtStartTime = result.dtStart!;
                dtEndTime = result.dtEnd!;
                if (isPlayEpisode) {
                  if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                    resetEpisodeStatus();

                    return true;
                  }
                }
              }
            }
          }
        } else {
          bExisted = true;
          var result = getActualEpisodeDateTime(startEpisodeDateTime,
              eventFile.strStartTime2, eventFile.strEndTime2, false);
          if (result.status) {
            dtStartTime = result.dtStart!;
            dtEndTime = result.dtEnd!;
            if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
              resetEpisodeStatus();

              return true;
            }
          }
        }
      } else {
        EventItemData? pPlayListData = eventFile.getEventItem(currEpisode);
        if (pPlayListData != null) {
          bExisted = true;
          var result = getActualEpisodeDateTime(startEpisodeDateTime,
              pPlayListData.dtStart, pPlayListData.dtEnd, false);
          if (result.status) {
            dtStartTime = result.dtStart!;
            dtEndTime = result.dtEnd!;
            if (isPlayEpisode) {
              if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                resetEpisodeStatus();

                return true;
              }
            }
          }
        }
      }
      if (!bExisted) {
        resetEpisodeStatus();

        return true;
      }
    } else {
      if (pAHSchedule == null) {
        return false;
      }

      DateTime dtEndTime;
      DateTime dtStartTime;
      bool bExisted = false;
      if (eventFile.isComplexAH()) {
        EventItemData? pPlayListData =
            eventFile.getEventItem(pAHSchedule!.itemID);
        if (pPlayListData != null) {
          bExisted = true;
          if (pPlayListData.isInsertItem()) {
            var result = getActualEpisodeDateTime(startEpisodeDateTime,
                pPlayListData.dtStart, pPlayListData.dtEnd);
            if (result.status) {
              dtStartTime = result.dtStart!;
              dtEndTime = result.dtEnd!;
              if (isPlayEpisode) {
                if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                  resetEpisodeStatus();

                  return true;
                }
              }
            }
          } else {
            if (pAHSchedule!.uiTimeID != -1) {
              if (pAHSchedule!.uiTimeID >= pPlayListData.arrTimeItems!.length) {
                resetEpisodeStatus();

                return true;
              }
              String strStart =
                  pPlayListData.arrTimeItems![pAHSchedule!.uiTimeID].dtStart;
              String strEnd =
                  pPlayListData.arrTimeItems![pAHSchedule!.uiTimeID].dtEnd;
              var result = getActualEpisodeDateTime(
                  startEpisodeDateTime, strStart, strEnd);
              if (result.status) {
                dtStartTime = result.dtStart!;
                dtEndTime = result.dtEnd!;
                if (isPlayEpisode) {
                  if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                    resetEpisodeStatus();

                    return true;
                  }
                }
              }
            }
          }
        }
      } else {
        bExisted = true;
        var result = getActualEpisodeDateTime(startEpisodeDateTime,
            eventFile.strStartTime2, eventFile.strEndTime2);
        if (result.status) {
          dtStartTime = result.dtStart!;
          dtEndTime = result.dtEnd!;
          if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
            resetEpisodeStatus();

            return true;
          }
        }
      }

      if (!bExisted) {
        resetEpisodeStatus();

        return true;
      }
    }

    return false;
  }

  void resetEpisodeStatus() {
    currEpisode = -1;
    currTime = -1;
    isPlayEpisode = false;
    isAHPlaying = false;
    ahAdjust = const Duration();
    playedDuration = 0;
    pAHSchedule = null;
    ahPlaylistZone.resetPlaylistZone();
  }

  bool checkForStopEpisode(DateTime dtStart) {
    if (!isPlayEpisode) {
      return true;
    }

    if (!eventFile.bIsTimeSchedule) {
      return true;
    }

    if (DCMGlobal.processAHConflict == 0) {
      DateTime dtEndTime;
      DateTime dtStartTime;
      bool bExisted = false;
      if (eventFile.nGroupLoop == 0) {
        if (eventFile.isComplexAH()) {
          EventItemData? pPlayListData = eventFile.getEventItem(currEpisode);
          if (pPlayListData != null) {
            bExisted = true;
            if (currTime != -1) {
              if (currTime >= pPlayListData.arrTimeItems!.length) {
                return true;
              }
              String strStart = pPlayListData.arrTimeItems![currTime].dtStart;
              String strEnd = pPlayListData.arrTimeItems![currTime].dtEnd;
              var result = getActualEpisodeDateTime(
                  startEpisodeDateTime, strStart, strEnd, false);
              if (result.status) {
                dtStartTime = result.dtStart!;
                dtEndTime = result.dtEnd!;
                if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                  return true;
                }
              }
            }
          }
        } else {
          bExisted = true;
          var result = getActualEpisodeDateTime(startEpisodeDateTime,
              eventFile.strStartTime2, eventFile.strEndTime2, false);
          if (result.status) {
            dtStartTime = result.dtStart!;
            dtEndTime = result.dtEnd!;
            if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
              return true;
            }
          }
        }
      } else {
        EventItemData? pPlayListData = eventFile.getEventItem(currEpisode);
        if (pPlayListData != null) {
          bExisted = true;
          var result = getActualEpisodeDateTime(startEpisodeDateTime,
              pPlayListData.dtStart, pPlayListData.dtEnd, false);
          if (result.status) {
            dtStartTime = result.dtStart!;
            dtEndTime = result.dtEnd!;
            if (isPlayEpisode) {
              if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                return true;
              }
            }
          }
        }
      }
      if (!bExisted) {
        return true;
      }
    } else {
      if (pAHSchedule == null) {
        return true;
      }

      DateTime dtEndTime;
      DateTime dtStartTime;
      bool bExisted = false;
      if (eventFile.isComplexAH()) {
        EventItemData? pPlayListData =
            eventFile.getEventItem(pAHSchedule!.itemID);
        if (pPlayListData != null) {
          bExisted = true;
          if (pPlayListData.isInsertItem()) {
            if (pAHSchedule!.uiTimeID != -1) {
              if (pAHSchedule!.uiTimeID >= pPlayListData.arrTimeItems!.length) {
                return (getAHScheduleCount() == 0);
              }
              String strStart =
                  pPlayListData.arrTimeItems![pAHSchedule!.uiTimeID].dtStart;
              String strEnd =
                  pPlayListData.arrTimeItems![pAHSchedule!.uiTimeID].dtEnd;
              var result = getActualEpisodeDateTime(
                  startEpisodeDateTime, strStart, strEnd);
              if (result.status) {
                dtStartTime = result.dtStart!;
                dtEndTime = result.dtEnd!;
                if (isPlayEpisode) {
                  if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                    return (getAHScheduleCount() == 0);
                  }
                }
              }
            }
          } else {
            var result = getActualEpisodeDateTime(startEpisodeDateTime,
                pPlayListData.dtStart, pPlayListData.dtEnd);
            if (result.status) {
              dtStartTime = result.dtStart!;
              dtEndTime = result.dtEnd!;
              if (isPlayEpisode) {
                if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
                  return (getAHScheduleCount() == 0);
                }
              }
            }
          }
        }
      } else {
        bExisted = true;
        var result = getActualEpisodeDateTime(startEpisodeDateTime,
            eventFile.strStartTime2, eventFile.strEndTime2);
        if (result.status) {
          dtStartTime = result.dtStart!;
          dtEndTime = result.dtEnd!;
          if (isTimeExpired(dtStart, dtStartTime, dtEndTime)) {
            return (getAHScheduleCount() == 0);
          }
        }
      }

      if (!bExisted) {
        return (getAHScheduleCount() == 0);
      }
    }

    return false;
  }

  void changeTVChannel(int nNewChannel) {
    if (eventFile.lstPlayList != null) {
      for (var pPlayListData in eventFile.lstPlayList!) {
        if (pPlayListData.arrDCMFile!.isNotEmpty) {
          for (int i = 0; i < pPlayListData.arrDCMFile!.length; i++) {
            changeTVChannelForDCMFile(
                pPlayListData.arrDCMFile![i], nNewChannel);
          }
        } else {
          changeTVChannelForDCMFile(pPlayListData.strDCMFile, nNewChannel);
        }
      }
    }
  }

  void changeTVChannelForDCMFile(String strDCMFile, int nNewChannel) {
    String strEdit = path.join(DCMGlobal.openPath, '$strDCMFile.dcm'); //szDir;
    if (File(strEdit).existsSync()) {
      bool bFileChanged = false;
      DCMFileData? dcmFileData = DCMFileImpl.openCatalogue(szEdit: strEdit);
      if (dcmFileData != null) {
        int nOldChannel = -1;
        int nProduct = dcmFileData.nQuantity;
        for (int i = 0; i < nProduct; i++) {
          ProductData? pData = dcmFileData.getProductDataByIndex(i);
          if (pData != null) {
            for (var pZoneData in pData.lstZone) {
              if (cTVCAPTURETYPE == pZoneData.nZoneType) {
                nOldChannel = pZoneData.getTVChannel();
                if (nNewChannel != nOldChannel) {
                  int nChannelCount = pZoneData.getChannelCount();
                  for (int nChannel = 0; nChannel < nChannelCount; nChannel++) {
                    if (nNewChannel == pZoneData.getChannel(nChannel)) {
                      pZoneData.setTVChannel(nNewChannel);
                      pZoneData.strZoneFile =
                          pZoneData.getChannelName(nChannel);
                      bFileChanged = true;
                      break;
                    }
                  }
                }
              }
            }
          }
        }

        if (bFileChanged) {
          DCMFileImpl.saveCatalogue(dcmFileData, strDCMFile);
          logD(
              'ChangeTVChannelForDCMFile - Catalogue: \'$strDCMFile\' changed, original channel: \'$nOldChannel\', nNewChannel: \'$nNewChannel\'.');
        } else {
          logD(
              'ChangeTVChannelForDCMFile - Catalogue: \'$strDCMFile\' not change, original channel: \'$nOldChannel\', nNewChannel: \'$nNewChannel\'.');
        }
      } else {
        logD(
            'ChangeTVChannelForDCMFile - Open catalogue: \'$strDCMFile\' failed, nNewChannel: \'$nNewChannel\'.');
      }
    } else {
      logD(
          'ChangeTVChannelForDCMFile - Catalogue: \'$strDCMFile\' not found, nNewChannel: \'$nNewChannel\'.');
    }
  }

  void genEventDisplayAH({String? strDCMFile}) {
    if (strDCMFile == null || strDCMFile.isEmpty) {
      if (eventFile.bIsTimeSchedule && eventFile.nGroupLoop == 2) {
        logD(
            'GenEventDisplayAH for playlist: \'${eventFile.strScheduleName}\', nGroupLoop: \'${eventFile.nGroupLoop}\'.');
        EventItemData? pPlayListData;
        for (pPlayListData in eventFile.lstPlayList!) {
          if (pPlayListData.nItemType == EventItemType.eventDisplay) {
            break;
          }
        }
        if (pPlayListData != null) {
          eventFile.lstPlayList!.remove(pPlayListData);
          if (pPlayListData.strDCMFile.isNotEmpty) {
            genEventDisplayAH(strDCMFile: pPlayListData.strDCMFile);
          }
        }
      }
    } else {
      String strEdit = path.join(DCMGlobal.openPath, '$strDCMFile.dcm');
      if (File(strEdit).existsSync()) {
        DCMFileData? dcmFileData = DCMFileImpl.openCatalogue(szEdit: strEdit);
        if (dcmFileData != null) {
          int nProduct = dcmFileData.nQuantity;
          for (int i = 0; i < nProduct; i++) {
            ProductData? pData = dcmFileData.getProductDataByIndex(i);
            if (pData != null) {
              for (var pZoneData in pData.lstZone) {
                if (cEVENTTYPE == pZoneData.nZoneType) {
                  String strLobby = pZoneData.strZoneFile.substring(0, 5);
                  if (strLobby.toLowerCase() == 'lobby') {
                    genLobbyEventDisplayAH(strDCMFile);
                  } else {
                    genRoomEventDisplayAH(
                        strDCMFile, int.tryParse(pZoneData.strZoneFile) ?? 0);
                  }
                }
              }
            }
          }
        } else {
          logD('GenEventDisplayAH - Open catalogue: \'$strDCMFile\' failed.');
        }
      } else {
        logD('GenEventDisplayAH - Catalogue: \'$strDCMFile\' not found.');
      }
    }
  }

  void genLobbyEventDisplayAH(String strDCMFile) {
    EventDateFile eventDate = EventDateFile();
    if (eventDate.loadFile(mode: XfOpen.read)) {
      eventDate.sortEventByLobbyTime();
      XmlItem? hEventItem = eventDate.getFirstEventItem();
      int i = 1;
      if (hEventItem != null) {
        EventItemData? pEventItem = EventItemData();
        pEventItem.initEventDisplayItem(i, strDCMFile);
        String dtStart;
        String dtEnd;
        while (hEventItem != null) {
          var result = eventDate.getLobbyTimeRange(hEventItem);
          if (result.status) {
            dtStart = result.timeFrom!;
            dtEnd = result.timeTo!;
            if (pEventItem!.dtStart == '00:00:00' &&
                pEventItem.dtEnd == '00:00:00') {
              pEventItem.dtStart = dtStart;
              pEventItem.dtEnd = dtEnd;
            } else {
              if (dtStart.compareTo(pEventItem.dtEnd) >= 0) {
                if (eventFile.lstPlayList!.contains(pEventItem)) {
                  logD(
                      'GenLobbyEventDisplayAH - Catalogue: \'$strDCMFile\', start time: \'${pEventItem.dtStart}\', end time: \'${pEventItem.dtEnd}\', seq: \'$i\'.');
                  eventFile.lstPlayList!.add(pEventItem);
                }
                i++;

                pEventItem = EventItemData();
                pEventItem.initEventDisplayItem(i, strDCMFile,
                    dtStart: dtStart, dtEnd: dtEnd);
              } else {
                if (dtEnd.compareTo(pEventItem.dtEnd) > 0) {
                  pEventItem.dtEnd = dtEnd;
                }
              }
            }
          }

          hEventItem = eventDate.getNextEventItem(hEventItem);
        }

        if (pEventItem != null && eventFile.lstPlayList!.contains(pEventItem)) {
          if (pEventItem.dtStart == '00:00:00' &&
              pEventItem.dtEnd == '00:00:00') {
            pEventItem = null;
          } else {
            logD(
                'GenLobbyEventDisplayAH - Catalogue: \'$strDCMFile\', start time: \'${pEventItem.dtStart}\', end time: \'${pEventItem.dtEnd}\', seq: \'$i\'.');
            eventFile.lstPlayList!.add(pEventItem);
          }
        }
      } else {
        logD(
            'GenLobbyEventDisplayAH - no item found in lobby file: \'${eventDate.getFilePath()}\' failed.');
      }
    } else {
      logD(
          'GenLobbyEventDisplayAH - Load lobby file: \'${eventDate.getFilePath()}\' failed.');
    }
  }

  /*bool compare_SectionContent (const CSectionContentData * first, const CSectionContentData * second)
  {
    return ( first.dtStartTime1.Compare(second.dtStartTime1) < 0);
  }*/

  void genRoomEventDisplayAH(String strDCMFile, int nRoomIndex) {
    RoomDateFile roomDate = RoomDateFile();
    if (roomDate.loadFile(ignoreDefaultXml: true)) {
      var result = roomDate.getSectionListByRoomIndex(nRoomIndex);
      logD(
          'Load XML success!!!, Room: \'$nRoomIndex\', lstSectionContent size: \'${result.lstSectionContent?.length}\'');
      result.lstSectionContent?.sort(
          (first, second) => first.startTime1.compareTo(second.startTime1));
      int i = 1;
      for (var pContentData in result.lstSectionContent!) {
        String strTimeFrom = pContentData.startTime1;
        String strTimeTo = pContentData.endTime1;
        if (strTimeFrom.isEmpty && strTimeTo.isEmpty) {
          continue;
        }

        if (strTimeFrom.isEmpty) {
          strTimeFrom = '00:00:00';
        }

        if (strTimeTo.isEmpty) {
          strTimeTo = '23:59:59';
        }

        if (strTimeFrom == '00:00:00' && strTimeTo == '00:00:00') {
          strTimeTo = '23:59:59';
        }

        EventItemData pEventItem = EventItemData();
        pEventItem.initEventDisplayItem(i, strDCMFile,
            dtStart: strTimeFrom, dtEnd: strTimeTo);
        logD(
            'GenRoomEventDisplayAH - Catalogue: \'$strDCMFile\', start time: \'${pEventItem.dtStart}\', end time: \'${pEventItem.dtEnd}\', seq: \'$i\'.');
        eventFile.lstPlayList!.add(pEventItem);
        i++;
      }
    } else {
      logD(
          'GenRoomEventDisplayAH - Load room event file: \'${roomDate.getFilePath()}\' failed.');
    }
  }
}
