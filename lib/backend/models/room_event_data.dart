// Helper classes for the objects
import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

class RoomData {
  late int uiID;
  late int uiGroupID;
  late int uiIndex;
  late String roomCode;
  late String roomName;
  late String roomDesc;
  late String venue;
  late String playerName;
  late String macAddress;
  late String diskSerial;
  late String location;
  late String ipAddress;
  late bool roomDef;
  late bool isDeleted;
  late String userCode;
  late String groupCode;
  late DateTime modified;
  late DateTime createTime;

  RoomData({
    this.uiID = -1,
    this.uiGroupID = -1,
    this.uiIndex = 0,
    this.roomCode = '',
    this.roomName = '',
    this.roomDesc = '',
    this.venue = '',
    this.playerName = '',
    this.macAddress = '',
    this.diskSerial = '',
    this.location = '',
    this.ipAddress = '',
    this.roomDef = false,
    this.isDeleted = false,
    this.userCode = '',
    this.groupCode = '',
    DateTime? modified,
    DateTime? createTime,
  })  : modified = modified ?? DateTime.now(),
        createTime = createTime ?? DateTime.now();

  factory RoomData.fromJson(Map<String, dynamic> json) {
    return RoomData(
      uiID: json['uiID'] ?? -1,
      uiGroupID: json['uiGroupID'] ?? -1,
      uiIndex: json['uiIndex'] ?? 0,
      roomCode: json['roomCode'] ?? '',
      roomName: json['roomName'] ?? '',
      roomDesc: json['roomDesc'] ?? '',
      venue: json['venue'] ?? '',
      playerName: json['playerName'] ?? '',
      macAddress: json['macAddress'] ?? '',
      diskSerial: json['diskSerial'] ?? '',
      location: json['location'] ?? '',
      ipAddress: json['ipAddress'] ?? '',
      roomDef: json['roomDef'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      userCode: json['userCode'] ?? '',
      groupCode: json['groupCode'] ?? '',
      modified: DateTime.tryParse(json['modified'] ?? '') ?? DateTime.now(),
      createTime: DateTime.tryParse(json['createTime'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uiID': uiID,
      'uiGroupID': uiGroupID,
      'uiIndex': uiIndex,
      'roomCode': roomCode,
      'roomName': roomName,
      'roomDesc': roomDesc,
      'venue': venue,
      'playerName': playerName,
      'macAddress': macAddress,
      'diskSerial': diskSerial,
      'location': location,
      'ipAddress': ipAddress,
      'roomDef': roomDef,
      'isDeleted': isDeleted,
      'userCode': userCode,
      'groupCode': groupCode,
      'modified': modified.toIso8601String(),
      'createTime': createTime.toIso8601String(),
    };
  }

  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_uiID', uiID);
    pXmlItem.addItem('m_uiGroupID', uiGroupID);
    pXmlItem.addItem('m_uiIndex', uiIndex);
    pXmlItem.addItem('m_strRoomName', roomName);
    pXmlItem.addItem('m_strRoomDesc', roomDesc);
    pXmlItem.addItem('m_strPlayerName', playerName);
    pXmlItem.addItem('m_strDiskSerial', diskSerial);
    pXmlItem.addItem('m_strMacAddress', macAddress);
    pXmlItem.addItem('m_strLocation', location);
    pXmlItem.addItem('m_strIPAddress', ipAddress);
    pXmlItem.addItem('m_strVenue', venue);
  }

  void getFromXML(XmlItem pXmlItem) {
    uiID = pXmlItem.getItemValueI('m_uiID');
    uiGroupID = pXmlItem.getItemValueI('m_uiGroupID');
    uiIndex = pXmlItem.getItemValueI('m_uiIndex');
    roomName = pXmlItem.getItemValue('m_strRoomName');
    roomDesc = pXmlItem.getItemValue('m_strRoomDesc');
    playerName = pXmlItem.getItemValue('m_strPlayerName');
    diskSerial = pXmlItem.getItemValue('m_strDiskSerial');
    macAddress = pXmlItem.getItemValue('m_strMacAddress');
    location = pXmlItem.getItemValue('m_strLocation');
    ipAddress = pXmlItem.getItemValue('m_strIPAddress');
    venue = pXmlItem.getItemValue('m_strVenue');
  }
}

class SectionContentData {
  late int uiID;
  late DateTime eventDate;
  late int roomID;
  late String title;
  late String titleImage;
  late String startTime;
  late String endTime;
  late String startTime1;
  late String endTime1;
  late String startTime2;
  late String endTime2;
  late String content;
  late String html;
  late String xmlFormat;
  late int contentType;
  late int bg;
  late String file;
  late int font;
  late int direction;
  late double duration;
  late int speed;
  late int top;
  late int left;
  late int behavior;
  late int language;
  late String charset;
  late String textFontName;
  late String halign;
  late int bullet;
  late int indent;
  late bool fontItalic;
  late bool fontBold;
  late bool fontUnderline;
  late bool strikethrough;
  late bool isGif;
  late bool hlColor;
  late String languageStr;
  late String backgRepeat;
  late String backgAttachment;
  late String backgPosition;
  late int textFontSize;
  late int textFgColor;
  late int textBkColor;
  late int textHlColor;
  late int horiAlign;
  late int vertAlign;
  late int layout;
  late int uiCustID;
  late String custCode;
  late String company;
  late String remark;
  late String roomVenue;
  late String eventDateStr;
  late String userCode;
  late String groupCode;
  late DateTime modified;
  late DateTime createTime;
  late int scrollAmount;

  SectionContentData({
    this.uiID = -1,
    DateTime? eventDate,
    this.roomID = -1,
    this.title = '',
    this.titleImage = '',
    this.startTime = '00:00:00',
    this.endTime = '00:00:00',
    this.startTime1 = '00:00:00',
    this.endTime1 = '00:00:00',
    this.startTime2 = '00:00:00',
    this.endTime2 = '00:00:00',
    this.content = '',
    this.html = '',
    this.xmlFormat = '',
    this.contentType = 0,
    this.bg = 0,
    this.file = '',
    this.font = 0,
    this.direction = 0,
    this.duration = 60.0,
    this.speed = 5,
    this.top = 0,
    this.left = 0,
    this.behavior = 0,
    this.language = 0,
    this.charset = 'utf-8',
    this.textFontName = 'Arial',
    this.halign = 'left',
    this.bullet = 0,
    this.indent = 0,
    this.fontItalic = false,
    this.fontBold = false,
    this.fontUnderline = false,
    this.strikethrough = false,
    this.isGif = false,
    this.hlColor = true,
    this.languageStr = 'ENG',
    this.backgRepeat = 'repeat',
    this.backgAttachment = 'scroll',
    this.backgPosition = 'top left',
    this.textFontSize = 12,
    this.textFgColor = 0xFFFFFFFF,
    this.textBkColor = 0xFF000000,
    this.textHlColor = 0xFFFFFFFF,
    this.horiAlign = 1,
    this.vertAlign = 1,
    this.layout = 0,
    this.uiCustID = -1,
    this.custCode = '',
    this.company = '',
    this.remark = '',
    this.roomVenue = '',
    this.eventDateStr = '',
    this.userCode = '',
    this.groupCode = '',
    DateTime? modified,
    DateTime? createTime,
    this.scrollAmount = 8,
  })  : eventDate = eventDate ?? DateTime.now(),
        modified = modified ?? DateTime.now(),
        createTime = createTime ?? DateTime.now();

  factory SectionContentData.fromJson(Map<String, dynamic> json) {
    return SectionContentData(
      uiID: json['uiID'] ?? -1,
      eventDate: DateTime.tryParse(json['eventDate'] ?? '') ?? DateTime.now(),
      roomID: json['roomID'] ?? -1,
      title: json['title'] ?? '',
      titleImage: json['titleImage'] ?? '',
      startTime: json['startTime'] ?? '00:00:00',
      endTime: json['endTime'] ?? '00:00:00',
      startTime1: json['startTime1'] ?? '00:00:00',
      endTime1: json['endTime1'] ?? '00:00:00',
      startTime2: json['startTime2'] ?? '00:00:00',
      endTime2: json['endTime2'] ?? '00:00:00',
      content: json['content'] ?? '',
      html: json['html'] ?? '',
      xmlFormat: json['xmlFormat'] ?? '',
      contentType: json['contentType'] ?? 0,
      bg: json['bg'] ?? 0,
      file: json['file'] ?? '',
      font: json['font'] ?? 0,
      direction: json['direction'] ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 60.0,
      speed: json['speed'] ?? 5,
      top: json['top'] ?? 0,
      left: json['left'] ?? 0,
      behavior: json['behavior'] ?? 0,
      language: json['language'] ?? 0,
      charset: json['charset'] ?? 'utf-8',
      textFontName: json['textFontName'] ?? 'Arial',
      halign: json['halign'] ?? 'left',
      bullet: json['bullet'] ?? 0,
      indent: json['indent'] ?? 0,
      fontItalic: json['fontItalic'] ?? false,
      fontBold: json['fontBold'] ?? false,
      fontUnderline: json['fontUnderline'] ?? false,
      strikethrough: json['strikethrough'] ?? false,
      isGif: json['isGif'] ?? false,
      hlColor: json['hlColor'] ?? true,
      languageStr: json['languageStr'] ?? 'ENG',
      backgRepeat: json['backgRepeat'] ?? 'repeat',
      backgAttachment: json['backgAttachment'] ?? 'scroll',
      backgPosition: json['backgPosition'] ?? 'top left',
      textFontSize: json['textFontSize'] ?? 12,
      textFgColor: json['textFgColor'] ?? 0xFFFFFFFF,
      textBkColor: json['textBkColor'] ?? 0xFF000000,
      textHlColor: json['textHlColor'] ?? 0xFFFFFFFF,
      horiAlign: json['horiAlign'] ?? 1,
      vertAlign: json['vertAlign'] ?? 1,
      layout: json['layout'] ?? 0,
      uiCustID: json['uiCustID'] ?? -1,
      custCode: json['custCode'] ?? '',
      company: json['company'] ?? '',
      remark: json['remark'] ?? '',
      roomVenue: json['roomVenue'] ?? '',
      eventDateStr: json['eventDateStr'] ?? '',
      userCode: json['userCode'] ?? '',
      groupCode: json['groupCode'] ?? '',
      modified: DateTime.tryParse(json['modified'] ?? '') ?? DateTime.now(),
      createTime: DateTime.tryParse(json['createTime'] ?? '') ?? DateTime.now(),
      scrollAmount: json['scrollAmount'] ?? 8,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uiID': uiID,
      'eventDate': eventDate.toIso8601String(),
      'roomID': roomID,
      'title': title,
      'titleImage': titleImage,
      'startTime': startTime,
      'endTime': endTime,
      'startTime1': startTime1,
      'endTime1': endTime1,
      'startTime2': startTime2,
      'endTime2': endTime2,
      'content': content,
      'html': html,
      'xmlFormat': xmlFormat,
      'contentType': contentType,
      'bg': bg,
      'file': file,
      'font': font,
      'direction': direction,
      'duration': duration,
      'speed': speed,
      'top': top,
      'left': left,
      'behavior': behavior,
      'language': language,
      'charset': charset,
      'textFontName': textFontName,
      'halign': halign,
      'bullet': bullet,
      'indent': indent,
      'fontItalic': fontItalic,
      'fontBold': fontBold,
      'fontUnderline': fontUnderline,
      'strikethrough': strikethrough,
      'isGif': isGif,
      'hlColor': hlColor,
      'languageStr': languageStr,
      'backgRepeat': backgRepeat,
      'backgAttachment': backgAttachment,
      'backgPosition': backgPosition,
      'textFontSize': textFontSize,
      'textFgColor': textFgColor,
      'textBkColor': textBkColor,
      'textHlColor': textHlColor,
      'horiAlign': horiAlign,
      'vertAlign': vertAlign,
      'layout': layout,
      'uiCustID': uiCustID,
      'custCode': custCode,
      'company': company,
      'remark': remark,
      'roomVenue': roomVenue,
      'eventDateStr': eventDateStr,
      'userCode': userCode,
      'groupCode': groupCode,
      'modified': modified.toIso8601String(),
      'createTime': createTime.toIso8601String(),
      'scrollAmount': scrollAmount,
    };
  }

  DateTime? getStartTime(DateTime dtCurr) {
    if (startTime.isEmpty) {
      return null;
    }

    return mergeTimeFrom(dtCurr, startTime);
  }

  DateTime? getEndTime(DateTime dtCurr) {
    if (endTime.isEmpty) {
      return null;
    }

    return mergeTimeFrom(dtCurr, endTime);
  }

  DateTime? getStartTime1(DateTime dtCurr) {
    if (startTime1.isEmpty) {
      return null;
    }

    return mergeTimeFrom(dtCurr, startTime1);
  }

  DateTime? getEndTime1(DateTime dtCurr) {
    if (endTime1.isEmpty) {
      return null;
    }

    return mergeTimeFrom(dtCurr, endTime1);
  }

  DateTime? getStartTime2(DateTime dtCurr) {
    if (startTime2.isEmpty) {
      return null;
    }

    return mergeTimeFrom(dtCurr, startTime2);
  }

  DateTime? getEndTime2(DateTime dtCurr) {
    if (endTime2.isEmpty) {
      return null;
    }

    return mergeTimeFrom(dtCurr, endTime2);
  }

  bool filterSection(String strStartTime, String strEndTime) {
    if (strStartTime == '00:00:00' && strEndTime == '00:00:00') {
      return true;
    }

    return false;
  }

  bool filterCompany(String strCompanyFrom, String strCompanyTo) {
    if (strCompanyFrom.isEmpty && strCompanyTo.isEmpty) {
      return true;
    }

    if (strCompanyTo.isEmpty && company.compareTo(strCompanyFrom) >= 0) {
      return true;
    }

    if (strCompanyFrom.isEmpty && company.compareTo(strCompanyTo) <= 0) {
      return true;
    }

    return false;
  }

  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_uiID', uiID);
    pXmlItem.addItem('m_uiRoomID', roomID);
    pXmlItem.addItem('m_nContentType', contentType);
    //pXmlItem.addItem('m_bAttachmentFlag', bAttachmentFlag);
    pXmlItem.addItem('m_strTitle', title);
    pXmlItem.addItem('m_strTitleImage', titleImage);
    pXmlItem.addItem('m_dtStartTime', startTime);
    pXmlItem.addItem('m_dtEndTime', endTime);
    pXmlItem.addItem('m_dtStartTime1', startTime1);
    pXmlItem.addItem('m_dtEndTime1', endTime1);
    pXmlItem.addItem('m_dtStartTime2', startTime2);
    pXmlItem.addItem('m_dtEndTime2', endTime2);
    pXmlItem.addItem('m_strTextFontName', textFontName);
    pXmlItem.addItem('m_nTextFontSize', textFontSize);
    pXmlItem.addItem('m_nBg', bg);
    pXmlItem.addItem('m_nLanguage', language);
    pXmlItem.addItem('m_strLanguage', languageStr);
    pXmlItem.addItem('m_strCharset', charset);
    pXmlItem.addItem('m_crTextFGColor', textFgColor);
    pXmlItem.addItem('m_crTextBKColor', textBkColor);
    pXmlItem.addItem('m_strFile', file);
    pXmlItem.addItem('m_strContent', content);
    pXmlItem.addItem('m_strHtml', html);
    pXmlItem.addItem('m_strXMLFormat', xmlFormat);
    pXmlItem.addItem('m_bFontBold', fontBold);
    pXmlItem.addItem('m_bFontItalic', fontItalic);
    pXmlItem.addItem('m_bFontUnderline', fontUnderline);
    pXmlItem.addItem('m_uiCustID', uiCustID);
    pXmlItem.addItem('m_strCompany', company);
    pXmlItem.addItem('m_strCustCode', custCode);
    pXmlItem.addItem('m_strRemark', remark);
  }

  void getFromXML(XmlItem pXmlItem) {
    uiID = pXmlItem.getItemValueI('m_uiID');
    roomID = pXmlItem.getItemValueI('m_uiRoomID');
    contentType = cEVENTTYPE;
    XmlItem? pItem = pXmlItem.getItem('m_nContentType');
    if (pItem != null) {
      contentType = pXmlItem.getItemValueI('m_nContentType');
    }
    //m_bAttachmentFlag = pXmlItem.getItemValueI('m_bAttachmentFlag') > 0;
    title = pXmlItem.getItemValue('m_strTitle');
    titleImage = pXmlItem.getItemValue('m_strTitleImage');
    startTime = pXmlItem.getItemValue('m_dtStartTime');
    endTime = pXmlItem.getItemValue('m_dtEndTime');
    startTime1 = pXmlItem.getItemValue('m_dtStartTime1');
    endTime1 = pXmlItem.getItemValue('m_dtEndTime1');
    startTime2 = pXmlItem.getItemValue('m_dtStartTime2');
    endTime2 = pXmlItem.getItemValue('m_dtEndTime2');
    textFontName = pXmlItem.getItemValue('m_strTextFontName');
    textFontSize = pXmlItem.getItemValueI('m_nTextFontSize');
    bg = pXmlItem.getItemValueI('m_nBg');
    language = pXmlItem.getItemValueI('m_nLanguage');
    languageStr = pXmlItem.getItemValue('m_strLanguage');
    charset = pXmlItem.getItemValue('m_strCharset');
    textFgColor = pXmlItem.getItemValueR('m_crTextFGColor') ?? 0xFF000000;
    textBkColor = pXmlItem.getItemValueR('m_crTextBKColor') ?? 0xFFFFFFFF;
    file = pXmlItem.getItemValue('m_strFile');
    content = pXmlItem.getItemValue('m_strContent');
    XmlItem? pContents = pXmlItem.getItem('Contents');
    if (pContents != null) {
      XmlFilePro fileLocal = XmlFilePro('Contents', null);
      fileLocal.root()!.copy(pContents, false);
      content = fileLocal.export();
      fileLocal.close();
    }

    html = pXmlItem.getItemValue('m_strHtml');
    xmlFormat = pXmlItem.getItemValue('m_strXMLFormat');
    fontBold = pXmlItem.getItemValueB('m_bFontBold');
    fontItalic = pXmlItem.getItemValueB('m_bFontItalic');
    fontUnderline = pXmlItem.getItemValueB('m_bFontUnderline');

    uiCustID = pXmlItem.getItemValueI('m_uiCustID');
    company = pXmlItem.getItemValue('m_strCompany');
    custCode = pXmlItem.getItemValue('m_strCustCode');
    remark = pXmlItem.getItemValue('m_strRemark');
  }

  bool isContentEmpty() {
    return content.isEmpty;
  }

  String getContent() {
    return html.isNotEmpty ? html : content;
  }
}

class RoomEventData {
  late int uiID;
  late int uiRoomID;
  late DateTime eventDate;
  late String playerName;
  late String macAddress;
  late String diskSerial;
  late String location;
  late String ipAddress;
  late String roomName;
  late String roomDesc;
  late String roomVenue;
  late List<SectionContentData> sectionContent;

  RoomEventData({
    this.uiID = -1,
    this.uiRoomID = 0,
    DateTime? eventDate,
    this.playerName = '',
    this.macAddress = '',
    this.diskSerial = '',
    this.location = '',
    this.ipAddress = '',
    this.roomName = '',
    this.roomDesc = '',
    this.roomVenue = '',
  })  : eventDate = eventDate ?? DateTime.now(),
        sectionContent = <SectionContentData>[];

  factory RoomEventData.fromJson(Map<String, dynamic> json) {
    return RoomEventData(
      uiID: json['uiID'] ?? -1,
      uiRoomID: json['uiRoomID'] ?? 0,
      eventDate: DateTime.tryParse(json['eventDate'] ?? '') ?? DateTime.now(),
      playerName: json['playerName'] ?? '',
      macAddress: json['macAddress'] ?? '',
      diskSerial: json['diskSerial'] ?? '',
      location: json['location'] ?? '',
      ipAddress: json['ipAddress'] ?? '',
      roomName: json['roomName'] ?? '',
      roomDesc: json['roomDesc'] ?? '',
      roomVenue: json['roomVenue'] ?? '',
    )..sectionContent = (json['sectionContent'] as List<dynamic>?)
            ?.map((e) => SectionContentData.fromJson(e))
            .toList() ??
        <SectionContentData>[];
  }

  Map<String, dynamic> toJson() {
    return {
      'uiID': uiID,
      'uiRoomID': uiRoomID,
      'eventDate': eventDate.toIso8601String(),
      'playerName': playerName,
      'macAddress': macAddress,
      'diskSerial': diskSerial,
      'location': location,
      'ipAddress': ipAddress,
      'roomName': roomName,
      'roomDesc': roomDesc,
      'roomVenue': roomVenue,
      'sectionContent': sectionContent.map((e) => e.toJson()).toList(),
    };
  }

  void addSectionContent(SectionContentData content) {
    sectionContent.add(content);
  }

  void removeSectionContent(int uiID) {
    sectionContent.removeWhere((content) => content.uiID == uiID);
  }

  bool isOverlayExistedSection(
    DateTime dtTimeStart,
    DateTime dtTimeEnd,
    SectionContentData? pSection,
  ) {
    for (var content in sectionContent) {
      if (pSection == null || (pSection != null && pSection != content)) {
        var dtTimeStart1 = DateTime.parse(content.startTime);
        var dtTimeEnd1 = DateTime.parse(content.endTime);

        if (dtTimeStart == dtTimeStart1 && dtTimeEnd == dtTimeEnd1) {
          return true;
        }
        if (dtTimeStart.isAfter(dtTimeStart1) &&
            dtTimeStart.isBefore(dtTimeEnd1)) {
          return true;
        }
        if (dtTimeEnd.isAfter(dtTimeStart1) && dtTimeEnd.isBefore(dtTimeEnd1)) {
          return true;
        }
      }
    }
    return false;
  }
}
