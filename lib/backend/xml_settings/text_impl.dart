//===========================================================================
// This is a part of dc Catalogue System(Visual C++).
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//===========================================================================
//
//	Project/Product :	dcCatalogue
//  FileName		:	ContentImpl.cpp
//	Author(s)		:	John Lee
//  Homepage		:	http://www.s2001.com
//
//	Description		:	All the global functions used in the dcCatalogue
//
//	Classes			:	None
//
//	Information		:
//	  Compiler(s)	:	Visual C++ 6.0 Ent.
//	  Target(s)		:	Win32 / MFC
//	  Editor		  :	Microsoft Visual Studio 6.0 editor
//
//	History
//	Vers.  Date        Aut.  Type     Description
//  -----  --------    ----  -------  -----------------------------------------
//	1.00   12 04 2004  JL    Create   Original
//===========================================================================
// Construction/Destruction
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/banner_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';

//////////////////////////////////////////////////////////////////////
class TextImpl {
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //Scroll Text Setting
  TextImpl();

  static BannerData loadDefaultSetting(String strDefault) {
    BannerData pBanner = BannerData();

    pBanner.strTextFontName =
        AppGlobal.getString('$strDefault.FontName', 'Arial');
    pBanner.strText = AppGlobal.getString('$strDefault.TextContent', '');
    pBanner.bFontItalic = AppGlobal.getBool('$strDefault.FontItalic');
    pBanner.bFontBold = AppGlobal.getBool('$strDefault.FontBold');
    pBanner.bFontUnderline = AppGlobal.getBool('$strDefault.FontUnderline');
    pBanner.bStrikethrough = AppGlobal.getBool('$strDefault.FontStrikethrough');
    pBanner.nTextFontSize = AppGlobal.getInt('$strDefault.FontSize', 50) * 20;
    pBanner.nDirection = AppGlobal.getInt('$strDefault.Direction', 0);
    pBanner.nSpeed = AppGlobal.getInt('$strDefault.Speed', 2);
    pBanner.nBehavior = AppGlobal.getInt('$strDefault.Behavior', 1);
    pBanner.crTextBKColor = fromRGBString(
        AppGlobal.getString('$strDefault.BackgroundColor', '0,0,0'));
    pBanner.crTextFGColor = fromRGBString(
        AppGlobal.getString('$strDefault.FontColor', '255,255,255'));
    pBanner.nTemplate = AppGlobal.getInt('$strDefault.Template', 2);

    pBanner.customComments = pBanner.strText;
    pBanner.strHtml = pBanner.strText;

    return pBanner;
  }

  static BannerData loadDefaSettingForEventImp() {
    BannerData pBanner = BannerData();

    pBanner.strTextFontName =
        AppGlobal.getString('TextDefaSettingForEventImp.FontName', 'Arial');
    pBanner.strText =
        AppGlobal.getString('TextDefaSettingForEventImp.TextContent');
    pBanner.bFontItalic =
        AppGlobal.getBool('TextDefaSettingForEventImp.FontItalic');
    pBanner.bFontBold =
        AppGlobal.getBool('TextDefaSettingForEventImp.FontBold');
    pBanner.bFontUnderline =
        AppGlobal.getBool('TextDefaSettingForEventImp.FontUnderline');
    pBanner.bStrikethrough =
        AppGlobal.getBool('TextDefaSettingForEventImp.FontStrikethrough');
    pBanner.nTextFontSize =
        AppGlobal.getInt('TextDefaSettingForEventImp.FontSize', 50) * 20;
    pBanner.nDirection =
        AppGlobal.getInt('TextDefaSettingForEventImp.Direction', 0);
    pBanner.nSpeed = AppGlobal.getInt('TextDefaSettingForEventImp.Speed', 2);
    pBanner.nBehavior =
        AppGlobal.getInt('TextDefaSettingForEventImp.Behavior', 1);
    pBanner.crTextBKColor = fromRGBString(AppGlobal.getString(
        'TextDefaSettingForEventImp.BackgroundColor', '0,0,0'));
    pBanner.crTextFGColor = fromRGBString(AppGlobal.getString(
        'TextDefaSettingForEventImp.FontColor', '255,255,255'));
    pBanner.nTemplate =
        AppGlobal.getInt('TextDefaSettingForEventImp.Template', 0);
    pBanner.strFile =
        AppGlobal.getString('TextDefaSettingForEventImp.BackgroundImage');

    pBanner.customComments = pBanner.strText;
    pBanner.strHtml = pBanner.strText;

    return pBanner;
  }

  static BannerData? loadTextSetting(String strTextFile, [String? strCompany]) {
    String strFileName =
        Utils.getFilePath(strTextFile, cTEXTTYPE, -1, strCompany);

    return loadByFilePath(strFileName);
  }

  static BannerData? loadByFilePath(String strFileName) {
    BannerData? pBanner;
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    if (xmlProfile.loadProfile(szRootItemName: 'TextXML')) {
      pBanner = BannerData();
      pBanner.strDesc =
          xmlProfile.getProfileString('TextSetting', 'm_strDesc', '');
      pBanner.strContent =
          xmlProfile.getProfileString('TextSetting', 'm_strContent', '');
      pBanner.nBg = xmlProfile.getProfileInt('TextSetting', 'm_nBg', 0);
      pBanner.strText =
          xmlProfile.getProfileString('TextSetting', 'm_strText', '');
      pBanner.customComments =
          xmlProfile.getProfileString('TextSetting', 'm_CustomComments', '');
      pBanner.strHtml =
          xmlProfile.getProfileString('TextSetting', 'm_strHtml', '');
      pBanner.strXMLFormat =
          xmlProfile.getProfileString('TextSetting', 'm_strXMLFormat', '');
      pBanner.bFontItalic =
          (xmlProfile.getProfileInt('TextSetting', 'm_bFontItalic', 0) == 1);
      pBanner.bFontBold =
          (xmlProfile.getProfileInt('TextSetting', 'm_bFontBold', 0) == 1);
      pBanner.bFontUnderline =
          (xmlProfile.getProfileInt('TextSetting', 'm_bFontUnderline', 0) == 1);
      pBanner.bStrikethrough =
          (xmlProfile.getProfileInt('TextSetting', 'm_bStrikethrough', 0) == 1);
      pBanner.bHLColor =
          (xmlProfile.getProfileInt('TextSetting', 'm_bHLColor', 1) == 1);
      //bool bIsHtml = (xmlProfile.getProfileInt('TextSetting', 'm_bIsHtml', 0) == 1);
      pBanner.nTemplate =
          xmlProfile.getProfileInt('TextSetting', 'm_nTemplate', 0);
      pBanner.nTextFontSize =
          xmlProfile.getProfileInt('TextSetting', 'm_nTextFontSize', 44 * 20);
      pBanner.strTextFontName = xmlProfile.getProfileString(
          'TextSetting', 'm_strTextFontName', 'Arial');
      pBanner.strFile =
          xmlProfile.getProfileString('TextSetting', 'm_strFile', '');
      pBanner.strMusicFile =
          xmlProfile.getProfileString('TextSetting', 'm_strMusicFile', '');
      pBanner.nFont = xmlProfile.getProfileInt('TextSetting', 'm_nFont', 0);
      pBanner.nDirection =
          xmlProfile.getProfileInt('TextSetting', 'm_nDirection', 0);
      pBanner.nValign = xmlProfile.getProfileInt('TextSetting', 'm_nValign', 0);
      pBanner.nBullet = xmlProfile.getProfileInt('TextSetting', 'm_nBullet', 0);
      pBanner.nIndent = xmlProfile.getProfileInt('TextSetting', 'm_nIndent', 0);
      //pBanner.nDuration = xmlProfile.getProfileInt('TextSetting', 'm_nDuration', 60);
      pBanner.nSpeed = xmlProfile.getProfileInt('TextSetting', 'm_nSpeed', 5);
      pBanner.nTop = xmlProfile.getProfileInt('TextSetting', 'm_nTop', 0);
      pBanner.nLeft = xmlProfile.getProfileInt('TextSetting', 'm_nLeft', 0);
      pBanner.nBehavior =
          xmlProfile.getProfileInt('TextSetting', 'm_nBehavior', 1);
      String strColor = xmlProfile.getProfileString(
          'TextSetting', 'm_crTextBKColor', '0,0,0');
      pBanner.crTextBKColor = fromRGBString(strColor);
      strColor = xmlProfile.getProfileString(
          'TextSetting', 'm_crTextFGColor', '255,255,255');
      pBanner.crTextFGColor = fromRGBString(strColor);
      strColor = xmlProfile.getProfileString(
          'TextSetting', 'm_crTextHLColor', '255,255,255');
      pBanner.crTextHLColor = fromRGBString(strColor);
      pBanner.strLanguage =
          xmlProfile.getProfileString('TextSetting', 'm_strLanguage', 'ENG');

      pBanner.strHalign =
          xmlProfile.getProfileString('TextSetting', 'm_strHalign', 'left');
      pBanner.strValign =
          xmlProfile.getProfileString('TextSetting', 'm_strValign', 'top');
    }

    return pBanner;
  }

  static bool saveTextSetting(String strTextFile, BannerData pBanner,
      [String? strCompany]) {
    String strFileName =
        Utils.getFilePath(strTextFile, cTEXTTYPE, -1, strCompany);

    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    //xmlProfile.loadProfile('TextXML');
    xmlProfile.createProfile('TextXML');

    // write some stuff in the profile
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strContent', pBanner.strContent);
    xmlProfile.writeProfileString('TextSetting', 'm_strDesc', pBanner.strDesc);
    //xmlProfile.writeProfileInt('TextSetting', 'm_nLanguage', m_nLanguage);
    xmlProfile.writeProfileInt('TextSetting', 'm_nBg', pBanner.nBg);
    xmlProfile.writeProfileString('TextSetting', 'm_strText', pBanner.strText);
    xmlProfile.writeProfileString('TextSetting', 'm_strHtml', pBanner.strHtml);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strXMLFormat', pBanner.strXMLFormat);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_CustomComments', pBanner.customComments);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_bFontItalic', pBanner.bFontItalic ? 1 : 0);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_bFontBold', pBanner.bFontBold ? 1 : 0);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_bUnderline', pBanner.bFontUnderline ? 1 : 0);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_bStrikethrough', pBanner.bStrikethrough ? 1 : 0);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_bHLColor', pBanner.bHLColor ? 1 : 0);
    //xmlProfile.writeProfileInt('TextSetting', 'm_bIsHtml', m_bIsHtml ? 1 : 0);
    xmlProfile.writeProfileInt('TextSetting', 'm_nTemplate', pBanner.nTemplate);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_nTextFontSize', pBanner.nTextFontSize);
    xmlProfile.writeProfileInt('TextSetting', 'm_nFont', pBanner.nFont);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strTextFontName', pBanner.strTextFontName);
    xmlProfile.writeProfileString('TextSetting', 'm_strFile', pBanner.strFile);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strMusicFile', pBanner.strMusicFile);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strHalign', pBanner.strHalign);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strValign', pBanner.strValign);
    xmlProfile.writeProfileInt(
        'TextSetting', 'm_nDirection', pBanner.nDirection);
    //xmlProfile.writeProfileInt('TextSetting', 'm_nDuration', 60);
    xmlProfile.writeProfileInt('TextSetting', 'm_nSpeed', pBanner.nSpeed);
    xmlProfile.writeProfileInt('TextSetting', 'm_nTop', pBanner.nTop);
    xmlProfile.writeProfileInt('TextSetting', 'm_nLeft', pBanner.nLeft);
    xmlProfile.writeProfileInt('TextSetting', 'm_nBehavior', pBanner.nBehavior);
    xmlProfile.writeProfileInt('TextSetting', 'm_nValign', pBanner.nValign);
    xmlProfile.writeProfileInt('TextSetting', 'm_nBullet', pBanner.nBullet);
    xmlProfile.writeProfileInt('TextSetting', 'm_nIndent', pBanner.nIndent);
    xmlProfile.writeProfileString(
        'TextSetting', 'm_crTextBKColor', toRGBString(pBanner.crTextBKColor));
    xmlProfile.writeProfileString(
        'TextSetting', 'm_crTextFGColor', toRGBString(pBanner.crTextFGColor));
    xmlProfile.writeProfileString(
        'TextSetting', 'm_crTextHLColor', toRGBString(pBanner.crTextHLColor));
    xmlProfile.writeProfileString(
        'TextSetting', 'm_strLanguage', pBanner.strLanguage);

    return xmlProfile.saveProfile();
  }

  static bool getFromXMLFormat(String strXMLFormat, BannerData pBanner) {
    XmlFile xmlFormat = XmlFile('XMLContentFormat');
    if (xmlFormat.loadXml(strXMLFormat)) {
      //XmlItem *pItem = XMLFormat.GetItem('ContentFormat');
      XmlItem xi = xmlFormat.root();
      pBanner.bFontItalic = xi.getItemValueB('m_bFontItalic');
      pBanner.bFontBold = xi.getItemValueB('m_bFontBold');
      pBanner.bFontUnderline = xi.getItemValueB('m_bUnderline');
      pBanner.bStrikethrough = xi.getItemValueB('m_bStrikethrough');
      pBanner.bHLColor = xi.getItemValueB('m_bHLColor');
      pBanner.nTextFontSize = xi.getItemValueI('m_nTextFontSize');
      pBanner.strTextFontName = xi.getItemValue('m_strTextFontName');
      pBanner.nBullet = xi.getItemValueI('m_nBullet');
      pBanner.nIndent = xi.getItemValueI('m_nIndent');
      pBanner.crTextFGColor = xi.getItemValueR('m_crTextFGColor') ?? 0xFFFFFF;
      pBanner.crTextHLColor = xi.getItemValueR('m_crTextHLColor') ?? 0xFFFFFF;
      pBanner.strHalign = xi.getItemValue('m_strHalign');

      return true;
    }

    return false;
  }

  static List<String>? getImagesPath(BannerData pBanner) {
    XmlFile xmlFormat = XmlFile('XMLImagesArray');
    if (xmlFormat.loadXml(pBanner.strXMLFormat)) {
      XmlItem? pImagesItem = xmlFormat.root().getItem('arrImages');
      if (pImagesItem != null) {
        List<String> arrImage = [];
        XmlItem? pNameXISibling = pImagesItem.getItem('Image');
        while (pNameXISibling != null) {
          arrImage.add(pNameXISibling.getItemValue('Path'));

          pNameXISibling = pNameXISibling.getSibling();
        }

        return arrImage;
      }
    }

    return null;
  }

  static bool formatHtmlContent(String strContent, BannerData pBanner) {
    List<String>? arrImages = getImagesPath(pBanner);
    if (arrImages != null) {
      for (int i = 0; i < arrImages.length; i++) {
        String strImageFile = arrImages.elementAt(i);
        String strPreImage = strImageFile.substring(0, 7);
        if (strPreImage.equalsIgnoreCase('file:///')) {
          strImageFile = strImageFile.substring(8);
        }
        strImageFile.replaceAll('\\', '/');
        strImageFile.replaceAll('%20', ' ');
        String strFile =
            strImageFile.substring(strImageFile.lastIndexOf('/') + 1);
        //strImageFile = Settings.strImagePath + '/') + strFile;
        strImageFile = 'file:///${Utils.getFilePath(strFile, cIMAGETYPE)}';
        strImageFile.replaceAll('\\', '/');
        strImageFile.replaceAll(' ', '%20');
        strContent.replaceAll('{image$i}', strImageFile);
        strContent.replaceAll(arrImages.elementAt(i), strImageFile);
      }
    }

    return true;
  }
}
