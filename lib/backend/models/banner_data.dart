// BannerData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

/// Class to hold the data for Scroll Text Setting
class BannerData {
  // Attributes
  int uiID = 0;
  String strDesc = '';
  String strContent = '';
  int nBg = 0;

  String strText = '';
  String strHtml = '';
  String customComments = '';
  String strXMLFormat = '';
  String strRSS = '';

  String strFile = '';
  String strMusicFile = '';
  int nFont = 0;
  int nDirection = 0;
  double nDuration = 0.0;
  int nSpeed = 2;
  int nTop = 0;
  int nLeft = 0;
  int nBehavior = 0;

  int nValign = 0;
  int nBullet = 0;
  int nIndent = 0;
  int nTemplate = 0;

  bool bFontItalic = false;
  bool bFontBold = true;
  bool bFontUnderline = false;
  bool bStrikethrough = false;

  bool bHLColor = false;

  String strTextFontName = 'Arial';
  String strLanguage = '';
  int nTextFontSize = 1000;
  int crTextFGColor = 0xFFFFFFFF; // White
  int crTextBKColor = 0xFF000000; // Black
  int crTextHLColor = 0;

  String strHalign = '';
  String strValign = '';

  int nScrollAmount = 0;

  String strUserCode = '';
  String strGroupCode = '';
  String dtModified = '';
  String dtCreated = '';

  /// Create a copy of this BannerData
  BannerData copy() {
    final copy = BannerData();
    copy.uiID = uiID;
    copy.strDesc = strDesc;
    copy.strContent = strContent;
    copy.nBg = nBg;
    copy.strText = strText;
    copy.strHtml = strHtml;
    copy.customComments = customComments;
    copy.strXMLFormat = strXMLFormat;
    copy.strRSS = strRSS;
    copy.strFile = strFile;
    copy.strMusicFile = strMusicFile;
    copy.nFont = nFont;
    copy.nDirection = nDirection;
    copy.nDuration = nDuration;
    copy.nSpeed = nSpeed;
    copy.nTop = nTop;
    copy.nLeft = nLeft;
    copy.nBehavior = nBehavior;
    copy.nValign = nValign;
    copy.nBullet = nBullet;
    copy.nIndent = nIndent;
    copy.nTemplate = nTemplate;
    copy.bFontItalic = bFontItalic;
    copy.bFontBold = bFontBold;
    copy.bFontUnderline = bFontUnderline;
    copy.bStrikethrough = bStrikethrough;
    copy.bHLColor = bHLColor;
    copy.strTextFontName = strTextFontName;
    copy.strLanguage = strLanguage;
    copy.nTextFontSize = nTextFontSize;
    copy.crTextFGColor = crTextFGColor;
    copy.crTextBKColor = crTextBKColor;
    copy.crTextHLColor = crTextHLColor;
    copy.strHalign = strHalign;
    copy.strValign = strValign;
    copy.nScrollAmount = nScrollAmount;
    copy.strUserCode = strUserCode;
    copy.strGroupCode = strGroupCode;
    copy.dtModified = dtModified;
    copy.dtCreated = dtCreated;
    return copy;
  }
}
