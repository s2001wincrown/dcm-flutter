// XmlMultiImageSetting.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/slideshow_data.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';

/// Class for Multi-Image XML Setting operations
class XmlMultiImageSetting {
  static String serialize(SlideShowData pSlideShow) {
    XmlProfile xmlProfile = XmlProfile();

    xmlProfile.createProfile("ImageXML");
    // write some stuff in the profile
    xmlProfile.writeProfileString(
        'ImageSetting', 'Id', pSlideShow.id?.toString() ?? '');
    xmlProfile.writeProfileString(
        'ImageSetting', 'm_strContent', pSlideShow.strContent);
    xmlProfile.writeProfileString(
        'ImageSetting', 'm_strDesc', pSlideShow.strDesc);
    xmlProfile.writeProfileInt(
        'ImageSetting', 'm_bAspectRatio', pSlideShow.bAspectRatio ? 1 : 0);
    xmlProfile.writeProfileInt('ImageSetting', 'm_bRandomTransition',
        pSlideShow.bRandomTransition ? 1 : 0);
    xmlProfile.writeProfileInt(
        'ImageSetting', 'm_nPerSecond', pSlideShow.nPerSecond);
    xmlProfile.writeProfileString(
        'ImageSetting', 'm_crTextBKColor', toRGBString(pSlideShow.crBGColor));
    int i = 0;
    if (pSlideShow.arrImageFile != null) {
      xmlProfile.writeProfileInt(
          'ImageFile', 'TotalImage', pSlideShow.arrImageFile!.length);

      for (i = 0; i < pSlideShow.arrImageFile!.length; i++) {
        String strSeq = 'Image$i';
        xmlProfile.writeProfileString(
            'ImageFile', strSeq, pSlideShow.arrImageFile![i]);
      }
    }
    if (pSlideShow.arrDuration != null) {
      xmlProfile.writeProfileInt(
          'ImageDuration', 'TotalDuration', pSlideShow.arrDuration!.length);
      for (i = 0; i < pSlideShow.arrDuration!.length; i++) {
        String strSeq = 'Duration$i';
        xmlProfile.writeProfileInt(
            'ImageDuration', strSeq, pSlideShow.arrDuration![i]);
      }
    }
    if (pSlideShow.arrTransition != null) {
      xmlProfile.writeProfileInt(
          'Transition', 'TotalTransition', pSlideShow.arrTransition!.length);
      for (i = 0; i < pSlideShow.arrTransition!.length; i++) {
        String strSeq = 'Transition$i';
        xmlProfile.writeProfileString(
            'Transition', strSeq, pSlideShow.arrTransition![i]);
      }
    }
    if (pSlideShow.arrContentObject != null) {
      xmlProfile.writeProfileInt('ContentObject', 'TotalContentObject',
          pSlideShow.arrContentObject!.length);
      for (i = 0; i < pSlideShow.arrContentObject!.length; i++) {
        String strSeq = 'ContentObject$i';
        xmlProfile.writeProfileString(
            'ContentObject', strSeq, pSlideShow.arrContentObject![i]);
      }
    }

    return xmlProfile.export();
  }

  static SlideShowData? loadByFilePath(String strFilePath) {
    if (File(strFilePath).existsSync()) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFilePath);
      if (xmlProfile.loadProfile(szRootItemName: 'ImageXML')) {
        SlideShowData pSlideShow = SlideShowData();
        // write some stuff in the profile
        pSlideShow.strDesc =
            xmlProfile.getProfileString('ImageSetting', 'm_strDesc', '');
        pSlideShow.strContent =
            xmlProfile.getProfileString('ImageSetting', 'm_strContent', '');
        pSlideShow.bAspectRatio =
            (xmlProfile.getProfileInt('ImageSetting', 'm_bAspectRatio', 0) ==
                1);
        pSlideShow.bRandomTransition = (xmlProfile.getProfileInt(
                'ImageSetting', 'm_bRandomTransition', 0) ==
            1);
        pSlideShow.nPerSecond =
            xmlProfile.getProfileInt('ImageSetting', 'm_nPerSecond', 0);
        String strColor = xmlProfile.getProfileString(
            'ImageSetting', 'm_crTextBKColor', '0,0,0');
        pSlideShow.crBGColor = fromRGBString(strColor);
        pSlideShow.strFile =
            xmlProfile.getProfileString('ImageSetting', 'm_strFile', '');

        int nTotalImage =
            xmlProfile.getProfileInt('ImageFile', 'TotalImage', 0);
        int i = 0;
        if (nTotalImage > 0) {
          pSlideShow.arrImageFile ??= [];
          for (i = 0; i < nTotalImage; i++) {
            String strSeq = 'Image$i';
            pSlideShow.arrImageFile!
                .add(xmlProfile.getProfileString('ImageFile', strSeq, ''));
          }
        }
        int nTotalDuration =
            xmlProfile.getProfileInt('ImageDuration', 'TotalDuration', 0);
        if (nTotalDuration > 0) {
          pSlideShow.arrDuration ??= [];
          for (i = 0; i < nTotalDuration; i++) {
            String strSeq = 'Duration$i';
            pSlideShow.arrDuration!
                .add(xmlProfile.getProfileInt('ImageDuration', strSeq, 8));
          }
        }
        int nTotalTransition =
            xmlProfile.getProfileInt('Transition', 'TotalTransition', 0);
        if (nTotalTransition > 0) {
          pSlideShow.arrTransition ??= [];
          for (i = 0; i < nTotalTransition; i++) {
            String strSeq = 'Transition$i';
            pSlideShow.arrTransition!
                .add(xmlProfile.getProfileString('Transition', strSeq, ''));
          }
        }
        return pSlideShow;
      }
    }

    return null;
  }

  static SlideShowData? loadImageSetting(
      String strImageFile, SlideShowData pSlideShow,
      [String? strCompany]) {
    String strFileName =
        Utils.getFilePath(strImageFile, cIMAGETYPE, -1, strCompany);

    return loadByFilePath(strFileName);
  }
}
