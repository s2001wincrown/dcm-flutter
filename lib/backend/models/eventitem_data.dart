import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';

// 事件项类型枚举
enum EventItemType {
  normal(0),
  insert(1),
  group(2),
  rtGroup(3),
  eventDisplay(4),
  wallpaper(5);

  const EventItemType(this.value);
  final int value;
}

// 时间项目结构
class TimeItem {
  String dtStart = '';
  String dtEnd = '';

  TimeItem({this.dtStart = '', this.dtEnd = ''});
}

// 播放列表数据类（辅助类）
class PlayListData {
  int uiID = -1;
  String strDCMFile = '';
  int nPlayTimes = 0;
  String dtStart = '00:00:00';
  String dtEnd = '00:00:00';
  bool bIsTimeSchedule = false;
  bool bIsGroup = false;
  List<String>? arrDCMFile;
  List<TimeItem>? arrTimeItems;

  PlayListData();

  void writeToXML(XmlItem pXmlItem) {
    XmlItem? xi = pXmlItem.getItem("PlayFile$uiID");
    if (xi != null) {
      xi.setItemValue('m_uiID', uiID, XiType.element);
      xi.setItemValue('m_strDCMFile', strDCMFile, XiType.element);
      xi.setItemValue('m_nPlayTimes', nPlayTimes, XiType.element);
      xi.setItemValue('m_dtStart', dtStart, XiType.element);
      xi.setItemValue('m_dtEnd', dtEnd, XiType.element);
      xi.setItemValue('m_bIsTimeSchedule', bIsTimeSchedule, XiType.element);
      xi.setItemValue('m_bIsGroup', bIsGroup, XiType.element);
      if (arrDCMFile != null) {
        xi.setItemValueArray(
            arrDCMFile!, 'm_arrDCMFile', 'DCMFile', XiType.element);
      }

      if (arrTimeItems != null) {
        XmlItem? pTimeItems = xi.addItem('m_arrTimeItems');
        if (pTimeItems != null) {
          for (int i = 0; i < arrTimeItems!.length; i++) {
            XmlItem? pTimeItem = pTimeItems.addItem('TimeItem$i');
            if (pTimeItem != null) {
              pTimeItem.setItemValue(
                  'm_dtStart', arrTimeItems![i].dtStart, XiType.element);
              pTimeItem.setItemValue(
                  'm_dtEnd', arrTimeItems![i].dtEnd, XiType.element);
            }
          }
        }
      }
    }
  }

  void getFromXML(XmlItem pXmlItem) {
    XmlItem? xi1 = pXmlItem.getItem('m_strDCMFile');
    if (xi1 != null) {
      strDCMFile = xi1.getValue();
    }
    XmlItem? xi2 = pXmlItem.getItem('m_nPlayTimes');
    if (xi2 != null) {
      nPlayTimes = xi2.getValueI();
    }
    XmlItem? xi3 = pXmlItem.getItem('m_uiID');
    if (xi3 != null) {
      uiID = xi3.getValueI();
    }
    XmlItem? xi4 = pXmlItem.getItem('m_dtStart');
    if (xi4 != null) {
      dtStart = xi4.getValue();
    }
    XmlItem? xi5 = pXmlItem.getItem('m_dtEnd');
    if (xi5 != null) {
      dtEnd = xi5.getValue();
    }
    XmlItem? xi6 = pXmlItem.getItem('m_bIsTimeSchedule');
    if (xi6 != null) {
      bIsTimeSchedule = xi6.getValueI() > 0;
    }
    XmlItem? xi7 = pXmlItem.getItem('m_bIsGroup');
    if (xi7 != null) {
      bIsGroup = xi7.getValueI() > 0;
    }
    /*CXmlItem xi8(pXmlItem->GetItem(_T("m_arrDCMFile")));
	if (xi8.IsValid())
	{
		xi8.GetItemValueArray(
		m_strDCMFile = xi1.GetValue();
	}*/
    //pXmlItem->GetItemValueArray(m_arrDCMFile, _T("m_arrDCMFile"), _T("DCMFile"));
    arrDCMFile = null;
    XmlItem? xi8 = pXmlItem.getItem('m_arrDCMFile');
    if (xi8 != null) {
      arrDCMFile = [];
      XmlItem? pFileItem = xi8.getItem('DCMFile');
      while (pFileItem != null) {
        arrDCMFile?.add(pFileItem.getValue());

        pFileItem = pFileItem.getSibling();
      }
    }

    //m_arrTimeItems.RemoveAll();
    arrTimeItems = null;
    XmlItem? xi9 = pXmlItem.getItem('m_arrTimeItems');
    if (xi9 != null) {
      arrTimeItems = [];
      int nCnt = 0;
      XmlItem? pTimeItem = xi9.getItem('TimeItem$nCnt');
      while (pTimeItem != null) {
        arrTimeItems?.add(TimeItem(dtStart: '', dtEnd: ''));
        int nItem = arrTimeItems!.length - 1;
        XmlItem? pStart = pTimeItem.getItem('m_dtStart');
        if (pStart != null) arrTimeItems![nItem].dtStart = pStart.getValue();

        XmlItem? pEnd = pTimeItem.getItem('m_dtEnd');
        if (pEnd != null) arrTimeItems![nItem].dtEnd = pEnd.getValue();

        nCnt++;
        pTimeItem = xi9.getItem('TimeItem$nCnt');
      }
    }
  }
}

// 事件项数据类
class EventItemData {
  int uiPID = 0;
  int uiEventID = 0;
  int uiCatalogueID = 0;
  int uiID = -1;
  int uiGroupID = -1;
  String strDCMFile = '';
  String dtStart = '00:00:00';
  String dtEnd = '00:00:00';
  int nPlayTimes = 0;
  EventItemType nItemType = EventItemType.normal;
  bool bIsTimeSchedule = false;
  bool bIsGroup = false;
  List<String>? arrDCMFile;
  List<int>? arrCatalogueID;

  List<TimeItem>? arrTimeItems;

  EventItemData();

  // 复制构造函数
  EventItemData.fromPlayListData(PlayListData playListData) {
    uiID = playListData.uiID;
    strDCMFile = playListData.strDCMFile;
    nPlayTimes = playListData.nPlayTimes;
    dtStart = playListData.dtStart;
    dtEnd = playListData.dtEnd;
    bIsTimeSchedule = playListData.bIsTimeSchedule;
    bIsGroup = playListData.bIsGroup;
    uiGroupID = -1;

    if (bIsTimeSchedule) {
      if (bIsGroup) {
        nItemType = EventItemType.group;
        uiGroupID = int.tryParse(playListData.strDCMFile) ?? -1;
      } else {
        nItemType = EventItemType.insert;
      }
    } else {
      nItemType = EventItemType.normal;
    }

    arrDCMFile = playListData.arrDCMFile != null
        ? List.from(playListData.arrDCMFile!)
        : null;
    arrTimeItems = null;
    if (playListData.arrTimeItems != null) {
      arrTimeItems = playListData.arrTimeItems!
          .map((item) => TimeItem(dtStart: item.dtStart, dtEnd: item.dtEnd))
          .toList();
    }
  }

  // 初始化事件显示项
  void initEventDisplayItem(int uiID, String strCatalogue,
      {String dtStart = '00:00:00', String dtEnd = '00:00:00'}) {
    uiID = uiID;
    uiGroupID = -1;
    strDCMFile = strCatalogue;
    dtStart = dtStart;
    dtEnd = dtEnd;
    nPlayTimes = 1;
    nItemType = EventItemType.eventDisplay;
    bIsTimeSchedule = true;
    bIsGroup = false;
  }

  // 复制到播放列表数据
  PlayListData copyToPlayListData() {
    PlayListData playListData = PlayListData();
    playListData.uiID = uiID;
    playListData.strDCMFile = strDCMFile;
    playListData.nPlayTimes = nPlayTimes;
    playListData.dtStart = dtStart;
    playListData.dtEnd = dtEnd;
    playListData.bIsTimeSchedule = bIsTimeSchedule;
    playListData.bIsGroup = bIsGroup;

    if (bIsTimeSchedule) {
      if (nItemType == EventItemType.group) {
        playListData.bIsGroup = true;
        playListData.strDCMFile = uiGroupID.toString();
      } else {
        playListData.bIsGroup = false;
      }
    }

    playListData.arrDCMFile =
        arrDCMFile != null ? List.from(arrDCMFile!) : null;
    playListData.arrTimeItems = null;
    if (arrTimeItems != null) {
      playListData.arrTimeItems = arrTimeItems!
          .map((item) => TimeItem(dtStart: item.dtStart, dtEnd: item.dtEnd))
          .toList();
    }

    return playListData;
  }

  // 写入XML
  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_uiPID', uiPID);
    pXmlItem.addItem('m_uiCatalogueID', uiCatalogueID);
    pXmlItem.addItem('m_uiID', uiID);
    pXmlItem.addItem('m_uiGroupID', uiGroupID);
    pXmlItem.addItem('m_strDCMFile', strDCMFile);
    pXmlItem.addItem('m_nPlayTimes', nPlayTimes);
    pXmlItem.addItem('m_dtStart', dtStart);
    pXmlItem.addItem('m_dtEnd', dtEnd);
    pXmlItem.addItem('m_bIsTimeSchedule', bIsTimeSchedule);
    pXmlItem.addItem('m_bIsGroup', bIsGroup);
    pXmlItem.addItem('m_nItemType', nItemType.index);
    pXmlItem.addItem('m_arrDCMFile', arrDCMFile);
    pXmlItem.addItem('m_arrCatalogueID', arrCatalogueID);
    if (arrTimeItems != null) {
      XmlItem? pTimeItem = pXmlItem.addItem('m_arrTimeItems');
      if (pTimeItem != null) {
        for (int i = 0; i < arrTimeItems!.length; i++) {
          XmlItem? xiSubItem = pTimeItem.addItem('TimeItem');
          if (xiSubItem != null) {
            xiSubItem.addItem('m_dtStart', arrTimeItems![i].dtStart);
            xiSubItem.addItem('m_dtEnd', arrTimeItems![i].dtEnd);
          }
        }
      }
    }
  }

// 从XML读取
  void getFromXML(XmlItem pXmlItem) {
    uiPID = pXmlItem.getItemValueI('m_uiPID');
    uiCatalogueID = pXmlItem.getItemValueI('m_uiCatalogueID');
    uiID = pXmlItem.getItemValueI('m_uiID');
    uiGroupID = pXmlItem.getItemValueI('m_uiGroupID');
    strDCMFile = pXmlItem.getItemValue('m_strDCMFile');
    nPlayTimes = pXmlItem.getItemValueI('m_nPlayTimes');
    dtStart = pXmlItem.getItemValue('m_dtStart');
    dtEnd = pXmlItem.getItemValue('m_dtEnd');
    bIsTimeSchedule = pXmlItem.getItemValueB('m_bIsTimeSchedule');
    bIsGroup = pXmlItem.getItemValueB('m_bIsGroup');
    nItemType = EventItemType.values.firstWhere(
        (type) => type.value == pXmlItem.getItemValueI('m_nItemType'),
        orElse: () => EventItemType.normal);
    arrDCMFile = pXmlItem.getItemValueArray('m_arrDCMFile');
    var arrCatalogueIDStr = pXmlItem.getItemValueArray('m_arrCatalogueID');
    arrCatalogueID = null;
    if (arrCatalogueIDStr != null) {
      arrCatalogueID = [];
      for (int i = 0; i < arrCatalogueIDStr.length; i++) {
        var catalogueID = int.tryParse(arrCatalogueIDStr[i]);
        if (catalogueID != null) {
          arrCatalogueID!.add(catalogueID);
        }
      }
    }
    arrTimeItems = null;
    XmlItem? pItem = pXmlItem.getItem('m_arrTimeItems');
    if (pItem != null) {
      arrTimeItems = [];
      XmlItem? pXISibling = pItem.getItem('TimeItem');
      while (pXISibling != null) {
        arrTimeItems!.add(TimeItem(
            dtStart: pXISibling.getItemValue('m_dtStart'),
            dtEnd: pXISibling.getItemValue('m_dtEnd')));

        pXISibling = pXISibling.getSibling();
      }
    }
  }

  // 判断项目类型
  bool isNormalItem() => nItemType == EventItemType.normal;
  bool isInsertItem() => nItemType == EventItemType.insert;
  bool isGroupItem() => nItemType == EventItemType.group;
  bool isRTGroupItem() => nItemType == EventItemType.rtGroup;
  bool isNormalGroupItem() =>
      !bIsTimeSchedule && nItemType == EventItemType.group;

  // 检查DCM文件是否存在
  bool isDCMFileExist([int nCount = 0, String? strCompany]) {
    if (nItemType == EventItemType.wallpaper) {
      return true;
    } else if (nItemType != EventItemType.group &&
        nItemType != EventItemType.rtGroup) {
      String strPlayFile =
          Utils.getFilePath(strDCMFile, cDCMFILETYPE, -1, strCompany);
      return File(strPlayFile).existsSync();
    } else {
      if (arrDCMFile != null && nCount < arrDCMFile!.length) {
        String strPlayFile = Utils.getFilePath(
            arrDCMFile![nCount], cDCMFILETYPE, -1, strCompany);
        return File(strPlayFile).existsSync();
      }
    }
    return false;
  }

  // 获取总持续时间
  double getTotalDuration() {
    double dbTotalDuration = 0.00;
    if (nItemType != EventItemType.normal) {
      if (nItemType != EventItemType.group &&
          nItemType != EventItemType.rtGroup) {
        if (dtStart != '00:00:00' || dtEnd != '00:00:00') {
          dbTotalDuration = getDuration(dtStart, dtEnd);
        }
      } else {
        if (arrTimeItems != null) {
          for (TimeItem item in arrTimeItems!) {
            dbTotalDuration += getDuration(item.dtStart, item.dtEnd);
          }
        }
      }
    }

    return dbTotalDuration;
  }

  // 播放下一个文件
  ({bool status, int nCurrPlay, String? strDCMFile}) playNextFile(int nCurrPlay,
      {String? strCompany}) {
    if (arrDCMFile != null && nCurrPlay < arrDCMFile!.length - 1) {
      for (int i = nCurrPlay + 1; i < arrDCMFile!.length; i++) {
        String strPlayFile =
            Utils.getFilePath(arrDCMFile![i], cDCMFILETYPE, -1, strCompany);
        if (File(strPlayFile).existsSync()) {
          nCurrPlay = i;
          return (status: true, nCurrPlay: i, strDCMFile: arrDCMFile![i]);
        }
      }
    }
    return (status: false, nCurrPlay: -1, strDCMFile: null);
  }

  // 获取当前文件
  bool getCurrFile(StringBuffer outDCMFile, int nCurrPlay,
      {String? strCompany}) {
    if (nItemType == EventItemType.wallpaper) {
      outDCMFile.write(strDCMFile);
      return true;
    } else if (nItemType != EventItemType.group &&
        nItemType != EventItemType.rtGroup) {
      String strPlayFile =
          Utils.getFilePath(strDCMFile, cDCMFILETYPE, -1, strCompany);
      if (File(strPlayFile).existsSync()) {
        outDCMFile.write(strDCMFile);
        return true;
      }
    } else {
      if (arrDCMFile != null &&
          nCurrPlay < arrDCMFile!.length &&
          nCurrPlay >= 0) {
        String strPlayFile = Utils.getFilePath(
            arrDCMFile![nCurrPlay], cDCMFILETYPE, -1, strCompany);
        if (File(strPlayFile).existsSync()) {
          outDCMFile.write(arrDCMFile![nCurrPlay]);
          return true;
        }
      }
    }
    return false;
  }

  // 获取DCM文件
  ({bool status, int nCurrPlay, String? strDCMFile}) getDCMFile(int nCurrPlay,
      [String? strCompany]) {
    if (nItemType == EventItemType.wallpaper) {
      return (status: true, nCurrPlay: nCurrPlay, strDCMFile: strDCMFile);
    } else if (nItemType != EventItemType.group &&
        nItemType != EventItemType.rtGroup) {
      return (status: true, nCurrPlay: nCurrPlay, strDCMFile: strDCMFile);
    } else {
      if (arrDCMFile != null && nCurrPlay < arrDCMFile!.length) {
        for (int i = (nCurrPlay < 0 ? 0 : nCurrPlay);
            i < arrDCMFile!.length;
            i++) {
          String strPlayFile =
              Utils.getFilePath(arrDCMFile![i], cDCMFILETYPE, -1, strCompany);
          if (File(strPlayFile).existsSync()) {
            return (
              status: true,
              nCurrPlay: nCurrPlay,
              strDCMFile: arrDCMFile![i]
            );
          }
        }
      }
    }

    return (status: false, nCurrPlay: nCurrPlay, strDCMFile: null);
  }

  // 检查目录列表中是否包含任何目录
  bool anyCatalogueInList(List<String> dcmFiles) {
    if (nItemType == EventItemType.wallpaper) {
      return true;
    } else if (nItemType != EventItemType.group &&
        nItemType != EventItemType.rtGroup) {
      return dcmFiles.contains(strDCMFile);
    } else {
      if (arrDCMFile != null) {
        for (String file in arrDCMFile!) {
          if (dcmFiles.contains(file)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // 将目录添加到列表
  void addCatalogueTo(List<String> dcmFiles) {
    if (nItemType != EventItemType.group &&
        nItemType != EventItemType.rtGroup) {
      if (!dcmFiles.contains(strDCMFile)) {
        dcmFiles.add(strDCMFile);
      }
    } else {
      if (arrDCMFile != null) {
        for (String file in arrDCMFile!) {
          if (!dcmFiles.contains(file)) {
            dcmFiles.add(file);
          }
        }
      }
    }
  }

  // 获取计数
  int getCount() {
    if (nItemType != EventItemType.group &&
        nItemType != EventItemType.rtGroup) {
      return 1;
    } else {
      return arrDCMFile != null ? arrDCMFile!.length : 0;
    }
  }
}

// 事件文件数据类
class EventFileData {
  int uiID = 0;
  String strOrganizationId = '';
  String strDocVersion = '6.01';
  String strScheduleName = 'dcmplay';
  String strScheduleDesc = '';
  bool bAutoPlay = true;
  bool bStopAndQuit = false;
  bool bIsTimeSchedule = false;
  DateTime? dtStart;
  DateTime? dtEnd;
  String strStartTime2 = '00:00:00';
  String strEndTime2 = '00:00:00';
  String strCompany = '';
  int nGroupLoop = 0;
  int nGroupNumber = 0;
  int nApprovalLevel = 0;
  int nApprovalStatus = 0;
  String strApprover = '';
  String strUserCode = '';
  String strGroupCode = '';
  DateTime? dtModified;
  DateTime? dtCreated;
  List<EventItemData>? lstPlayList;

  EventFileData();

  // 移除所有播放列表
  void removeAllPlayList() {
    if (lstPlayList != null) {
      lstPlayList!.clear();
    }
  }

  void addPlayList(EventItemData playListData) {
    lstPlayList ??= [];
    lstPlayList!.add(playListData);
  }

  // 获取第一个项目位置
  int getFirstItemPos() {
    return 0;
  }

  // 获取下一个项目
  EventItemData? getNextItem(int pos) {
    if (lstPlayList != null && pos < lstPlayList!.length) {
      return lstPlayList![pos];
    }
    return null;
  }

  // 获取项目数量
  int getCount() {
    return lstPlayList != null ? lstPlayList!.length : 0;
  }

  bool isComplexAH() {
    return (strStartTime2 == '00:00:00' && strEndTime2 == '00:00:00');
  }

  // 获取正常项目数量
  int getNormalItemCount({bool bIsMultiGroup = false}) {
    int nCount = 0;
    if (lstPlayList != null) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (bIsMultiGroup) {
          if (pPlayListData.isNormalItem()) {
            nCount += pPlayListData.getCount();
          }
        } else {
          if (!pPlayListData.bIsTimeSchedule && pPlayListData.isGroupItem()) {
            nCount += pPlayListData.getCount();
          }
        }
      }
    }

    return nCount;
  }

  // 获取项目数量（按类型）
  int getItemCount(EventItemType nItemType, {bool bIsAH = true}) {
    int nCount = 0;
    if (lstPlayList == null) return nCount;
    if (nItemType == EventItemType.group && bIsAH) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (pPlayListData.bIsTimeSchedule && pPlayListData.isGroupItem()) {
          nCount++;
        }
      }
    } else if (nItemType == EventItemType.group && !bIsAH) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (!pPlayListData.bIsTimeSchedule && pPlayListData.isGroupItem()) {
          nCount++;
        }
      }
    } else if (nItemType == EventItemType.rtGroup && bIsAH) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (pPlayListData.bIsTimeSchedule && pPlayListData.isRTGroupItem()) {
          nCount++;
        }
      }
    }
    return nCount;
  }

  // 获取公司
  String getCompany() {
    return strCompany;
  }

  // 是否跨夜
  bool isOvernight() {
    return dtEnd != null &&
        dtStart != null &&
        dtEnd!.difference(dtStart!).inDays > 0;
  }

  // 是否为正常计划
  bool isNormalSchedule() {
    if (lstPlayList != null) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (!pPlayListData.isNormalItem()) {
          return false;
        }
      }
    }
    return true;
  }

  // 是否为正常组循环
  bool isNormalGroupLoop() {
    if (lstPlayList != null) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (!pPlayListData.bIsTimeSchedule && pPlayListData.isGroupItem()) {
          return true;
        }
      }
    }
    return false;
  }

  // 获取事件项目
  EventItemData? getEventItem(int nItem) {
    if (lstPlayList != null) {
      for (EventItemData pPlayListData in lstPlayList!) {
        if (pPlayListData.uiID == nItem) {
          return pPlayListData;
        }
      }
    }
    return null;
  }

  // 获取开始时间
  String getStartTime() {
    if (dtStart == null) {
      return '00:00:00';
    }
    return DateFormat('HH:mm:ss').format(dtStart!);
  }

  // 获取结束时间
  String getEndTime() {
    if (dtEnd == null) {
      return '24:00:00';
    }
    String strEndTime = DateFormat('HH:mm:ss').format(dtEnd!);
    if (dtEnd!.hour == 23 && dtEnd!.minute == 59 && dtEnd!.second == 59) {
      strEndTime = '24:00:00';
    }
    return strEndTime;
  }

  // 获取播放范围
  Pair<DateTime, DateTime> getPlayRange(DateTime dtCurr) {
    DateTime playStart =
        dtStart ?? dtCurr.copyWith(hour: 0, minute: 0, second: 0);
    DateTime playEnd =
        dtEnd ?? dtCurr.copyWith(hour: 23, minute: 59, second: 59);
    Duration dts = playEnd.difference(playStart);
    DateTime startTime = dtCurr.copyWith(
        hour: playStart.hour,
        minute: playStart.minute,
        second: playStart.second);
    if (startTime.isAfter(dtCurr)) {
      playStart = playStart.subtract(const Duration(days: 1));
    }
    DateTime endTime = startTime.add(dts);
    if (endTime.compareTo(dtCurr) <= 0) {
      startTime = startTime.add(const Duration(days: 1));
      endTime = endTime.add(const Duration(days: 1));
    }
    return Pair(startTime, endTime);
  }
}
