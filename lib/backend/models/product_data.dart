import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'zone_data.dart';

/// Class to hold the data for Product
class ProductData {
  // Attributes
  int id = 0;
  int uiID = 0; // index for Page Tab
  int uiCatalogueID = 0; // Catalogue ID
  String strProductName = ''; // Product name
  String strProductDesc = ''; // Product description
  String strImgFile = ''; // Image file for product button
  String strBtnEvent = '';
  int nLanguage = 0;
  List<String> arrProductName = [];
  List<ZoneData> lstZone = [];

  /// Write to XML
  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_uiID', uiID);
    pXmlItem.addItem('m_strProductName', strProductName);
    pXmlItem.addItem('m_strProductDesc', strProductDesc);
    pXmlItem.addItem('m_strBtnEvent', strBtnEvent);
    pXmlItem.addItem('m_nLanguage', nLanguage);
    pXmlItem.addItem('m_strImgFile', strImgFile);

    // Write product names
    if (arrProductName.isNotEmpty) {
      XmlItem xiProductNames = pXmlItem.addItem('m_arrProductName')!;
      for (int i = 0; i < arrProductName.length; i++) {
        XmlItem xiName = xiProductNames.addItem('ProductName')!;
        xiName.addItem('CString', arrProductName[i]);
      }
    }

    // Write zones
    if (lstZone.isNotEmpty) {
      XmlItem xiZones = pXmlItem.addItem('m_lstZone')!;
      for (int i = 0; i < lstZone.length; i++) {
        XmlItem xiZoneData = xiZones.addItem('CZoneData')!;
        lstZone[i].writeToXML(xiZoneData);
      }
    }
  }

  /// Get from XML
  void getFromXML(XmlItem pXmlItem) {
    uiID = pXmlItem.getItemValueI('m_uiID');
    strProductName = pXmlItem.getItemValue('m_strProductName');
    strProductDesc = pXmlItem.getItemValue('m_strProductDesc');
    strBtnEvent = pXmlItem.getItemValue('m_strBtnEvent');
    nLanguage = pXmlItem.getItemValueI('m_nLanguage');
    strImgFile = pXmlItem.getItemValue('m_strImgFile');

    // Get product names
    XmlItem? pNameItem = pXmlItem.getItem('m_arrProductName');
    if (pNameItem != null) {
      arrProductName = [];
      var pos = pNameItem.getFirstItemPos();
      while (pos.moveNext()) {
        XmlItem pNameXISibling = pNameItem.getNextItem(pos);
        XmlItem? pCString = pNameXISibling.getItem('CString');
        if (pCString != null) {
          arrProductName.add(pCString.getValue());
        }
      }
    }

    // Get zones
    XmlItem? pItem = pXmlItem.getItem('m_lstZone');
    if (pItem != null) {
      lstZone.clear();
      var pZoneItem = pItem.getItem('CZoneData');
      while (pZoneItem != null) {
        ZoneData zone = ZoneData();
        zone.getFromXML(pZoneItem);
        lstZone.add(zone);
        pZoneItem = pZoneItem.getSibling();
      }
    }
  }

  /// Create a copy of this ProductData
  ProductData copy() {
    final copy = ProductData();
    copy.id = id;
    copy.uiID = uiID;
    copy.uiCatalogueID = uiCatalogueID;
    copy.strProductName = strProductName;
    copy.strProductDesc = strProductDesc;
    copy.strImgFile = strImgFile;
    copy.strBtnEvent = strBtnEvent;
    copy.nLanguage = nLanguage;
    copy.arrProductName = List.from(arrProductName);
    copy.lstZone = lstZone.map((zone) => zone.copy()).toList();
    return copy;
  }

  void validZoneData(int nZone) {
    if (nZone == lstZone.length) {
      return;
    }

    if (nZone > lstZone.length) {
      int nStart = lstZone.length;
      for (int i = nStart; i < nZone; i++) {
        ZoneData pZoneData = ZoneData();
        pZoneData.nZoneID = i;
        lstZone.add(pZoneData);
      }
    } else {
      List<ZoneData> zonesToRemove = [];
      for (var zoneData in lstZone) {
        if (zoneData.nZoneID >= nZone) {
          zonesToRemove.add(zoneData);
        }
      }
      lstZone.removeWhere((zone) => zonesToRemove.contains(zone));
    }
  }

  bool isValidForPlay() {
    for (var zoneData in lstZone) {
      if ((zoneData.strZoneFile.isNotEmpty) ||
          (zoneData.nZoneType == cPLUGINTYPE) ||
          (zoneData.nZoneType == cSITEPLAYLIST)) {
        return true;
      }
    }

    return false;
  }

  bool isAllSetting() {
    for (var zoneData in lstZone) {
      if (zoneData.nZoneType != cSITEPLAYLIST && zoneData.strZoneFile.isEmpty) {
        return false;
      }
    }
    return true;
  }

  ZoneData? getZoneData(int nZone) {
    for (var zoneData in lstZone) {
      if (zoneData.nZoneID == nZone) {
        return zoneData;
      }
    }
    return null;
  }

  int getZoneCount([ZoneEffectType nZoneEffect = ZoneEffectType.noEffect]) {
    int nZone = 0;
    for (var zoneData in lstZone) {
      if (zoneData.getZoneEffect() == nZoneEffect.value) {
        nZone++;
      }
    }

    return nZone;
  }

  int getZone(int nContentType) {
    int nZone = 0;
    for (var zoneData in lstZone) {
      if (zoneData.nZoneType == nContentType) {
        nZone = zoneData.nZoneID;
      }
    }
    return nZone;
  }

  List<ZoneData> getContents(int nType) {
    List<ZoneData> results = [];
    for (var zoneData in lstZone) {
      if (zoneData.nZoneType == nType) {
        results.add(zoneData.copy());
      }
    }
    return results;
  }

  bool hasContentType(int nContentType) {
    for (var zoneData in lstZone) {
      if (zoneData.nZoneType == nContentType) {
        //DIRECTPLAY_TYPE
        return true;
      }
    }
    return false;
  }
}
