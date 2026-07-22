import 'dart:io';

import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/xmlfile/xmlfiledata.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

class DayInfoData extends XmlFileData {
  int day = 0;
  String event = '';
  String info = '';
  int playMeth = 0;
  int approvalLevel = 0;
  int approvalStatus = 0;
  String userCode = '';
  String groupCode = '';
  DateTime? modified;
  DateTime? created;

  List<Pair<String, String>> arrEvent = [];

  DayInfoData();

  DayInfoData.copy(DayInfoData other) {
    day = other.day;
    event = other.event;
    info = other.info;
    playMeth = other.playMeth;
    approvalLevel = other.approvalLevel;
    approvalStatus = other.approvalStatus;
    userCode = other.userCode;
    groupCode = other.groupCode;
    modified = other.modified;
    created = other.created;
    arrEvent = other.arrEvent.map((entry) {
      final copy = Pair<String, String>(entry.key, entry.value);
      return copy;
    }).toList();
  }

  @override
  void writeToXML(XmlItem pXmlItem) {
    XmlItem? xi = pXmlItem.addItem('Day$day');
    if (xi == null) return;

    xi.addItem('m_nDay', day);
    xi.addItem('m_nPlayMeth', playMeth);
    xi.addItem('m_strEvent', event);
    XmlItem? xiEventArray = xi.addItem('m_arrEvent');
    if (xiEventArray != null) {
      for (var entry in arrEvent) {
        XmlItem? xiEvent = xiEventArray.addItem('String');
        if (xiEvent != null) {
          xiEvent.addItem('Name', entry.key);
          xiEvent.addItem('Value', entry.value);
        }
      }
    }
    xi.addItem('m_strInfo', info);
    xi.addItem('m_nApprovalLevel', approvalLevel);
    xi.addItem('m_nApprovalStatus', approvalStatus);
    xi.addItem('m_strUserCode', userCode);
    xi.addItem('m_strGroupCode', groupCode);
    xi.addItem('m_dtmodified', modified);
    xi.addItem('m_dtCreated', created);
  }

  @override
  void getFromXML(XmlItem pXmlItem) {
    arrEvent.clear();
    event = pXmlItem.getItemValue('m_strEvent');
    day = pXmlItem.getItemValueI('m_nDay');
    playMeth = pXmlItem.getItemValueI('m_nPlayMeth');
    info = pXmlItem.getItemValue('m_strInfo');
    approvalLevel = pXmlItem.getItemValueI('m_nApprovalLevel');
    approvalStatus = pXmlItem.getItemValueI('m_nApprovalStatus');
    userCode = pXmlItem.getItemValue('m_strUserCode');
    groupCode = pXmlItem.getItemValue('m_strGroupCode');
    modified = pXmlItem.getItemValueD('m_dtmodified');
    created = pXmlItem.getItemValueD('m_dtCreated');

    XmlItem? xiEventArray = pXmlItem.getItem('m_arrEvent');
    while (xiEventArray != null) {
      XmlItem? pEvent = xiEventArray.getItem('String');
      while (pEvent != null) {
        final key = Pair<String, String>(
            pEvent.getItemValue('Name'), pEvent.getItemValue('Value'));
        arrEvent.add(key);
        pEvent = pEvent.getSibling();
      }
      break;
    }
  }

  @override
  XmlFileData? createObject() {
    return DayInfoData();
  }

  void getPlaylists(List<String> playlists) {
    if (arrEvent.isEmpty) {
      if (event.isNotEmpty && !playlists.contains(event)) {
        playlists.add(event);
      }
    } else {
      for (var entry in arrEvent) {
        if (entry.value.isNotEmpty && !playlists.contains(entry.value)) {
          playlists.add(entry.value);
        }
      }
    }
  }

  bool isEventExisted() {
    if (event.isEmpty) return false;
    String dir = DCMGlobal.dayPath;
    if (dir.isEmpty) return false;

    String fileName = path.join(dir, '$event.xml');
    return File(fileName).existsSync();
  }

  static List<DayInfoData> readDayInfoList(XmlProfile xmlProfile) {
    XmlItem? pXItem = xmlProfile.getItem('DayInfoList');
    List<DayInfoData> lstDayInfo = [];
    if (pXItem != null) {
      var pos = pXItem.getFirstItemPos();
      while (pos.moveNext()) {
        XmlItem? xiDayItem = pos.current;
        DayInfoData pObject = DayInfoData();
        lstDayInfo.add(pObject);
        pObject.getFromXML(xiDayItem);
      }
    }

    return lstDayInfo;
  }

  static bool writeDayInfoList(
      XmlProfile xmlProfile, List<DayInfoData> lstDayInfo) {
    XmlItem? xi = xmlProfile.root().newItem('DayInfoList'); //
    if (xi != null) {
      for (var iter in lstDayInfo) {
        iter.writeToXML(xi);
      }

      return true;
    }

    return false;
  }
}
