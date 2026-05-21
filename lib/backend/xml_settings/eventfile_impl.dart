import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:path/path.dart' as path;

// 事件文件实现类
class EventFileImpl {
  static const String lpszEventSignature = "DCMPlayer Event Document";

  EventFileImpl();

  // 序列化
  bool serialize(EventFileData pData, String strFilename,
      [bool bStoring = true]) {
    if (bStoring) {
      XmlFilePro eventFile = XmlFilePro('EventDocument');

      eventFile.setDataNode(null, 'm_uiID', pData.uiID);
      eventFile.setDataNode(null, 'm_strDocVersion', pData.strDocVersion);
      eventFile.setDataNode(
          null, 'm_strOrganizationId', pData.strOrganizationId);
      eventFile.setDataNode(null, 'm_strScheduleName', pData.strScheduleName);
      eventFile.setDataNode(null, 'm_strScheduleDesc', pData.strScheduleDesc);
      eventFile.setDataNode(null, 'm_nGroupLoop', pData.nGroupLoop);
      eventFile.setDataNode(null, 'm_nGroupNumber', pData.nGroupNumber);
      eventFile.setDataNode(null, 'm_bAutoPlay', pData.bAutoPlay);
      eventFile.setDataNode(null, 'm_bIsTimeSchedule', pData.bIsTimeSchedule);
      eventFile.setDataNode(null, 'm_strStartTime2', pData.strStartTime2);
      eventFile.setDataNode(null, 'm_strEndTime2', pData.strEndTime2);
      eventFile.setDataNode(null, 'm_bStopAndQuit', pData.bStopAndQuit);
      eventFile.setDataNode(null, 'm_dtStart', pData.dtStart, true);
      eventFile.setDataNode(null, 'm_dtEnd', pData.dtEnd, true);

      eventFile.setDataNode(null, 'm_strUserCode', pData.strUserCode);
      eventFile.setDataNode(null, 'm_strGroupCode', pData.strGroupCode);
      eventFile.setDataNode(null, 'm_dtmodified', pData.dtModified, true);
      eventFile.setDataNode(null, 'm_dtCreated', pData.dtCreated, true);

      // Save the Event item  information
      //IXmlItem *pItem = EventFile.AddDataNode('m_lstPlayList', NULL);
      if (pData.lstPlayList != null) {
        for (var item in pData.lstPlayList!) {
          XmlItem? xiEventItem = eventFile.addDataNode('CEventItemData', null);
          if (xiEventItem != null) {
            item.writeToXML(xiEventItem);
          }
        }
      }

      eventFile.setSignature(lpszEventSignature);

      return eventFile.save(strFilename);
    } else {
      XmlFilePro file = XmlFilePro('EventDocument', null);
      if (!file.open(strFilename, XfOpen.read, false)) {
        return false;
      }

      if (file.loadEx()) {
        return serializeFrom(pData, file);
      }
      return false;
    }
  }

  bool serializeFrom(EventFileData pData, XmlFilePro file) {
    // file header info
    String sXmlHeader = file.getSignature();
    if (sXmlHeader == lpszEventSignature) {
      pData.uiID = file.getItemValueI('m_uiID');
      pData.strOrganizationId = file.getItemValue('m_strOrganizationId');
      pData.strDocVersion = file.getItemValue('m_strDocVersion');
      pData.nGroupLoop = file.getItemValueI('m_nGroupLoop');
      pData.nGroupNumber = file.getItemValueI('m_nGroupNumber');
      pData.strScheduleName = file.getItemValue('m_strScheduleName');
      pData.strScheduleDesc = file.getItemValue('m_strScheduleDesc');
      pData.bIsTimeSchedule = file.getItemValueB('m_bIsTimeSchedule');
      pData.bAutoPlay = file.getItemValueB('m_bAutoPlay');
      pData.bStopAndQuit = file.getItemValueB('m_bStopAndQuit');
      pData.strStartTime2 = file.getItemValue('m_strStartTime2');
      pData.strEndTime2 = file.getItemValue('m_strEndTime2');
      pData.dtStart = file.getItemValueD('m_dtStart');
      pData.dtEnd = file.getItemValueD('m_dtEnd');
      pData.strUserCode = file.getItemValue('m_strUserCode');
      pData.strGroupCode = file.getItemValue('m_strGroupCode');
      pData.dtModified = file.getItemValueD('m_dtmodified');
      pData.dtCreated = file.getItemValueD('m_dtCreated');

      // get Event Item information list
      //IXmlItem *pItem = file.GetItem('m_lstPlayList');
      //IXmlItem* pXISibling = pItem->GetItem('CEventItemData');
      pData.removeAllPlayList();
      XmlItem? pXISibling = file.getItem('CEventItemData');
      while (pXISibling != null) {
        EventItemData pItem = EventItemData();

        // get Playlist Inforamtion data
        pItem.getFromXML(pXISibling);

        // add Player Channel data to list
        pData.addPlayList(pItem);

        pXISibling = pXISibling.getSibling();
      }
      return true;
    }

    return false;
  }

  // 检查事件是否存在
  static bool isEventExisted(String strEventFile,
      {String? company, bool monthSchedule = true}) {
    EventFileImpl eventFileImpl = EventFileImpl();
    return eventFileImpl.eventExists(strEventFile,
        strCompany: company, bMonthSchedule: monthSchedule);
  }

  // 事件是否存在
  bool eventExists(String strEventFile,
      {String? strCompany, bool bMonthSchedule = true}) {
    String strFileName = '';
    if (strCompany == null || strCompany.isEmpty) {
      strFileName = path.join(DCMGlobal.dayPath, '$strEventFile.xml');
      if (!bMonthSchedule) {
        if (File(strFileName).existsSync()) {
          return true;
        }
        strFileName = path.join(App().dataPath, '$strEventFile.xml');
      }
    } else {
      strFileName =
          path.join(DCMGlobal.dayPath, strCompany, '$strEventFile.xml');
      if (!bMonthSchedule) {
        if (File(strFileName).existsSync()) {
          return true;
        }
        strFileName =
            path.join(App().dataPath, strCompany, '$strEventFile.xml');
      }
    }

    return File(strFileName).existsSync();
  }

  // 保存播放列表
  bool savePlayList(EventFileData pData, String strEventFile,
      {String? strCompany, bool bMonthSchedule = true}) {
    String strFileName =
        Utils.getFilePath(strEventFile, cDCMDAYTYPE, -1, strCompany);

    return serialize(pData, strFileName, true);
  }

  // 加载播放列表
  bool loadPlayList(EventFileData pData, String strEventFile,
      {String? strCompany, bool bMonthSchedule = true}) {
    String strFileName =
        Utils.getFilePath(strEventFile, cDCMDAYTYPE, -1, strCompany);

    return loadPlayListByFilePath(pData, strFileName);
  }

  // 通过文件路径加载播放列表
  bool loadPlayListByFilePath(EventFileData pData, String strFilePath) {
    pData.removeAllPlayList();

    if (File(strFilePath).existsSync()) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFilePath);
      if (xmlProfile.loadProfile(szRootItemName: 'PlayListAndSetting')) {
        pData.strScheduleName =
            xmlProfile.getProfileString('PlaySetting', 'm_strScheduleName', '');
        pData.strScheduleDesc =
            xmlProfile.getProfileString('PlaySetting', 'm_strScheduleDesc', '');
        String strAutoPlay =
            xmlProfile.getProfileString('PlaySetting', 'm_bAutoPlay', 'FALSE');
        pData.bAutoPlay = (strAutoPlay == 'TRUE' ? true : false);
        String strTimeSchedule = xmlProfile.getProfileString(
            'PlaySetting', 'm_bIsTimeSchedule', 'FALSE');
        pData.bIsTimeSchedule = (strTimeSchedule == 'TRUE' ? true : false);
        String strStopAndQuit = xmlProfile.getProfileString(
            'PlaySetting', 'm_bStopAndQuit', 'FALSE');
        pData.bStopAndQuit = (strStopAndQuit == 'TRUE' ? true : false);
        DateTime dtDefault = DateTime.now();
        dtDefault = dtDefault.copyWith(hour: 0, minute: 0, second: 0);
        pData.dtStart = xmlProfile.getProfileDateTime(
            'PlaySetting', 'm_dtStart', dtDefault);
        dtDefault = dtDefault.copyWith(hour: 23, minute: 59, second: 59);
        pData.dtEnd =
            xmlProfile.getProfileDateTime('PlaySetting', 'm_dtEnd', dtDefault);
        pData.strStartTime2 = xmlProfile.getProfileString(
            'PlaySetting', 'm_strStartTime2', '00:00:00');
        pData.strEndTime2 = xmlProfile.getProfileString(
            'PlaySetting', 'm_strEndTime2', '00:00:00');
        pData.nGroupLoop =
            xmlProfile.getProfileInt('PlaySetting', 'm_nGroupLoop', 0);
        pData.nGroupNumber =
            xmlProfile.getProfileInt('PlaySetting', 'm_nGroupNumber', 1);

        pData.nApprovalLevel =
            xmlProfile.getProfileInt('PlaySetting', 'm_nApprovalLevel', 0);
        pData.nApprovalStatus =
            xmlProfile.getProfileInt('PlaySetting', 'm_nApprovalStatus', 0);

        //xmlProfile.getProfileList('PlayFileList', RUNTIME_CLASS(CPlayListData), pData->m_lstPlayList);
        List<PlayListData> lstPlayList = [];
        XmlItem? pXItem = xmlProfile.getItem('PlayFileList');
        if (pXItem != null) {
          var pos = pXItem.getFirstItemPos();
          while (pos.moveNext()) {
            PlayListData pObject = PlayListData();
            lstPlayList.add(pObject);
            pObject.getFromXML(pos.current);
          }
        }

        pData.lstPlayList = [];
        if (pData.strStartTime2 == '00:00:00' &&
            pData.strEndTime2 == '00:00:00') {
          for (var playListData in lstPlayList) {
            EventItemData pEventItem =
                EventItemData.fromPlayListData(playListData);
            pData.lstPlayList!.add(pEventItem);
          }
        } else {
          EventItemData? pGroupItem;
          for (var playListData in lstPlayList) {
            if (playListData.bIsTimeSchedule) {
              if (pGroupItem == null) {
                pGroupItem = EventItemData.fromPlayListData(playListData);
                pGroupItem.arrTimeItems = [];
                pGroupItem.arrTimeItems!.add(TimeItem(
                    dtStart: pData.strStartTime2, dtEnd: pData.strEndTime2));
                pGroupItem.nItemType = EventItemType.group;
                pGroupItem.uiGroupID = 0;
              }
              pGroupItem.arrDCMFile = [];
              pGroupItem.arrDCMFile!.add(playListData.strDCMFile);
            } else {
              EventItemData pEventItem =
                  EventItemData.fromPlayListData(playListData);
              pData.lstPlayList!.add(pEventItem);
            }
          }
          if (pGroupItem != null) {
            pData.lstPlayList!.add(pGroupItem);
          }
        }

        return true;
      }
    }

    return false;
  }

  // 保存到XML
  bool saveToXML(String strEventName, EventFileData pData,
      {String? strCompany, bool bMonthSchedule = true}) {
    if (DCMGlobal.multiGroup == 2) {
      String strFileName =
          Utils.getFilePath(strEventName, cDCMDAYTYPE, -1, strCompany);
      if (serialize(pData, strFileName, true)) {
        // 这里可以添加校验和计算逻辑
        return true;
      }

      return false;
    } else {
      return savePlayList(pData, strEventName,
          strCompany: strCompany, bMonthSchedule: bMonthSchedule);
    }
  }

  // 从XML加载
  bool loadFromXML(String strEventName, EventFileData pData,
      {String? strCompany, bool bMonthSchedule = true}) {
    pData.removeAllPlayList();

    String strFileName =
        Utils.getFilePath(strEventName, cDCMDAYTYPE, -1, strCompany);
    if (File(strFileName).existsSync()) {
      return serialize(pData, strFileName, false);
    }

    return false;
  }

  // 删除事件
  bool deleteEvent(String szEvent) {
    String strEventName = szEvent;

    if (strEventName.isNotEmpty) {
      String strFilePath =
          Utils.getFilePath(strEventName, cDCMDAYTYPE, -1, null);
      if (File(strFilePath).existsSync()) {
        File(strFilePath).deleteSync();
        return true;
      }
    }

    return false;
  }

  // 删除事件（通过数据对象）
  bool deleteEventByData(EventFileData pData) {
    return deleteEvent(pData.strScheduleName);
  }

  // 删除所有事件
  bool deleteEventAll({bool bEmptyAll = false}) {
    return true;
  }

  // 添加事件
  bool addEvent(EventFileData pData) {
    return saveToXML(pData.strScheduleName, pData);
  }

  // 更新事件
  bool updateEvent(EventFileData pData) {
    return saveToXML(pData.strScheduleName, pData);
  }

  // 计算正常项目数量
  int countNormalItem(EventFileData pData, {bool bIsMultiGroup = false}) {
    int nCount = 0;
    for (EventItemData pPlayListData in pData.lstPlayList!) {
      if (!bIsMultiGroup) {
        if (pPlayListData.isNormalItem()) {
          nCount++;
        }
      } else {
        if (!pPlayListData.bIsTimeSchedule && pPlayListData.isGroupItem()) {
          nCount++;
        }
      }
    }
    return nCount;
  }
}
