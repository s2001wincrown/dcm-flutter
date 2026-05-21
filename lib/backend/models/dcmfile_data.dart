// dcmfile_data.dart : implementation of the CDCMFileData class
//
// CDCMFileData

import 'dart:core';
import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';

/////////////////////////////////////////////////////////////////////////////
// CDCMFileData construction/destruction
class DCMFileData {
  String? strDocVersion;

  int uiID = 0;

  int nSkin = 0;
  String strBtnLng = 'ENG'; //Product button default language
  int nBtnAlign = 0; //Product button align(bottom or right)
  int nBtnStyle = 0; //Product button style(Image+text, image, text)
  int nScreenType = 0; //Screen type(16:9 or 4:3)
  int nFontSize =
      0; //Product button text font size(if button style is image+text or text)
  int nQuantity = 0; //Product quantity
  int nBGType = 0;

  int crFontColor = 0;
  int crBGColor = 0;

  bool bFontUnderline =
      false; //Product button text font underline or not(if button style is image+text or text)
  bool bFontItalic =
      false; //Product button text font italic or not(if button style is image+text or text)
  bool bFontBold =
      false; //Product button text font Bold or not(if button style is image+text or text)
  bool bBGMusic = false; //Backgroup Music
  bool bInteractive = false; //Interactvie

  String strFontName =
      'Arial'; ////Product button text font name(if button style is image+text or text)
  String strLayoutName = '';
  String strSkinCode = '';
  String strMusicFile = '';
  String strImageFile = '';

  LayoutData?
      pLayoutDataObj; //Layout data object(CLayoutData) for layout define.
  List<ProductData>? lstProduct; //List for product data object

  String strCatalogueName = '';
  String strCatalogueDesc = '';
  String strUserCode = '';
  String strGroupCode = '';
  DateTime? dtModified;
  DateTime? dtCreated;

  DCMFileData() {
    pLayoutDataObj = null;
    initDocument();
  }

  /////////////////////////////////////////////////////////////////////////////
  // CDCMFileData serialization
  void validProductZone() {
    if (lstProduct == null) return;
    var it = lstProduct!.iterator;
    while (it.moveNext()) {
      ProductData product = it.current;
      product.validZoneData(getZoneNumber());
    }
  }

  int getProductCount() {
    if (lstProduct != null) {
      return lstProduct!.length;
    }

    return 0;
  }

  int getZoneNumber() {
    if (pLayoutDataObj == null) {
      return 0;
    }
    return (pLayoutDataObj!.iNoOfParition < 0)
        ? 0
        : pLayoutDataObj!.iNoOfParition;
  }

  List getDDEList() {
    List<String> arrDDE = [];
    if (lstProduct == null) return arrDDE;
    var it = lstProduct!.iterator;
    while (it.moveNext()) {
      ProductData product = it.current;
      var itZone = product.lstZone.iterator;
      while (itZone.moveNext()) {
        ZoneData zone = itZone.current;
        if (zone.nZoneType == cDDETYPE || zone.nZoneType == cDIRECTPLAYTYPE) {
          String strDDE = zone.strZoneFile;
          if (arrDDE.contains(strDDE)) {
            arrDDE.add(strDDE);
          }
        }
      }
    }

    return arrDDE;
  }

  void addProduct(ProductData product) {
    lstProduct ??= [];
    lstProduct!.add(product);
  }

  void addProductList(
      int nIndex, List arrProdName, String strDesc, String strImage,
      [String? strProdEvent]) {
    ProductData? pData = getProductDataByIndex(nIndex);
    int i;
    if (pData == null) {
      pData = ProductData();

      lstProduct!.add(pData);
    }
    /*for(i=0; i<(int)arrProdName.size(); i++)
		{
			pData.AddProductName(arrProdName.get(i), i);
		}*/
    pData.strProductDesc = strDesc;
    pData.strImgFile = strImage;
    pData.uiID = nIndex;
    pData.strBtnEvent = strProdEvent ?? '';
  }

  ProductData? getProductDataByIndex(int nIndex) {
    if (lstProduct != null) {
      Iterator it = lstProduct!.iterator;
      while (it.moveNext()) {
        ProductData product = it.current;
        if (product.uiID == nIndex) {
          //pData.InitZoneList(GetZoneNumber());
          return product;
        }
      }
    }
    return null;
  }

  void removeProductDataByIndex(int nIndex) {
    if (lstProduct != null) {
      Iterator it = lstProduct!.iterator;
      while (it.moveNext()) {
        ProductData product = it.current;
        if (product.uiID == nIndex) {
          lstProduct!.remove(product);
          break;
        }
      }
    }
  }

  int getTextZone() {
    return 0;
  }

  Rect getLayoutSize() {
    if (pLayoutDataObj == null) {
      return Rect.zero;
    }

    return Rect.fromLTWH(0, 0, pLayoutDataObj!.iScreenWidth.toDouble(),
        pLayoutDataObj!.iScreenHeight.toDouble());
  }

  bool getVideoWindowRect(Rect rectVW) {
    if (pLayoutDataObj == null) {
      return false;
    }

    double nVWWidth;
    double nVWHeight;
    double nScreenWidth = pLayoutDataObj!.iScreenWidth.toDouble();
    double nScreenHeight = pLayoutDataObj!.iScreenHeight.toDouble();
    double nHeight = rectVW.height;
    double nWidth = rectVW.width;
    if ((nWidth / nHeight) > (nScreenWidth / nScreenHeight)) {
      nVWWidth = rectVW.height * nScreenWidth / nScreenHeight;
      nVWHeight = rectVW.height;
    } else {
      nVWWidth = rectVW.width;
      nVWHeight = rectVW.width * nScreenHeight / nScreenWidth;
    }
    rectVW = Rect.fromLTWH(0, 0, nVWWidth, nVWHeight);

    return true;
  }

  Rect? getZoneRect(int nZone, Rect rectVW) {
    if (pLayoutDataObj == null) {
      return null;
    }

    double nLeft = 0;
    double nTop = 0;
    double nRight = 0;
    double nBottom = 0;
    Rect? pRect = pLayoutDataObj!.getZoneRect(nZone);
    if (pRect != null) {
      nLeft = pRect.left;
      nTop = pRect.top;
      nRight = pRect.right;
      nBottom = pRect.bottom;
    }

    int nScreenWidth = pLayoutDataObj!.iScreenWidth;
    int nScreenHeight = pLayoutDataObj!.iScreenHeight;
    double nHeight = rectVW.height;
    double nWidth = rectVW.width;
    nLeft = rectVW.left + nLeft * nWidth / nScreenWidth;
    nTop = rectVW.top + nTop * nHeight / nScreenHeight;
    nRight = rectVW.left + nRight * nWidth / nScreenWidth;
    nBottom = rectVW.top + nBottom * nHeight / nScreenHeight;
    Rect rcZone = Rect.fromLTRB(nLeft, nTop, nRight, nBottom);

    return rcZone;
  }

  void initDocument() {
    strDocVersion = '4.0';
    nQuantity = 1;
    nScreenType = 0;
    nBGType = 0;
    strLayoutName = '';
    strFontName = 'Arial';
    strMusicFile = '';
    strImageFile = '';
    crBGColor = 0;
    nFontSize = 160;
    bFontBold = false;
    bFontItalic = false;
    bFontUnderline = false;
    bBGMusic = false;
    crFontColor = 0;
    strBtnLng = 'ENG';
    nBtnAlign = -1;
    nBtnStyle = 0;
    strSkinCode = '';
    nSkin = 0;
    bInteractive = false;
    strCatalogueName = '';
    strCatalogueDesc = '';
    strUserCode = '';
    strGroupCode = '';
    dtCreated = DateTime.now();
    dtModified = DateTime.now();

    clearDataObj();
  }

  void clearDataObj() {
    pLayoutDataObj = null;
    if (lstProduct != null) lstProduct!.clear();
  }

  bool hasProductDataByIndex(int nIndex) {
    if (lstProduct == null) return false;
    Iterator it = lstProduct!.iterator;
    while (it.moveNext()) {
      ProductData product = it.current;
      if (product.uiID == nIndex) {
        return true;
      }
    }

    return false;
  }

  bool sameAsPrevContent(ZoneData pZoneData, int nProduct) {
    if (nProduct < 0) {
      return false;
    }

    ProductData? pProductData = getProductDataByIndex(nProduct);
    if (pProductData != null) {
      ZoneData? pNewZoneData = pProductData!.getZoneData(pZoneData.nZoneID);
      if (pNewZoneData != null) {
        return (pNewZoneData.nZoneType == pZoneData.nZoneType &&
            pNewZoneData.strZoneFile == pZoneData.strZoneFile);
      }
    }

    return false;
  }

  void addZoneRect(Rect rect, int nIndex) {}

  int invalidProduct() {
    int nCount = 0;
    int nProduct = 0;
    Iterator it = lstProduct!.iterator;
    while (it.moveNext()) {
      ProductData product = it.current;
      if (!product.isAllSetting()) {
        nCount++;
      }

      nProduct++;
      if (nProduct == nQuantity) {
        break;
      }
    }

    return nCount;
  }

  bool hasContentType([int nContentType = cPLUGINTYPE]) {
    if (lstProduct != null) {
      if (lstProduct!.isEmpty) {
        return false;
      } else {
        Iterator it = lstProduct!.iterator;
        while (it.moveNext()) {
          ProductData product = it.current;
          Iterator itZone = product.lstZone.iterator;
          while (itZone.moveNext()) {
            ZoneData zone = itZone.current;
            if (zone.nZoneType == nContentType) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool hasPowerPoint(int nIndex) {
    if (lstProduct == null) return false;
    if (lstProduct!.isEmpty) {
      return false;
    } else {
      Iterator it = lstProduct!.iterator;
      while (it.moveNext()) {
        ProductData product = it.current;
        if (product.uiID == nIndex) {
          Iterator itZone = product.lstZone.iterator;
          while (itZone.moveNext()) {
            ZoneData zone = itZone.current;
            if (zone.nZoneType == cPOWERPOINTTYPE) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool isPlayContinue(int nIndex, bool bMulti) {
    if (lstProduct == null) return false;
    if ((nIndex > lstProduct!.length - 1) && bMulti) {
      return false;
    } else {
      int productID = nIndex;
      if (nIndex > lstProduct!.length - 1) {
        productID = 0;
      }
      bool bIsContinue = false;
      Iterator it = lstProduct!.iterator;
      while (it.moveNext()) {
        ProductData product = it.current;
        if (product.uiID == productID) {
          Iterator itZone = product.lstZone.iterator;
          while (itZone.moveNext()) {
            ZoneData zone = itZone.current;
            if (zone.bChkZone) {
              bIsContinue = true;
              break;
            }
          }
          break;
        }
      }
      return bIsContinue;
    }
  }

  bool canPlay() {
    if (lstProduct == null || lstProduct!.isEmpty) {
      return false;
    } else {
      bool bIsEmpty = true;
      var it = lstProduct!.iterator;
      while (it.moveNext()) {
        ProductData product = it.current;
        if (product.isValidForPlay()) {
          bIsEmpty = false;
          break;
        }
      }
      if (bIsEmpty) {
        return false;
      }
    }

    if (strLayoutName.isEmpty) {
      return false;
    }
    if (nQuantity == 0) {
      return false;
    }

    return true;
  }
}
