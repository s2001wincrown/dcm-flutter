// XmlWeatherSetting.dart
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
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import '../models/weather_data.dart';

/// Class for Weather XML Setting operations
class XmlWeatherSetting {
  static const String lpszSignature =
      'DCMPlayer Version 7.0.0 - Weather Setting';

/********************************************************************/
  /*																	*/
  /* Function name : Serialize										*/
  /* Description   : Call this function to store/load the Weather  data	*/
  /*																	*/
  /// *****************************************************************
  static bool saveToFile(
      WeatherData weather, String strWeatherFile, String strCompany) {
    String strFilename =
        Utils.getFilePath(strWeatherFile, cWEATHERTYPE, -1, strCompany);
    XmlFilePro playerReg = XmlFilePro('WeatherXML');

    // Save the Weather information
    XmlItem? xi = playerReg.addDataNode('WeatherItem', null);
    if (xi != null) {
      writeToXML(xi, weather);
    }

    playerReg.setSignature(lpszSignature);

    return playerReg.save(strFilename);
  }

  static WeatherData? loadFromFile(String strWeatherFile, String strCompany) {
    String strFilename =
        Utils.getFilePath(strWeatherFile, cWEATHERTYPE, -1, strCompany);
    XmlFilePro file = XmlFilePro('WeatherXML');
    if (!file.open(strFilename, XfOpen.read)) {
      return null;
    }

    WeatherData? weather;
    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        // get Weather Setting Item
        XmlItem? xiSibling = file.getItem('WeatherItem');
        if (xiSibling != null) {
          // get weather Inforamtion data
          weather = getFromXML(xiSibling);
        }
      }
    }
    file.close();

    return weather;
  }

  static void writeToXML(XmlItem pXmlItem, WeatherData weather) {
    pXmlItem.addItem('m_strDesc', weather.strDesc);
    pXmlItem.addItem('m_strContent', weather.strContent);
    pXmlItem.addItem('m_nBg', weather.nBg);
    pXmlItem.addItem('m_strCountry', weather.strCountry);
    pXmlItem.addItem('m_strCity', weather.strCity);
    pXmlItem.addItem('m_strText', weather.strText);
    pXmlItem.addItem('m_bFontBold', weather.bFontBold);
    pXmlItem.addItem('m_bFontItalic', weather.bFontItalic);
    pXmlItem.addItem('m_bFontUnderline', weather.bFontUnderline);
    pXmlItem.addItem('m_nTextFontSize', weather.nTextFontSize);
    pXmlItem.addItem('m_strTextFontName', weather.strTextFontName);
    pXmlItem.addItem('m_strFile', weather.strFile);
    pXmlItem.addItem('m_nFont', weather.nFont);
    pXmlItem.addItem('m_nDirection', weather.nDirection);
    pXmlItem.addItem('m_nDuration', weather.nDuration);
    pXmlItem.addItem('m_nSpeed', weather.nSpeed);
    pXmlItem.addItem('m_nTop', weather.nTop);
    pXmlItem.addItem('m_nLeft', weather.nLeft);
    pXmlItem.addItem('m_nBehavior', weather.nBehavior);
    pXmlItem.addItem('m_crTextBKColor', weather.crTextBKColor);
    pXmlItem.addItem('m_crTextFGColor', weather.crTextFGColor);
    pXmlItem.addItem('m_strLanguage', weather.strLanguage);
    pXmlItem.addItem('m_strConditions', weather.strConditions);
    pXmlItem.addItem('m_strWind', weather.strWind);
    pXmlItem.addItem('m_strURadiation', weather.strURadiation);
    pXmlItem.addItem('m_strBarometer', weather.strBarometer);
    pXmlItem.addItem('m_dbHight', weather.dbHight);
    pXmlItem.addItem('m_dbLow', weather.dbLow);
    pXmlItem.addItem('m_dbCurrent', weather.dbCurrent);
    pXmlItem.addItem('m_dbDewpoint', weather.dbDewpoint);
    pXmlItem.addItem('m_dbFeels', weather.dbFeels);
    pXmlItem.addItem('m_dbHumidity', weather.dbHumidity);
    pXmlItem.addItem('m_dbVisibility', weather.dbVisibility);

    pXmlItem.addItem('m_dtPublish', weather.dtPublish);
    pXmlItem.addItem('m_dtSunrise', weather.dtSunrise);
    pXmlItem.addItem('m_dtSunset', weather.dtSunset);
  }

  static WeatherData getFromXML(XmlItem pXmlItem) {
    WeatherData weather = WeatherData();
    weather.strDesc = pXmlItem.getItemValue('m_strDesc');
    weather.strContent = pXmlItem.getItemValue('m_strContent');
    weather.nBg = pXmlItem.getItemValueI('m_nBg');
    weather.strText = pXmlItem.getItemValue('m_strText');
    weather.bFontItalic = pXmlItem.getItemValueB('m_bFontItalic');
    weather.bFontBold = pXmlItem.getItemValueB('m_bFontBold');
    weather.bFontUnderline = pXmlItem.getItemValueB('m_bFontUnderline');
    weather.nTextFontSize = pXmlItem.getItemValueI('m_nTextFontSize');
    weather.strTextFontName = pXmlItem.getItemValue('m_strTextFontName');
    weather.strFile = pXmlItem.getItemValue('m_strFile');
    weather.nFont = pXmlItem.getItemValueI('m_nFont');
    weather.nDirection = pXmlItem.getItemValueI('m_nDirection');
    weather.nDuration = pXmlItem.getItemValueF('m_nDuration');
    weather.nSpeed = pXmlItem.getItemValueI('m_nSpeed');
    weather.nTop = pXmlItem.getItemValueI('m_nTop');
    weather.nLeft = pXmlItem.getItemValueI('m_nLeft');
    weather.nBehavior = pXmlItem.getItemValueI('m_nBehavior');
    weather.crTextBKColor = pXmlItem.getItemValueR('m_crTextBKColor') ?? 0;
    weather.crTextFGColor =
        pXmlItem.getItemValueR('m_crTextFGColor') ?? 0xFFFFFF;
    weather.strLanguage = pXmlItem.getItemValue('m_strLanguage');
    weather.strCountry = pXmlItem.getItemValue('m_strCountry');
    weather.strCity = pXmlItem.getItemValue('m_strCity');
    weather.strConditions = pXmlItem.getItemValue('m_strConditions');
    weather.strURadiation = pXmlItem.getItemValue('m_strURadiation');
    weather.strBarometer = pXmlItem.getItemValue('m_strBarometer');
    weather.dbDewpoint = pXmlItem.getItemValueF('m_dbDewpoint');
    weather.dbFeels = pXmlItem.getItemValueF('m_dbFeels');
    weather.dbHight = pXmlItem.getItemValueF('m_dbHight');
    weather.dbHumidity = pXmlItem.getItemValueF('m_dbHumidity');
    weather.dbLow = pXmlItem.getItemValueF('m_dbLow');
    weather.dbCurrent = pXmlItem.getItemValueF('m_dbCurrent');
    weather.dbVisibility = pXmlItem.getItemValueF('m_dbVisibility');
    weather.strWind = pXmlItem.getItemValue('m_strWind');

    weather.dtPublish = pXmlItem.getItemValueD('m_dtPublish');
    weather.dtSunrise = pXmlItem.getItemValueD('m_dtSunrise');
    weather.dtSunset = pXmlItem.getItemValueD('m_dtSunset');

    return weather;
  }

  static WeatherData? loadWeatherSetting(
      String strWeatherFile, String strCompany) {
    String strFileName = '';

    if (FileUtils.fileExistsSync(strFileName)) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
      if (xmlProfile.loadProfile(szRootItemName: 'WeatherXML')) {
        WeatherData weather = WeatherData();
        weather.strDesc =
            xmlProfile.getProfileString('WeatherSetting', 'm_strDesc', '');
        weather.strContent =
            xmlProfile.getProfileString('WeatherSetting', 'm_strContent', '');
        weather.nBg = xmlProfile.getProfileInt('WeatherSetting', 'm_nBg', 0);
        weather.strText =
            xmlProfile.getProfileString('WeatherSetting', 'm_strText', '');
        weather.bFontItalic =
            (xmlProfile.getProfileInt('WeatherSetting', 'm_bFontItalic', 0) ==
                1);
        weather.bFontBold =
            (xmlProfile.getProfileInt('WeatherSetting', 'm_bFontBold', 0) == 1);
        weather.bFontUnderline = (xmlProfile.getProfileInt(
                'WeatherSetting', 'm_bFontUnderline', 0) ==
            1);
        weather.nTextFontSize =
            xmlProfile.getProfileInt('WeatherSetting', 'm_nTextFontSize', 44);
        weather.strTextFontName = xmlProfile.getProfileString(
            'WeatherSetting', 'm_strTextFontName', 'Arial');
        weather.strFile =
            xmlProfile.getProfileString('WeatherSetting', 'm_strFile', '');
        weather.nFont =
            xmlProfile.getProfileInt('WeatherSetting', 'm_nFont', 0);
        weather.nDirection =
            xmlProfile.getProfileInt('WeatherSetting', 'm_nDirection', 0);
        weather.nDuration = xmlProfile
            .getProfileInt('WeatherSetting', 'm_nDuration', 60)
            .toDouble();
        weather.nSpeed =
            xmlProfile.getProfileInt('WeatherSetting', 'm_nSpeed', 5);
        weather.nTop = xmlProfile.getProfileInt('WeatherSetting', 'm_nTop', 0);
        weather.nLeft =
            xmlProfile.getProfileInt('WeatherSetting', 'm_nLeft', 0);
        weather.nBehavior =
            xmlProfile.getProfileInt('WeatherSetting', 'm_nBehavior', 1);
        weather.crTextBKColor = fromRGBString(xmlProfile.getProfileString(
            'WeatherSetting', 'm_crTextBKColor', '0,0,0'));
        weather.crTextFGColor = fromRGBString(xmlProfile.getProfileString(
            'WeatherSetting', 'm_crTextFGColor', '255,255,255'));
        weather.strLanguage = xmlProfile.getProfileString(
            'WeatherSetting', 'm_strLanguage', 'ENG');

        return weather;
      }
    }

    return null;
  }

  static void saveWeatherSetting(
      WeatherData weather, String strWeatherFile, String strCompany) {
    String strFileName = '';
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);

    xmlProfile.createProfile('WeatherXML');
    // write some stuff in the profile
    xmlProfile.writeProfileString(
        'WeatherSetting', 'm_strContent', weather.strContent);
    xmlProfile.writeProfileString(
        'WeatherSetting', 'm_strDesc', weather.strDesc);
    xmlProfile.writeProfileInt('WeatherSetting', 'm_nBg', weather.nBg);
    xmlProfile.writeProfileString(
        'WeatherSetting', 'm_strText', weather.strText);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_bFontItalic', weather.bFontItalic ? 1 : 0);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_bFontBold', weather.bFontBold ? 1 : 0);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_bUnderline', weather.bFontUnderline ? 1 : 0);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_nTextFontSize', weather.nTextFontSize);
    xmlProfile.writeProfileInt('WeatherSetting', 'm_nFont', weather.nFont);
    xmlProfile.writeProfileString(
        'WeatherSetting', 'm_strTextFontName', weather.strTextFontName);
    xmlProfile.writeProfileString(
        'WeatherSetting', 'm_strFile', weather.strFile);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_nDirection', weather.nDirection);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_nDuration', weather.nDuration.toInt());
    xmlProfile.writeProfileInt('WeatherSetting', 'm_nSpeed', weather.nSpeed);
    xmlProfile.writeProfileInt('WeatherSetting', 'm_nTop', weather.nTop);
    xmlProfile.writeProfileInt('WeatherSetting', 'm_nLeft', weather.nLeft);
    xmlProfile.writeProfileInt(
        'WeatherSetting', 'm_nBehavior', weather.nBehavior);
    xmlProfile.writeProfileString('WeatherSetting', 'm_crTextBKColor',
        toRGBString(weather.crTextBKColor));
    xmlProfile.writeProfileString('WeatherSetting', 'm_crTextFGColor',
        toRGBString(weather.crTextFGColor));
    xmlProfile.writeProfileString(
        'WeatherSetting', 'm_strLanguage', weather.strLanguage);

    xmlProfile.saveProfile();
  }
}
