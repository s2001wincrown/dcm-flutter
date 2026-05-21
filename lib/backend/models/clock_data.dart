// ClockData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

/// Clock type enum
enum ClockType {
  text(0),
  analog(1);

  final int value;
  const ClockType(this.value);
}

/// Clock time enum
enum ClockTime {
  local(0),
  custom(1);

  final int value;
  const ClockTime(this.value);
}

/// Time format enum
enum TimeFormat {
  hhmm24(0),
  hhmmss24(1),
  hhmmap(2),
  hhmmssap(3),
  aphhmm(4),
  aphhmmss(5),
  chstime24(6),
  chstimeap(7);

  final int value;
  const TimeFormat(this.value);
}

/// Date format enum
enum DateFormat {
  ddMmYy(0),
  ddMmYyyy(1),
  mmDdYy(2),
  mmDdYyyy(3),
  yyMmDd(4),
  yyyyMmDd(5),
  ddMmmYy(6),
  ddMmmYyyy(7),
  mmmDdYy(8),
  mmmDdYyyy(9),
  ddMmmmYy(10),
  ddMmmmYyyy(11),
  mmmmDdYy(12),
  mmmmDdYyyy(13),
  chinese(14);

  final int value;
  const DateFormat(this.value);
}

/// Week format enum
enum WeekFormat {
  wfMon(0),
  wfMonday(1),
  wfChinese(2);

  final int value;
  const WeekFormat(this.value);
}

/// Date box format enum
enum DateBoxFormat {
  dbfD(0),
  dbfDD(1);

  final int value;
  const DateBoxFormat(this.value);
}

/// Clock title alignment
enum ClockAlignment {
  bottomCenter(0),
  bottomLeft(1),
  bottomRight(2),
  topCenter(3),
  topLeft(4),
  topRight(5);

  final int value;
  const ClockAlignment(this.value);
}

class ClockUnit {
  String szThemeName = '';

  String szTimeZone = 'UTC';
  int nDiffSecs = 0;

  String szTitle = '';
  ClockAlignment nTitleAlign = ClockAlignment.bottomCenter;

  ClockType nClockType = ClockType.text;
  ClockTime nTimeType = ClockTime.local;

  WeekFormat nWeek = WeekFormat.wfMon;
  DateFormat nDate = DateFormat.ddMmYyyy;
  TimeFormat nTime = TimeFormat.hhmm24;
  String strDateSep = ' ';
  String strTimeSep = ':';
  int nTop = 0;
  int nLeft = 0;

  String strTextFontName = 'Arial';
  int nTextFontSize = 44;
  int crTextFGColor = 0xFFFFFFFF;
  bool bFontItalic = false;
  bool bFontBold = false;
  bool bFontUnderline = false;

  String strTitleFontName = '';
  int nTitleFontSize = 44;
  int crTitleFGColor = 0xFFFFFFFF;
  bool bTitleItalic = false;
  bool bTitleBold = false;
  bool bTitleUnderline = false;

  bool bShowDate = true;
  bool bShowTime = true;
  bool bShowWeek = true;

  bool bShowDateHand = true;
  bool bShowSecondHand = true;

  DateBoxFormat nDayBox = DateBoxFormat.dbfDD;

  String? strFile;
  int crTextBKColor = 0;
  int bAlpha = 0;

  //Color Clock
  bool bAutomaticHandColor = false;
  int rgbFaceLine = 0;
  int rgbSecondHand = 0;
  int rgbMinuteHand = 0;
  int rgbHourHand = 0;
  int rgbFaceGradientStart = 0;
  int rgbFaceGradientStop = 0;
}

/// Class to hold the data for Clock Setting
class ClockData {
  // Date Format
  static const List<String> strDateFormat = [
    'DD MM YY',
    'DD MM YYYY',
    'MM DD YY',
    'MM DD YYYY',
    'YY MM DD',
    'YYYY MM DD',
    'DD MMM YY',
    'DD MMM YYYY',
    'MMM DD YY',
    'MMM DD YYYY',
    'DD MMMM YY',
    'DD MMMM YYYY',
    'MMMM DD YY',
    'MMMM DD YYYY',
    'YYYY年MM月DD',
  ];

  // Date Box Format
  static const List<String> strDateBoxFmt = ['D', 'DD'];

  // Time Format
  static const List<String> strTimeFormat = [
    'HH MM - 24 hour',
    'HH MM SS - 24 hour',
    'HH MM am/pm',
    'HH MM SS am/pm',
    'am/pm HH MM',
    'am/pm HH MM SS',
    'HH时MM份SS - 24 hour',
    'HH时MM分SS - am/pm',
  ];

  // Week Format
  static const List<String> strWeekFormat = ['Mon', 'Monday', '星期一'];

  // Date Separator
  static const List<String> dcmDateSep = [' ', '/', '-', '.'];

  // Time Separator
  static const List<String> dcmTimeSep = [' ', ':'];

  // Attributes
  String strDesc = '';
  String strContent = '';
  int nBg = 0;
  String strTimeZone = '';
  String strDateSep = ' ';
  String strTimeSep = ':';
  bool bFontItalic = false;
  bool bFontBold = false;
  bool bFontUnderline = false;
  int nTextFontSize = 44;
  String strTextFontName = 'Arial';
  String strFile = '';
  String strSkinType = '';
  int nFont = 0;
  int nDirection = 0;
  int nDuration = 60;
  int nTimeType = 0;
  int nTop = 0;
  int nLeft = 0;
  int nTimeZone = 0;
  int crTextBKColor = 0xFF000000;
  int crTextFGColor = 0xFFFFFFFF;
  String strLanguage = 'ENG';
  bool bShowDate = false;
  bool bShowTime = false;
  bool bShowWeek = false;
  bool bShowDateHand = false;
  bool bShowSecondHand = false;
  int nClockType = 0;
  int nSkinType = 0;
  String strSkinImage = '';
  String strStyleImage = '';
  String strTimeZoneTitle = '';
  int nDate = 0;
  int nTime = 0;
  int nWeek = 0;
  int nOffsetMins = 0;
  int nRows = 1;
  int nCols = 1;
  List<ClockUnit>? pClocks;

  int getClocksNum() {
    return nRows * nCols;
  }

  ClockUnit? getClock(int nClockID) {
    int nClocks = nRows * nCols;
    if (pClocks != null && nClockID < nClocks) {
      return pClocks?[nClockID];
    }

    return null;
  }

  /// Create a copy of this ClockData
  ClockData copy() {
    final copy = ClockData();
    copy.strDesc = strDesc;
    copy.strContent = strContent;
    copy.nBg = nBg;
    copy.strTimeZone = strTimeZone;
    copy.strDateSep = strDateSep;
    copy.strTimeSep = strTimeSep;
    copy.bFontItalic = bFontItalic;
    copy.bFontBold = bFontBold;
    copy.bFontUnderline = bFontUnderline;
    copy.nTextFontSize = nTextFontSize;
    copy.strTextFontName = strTextFontName;
    copy.strFile = strFile;
    copy.nFont = nFont;
    copy.nDirection = nDirection;
    copy.nDuration = nDuration;
    copy.nTimeType = nTimeType;
    copy.nTop = nTop;
    copy.nLeft = nLeft;
    copy.nTimeZone = nTimeZone;
    copy.crTextBKColor = crTextBKColor;
    copy.crTextFGColor = crTextFGColor;
    copy.strLanguage = strLanguage;
    copy.bShowDate = bShowDate;
    copy.bShowTime = bShowTime;
    copy.bShowWeek = bShowWeek;
    copy.bShowDateHand = bShowDateHand;
    copy.bShowSecondHand = bShowSecondHand;
    copy.nClockType = nClockType;
    copy.nSkinType = nSkinType;
    copy.strSkinImage = strSkinImage;
    copy.strStyleImage = strStyleImage;
    copy.strTimeZoneTitle = strTimeZoneTitle;
    copy.nDate = nDate;
    copy.nTime = nTime;
    copy.nWeek = nWeek;
    copy.nOffsetMins = nOffsetMins;
    copy.nRows = nRows;
    copy.nCols = nCols;
    return copy;
  }
}
