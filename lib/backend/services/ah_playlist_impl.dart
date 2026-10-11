// ah_playlist.dart
import 'dart:io';
import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/ah_message_impl.dart';
import 'package:dcm/backend/services/app_skin_impl.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:path/path.dart' as path;

class AHMessageItem {
  String ahName;
  String lastMsgName;
  DateTime startTime;
  DateTime endTime;
  DateTime createTime;
  int level;
  bool endManual;
  AHItemStatus status;
  int endType;
  int delay;

  AHMessageItem({
    required this.ahName,
    required this.startTime,
    required this.endTime,
    required this.createTime,
    required this.level,
    required this.endManual,
    this.status = AHItemStatus.normal,
    this.endType = -1,
    this.delay = 5,
    this.lastMsgName = '',
  });

  bool isEffective(DateTime currTime) {
    return endManual || currTime.isBefore(endTime!);
  }

  bool isTimeForPlay(DateTime currTime) {
    return isEffective(currTime) && !currTime.isBefore(startTime!);
  }

  AHMessageItem copy() {
    return AHMessageItem(
      ahName: ahName,
      startTime: startTime,
      endTime: endTime,
      createTime: createTime,
      level: level,
      endManual: endManual,
      status: status,
      endType: endType,
      delay: delay,
      lastMsgName: lastMsgName,
    );
  }
}

enum AHItemStatus {
  normal(-1),
  newItem(0),
  dirty(1);

  final int value;
  const AHItemStatus(this.value);
}

class AHMessageList {
  int output;
  List<AHMessageItem> arrAHList = [];
  bool showMessage = false;
  bool isPlayMessage = false;
  String currMessage = '';
  DateTime startTime = DateTime.now();
  int alpha = 255;
  AHMessagePos layout = AHMessagePos.eAHFULLSCREEN;
  int overlay = 1;
  int messageZone = 0;
  int contentType = -1;
  int endType = AhEndType.byTime;
  int delay = 20;
  int autoUpdate = 0;
  Rect rcMessageWnd = Rect.zero;
  Map<String, ProductData> mapZoneData = {};
  Map<String, LayoutData> mapLayout = {};

  AHMessageList(this.output);

  void showAHMessage(bool show) {
    showMessage = show;
  }

  bool isPlaying() {
    return isPlayMessage;
  }

  Rect getMessageRect() {
    Rect rect = rcMessageWnd;
    if (layout == AHMessagePos.eAHBOTTOMMZ) {
      int nZone = 0;
      for (int i = 0; i < arrAHList.length; i++) {
        if (arrAHList[i].isTimeForPlay(DateTime.now())) {
          nZone++;
        }
      }
      rect = Rect.fromLTWH(
        rect.left,
        rect.top - (rect.height * (nZone - 1)),
        rect.width,
        rect.height,
      );
    }
    return rect;
  }

  AHMessagePos getMessageLayout() {
    return layout;
  }

  int getMessageZone() {
    return messageZone;
  }

  int getMessageZoneType() {
    return contentType;
  }

  int getAlpha() {
    return alpha;
  }

  int getEndType() {
    for (int i = 0; i < arrAHList.length; i++) {
      if (currMessage.toLowerCase() == arrAHList[i].ahName.toLowerCase()) {
        return arrAHList[i].endType;
      }
    }
    return endType;
  }

  void addMessageItem(AHMessageItem messageItem) {
    arrAHList.add(messageItem);
  }

  bool removeMessageItem(String message) {
    for (int i = 0; i < arrAHList.length; i++) {
      if (message.toLowerCase() == arrAHList[i].ahName.toLowerCase()) {
        arrAHList.removeAt(i);
        logI(
            'CAHMessageList::RemoveMessageItem: Remove message \'$message\' successfully');
        removeZoneData(message);
        removeLayoutData(message);
        AHPlayList.resetDefaultMessage();
        return true;
      }
    }
    return false;
  }

  bool addAHMessage({
    required String message,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime createTime,
    int level = 0,
    bool endManual = false,
    int endType = -1,
    int delay = 5,
  }) {
    bool isTimeForLoad = false;
    for (int i = 0; i < arrAHList.length; i++) {
      if (message.toLowerCase() == arrAHList[i].ahName.toLowerCase()) {
        arrAHList[i].startTime = startTime;
        arrAHList[i].endTime = endTime;
        arrAHList[i].createTime = createTime;
        arrAHList[i].level = level;
        arrAHList[i].endManual = endManual;
        arrAHList[i].status = AHItemStatus.dirty;
        arrAHList[i].endType = endType;
        arrAHList[i].delay = delay;
        if (currMessage == message) {
          loadMessage(currMessage);
          isTimeForLoad = true;
        }
        return isTimeForLoad;
      }
    }

    AHMessageItem messageItem = AHMessageItem(
      ahName: message,
      startTime: startTime,
      endTime: endTime,
      createTime: createTime,
      level: level,
      endManual: endManual,
      endType: endType,
      delay: delay,
      lastMsgName: loadLastMessage(message),
    );
    messageItem.status = AHItemStatus.newItem;
    addMessageItem(messageItem);
    return isTimeForLoad;
  }

  bool removeAHMessage(String message) {
    return removeMessageItem(message);
  }

  bool stopAHMessage(String message) {
    logI('CAHMessageList::StopAHMessage: try to stop messge \'$message\'');
    if (removeAHMessage(message)) {
      logI(
          'CAHMessageList::StopAHMessage: remove message \'$message\' successfully');
      if (message.endsWithIgnoreCase('AHWait') ||
          message.endsWithIgnoreCase('AHDirect')) {
        return true;
      }
      MessageData? messageData = AHMessageImpl.loadMessageData(message);
      if (messageData != null) {
        messageData.nStatus = 2;
        messageData.dtStopTime = DateTime.now();
        AHMessageImpl.saveMessageData(messageData);
      }

      //COleDateTimeSpan dts = COleDateTime::GetCurrentTime() - COleDateTime(m_tmStartTime.GetTime());
      //WritePlayLoger(m_tmStartTime.GetTime(), m_nLayout, DCM_AHMESSAGE_TYPE, m_strMsgLogName, dts.GetTotalSeconds());
      return true;
    }

    return false;
  }

  bool stopAll() {
    for (var ah in arrAHList) {
      MessageData? messageData = AHMessageImpl.loadMessageData(ah.ahName);
      if (messageData != null) {
        messageData.nStatus = 2;
        messageData.dtStopTime = DateTime.now();
        AHMessageImpl.saveMessageData(messageData);
      }
    }
    arrAHList.clear();
    return true;
  }

  Future<bool> isTimeForMessage(DateTime dateTime) async {
    if (!isPlayMessage) {
      int nItem = 0;
      if (highestLevelItem(nItem, dateTime)) {
        currMessage = arrAHList[nItem].ahName;
        if (await loadMessage(currMessage)) {
          isPlayMessage = true;
          return true;
        }
      }
    } else {
      for (int i = arrAHList.length - 1; i >= 0; i--) {
        if (dateTime.isAfter(arrAHList[i].endTime) && !arrAHList[i].endManual) {
          String message = arrAHList[i].ahName;
          arrAHList.removeAt(i);
          removeZoneData(message);
        }
      }
    }
    return false;
  }

  int isTimeForStop(DateTime dateTime) {
    if (isPlayMessage) {
      if (layout == AHMessagePos.eAHBOTTOMMZ) {
        bool changed = false;
        for (int i = arrAHList.length - 1; i >= 0; i--) {
          String message = arrAHList[i].ahName;
          DateTime dtStart = arrAHList[i].startTime;
          DateTime dtEnd = arrAHList[i].endTime;
          bool bEndManual = arrAHList[i].endManual;
          if (isMessageTimeOut(
                  dtStart, arrAHList[i].endType, arrAHList[i].delay) ||
              (dateTime.isAfter(dtEnd) && !bEndManual)) {
            changed = true;
            arrAHList.removeAt(i);
            removeZoneData(message);
          }
        }

        if (!hasMessageAvailable(dateTime)) {
          isPlayMessage = false;
          return 0;
        } else {
          return changed ? 2 : 1;
        }
      }

      // 检查当前消息
      AHMessageItem? currentItem = arrAHList.firstWhere(
        (item) => item.ahName == currMessage,
        orElse: () => AHMessageItem(
          ahName: '',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          createTime: DateTime.now(),
          level: 0,
          endManual: false,
        ),
      );

      if (isMessageTimeOut(
              currentItem.startTime, currentItem.endType, currentItem.delay) ||
          (dateTime.isAfter(currentItem.endTime) && !currentItem.endManual) ||
          dateTime.isBefore(currentItem.startTime)) {
        if (!dateTime.isBefore(currentItem.startTime)) {
          removeAHMessage(currMessage);
        }

        String nextMessage = '';
        getNextMessageDateTime(dateTime, nextMessage, DateTime.now(),
            DateTime.now(), DateTime.now(), 0, false, -1, 20);
        if (nextMessage.isEmpty) {
          isPlayMessage = false;
          return 0;
        } else {
          currMessage = nextMessage;
          loadMessage(currMessage);
          return 2;
        }
      }
    }

    return 1; // not playing
  }

  Future<bool> isTimeForLoad(DateTime dateTime) async {
    if (isPlayMessage) {
      if (layout == AHMessagePos.eAHBOTTOMMZ) {
        return false;
      }

      AHMessageItem? currentItem = arrAHList.firstWhere(
        (item) => item.ahName == currMessage,
        orElse: () => AHMessageItem(
          ahName: '',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          createTime: DateTime.now(),
          level: 0,
          endManual: false,
        ),
      );

      for (int i = 0; i < arrAHList.length; i++) {
        if (arrAHList[i].ahName != currMessage) {
          if (arrAHList[i].isTimeForPlay(dateTime)) {
            if (compareLevel(
                arrAHList[i], currentItem.level, currentItem.createTime)) {
              currMessage = arrAHList[i].ahName;
              if (await loadMessage(currMessage)) {
                isPlayMessage = true;
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }

  bool isMessageTimeOut(DateTime startTime, int endType, int delay) {
    if (endType < 0) {
      if (this.endType == AhEndType.timeout) {
        DateTime dtCurr = DateTime.now();
        Duration dts = dtCurr.difference(startTime);
        if (dts.inSeconds > this.delay) {
          return true;
        }
      }
    } else {
      if (endType == AhEndType.timeout) {
        DateTime dtCurr = DateTime.now();
        Duration dts = dtCurr.difference(startTime);
        if (dts.inSeconds > delay) {
          return true;
        }
      }
    }
    return false;
  }

  bool highestLevelItem(int nItem, DateTime currTime) {
    DateTime dtCreateTime = DateTime.now();
    int level = 0;
    bool bItem = false;
    int i = 0;
    for (; i < arrAHList.length; i++) {
      if (arrAHList[i].isEffective(currTime) &&
          !currTime.isBefore(arrAHList[i].startTime)) {
        dtCreateTime = arrAHList[i].createTime;
        level = arrAHList[i].level;
        nItem = i;
        bItem = true;
        break;
      }
    }
    if (bItem) {
      for (; i < arrAHList.length; i++) {
        if (arrAHList[i].isEffective(currTime) &&
            !currTime.isBefore(arrAHList[i].startTime)) {
          if (compareLevel(arrAHList[i], level, dtCreateTime)) {
            dtCreateTime = arrAHList[i].createTime;
            level = arrAHList[i].level;
            nItem = i;
          }
        }
      }
    }
    return bItem;
  }

  bool compareLevel(
      AHMessageItem messageItem, int level, DateTime dtCreateTime) {
    DateTime dtAHItem = messageItem.createTime;
    int nLevelItem = messageItem.level;
    if (messageItem.level == 0) {
      if (level != 0) {
        return false;
      } else {
        return dtAHItem.isAfter(dtCreateTime);
      }
    }
    if (level == messageItem.level) {
      return dtAHItem.isAfter(dtCreateTime);
    }
    return nLevelItem < level;
  }

  bool getNextMessageDateTime(
    DateTime dateTime,
    String message,
    DateTime startTime,
    DateTime endTime,
    DateTime createTime,
    int level,
    bool endManual,
    int endType,
    int delay,
  ) {
    int nItem = 0;
    if (highestLevelItem(nItem, dateTime)) {
      message = arrAHList[nItem].ahName;
      startTime = arrAHList[nItem].startTime;
      endTime = arrAHList[nItem].endTime;
      createTime = arrAHList[nItem].createTime;
      level = arrAHList[nItem].level;
      endManual = arrAHList[nItem].endManual;
      endType = arrAHList[nItem].endType;
      delay = arrAHList[nItem].delay;
    }
    return true;
  }

  bool hasMessageAvailable(DateTime currTime) {
    for (int i = 0; i < arrAHList.length; i++) {
      if (arrAHList[i].isTimeForPlay(currTime)) {
        return true;
      }
    }
    return false;
  }

  void saveLastMessage(String ahName, String messageName) {
    // 实际应用中应保存到持久存储
  }

  String loadLastMessage(String ahName) {
    // 实际应用中应从持久存储读取
    return '';
  }

  Future<void> saveDefaultMessage() async {
    String strDefaEvent =
        path.join(AppGlobal.settingPath, 'DefaultMessage$output.xml');
    XmlProfile xmlProfile = XmlProfile.fromFile(strDefaEvent);

    //xmlProfile.loadProfile('TextXML');
    xmlProfile.createProfile('DefaultMessage');
    xmlProfile.writeProfileInt('DefaultMessage', 'Output', output);
    xmlProfile.writeProfileString('DefaultMessage', 'Message', currMessage);
    xmlProfile.saveProfile();
    xmlProfile.close();
    await File(strDefaEvent).copy('$strDefaEvent.bak');
  }

  Future<bool> loadMessage(String message) async {
    int nOutput = (fLOBYTE(output) == cBYTEMAX) ? -1 : fLOBYTE(output);
    Rect rectMonitor = await playSkin.getMonitorRect(nOutput);
    logI(
        '''CAHMessageList::LoadMessage:'$message' Output:'$output'; rect:'${rectMonitor.toString()}'.''');
    try {
      MessageData? messageData = AHMessageImpl.loadMessageData(message);
      if (messageData != null) {
        int nPercent = messageData.nPercentScreen;
        if (nPercent == 0) {
          nPercent = AHPlayList.nPercent;
        }

        rcMessageWnd = Rect.zero;
        if (AHPlayList.rcAHWnd.isEmpty) {
          if (messageData.nLayout == 0) {
            rcMessageWnd =
                rectMonitor; //.SetRect(rectMonitor.left, rectMonitor.top, rectMonitor.Width(), rectMonitor.Height());
          } else if (messageData.nLayout == 1) {
            rcMessageWnd = Rect.fromLTRB(
                rectMonitor.left,
                rectMonitor.top,
                rectMonitor.left + rectMonitor.width,
                rectMonitor.top + rectMonitor.height * nPercent / 100);
          } else if (messageData.nLayout == 2 ||
              messageData.nLayout == AHMessagePos.eAHBOTTOMMZ.index) {
            rcMessageWnd = Rect.fromLTRB(
                rectMonitor.left,
                rectMonitor.top + rectMonitor.height * (100 - nPercent) / 100,
                rectMonitor.left + rectMonitor.width,
                rectMonitor.top + rectMonitor.height);
          }
        } else {
          rcMessageWnd = AHPlayList.rcAHWnd;
        }
        logI(
            '''CAHMessageList::LoadMessage Output:'$output'; rect:'${rcMessageWnd.toString()}'.''');

        alpha = messageData.bAlpha;
        layout = AHMessagePos.fromInt(messageData.nLayout) ??
            AHMessagePos.eAHFULLSCREEN;
        overlay = messageData.nOverlay;
        messageZone = messageData.nMessageZone;
        endType = messageData.nEndType;
        delay = messageData.nDelay;
        autoUpdate = messageData.nAutoUpdate;

        if (messageData.lstZone.isNotEmpty) {
          contentType = messageData.lstZone.first.nZoneType;
        }
        if (messageData.nLayout != AHMessagePos.eAHBOTTOMMZ.index) {
          removeZoneData(message);
          removeLayoutData(message);
          //messageData.GetZoneDataList(lstZoneData);
          //CZoneData *pZoneData = new CZoneData((CZoneData *)messageData.lstZone.GetHead());
          mapZoneData[message] = ProductData();
          mapZoneData[message]!.copyZoneData(messageData.lstZone);
          if (messageData.pLayoutDataObj != null) {
            mapLayout[message] = messageData.pLayoutDataObj!;
          }
        }
        saveDefaultMessage();

        return true;
      } else {
        logI('CAHMessageList::LoadMessage data failed.');
      }
    } catch (error, stackTrace) {
      logI('CAHMessageList::LoadMessage failed; $error\n$stackTrace');
    }

    return false;
  }

  void destroyZoneData() {
    mapZoneData.clear();
  }

  void destroyLayoutData() {
    mapLayout.clear();
  }

  void removeZoneData(String message) {
    mapZoneData.remove(message);
  }

  void removeLayoutData(String message) {
    mapLayout.remove(message);
  }

  ProductData? getProductData() {
    if (layout == AHMessagePos.eAHBOTTOMMZ) {
      ProductData pProductData = ProductData();
      destroyZoneData();
      for (int i = 0; i < arrAHList.length; i++) {
        if (arrAHList[i].isTimeForPlay(DateTime.now())) {
          String strMessage = arrAHList[i].ahName;

          MessageData? messageData = AHMessageImpl.loadMessageData(strMessage);
          if (messageData != null) {
            if (messageData.nLayout == AHMessagePos.eAHBOTTOMMZ.index) {
              // && messageData.IsEffective(DateTime.now())
              ProductData pMsgProductData = ProductData();
              //CZoneData *pZoneData = new CZoneData((CZoneData *)messageData.lstZone.GetHead());
              if (messageData.lstZone.isNotEmpty) {
                pProductData.addZoneData(messageData.lstZone.first);
                pMsgProductData.addZoneData(messageData.lstZone.first);
              }
              mapZoneData[strMessage] = pMsgProductData;
              String strMessageName = messageData.strAHDesc1.isEmpty
                  ? messageData.strAHName
                  : messageData.strAHDesc1;
              if (!strMessageName.equalsIgnoreCase(arrAHList[i].lastMsgName)) {
                writeMessageLog(strMessage, strMessageName,
                    pMsgProductData.getHeadZoneID());
                arrAHList[i].lastMsgName = strMessageName;
              }
            }
          }
        }
      }

      return pProductData;
    } else {
      if (mapZoneData.containsKey(currMessage)) {
        return mapZoneData[currMessage]!.copy();
      }
    }
    return null;
  }

  void writeMessageLog(
      String strAHName, String strMessageName, int nMessageType) {
    saveLastMessage(strAHName, strMessageName);
    //tmStartTime = CTime::GetCurrentTime();
    //WritePlayLoger(tmStartTime.GetTime(), nMessageType, DCM_AHMESSAGE_TYPE, strMessageName, 0);
  }

  LayoutData? getLayoutData() {
    if (mapLayout.containsKey(currMessage)) {
      return mapLayout[currMessage]!.copy();
    }
    return null;
  }

  ({
    int nChanged,
    List<ZoneData>? lstZoneData,
    List<ZoneData>? lstZoneDataChanged
  }) getZoneDataList() {
    int nChanged = 0;
    List<ZoneData> lstZoneData = [];
    List<ZoneData> lstZoneDataChanged = [];
    if (layout == AHMessagePos.eAHBOTTOMMZ) {
      Map<String, ProductData> mapZoneDataLocal = {};
      for (int i = 0; i < arrAHList.length; i++) {
        if (arrAHList[i].isTimeForPlay(DateTime.now())) {
          String strMessage = arrAHList[i].ahName;
          if (arrAHList[i].status != AHItemStatus.normal) {
            MessageData? messageData =
                AHMessageImpl.loadMessageData(strMessage);
            if (messageData != null) {
              if (messageData.nLayout == AHMessagePos.eAHBOTTOMMZ.index) {
                // && messageData.IsEffective(DateTime.now()
                nChanged = 1;
                arrAHList[i].status = AHItemStatus.normal;
                lstZoneDataChanged.add(messageData.lstZone.first);
                mapZoneDataLocal[strMessage] = ProductData();
                mapZoneDataLocal[strMessage]!
                    .addZoneData(messageData.lstZone.first);
                String strMessageName = messageData.strAHDesc1.isEmpty
                    ? messageData.strAHName
                    : messageData.strAHDesc1;
                if (!strMessageName
                    .equalsIgnoreCase(arrAHList[i].lastMsgName)) {
                  writeMessageLog(strMessage, strMessageName,
                      messageData.lstZone.first.nZoneID);
                  arrAHList[i].lastMsgName = strMessageName;
                }
                //WriteMessage(MSG_INFO, 'CAHPlayList::GetZoneDataList Message: '%s'; ZoneData Changed:'%s'; Zone ID: '%d'!', strMessage, pZoneData->m_strZoneFile, pZoneData->m_nZoneID);
              }
            }
          } else {
            if (mapZoneData.containsKey(strMessage)) {
              lstZoneData.add(mapZoneData[strMessage]!.getHeadZoneData()!);
              mapZoneDataLocal[strMessage] = mapZoneData[strMessage]!.copy();
            }
          }
        }
      }

      mapZoneData.clear();
      if (mapZoneDataLocal.isNotEmpty) mapZoneData.addAll(mapZoneDataLocal);

      /*if (bChanged)
        WriteMessage(MSG_INFO, 'CAHPlayList::GetZoneDataList; arrAHList size:%d; m_mapZoneData size:%d', arrAHList.size(), m_mapZoneData.size());*/

      return (
        nChanged: nChanged,
        lstZoneData: lstZoneData,
        lstZoneDataChanged: lstZoneDataChanged
      );
    }

    return (nChanged: -1, lstZoneData: null, lstZoneDataChanged: null);
  }

  int size() {
    return arrAHList.length;
  }

  AHMessageList copy() {
    AHMessageList newList = AHMessageList(output);
    for (int i = 0; i < arrAHList.length; i++) {
      newList.arrAHList.add(arrAHList[i].copy());
    }
    return newList;
  }
}

class AHPlayList {
  Map<int, AHMessageList> arrAHList = {};

  static Rect rcAHWnd = Rect.zero;
  static int nPercent = 10;

  static const int kAHBOTTOMMZ = 3;
  static const int kAHENDTIMEOUT = 1;
  static const int kAHENDBYTIME = 0;
  static const int kAHENDPLAYONETIME = 3;

  Future<void> loadAHList() async {
    List<int> arrOutputs = playSkin.getOutputs();
    AHMessageImpl messageImpl = AHMessageImpl();
    await messageImpl.loadMessageList();
    DateTime dtCurr = DateTime.now();
    for (var pData in messageImpl.lstMessage) {
      if (pData.nStatus == 0 && pData.isEffective(dtCurr)) {
        //pData.nStatus != 2 &&
        /*String strLastMessage = LoadLastMessage(pData.strAHName);
        CAHMessageItem messageItem(pData.strAHName, pData.dtStartTime, pData.dtEndTime,
          pData.dtCreateTime, pData.nLevel, pData.bEndManual, strLastMessage);*/
        AHMessageItem messageItem = AHMessageItem(
            ahName: pData.strAHName,
            startTime: pData.dtStartTime!,
            endTime: pData.dtEndTime!,
            createTime: pData.dtCreateTime!,
            level: pData.nLevel,
            endManual: pData.bEndManual,
            endType: pData.nEndType,
            delay: pData.nDelay);
        if (pData.uiOutput == -2) {
          for (int i = 0; i < arrOutputs.length; i++) {
            addMessageItem(
                messageItem, MessageData.getOutput(arrOutputs[i], pData));
          }
        } else {
          addMessageItem(
              messageItem, MessageData.getOutput(pData.uiOutput, pData));
        }
      }
    }

    var result = await getDefaultMessages();
    if (result.arrMessages.isNotEmpty) {
      for (int i = 0; i < result.arrOutputs!.length; i++) {
        int nOverlay = fHIBYTE(result.arrOutputs![i]);
        if (nOverlay == 0 && result.arrMessages.length > i) {
          MessageData? pData = messageImpl.getMessage(result.arrMessages[i]);
          if (pData != null) {
            AHMessageItem messageItem = AHMessageItem(
                ahName: pData.strAHName,
                startTime: DateTime.now(),
                endTime: DateTime.now(),
                createTime: DateTime.now(),
                level: pData.nLevel,
                endManual: true,
                endType: pData.nEndType,
                delay: pData.nDelay);

            addMessageItem(messageItem, result.arrOutputs![i]);
          }
        }
      }
    }

    List<int> arrLayer = getLayers();
    List<int> removeKeys = [];
    for (int i = 0; i < arrLayer.length; i++) {
      if (find(fMAKEWORD(cBYTEMAX, arrLayer[i]))) {
        for (var it in arrAHList.entries) {
          int nOverlay = fHIBYTE(it.value.output);
          int nRealOutput = fLOBYTE(it.value.output);
          if (nOverlay == arrLayer[i] && nRealOutput < cBYTEMAX) {
            it.value.stopAll();
            removeKeys.add(it.key);
          }
        }
        arrAHList.removeWhere((key, value) => removeKeys.contains(key));
      }
    }
  }

  static bool isAHMessage(int nZone) {
    return nZone > cAHMESSAGETYPE - 1 && nZone < cTOUCHSCREENTYPE;
  }

  static int getOutput(int nZone) {
    int nId = nZone - cAHMESSAGETYPE;
    int nLayer = 0;
    int nOutput = -1;
    if (nId > 0) {
      nLayer = nId ~/ 10;
      nOutput = (nId % 10) - 1;
    }
    nOutput = nOutput < 0 ? cBYTEMAX : nOutput;
    return (nOutput << 8) + nLayer;
  }

  static int getLayer(int nZone) {
    int nId = nZone - cAHMESSAGETYPE - 1;
    int nLayer = 0;
    if (nId > 0) {
      nLayer = nId ~/ 10;
    }
    return nLayer;
  }

  List<int> getLayers() {
    List<int> arrLayer = [];
    for (var it in arrAHList.entries) {
      int nLayer = fHIBYTE(it.key);
      bool bExists = false;
      for (int i = 0; i < arrLayer.length; i++) {
        if (arrLayer[i] == nLayer) {
          bExists = true;
          break;
        }
      }
      if (!bExists) {
        arrLayer.add(nLayer);
      }
    }

    return arrLayer;
  }

  static int getRealOutput(int nZone) {
    int nId = nZone - cAHMESSAGETYPE - 1;
    int nOutput = nId < 0 ? cBYTEMAX : nId;
    if (nId > 0) {
      nOutput = nId % 10;
    }
    return nOutput;
  }

  static int getMessageId(int nOutput) {
    int nId = nOutput;
    if (nOutput > 0) {
      int nLayer = (nOutput >> 8) & 0xFF;
      int nRealOutput = nOutput & 0xFF;
      nId = (nLayer * 10 + (nRealOutput == cBYTEMAX ? -1 : nRealOutput));
    }
    return (cAHMESSAGETYPE + nId + 1);
  }

  void addMessageItem(AHMessageItem messageItem, [int nOutput = -1]) {
    arrAHList[nOutput] = AHMessageList(nOutput);
    if (arrAHList[nOutput] != null) {
      messageItem.lastMsgName =
          arrAHList[nOutput]!.loadLastMessage(messageItem.ahName);
      arrAHList[nOutput]?.addMessageItem(messageItem);
    }
  }

  bool removeAHMessage(String message, [int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.removeMessageItem(message);
    }
    return false;
  }

  int addAHMessage({
    required String message,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime createTime,
    int level = 0,
    bool endManual = false,
    int nOutput = -1,
    int endType = -1,
    int delay = 20,
  }) {
    int needRefresh = cINTMIN; // INT_MIN
    if (!arrAHList.containsKey(nOutput)) {
      int nOverlay = (nOutput >> 8) & 0xFF;
      int nRealOutput = nOutput & 0xFF;
      if ((nRealOutput == cBYTEMAX && countByLayer(nOverlay) > 0) ||
          arrAHList.containsKey((cBYTEMAX << 8) + nOverlay)) {
        stop(nOverlay);
        needRefresh = (0xFFFF << 16) + nOverlay; // MAKEDWORD
      }

      if (count(nOutput) < 0) {
        arrAHList[nOutput] = AHMessageList(nOutput);
      }
    }

    bool bNeedRefresh = arrAHList[nOutput]!.addAHMessage(
      message: message,
      startTime: startTime,
      endTime: endTime,
      createTime: createTime,
      level: level,
      endManual: endManual,
      endType: endType,
      delay: delay,
    );

    return (needRefresh == cINTMIN)
        ? (bNeedRefresh ? nOutput : cINTMIN)
        : needRefresh;
  }

  void showAHMessage(bool bShow, [int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      arrAHList[nOutput]!.showAHMessage(bShow);
    }
  }

  bool isPlaying([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.isPlaying();
    }
    return false;
  }

  Future<int> isTimeForMessage(DateTime dtDateTime) async {
    for (int key in arrAHList.keys) {
      if (await arrAHList[key]!.isTimeForMessage(dtDateTime)) {
        return arrAHList[key]!.output;
      }
    }
    return cINTMIN;
  }

  int isTimeForStop(DateTime dtDateTime, int nOutput) {
    for (int key in arrAHList.keys) {
      int result = arrAHList[key]!.isTimeForStop(dtDateTime);
      if (result == 2 || result == 0) {
        nOutput = arrAHList[key]!.output;
        return result;
      }
    }
    return 1;
  }

  Future<int> isTimeForLoad(DateTime dtDateTime) async {
    for (int key in arrAHList.keys) {
      if (await arrAHList[key]!.isTimeForLoad(dtDateTime)) {
        return arrAHList[key]!.output;
      }
    }
    return cINTMIN;
  }

  bool isAHWaiting([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.currMessage.toLowerCase() == 'ahwait';
    }
    return false;
  }

  bool isTransparency([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.getAlpha() < 255;
    }
    return false;
  }

  bool isOverlay([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return (arrAHList[nOutput]!.overlay & cAHMSGOVERLAY) > 0;
    }
    return false;
  }

  bool isStopPlaylist([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return (arrAHList[nOutput]!.overlay & cAHMSGSTOPPLAYLIST) > 0;
    }
    return false;
  }

  int getAlpha([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.getAlpha();
    }

    return cBYTEMAX;
  }

  int getEndType([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.getEndType();
    }
    return kAHENDBYTIME;
  }

  int count(int nOutput) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.size();
    } else {
      return -1;
    }
  }

  int countByLayer(int nLayer) {
    int nCnt = 0;
    for (int key in arrAHList.keys) {
      if (nLayer == (key >> 8) & 0xFF) {
        nCnt += arrAHList[key]!.size();
      }
    }
    return nCnt;
  }

  bool find(int nOutput) {
    return arrAHList.containsKey(nOutput) && arrAHList[nOutput]!.size() > 0;
  }

  ({
    int nChanged,
    List<ZoneData>? lstZoneData,
    List<ZoneData>? lstZoneDataChanged
  }) getZoneDataList(int nOutput /* = -1*/) {
    if (find(nOutput)) {
      return arrAHList[nOutput]!.getZoneDataList();
    }

    return (nChanged: 0, lstZoneData: null, lstZoneDataChanged: null);
  }

  ProductData? getProductData([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.getProductData();
    }
    return null;
  }

  LayoutData? getLayoutData([int nOutput = -1]) {
    if (arrAHList.containsKey(nOutput)) {
      return arrAHList[nOutput]!.getLayoutData();
    }
    return null;
  }

  void stop(int nLayer) {
    for (int key in arrAHList.keys) {
      if (nLayer == (key >> 8) & 0xFF) {
        arrAHList[key]!.stopAll();
      }
    }
  }

  bool stopAll([int nOutput = -1]) {
    if (nOutput < 0) {
      for (int key in arrAHList.keys) {
        arrAHList[key]!.stopAll();
      }
      arrAHList.clear();
    } else {
      if (find(nOutput)) {
        return arrAHList[nOutput]!.stopAll();
      }
    }
    return true;
  }

  Rect getMessageRect([int nOutput = -1]) {
    Rect rect = Rect.zero;
    if (find(nOutput)) {
      rect = arrAHList[nOutput]!.getMessageRect();
    }
    return rect;
  }

  AHMessagePos getMessageLayout([int nOutput = -1]) {
    AHMessagePos nLayout = AHMessagePos.eAHFULLSCREEN;
    if (find(nOutput)) {
      nLayout = arrAHList[nOutput]!.getMessageLayout();
    }
    return nLayout;
  }

  int getMessageZone([int nOutput = -1]) {
    int nZone = 0;
    if (find(nOutput)) {
      nZone = arrAHList[nOutput]!.getMessageZone();
    }
    return nZone;
  }

  int getMessageZoneType([int nOutput = -1]) {
    int nZoneType = -1;
    if (find(nOutput)) {
      nZoneType = arrAHList[nOutput]!.getMessageZoneType();
    }
    return nZoneType;
  }

  int stopAllAndAddAHMessage(String strMessage, DateTime dtStartTime,
      DateTime dtEndTime, DateTime dtCreateTime,
      [int nLevel = 0,
      bool bEndManual = false,
      int nOutput = -1,
      int nEndType = -1,
      int nDelay = 20]) {
    int nNeedRefresh = cINTMIN;
    if (!find(nOutput)) {
      int nOverlay = fHIBYTE(nOutput);
      int nRealOutput = fLOBYTE(nOutput);
      if ((nRealOutput == cBYTEMAX && countByLayer(nOverlay) > 0) ||
          find(fMAKEWORD(cBYTEMAX, nOverlay))) {
        stop(nOverlay);
        nNeedRefresh = fMAKEDWORD(cWORDMAX, nOverlay); //MAKEWORD
      }

      if (count(nOutput) < 0) {
        arrAHList[nOutput] = AHMessageList(nOutput);
      }
    } else {
      arrAHList[nOutput]!.stopAll();
    }

    bool bNeedRefresh = arrAHList[nOutput]!.addAHMessage(
        message: strMessage,
        startTime: dtStartTime,
        endTime: dtEndTime,
        createTime: dtCreateTime,
        level: nLevel,
        endManual: bEndManual,
        endType: nEndType,
        delay: nDelay);

    return ((nNeedRefresh == cINTMIN)
        ? (bNeedRefresh ? nOutput : cINTMIN)
        : nNeedRefresh);
  }

  bool stopAHMessage(String strMessage, [int nOutput = -1]) {
    if (find(nOutput)) {
      return arrAHList[nOutput]!.stopAHMessage(strMessage);
    }

    return false;
  }

  Future<({List<String> arrMessages, List<int>? arrOutputs})>
      getDefaultMessages() async {
    final List<String> arrMessages = [];
    final settingsPath = AppGlobal.settingPath;
    if (settingsPath.isEmpty) {
      return (arrOutputs: null, arrMessages: arrMessages);
    }

    final directory = Directory(settingsPath);
    if (!await directory.exists()) {
      return (arrOutputs: null, arrMessages: arrMessages);
    }

    final regex = RegExp(r'^DefaultMessage.*\.xml\$', caseSensitive: false);
    final files = directory
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => regex.hasMatch(path.basename(file.path)))
        .toList()
      ..sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

    List<int> arrOutputs = [];
    for (final file in files) {
      final xmlProfile = XmlProfile();
      if (loadDefaultMessage(xmlProfile, file.path)) {
        final nOutput =
            xmlProfile.getProfileInt('DefaultMessage', 'Output', cINTMIN);
        if (nOutput != cINTMIN) {
          arrOutputs.add(nOutput);
          arrMessages.add(
              xmlProfile.getProfileString('DefaultMessage', 'Message', ''));
        }
      }
    }

    return (arrOutputs: arrOutputs, arrMessages: arrMessages);
  }

  String getDefaultMessage(int nOutput) {
    final settingsPath = AppGlobal.settingPath;
    if (settingsPath.isEmpty) return '';

    final strDefaEvent = path.join(settingsPath, 'DefaultMessage$nOutput.xml');
    final file = File(strDefaEvent);
    if (!file.existsSync()) return '';

    final xmlProfile = XmlProfile();
    if (loadDefaultMessage(xmlProfile, strDefaEvent)) {
      return xmlProfile.getProfileString('DefaultMessage', 'Message', '');
    }
    return '';
  }

  bool loadDefaultMessage(XmlProfile xmlProfile, String strDefaultMessage) {
    if (xmlProfile.loadProfile(
        lpszFileName: strDefaultMessage, szRootItemName: 'DefaultMessage')) {
      return true;
    }

    final backupFile = File('$strDefaultMessage.bak');
    if (backupFile.existsSync()) {
      try {
        backupFile.copySync(strDefaultMessage);
      } catch (_) {
        return false;
      }
      return xmlProfile.loadProfile(
          lpszFileName: strDefaultMessage, szRootItemName: 'DefaultMessage');
    }

    return false;
  }

  static void resetDefaultMessage() {
    final settingsPath = AppGlobal.settingPath;
    if (settingsPath.isEmpty) return;

    final directory = Directory(settingsPath);
    if (!directory.existsSync()) return;

    final xmlRegex = RegExp(r'^DefaultMessage.*\.xml\$', caseSensitive: false);
    final bakRegex =
        RegExp(r'^DefaultMessage.*\.xml\.bak\$', caseSensitive: false);

    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File) {
        final name = path.basename(entity.path);
        if (xmlRegex.hasMatch(name) || bakRegex.hasMatch(name)) {
          try {
            entity.deleteSync();
          } catch (_) {
            // ignore delete errors
          }
        }
      }
    }
  }
}
