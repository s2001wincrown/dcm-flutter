import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/daily_schedule_file.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/services/channel_schedule_impl.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/xml_settings/channel_schedule_file.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

/// 对应 DailyScheduleData
class DailyScheduleData {
  final List<String> _arrChannelName = [];
  String _strChannelName = '';
  String strMonth = '';
  String _strTodayEventOld = '';
  String _strTodayEventNew = '';

  List<String> arrDay = [];
  static List<String> arrEvent = [];
  static List<String> arrDCMFile = [];
  static List<String> arrContentList = [];

  List<String> get arrChannelName => _arrChannelName;
  String get strChannelName => _strChannelName;
  String get strTodayEventOld => _strTodayEventOld;
  String get strTodayEventNew => _strTodayEventNew;

  DailyScheduleData();

  static void clear() {
    arrDCMFile.clear();
    arrEvent.clear();
    arrContentList.clear();
  }

  DailyScheduleData.copy(DailyScheduleData dailyScheduleData) {
    // copy-constructor
    _strChannelName = dailyScheduleData._strChannelName;
    strMonth = dailyScheduleData.strMonth;
    for (int i = 0; i < dailyScheduleData.arrDay.length; i++) {
      arrDay.add(dailyScheduleData.arrDay[i]);
    }
  }

  Future<bool> copyMonthFile() async {
    bool bCopyed = false;
    String strSource = path.join(AppGlobal.calendarPath,
        '$strMonth.xml'); //_strAppPath + 'Schedule/calendar/'
    var monthFile = File(strSource);
    if (await monthFile.exists()) {
      String strLocalFile =
          await PlayerPathService.getExistedTempPath(cDCMCALENDARTYPE) ?? '';
      strLocalFile = path.join(strLocalFile, '$strMonth.xml');
      try {
        await monthFile.copy(strLocalFile);
        bCopyed = true;
        logI(
            '''copy schedule file:'$strSource' to '$strLocalFile' successfully\n''');
      } catch (e) {
        logI(
            '''copy schedule file:'$strSource' to '$strLocalFile' failure\n''');
      }
    }

    if (!bCopyed) {
      String strSource = path.join(AppGlobal.monthPath,
          '$strMonth.xml'); //_strAppPath + 'Schedule/month/'
      var monthFile = File(strSource);
      if (await monthFile.exists()) {
        String strLocalFile =
            await PlayerPathService.getExistedTempPath(cDCMCALENDARTYPE) ?? '';
        strLocalFile = path.join(strLocalFile, '$strMonth.xml');
        try {
          await monthFile.copy(strLocalFile);
          logI(
              '''copy schedule file:'$strSource' to '$strLocalFile' successfully\n''');
        } catch (e) {
          logI(
              '''copy schedule file:'$strSource' to '$strLocalFile' failure\n''');
          return false;
        }
      }
    }
    return true;
  }

  bool isTodayInclude() {
    String currMonth = DateFormat('yyyyMM').format(DateTime.now());
    if (strMonth == currMonth) {
      String strDay = '${DateTime.now().day}';
      for (int i = 0; i < arrDay.length; i++) {
        if (arrDay[i] == strDay) {
          return true;
        }
      }
    }
    return false;
  }

  void writeScheduleLog(
      XmlProfile xmlLog, String strEvent, String strDate, String strInfo) {
    XmlItem? nSec = xmlLog.getSection('DayItems');
    if (nSec != null) {
      XmlItem? pItem = nSec.addItem('DayItem');
      if (pItem != null) {
        pItem.addItem('m_strEvent', strEvent);
        pItem.addItem('m_nDay', strDate);
        pItem.addItem('m_strInfo', strInfo);
      }
    }
  }

  Future<bool> addEventToMonthSchedule() async {
    String strTempFile =
        await PlayerPathService.getExistedTempPath(cDCMCALENDARTYPE) ?? '';
    String strDestFile = path.join(strTempFile, '$strMonth.xml');
    String strLogFile = path.join(AppGlobal.ftpSettingPath, 'ftperror.xml');

    String strDestChannel = '';
    ChannelScheduleFile destfile = ChannelScheduleFile();
    if (await File(strDestFile).exists() &&
        !ChannelScheduleImpl.loadScheduleFile(
            strDestChannel, strDestFile, destfile)) {
      logE('''Load schedule file:'$strDestFile' failure\n''');

      return false;
    }
    XmlItem? hChannelDest = destfile.getChannelScheduleItem(null, bNew: true);
    if (hChannelDest != null) {
      int nToday = DateTime.now().day;
      XmlItem? hToday = destfile.findChannelItemByDay(nToday, hChannelDest);
      if (hToday != null) {
        _strTodayEventOld = destfile.getChannelScheduleEvent(hToday);

        logI('''Today playlist:'$_strTodayEventOld'\n''');
      }

      bool bLog = true;
      XmlProfile xmlLog = XmlProfile.fromFile(strLogFile);
      if (!xmlLog.loadProfile(szRootItemName: 'FTPError')) {
        bLog = xmlLog.createProfile('FTPError');
      }

      for (int i = 0; i < arrDay.length; i++) {
        List<Pair<String, String>> aItems = [];
        String strEvent = '';

        int nDay = int.parse(arrDay[i]);
        String strDate = path.join(
            arrDay[i], strMonth.substring(4, 6), strMonth.substring(0, 4));
        XmlItem? hDayItem = destfile.findChannelItemByDay(nDay, hChannelDest);
        if (hDayItem != null) {
          strEvent = destfile.getChannelScheduleEvent(hDayItem);
          aItems = destfile.getChannelScheduleEvents(hDayItem);
        }

        logI(
            '''Origin playlist:'$strEvent'; total playlists: ${aItems.length}\n''');
        if (aItems.isEmpty) {
          Pair<String, String> keyEvent = Pair<String, String>('0', strEvent);
          aItems.add(keyEvent);

          logI(
              '''Add playlist:'$strEvent' to playlist queue; total playlists: ${aItems.length}\n''');
        }

        String strAHEvent = arrEvent[0];
        bool bAddPlaylist = true;
        for (int nItem = 0; nItem < aItems.length; nItem++) {
          if (strAHEvent.equalsIgnoreCase(aItems[nItem].value)) {
            logI(
                '''ad-hoc playlist:'$strAHEvent' exist; total playlists: ${aItems.length}\n''');

            bAddPlaylist = false;
            break;
          }
        }

        if (bAddPlaylist) {
          Pair<String, String> keyEvent =
              Pair<String, String>('${aItems.length - 1}', strAHEvent);
          aItems.add(keyEvent);
          if (strEvent.isNotEmpty) {
            strEvent += ';';
          }

          strEvent += arrEvent[0];

          logI(
              '''Add ad-hoc playlist:'$strAHEvent' to playlist queue; total playlists: ${aItems.length}\n''');
        }

        XmlItem? hNewItem = destfile.getChannelDayItem(nDay, hChannelDest);
        //String strInfo = 'Multi Ouput';
        //String strEvent = 'Multi Playlist';
        if (hNewItem != null) {
          destfile.setChannelScheduleEvent(hNewItem, strEvent);
          destfile.setChannelScheduleInfo(hNewItem, '');
          destfile.setChannelSchedulePlayMeth(
              hNewItem, SchedulePlayMeth.eAHPLAYLIST.index);
          destfile.setChannelScheduleEvents(hNewItem, aItems);
        }

        if (bLog) {
          writeScheduleLog(xmlLog, strEvent, strDate, '');
        }
      }
      xmlLog.saveProfile('ftperror.xsl');

      destfile.setFileVersion(1);
      destfile.setNextUniqueID(destfile.getNextUniqueID());
      destfile.save(strDestFile);

      genOldMonthSchedule(destfile);
      destfile.close();
    }

    return true;
  }

  Future<bool> hasDCMPlay(bool bHasDCMPlayInServer) async {
    String strEvent = 'dcmplay';
    if (await File(path.join(
            await PlayerPathService.getLocalPath(cDCMDAYTYPE), '$strEvent.xml'))
        .exists()) {
      return true;
    }

    return bHasDCMPlayInServer;
  }

  Future<bool> loadTempChannelSchedule(
      ChannelScheduleFile file, String pszTempPath) async {
    String strChannelFile = path.join(pszTempPath, '${strMonth}_tmp.xml');
    if (await File(strChannelFile).exists()) {
      return (file.load(strChannelFile, null, false) == true);
    } else {
      for (int i = 0; i < _arrChannelName.length; i++) {
        String strChannel = _arrChannelName[i];
        String strChannelFile =
            path.join(pszTempPath, '$strChannel$strMonth.xml');
        if (await File(strChannelFile).exists()) {
          XmlProfile xmlProfile = XmlProfile.fromFile(strChannelFile);
          if (xmlProfile.loadProfile()) {
            List<DayInfoData> lstDayInfo =
                DayInfoData.readDayInfoList(xmlProfile);

            XmlItem? hScheduleItem = file.getChannelScheduleItem(strChannel);
            if (hScheduleItem != null) {
              for (var it in lstDayInfo) {
                DayInfoData pData = it;

                //XmlItem? hDayItem = file.NewChannelSchedule(pData.nDay, hScheduleItem);
                XmlItem? hDayItem =
                    file.getChannelDayItem(pData.day, hScheduleItem);
                if (hDayItem != null) {
                  file.setChannelScheduleEvent(hDayItem, pData.event);
                  file.setChannelScheduleInfo(hDayItem, pData.info);
                  file.setChannelSchedulePlayMeth(hDayItem, pData.playMeth);
                  file.setChannelScheduleEvents(hDayItem, pData.arrEvent);
                }
              }
            }
          }
        }
      }

      return (file.getChannelScheduleCount() > 0);
    }
  }

  Future<bool> parseCalendarInfo(DailyScheduleFile dailySchedule) async {
    String strLocalFile;
    String strTempFile =
        await PlayerPathService.getExistedTempPath(cDCMCALENDARTYPE) ?? '';

    logI('''Parsing calendar information from temp folder:'$strTempFile'.''');

    ChannelScheduleFile sourcefile = ChannelScheduleFile();
    if (await loadTempChannelSchedule(sourcefile, strTempFile)) {
      logI(
          '''Load calendar information from temp folder:'$strTempFile' successfully\n''');

      List<String> arrOutputs = [];
      int nOutputs = dailySchedule.getOutputs(arrOutputs);
      XmlItem? pOutput = dailySchedule.getItem('Output');
      while (pOutput != null) {
        int nOutput = pOutput.getItemValueI('ID');
        for (int i = 0; i < arrDay.length; i++) {
          int nDay = int.parse(arrDay[i]);
          String strDate =
              '${arrDay[i]}/${strMonth.substring(4, 6)}/${strMonth.substring(0, 4)}';
          XmlItem? pDayItem = dailySchedule.getDayItem(pOutput, strDate);
          if (pDayItem != null) {
            String strChannelName = pDayItem.getItemValue('Channel');

            String strEvent = 'dcmplay';
            String strInfo = '';
            int nPMethod = 0;
            //DCMKEYARRAY arrEvent;
            XmlItem? hChannelItem =
                sourcefile.getChannelScheduleItem(strChannelName, bNew: false);
            if (hChannelItem != null) {
              XmlItem? hDayItem =
                  sourcefile.findChannelItemByDay(nDay, hChannelItem);
              if (hDayItem != null) {
                strEvent = sourcefile.getChannelScheduleEvent(hDayItem);
                nPMethod = sourcefile.getChannelSchedulePlayMeth(hDayItem);
                strInfo = sourcefile.getChannelScheduleInfo(hDayItem);
                //sourcefile.getChannelScheduleEvents(hDayItem, arrEvent);
              }
            }
            nPMethod = (nOutputs > 1 ? 2 : nPMethod);
            dailySchedule.setEvent(pDayItem, strEvent);
            dailySchedule.setPMethod(pDayItem, nPMethod);
            dailySchedule.setInfo(pDayItem, strInfo);

            logI(
                '''Found playlist date:'$strDate'; output:'$nOutput' playlist:'$strEvent' play method:'$nPMethod'!''');
          }
        }

        pOutput = pOutput.getSibling();
      }
    }
    sourcefile.close();

    strLocalFile = path.join(strTempFile, '${strMonth}_tmp.xml');
    var localFile = File(strLocalFile);
    if (await localFile.exists()) {
      await localFile.delete();
    }
    for (int i = 0; i < _arrChannelName.length; i++) {
      strLocalFile =
          path.join(strTempFile, '${_arrChannelName[i]}$strMonth.xml');
      var channelFile = File(strLocalFile);
      if (await channelFile.exists()) {
        await channelFile.delete();
      }
    }

    return (arrEvent.isNotEmpty);
  }

  Future<bool> getEventList(DailyScheduleFile dailySchedule) async {
    await writeDefaultEvent(dailySchedule);
    String strTempFile =
        await PlayerPathService.getExistedTempPath(cDCMCALENDARTYPE) ?? '';
    String strDestFile = path.join(strTempFile, '$strMonth.xml');
    String strLogFile = path.join(AppGlobal.ftpSettingPath, 'ftperror.xml');

    logI(
        '''Start get event list from schedule file temp folder: '$strTempFile'\n''',
        syncTag);

    ChannelScheduleFile destfile = ChannelScheduleFile();
    bool bInclude = isTodayInclude();

    String strDestChannel = '';
    ChannelScheduleImpl.loadScheduleFile(strDestChannel, strDestFile, destfile);
    XmlItem? hChannelDest = destfile.getChannelScheduleItem(null, bNew: true);
    if (hChannelDest != null) {
      int nToday = DateTime.now().day;
      if (bInclude) {
        XmlItem? hDayItem = destfile.findChannelItemByDay(nToday, hChannelDest);
        if (hDayItem != null) {
          _strTodayEventOld = destfile.getChannelScheduleEvent(hDayItem);
        }
      }

      bool bLog = true;
      XmlProfile xmlLog = XmlProfile.fromFile(strLogFile);
      if (!xmlLog.loadProfile(szRootItemName: 'FTPError')) {
        bLog = xmlLog.createProfile('FTPError');
      }
      bool bDCMPlay = dailySchedule.hasDCMPlay();
      if (bDCMPlay) {
        addToEventList('dcmplay');
      }

      for (int i = 0; i < arrDay.length; i++) {
        int nDay = int.parse(arrDay[i]);
        String strDate =
            '${arrDay[i].padLeft(2, '0')}/${strMonth.substring(4, 6)}/${strMonth.substring(0, 4)}';
        DateTime? dtDate = fromDateTimeFormat('$strDate 00:00:00');

        List<String> arrOutputs = [];
        int nOutputs = dailySchedule.getOutputs(arrOutputs);
        if (nOutputs > 1) {
          List<Pair<String, String>> aItems = [];
          for (int nOutput = 0; nOutput < nOutputs; nOutput++) {
            String strEvent = dailySchedule.getEventByOutput(dtDate!, nOutput);
            if (strEvent.isNotEmpty) {
              addToEventList(strEvent);
            }
            if (strEvent.isEmpty && await hasDCMPlay(bDCMPlay)) {
              strEvent = 'dcmplay';
            }

            Pair<String, String> keyEvent =
                Pair<String, String>(arrOutputs[nOutput], strEvent);
            aItems.add(keyEvent);

            logI(
                '''Generating Calendar date:'$strDate'; output:'$nOutput' playlist:'$strEvent' play method:'2'!''');
          }

          String strInfo = 'Multi Ouput';
          String strEvent = 'Multi Playlist';
          XmlItem? hNewItem = destfile.getChannelDayItem(nDay, hChannelDest);
          if (hNewItem != null) {
            destfile.setChannelScheduleEvent(hNewItem, strEvent);
            destfile.setChannelScheduleInfo(hNewItem, strInfo);
            destfile.setChannelSchedulePlayMeth(hNewItem, 2);
            destfile.setChannelScheduleEvents(hNewItem, aItems);
          }

          if (bLog) {
            writeScheduleLog(xmlLog, strEvent, strDate, strInfo);
          }
        } else {
          String strEvent = '';
          String strInfo = '';
          int nPMethod = 0;

          List<Pair<String, String>> arrEvents = [];
          XmlItem? pDayItem = dailySchedule.getDayItemByOutput(dtDate: dtDate);
          if (pDayItem != null) {
            strEvent = dailySchedule.getEvent(pDayItem);
            arrEvents = dailySchedule.getEvents(pDayItem);
            nPMethod = dailySchedule.getPMethod(pDayItem);
          }
          if (strEvent.isEmpty &&
              arrEvents.isEmpty &&
              await hasDCMPlay(bDCMPlay)) {
            strEvent = 'dcmplay';
          }

          if (bInclude && nDay == nToday) {
            _strTodayEventNew = strEvent;
          }
          if (arrEvents.isNotEmpty) {
            addToEventLists(arrEvents);
          } else {
            addToEventList(strEvent);
          }

          XmlItem? hNewItem = destfile.getChannelDayItem(nDay, hChannelDest);
          if (hNewItem != null) {
            destfile.setChannelScheduleEvent(hNewItem, strEvent);
            destfile.setChannelScheduleInfo(hNewItem, strInfo);
            destfile.setChannelSchedulePlayMeth(hNewItem, nPMethod);
            destfile.setChannelScheduleEvents(hNewItem, arrEvents);
          }
          logI(
              '''Generating Calendar date:'$strDate'; playlist:'$strEvent' play method:'$nPMethod'!''');
          if (bLog) {
            writeScheduleLog(xmlLog, strEvent, strDate, strInfo);
          }
        }
      }
      xmlLog.saveProfile('ftperror.xsl');

      destfile.setFileVersion(1);
      destfile.setNextUniqueID(destfile.getNextUniqueID());
      destfile.save(strDestFile);

      return (await genOldMonthSchedule(destfile));
    }

    return false;
  }

  Future<void> writeDefaultEvent(DailyScheduleFile dailySchedule) async {
    if (DateFormat('yyyyMM').format(DateTime.now()) == strMonth) {
      String strDefaEvent = path.join(AppGlobal.tempPath, 'DefaultEvent.ini');
      var eventFile = File(strDefaEvent);
      if (await eventFile.exists()) {
        await eventFile.delete();
      }

      IniFile settingsFile = IniFile(strDefaEvent);
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      settingsFile.writeString('Version', 'VersionNo', packageInfo.version);
      for (var it in dailySchedule.mapEventDefa.keys) {
        String strID = 'Output$it';
        settingsFile.writeString(
            'DefaultEvent', strID, dailySchedule.mapEventDefa[it]!);
      }
      settingsFile.save(strDefaEvent);
    }
  }

  Future<bool> genOldMonthSchedule(ChannelScheduleFile destfile) async {
    XmlItem? hScheduleItem = destfile.getChannelScheduleItem(null, bNew: false);
    List<DayInfoData> lstDayInfo = [];
    if (hScheduleItem != null) {
      XmlItem? hDayItem = destfile.getFirstChannelSchedule(hScheduleItem);
      while (hDayItem != null) {
        DayInfoData pData = DayInfoData();
        pData.day = destfile.getChannelScheduleDay(hDayItem);
        pData.event = destfile.getChannelScheduleEvent(hDayItem);
        pData.info = destfile.getChannelScheduleInfo(hDayItem);
        pData.arrEvent = destfile.getChannelScheduleEvents(hDayItem);
        pData.playMeth = destfile.getChannelSchedulePlayMeth(hDayItem);

        lstDayInfo.add(pData);

        hDayItem = destfile.getNextChannelSchedule(hDayItem);
      }
    }

    String strTempFile =
        await PlayerPathService.getExistedTempPath(cDCMMONTHTYPE) ?? '';
    String strFileName = path.join(strTempFile, '$strMonth.xml');

    bool bSuccess = false;
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    xmlProfile.loadProfile(szRootItemName: 'MonthlySchedule');
    // write some stuff in the profile
    xmlProfile.writeProfileString('ScheduleSetting', 'Month', strMonth);
    DayInfoData.writeDayInfoList(xmlProfile, lstDayInfo);
    bSuccess = xmlProfile.saveProfile();

    return bSuccess;
  }

  static bool addToEventLists(List<Pair<String, String>> aItems) {
    if (aItems.isNotEmpty) {
      for (int i = 0; i < aItems.length; i++) {
        if (!arrEvent.contains(aItems[i].value)) {
          arrEvent.add(aItems[i].value);
        }
      }

      return true;
    }

    return false;
  }

  static bool addToEventList(String strEvent) {
    if (strEvent.isEmpty) {
      return false;
    }

    if (!arrEvent.contains(strEvent)) {
      arrEvent.add(strEvent);
    }

    return true;
  }
}
