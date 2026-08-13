// schedule_list.dart
import 'dart:io';
import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/layout_data.dart';
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
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
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
    if (currEvent.equalsIgnoreCase('StartupWallpaper') &&
        AppGlobal.startupWallpaper != null &&
        AppGlobal.startupWallpaper!.isNotEmpty) {
      catalogue.strCatalogueName = 'StartupWallpaper';
      catalogue.nQuantity = 1;
      catalogue.strLayoutName = 'H01';
      catalogue.nSkin = 1;
      catalogue.strSkinCode = 'No Frame and No Button';

      catalogue.productFromFile(AppGlobal.startupWallpaper!, cIMAGETYPE, 86400);
      catalogue.pLayoutDataObj = LayoutData();
      catalogue.pLayoutDataObj!.strLayoutName = 'H01';
      catalogue.pLayoutDataObj!.initFullScreen(1920, 1080);

      return true;
    }

    String strDCMFile = '';
    if (fileName == null && arrEvent.isNotEmpty) {
      PlayList? pPlaylist = getCurrPlaylist();
      if (pPlaylist != null) {
        strDCMFile = pPlaylist.getPlaylistZone().getDCMFile;
      }
    } else {
      strDCMFile = fileName ?? '';
    }

    String strCompany = getCurrCompany();
    try {
      getCatalogue().initDocument();
      var filePath =
          DCMFileImpl.getDCMPath(strDCMFile, AppGlobal.openPath, strCompany);
      if (filePath != null) {
        var catalogueData =
            DCMFileImpl.openCatalogue(szEdit: filePath, bShort: false);
        if (catalogueData != null) {
          catalogue = catalogueData;
          return true;
        }
      }
    } catch (e) {
      logE('loadCatalogue error: $e');
    }

    catalogue.strCatalogueName = '';
    catalogue.nQuantity = 1;
    catalogue.strLayoutName = 'H01';
    catalogue.nSkin = 1;
    catalogue.strSkinCode = 'No Frame and No Button';
    DCMFileImpl.getLayoutData(catalogue);

    return (DCMFileImpl.addContent(catalogue, strDCMFile) == true);
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
        var pList = PlayList(this);
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
                        AppGlobal.output) {
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

            if ((AppGlobal.loopMethod & settingLATESTPLAYLIST) > 0) {
              ChannelScheduleImpl.changeToLatestPlaylist(pDayInfoData);
            }

            break;
          }
        }
      }

      bool bExisted = arrEvent.isNotEmpty;
      if (!bExisted) {
        String strDefaEvent =
            path.join(AppGlobal.settingPath, 'DefaultEvent.ini');
        if (File(strDefaEvent).existsSync()) {
          IniFile inifile = IniFile(strDefaEvent);
          String strEvent = inifile.readString(
              'DefaultEvent', 'Output${AppGlobal.output}', '');
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

  List<ZoneData> getContents(int nType) {
    List<ZoneData> arrContents = [];
    for (int i = 0; i < arrEvent.length; i++) {
      PlayList? pPlaylist = getPlayList(arrEvent[i].key);
      if (pPlaylist != null) {
        EventFileImpl fileImpl = EventFileImpl();
        EventFileData objList = EventFileData();
        if (!fileImpl.loadFromXML(pPlaylist.strEvent, objList)) {
          fileImpl.loadPlayList(objList, pPlaylist.strEvent);
        }
        for (var pPlayListData in objList.lstPlayList!) {
          if (pPlayListData.arrDCMFile != null &&
              pPlayListData.arrDCMFile!.isNotEmpty) {
            for (int i = 0; i < pPlayListData.arrDCMFile!.length; i++) {
              if (pPlayListData.isDCMFileExist(i)) {
                arrContents.addAll(DCMFileImpl.getContents(
                    pPlayListData.arrDCMFile![i], nType));
              }
            }
          } else {
            if (pPlayListData.isDCMFileExist()) {
              arrContents.addAll(
                  DCMFileImpl.getContents(pPlayListData.strDCMFile, nType));
            }
          }
        }
      }
    }

    return arrContents;
  }

  bool integrityCheck([bool bOleviaPlayer = false]) {
    if (playMeth == SchedulePlayMeth.eAHPLAYLIST.index) {
      return true;
    }

    bool bLoad = true;
    if (bOleviaPlayer) {
      bool bReimport = false;
      IntegrityCheck integrityCheck = IntegrityCheck();
      //bool bValid = true;
      //if (bLoadSchedule)
      {
        for (int i = 0; i < arrEvent.length; i++) {
          //if (!CEventFileImpl::IsEventValid(m_arrEvent[i].Value, m_arrEvent[i].Name))
          PlayList? pPlaylist = getPlayList(arrEvent[i].key);
          if (pPlaylist != null) {
            if (!integrityCheck.integrityCheckPlaylist(pPlaylist.strEvent,
                company: pPlaylist.company)) {
              bReimport = true;
              bLoad = false;
              break;
            }
          }
        }
      }

      if (!bLoad) {
        for (int j = 0; j < cMaxDefaEventForPlay; j++) {
          String strEvent = 'Default${j + 1}';
          if (integrityCheck.integrityCheckPlaylist(strEvent)) {
            bLoad = loadSchedule(playList: strEvent);
            break;
          }
        }
      }
      if (!bLoad) {
        loadSchedule();
      }

      if (bReimport) {
        ContentImpInstance.reimportTaskCheck();
      }
    }

    return bLoad;
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
    var pList = PlayList(this);
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

  bool isAHPlaylist() {
    bool bAHPlaylist = false;

    PlayList? pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      bAHPlaylist = pPlaylist.ahPlaylist;
    }

    return bAHPlaylist;
  }

  ({bool status, String? strDCMFile}) startPlayAHItem() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    PlayList? pPlayList = getCurrPlaylist();
    if (pPlayList != null) {
      var result = pPlayList.startPlayAHItem();
      if (result.status) {
        return result;
      }
    }

    return (status: false, strDCMFile: null);
  }

  ({bool status, String? strDCMFile}) returnPlayNormalItem() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    PlayList? pPlayList = getCurrPlaylist();
    if (pPlayList != null) {
      var result = pPlayList.returnPlayNormalItem();
      if (result.status) {
        return result;
      }
    }

    return (status: false, strDCMFile: null);
  }

  ({bool status, String? strDCMFile}) playFileList() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    var nPlaylist = getPlaylistForPlay();
    if (nPlaylist != -1) {
      var pPlayList = getPlayList(arrEvent[nPlaylist].value);
      if (pPlayList != null) {
        pPlayList.adjustAHTime(DateTime.now());
        var result = pPlayList.playFileList();
        if (result.status) {
          playListIndex = nPlaylist;
          return result;
        }
      }
    }

    return (status: false, strDCMFile: null);
  }

  ({bool status, String? strDCMFile}) playNextPlaylist() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    DateTime dtCurr = DateTime.now();
    PlayList? pCurrPlaylist = getCurrPlaylist();
    if (pCurrPlaylist != null && pCurrPlaylist.ahPlaylist) {
      pCurrPlaylist.savePlayedDuration(dtCurr);
    }

    int nPlaylist = getPlaylistForPlay();
    if (nPlaylist != -1) {
      PlayList? pPlayList = getPlayList(arrEvent[nPlaylist].key);
      if (pPlayList != null) {
        pPlayList.adjustAHTime(dtCurr);
        var result = pPlayList.playNextPlaylist();
        if (result.status) {
          playListIndex = nPlaylist;
          return result;
        }
      }
    }

    return (status: false, strDCMFile: null);
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

  String getCurrCompany() {
    String strCompany = '';
    if (playMeth != SchedulePlayMeth.ePEROUTPUTPLAYLIST.index) {
      if (playListIndex < arrEvent.length) {
        PlayList? pPlayList = getPlayList(arrEvent[playListIndex].key);
        if (pPlayList != null) {
          strCompany = pPlayList.company;
        }
      }
    }

    return strCompany;
  }

  ({bool status, String? strDCMFile}) playNextFile() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    var pPlayList = getCurrPlaylist();
    if (pPlayList != null) {
      return pPlayList.playNextFile();
    }

    return (status: false, strDCMFile: null);
  }

  ({bool status, String? strDCMFile}) playNextGroup() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    PlayList? pPlayList = getCurrPlaylist();
    if (pPlayList != null) {
      return pPlayList.playNextFile();
    }

    return (status: false, strDCMFile: null);
  }

  ({bool status, String? strDCMFile}) playCurrFile() {
    if (arrEvent.isEmpty) {
      return (status: true, strDCMFile: dcmFile);
    }

    if (arrEvent.length <= playListIndex) {
      playListIndex = 0;
    } else {
      if (arrEvent.length == 1) {
        PlayList? pPlayList = getPlayList(arrEvent[0].key);
        if (pPlayList != null) {
          var result = pPlayList.playCurrFile();
          if (result.status) {
            pPlayList.adjustAHTime(DateTime.now());
            playListIndex = 0;

            return result;
          }
        }
      }

      int nPlaylist = getPlaylistForPlay();
      if (nPlaylist != -1) {
        PlayList? pPlayList = getPlayList(arrEvent[nPlaylist].key);
        if (pPlayList != null) {
          var result = pPlayList.playCurrFile();
          if (result.status) {
            pPlayList.adjustAHTime(DateTime.now());
            playListIndex = nPlaylist;
            return result;
          }
        }
      }
    }

    return validPlayFileList(playListIndex);
  }

  String getPlayFile() {
    var result = validPlayFileList(0, true);
    return result.strDCMFile ?? '';
  }

  ({bool status, String? strDCMFile}) getFirstAHFile() {
    if (playListIndex < arrEvent.length) {
      PlayList? pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        var result = pPlayList.getFirstAHFile();
        if (result.status) {
          return result;
        }
      }
    }

    return (status: false, strDCMFile: null);
  }

  ({bool status, String? strDCMFile}) validPlayFileList(int nStart,
      [bool bSeq = true]) {
    if (arrEvent.length == 1) {
      var pPlayList = getPlayList(arrEvent[0].key);
      if (pPlayList != null) {
        var result = pPlayList.playNextFile();
        if (result.status) {
          playListIndex = 0;
          return result;
        }
      }
    }

    var dtCurr = DateTime.now();
    var dtStartTime = dtCurr;
    var dtStartTime1 = scheduleStart;
    bool bPlaylist = false;

    String? validDCMFile;
    if (bSeq) {
      for (int i = (nStart < 0 ? 0 : nStart); i < arrEvent.length; i++) {
        var pPlayList = getPlayList(arrEvent[i].key);
        if (pPlayList != null) {
          var result = pPlayList.isTimeForStartPlay(dtCurr, dtStartTime);
          if (result.timeForPlay) {
            var playNextResult = pPlayList.playNextFile();
            if (playNextResult.status) {
              dtStartTime = result.dtStartTime!;
              if (dtStartTime.compareTo(dtStartTime1!) >= 0) {
                dtStartTime1 = dtStartTime;
                playListIndex = i;
                bPlaylist = true;
                validDCMFile = playNextResult.strDCMFile;
              }
            }
          }
        }
      }
    } else {
      for (int i = nStart; i > -1; i--) {
        var pPlayList = getPlayList(arrEvent[i].key);
        if (pPlayList != null) {
          var result = pPlayList.isTimeForStartPlay(dtCurr, dtStartTime);
          if (result.timeForPlay) {
            var playNextResult = pPlayList.playNextFile();
            if (playNextResult.status) {
              dtStartTime = result.dtStartTime!;
              if (dtStartTime.compareTo(dtStartTime1!) >= 0) {
                dtStartTime1 = dtStartTime;
                playListIndex = i;
                bPlaylist = true;
                validDCMFile = playNextResult.strDCMFile;
              }
            }
          }
        }
      }
    }

    return (status: bPlaylist, strDCMFile: validDCMFile);
  }

  int getPlayMeth() => playMeth;

  int get count => arrEvent.length;

  void setPlayTimes() {
    if (playListIndex < arrEvent.length) {
      PlayList? pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        pPlayList.setPlayTimes();
      }
    }
  }

  bool getPlayTimes() {
    if (playListIndex < arrEvent.length) {
      PlayList? pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null && pPlayList.getPlayTimes()) {
        return true;
      }
    }

    return false;
  }

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

  ({bool status, int index}) getContentListIndex(int nZone) {
    if (arrEvent.isEmpty) {
      return (status: false, index: 0);
    }

    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      return pPlaylist.getContentListIndex(nZone);
    }

    return (status: false, index: 0);
  }

  ({bool status, double duration}) getPlayDuration(int nZone) {
    var pPlaylist = getCurrPlaylist();
    if (pPlaylist != null) {
      return pPlaylist.getPlayDuration(nZone);
    }

    return (status: false, duration: 0.0);
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

  Rect scaleToVW(int nZone, Rect rectPlayer) {
    Rect rectVW = Rect.fromLTWH(0, 0, rectPlayer.width, rectPlayer.height);

    Rect? rcVW = catalogue.getZoneRect(nZone, rectVW);
    if (rcVW != null) {
      rcVW = rcVW.shift(rectPlayer.topLeft);
    } else {
      rcVW = rectPlayer;
    }

    return rcVW;
  }

  int getZoneCount(int nProduct,
      [ZoneEffectType nZoneEffect = ZoneEffectType.noEffect]) {
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
  DCMFileData getCatalogue() => catalogue;
  bool isDCMFilePlay() => lstScheduleList.isEmpty;
  ProductData? getProductData(int nProduct) =>
      catalogue.getProductDataByIndex(nProduct);
  void setShowMessage(bool bShow) {
    messageList.showAHMessage(bShow);
  }

  bool isMessagePlaying() => messageList.isPlaying();

  bool hasContentType([int nContentType = cPLUGINTYPE]) {
    return catalogue.hasContentType(nContentType);
  }

  bool isCatalogueCanPlay() {
    return catalogue.canPlay();
  }

  bool hasPowerPoint(int nCurrProduct) {
    return catalogue.hasPowerPoint(nCurrProduct);
  }
  //bool isLastProduct() { return (catalogue.m_nQuantity <= _nCurrProduct + 1);}

  bool loadState() => true;
  bool saveState() => true;

  void resetStartDateTime() {
    startDateTime = DateTime.now();
  }

  bool isTimeForPlay(DateTime dtStart) {
    DateTime dtStartTime;
    DateTime dtEnd;

    dtStartTime = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        scheduleStart!.hour,
        scheduleStart!.minute,
        scheduleStart!.second);

    //String strStartTime3 = scheduleStart.Format('%Y%m%d%H%M%S');
    //String strStartTime4 = scheduleEnd.Format('%Y%m%d%H%M%S');

    //String strStartTime = dtStartTime.Format('%Y%m%d%H%M%S');
    Duration dts = differenceTime(
        scheduleStart, scheduleEnd); //scheduleEnd - scheduleStart;
    if (dtStartTime
        .subtract(const Duration(days: 1))
        .add(dts)
        .isAfter(startDateTime)) {
      dtStartTime = dtStartTime.subtract(const Duration(days: 1));
    }
    //String strStartTime1 = dtStartTime.Format('%Y%m%d%H%M%S');

    dtEnd = dtStartTime.add(dts);
    //String strStartTime2 = dtEnd.Format('%Y%m%d%H%M%S');
    if (dtEnd.compareTo(startDateTime) <= 0) {
      dtStartTime = dtStartTime.add(const Duration(days: 1));
      dtEnd = dtEnd.add(const Duration(days: 1));
    }

    if (dtStart.compareTo(dtStartTime) >= 0 && dtStart.isBefore(dtEnd)) {
      return true;
    }

    return false;
  }

  int isTimeForMessage(DateTime dtCurr) {
    return messageList.isTimeForMessage(dtCurr);
  }

  int isTimeForStopMessage(DateTime dtCurr, int nOutput) {
    return messageList.isTimeForStop(dtCurr, nOutput);
  }

  int isTimeForLoadMessage(DateTime dtCurr) {
    return messageList.isTimeForLoad(dtCurr);
  }

  ({bool status, int? nFlag}) isTimeForLoad(DateTime dtStart, int nFlag) {
    if (swapEvent) {
      swapEvent = false;
      return (status: true, nFlag: nFlag);
    }

    logD(
        'IsTimeForLoad m_dtSTartDateTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime)}');
    DateTime dtEnd;
    DateTime dtStart1;
    DateTime dtStartTime;
    Duration dts = differenceTime(
        scheduleStart, scheduleEnd); //scheduleEnd - scheduleStart;
    dtStart1 = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
        scheduleStart!.hour,
        scheduleStart!.minute,
        scheduleStart!.second);

    logD(
        'IsTimeForLoad dtStart1: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart1)}');
    /*if (dtStart1 - Duration(1, 0, 0, 0) + dts > startDateTime)
    {
      //DateTime dtDay = startDateTime - Duration(1, 0, 0, 0);
      dtStart1 -= Duration(1, 0, 0, 0);
    }*/

    DateTime dtTime = dtStart1.subtract(const Duration(days: 1)).add(dts);
    if (dtTime.isAfter(startDateTime)) {
      if (dtStart.compareTo(dtTime) <= 0) {
        dtStart1 = dtStart1.subtract(const Duration(days: 1));
      }
    }

    logD(
        'IsTimeForLoad dtStart1: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart1)}');

    day = dtStart1.day;

    //Duration dts1 = startDateTime - dtStart1;
    dtEnd = dtStart1.add(dts); //startDateTime + (dts - dts1);
    logD(
        'IsTimeForLoad dtStart: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart)}');
    logD(
        'IsTimeForLoad dtEnd: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtEnd)}');

    if (dtStart.compareTo(dtEnd) >= 0) {
      //if Prev playback End
      DateTime dtStart2 =
          dtStart.add(const Duration(days: 1)); //Next Playback time
      dtStartTime = DateTime(
          dtStart2.year,
          dtStart2.month,
          dtStart2.day,
          scheduleStart!.hour,
          scheduleStart!.minute,
          scheduleStart!.second); //Next Playback time
      //String strTime2 = dtStartTime.Format('%Y%m%d%H%M%S');
      //String strTime3 = dtEnd.Format('%Y%m%d%H%M%S');
      /*if (dtStartTime < dtEnd)//Next playtime must more than prev playtime
      {
        dtStartTime += Duration(1, 0, 0, 0);
      }*/

      logD(
          'IsTimeForLoad dtStart2: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStart2)}');
      logD(
          'IsTimeForLoad dtStartTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtStartTime)}');

      if (dtStartTime.compareTo(dtStart2) <= 0) {
        //Start Next Playback
        if (dtStartTime.isBefore(dtEnd)) {
          //Next playtime must more than prev playtime
          startDateTime = dtEnd;
        } else {
          startDateTime = dtStartTime;
        }

        logD(
            'IsTimeForLoad After m_dtSTartDateTime: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime)}');
        day = dtStartTime.day;
        month = DateFormat('yyyyMM').format(dtStartTime);

        if (loadSchedule()) {
          return (status: true, nFlag: nFlag);
        }
      }
    }

    //bool bReload = false;
    if (AppGlobal.processAHConflict == 1) {
      for (var pPlayList in lstScheduleList) {
        pPlayList.checkAHSchedule(dtStart);
      }
    }

    if (playListIndex < arrEvent.length) {
      PlayList? pPlayList = getPlayList(arrEvent[playListIndex].key);
      if (pPlayList != null) {
        var result = pPlayList.isTimeForLoadEpisode(dtStart);
        if (result.status) {
          return (status: true, nFlag: result.nFlag);
        }
      }
    }

    return (status: false, nFlag: nFlag);
  }

  void changeTVChannel(int nNewChannel) {
    for (var pPlayList in lstScheduleList) {
      pPlayList.changeTVChannel(nNewChannel);
    }
  }
}
