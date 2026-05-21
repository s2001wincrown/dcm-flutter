// XmlClockSetting.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';

import '../models/clock_data.dart';

/// Class for Clock XML Setting operations
class XmlClockSetting {
  static bool loadClockSetting(String strClockFile, ClockData pClock,
      [String? strCompany]) {
    String strFileName =
        Utils.getFilePath(strClockFile, cCLOCKTYPE, -1, strCompany);
    if (FileUtils.fileExistsSync(strFileName)) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
      if (xmlProfile.loadProfile(szRootItemName: 'ClockXML')) {
        pClock.strDesc =
            xmlProfile.getProfileString('ClockSetting', 'm_strDesc', '');
        pClock.strContent =
            xmlProfile.getProfileString('ClockSetting', 'm_strContent', '');
        pClock.nBg = xmlProfile.getProfileInt('ClockSetting', 'm_nBg', 0);
        pClock.strTimeZone =
            xmlProfile.getProfileString('ClockSetting', 'm_strTimeZone', '');
        pClock.strDateSep =
            xmlProfile.getProfileString('ClockSetting', 'm_strDateSep', ' ');
        pClock.strTimeSep =
            xmlProfile.getProfileString('ClockSetting', 'm_strTimeSep', ':');
        pClock.bFontItalic =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bFontItalic', 0) == 1);
        pClock.bFontBold =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bFontBold', 0) == 1);
        pClock.bFontUnderline =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bFontUnderline', 0) ==
                1);
        pClock.nTextFontSize =
            xmlProfile.getProfileInt('ClockSetting', 'm_nTextFontSize', 44);
        pClock.strTextFontName = xmlProfile.getProfileString(
            'ClockSetting', 'm_strTextFontName', 'Arial');
        pClock.strFile =
            xmlProfile.getProfileString('ClockSetting', 'm_strFile', '');
        pClock.nFont = xmlProfile.getProfileInt('ClockSetting', 'm_nFont', 0);
        pClock.nDirection =
            xmlProfile.getProfileInt('ClockSetting', 'm_nDirection', 0);
        pClock.nDuration =
            xmlProfile.getProfileInt('ClockSetting', 'm_nDuration', 60);
        pClock.nTimeType =
            xmlProfile.getProfileInt('ClockSetting', 'm_nTimeType', 0);
        pClock.nTop = xmlProfile.getProfileInt('ClockSetting', 'm_nTop', 0);
        pClock.nLeft = xmlProfile.getProfileInt('ClockSetting', 'm_nLeft', 0);
        pClock.nTimeZone =
            xmlProfile.getProfileInt('ClockSetting', 'm_nTimeZone', 0);
        pClock.crTextBKColor = fromRGBString(xmlProfile.getProfileString(
            'ClockSetting', 'm_crTextBKColor', '0,0,0'));
        pClock.crTextFGColor = fromRGBString(xmlProfile.getProfileString(
            'ClockSetting', 'm_crTextFGColor', '255,255,255'));
        pClock.strLanguage =
            xmlProfile.getProfileString('ClockSetting', 'm_strLanguage', 'ENG');
        pClock.bShowDate =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bShowDate', 0) == 1);
        pClock.bShowTime =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bShowTime', 0) == 1);
        pClock.bShowWeek =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bShowWeek', 0) == 1);
        pClock.bShowDateHand =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bShowDateHand', 0) ==
                1);
        pClock.bShowSecondHand =
            (xmlProfile.getProfileInt('ClockSetting', 'm_bShowSecondHand', 0) ==
                1);
        pClock.nClockType =
            xmlProfile.getProfileInt('ClockSetting', 'm_nClockType', 0);
        pClock.nSkinType =
            xmlProfile.getProfileInt('ClockSetting', 'm_nSkinType', 0);
        pClock.strSkinImage =
            xmlProfile.getProfileString('ClockSetting', 'm_strSkinImage', '');
        pClock.strStyleImage =
            xmlProfile.getProfileString('ClockSetting', 'm_strStyleImage', '');
        pClock.strTimeZoneTitle = xmlProfile.getProfileString(
            'ClockSetting', 'm_strTimeZoneTitle', '');
        pClock.nDate = xmlProfile.getProfileInt('ClockSetting', 'm_nDate', 0);
        pClock.nTime = xmlProfile.getProfileInt('ClockSetting', 'm_nTime', 0);
        pClock.nWeek = xmlProfile.getProfileInt('ClockSetting', 'm_nWeek', 0);
        pClock.nOffsetMins =
            xmlProfile.getProfileInt('ClockSetting', 'm_nOffsetMins', 0);
        pClock.nRows = xmlProfile.getProfileInt('ClockSetting', 'm_nRows', 0);
        pClock.nCols = xmlProfile.getProfileInt('ClockSetting', 'm_nCols', 0);
        XmlItem? xiClocks = xmlProfile.root()?.getItem('Clocks');
        if (xiClocks != null) {
          getClocksFromXML(xiClocks, pClock);
        }

        return true;
      }
    }

    return false;
  }

  static void saveClockSetting(String strClockFile, ClockData pClock,
      [bool bAdd = true, String strCompany = '']) {
    String strFileName =
        Utils.getFilePath(strClockFile, cCLOCKTYPE, -1, strCompany);
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    bool bOK = false;
    if (FileUtils.fileExistsSync(strFileName)) {
      bOK = xmlProfile.loadProfile(szRootItemName: 'ClockXML');
    } else {
      bOK = xmlProfile.createProfile('ClockXML');
    }
    if (bOK) {
      // write some stuff in the profile
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strContent", pClock.strContent);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strDesc", pClock.strDesc);
      xmlProfile.writeProfileInt("ClockSetting", "m_nBg", pClock.nBg);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strTimeZone", pClock.strTimeZone);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strDateSep", pClock.strDateSep);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strTimeSep", pClock.strTimeSep);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bFontItalic", pClock.bFontItalic ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bFontBold", pClock.bFontBold ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bUnderline", pClock.bFontUnderline ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bShowDate", pClock.bShowDate ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bShowTime", pClock.bShowTime ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bShowWeek", pClock.bShowWeek ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bShowDateHand", pClock.bShowDateHand ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_bShowSecondHand", pClock.bShowSecondHand ? 1 : 0);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nTextFontSize", pClock.nTextFontSize);
      xmlProfile.writeProfileInt("ClockSetting", "m_nFont", pClock.nFont);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strTextFontName", pClock.strTextFontName);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strFile", pClock.strFile);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nDirection", pClock.nDirection);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nDuration", pClock.nDuration);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nTimeType", pClock.nTimeType);
      xmlProfile.writeProfileInt("ClockSetting", "m_nTop", pClock.nTop);
      xmlProfile.writeProfileInt("ClockSetting", "m_nLeft", pClock.nLeft);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nTimeZone", pClock.nTimeZone);
      xmlProfile.writeProfileInt("ClockSetting", "m_nDate", pClock.nDate);
      xmlProfile.writeProfileInt("ClockSetting", "m_nTime", pClock.nTime);
      xmlProfile.writeProfileInt("ClockSetting", "m_nWeek", pClock.nWeek);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nOffsetMins", pClock.nOffsetMins);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nClockType", pClock.nClockType);
      xmlProfile.writeProfileInt(
          "ClockSetting", "m_nSkinType", pClock.nSkinType);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strSkinType", pClock.strSkinType);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strSkinImage", pClock.strSkinImage);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strStyleImage", pClock.strStyleImage);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strTimeZoneTitle", pClock.strTimeZoneTitle);
      xmlProfile.writeProfileString(
          "ClockSetting", "m_crTextBKColor", toRGBString(pClock.crTextBKColor));
      xmlProfile.writeProfileString(
          "ClockSetting", "m_crTextFGColor", toRGBString(pClock.crTextFGColor));
      xmlProfile.writeProfileString(
          "ClockSetting", "m_strLanguage", pClock.strLanguage);
      xmlProfile.writeProfileInt("ClockSetting", "m_nRows", pClock.nRows);
      xmlProfile.writeProfileInt("ClockSetting", "m_nCols", pClock.nCols);
      if (pClock.pClocks != null) {
        XmlItem? xiClocks = xmlProfile.root()?.addItem("Clocks");
        if (xiClocks != null) {
          writeClocksToXML(xiClocks, pClock);
        }
      }

      xmlProfile.saveProfile();
    }
  }

  static void writeToXML(XmlItem pXmlItem, ClockData pClock) {
    // write some stuff in the profile
    pXmlItem.addItem('m_strContent', pClock.strContent, XiType.element);
    pXmlItem.addItem('m_strDesc', pClock.strDesc, XiType.element);
    pXmlItem.addItem('m_nBg', pClock.nBg, XiType.element);
    pXmlItem.addItem('m_strTimeZone', pClock.strTimeZone, XiType.element);
    pXmlItem.addItem('m_strDateSep', pClock.strDateSep, XiType.element);
    pXmlItem.addItem('m_strTimeSep', pClock.strTimeSep, XiType.element);
    pXmlItem.addItem(
        'm_bFontItalic', pClock.bFontItalic ? 1 : 0, XiType.element);
    pXmlItem.addItem('m_bFontBold', pClock.bFontBold ? 1 : 0, XiType.element);
    pXmlItem.addItem(
        'm_bUnderline', pClock.bFontUnderline ? 1 : 0, XiType.element);
    pXmlItem.addItem('m_bShowDate', pClock.bShowDate ? 1 : 0, XiType.element);
    pXmlItem.addItem('m_bShowTime', pClock.bShowTime ? 1 : 0, XiType.element);
    pXmlItem.addItem('m_bShowWeek', pClock.bShowWeek ? 1 : 0, XiType.element);
    pXmlItem.addItem(
        'm_bShowDateHand', pClock.bShowDateHand ? 1 : 0, XiType.element);
    pXmlItem.addItem(
        'm_bShowSecondHand', pClock.bShowSecondHand ? 1 : 0, XiType.element);
    pXmlItem.addItem('m_nTextFontSize', pClock.nTextFontSize, XiType.element);
    pXmlItem.addItem('m_nFont', pClock.nFont, XiType.element);
    pXmlItem.addItem(
        'm_strTextFontName', pClock.strTextFontName, XiType.element);
    pXmlItem.addItem('m_strFile', pClock.strFile, XiType.element);
    pXmlItem.addItem('m_nDirection', pClock.nDirection, XiType.element);
    pXmlItem.addItem('m_nDuration', pClock.nDuration, XiType.element);
    pXmlItem.addItem('m_nTimeType', pClock.nTimeType, XiType.element);
    pXmlItem.addItem('m_nTop', pClock.nTop, XiType.element);
    pXmlItem.addItem('m_nLeft', pClock.nLeft, XiType.element);
    pXmlItem.addItem('m_nTimeZone', pClock.nTimeZone, XiType.element);
    pXmlItem.addItem('m_nDate', pClock.nDate, XiType.element);
    pXmlItem.addItem('m_nTime', pClock.nTime, XiType.element);
    pXmlItem.addItem('m_nWeek', pClock.nWeek, XiType.element);
    pXmlItem.addItem('m_nRows', pClock.nRows, XiType.element);
    pXmlItem.addItem('m_nCols', pClock.nCols, XiType.element);
    pXmlItem.addItem('m_nOffsetMins', pClock.nOffsetMins, XiType.element);
    pXmlItem.addItem('m_nClockType', pClock.nClockType, XiType.element);
    pXmlItem.addItem('m_nSkinType', pClock.nSkinType, XiType.element);
    pXmlItem.addItem('m_strSkinType', pClock.strSkinType, XiType.element);
    pXmlItem.addItem('m_strSkinImage', pClock.strSkinImage, XiType.element);
    pXmlItem.addItem('m_strStyleImage', pClock.strStyleImage, XiType.element);
    pXmlItem.addItem(
        'm_strTimeZoneTitle', pClock.strTimeZoneTitle, XiType.element);
    pXmlItem.addItem(
        'm_crTextBKColor', toRGBString(pClock.crTextBKColor), XiType.element);
    pXmlItem.addItem(
        'm_crTextFGColor', toRGBString(pClock.crTextFGColor), XiType.element);
    pXmlItem.addItem('m_strLanguage', pClock.strLanguage, XiType.element);
    if (pClock.pClocks != null) {
      XmlItem? xiClocks = pXmlItem.addItem('Clocks');
      if (xiClocks != null) {
        writeClocksToXML(xiClocks, pClock);
      }
    }
  }

  static void getFromXML(XmlItem pXmlItem, ClockData pClock) {
    pClock.strContent = pXmlItem.getItemValue('m_strContent');
    pClock.strDesc = pXmlItem.getItemValue('m_strDesc');
    pClock.nBg = pXmlItem.getItemValueI('m_nBg');
    pClock.strTimeZone = pXmlItem.getItemValue('m_strTimeZone');
    pClock.strDateSep = pXmlItem.getItemValue('m_strDateSep');
    pClock.strTimeSep = pXmlItem.getItemValue('m_strTimeSep');
    pClock.bFontItalic = pXmlItem.getItemValueB('m_bFontItalic');
    pClock.bFontBold = pXmlItem.getItemValueB('m_bFontBold');
    pClock.bFontUnderline = pXmlItem.getItemValueB('m_bUnderline');
    pClock.bShowDate = pXmlItem.getItemValueB('m_bShowDate');
    pClock.bShowTime = pXmlItem.getItemValueB('m_bShowTime');
    pClock.bShowWeek = pXmlItem.getItemValueB('m_bShowWeek');
    pClock.bShowDateHand = pXmlItem.getItemValueB('m_bShowDateHand');
    pClock.bShowSecondHand = pXmlItem.getItemValueB('m_bShowSecondHand');
    pClock.nTextFontSize = pXmlItem.getItemValueI('m_nTextFontSize');
    pClock.nFont = pXmlItem.getItemValueI('m_nFont');
    pClock.strTextFontName = pXmlItem.getItemValue('m_strTextFontName');
    pClock.strFile = pXmlItem.getItemValue('m_strFile');
    pClock.nDirection = pXmlItem.getItemValueI('m_nDirection');
    pClock.nDuration = pXmlItem.getItemValueI('m_nDuration');
    pClock.nTimeType = pXmlItem.getItemValueI('m_nTimeType');
    pClock.nTop = pXmlItem.getItemValueI('m_nTop');
    pClock.nLeft = pXmlItem.getItemValueI('m_nLeft');
    pClock.nTimeZone = pXmlItem.getItemValueI('m_nTimeZone');
    pClock.nDate = pXmlItem.getItemValueI('m_nDate');
    pClock.nTime = pXmlItem.getItemValueI('m_nTime');
    pClock.nWeek = pXmlItem.getItemValueI('m_nWeek');
    pClock.nRows = pXmlItem.getItemValueI('m_nRows');
    pClock.nCols = pXmlItem.getItemValueI('m_nCols');
    pClock.nOffsetMins = pXmlItem.getItemValueI('m_nOffsetMins');
    pClock.nClockType = pXmlItem.getItemValueI('m_nClockType');
    pClock.nSkinType = pXmlItem.getItemValueI('m_nSkinType');
    pClock.strSkinType = pXmlItem.getItemValue('m_strSkinType');
    pClock.strSkinImage = pXmlItem.getItemValue('m_strSkinImage');
    pClock.strStyleImage = pXmlItem.getItemValue('m_strStyleImage');
    pClock.strTimeZoneTitle = pXmlItem.getItemValue('m_strTimeZoneTitle');
    pClock.crTextBKColor =
        pXmlItem.getItemValueR('m_crTextBKColor') ?? 0xFFFFFF;
    pClock.crTextFGColor = pXmlItem.getItemValueR('m_crTextFGColor') ?? 0;
    pClock.strLanguage = pXmlItem.getItemValue('m_strLanguage');
    XmlItem? xiClocks = pXmlItem.getItem('Clocks');
    if (xiClocks != null) {
      getClocksFromXML(xiClocks, pClock);
    }
  }

  static void writeClocksToXML(XmlItem pXmlItem, ClockData pClock) {
    int nClocks = pClock.getClocksNum();
    for (int nClock = 0; nClock < nClocks; nClock++) {
      ClockUnit? pClockItem = pClock.getClock(nClock);
      if (pClockItem != null) {
        XmlItem? xiClock = pXmlItem.addItem('Clock');
        if (xiClock != null) {
          xiClock.addItem('nDiffSecs', pClockItem.nDiffSecs);
          xiClock.addItem('nTitleAlign', pClockItem.nTitleAlign.value);
          xiClock.addItem('szThemeName', pClockItem.szThemeName);
          xiClock.addItem('szTimeZone', pClockItem.szTimeZone);
          xiClock.addItem('szTitle', pClockItem.szTitle);
        }
      }
    }
  }

  static void getClocksFromXML(XmlItem pXmlItem, ClockData pClock) {
    int nClocks = pClock.getClocksNum();
    XmlItem? pXIClock = pXmlItem.getItem('Clock');
    int nClock = 0;
    pClock.pClocks = [];
    while (pXIClock != null) {
      ClockUnit pClockUnit = ClockUnit();
      pClockUnit.szThemeName = pXIClock.getItemValue('szThemeName');
      pClockUnit.szTimeZone = pXIClock.getItemValue('szTimeZone');
      pClockUnit.nDiffSecs = pXIClock.getItemValueI('nDiffSecs');
      pClockUnit.nTitleAlign =
          ClockAlignment.values[pXIClock.getItemValueI('nTitleAlign')];
      pClockUnit.szTitle = pXIClock.getItemValue('szTitle');
      pClock.pClocks?.add(pClockUnit);

      nClock++;
      if (nClock == nClocks) {
        break;
      }

      pXIClock = pXIClock.getSibling();
    }
  }
}
