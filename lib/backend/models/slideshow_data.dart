// SlideShowData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'package:uuid/uuid.dart';

/// Slide show type enum
class SlideShowType {
  static const int carouselH = 2;
  static const int carouselV = 1;
  static const int slideShow = 0;
}

/// Class to hold the data for Multi-Image Setting
class SlideShowData {
  // Attributes
  Uuid? id;
  int uiID = -1;
  String strDesc = '';
  String strContent = '';
  String strFile = ''; // Zone 1 File Name
  int crBGColor = 0; // Zone 1 backgroup color
  String strBGFile = ''; // zone 1 backgroup image file
  bool bSelectBgPic = false;
  bool bAspectRatio = false; // Zone 1 Aspect Ratio or not
  double nDuration = 10.0; // Zone 1 duration
  int nEffectType = 0; // zone 1 effect type
  int nOrientation = 0; // zone 1 effect 1
  int nMotion = 0; // zone 1 effect 2
  int nDelay = 0; // zone 1 effect 3
  int nDirection = 0; // zone 1 effect 4
  int nSwapDelay = 0;
  int nPerSecond = 8;
  bool bRandomTransition = false;
  List<String>? arrImageFile;
  List<String>? arrContentObject;
  List<String>? arrTransition;
  List<int>? arrDuration;

  int nType = 0;
  String strUserCode = '';
  String strGroupCode = '';
  String dtModified = '';
  String dtCreated = '';

  /// Get total duration
  double getDuration() {
    double nTotalDuration = 0;
    if (arrDuration != null && arrDuration!.isNotEmpty) {
      for (int i = 0; i < arrImageFile!.length; i++) {
        if (i + 1 > arrDuration!.length) {
          nTotalDuration += nPerSecond;
        } else {
          nTotalDuration += arrDuration![i];
        }
      }
    }
    return nTotalDuration;
  }

  /// Set image file
  void setImageFile(String strImageFile) {
    strFile = strImageFile;
  }

  /// Set background color
  void setBGColor(int crBGColor) {
    crBGColor = crBGColor;
  }

  /// Create a copy of this SlideShowData
  SlideShowData copy() {
    final copy = SlideShowData();
    copy.uiID = uiID;
    copy.strDesc = strDesc;
    copy.strContent = strContent;
    copy.strFile = strFile;
    copy.crBGColor = crBGColor;
    copy.strBGFile = strBGFile;
    copy.bSelectBgPic = bSelectBgPic;
    copy.bAspectRatio = bAspectRatio;
    copy.nDuration = nDuration;
    copy.nEffectType = nEffectType;
    copy.nOrientation = nOrientation;
    copy.nMotion = nMotion;
    copy.nDelay = nDelay;
    copy.nDirection = nDirection;
    copy.nSwapDelay = nSwapDelay;
    copy.nPerSecond = nPerSecond;
    copy.bRandomTransition = bRandomTransition;
    copy.arrImageFile = arrImageFile != null ? List.from(arrImageFile!) : null;
    copy.arrContentObject =
        arrContentObject != null ? List.from(arrContentObject!) : null;
    copy.arrTransition =
        arrTransition != null ? List.from(arrTransition!) : null;
    copy.arrDuration = arrDuration != null ? List.from(arrDuration!) : null;
    copy.nType = nType;
    copy.strUserCode = strUserCode;
    copy.strGroupCode = strGroupCode;
    copy.dtModified = dtModified;
    copy.dtCreated = dtCreated;
    return copy;
  }
}
