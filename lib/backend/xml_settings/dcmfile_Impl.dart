// dcmfile_impl.dart : implementation of the DCMFileImpl class
//

// copyright (C) 2004 s2001 Ltd.. All rights reserved.
// DCMFileImpl construction/destruction
import 'dart:io';
import 'dart:ui';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/contentlist_impl.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

class DCMFileImpl {
  static const String lpszSignature = "dcCatalogue Version 4.0 Document";

  static bool deleteCatalogue({DCMFileData? dcmfileData, String? szCatalogue}) {
    String? strCatalogue = szCatalogue;
    if (dcmfileData != null) {
      strCatalogue = dcmfileData.strCatalogueName;
    }

    if (strCatalogue == null || strCatalogue.isEmpty) {
      return false;
    }

    String strDCMFile = Utils.getFilePath(strCatalogue, cDCMFILETYPE, -1, null);
    File(strDCMFile).deleteSync();

    return true;
  }

  static bool addCatalogue(DCMFileData pData) {
    if (serializeDataBase(pData, pData.strCatalogueName, bUpdate: true)) {
      //Load Database
      String strEdit = Utils.getFilePath(pData.strCatalogueName, cDCMFILETYPE);

      return serializeTo(pData, strEdit); // save me
    }

    return false; // success
  }

  static bool updateCatalogue(DCMFileData pData) {
    if (serializeDataBase(pData, pData.strCatalogueName,
        bUpdate: true, bNew: false)) {
      //Load Database
      String strEdit = Utils.getFilePath(pData.strCatalogueName, cDCMFILETYPE);

      return serializeTo(pData, strEdit); // save me
    }

    return false; // success
  }

  static bool serializeTo(DCMFileData pDCMFile, String strFilename) {
    XmlFilePro playerReg = XmlFilePro("DCMDocument");

    playerReg.setDataNode(null, 'm_strDocVersion', pDCMFile.strDocVersion);
    playerReg.setDataNode(null, "m_nQuantity", pDCMFile.nQuantity);
    playerReg.setDataNode(null, "m_strBtnLng", pDCMFile.strBtnLng);
    playerReg.setDataNode(null, "m_nBtnAlign", pDCMFile.nBtnAlign);
    playerReg.setDataNode(null, "m_nBtnStyle", pDCMFile.nBtnStyle);
    playerReg.setDataNode(null, "m_nFontSize", pDCMFile.nFontSize);
    playerReg.setDataNode(null, "m_nScreenType", pDCMFile.nScreenType);
    playerReg.setDataNode(null, "m_nBGType", pDCMFile.nBGType);
    playerReg.setDataNode(null, "m_strFontName", pDCMFile.strFontName);
    playerReg.setDataNode(null, "m_strImageFile", pDCMFile.strImageFile);
    playerReg.setDataNode(null, "m_strMusicFile", pDCMFile.strMusicFile);
    playerReg.setDataNode(null, "m_bBGMusic", pDCMFile.bBGMusic);
    playerReg.setDataNode(null, "m_bFontBold", pDCMFile.bFontBold);
    playerReg.setDataNode(null, "m_bFontItalic", pDCMFile.bFontItalic);
    playerReg.setDataNode(null, "m_bFontUnderline", pDCMFile.bFontUnderline);
    playerReg.setDataNode(null, "m_crFontColor", pDCMFile.crFontColor);
    playerReg.setDataNode(null, "m_crBGColor", pDCMFile.crBGColor);
    playerReg.setDataNode(null, "m_strLayoutName", pDCMFile.strLayoutName);
    playerReg.setDataNode(null, "m_nSkin", pDCMFile.nSkin);
    playerReg.setDataNode(null, "m_strSkinCode", pDCMFile.strSkinCode);
    playerReg.setDataNode(null, "m_strUserCode", pDCMFile.strUserCode);
    playerReg.setDataNode(null, "m_strGroupCode", pDCMFile.strGroupCode);
    playerReg.setDataNode(null, "m_dtCreated", pDCMFile.dtCreated, true);
    playerReg.setDataNode(null, "m_dtModified", pDCMFile.dtModified, true);

    // Save the Product information
    if (pDCMFile.lstProduct != null) {
      XmlItem? pItem = playerReg.addDataNode('m_lstProduct', null);
      if (pItem != null) {
        Iterator it = pDCMFile.lstProduct!.iterator;
        while (it.moveNext()) {
          ProductData product = it.current;
          if (product.uiID < pDCMFile.nQuantity) {
            XmlItem? xiProductItem = pItem.addItem('ProductData');
            if (xiProductItem != null) {
              product.writeToXML(xiProductItem);
            }
          }
        }
      }
    }
    if (pDCMFile.pLayoutDataObj != null) {
      XmlItem? xiLayoutItem = playerReg.addDataNode('LayoutData', null);
      if (xiLayoutItem != null) {
        serializeLayoutTo(pDCMFile.pLayoutDataObj, xiLayoutItem);
      }
    }

    playerReg.setSignature(lpszSignature);

    // encrypt prior to setting checkout status and file info (so these are visible without decryption)
    // this simply fails if password is empty
    //PlayerReg.Encrypt(CEncryption::GetDCMPhrase());

    return playerReg.save(strFilename);
  }

  static DCMFileData? serializeFromFile(String strFilename) {
    XmlFilePro file = XmlFilePro("DCMDocument", Encodes.cCONTENTFILECRYPTKEY);
    if (!file.open(strFilename, XfOpen.read)) {
      return null;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        DCMFileData pDCMFile = DCMFileData();
        pDCMFile.strDocVersion = file.getItemValue("m_strDocVersion");
        pDCMFile.nQuantity = file.getItemValueI("m_nQuantity");
        pDCMFile.nBGType = file.getItemValueI("m_nBGType");
        pDCMFile.strBtnLng = file.getItemValue("m_strBtnLng");
        pDCMFile.nBtnAlign = file.getItemValueI("m_nBtnAlign");
        pDCMFile.nBtnStyle = file.getItemValueI("m_nBtnStyle");
        pDCMFile.nFontSize = file.getItemValueI("m_nFontSize");
        pDCMFile.nScreenType = file.getItemValueI("m_nScreenType");
        pDCMFile.strFontName = file.getItemValue("m_strFontName");
        pDCMFile.strImageFile = file.getItemValue("m_strImageFile");
        pDCMFile.strMusicFile = file.getItemValue("m_strMusicFile");
        pDCMFile.bBGMusic = file.getItemValueB("m_bBGMusic");
        pDCMFile.bFontBold = file.getItemValueB("m_bFontBold");
        pDCMFile.bFontItalic = file.getItemValueB("m_bFontItalic");
        pDCMFile.bFontUnderline = file.getItemValueB("m_bFontUnderline");
        pDCMFile.crFontColor = file.getItemValueR("m_crFontColor") ?? 0xFFFFFF;
        pDCMFile.crBGColor = file.getItemValueR("m_crBGColor") ?? 0;
        pDCMFile.strLayoutName = file.getItemValue("m_strLayoutName");
        pDCMFile.nSkin = file.getItemValueI("m_nSkin");
        pDCMFile.strSkinCode = file.getItemValue("m_strSkinCode");
        pDCMFile.strUserCode = file.getItemValue("m_strUserCode");
        pDCMFile.strGroupCode = file.getItemValue("m_strGroupCode");
        pDCMFile.dtCreated = file.getItemValueD("m_dtCreated");
        pDCMFile.dtModified = file.getItemValueD("m_dtModified");

        // get Product information list
        XmlItem? pItem = file.getItem("m_lstProduct");
        if (pItem != null) {
          XmlItem? pXISibling = pItem.getItem("CProductData");
          while (pXISibling != null) {
            ProductData pData = ProductData();

            // get Player channel Inforamtion data
            pData.getFromXML(pXISibling);

            // add Player Channel data to list
            pDCMFile.addProduct(pData);

            pXISibling = pXISibling.getSibling();
          }
        }

        pDCMFile.pLayoutDataObj = null;
        XmlItem? xiLayoutItem = file.getItem("LayoutData");
        if (xiLayoutItem != null && xiLayoutItem.getItemCount() > 0) {
          pDCMFile.pLayoutDataObj = serializeLayoutFrom(xiLayoutItem);
        }

        return pDCMFile;
      }
    }
    return null;
  }

  static DCMFileData? serializeFrom(String strXml) {
    XmlFilePro file = XmlFilePro("DCMDocument");
    if (file.loadXml(strXml)) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        DCMFileData pDCMFile = DCMFileData();
        pDCMFile.strDocVersion = file.getItemValue('m_strDocVersion');
        pDCMFile.nQuantity = file.getItemValueI('m_nQuantity');
        pDCMFile.nBGType = file.getItemValueI('m_nBGType');
        pDCMFile.strBtnLng = file.getItemValue('m_strBtnLng');
        pDCMFile.nBtnAlign = file.getItemValueI('m_nBtnAlign');
        pDCMFile.nBtnStyle = file.getItemValueI('m_nBtnStyle');
        pDCMFile.nFontSize = file.getItemValueI("m_nFontSize");
        pDCMFile.nScreenType = file.getItemValueI("m_nScreenType");
        pDCMFile.strFontName = file.getItemValue("m_strFontName");
        pDCMFile.strImageFile = file.getItemValue("m_strImageFile");
        pDCMFile.strMusicFile = file.getItemValue("m_strMusicFile");
        pDCMFile.bBGMusic = file.getItemValueB("m_bBGMusic");
        pDCMFile.bFontBold = file.getItemValueB("m_bFontBold");
        pDCMFile.bFontItalic = file.getItemValueB("m_bFontItalic");
        pDCMFile.bFontUnderline = file.getItemValueB("m_bFontUnderline");
        pDCMFile.crFontColor = file.getItemValueR("m_crFontColor") ?? 0xFFFFFF;
        pDCMFile.crBGColor = file.getItemValueR("m_crBGColor") ?? 0;
        pDCMFile.strLayoutName = file.getItemValue("m_strLayoutName");
        pDCMFile.nSkin = file.getItemValueI("m_nSkin");
        pDCMFile.strSkinCode = file.getItemValue("m_strSkinCode");
        pDCMFile.strUserCode = file.getItemValue("m_strUserCode");
        pDCMFile.strGroupCode = file.getItemValue("m_strGroupCode");
        pDCMFile.dtCreated = file.getItemValueD("m_dtCreated");
        pDCMFile.dtModified = file.getItemValueD("m_dtModified");

        // get Product information list
        XmlItem? pItem = file.getItem('m_lstProduct');
        if (pItem != null) {
          XmlItem? pXISibling = pItem.getItem('CProductData');
          while (pXISibling != null) {
            ProductData pData = ProductData();

            // get Player channel Inforamtion data
            pData.getFromXML(pXISibling);

            // add product data to list
            pDCMFile.addProduct(pData);

            pXISibling = pXISibling.getSibling();
          }
        }

        pDCMFile.pLayoutDataObj = null;
        XmlItem? xiLayoutItem = file.getItem('LayoutData');
        if (xiLayoutItem != null && xiLayoutItem.getItemCount() > 0) {
          pDCMFile.pLayoutDataObj = serializeLayoutFrom(xiLayoutItem);
        }

        return pDCMFile;
      }
    }
    return null;
  }

  /////////////////////////////////////////////////////////////////////////////
  // CDCMFileImpl commands

  static void getLayoutData(DCMFileData pDCMFile) {}

  static bool serializeDataBase(DCMFileData pDCMFile, String strCatalogueName,
      {bool bUpdate = true, bool bNew = true}) {
    if (strCatalogueName.isEmpty) {
      return true;
    }

    bool bSuccess = true;
    return bSuccess;
  }

  static Rect? getVideoWindowRect(LayoutData? pLayoutDataObj, Rect rectVW) {
    if (pLayoutDataObj == null) {
      return null;
    }

    double nVWWidth;
    double nVWHeight;
    double nScreenWidth = pLayoutDataObj.iScreenWidth.toDouble();
    double nScreenHeight = pLayoutDataObj.iScreenHeight.toDouble();
    double nHeight = rectVW.height;
    double nWidth = rectVW.width;
    if ((nWidth / nHeight) > (nScreenWidth / nScreenHeight)) {
      nVWWidth = rectVW.height * nScreenWidth / nScreenHeight;
      nVWHeight = rectVW.height;
    } else {
      nVWWidth = rectVW.width;
      nVWHeight = rectVW.width * nScreenHeight / nScreenWidth;
    }

    return Rect.fromLTWH(0, 0, nVWWidth, nVWHeight);
  }

  static Rect? getZoneRect(
      LayoutData? pLayoutDataObj, int nZone, Rect rectVW, Rect rcZone) {
    if (pLayoutDataObj == null) {
      return null;
    }
    double nLeft = 0;
    double nTop = 0;
    double nRight = 0;
    double nBottom = 0;

    Rect? pRect = pLayoutDataObj.getZoneRect(nZone);
    if (pRect != null) {
      nLeft = pRect.left;
      nTop = pRect.top;
      nRight = pRect.right;
      nBottom = pRect.bottom;
    }

    int nScreenWidth = pLayoutDataObj.iScreenWidth;
    int nScreenHeight = pLayoutDataObj.iScreenHeight;
    double nHeight = rectVW.height;
    double nWidth = rectVW.width;
    nLeft = rectVW.left + nLeft * nWidth / nScreenWidth;
    nTop = rectVW.top + nTop * nHeight / nScreenHeight;
    nRight = rectVW.left + nRight * nWidth / nScreenWidth;
    nBottom = rectVW.top + nBottom * nHeight / nScreenHeight;

    return Rect.fromLTWH(nLeft, nTop, nRight, nBottom);
  }

  static bool isProductValidForPlay(ProductData pProduct,
      [String? lpszCompany]) {
    Iterator it = pProduct.lstZone.iterator;
    while (it.moveNext()) {
      ZoneData pData = it.current;
      if ((pData.strZoneFile.isNotEmpty) ||
          (pData.nZoneType == cPLUGINTYPE) ||
          (pData.nZoneType == cSITEPLAYLIST)) {
        return true;
      }
    }

    return false;
  }

  static String? getDCMPath(String szCatalogueName, String szFolder,
      [String? szCompany]) {
    String strPlayFile;
    if (szFolder.isEmpty) {
      strPlayFile =
          Utils.getFilePath(szCatalogueName, cDCMFILETYPE, -1, szCompany);
    } else {
      strPlayFile = path.join(szFolder, '$szCatalogueName.DCM');
      if (isNotBlank(szCompany)) {
        strPlayFile = path.join(szFolder, szCompany, '$szCatalogueName.DCM');
      }

      if (File(strPlayFile).existsSync()) {
        return strPlayFile;
      }
    }

    return null;
  }

  static bool isZoneValidForPlay(String strPath, int nZoneType) {
    if (nZoneType == cDIRECTPLAYTYPE || nZoneType == cDDETYPE) {
      return true;
    }

    if (strPath.isNotEmpty) {
      if (nZoneType == cTVCAPTURETYPE ||
          nZoneType == cTEXTTYPE ||
          nZoneType == cWEBCAMTYPE ||
          nZoneType == cIMAGETYPE ||
          nZoneType == cSTREAMINGTYPE ||
          nZoneType == cONLINETYPE ||
          nZoneType == cCLOCKTYPE ||
          nZoneType == cWEATHERTYPE ||
          nZoneType == cEXPLORERTYPE ||
          nZoneType == cLINKAGETYPE ||
          nZoneType == cEVENTTYPE ||
          nZoneType == cPLUGINTYPE) {
        return true;
      }

      if (nZoneType != cWEBPAGETYPE) {
        // Is this a valid directory and file name?
        return File(strPath).existsSync();
      } else {
        return true;
      }
    }

    return false;
  }

  static DCMFileData? openCatalogue(
      {DCMFileData? pDCMFile,
      String? szEdit,
      String? catalogueName,
      bool bShort = false}) {
    if (pDCMFile == null) {
      String strDCMFile = "";
      if (bShort) {
        strDCMFile = Utils.getFilePath(szEdit!, cDCMFILETYPE);
      } else {
        strDCMFile = szEdit!;
      }

      if (File(strDCMFile).existsSync()) {
        return serializeFromFile(strDCMFile);
      }
    } else {
      String strEdit = szEdit!;
      String strCatalogueName = catalogueName!;
      if (serializeDataBase(pDCMFile, strCatalogueName, bUpdate: false)) {
        //Load DataBase
        return serializeFromFile(strEdit); // load me
      } else {
        return serializeFromFile(strEdit); // load me
      }
    }

    return null;
  }

  static bool saveCatalogue(DCMFileData pDCMFile, String szTitle) {
    bool bSuccess = false;
    String strTitle = szTitle;
    if (serializeDataBase(pDCMFile, strTitle)) {
      //Load Database
      String strEdit = Utils.getFilePath(szTitle, cDCMFILETYPE);

      bSuccess = serializeTo(pDCMFile, strEdit); // save me
    }

    return bSuccess; // success
  }

  static bool serializeLayout(DCMFileData pDCMFile, XmlItem pItem,
      [bool bStoring = true]) {
    if (!bStoring) {
      pDCMFile.pLayoutDataObj = serializeLayoutFrom(pItem);
      return true;
    } else {
      return serializeLayoutTo(pDCMFile.pLayoutDataObj, pItem);
    }
  }

  static bool serializeLayoutTo(LayoutData? pLayoutData, XmlItem? pItem) {
    if (pLayoutData == null || pItem == null) {
      return false;
    }

    // Save the Layout information
    pItem.addItem("m_uiID", pLayoutData.uiID);
    pItem.addItem("m_uiGroupID", pLayoutData.uiGroupID);
    pItem.addItem("m_strLayoutName", pLayoutData.strLayoutName);
    pItem.addItem("m_strLayoutDesc", pLayoutData.strLayoutDesc);
    pItem.addItem("m_strImageFile", pLayoutData.strImageFile);
    pItem.addItem("m_iScreenHeight", pLayoutData.iScreenHeight);
    pItem.addItem("m_iScreenWidth", pLayoutData.iScreenWidth);
    pItem.addItem("m_iNoOfParition", pLayoutData.iNoOfParition);
    if (pLayoutData.pZoneRect.isNotEmpty) {
      XmlItem? xiZoneRect = pItem.addItem("m_pZoneRect");
      if (xiZoneRect != null) {
        int nZone = 0;
        for (var pRect in pLayoutData.pZoneRect) {
          XmlItem? xiZoneRectItem = xiZoneRect.addItem("ZoneRect");
          if (xiZoneRectItem != null) {
            xiZoneRectItem.addItem("left", pRect!.left);
            xiZoneRectItem.addItem("top", pRect.top);
            xiZoneRectItem.addItem("right", pRect.right);
            xiZoneRectItem.addItem("bottom", pRect.bottom);
          }

          switch (nZone) {
            case 0:
              pItem.addItem("m_iL1Left", pRect!.left);
              pItem.addItem("m_iL1Top", pRect.top);
              pItem.addItem("m_iL1Right", pRect.right);
              pItem.addItem("m_iL1Bottom", pRect.bottom);
              break;
            case 1:
              pItem.addItem("m_iL2Left", pRect!.left);
              pItem.addItem("m_iL2Top", pRect.top);
              pItem.addItem("m_iL2Right", pRect.right);
              pItem.addItem("m_iL2Bottom", pRect.bottom);
              break;
            case 2:
              pItem.addItem("m_iL3Left", pRect!.left);
              pItem.addItem("m_iL3Top", pRect.top);
              pItem.addItem("m_iL3Right", pRect.right);
              pItem.addItem("m_iL3Bottom", pRect.bottom);
              break;
            case 3:
              pItem.addItem("m_iL4Left", pRect!.left);
              pItem.addItem("m_iL4Top", pRect.top);
              pItem.addItem("m_iL4Right", pRect.right);
              pItem.addItem("m_iL4Bottom", pRect.bottom);
              break;
            case 4:
              pItem.addItem("m_iL5Left", pRect!.left);
              pItem.addItem("m_iL5Top", pRect.top);
              pItem.addItem("m_iL5Right", pRect.right);
              pItem.addItem("m_iL5Bottom", pRect.bottom);
              break;
            case 5:
              pItem.addItem("m_iL6Left", pRect!.left);
              pItem.addItem("m_iL6Top", pRect.top);
              pItem.addItem("m_iL6Right", pRect.right);
              pItem.addItem("m_iL6Bottom", pRect.bottom);
              break;
            case 6:
              pItem.addItem("m_iL7Left", pRect!.left);
              pItem.addItem("m_iL7Top", pRect.top);
              pItem.addItem("m_iL7Right", pRect.right);
              pItem.addItem("m_iL7Bottom", pRect.bottom);
              break;
            case 7:
              pItem.addItem("m_iL8Left", pRect!.left);
              pItem.addItem("m_iL8Top", pRect.top);
              pItem.addItem("m_iL8Right", pRect.right);
              pItem.addItem("m_iL8Bottom", pRect.bottom);
              break;
            case 8:
              pItem.addItem("m_iL9Left", pRect!.left);
              pItem.addItem("m_iL9Top", pRect.top);
              pItem.addItem("m_iL9Right", pRect.right);
              pItem.addItem("m_iL9Bottom", pRect.bottom);
              break;
            case 9:
              pItem.addItem("m_iL10Left", pRect!.left);
              pItem.addItem("m_iL10Top", pRect.top);
              pItem.addItem("m_iL10Right", pRect.right);
              pItem.addItem("m_iL10Bottom", pRect.bottom);
              break;
            case 10:
              pItem.addItem("m_iL11Left", pRect!.left);
              pItem.addItem("m_iL11Top", pRect.top);
              pItem.addItem("m_iL11Right", pRect.right);
              pItem.addItem("m_iL11Bottom", pRect.bottom);
              break;
            case 11:
              pItem.addItem("m_iL12Left", pRect!.left);
              pItem.addItem("m_iL12Top", pRect.top);
              pItem.addItem("m_iL12Right", pRect.right);
              pItem.addItem("m_iL12Bottom", pRect.bottom);
              break;
          }
          nZone++;
        }
      }
    }

    return true;
  }

  static LayoutData serializeLayoutFrom(XmlItem pItem) {
    LayoutData pLayoutData = LayoutData();
    pLayoutData.uiID = pItem.getItemValueI('m_uiID');
    pLayoutData.strLayoutName = pItem.getItemValue('m_strLayoutName');
    pLayoutData.strLayoutDesc = pItem.getItemValue('m_strLayoutDesc');
    pLayoutData.uiGroupID = pItem.getItemValueI('m_uiGroupID');
    pLayoutData.iNoOfParition = pItem.getItemValueI('m_iNoOfParition');
    pLayoutData.iScreenWidth = pItem.getItemValueI('m_iScreenWidth');
    pLayoutData.iScreenHeight = pItem.getItemValueI('m_iScreenHeight');
    pLayoutData.strImageFile = pItem.getItemValue('m_strImageFile');
    pLayoutData.pZoneRect.clear();
    XmlItem? xiZoneRect = pItem.getItem("m_pZoneRect");
    if (xiZoneRect != null) {
      XmlItem? pZoneRectItem = xiZoneRect.getItem("ZoneRect");
      int nZone = 0;
      while (pZoneRectItem != null) {
        pLayoutData.pZoneRect.add(Rect.fromLTRB(
            pZoneRectItem.getItemValueF("left"),
            pZoneRectItem.getItemValueF("top"),
            pZoneRectItem.getItemValueF("right"),
            pZoneRectItem.getItemValueF("bottom")));
        nZone++;
        if (nZone == pLayoutData.iNoOfParition) {
          break;
        }

        pZoneRectItem = pZoneRectItem.getSibling();
      }
    }

    if (pLayoutData.pZoneRect.isEmpty) {
      for (int nZone = 0; nZone < pLayoutData.iNoOfParition; nZone++) {
        int nLeft = 0;
        int nTop = 0;
        int nRight = 0;
        int nBottom = 0;
        switch (nZone) {
          case 0:
            nLeft = pItem.getItemValueI("m_iL1Left");
            nTop = pItem.getItemValueI("m_iL1Top");
            nRight = pItem.getItemValueI("m_iL1Right");
            nBottom = pItem.getItemValueI("m_iL1Bottom");
            break;
          case 1:
            nLeft = pItem.getItemValueI("m_iL2Left");
            nTop = pItem.getItemValueI("m_iL2Top");
            nRight = pItem.getItemValueI("m_iL2Right");
            nBottom = pItem.getItemValueI("m_iL2Bottom");
            break;
          case 2:
            nLeft = pItem.getItemValueI("m_iL3Left");
            nTop = pItem.getItemValueI("m_iL3Top");
            nRight = pItem.getItemValueI("m_iL3Right");
            nBottom = pItem.getItemValueI("m_iL3Bottom");
            break;
          case 3:
            nLeft = pItem.getItemValueI("m_iL4Left");
            nTop = pItem.getItemValueI("m_iL4Top");
            nRight = pItem.getItemValueI("m_iL4Right");
            nBottom = pItem.getItemValueI("m_iL4Bottom");
            break;
          case 4:
            nLeft = pItem.getItemValueI("m_iL5Left");
            nTop = pItem.getItemValueI("m_iL5Top");
            nRight = pItem.getItemValueI("m_iL5Right");
            nBottom = pItem.getItemValueI("m_iL5Bottom");
            break;
          case 5:
            nLeft = pItem.getItemValueI("m_iL6Left");
            nTop = pItem.getItemValueI("m_iL6Top");
            nRight = pItem.getItemValueI("m_iL6Right");
            nBottom = pItem.getItemValueI("m_iL6Bottom");
            break;
          case 6:
            nLeft = pItem.getItemValueI("m_iL7Left");
            nTop = pItem.getItemValueI("m_iL7Top");
            nRight = pItem.getItemValueI("m_iL7Right");
            nBottom = pItem.getItemValueI("m_iL7Bottom");
            break;
          case 7:
            nLeft = pItem.getItemValueI("m_iL8Left");
            nTop = pItem.getItemValueI("m_iL8Top");
            nRight = pItem.getItemValueI("m_iL8Right");
            nBottom = pItem.getItemValueI("m_iL8Bottom");
            break;
          case 8:
            nLeft = pItem.getItemValueI("m_iL9Left");
            nTop = pItem.getItemValueI("m_iL9Top");
            nRight = pItem.getItemValueI("m_iL9Right");
            nBottom = pItem.getItemValueI("m_iL9Bottom");
            break;
          case 9:
            nLeft = pItem.getItemValueI("m_iL10Left");
            nTop = pItem.getItemValueI("m_iL10Top");
            nRight = pItem.getItemValueI("m_iL10Right");
            nBottom = pItem.getItemValueI("m_iL10Bottom");
            break;
          case 10:
            nLeft = pItem.getItemValueI("m_iL11Left");
            nTop = pItem.getItemValueI("m_iL11Top");
            nRight = pItem.getItemValueI("m_iL11Right");
            nBottom = pItem.getItemValueI("m_iL11Bottom");
            break;
          case 11:
            nLeft = pItem.getItemValueI("m_iL12Left");
            nTop = pItem.getItemValueI("m_iL12Top");
            nRight = pItem.getItemValueI("m_iL12Right");
            nBottom = pItem.getItemValueI("m_iL12Bottom");
            break;
        }
        pLayoutData.pZoneRect.add(Rect.fromLTRB(nLeft.toDouble(),
            nTop.toDouble(), nRight.toDouble(), nBottom.toDouble()));
      }
    }

    return pLayoutData;
  }

  static ({bool status, double dbDuration}) calcDCMDuration(
      String szCatalogue, double dbDuration, double dbMax) {
    double dbTotal = dbDuration;
    DCMFileData? dcmFile =
        openCatalogue(catalogueName: szCatalogue, bShort: true);
    if (dcmFile != null && dcmFile.lstProduct != null) {
      Iterator it = dcmFile.lstProduct!.iterator;
      while (it.moveNext()) {
        ProductData pData = it.current;
        double dbProduct = Utils.getMaxDuration(pData);
        dbTotal += dbProduct;
        if ((dbTotal - dbMax).abs() < cPLAYINGINTERVAL) {
          dbDuration = dbTotal;
          return (status: true, dbDuration: dbDuration);
        } else if (dbTotal > dbMax) {
          if (!pData.hasContentType(cDIRECTPLAYTYPE) ||
              dcmFile.getZoneNumber() > 1) {
            dbDuration = dbTotal - dbProduct;
            return (status: true, dbDuration: dbDuration);
          } else {
            dbTotal = dbTotal - dbProduct;
            ContentListImpl contentlist = ContentListImpl(cDIRECTPLAYTYPE);
            ZoneData? pZoneData = pData.getZoneData(0);
            if (pZoneData != null) {
              String strFilePath =
                  Utils.getFilePath(pZoneData.strZoneFile, cDIRECTPLAYTYPE);
              contentlist.loadContentList(strFilePath);
              for (int i = 0; i < contentlist.lstProduct.length; i++) {
                //for (POSITION pos = ContentList.getProductData().lstProduct.getHeadPosition (); pos != null;)
                ProductData? pProduct = contentlist.getProductData(
                    nProduct: i +
                        1); //(ProductData*)(ContentList.lstProduct.getNext (pos));
                if (pProduct != null) {
                  if (!contentlist.isOutdated(pProduct)) {
                    double dbProduct1 = Utils.getMaxDuration(pProduct);
                    dbTotal += dbProduct1;
                    if ((dbTotal - dbMax).abs() < cPLAYINGINTERVAL) {
                      dbDuration = dbTotal;

                      return (status: true, dbDuration: dbDuration);
                    } else if (dbTotal > dbMax) {
                      dbDuration = dbTotal - dbProduct1;

                      return (status: true, dbDuration: dbDuration);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    dbDuration = dbTotal;

    return (status: false, dbDuration: dbDuration);
  }

  double getDCMTotalDuration(String strFile) {
    String strEdit = strFile;

    double dDuration = 0.00;

    XmlFilePro file = XmlFilePro("DCMDocument");
    if (file.open(strEdit, XfOpen.read)) {
      if (file.loadEx()) {
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == lpszSignature) {
          int nProduct = file.getItemValueI("m_nQuantity");
          List<ProductData> lstProduct = [];
          // get Product information list
          XmlItem? pItem = file.getItem("m_lstProduct");
          if (pItem != null) {
            XmlItem? pXISibling = pItem.getItem("CProductData");
            while (pXISibling != null) {
              ProductData pData = ProductData();

              // get Player channel Inforamtion data
              pData.getFromXML(pXISibling);

              // add Player Channel data to list
              lstProduct.add(pData);

              pXISibling = pXISibling.getSibling();
            }

            dDuration = getProductListDuration(lstProduct, nProduct);
          }
        }
      }
    }

    return dDuration;
  }

  static double getProductListDuration(List lstProduct, int nProduct) {
    double dDuration = 0.00;
    for (int i = 0; i < nProduct; i++) {
      ProductData? pData = getProductDataByIndex(lstProduct, i);
      if (pData != null) {
        dDuration += Utils.getMaxDuration(pData);
      }
    }

    return dDuration;
  }

  static ProductData? getProductDataByIndex(List lstProduct, int nIndex) {
    Iterator it = lstProduct.iterator;
    while (it.moveNext()) {
      ProductData product = it.current;
      if (product.uiID == nIndex) {
        return product;
      }
    }
    return null;
  }

  static List<ZoneData> getContents(String szCatalogue, int nType) {
    List<ZoneData> arrContents = [];
    DCMFileData? dcmFileData =
        DCMFileImpl.openCatalogue(catalogueName: szCatalogue, bShort: true);
    if (dcmFileData != null && dcmFileData.lstProduct != null) {
      for (var pData in dcmFileData.lstProduct!) {
        if (nType != cDIRECTPLAYTYPE) {
          var lstZone = pData.getContents(cDIRECTPLAYTYPE);
          for (var pZoneData in lstZone) {
            ContentListImpl contentList = ContentListImpl(cDIRECTPLAYTYPE);
            String strFilePath =
                Utils.getFilePath(pZoneData.strZoneFile, cDIRECTPLAYTYPE);
            contentList.loadContentList(strFilePath);
            for (int i = 0; i < contentList.lstProduct.length; i++) {
              ProductData? pProduct =
                  contentList.getProductData(nProduct: i + 1);

              if (pProduct != null) {
                if (!contentList.isOutdated(pProduct)) {
                  var lstZoneData = pProduct.getContents(nType);
                  if (lstZoneData.isNotEmpty) {
                    for (var pZoneData1 in lstZoneData) {
                      /*if (nType == cWEBPAGETYPE &&
                          AppGlobal.webView2Path.IsEmpty() &&
                          pZoneData1.strAudioDevice != "Google Chrome") {
                        continue;
                      }*/

                      arrContents.add(pZoneData1);
                    }
                  }
                }
              }
            }
          }
        }

        var lstZoneData = pData.getContents(nType);
        if (lstZoneData.isNotEmpty) {
          for (var pZoneData in lstZoneData) {
            /*if (nType == cWEBPAGETYPE &&
                AppGlobal.webView2Path.IsEmpty() &&
                pZoneData.strAudioDevice == "Google Chrome") {
              continue;
            }*/

            arrContents.add(pZoneData);
          }
        }
      }
    }

    return arrContents;
  }

  static Future<bool> addContent(DCMFileData pDCMFile, String strContent,
      [double? dbDuration]) async {
    int nContentType =
        App().contentTypeManager.getContentTypeByFileName(strContent);
    if (nContentType != -1) {
      int pType = -1;
      if (nContentType == cIMAGETYPE) {
        pType = cDCMSINGLEIMAGETYPE;
      }

      String strFileName = strContent;
      String strFilePath = Utils.getFilePath(strFileName, nContentType, pType);
      if (File(strFilePath).existsSync()) {
        ProductData pProduct = ProductData();
        pProduct.uiID = 0;
        pDCMFile.lstProduct!.add(pProduct);
        ZoneData pZoneData = ZoneData();
        pZoneData.uiID = 0;
        pProduct.lstZone.add(pZoneData);
        pZoneData.strZoneFile = strFileName;
        pZoneData.nZoneType = nContentType;
        if (dbDuration == null) {
          pZoneData.nZoneDuration = cDEFAULTDURATION;
          if (nContentType == cVIDEOTYPE) {
            pZoneData.nZoneDuration =
                await PlayerZoneImpl.getVideoDuration(strFilePath);
            pZoneData.bZoneRatio = false;
          }
        } else {
          pZoneData.nZoneDuration = dbDuration;
        }

        return true;
      }
    }

    return false;
  }
}
