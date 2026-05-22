import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xml_settings/channel_schedule_file.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

class ChannelScheduleImpl {
  String lastError = '';

  bool saveSchedule(List<DayInfoData> lstDayInfo, String channelName,
      {String? strSchedule, DateTime? dtSchedule}) {
    ChannelScheduleFile file = ChannelScheduleFile();
    if (file.loadFile(filePath: strSchedule, dtSchedule: dtSchedule)) {
      XmlItem? hScheduleItem = file.getChannelScheduleItem(channelName);
      if (hScheduleItem == null) {
        file.deleteChannelDayItem(hScheduleItem!);
      }

      for (var pData in lstDayInfo) {
        XmlItem? hDayItem = file.getChannelDayItem(pData.day, hScheduleItem);
        if (hDayItem != null) {
          file.setChannelScheduleEvent(hDayItem, pData.event);
          file.setChannelScheduleInfo(hDayItem, pData.info);
          file.setChannelSchedulePlayMeth(hDayItem, pData.playMeth);
          file.setChannelScheduleEvents(hDayItem, pData.arrEvent);
        }
      }
      file.setFileVersion(1);
      file.setNextUniqueID(file.getNextUniqueID());

      return file.saveEx();
    }

    return false;
  }

  List<DayInfoData> loadSchedule(String channelName,
      {String? scheduleMonth, DateTime? dtSchedule, String? schedulePath}) {
    if (scheduleMonth == null && dtSchedule != null) {
      scheduleMonth = DateFormat('yyyyMM').format(dtSchedule);
    }
    List<DayInfoData> lstDayInfo = [];

    String strPath =
        ((schedulePath == null) ? DCMGlobal.calendarPath : schedulePath);
    String strFileName = path.join(strPath, '$scheduleMonth.xml');

    String strPath1 =
        ((schedulePath == null) ? DCMGlobal.monthPath : schedulePath);
    String strFileName1 = path.join(strPath1, '$channelName$scheduleMonth.xml');
    if (File(strFileName1).existsSync()) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName1);
      if (xmlProfile.loadProfile(szRootItemName: 'MonthlySchedule')) {
        lstDayInfo = xmlProfile.getProfileList('DayInfoList', DayInfoData());
      }
    } else {
      ChannelScheduleFile file = ChannelScheduleFile();
      if (file.loadFile(filePath: strFileName)) {
        XmlItem? hScheduleItem =
            file.getChannelScheduleItem(channelName, bNew: false);
        if (hScheduleItem != null) {
          XmlItem? hDayItem = file.getFirstChannelSchedule(hScheduleItem);
          while (hDayItem != null) {
            DayInfoData pData = DayInfoData();
            pData.day = file.getChannelScheduleDay(hDayItem);
            pData.event = file.getChannelScheduleEvent(hDayItem);
            pData.info = file.getChannelScheduleInfo(hDayItem);
            pData.arrEvent = file.getChannelScheduleEvents(hDayItem);
            pData.playMeth = file.getChannelSchedulePlayMeth(hDayItem);

            lstDayInfo.add(pData);

            hDayItem = file.getNextChannelSchedule(hDayItem);
          }
        }
      }
    }

    return lstDayInfo;
  }

  bool loadScheduleFile(
      String channelName, String scheduleFile, ChannelScheduleFile file) {
    if (file.loadScheduleFile(scheduleFile) &&
        file.getFirstChannelSchedule() != null) {
      return true;
    }
    file.reset();
    file.close();

    if (File(scheduleFile).existsSync()) {
      XmlProfile xmlProfile = XmlProfile.fromFile(scheduleFile);
      if (xmlProfile.loadProfile(szRootItemName: 'MonthlySchedule')) {
        List<DayInfoData> lstDayInfo =
            xmlProfile.getProfileList('DayInfoList', DayInfoData());
        xmlProfile.close();

        File(scheduleFile).deleteSync();
        if (File(scheduleFile).existsSync()) {
          if (!file.loadScheduleFile(scheduleFile)) {
            return false;
          }
        }
        XmlItem? hScheduleItem = file.getChannelScheduleItem(channelName);
        if (hScheduleItem != null) {
          for (var pData in lstDayInfo) {
            //XmlItem hDayItem = file.NewChannelSchedule(pData.nDay, hScheduleItem);
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
        file.setFileVersion(1);
        file.setNextUniqueID(file.getNextUniqueID());

        return (file.save(scheduleFile));
      }
    }

    return false;
  }

  bool deleteChannel(String channelName) {
    try {
      final directory = Directory(DCMGlobal.calendarPath);
      if (!directory.existsSync()) {
        return true;
      }

      final fileRegex = RegExp(r'^\d{4}(0?[1-9]|1[0-2])\.xml$');
      for (final entity in directory.listSync()) {
        if (entity is File && fileRegex.hasMatch(path.basename(entity.path))) {
          final file = ChannelScheduleFile();
          if (!file.loadScheduleFile(entity.path)) {
            continue;
          }

          final XmlItem? channelItem =
              file.getChannelScheduleItem(channelName, bNew: false);
          if (channelItem != null) {
            file.deleteChannelSchedule(channelItem);
            file.saveSchedule(filePath: entity.path);
          }
        }
      }

      return true;
    } catch (e) {
      lastError = 'DeleteChannel error: $e';
      return false;
    }
  }

  static void changeToPlaylist(String playlist, [DateTime? dtDay]) {
    dtDay ??= DateTime.now();
    DateTime dtSchedule = dtDay;
    int nDay = dtSchedule.day;
    ChannelScheduleFile file = ChannelScheduleFile();
    try {
      if (file.loadFile(dtSchedule: dtSchedule)) {
        String strChannelName = '';
        XmlItem? hScheduleItem = file.getChannelScheduleItem(strChannelName);
        if (hScheduleItem != null) {
          XmlItem? hDayItem = file.getChannelDayItem(nDay, hScheduleItem);
          if (hDayItem != null) {
            var aItems = file.getChannelScheduleEvents(hDayItem);
            if (aItems.isNotEmpty) {
              file.setChannelScheduleEvent(hDayItem, playlist);
              file.setChannelScheduleInfo(hDayItem, playlist);
              //file.setChannelSchedulePlayMeth(hDayItem, 0);
            } else {
              aItems[0] = Pair(aItems[0].key, playlist);
              file.setChannelScheduleEvent(hDayItem, playlist);
              file.setChannelScheduleInfo(hDayItem, playlist);
              file.setChannelScheduleEvents(hDayItem, aItems);
              //file.setChannelSchedulePlayMeth(hDayItem, SEQUENCE_PLAYLIST);
            }

            file.setFileVersion(1);
            file.setNextUniqueID(file.getNextUniqueID());
            file.saveEx();
          }
        }
      }

      String strFileName = path.join(DCMGlobal.monthPath,
          '${DateFormat('yyyyMM').format(dtSchedule)}.xml');
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
      if (xmlProfile.loadProfile(szRootItemName: 'MonthlySchedule')) {
        var lstDayInfo =
            xmlProfile.getProfileList('DayInfoList', DayInfoData());

        bool bExisted = false;
        for (var pData in lstDayInfo) {
          if (pData.day == nDay) {
            //pData.nPlayMeth = SEQUENCE_PLAYLIST;
            if (pData.arrEvent.isEmpty) {
              pData.event = playlist;
            } else {
              pData.arrEvent[0] = Pair(pData.arrEvent[0].key, playlist);
            }
            bExisted = true;
            break;
          }
        }
        if (!bExisted) {
          DayInfoData pData = DayInfoData();
          pData.day = nDay;
          pData.event = playlist;
          pData.playMeth = SchedulePlayMeth.eSEQUENCEPLAYLIST.index;

          lstDayInfo.add(pData);
        }

        // write some stuff in the profile
        xmlProfile.writeProfileString('ScheduleSetting', 'Month',
            DateFormat('yyyyMM').format(dtSchedule));
        xmlProfile.writeProfileList('DayInfoList', lstDayInfo);

        xmlProfile.saveProfile();
      }
    } catch (e) {
      logE('ChangeToPlaylist error: $e');
    }
  }

  static void changeToLatestPlaylist(DayInfoData dayInfo,
      [DateTime? dtStart, int totalDay = 7]) {
    DateTime dtDay = dtStart ?? DateTime.now().add(const Duration(days: 1));
    String startMonth = DateFormat('yyyyMM').format(dtDay);
    DateTime dtSchedule = dtDay;
    final List<int> lstSelDays = [];

    for (int j = 0; j <= totalDay; j++) {
      final String currentMonth = DateFormat('yyyyMM').format(dtDay);
      if (j == totalDay || currentMonth != startMonth) {
        changeToLatestPlaylistForDays(dayInfo, dtSchedule, lstSelDays);
        if (j == totalDay) {
          break;
        }
        startMonth = currentMonth;
        lstSelDays.clear();
        lstSelDays.add(dtDay.day);
        dtSchedule = dtDay;
      } else {
        lstSelDays.add(dtDay.day);
      }
      dtDay = dtDay.add(const Duration(days: 1));
    }
  }

  static void changeToLatestPlaylistForDays(
      DayInfoData dayInfo, DateTime dtDay, List<int> lstDays) {
    DateTime dtSchedule = dtDay;
    final String scheduleMonth = DateFormat('yyyyMM').format(dtDay);
    final file = ChannelScheduleFile();
    bool bSave = false;
    bool bExisted = false;
    String strChannelName = '';
    try {
      if (file.loadFile(dtSchedule: dtSchedule)) {
        XmlItem? hScheduleItem =
            file.getChannelScheduleItem(strChannelName, bNew: false);
        if (hScheduleItem != null) {
          bExisted = true;
          for (var it in lstDays) {
            bool bDayExisted = false;
            XmlItem? hDayItem =
                file.getChannelDayItem(it, hScheduleItem, bNew: false);
            if (hDayItem != null) {
              var aItems = file.getChannelScheduleEvents(hDayItem);
              String strPlaylist = file.getChannelScheduleEvent(hDayItem);
              if (aItems.isEmpty) {
                if (strPlaylist.isNotEmpty) {
                  bDayExisted = true;
                }
              } else {
                for (int i = 0; i < aItems.length; i++) {
                  if (aItems[i].value.isNotEmpty) {
                    bDayExisted = true;
                    break;
                  }
                }
              }
            }
            if (!bDayExisted) {
              hDayItem ??= file.getChannelDayItem(it, hScheduleItem);
              if (hDayItem != null) {
                file.setChannelScheduleEvent(hDayItem, dayInfo.event);
                file.setChannelScheduleInfo(hDayItem, dayInfo.info);
                file.setChannelScheduleEvents(hDayItem, dayInfo.arrEvent);
                file.setChannelSchedulePlayMeth(hDayItem, dayInfo.playMeth);
              }
              bSave = true;
            }
          }
        }
      }
      if (!bExisted) {
        bSave = true;
        XmlItem? hScheduleItem = file.getChannelScheduleItem(strChannelName);
        if (hScheduleItem != null) {
          for (var it in lstDays) {
            XmlItem? hDayItem = file.getChannelDayItem(it, hScheduleItem);
            if (hDayItem != null) {
              file.setChannelScheduleEvent(hDayItem, dayInfo.event);
              file.setChannelScheduleInfo(hDayItem, dayInfo.info);
              file.setChannelScheduleEvents(hDayItem, dayInfo.arrEvent);
              file.setChannelSchedulePlayMeth(hDayItem, dayInfo.playMeth);
            }
          }
        }
      }
      if (bSave) {
        file.setFileVersion(1);
        file.setNextUniqueID(file.getNextUniqueID());
        file.saveEx();
      }

      String strFileName = path.join(DCMGlobal.monthPath, '$scheduleMonth.xml');
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
      if (xmlProfile.loadProfile(szRootItemName: 'MonthlySchedule')) {
        List<int> lstExists = [];
        var lstDayInfo =
            xmlProfile.getProfileList('DayInfoList', DayInfoData());

        for (var pData in lstDayInfo) {
          if (lstDays.contains(pData.day)) {
            bool bDayExisted = false;
            if (pData.arrEvent.isEmpty) {
              if (pData.event.isNotEmpty) {
                bDayExisted = true;
              }
            } else {
              for (int i = 0; i < pData.arrEvent.length; i++) {
                if (pData.arrEvent[i].value.isNotEmpty) {
                  bDayExisted = true;
                  break;
                }
              }
            }

            if (!bDayExisted) {
              pData = DayInfoData.copy(dayInfo); // = *pDayInfo;
            }
            lstExists.add(pData.day);
          }
        }

        for (var it in lstDays) {
          if (!lstExists.contains(it)) {
            DayInfoData pData = DayInfoData.copy(dayInfo);
            pData.day = it;

            lstDayInfo.add(pData);
          }
        }

        // write some stuff in the profile
        xmlProfile.reset();
        if (xmlProfile.createProfile('MonthlySchedule')) {
          xmlProfile.writeProfileString(
              'ScheduleSetting', 'Month', scheduleMonth);
          xmlProfile.writeProfileList('DayInfoList', lstDayInfo);

          xmlProfile.saveProfile();
        }
      }
    } catch (e) {
      logE('ChangeToLatestPlaylistForDays error: $e');
    }
  }
}
