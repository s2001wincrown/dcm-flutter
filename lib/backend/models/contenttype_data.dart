// ZoneRectData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

class ContentTypeData {
  ContentTypeData();
  ContentTypeData.fromContent(int nType, String strContent) {
    uiID = nType;
    uiContentType = nType;
    strContentType = strContent;
    strContentName = strContent;
    uiLangID = nType;
    nSeq = nType;
    dwFlag = BigInt.zero;
    dwFlags = BigInt.zero;
    strSettingsKey = "";
  }

  int uiID = 0;
  int uiContentType = 0;
  String strContentType = "";
  String strContentName = "";
  String strFilter = "";
  int uiLangID = 0;
  int nSeq = 0;
  BigInt dwFlag = BigInt.zero;
  BigInt dwFlags = BigInt.zero;
  String strSettingsKey = "";
}
