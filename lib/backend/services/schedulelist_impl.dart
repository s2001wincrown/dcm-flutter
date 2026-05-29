// schedule_list.dart
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/ah_playlist_impl.dart';
import 'package:dcm/backend/services/channel_schedule_impl.dart';
import 'package:dcm/backend/services/content_imp_instance.dart';
import 'package:dcm/backend/services/integrity_check.dart';
import 'package:dcm/backend/services/playlist_impl.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/xml_settings/eventfile_impl.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

class ScheduleList {
  static const int cMaxDefaEventForPlay = 1;
  String month = '';
  String currEvent = '';
  String channel = '';
  String controlEvent = '';
  String dcmFile = '';

  bool deviceControl = false;
  bool controlPlay = false;
  bool swapEvent = false;

  DateTime? scheduleStart; // Play start time
  DateTime? scheduleEnd; // Play end time

  int playListIndex = 0;
  int currPlayList = 0;
  int currTime = 0;
  int currPlay = -1; // Current Play DCM File in Group Loop
  int playProduct = 0;

  List<Pair<String, String>> arrEvent = [];
  List<PlayList> lstScheduleList = [];
  AHPlayList messageList = AHPlayList();
  DCMFileData catalogue = DCMFileData();

  static Object scheduleLock = Object(); // Dart中可以使用其他同步机制

  int currEpisode = -1;
  int day = 0;
  int playMeth = 0;

  DateTime startDateTime = DateTime.now();

  static final ScheduleList _instance = ScheduleList._internal();
  factory ScheduleList() => _instance;
  ScheduleList._internal() {
    var now = DateTime.now();
    startDateTime = now;
    day = now.day;
    month = '${now.year}${now.month.toString().padLeft(2, '0')}';
  }

  void removeScheduleList() {
    lstScheduleList.clear();
    arrEvent.clear();
  }

  bool loadCatalogue(String? fileName, [DCMFileData? pDCMFileData]) {
    var target = pDCMFileData ?? catalogue;

    if (fileName != null) {
      // 实现加载catalogue逻辑
      return true;
    }

    return false;
  }

  bool loadCatalogueDirect(String? fileName) {
    if (currEvent == 'StartupWallpaper' && fileName != null) {
      // 启动壁纸特殊处理
      catalogue.strCatalogueName = 'StartupWallpaper';
      catalogue.nQuantity = 1;
      catalogue.strLayoutName = 'H01';
      catalogue.nSkin = 1;
      catalogue.strSkinCode = 'No Frame and No Button';
      return true;
    }

    var strDCMFile = fileName ?? '';
    if (strDCMFile.isEmpty && arrEvent.isNotEmpty) {
      var pPlaylist = getCurrPlaylist();
      if (pPlaylist != null) {
        strDCMFile = pPlaylist.getPlaylistZone().getDCMFile;
      }
    }

    try {
      catalogue = DCMFileData(); // 初始化
      // 实现具体的加载逻辑
    } catch (e) {
      // 添加默认内容
    }

    return true;
  }

  ProductData? getNextProduct() {
    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.getPlaylistZone().incrementProductIndex(getTotalProducts());
      return catalogue
          .getProductDataByIndex(pPlaylist.getPlaylistZone().getPlayProduct);
    }
    return null;
  }

  bool reachLastProduct() {
    if (arrEvent.isEmpty) {
      return getTotalProducts() <= playProduct + 1;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      return getTotalProducts() <=
          pPlaylist.getPlaylistZone().getPlayProduct + 1;
    }

    return true;
  }

  void playNextProduct([bool bIsPlayEpisode = false]) {
    if (arrEvent.isEmpty) {
      if (getTotalProducts() <= playProduct + 1) {
        playProduct = 0;
      } else {
        playProduct++;
      }
      return;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.playNextProduct(getTotalProducts(), bIsPlayEpisode);
    }
  }

  void setProductIndex([int nProduct = -1]) {
    if (arrEvent.isEmpty) {
      if (nProduct < 0) {
        playProduct++;
      } else {
        playProduct = nProduct;
      }
      return;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      if (nProduct < 0) {
        pPlaylist.getPlaylistZone().incrementProductIndex(getTotalProducts());
      } else {
        pPlaylist.getPlaylistZone().setPlayProduct(nProduct);
      }
    }
  }

  bool loadSchedule({String? playList, bool displayChanged = false}) {
    if (playList != null) {
      currEvent = playList;

      removeScheduleList();

      if (currEvent == 'StartupWallpaper') {
        var pList = PlayList();
        if (pList.loadPlayList(uniqueName: 'StartupWallpaper')) {
          arrEvent.add(const Pair('StartupWallpaper', 'StartupWallpaper'));
          pList.startDateTime = startDateTime;
          lstScheduleList.add(pList);
        }
      } else {
        createPlayList(playList);
      }

      getPlayRange();

      return true;
    } else {
      if ((currEvent.isNotEmpty && currEvent != 'StartupWallpaper') ||
          (displayChanged && currEvent == 'StartupWallpaper')) {
        return loadSchedule(playList: currEvent);
      }

      currEvent = '';

      var strCurrEvent = '';
      if (arrEvent.isNotEmpty) {
        strCurrEvent = arrEvent[playListIndex].value;
      }

      removeScheduleList();

      bool bLoad = false;
      ChannelScheduleImpl scheduleImpl = ChannelScheduleImpl();
      List<DayInfoData> lstDayInfo =
          scheduleImpl.loadSchedule(channel, scheduleMonth: month);
      logD('CScheduleList::LoadSchedule: $channel - $month');
      if (lstDayInfo.isNotEmpty) {
        for (var pDayInfoData in lstDayInfo) {
          if (pDayInfoData.day == day) {
            logD('CScheduleList::LoadSchedule:$month - $day');
            playMeth = pDayInfoData.playMeth;
            if (pDayInfoData.arrEvent.isEmpty) {
              logD(
                  'CScheduleList::LoadSchedule: Current Playlist: ${pDayInfoData.event} - Orign Playlist: $strCurrEvent');
              PlayList? pList = createPlayList(pDayInfoData.event);
              if (pList != null) {
                bLoad = (!strCurrEvent.equalsIgnoreCase(pDayInfoData.event));
              }
            } else {
              bLoad = true;
              if (playMeth == SchedulePlayMeth.eCROSSPLAYLIST.index) {
                for (int i = 0; i < pDayInfoData.arrEvent.length; i++) {
                  PlayList? pList = createPlayList(
                      pDayInfoData.arrEvent[i].value,
                      pDayInfoData.arrEvent[i].key,
                      pDayInfoData.arrEvent[i].key);
                  if (pList != null &&
                      strCurrEvent
                          .equalsIgnoreCase(pDayInfoData.arrEvent[i].value)) {
                    bLoad = false;
                  }
                }
              } else if (playMeth ==
                  SchedulePlayMeth.ePEROUTPUTPLAYLIST.index) {
                logD('Load Schedule1 $pid');
                try {
                  for (int i = 0; i < pDayInfoData.arrEvent.length; i++) {
                    if (int.tryParse(pDayInfoData.arrEvent[i].key) ==
                        DCMGlobal.output) {
                      PlayList? pList = createPlayList(
                          pDayInfoData.arrEvent[i].value,
                          pDayInfoData.arrEvent[i].key);
                      if (pList != null &&
                          strCurrEvent.equalsIgnoreCase(
                              pDayInfoData.arrEvent[i].value)) {
                        bLoad = false;
                      }
                    }
                  }
                } catch (e) {
                  logE('Load Playlist error: $e, pid: $pid.');
                }
              } else if (playMeth == SchedulePlayMeth.eSEQUENCEPLAYLIST.index) {
                for (int i = 0; i < pDayInfoData.arrEvent.length; i++) {
                  PlayList? pList = createPlayList(
                      pDayInfoData.arrEvent[i].value,
                      pDayInfoData.arrEvent[i].key);
                  if (pList != null &&
                      strCurrEvent
                          .equalsIgnoreCase(pDayInfoData.arrEvent[i].value)) {
                    bLoad = false;
                  }
                }
              } else if (playMeth == SchedulePlayMeth.eAHPLAYLIST.index) {
                IntegrityCheck integrityCheck = IntegrityCheck();
                int nAHEvent = 0;
                bool bReimport = false;
                for (int i = 0; i < pDayInfoData.arrEvent.length; i++) {
                  String strAHEvent = pDayInfoData.arrEvent[i].value;
                  if (i == 0) {
                    if (!integrityCheck.integrityCheckPlaylist(strAHEvent)) {
                      bReimport = true;
                      strAHEvent =
                          getDefaPlaylistIntegrityCheck(integrityCheck);
                      if (strAHEvent.isEmpty) {
                        break;
                      }
                    }
                  } else {
                    if (!integrityCheck.integrityCheckPlaylist(strAHEvent)) {
                      bReimport = true;
                      continue;
                    }
                  }

                  PlayList? pList = createPlayList(strAHEvent, '$nAHEvent');
                  if (pList != null) {
                    pList.ahPlaylist = (i != 0);
                    if (strCurrEvent.equalsIgnoreCase(strAHEvent)) {
                      bLoad = false;
                    }
                    nAHEvent++;
                  }
                }

                if (bReimport) {
                  ContentImpInstance.reimportTaskCheck();
                }
              }
            }

            if ((DCMGlobal.loopMethod & settingLATESTPLAYLIST) > 0) {
              ChannelScheduleImpl.changeToLatestPlaylist(pDayInfoData);
            }

            break;
          }
        }
      }

      bool bExisted = arrEvent.isNotEmpty;
      if (!bExisted) {
        String strDefaEvent =
            path.join(DCMGlobal.settingPath, 'DefaultEvent.ini');
        if (File(strDefaEvent).existsSync()) {
          IniFile? inifile = IniFile(strDefaEvent);
          String strEvent = inifile.readString(
              'DefaultEvent', 'Output${DCMGlobal.output}', '');
          if (EventFileImpl.isEventExisted(strEvent)) {
            createPlayList(strEvent);
            bLoad = (!strCurrEvent.equalsIgnoreCase(strEvent));

            bExisted = true;
          }
        }
      }
      if (!bExisted) {
        for (int j = 0; j < cMaxDefaEventForPlay; j++) {
          String strEvent = 'Default${j + 1}';
          if (EventFileImpl.isEventExisted(strEvent)) {
            createPlayList(strEvent);
            bLoad = (!strCurrEvent.equalsIgnoreCase(strEvent));

            bExisted = true;

            break;
          }
        }
      }

      if (!bExisted) {
        createPlayList('dcmplay');
        bLoad = (!strCurrEvent.equalsIgnoreCase('dcmplay'));
      }

      getPlayRange();
      logD('Load Schedule2 $pid.');

      return bLoad;
    }
  }

  String getDefaPlaylistIntegrityCheck(IntegrityCheck integrityCheck) {
    String strDefaultEvent = '';
    for (int j = 0; j < cMaxDefaEventForPlay; j++) {
      String strEvent = 'Default${j + 1}';
      if (integrityCheck.integrityCheckPlaylist(strEvent)) {
        strDefaultEvent = strEvent;
        break;
      }
    }

    return strDefaultEvent;
  }

  PlayList? createPlayList(String szPlayList,
      [String? szUniqueName, String? szCompany]) {
    var pList = PlayList();
    pList.company = szCompany ?? '';
    pList.strEvent = szPlayList;
    pList.uniqueName = szUniqueName ?? '';

    if (!pList.loadPlayList(
        plName: szPlayList, uniqueName: szUniqueName, company: szCompany)) {
      return null;
    } else {
      arrEvent.add(Pair(szUniqueName ?? szPlayList, szPlayList));
      pList.startDateTime = startDateTime;
      lstScheduleList.add(pList);
    }

    return pList;
  }

  PlayList? getPlayList(String strPlayList) {
    for (var pPlayList in lstScheduleList) {
      if (pPlayList.uniqueName == strPlayList) {
        return pPlayList;
      }
    }
    return null;
  }

  PlayList? getCurrPlaylist() {
    if (playListIndex < arrEvent.length) {
      return getPlayList(arrEvent[playListIndex].key);
    }
    return null;
  }

  bool playFileList(StringBuffer dcmFile) {
    if (arrEvent.isEmpty) {
      dcmFile.write(this.dcmFile);
      return true;
    }

    var nPlaylist = getPlaylistForPlay();
    if (nPlaylist != -1) {
      var pPlayList = getPlayList(arrEvent[nPlaylist].value);
      if (pPlayList != null) {
        var dtCurr = DateTime.now();
        pPlayList.adjustAHTime(dtCurr);
        if (pPlayList.playFileList(dcmFile)) {
          playListIndex = nPlaylist;
          return true;
        }
      }
    }

    return false;
  }

  int getPlaylistForPlay() {
    var dtCurr = DateTime.now();
    var dtStartTime = dtCurr;
    var dtStartTime1 = scheduleStart;
    int nPlaylist = -1;

    for (int i = 0; i < arrEvent.length; i++) {
      var pPlayList = getPlayList(arrEvent[i].key);
      if (pPlayList == null) continue;

      var result = pPlayList.isTimeForStartPlay(dtCurr, dtStartTime);
      if (result.timeForPlay &&
          (pPlayList.ahPlaylist ||
              (!pPlayList.ahPlaylist && (!pPlayList.isTimeForStop(dtCurr))))) {
        dtStartTime = result.dtStartTime!;
        if (dtStartTime.compareTo(dtStartTime1!) >= 0) {
          dtStartTime1 = dtStartTime;
          nPlaylist = i;
        }
      }
    }

    return nPlaylist;
  }

  bool playNextFile(StringBuffer outDCMFile) {
    if (arrEvent.isEmpty) {
      outDCMFile.write(dcmFile);
      return true;
    }

    var pPlayList = getCurrPlaylist();
    if (pPlayList != null && pPlayList.playNextFile(outDCMFile)) {
      return true;
    }

    return false;
  }

  String getPlayFile() {
    var strDCMFile = StringBuffer();
    validPlayFileList(0, strDCMFile, true);
    return strDCMFile.toString();
  }

  bool validPlayFileList(int nStart, StringBuffer strDCMFile, bool bSeq) {
    if (arrEvent.length == 1) {
      var pPlayList = getPlayList(arrEvent[0].key);
      if (pPlayList != null && pPlayList.playNextFile(strDCMFile)) {
        playListIndex = 0;
        return true;
      }
    }

    var dtCurr = DateTime.now();
    var dtStartTime = dtCurr;
    var dtStartTime1 = scheduleStart;
    bool bPlaylist = false;

    if (bSeq) {
      for (int i = (nStart < 0 ? 0 : nStart); i < arrEvent.length; i++) {
        var pPlayList = getPlayList(arrEvent[i].key);
        if (pPlayList != null) {
          var result = pPlayList.isTimeForStartPlay(dtCurr, dtStartTime);
          if (result.timeForPlay && pPlayList.playNextFile(strDCMFile)) {
            dtStartTime = result.dtStartTime!;
            if (dtStartTime.compareTo(dtStartTime1!) >= 0) {
              dtStartTime1 = dtStartTime;
              playListIndex = i;
              bPlaylist = true;
            }
          }
        }
      }
    } else {
      for (int i = nStart; i > -1; i--) {
        var pPlayList = getPlayList(arrEvent[i].key);
        if (pPlayList != null) {
          var result = pPlayList.isTimeForStartPlay(dtCurr, dtStartTime);
          if (result.timeForPlay && pPlayList.playNextFile(strDCMFile)) {
            dtStartTime = result.dtStartTime!;
            if (dtStartTime.compareTo(dtStartTime1!) >= 0) {
              dtStartTime1 = dtStartTime;
              playListIndex = i;
              bPlaylist = true;
            }
          }
        }
      }
    }

    return bPlaylist;
  }

  int getPlayMeth() => playMeth;

  int get count => arrEvent.length;

  int getPlayProduct([bool? bIsAH]) {
    if (arrEvent.isEmpty) {
      return playProduct;
    }

    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        if (bIsAH != null) {
          return pPlayList.getPlaylistZone(bIsAH).getPlayProduct;
        }

        return pPlayList.getPlaylistZone().getPlayProduct;
      }
    }

    return 0;
  }

  void initPlaylistZone(ProductData? pProduct) {
    if (arrEvent.isEmpty) {
      return;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.getPlaylistZone().initPlaylistZone(pProduct);
    }
  }

  bool getContentListIndex(int nZone, int nIndex) {
    if (arrEvent.isEmpty) {
      return true;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      return pPlaylist.getContentListIndex(nZone, nIndex);
    }

    return false;
  }

  bool getPlayDuration(int nZone, double dbDuration) {
    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      return pPlaylist.getPlayDuration(nZone, dbDuration);
    }

    return false;
  }

  void setContentListIndex(int nZone, int nIndex, [int nTotal = 0]) {
    if (arrEvent.isEmpty) {
      return;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.setContentListIndex(nZone, nIndex, nTotal);
    }
  }

  void incrementContentListIndex(bool bIsAH) {
    if (arrEvent.isEmpty) {
      return;
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.incrementContentListIndex(bIsAH);
    }
  }

  void setPlayDuration(int nZone, double dbDuration) {
    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.setPlayDuration(nZone, dbDuration);
    }
  }

  bool isLoadedState() {
    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      return pPlaylist.isLoadState;
    }

    return false;
  }

  void setLoadedState(bool bState) {
    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      pPlaylist.isLoadState = bState;
    }
  }

  void writePlaylistLog([bool bWriteLog = true]) {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        pPlayList.writePlaylistLog(bWriteLog);
      }
    }
  }

  void setPlaylistLog([bool bWriteLog = true]) {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        pPlayList.writeLog = bWriteLog;
      }
    }
  }

  void setPlayProduct(int nProduct) {
    if (arrEvent.isEmpty) {
      playProduct = nProduct;
      return;
    }

    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);

      if (pPlayList != null) {
        pPlayList.getPlaylistZone().setPlayProduct(nProduct);
      }
    }
  }

  int getZoneCount(int nProduct, [int nZoneEffect = 0]) {
    var pProduct = catalogue.getProductDataByIndex(nProduct);
    if (pProduct != null) {
      return pProduct.getZoneCount(nZoneEffect);
    }

    return catalogue.getZoneNumber();
  }

  ZoneData? getZoneData(int nProduct, int nZone) {
    var pProduct = catalogue.getProductDataByIndex(nProduct);
    if (pProduct != null) {
      return pProduct.getZoneData(nZone);
    }

    return null;
  }

  bool isTimeForStopCurrPlayList(DateTime dtCurr) {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);

      if (pPlayList != null && pPlayList.isTimeForStop(dtCurr)) {
        return true;
      }
    }

    return false;
  }

  void adjustAHTime(DateTime dtStart) {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        pPlayList.adjustAHTime(dtStart);
      }
    }
  }

  bool isPlayingEpisode() {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);

      if (pPlayList != null && pPlayList.isAHPlaying) {
        return true;
      }
    }

    return false;
  }

  bool isWaitForPlayAH() {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);

      if (pPlayList != null && pPlayList.isPlayEpisode) {
        return true;
      }
    }

    return false;
  }

  bool isTimeForPlayEpisode(DateTime dtStart) {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null && pPlayList.isTimeForPlayEpisode(dtStart)) {
        return true;
      }
    }

    return false;
  }

  bool isTimeForPlayNextEvent() {
    var dtCurr = DateTime.now();
    var pCurrPlaylist = getCurrPlaylist();
    if (pCurrPlaylist != null) {
      if (pCurrPlaylist.ahPlaylist && !pCurrPlaylist.isTimeForStop(dtCurr)) {
        return false;
      }
    }

    var dtStartTime = dtCurr;
    var dtStartTime1 = scheduleStart;
    int nNext = -1;
    for (int i = 0; i < arrEvent.length; i++) {
      var pPlayList = getPlayList(arrEvent[i].key);
      if (pPlayList != null) {
        if (pCurrPlaylist != null && pPlayList == pCurrPlaylist) {
          if (pCurrPlaylist.ahPlaylist) {
            continue;
          }
        }

        var result = pPlayList.isTimeForStartPlay(dtCurr, dtStartTime);
        if (result.timeForPlay &&
            (pPlayList.ahPlaylist ||
                (!pPlayList.ahPlaylist &&
                    (!pPlayList.isTimeForStop(dtCurr))))) {
          dtStartTime = result.dtStartTime!;
          if (dtStartTime.compareTo(dtStartTime1!) >= 0) {
            dtStartTime1 = dtStartTime;
            nNext = i;
          }
        }
      }
    }

    if (nNext != -1 && nNext != playListIndex) {
      logD(
          'CScheduleList::IsTimeForPlayNextEvent; curr playlist: $playListIndex - next playlist: $nNext');
      return true;
    }

    return false;
  }

  bool isTimeForPlayNextGroup() {
    if (playListIndex < arrEvent.length) {
      var pPlayList = getPlayList(arrEvent[playListIndex].key);

      if (pPlayList != null && pPlayList.isTimeForPlayNextGroup()) {
        return true;
      }
    }

    return false;
  }

  void getPlayRange() {
    var dtCurr = DateTime.now();
    scheduleStart = null; // 设置为null状态
    scheduleEnd = null; // 设置为null状态

    for (int i = 0; i < arrEvent.length; i++) {
      var pPlayList = getPlayList(arrEvent[i].key);

      if (pPlayList != null) {
        var result = pPlayList.getPlayRange(dtCurr);
        if (scheduleStart == null || scheduleStart!.isAfter(result.dtStart!)) {
          scheduleStart = result.dtStart;
        }
        if (scheduleEnd == null || scheduleEnd!.isBefore(result.dtEnd!)) {
          scheduleEnd = result.dtEnd;
        }
      }
    }
  }

  bool isTimeForStop(DateTime dtCurr) {
    var dtEnd = DateTime.now();
    var dtStart = DateTime.now();
    var dts = differenceTime(scheduleStart, scheduleEnd);

    dtStart = DateTime(
      startDateTime.year,
      startDateTime.month,
      startDateTime.day,
      scheduleStart!.hour,
      scheduleStart!.minute,
      scheduleStart!.second,
    );

    if (dtStart
        .subtract(const Duration(days: 1))
        .add(dts)
        .isAfter(startDateTime)) {
      dtStart = dtStart.subtract(const Duration(days: 1));
    }

    dtEnd = dtStart.add(dts);
    if (dtEnd.compareTo(startDateTime) <= 0) {
      dtStart = dtStart.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }

    logD(
        'IsTimeForStop StartTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart)}; EndTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtEnd)}; CurrTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtCurr)}');
    if (dtEnd.compareTo(dtCurr) <= 0) {
      return isReLoadEvent();
    }

    if (dtStart.difference(dtCurr).inSeconds > 1) {
      return true;
    }

    return false;
  }

  bool isEndTime(DateTime dtCurr) {
    DateTime dtEnd;
    DateTime dtStart;
    Duration dts = differenceTime(scheduleStart, scheduleEnd);
    dtStart = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        scheduleStart!.hour,
        scheduleStart!.minute,
        scheduleStart!.second);
    //String dtTime = dtStart.Format('%Y/%m/%d %H:%M%S');
    //String dtTime5 = startDateTime.Format('%Y/%m/%d %H:%M%S');
    if (dtStart
        .subtract(const Duration(days: 1))
        .add(dts)
        .isAfter(startDateTime)) {
      dtStart = dtStart.subtract(const Duration(days: 1));
    }
    //String dtTime1 = dtStart.Format('%Y/%m/%d %H:%M:%S');
    //Duration dts1 = startDateTime - dtStart;
    dtEnd = dtStart.add(dts); //startDateTime + (dts - dts1);
    //String dtTime2 = dtEnd.Format('%Y/%m/%d %H:%M%S');
    if (dtEnd.compareTo(startDateTime) <= 0) {
      dtStart = dtStart.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }
    //String dtTime3 = dtStart.Format('%Y/%m/%d %H:%M%S');
    //String dtTime4 = dtEnd.Format('%Y/%m/%d %H:%M%S');
    if (dtEnd.compareTo(dtCurr) <= 0) {
      return true;
    }

    if (dtStart.isAfter(dtCurr)) {
      return true;
    }
    return false;
  }

  bool isReLoadEvent() {
    var dtEnd = DateTime.now();
    var dtStart = DateTime.now();
    var dtStart1 = DateTime.now();
    var dtCurr = DateTime.now();
    var dts = scheduleEnd!.difference(scheduleStart!);

    dtStart1 = DateTime(
      startDateTime.year,
      startDateTime.month,
      startDateTime.day,
      scheduleStart!.hour,
      scheduleStart!.minute,
      scheduleStart!.second,
    );

    if (dtStart1
        .subtract(const Duration(days: 1))
        .add(dts)
        .isAfter(startDateTime)) {
      dtStart1 = dtStart1.subtract(const Duration(days: 1));
    }

    dtEnd = dtStart1.add(dts);
    dtCurr = dtCurr.add(const Duration(seconds: 1));

    dtStart = DateTime(
      dtCurr.year,
      dtCurr.month,
      dtCurr.day,
      scheduleStart!.hour,
      scheduleStart!.minute,
      scheduleStart!.second,
    );

    if (dtStart.isBefore(dtEnd)) {
      return true;
    }

    var strMonth = '${dtStart.year}${dtStart.month.toString().padLeft(2, '0')}';
    var nDay = dtStart.day;
    if (month == strMonth && day == nDay) {
      return false;
    }

    return true;
  }

  int getTotalProducts() => catalogue.nQuantity;
  int getTotalZones() => catalogue.getZoneNumber();
  bool hasBGMusic() => catalogue.bBGMusic;
  String getBGMusicFile() => catalogue.strMusicFile;
}
