// LayoutData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'dart:ui';

/// Class to hold the data for Layout
class LayoutData {
  int uiID = 0;
  String strLayoutName = '';
  String strLayoutDesc = '';
  int uiGroupID = 0;
  int iNoOfParition = 0;
  int iScreenWidth = 0;
  int iScreenHeight = 0;
  String strImageFile = '';

  List<Rect?> pZoneRect = [];

  LayoutData() {
    pZoneRect = [];
  }

  /// Get zone rect by zone ID
  Rect? getZoneRect(int nZoneID) {
    if (nZoneID < pZoneRect.length) {
      return pZoneRect[nZoneID];
    }
    return null;
  }

  /// Initialize zone rect array
  List<Rect?> initZoneRect() {
    freeZoneRect();
    pZoneRect = List.filled(iNoOfParition, null);
    for (int nZone = 0; nZone < iNoOfParition; nZone++) {
      pZoneRect[nZone] = Rect.zero;
    }
    return pZoneRect;
  }

  List<Rect?> initFullScreen(int nWidth, int nHeight) {
    freeZoneRect();
    iNoOfParition = 1;
    iScreenWidth = nWidth;
    iScreenHeight = nHeight;
    pZoneRect = [];
    pZoneRect.add(Rect.fromLTWH(0, 0, nWidth.toDouble(), nHeight.toDouble()));

    return pZoneRect;
  }

  /// Free zone rect array
  void freeZoneRect() {
    pZoneRect.clear();
  }

  /// Create a copy of this LayoutData
  LayoutData copy() {
    final copy = LayoutData();
    copy.uiID = uiID;
    copy.strLayoutName = strLayoutName;
    copy.strLayoutDesc = strLayoutDesc;
    copy.uiGroupID = uiGroupID;
    copy.iNoOfParition = iNoOfParition;
    copy.iScreenWidth = iScreenWidth;
    copy.iScreenHeight = iScreenHeight;
    copy.strImageFile = strImageFile;
    copy.pZoneRect = pZoneRect.map((rect) => rect).toList();
    return copy;
  }
}
