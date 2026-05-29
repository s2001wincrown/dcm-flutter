// ContentTypeImpl.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

import '../models/contenttype_data.dart';
import '../models/dcm_global.dart';

/// Class for ContentType manager
class ContentTypeManager {
  static List<ContentTypeData> contentTypeList = [];

  static void loadContentTypes() {
    contentTypeList.clear();
    XmlFile xmlContentTypes = XmlFile('ContentTypes');
    String strContentTypeFile =
        path.join(DCMGlobal.settingPath, 'ContentTypes.xml');
    if (xmlContentTypes.load(strContentTypeFile)) {
      XmlItem? xmlItem = xmlContentTypes.getItem('ContentType');
      while (xmlItem != null) {
        ContentTypeData contentType = ContentTypeData();
        contentTypeList.add(contentType);
        getFromXML(xmlItem, contentType);

        xmlItem = xmlItem.getSibling();
      }
    }
    if (contentTypeList.isEmpty) {
      loadBuiltinContentTypes();
    }
  }

  static void loadBuiltinContentTypes() {
    int i = 0;
    int nContentTypes = contentTypeTable.length;
    for (i = 0; i < nContentTypes; i++) {
      if (i == 2) {
        continue;
      }

      ContentTypeData contentTypeData = ContentTypeData.fromContent(
          i, contentTypeTable[i].strContentTypeName);
      contentTypeList.add(contentTypeData);

      contentTypeData.nSeq = contentTypeTable[i].nSeq;
      contentTypeData.strFilter = contentTypeTable[i].strFilter;
      contentTypeData.dwFlag = contentTypeTable[i].dwFlag;
      contentTypeData.dwFlags = contentTypeTable[i].dwFlags;
    }
    ContentTypeData contentTypeData =
        ContentTypeData.fromContent(cDCMFILETYPE, 'Catalogue', '|.DCM|');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.from(4194303);

    contentTypeData = ContentTypeData.fromContent(
        cDCMAHMESSAGETYPE, 'Emergency Message', '|.xml|');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.from(6143);

    contentTypeData =
        ContentTypeData.fromContent(cDCMGRAPHICSTYPE, 'Graphics and template');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData =
        ContentTypeData.fromContent(cDCMMONTHTYPE, 'Month xml file', '|.xml|');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData = ContentTypeData.fromContent(
        cDCMCALENDARTYPE, 'Calendar xml file', '|.xml|');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData =
        ContentTypeData.fromContent(cDCMDAYTYPE, 'Playlist xml file', '|.xml|');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData = ContentTypeData.fromContent(cDCMLAYOUTTYPE, 'Layout');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData = ContentTypeData.fromContent(cDCMSKINSTYPE, 'Skins');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData =
        ContentTypeData.fromContent(cDCMDDEOTHERTYPE, 'DDE Others');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
    contentTypeData =
        ContentTypeData.fromContent(cDCMSITEDATATYPE, 'Site playlist data');
    nContentTypes++;
    contentTypeList.add(contentTypeData);
    contentTypeData.uiID = nContentTypes;
    contentTypeData.uiLangID = 0;
    contentTypeData.nSeq = -1;
    contentTypeData.dwFlag = BigInt.zero;
    contentTypeData.dwFlags = BigInt.zero;
  }

  static void writeToXML(XmlItem xmlItem, ContentTypeData contentTypeData) {
    xmlItem.addItem('m_uiID', contentTypeData.uiID);
    xmlItem.addItem('m_uiContentType', contentTypeData.uiContentType);
    xmlItem.addItem('m_strContentName', contentTypeData.strContentName);
    xmlItem.addItem('m_strContentType', contentTypeData.strContentType);
    xmlItem.addItem('m_strFilter', contentTypeData.strFilter);
    xmlItem.addItem('m_dwFlag', contentTypeData.dwFlag);
    xmlItem.addItem('m_dwFlags', contentTypeData.dwFlags);
    xmlItem.addItem('m_nSeq', contentTypeData.nSeq);
    xmlItem.addItem('m_uiLangID', contentTypeData.uiLangID);
    xmlItem.addItem('m_strSettingsKey', contentTypeData.strSettingsKey);
  }

  static void getFromXML(XmlItem xmlItem, ContentTypeData contentType) {
    contentType.uiID = xmlItem.getItemValueI('m_uiID');
    contentType.uiContentType = xmlItem.getItemValueI('m_uiContentType');
    contentType.strContentName = xmlItem.getItemValue('m_strContentName');
    contentType.strContentType = xmlItem.getItemValue('m_strContentType');
    contentType.strFilter = xmlItem.getItemValue('m_strFilter');
    contentType.dwFlag = xmlItem.getItemValueI64('m_dwFlag');
    contentType.dwFlags = xmlItem.getItemValueI64('m_dwFlags');
    contentType.nSeq = xmlItem.getItemValueI('m_nSeq');
    contentType.uiLangID = xmlItem.getItemValueI('m_uiLangID');
    contentType.strSettingsKey = xmlItem.getItemValue('m_strSettingsKey');
  }

  static int getContentTypeByFileName(String strFileName) {
    String strExt = path.extension(strFileName);
    for (var contentType in contentTypeList) {
      if (isNotBlank(contentType.strFilter) &&
          contentType.strFilter!.containsIgnoreCase(strExt)) {
        return contentType.uiContentType;
      }
    }

    if (strFileName.startsWith(RegExp('HTTP://', caseSensitive: false)) ||
        strFileName.startsWith(RegExp('HTTPS://', caseSensitive: false))) {
      return cWEBPAGETYPE;
    }

    return -1;
  }

  static ContentTypeData? findByType(int nContentType) {
    ContentTypeData? contentTypeData;
    for (var contentType in contentTypeList) {
      if (contentType.uiContentType == nContentType) {
        contentTypeData = contentType;
        break;
      }
    }

    return contentTypeData;
  }

  static String fixContentFileName(String strContentName, int nContentType) {
    String strExt = path.extension(strContentName);
    ContentTypeData? contentTypeData = findByType(nContentType);
    if (contentTypeData != null && isNotBlank(contentTypeData.strFilter)) {
      if (strExt.isNotEmpty) {
        if (contentTypeData.strFilter!.containsIgnoreCase(strExt)) {
          return strContentName;
        }
      }

      strExt = '';
      var arrFilter = contentTypeData.strFilter!.split('|');
      for (int i = 0; i < arrFilter.length; i++) {
        if (arrFilter[i].trim().isNotEmpty) {
          strExt = arrFilter[i];
          break;
        }
      }
      if (strExt.isNotEmpty) {
        strContentName += strExt;
      }
    }

    return strContentName;
  }
}
