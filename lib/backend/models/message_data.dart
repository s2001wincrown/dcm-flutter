// MessageData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/ftpsite.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zoneext_data.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

import 'zone_data.dart';

/// Ad hoc message end types
class AhEndType {
  static const int byTime = 0;
  static const int manual = 1;
  static const int timeout = 2;
  static const int playOneTime = 3;
}

const int cAHMESSAGETYPE = 1000;
const int cTOUCHSCREENTYPE = 1100;

/// Message position in screen
class AhPosition {
  static const int fullScreen = 0;
  static const int top = 1;
  static const int bottom = 2;
  static const int inZone =
      3; // play ah in Specified zone but not stop zone play
  static const int bottomMZ = 4;
  static const int replaceZone =
      5; // play ah in Specified zone and stop current zone play
}

/// AH Message flags
class AhMsgFlag {
  static const int overlay = 0x0001; // AH Message overlay in playlist
  static const int stopPlaylist =
      0x0002; // stop current playlist when play AH message
}

/// Class to hold the data for Ad hoc message
class MessageData {
  // Attributes
  int uiID = -1; // Ad hoc Message ID
  String strAHName = ''; // Ad hoc Message name
  String strAHDesc = ''; // Ad hoc Message description
  String strAHDesc1 = ''; // Ad hoc Message description
  int nStatus = 0; // Ad hoc message status;(0-Normal; 1-Stop; 2-Stop by user)
  int nLevel = 1;
  int nEndType = AhEndType.byTime;
  int nDelay = 5;
  int nAutoUpdate = 0;
  int uiOutput = 0;

  int bAlpha = 255;
  int nLayout = 2;
  int nMessageZone = 0;
  int nOverlay = 1;
  int nPercentScreen = 10;
  bool bStartImm = true;
  bool bEndManual = false;
  DateTime? dtStartTime;
  DateTime? dtEndTime;
  DateTime? dtStopTime;
  DateTime? dtCreateTime;

  String strContent = '';
  String strContent1 = '';
  String strContent2 = '';
  String strContent3 = '';
  String strContent4 = '';
  String strContent5 = '';

  String strUserCode = '';
  String strGroupCode = '';
  DateTime? dtModified;
  DateTime? dtCreated;

  LayoutData?
      pLayoutDataObj; //Layout data object(CLayoutData) for layout define.

  List<ZoneData> lstZone = [];

  List<FtpSite> sitesArray = [];

  MessageData() {
    dtStartTime = DateTime.now();
    dtEndTime = DateTime.now();
    dtStopTime = DateTime.now();
    dtCreateTime = DateTime.now();
  }

  /// Create a copy of this MessageData
  MessageData copy() {
    final copy = MessageData();
    copy.uiID = uiID;
    copy.strAHName = strAHName;
    copy.strAHDesc = strAHDesc;
    copy.strAHDesc1 = strAHDesc1;
    copy.nStatus = nStatus;
    copy.nLevel = nLevel;
    copy.nEndType = nEndType;
    copy.nDelay = nDelay;
    copy.nAutoUpdate = nAutoUpdate;
    copy.uiOutput = uiOutput;
    copy.nLayout = nLayout;
    copy.nMessageZone = nMessageZone;
    copy.nOverlay = nOverlay;
    copy.bAlpha = bAlpha;
    copy.nPercentScreen = nPercentScreen;
    copy.bStartImm = bStartImm;
    copy.bEndManual = bEndManual;
    copy.dtStartTime = dtStartTime;
    copy.dtEndTime = dtEndTime;
    copy.dtStopTime = dtStopTime;
    copy.dtCreateTime = dtCreateTime;
    copy.strContent = strContent;
    copy.strContent1 = strContent1;
    copy.strContent2 = strContent2;
    copy.strContent3 = strContent3;
    copy.strContent4 = strContent4;
    copy.strContent5 = strContent5;
    copy.strUserCode = strUserCode;
    copy.strGroupCode = strGroupCode;
    copy.dtModified = dtModified;
    copy.dtCreated = dtCreated;
    copy.lstZone = lstZone.map((zone) => zone.copy()).toList();
    copy.sitesArray = List.from(sitesArray);
    return copy;
  }

  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_uiID', uiID);
    pXmlItem.addItem('m_strAHName', strAHName);
    pXmlItem.addItem('m_strAHDesc', strAHDesc);
    pXmlItem.addItem('m_strAHDesc1', strAHDesc1);
    pXmlItem.addItem('m_bStartImm', bStartImm);
    pXmlItem.addItem('m_bEndManual', bEndManual);
    pXmlItem.addItem('m_dtStartTime', dtStartTime);
    pXmlItem.addItem('m_dtEndTime', dtEndTime);
    pXmlItem.addItem('m_dtStopTime', dtStopTime);
    pXmlItem.addItem('m_dtCreateTime', dtCreateTime);
    pXmlItem.addItem('m_nLayout', nLayout);
    pXmlItem.addItem('m_nOverlay', nOverlay);
    pXmlItem.addItem('m_bAlpha', bAlpha);
    pXmlItem.addItem('m_nPercentScreen', nPercentScreen);
    pXmlItem.addItem('m_nMessageZone', nMessageZone);
    pXmlItem.addItem('m_nStatus', nStatus);
    pXmlItem.addItem('m_nLevel', nLevel);
    pXmlItem.addItem('m_nEndType', nEndType);
    pXmlItem.addItem('m_nDelay', nDelay);
    pXmlItem.addItem('m_nAutoUpdate', nAutoUpdate);
    pXmlItem.addItem('m_uiOutput', uiOutput);

    pXmlItem.addItem('m_strUserCode', strUserCode);
    pXmlItem.addItem('m_strGroupCode', strGroupCode);
    pXmlItem.addItem('m_dtModified', dtModified);
    pXmlItem.addItem('m_dtCreated', dtCreated);

    for (var pZoneData in lstZone) {
      XmlItem? xiZoneItem = pXmlItem.addItem('m_ZoneData');
      if (xiZoneItem != null) {
        pZoneData.writeToXML(xiZoneItem);
        xiZoneItem.setItemValue('ContentListID', pZoneData.uiID + 1);
      }
    }

    XmlItem? pItem = pXmlItem.addItem('m_SitesArray');
    if (pItem != null) {
      for (int i = 0; i < sitesArray.length; i++) {
        XmlItem? xiPlayerItem = pItem.addItem('PlayerData');
        if (xiPlayerItem != null) {
          sitesArray[i].writeToXML(xiPlayerItem);
        }
      }
    }

    if (pLayoutDataObj != null) {
      XmlItem? xiLayoutItem = pXmlItem.addItem('LayoutData');
      if (xiLayoutItem != null) {
        DCMFileImpl.serializeLayoutTo(pLayoutDataObj!, xiLayoutItem);
      }
    }
  }

  void getFromXML(XmlItem pXmlItem) {
    uiID = pXmlItem.getItemValueI('m_uiID');
    strAHName = pXmlItem.getItemValue('m_strAHName');
    strAHDesc = pXmlItem.getItemValue('m_strAHDesc');
    strAHDesc1 = pXmlItem.getItemValue('m_strAHDesc1');
    bEndManual = pXmlItem.getItemValueB('m_bEndManual');
    bStartImm = pXmlItem.getItemValueB('m_bStartImm');
    dtStartTime = pXmlItem.getItemValueD('m_dtStartTime');
    dtEndTime = pXmlItem.getItemValueD('m_dtEndTime');
    dtStopTime = pXmlItem.getItemValueD('m_dtStopTime');
    dtCreateTime = pXmlItem.getItemValueD('m_dtCreateTime');
    nLayout = pXmlItem.getItemValueI('m_nLayout');
    nOverlay = pXmlItem.getItemValueI('m_nOverlay');
    bAlpha = pXmlItem.getItemValueI('m_bAlpha');
    nPercentScreen = pXmlItem.getItemValueI('m_nPercentScreen');
    nMessageZone = pXmlItem.getItemValueI('m_nMessageZone');
    nStatus = pXmlItem.getItemValueI('m_nStatus');
    nLevel = pXmlItem.getItemValueI('m_nLevel');
    nEndType = pXmlItem.getItemValueI('m_nEndType');
    nDelay = pXmlItem.getItemValueI('m_nDelay');
    nAutoUpdate = pXmlItem.getItemValueI('m_nAutoUpdate');
    uiOutput = pXmlItem.getItemValueI('m_uiOutput');

    strUserCode = pXmlItem.getItemValue('m_strUserCode');
    strGroupCode = pXmlItem.getItemValue('m_strGroupCode');
    dtModified = pXmlItem.getItemValueD('m_dtModified');
    dtCreated = pXmlItem.getItemValueD('m_dtCreated');

    lstZone.clear();
    String strZoneItem = 'm_ZoneData';
    XmlItem? pXISibling = pXmlItem.getItem(strZoneItem);
    while (pXISibling != null) {
      if (strZoneItem == pXISibling.getName()) {
        ZoneExtData pData = ZoneExtData();

        // get zone data
        pData.getFromXML(pXISibling);

        // add Player Channel data to list
        lstZone.add(pData);
      }

      pXISibling = pXISibling.getSibling();
    }

    sitesArray.clear();
    XmlItem? pItem = pXmlItem.getItem('m_SitesArray');
    if (pItem != null) {
      pXISibling = pItem.getItem('PlayerData');
      while (pXISibling != null) {
        FtpSite ftpSite = FtpSite();

        // get Player channel Inforamtion data
        ftpSite.getFromXML(pXISibling);

        // add Player Channel data to list
        sitesArray.add(ftpSite);

        pXISibling = pXISibling.getSibling();
      }
    }

    pLayoutDataObj = null;
    XmlItem? xiLayoutItem = pXmlItem.getItem('LayoutData');
    if (xiLayoutItem != null && xiLayoutItem.getItemCount() > 0) {
      pLayoutDataObj = DCMFileImpl.serializeLayoutFrom(xiLayoutItem);
    }
  }

  ZoneData? getZoneData([int nZone = 0]) {
    for (var pZoneData in lstZone) {
      if (pZoneData.nZoneID == nZone) {
        return pZoneData;
      }
    }
    return null;
  }

  void copyFromZoneData(List<ZoneData> lstZoneData) {
    lstZone.clear();
    for (var pZoneData in lstZoneData) {
      lstZone.add(pZoneData.copy());
    }
  }

  List<ProductData> getProductInitFromZoneData(List<ProductData> lstProduct) {
    int nProduct = lstProduct.length;
    for (var pZoneData in lstZone) {
      if (pZoneData is ZoneExtData) {
        if (!pZoneData.isOutdated()) {
          ProductData pProduct = ProductData();
          pProduct.uiID = nProduct;
          pProduct.lstZone.add(pZoneData.copy());

          lstProduct.add(pProduct);
          nProduct++;
        }
      }
    }

    return lstProduct;
  }

  bool getZoneDataList(List<ZoneExtData> lstZoneData) {
    for (var pZoneData in lstZone) {
      if (pZoneData is ZoneExtData) {
        if (!pZoneData.isOutdated()) {
          lstZoneData.add(pZoneData.copy());
        }
      }
    }
    return true;
  }

  int getOutput(int nOutput, MessageData pMessageData) {
    int nTemp = pMessageData.uiOutput == -2 ? nOutput : pMessageData.uiOutput;
    int nLayer = 0;
    if ((pMessageData.nOverlay & cAHMSGLAYERED) == 0) {
      nLayer = 1;
    }

    return nTemp < 0 ? fMAKEWORD(cBYTEMAX, nLayer) : fMAKEWORD(nTemp, nLayer);
  }
}
