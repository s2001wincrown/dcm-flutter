// room_date_file.dart
import 'dart:convert';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/room_event_data.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class RoomDateFile extends XmlFile {
  static const String cROOMDATESERVERURL = 'ServerUrl';
  static const String cROOMDATEDATETIME = 'DateTime';
  static const String cROOMDATEROOT = 'Event';
  static const String cROOMDATEROOMITEM = 'Room';
  static const String cROOMDATEROOMID = 'RoomID';
  static const String cROOMDATEROOMINDEX = 'm_uiIndex';
  static const String cROOMDATEBGIMAGE = 'm_strFile';
  static const String cROOMDATETITLEIMAGE = 'm_strTitleImage';
  static const String cROOMDATEXMLIMAGES = 'm_strXMLFormat';
  static const String cROOMDATEHTML = 'm_strHtml';
  static const String cROOMDATECONTENT = 'm_strContent';
  static const String cROOMDATECONTENTTYPE = 'm_nContentType';
  static const String cROOMDATESECTIONITEM = 'Section';

  late String rootElement;
  late Map<String, dynamic> data;
  late int nextUniqueID;
  late Map<dynamic, dynamic> handles; // Maps handles to XML items

  RoomDateFile({String? password}) {
    rootElement = 'Event';
    data = {'Event': {}};
    nextUniqueID = 0;
    handles = {};
  }

  bool loadFile(
      {String? filePath,
      XfOpen mode = XfOpen.read,
      bool ignoreDefaultXml = false}) {
    if (filePath == null || filePath.isEmpty) {
      filePath = path.join(DCMGlobal.roomEventPath,
          '${DateFormat('yyyyMMdd').format(DateTime.now())}.xml');
      if (!ignoreDefaultXml && !File(filePath).existsSync()) {
        filePath = path.join(DCMGlobal.roomEventPath, 'defaultXML.xml');
      }
    }

    if (!open(filePath, mode)) {
      return false;
    }

    return loadEx();
  }

  bool loadDefaultXml() {
    // This would load a default XML file
    String fileName = path.join(DCMGlobal.roomEventPath, 'defaultXML.xml');
    return load(fileName);
  }

  Future<bool> saveAs(String filePath) async {
    try {
      String content = json.encode(data);
      await File(filePath).writeAsString(content);
      return true;
    } catch (e) {
      print('Error saving file: $e');
      return false;
    }
  }

  bool copy(RoomDateFile source) {
    data = Map.from(source.data);
    nextUniqueID = source.nextUniqueID;
    _buildHandleMap();
    return true;
  }

  int getRoomItemCount() {
    return handles.length;
  }

  int getNextUniqueID() {
    return nextUniqueID;
  }

  RoomData? getRoomData(int nRoomIndex) {
    XmlItem? pXI = findItem(cROOMDATEROOMINDEX, nRoomIndex);
    if (pXI != null) {
      XmlItem? parent = pXI.getParent();
      if (parent != null) {
        RoomData roomData = RoomData();
        roomData.getFromXML(parent);
        return roomData;
      }
    }

    return null;
  }

  List<String> getBackgroundImages(List<int> lstSection) {
    List<String> images = [];
    var rooms = _getRooms();

    for (var room in rooms) {
      var sections = room['m_lstSectionContent'] as List? ?? [];
      for (var section in sections) {
        if (lstSection.isEmpty || lstSection.contains(section['m_uiID'])) {
          String? image = section['m_strFile'];
          if (image != null && !images.contains(image)) {
            images.add(image);
          }
        }
      }
    }

    return images;
  }

  String? getServerUrl() {
    return data[rootElement]?['ServerUrl'];
  }

  bool setCheckedOutTo(String checkedOutTo) {
    data[rootElement]?['CheckedOutTo'] = checkedOutTo;
    return true;
  }

  bool setFileFormat(int format) {
    data[rootElement]?['FileFormat'] = format;
    return true;
  }

  bool setNextUniqueID(int nextID) {
    nextUniqueID = nextID;
    return true;
  }

  bool setEventDate(DateTime eventDate) {
    data[rootElement]?['DateTime'] =
        eventDate.millisecondsSinceEpoch.toDouble();
    return true;
  }

  bool setServerUrl(String serverUrl) {
    data[rootElement]?['ServerUrl'] = serverUrl;
    return true;
  }

  bool addRoom(RoomData room) {
    var rooms = _getRooms();
    var roomMap = {
      'm_uiID': room.uiID,
      'm_uiIndex': room.uiIndex,
      'm_strRoomName': room.roomName,
      'm_strRoomDesc': room.roomDesc,
      'm_strVenue': room.venue,
      'm_strPlayerName': room.playerName,
      'm_strMacAddress': room.macAddress,
      'm_strDiskSerial': room.diskSerial,
      'm_strLocation': room.location,
      'm_strIPAddress': room.ipAddress,
      'm_bRoomDef': room.roomDef,
      'm_bIsDeleted': room.isDeleted,
    };

    rooms.add(roomMap);
    _updateRooms(rooms);
    return true;
  }

  bool addSectionToRoom(SectionContentData section) {
    var rooms = _getRooms();
    for (var room in rooms) {
      if (room['m_uiID'] == section.roomID) {
        var sections = room['m_lstSectionContent'] as List? ?? [];
        sections.add(section.toJson());
        room['m_lstSectionContent'] = sections;
        _updateRooms(rooms);
        return true;
      }
    }
    return false;
  }

  ({
    bool success,
    List<SectionContentData>? lstSectionContent,
    int? screenWidth,
    int? screenHeight
  }) getSectionListByRoom(int uiRoomID) {
    List<SectionContentData> lstSectionContent = [];
    int? screenWidth;
    int? screenHeight;
    if (uiRoomID != 0) {
      XmlItem? pRoomItem = findRoomItem(uiRoomID);
      if (pRoomItem != null) {
        XmlItem? pScreenItem = pRoomItem.getItem('m_uiScreenWidth');
        if (pScreenItem != null) {
          screenWidth = pScreenItem.getValueI();
        }
        pScreenItem = pRoomItem.getItem('m_uiScreenHeight');
        if (pScreenItem != null) {
          screenHeight = pScreenItem.getValueI();
        }
        XmlItem? pNameXISibling = pRoomItem.getItem(cROOMDATESECTIONITEM);
        while (pNameXISibling != null) {
          SectionContentData pSectionContent = SectionContentData();
          pSectionContent.getFromXML(pNameXISibling);
          lstSectionContent.add(pSectionContent);

          pNameXISibling = pNameXISibling.getSibling();
        }
        return (
          success: true,
          lstSectionContent: lstSectionContent,
          screenWidth: screenWidth,
          screenHeight: screenHeight
        );
      }
    } else {
      XmlItem? pRoomItem = getFirstRoomItem();
      while (pRoomItem != null) {
        XmlItem? pScreenItem = pRoomItem.getItem('m_uiScreenWidth');
        if (pScreenItem != null) {
          screenWidth = pScreenItem.getValueI();
        }
        pScreenItem = pRoomItem.getItem('m_uiScreenHeight');
        if (pScreenItem != null) {
          screenHeight = pScreenItem.getValueI();
        }
        XmlItem? pNameXISibling = pRoomItem.getItem(cROOMDATESECTIONITEM);
        while (pNameXISibling != null) {
          SectionContentData pSectionContent = SectionContentData();
          pSectionContent.getFromXML(pNameXISibling);
          lstSectionContent.add(pSectionContent);

          pNameXISibling = pNameXISibling.getSibling();
        }

        pRoomItem = getNextRoomItem(pRoomItem);
      }
      return (
        success: true,
        lstSectionContent: lstSectionContent,
        screenWidth: screenWidth,
        screenHeight: screenHeight
      );
    }
    return (
      success: false,
      lstSectionContent: null,
      screenWidth: null,
      screenHeight: null
    );
  }

  ({
    bool success,
    List<SectionContentData>? lstSectionContent,
    int? screenWidth,
    int? screenHeight
  }) getSectionListByRoomIndex(int nRoomIndex,
      {int? screenWidth, int? screenHeight}) {
    RoomData? roomData = getRoomData(nRoomIndex);

    return getSectionListByRoom(roomData!.uiID);
  }

  List<SectionContentData> getContents(List<int> lstSection) {
    var rooms = _getRooms();
    List<SectionContentData> contents = [];

    for (var room in rooms) {
      var sections = room['m_lstSectionContent'] as List? ?? [];
      for (var section in sections) {
        int contentType = section['m_nContentType'] ?? 0;
        if (contentType != 0) {
          // Assuming EVENT_TYPE = 0
          if (lstSection.isEmpty || lstSection.contains(section['m_uiID'])) {
            contents.add(SectionContentData.fromJson(section));
          }
        }
      }
    }

    return contents;
  }

  bool deleteRoomItemAttributes(XmlItem hRoomItem) {
    var pos = hRoomItem.getFirstItemPos();
    while (pos.moveNext()) {
      XmlItem pXIChild = pos.current;

      if (!pXIChild.nameMatches(cROOMDATEROOMITEM)) {
        hRoomItem.deleteItem(pXI: pXIChild);
      }
    }
    return true;
  }

  bool deleteRoomItem(XmlItem hRoomItem) {
    XmlItem? pXIParent = hRoomItem.getParent();
    assert(pXIParent != null);

    return pXIParent!.deleteItem(pXI: hRoomItem);
  }

  XmlItem? findRoomItem(int dwRoomItemID) {
    XmlItem? pXI = findItem(cROOMDATEROOMID, dwRoomItemID);

    return pXI?.getParent();
  }

  bool isCheckedOut() {
    // This would check if the file is checked out
    return false;
  }

  bool isSourceControlled() {
    return (null != getItem(cDCMCHECKEDOUTTO));
  }

  String? getCheckOutTo() {
    return getItemValue(cDCMCHECKEDOUTTO);
  }

  int getFileFormat() {
    return getItemValueI(cDCMFILEFORMAT);
  }

  int getFileVersion() {
    return getItemValueI(cDCMFILEVERSION);
  }

  bool setFileVersion(int version) {
    return (null != setItemValue(cDCMFILEVERSION, version));
  }

  XmlItem? getFirstRoomItem() {
    XmlItem? pXIParent = root();

    if (pXIParent == null) {
      return null;
    }

    return pXIParent.getItem(cROOMDATEROOMITEM);
  }

  XmlItem? getNextRoomItem(XmlItem hRoomItem) {
    return hRoomItem.getSibling();
  }

  DateTime getEventDateOle(String dateItem, bool includeTime) {
    // This would extract the event date
    var dateValue = data[rootElement]?[dateItem];
    if (dateValue != null) {
      if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is double) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue.toInt());
      }
    }
    return DateTime.now();
  }

  bool setEventDateItem(String dateItem, DateTime tVal, bool includeTime) {
    data[rootElement]?[dateItem] = includeTime
        ? tVal.millisecondsSinceEpoch.toDouble()
        : tVal.millisecondsSinceEpoch ~/ 86400000 * 86400000.toDouble();
    return true;
  }

  bool setEventDateItemTime(String dateItem, int tVal, bool includeTime) {
    if (tVal == 0) {
      return setEventDateItem(
          dateItem, DateTime.fromMillisecondsSinceEpoch(0), includeTime);
    }

    var date = DateTime.fromMillisecondsSinceEpoch(tVal * 1000);
    return setEventDateItem(dateItem, date, includeTime);
  }

  // Private helper methods
  List<dynamic> _getRooms() {
    return data[rootElement]?['m_lstRoom'] as List? ?? [];
  }

  void _updateRooms(List<dynamic> rooms) {
    data[rootElement]?['m_lstRoom'] = rooms;
  }

  void _buildHandleMap() {
    handles.clear();
    var rooms = _getRooms();
    for (int i = 0; i < rooms.length; i++) {
      handles[i] = rooms[i];
    }
  }
}
