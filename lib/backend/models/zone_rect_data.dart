// ZoneRectData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'dart:ui';

/// Class to hold the data for Zone Rect
class ZoneRectData {
  // Attributes
  int nZoneID = 0;

  int nTop = 0;
  int nLeft = 0;
  int nBottom = 0;
  int nRight = 0;

  int nLevel = 0;

  bool bIsAH = false;
  bool bIsTS = false;
  int bAlpha = 0;

  /// Set zone rect from a Rect
  void setZoneRect(Rect rect) {
    nTop = rect.top.toInt();
    nLeft = rect.left.toInt();
    nBottom = rect.bottom.toInt();
    nRight = rect.right.toInt();
  }

  /// Get zone rect as a Rect
  Rect getZoneRect() {
    return Rect.fromLTRB(
      nLeft.toDouble(),
      nTop.toDouble(),
      nRight.toDouble(),
      nBottom.toDouble(),
    );
  }

  /// Create a copy of this ZoneRectData
  ZoneRectData copy() {
    final copy = ZoneRectData();
    copy.nZoneID = nZoneID;
    copy.nTop = nTop;
    copy.nLeft = nLeft;
    copy.nBottom = nBottom;
    copy.nRight = nRight;
    copy.nLevel = nLevel;
    copy.bIsAH = bIsAH;
    copy.bIsTS = bIsTS;
    copy.bAlpha = bAlpha;
    return copy;
  }
}
