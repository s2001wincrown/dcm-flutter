// room_date_file.dart
import 'dart:math';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class EventDateFile extends XmlFile {
  static const String cEVENTDATEEVENTID = 'EventID';
  static const String cEVENTDATESTARTTIME = 'BookTimeFrom';
  static const String cEVENTDATEENDTIME = 'BookTimeTo';
  static const String cEVENTDATESTARTTIME1 = 'DisplayTimeFrom';
  static const String cEVENTDATEENDTIME1 = 'DisplayTimeTo';
  static const String cEVENTDATESTARTTIME2 = 'LobbyTimeFrom';
  static const String cEVENTDATEENDTIME2 = 'LobbyTimeTo';
  static const String cEVENTDATEDATETIME = 'DateTime';
  static const String cEVENTDATEROOT = 'EventDate';
  static const String cEVENTDATEEVENTITEM = 'EventDateItem';
  static const String cEVENTDATEROOMID = 'RoomID';
  static const String cEVENTDATEROOMINDEX = 'RoomIndex';
  static const String cEVENTDATEROOMVENUE = 'RoomVenue';
  static const String cEVENTDATEROOMNAME = 'RoomName';
  static const String cEVENTDATEROOMDESC = 'RoomDesc';
  static const String cEVENTDATEROOMORDER = 'roomOrder';
  static const String cEVENTDATETITLE = 'Title';
  static const String cEVENTDATETITLEIMAGE = 'TitleImage';
  static const String cEVENTDATEDELAY = 'Delay';
  static const String cEVENTDATELINES = 'LinesOfPage';
  static const String cEVENTDATECHARSET = 'Charset';
  static const String cEVENTDATESERVERURL = 'ServerUrl';
  static const String cEVENTDATELOBBYURL = 'LobbyUrl';
  static const String cEVENTDATEBACKGROUNDCOLOR = 'backgroundColor';
  static const String cEVENTDATEHTMLCONTENT = 'lobbyContent';
  static const String cEVENTDATESCREENWIDTH = 'screenWidth';
  static const String cEVENTDATESCREENHEIGHT = 'screenHeight';
  static const String cEVENTDATEPLAYERUNIQUEID = 'playerUniqueId';

  late int nextUniqueID;

  EventDateFile({String? password}) : super(cEVENTDATEROOT) {
    nextUniqueID = 0;
  }

  bool deleteEventItem(XmlItem hEventItem) {
    XmlItem? pXIParent = hEventItem.getParent();
    assert(pXIParent != null);

    return pXIParent!.deleteItem(pXI: hEventItem);
  }

  bool deleteEventItemAttributes(XmlItem hEventItem) {
    var pos = hEventItem.getFirstItemPos();
    while (pos.moveNext()) {
      XmlItem pXIChild = pos.current;
      if (!pXIChild.nameMatches(cEVENTDATEEVENTITEM)) {
        hEventItem.deleteItem(pXI: pXIChild);
      }
    }

    return true;
  }

  XmlItem? findEventItem(int dwEventItemID) {
    XmlItem? hEventItem = getFirstEventItem();

    while (hEventItem != null) {
      int uiRoomID = hEventItem.getItemValueI(cEVENTDATEROOMID);
      if (uiRoomID == dwEventItemID) {
        return hEventItem;
      }

      hEventItem = getNextEventItem(hEventItem);
    }

    return null;
  }

  String getBackgroundColor(XmlItem hEventItem) {
    return hEventItem.getItemValue('backgroundColor');
  }

  String getCharset() {
    return getItemValue(cEVENTDATECHARSET);
  }

  String getCheckOutTo() {
    return getItemValue(cDCMCHECKEDOUTTO);
  }

  int getCurrentPlayTimeRange(DateTime dtCurr, DateTime? dtFrom, DateTime? dtTo,
      String playerUniqueId) {
    int nPages = 0;
    int nLines = 0;

    XmlItem? hEventItem = getFirstEventItem();
    if (hEventItem != null) {
      DateTime dtStart;
      DateTime dtEnd;
      while (hEventItem != null) {
        var result = getLobbyDateTimeRange(hEventItem, dtCurr);
        if (result.status) {
          dtStart = result.dtFrom!;
          dtEnd = result.dtTo!;
          if (dtFrom != null && dtTo != null) {
            if (dtStart.compareTo(dtTo) >= 0) {
              if (dtFrom.compareTo(dtCurr) <= 0 && dtTo.isAfter(dtCurr)) {
                break;
              } else {
                dtFrom = dtStart;
                dtTo = dtEnd;
                nPages = 0;
                nLines = 0;
                playerUniqueId = getPlayerUniqueId(hEventItem);
                var htmlContent = getHtmlContent(hEventItem);
                if (htmlContent.isNotEmpty) {
                  nPages++;
                } else {
                  nLines++;
                }
              }
            } else {
              if (dtEnd.isAfter(dtTo)) {
                dtTo = dtEnd;
              }

              var htmlContent = getHtmlContent(hEventItem);
              if (htmlContent.isNotEmpty) {
                nPages++;
              } else {
                nLines++;
              }
            }
          } else {
            dtFrom = dtStart;
            dtTo = dtEnd;
            playerUniqueId = getPlayerUniqueId(hEventItem);
            var htmlContent = getHtmlContent(hEventItem);
            if (htmlContent.isNotEmpty) {
              nPages++;
            } else {
              nLines++;
            }
          }
        }

        hEventItem = getNextEventItem(hEventItem);
      }
    }

    if (nLines > 0) {
      nPages++;
    }

    return nPages;
  }

  DateTime? getEventDate() {
    XmlItem? pXItem = getItem(cEVENTDATEDATETIME);
    if (pXItem != null) {
      return fromOleDateTime(pXItem.getValueF());
    }

    return null;
  }

  String getEventEndTime(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATEENDTIME);
  }

  String getEventEndTime1(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATEENDTIME1);
  }

  String getEventEndTime2(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATEENDTIME2);
  }

  int getEventID(XmlItem hEventItem) {
    return hEventItem.getItemValueI('EventID');
  }

  bool getEventLobbyItem(XmlItem hEventItem, String strLobby,
      {int nTemplate = 0}) {
    DateTime dtFrom;
    DateTime dtEnd;
    DateTime dtCurr; // = DateTime::GetCurrentTime();
    var result = getLobbyTime(hEventItem);
    if (result.status) {
      dtFrom = result.dtFrom!;
      dtEnd = result.dtTo!;
      dtCurr = result.dtCurr!;
      //DateTime dtCurr;// = DateTime::GetCurrentTime();
      if (dtCurr.compareTo(dtFrom) >= 0 && dtCurr.isBefore(dtEnd)) {
        strLobby = '<tr>';
        String strEventArray = '["';
        String strImage = getEventTitleImage(hEventItem);
        if (strImage.isNotEmpty) {
          strLobby += '<td class="EventItem">';
          String strImageFile1 = strImage;
          String strFile = path.basename(strImageFile1);
          //strImageFile = Settings.m_strImagePath + '\\' + strFile;
          strImageFile1 = 'file:///${Utils.getFilePath(strFile, cIMAGETYPE)}';
          strImageFile1.replaceAll('\\', '/');
          strImageFile1.replaceAll(' ', '%20');

          strEventArray += strImageFile1;
          strEventArray += '", "';
          strImage =
              '<img border="0" src="$strImageFile1" width="10" height="8"></td>';
          strLobby += strImage;
        } else {
          strEventArray += '", "';
        }
        strLobby += '<td valign="middle" align="center" class="EventItem">';
        String strStart = getEventStartTime(hEventItem);
        strEventArray += strStart.substring(0, 5);
        strLobby += strStart.substring(0, 5);
        strLobby += '<br>-<br>';
        String strEnd = getEventEndTime(hEventItem);
        strEventArray += '","';
        strEventArray += strEnd.substring(0, 5);
        strLobby += strEnd.substring(0, 5);
        strLobby += '<br></td><td class="EventItem">';
        String strTitle = getEventTitle(hEventItem);
        strTitle.replaceAll('\r', ' ');
        if (nTemplate == 0) {
          List<String> arrTitle = strTitle.split('\n');
          if (arrTitle.length > 3) {
            strTitle = '';
            for (int nLine = 0; nLine < 3; nLine++) {
              strTitle += arrTitle[nLine];
              if (nLine < 2) {
                strTitle += '<br>';
              }
            }
          } else {
            strTitle.replaceAll('\n', '<br>');
          }
        } else {
          strTitle.replaceAll('\n', '<br>');
        }
        strEventArray += '","';
        strEventArray += strTitle;
        strEventArray += '","';
        strLobby += strTitle;
        strLobby += '<br></td><td class="EventItem">';

        String strVenue = getEventRoomVenue(hEventItem);
        strVenue.replaceAll('\r', ' ');
        if (nTemplate == 0) {
          var arrVenue = strVenue.split('\n');
          if (arrVenue.length > 3) {
            strVenue = '';
            for (int nLine = 0; nLine < 3; nLine++) {
              strVenue += arrVenue[nLine];
              if (nLine < 2) strVenue += '<br>';
            }
          } else {
            strVenue.replaceAll('\n', '<br>');
          }
        } else {
          strVenue.replaceAll('\n', '<br>');
        }
        strLobby += strVenue;
        strEventArray += strVenue;
        strEventArray += '"];';
        strLobby += '<br></td></tr>';

        if (nTemplate != 0) strLobby = strEventArray;

        return true;
      }
    }

    return false;
  }

  String getEventRoomDesc(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATEROOMDESC);
  }

  int getEventRoomID(XmlItem hEventItem) {
    return hEventItem.getItemValueI('RoomID');
  }

  int getEventRoomIndex(XmlItem hEventItem) {
    return hEventItem.getItemValueI('RoomIndex');
  }

  String getEventRoomName(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATEROOMNAME);
  }

  String getEventRoomVenue(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATEROOMVENUE);
  }

  String getEventStartTime(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATESTARTTIME);
  }

  String getEventStartTime1(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATESTARTTIME1);
  }

  String getEventStartTime2(XmlItem hEventItem) {
    return hEventItem.getItemValue(cEVENTDATESTARTTIME2);
  }

  String getEventTitle(XmlItem hEventItem) {
    return hEventItem.getItemValue('Title');
  }

  String getEventTitleImage(XmlItem hEventItem) {
    return hEventItem.getItemValue('TitleImage');
  }

  int getFileFormat() {
    return getItemValueI(cDCMFILEFORMAT);
  }

  int getFileVersion() {
    return getItemValueI(cDCMFILEVERSION);
  }

  XmlItem? getFirstEventItem() {
    XmlItem? pXIParent = root();
    if (pXIParent != null) {
      return null;
    }

    return pXIParent!.getItem(cEVENTDATEEVENTITEM);
  }

  String getHtmlContent(XmlItem hEventItem) {
    return hEventItem.getItemValue('lobbyContent');
  }

  int getLinesOfPage() {
    return getItemValueI(cEVENTDATELINES);
  }

  ({bool status, DateTime? dtFrom, DateTime? dtTo}) getLobbyDateTimeRange(
      XmlItem hEventItem, DateTime dtCurr) {
    var result = getLobbyTimeRange(hEventItem);
    if (result.status) {
      return (
        status: true,
        dtFrom: mergeTimeFrom(dtCurr, result.timeFrom!),
        dtTo: mergeTimeFrom(dtCurr, result.timeTo!)
      );
    }

    return (status: false, dtFrom: null, dtTo: null);
  }

  double getLobbyDuration(DateTime dtCurr) {
    double dbDuration = 0.00;
    DateTime dtStart = dtCurr;
    DateTime dtEnd = dtCurr;
    XmlItem? hEventItem = getFirstEventItem();
    while (hEventItem != null) {
      DateTime dtFrom;
      DateTime dtTo;
      var result = getLobbyDateTimeRange(hEventItem, dtCurr);
      if (result.status) {
        dtFrom = result.dtFrom!;
        dtTo = result.dtTo!;
        if (dtFrom.compareTo(dtCurr) <= 0 && dtTo.isAfter(dtCurr)) {
          if (dtTo.isAfter(dtEnd)) {
            dtEnd = dtTo;
          }
        }
      }

      hEventItem = getNextEventItem(hEventItem);
    }
    dbDuration = dtEnd.difference(dtStart).inMilliseconds / 1000.00;

    return dbDuration;
  }

  int getLobbyPages(DateTime dtCurr) {
    double dbDuration = 0.00;
    int nPages = 0;
    int nLines = 0;
    XmlItem? hEventItem = getFirstEventItem();
    while (hEventItem != null) {
      if (isTimeForShow(hEventItem, dtCurr, dbDuration)) {
        String? htmlContent = getHtmlContent(hEventItem);
        if (htmlContent.isNotEmpty) {
          nPages++;
        } else {
          nLines++;
        }
      }

      hEventItem = getNextEventItem(hEventItem);
    }
    if (nLines > 0) {
      nPages++;
    }

    return nPages;
  }

  ({bool status, DateTime? dtFrom, DateTime? dtTo, DateTime? dtCurr})
      getLobbyTime(XmlItem hEventItem) {
    DateTime? dtEventDate = getEventDate();
    if (dtEventDate != null) {
      String strFrom = getEventStartTime2(hEventItem);
      String strEnd = getEventEndTime2(hEventItem);
      if (strFrom == '00:00:00' && strEnd == '00:00:00') {
        strEnd = '23:59:59';
      }
      return (
        status: true,
        dtFrom: mergeTimeFrom(dtEventDate, strFrom),
        dtTo: mergeTimeFrom(dtEventDate, strEnd),
        dtCurr: combineDateTime(dtEventDate)
      );
    }

    return (status: false, dtFrom: null, dtTo: null, dtCurr: null);
  }

  ({bool status, String? timeFrom, String? timeTo}) getLobbyTimeRange(
      XmlItem hEventItem) {
    var strTimeFrom = getEventStartTime2(hEventItem);
    var strTimeTo = getEventEndTime2(hEventItem);

    if (strTimeFrom.isEmpty && strTimeTo.isEmpty) {
      return (status: false, timeFrom: null, timeTo: null);
    }

    if (strTimeFrom.isEmpty) strTimeFrom = '00:00:00';
    if (strTimeTo.isEmpty) strTimeTo = '23:59:59';

    if (strTimeFrom == '00:00:00' && strTimeTo == '00:00:00') {
      strTimeTo = '23:59:59';
    }

    return (status: true, timeFrom: strTimeFrom, timeTo: strTimeTo);
  }

  String getLobbyUrl() {
    return getItemValue(cEVENTDATELOBBYURL);
  }

  XmlItem? getNextEventItem(XmlItem pXIEventItem) {
    return pXIEventItem.getSibling();
  }

  int getNextUniqueID() {
    return nextUniqueID;
  }

  String getPlayerUniqueId(XmlItem hEventItem) {
    return hEventItem.getItemValue('playerUniqueId');
  }

  int getScreenHeight(XmlItem hEventItem) {
    return hEventItem.getItemValueI('screenHeight');
  }

  int getScreenWidth(XmlItem hEventItem) {
    return hEventItem.getItemValueI('screenWidth');
  }

  int getScrollDelay() {
    return getItemValueI(cEVENTDATEDELAY);
  }

  String getServerUrl() {
    return getItemValue(cEVENTDATESERVERURL);
  }

  bool isCheckedOut() {
    // Check if the file is checked out
    return false;
  }

  bool isSourceControlled() {
    return (null != getItem(cDCMCHECKEDOUTTO));
  }

  bool isTimeForShow(XmlItem hEventItem, DateTime dtCurr, double dbDuration) {
    // Check if the current time is within the event's lobby time
    DateTime dtFrom = DateTime.parse(
        '1970-01-01 ${hEventItem.getItemValue('LobbyTimeFrom')}');
    DateTime dtTo =
        DateTime.parse('1970-01-01 ${hEventItem.getItemValue('LobbyTimeTo')}');

    DateTime dtCurrent = DateTime.parse(
        '1970-01-01 ${dtCurr.hour}:${dtCurr.minute}:${dtCurr.second}');

    if (dtFrom.compareTo(dtTo) > 0) {
      // Handle case where event spans midnight
      if (dtCurrent.compareTo(dtFrom) >= 0 || dtCurrent.compareTo(dtTo) < 0) {
        dbDuration = dtTo.difference(dtFrom).inSeconds.toDouble();
        return true;
      }
    } else {
      if (dtCurrent.compareTo(dtFrom) >= 0 && dtCurrent.compareTo(dtTo) < 0) {
        dbDuration = dtTo.difference(dtFrom).inSeconds.toDouble();
        return true;
      }
    }

    return false;
  }

  @override
  bool loadEx([String? szRootItemName]) {
    return super.loadEx(szRootItemName ?? cEVENTDATEROOT);
  }

  bool loadFile({String? filePath, XfOpen mode = XfOpen.read}) {
    if (filePath == null || filePath.isEmpty) {
      filePath = path.join(AppGlobal.lobbyPath,
          '${DateFormat('yyyyMMdd').format(DateTime.now())}.xml');
    }

    if (!open(filePath, mode)) {
      return false;
    }

    return loadEx();
  }

  XmlItem? newEventItem(String title, {int? dwID}) {
    XmlItem? pXIParent = root();

    if (pXIParent == null) {
      return null;
    }

    XmlItem pXINew = newItem(cEVENTDATEEVENTITEM);
    pXIParent.addItemObj(pXINew);

    // set ID and name
    setEventTitle(pXINew, title);

    if (dwID == null || dwID <= 0) {
      dwID = nextUniqueID++;
    } else {
      nextUniqueID = max(nextUniqueID, dwID + 1);
    }

    setEventID(pXINew, dwID);

    return pXINew;
  }

  bool setBackgroundColor(XmlItem hEventItem, String backgroundColor) {
    hEventItem.setItemValue('backgroundColor', backgroundColor);
    return true;
  }

  bool setCharset(String charset) {
    return (null != setItemValue(cEVENTDATECHARSET, charset));
  }

  bool setCheckedOutTo(String checkedOutTo) {
    return (null != setItemValue(cEVENTDATECHARSET, checkedOutTo));
  }

  bool setEventCChar(XmlItem hEventItem, String szCCharItem, String szVal,
      [bool bCData = false]) {
    return (hEventItem.setItemValue(
            szCCharItem, szVal, bCData ? XiType.cdata : XiType.attrib) !=
        null);
  }

  bool setEventDate(DateTime dtEventDate) {
    return (null !=
        setItemValue(cEVENTDATEDATETIME, toOleDateTime(dtEventDate)));
  }

  bool setEventEndTime(XmlItem hEventItem, String endTime) {
    hEventItem.setItemValue('BookTimeTo', endTime);
    return true;
  }

  bool setEventEndTime1(XmlItem hEventItem, String endTime1) {
    hEventItem.setItemValue('DisplayTimeTo', endTime1);
    return true;
  }

  bool setEventEndTime2(XmlItem hEventItem, String endTime2) {
    hEventItem.setItemValue('LobbyTimeTo', endTime2);
    return true;
  }

  bool setEventID(XmlItem hEventItem, int nEventID) {
    hEventItem.setItemValue('EventID', nEventID);
    return true;
  }

  bool setEventRoomDesc(XmlItem hEventItem, String roomDesc) {
    hEventItem.setItemValue('RoomDesc', roomDesc);
    return true;
  }

  bool setEventRoomID(XmlItem hEventItem, int roomID) {
    hEventItem.setItemValue('RoomID', roomID);
    return true;
  }

  bool setEventRoomIndex(XmlItem hEventItem, int roomIndex) {
    hEventItem.setItemValue('RoomIndex', roomIndex);
    return true;
  }

  bool setEventRoomName(XmlItem hEventItem, String roomName) {
    hEventItem.setItemValue('RoomName', roomName);
    return true;
  }

  bool setEventRoomVenue(XmlItem hEventItem, String roomVenue) {
    hEventItem.setItemValue('RoomVenue', roomVenue);
    return true;
  }

  bool setEventStartTime(XmlItem hEventItem, String startTime) {
    hEventItem.setItemValue('BookTimeFrom', startTime);
    return true;
  }

  bool setEventStartTime1(XmlItem hEventItem, String startTime1) {
    hEventItem.setItemValue('DisplayTimeFrom', startTime1);
    return true;
  }

  bool setEventStartTime2(XmlItem hEventItem, String startTime2) {
    hEventItem.setItemValue('LobbyTimeFrom', startTime2);
    return true;
  }

  bool setEventTitle(XmlItem hEventItem, String title) {
    hEventItem.setItemValue('Title', title);
    return true;
  }

  bool setEventTitleImage(XmlItem hEventItem, String titleImage) {
    hEventItem.setItemValue('TitleImage', titleImage);
    return true;
  }

  bool setFileFormat(int format) {
    return (null != setItemValue(cDCMFILEFORMAT, format));
  }

  bool setFileVersion(int version) {
    return (null != setItemValue(cDCMFILEVERSION, version));
  }

  bool setHtmlContent(XmlItem hEventItem, String htmlContent) {
    hEventItem.setItemValue('lobbyContent', htmlContent);
    return true;
  }

  bool setLinesOfPage(int lines) {
    return (null != setItemValue(cEVENTDATELINES, lines));
  }

  bool setLobbyUrl(String lobbyUrl) {
    return (null != setItemValue(cEVENTDATELOBBYURL, lobbyUrl));
  }

  bool setNextUniqueID(int nextID) {
    nextUniqueID = nextID;
    return true;
  }

  bool setPlayerUniqueId(XmlItem hEventItem, String playerUniqueId) {
    hEventItem.setItemValue('playerUniqueId', playerUniqueId);
    return true;
  }

  bool setScreenHeight(XmlItem hEventItem, int screenHeight) {
    hEventItem.setItemValue('screenHeight', screenHeight);
    return true;
  }

  bool setScreenWidth(XmlItem hEventItem, int screenWidth) {
    hEventItem.setItemValue('screenWidth', screenWidth);
    return true;
  }

  bool setScrollDelay(int delay) {
    return (null != setItemValue(cEVENTDATEDELAY, delay));
  }

  bool setServerUrl(String serverUrl) {
    return (null != setItemValue(cEVENTDATESERVERURL, serverUrl));
  }

  void sortEventByLobbyTime() {
    sortItems(cEVENTDATEEVENTITEM, cEVENTDATESTARTTIME2);
  }
}
