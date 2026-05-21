// WeatherData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

/// Class to hold the data for Weather Setting
class WeatherData {
  // Attributes
  int uiID = 0;
  String strDesc = '';
  String strContent = '';
  int nBg = 0;
  String strText = '';
  String strFile = '';
  int nFont = 0;
  int nDirection = 0;
  double nDuration = 0.0;
  int nSpeed = 0;
  int nTop = 0;
  int nLeft = 0;
  int nBehavior = 0;
  bool bFontItalic = false;
  bool bFontBold = false;
  bool bFontUnderline = false;
  String strTextFontName = '';
  String strLanguage = '';
  String strTemplate = '';
  int nTextFontSize = 0;
  int crTextFGColor = 0;
  int crTextBKColor = 0;

  String strCountry = '';
  String strCity = '';
  String strConditions = '';
  String strWind = '';
  String strBarometer = '';
  String strURadiation = '';

  DateTime? dtPublish;
  DateTime? dtSunrise;
  DateTime? dtSunset;

  double dbHight = 0.0;
  double dbLow = 0.0;
  double dbCurrent = 0.0;
  double dbFeels = 0.0;
  double dbHumidity = 0.0;
  double dbVisibility = 0.0;
  double dbDewpoint = 0.0;
  int nScrollAmount = 0;

  /// Create a copy of this WeatherData
  WeatherData copy() {
    final copy = WeatherData();
    copy.uiID = uiID;
    copy.strDesc = strDesc;
    copy.strContent = strContent;
    copy.nBg = nBg;
    copy.strText = strText;
    copy.strFile = strFile;
    copy.nFont = nFont;
    copy.nDirection = nDirection;
    copy.nDuration = nDuration;
    copy.nSpeed = nSpeed;
    copy.nTop = nTop;
    copy.nLeft = nLeft;
    copy.nBehavior = nBehavior;
    copy.bFontItalic = bFontItalic;
    copy.bFontBold = bFontBold;
    copy.bFontUnderline = bFontUnderline;
    copy.strTextFontName = strTextFontName;
    copy.strLanguage = strLanguage;
    copy.strTemplate = strTemplate;
    copy.nTextFontSize = nTextFontSize;
    copy.crTextFGColor = crTextFGColor;
    copy.crTextBKColor = crTextBKColor;
    copy.strCountry = strCountry;
    copy.strCity = strCity;
    copy.strConditions = strConditions;
    copy.strWind = strWind;
    copy.strBarometer = strBarometer;
    copy.strURadiation = strURadiation;
    copy.dtPublish = dtPublish;
    copy.dtSunrise = dtSunrise;
    copy.dtSunset = dtSunset;
    copy.dbHight = dbHight;
    copy.dbLow = dbLow;
    copy.dbCurrent = dbCurrent;
    copy.dbFeels = dbFeels;
    copy.dbHumidity = dbHumidity;
    copy.dbVisibility = dbVisibility;
    copy.dbDewpoint = dbDewpoint;
    copy.nScrollAmount = nScrollAmount;
    return copy;
  }
}
