// ZoneExtData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

import 'zone_data.dart';

/// Class to hold the data for Extend Zone Data
class ZoneExtData extends ZoneData {
  DateTime? dtStartTime;
  DateTime? dtEndTime;

  ZoneExtData() {
    uiIndex = -1;
    nProductIndex = -1;
    uiCatalogueID = -1;

    final dtCurr = DateTime.now();
    dtStartTime = DateTime(dtCurr.year, dtCurr.month, dtCurr.day, 0, 0, 0);
    dtEndTime = DateTime(2500, 12, 31, 23, 59, 59);
  }

  /// Write to XML
  @override
  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_dtStartTime', dtStartTime);
    pXmlItem.addItem('m_dtEndTime', dtEndTime);

    // Call parent writeToXML
    super.writeToXML(pXmlItem);
  }

  /// Get from XML
  @override
  void getFromXML(XmlItem pXmlItem) {
    dtStartTime = pXmlItem.getItemValueD('m_dtStartTime');
    dtEndTime = pXmlItem.getItemValueD('m_dtEndTime');

    // Call parent getFromXML
    super.getFromXML(pXmlItem);
  }

  /// Check if it's time to play
  bool isTimeForPlay() {
    final dtCurr = DateTime.now();
    DateTime? startTime = dtStartTime;
    DateTime? endTime = dtEndTime;

    // Note: SETTING_VALIDCLONLYTIME would need to be checked from constants
    if ((AppGlobal.globalSetting & settingVALIDCLONLYTIME) > 0) {
      endTime = dtCurr.copyWith(
          hour: dtEndTime?.hour ?? 0,
          minute: dtEndTime?.minute ?? 0,
          second: dtEndTime?.second ?? 0,
          millisecond: 0,
          microsecond: 0);
      startTime = dtCurr.copyWith(
          hour: dtStartTime?.hour ?? 0,
          minute: dtStartTime?.minute ?? 0,
          second: dtStartTime?.second ?? 0,
          millisecond: 0,
          microsecond: 0);
    }

    if (endTime != null && startTime != null) {
      return startTime.isBefore(dtCurr) && endTime.isAfter(dtCurr);
    }

    if (endTime != null) {
      return endTime.isAfter(dtCurr);
    }

    if (startTime != null) return (startTime.compareTo(dtCurr) <= 0);

    return true;
  }

  /// Check if the schedule is outdated
  bool isOutdated() {
    final dtCurr = DateTime.now();

    // Note: SETTING_VALIDCLONLYTIME would need to be checked from constants
    if ((AppGlobal.globalSetting & settingVALIDCLONLYTIME) > 0) {
      if (dtEndTime != null) {
        var endTime = dtCurr.copyWith(
          hour: dtEndTime?.hour ?? 0,
          minute: dtEndTime?.minute ?? 0,
          second: dtEndTime?.second ?? 0,
          millisecond: 0,
          microsecond: 0,
        );

        return (endTime.compareTo(dtCurr) <= 0);
      }
    } else {
      if (dtEndTime != null) {
        return dtEndTime!.isBefore(dtCurr);
      }
    }

    return false;
  }

  @override
  ZoneExtData copy() {
    final copy = ZoneExtData();
    copy.dtStartTime = dtStartTime;
    copy.dtEndTime = dtEndTime;
    // Copy base class properties
    copy.uiID = uiID;
    copy.uiCatalogueID = uiCatalogueID;
    copy.uiIndex = uiIndex;
    copy.nProductIndex = nProductIndex;
    copy.uiChannelID = uiChannelID;
    copy.nZoneID = nZoneID;
    copy.nZoneType = nZoneType;
    copy.strZoneFile = strZoneFile;
    copy.strZoneOfflineFile = strZoneOfflineFile;
    copy.crZoneBGColor = crZoneBGColor;
    copy.strZoneBGFile = strZoneBGFile;
    copy.bZoneSelectBgPic = bZoneSelectBgPic;
    copy.bChkZone = bChkZone;
    copy.bDDERefresh = bDDERefresh;
    copy.nZoom = nZoom;
    copy.dAspect = dAspect;
    copy.dVolume = dVolume;
    copy.dSpeed = dSpeed;
    copy.bAlpha = bAlpha;
    copy.bZoneMute = bZoneMute;
    copy.bZoneRatio = bZoneRatio;
    copy.nZoneDuration = nZoneDuration;
    copy.nZonePort = nZonePort;
    copy.nZoneEffectType = nZoneEffectType;
    copy.nZoneOrientation = nZoneOrientation;
    copy.nZoneMotion = nZoneMotion;
    copy.nZoneDelay = nZoneDelay;
    copy.nZoneDirection = nZoneDirection;
    copy.strWebCharset = strWebCharset;
    copy.nWebZoom = nWebZoom;
    copy.bZoneChkMpeg2 = bZoneChkMpeg2;
    copy.nVideoCompressor = nVideoCompressor;
    copy.nZoneTVSource = nZoneTVSource;
    copy.nZoneTVStandard = nZoneTVStandard;
    copy.nZoneTVInput = nZoneTVInput;
    copy.nZoneTVInputType = nZoneTVInputType;
    copy.nZoneTVTuningSpace = nZoneTVTuningSpace;
    copy.nZoneTVCountry = nZoneTVCountry;
    copy.lFrequency = lFrequency;
    copy.strZoneTVChannel = strZoneTVChannel;
    copy.strZoneTVSource = strZoneTVSource;
    copy.nAudioSource = nAudioSource;
    copy.nAudioStandard = nAudioStandard;
    copy.strAudioSource = strAudioSource;
    copy.strAudioDevice = strAudioDevice;
    return copy;
  }
}
