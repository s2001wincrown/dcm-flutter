import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/xml_settings/contenttype_manager.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class Utils {
  static String getLatestFile(String strPath, [DateTime? dtToday]) {
    int nDay = 0;
    DateTime dtCurr = dtToday ?? DateTime.now();
    String strFilePath =
        path.join(strPath, DateFormat('yyyyMMdd').format(dtCurr));
    strFilePath += '.xml';
    if (!FileUtils.fileExistsSync(strFilePath)) {
      //String strLog;
      //strLog.Format('SitePlaylist: '%s' not found, try default playlist', strFilePath);
      //CAppSettings::LogMessage(0, strLog);
      String strDefaFilePath = path.join(strPath, 'Default.xml');
      if (FileUtils.fileExistsSync(strDefaFilePath)) {
        return strDefaFilePath;
      }
    }

    //String strLog;
    //strLog.Format('default SitePlaylist: '%s' not found, try latest playlist'), strFilePath);
    //CAppSettings::LogMessage(0, strLog);
    while (!FileUtils.fileExistsSync(strFilePath)) {
      if (nDay > 1000) {
        break;
      }

      nDay++;
      dtCurr = dtCurr.subtract(const Duration(days: 1));

      strFilePath = path.join(strPath, DateFormat('yyyyMMdd').format(dtCurr));
      strFilePath += '.xml';
    }

    return strFilePath;
  }

  static String getShortPath(String pszFileName,
      [int type = -1, int ptype = -1, String strRoot = '']) {
    String strSrc = '';
    if (type < 0) {
      type = ContentTypeManager.getContentTypeByFileName(pszFileName);
      if (type == cIMAGETYPE) {
        ptype = cDCMSINGLEIMAGETYPE;
      }
    }
    if (type != -1) {
      String strFilePath = pszFileName;
      if (type == cWEBPAGETYPE || type == cRSSTYPE) {
        if (strFilePath.startsWith(RegExp('HTTP://', caseSensitive: false)) ||
            strFilePath.startsWith(RegExp('HTTPS://', caseSensitive: false))) {
          return strFilePath;
        }
      }
      String strEventContentPath =
          strRoot.isEmpty ? getBasePath(type, ptype) : strRoot;
      strSrc = FileUtils.getShortPath(strFilePath, strEventContentPath);
    }

    return strSrc;
  }

  static String getFilePath(String strFileName, int type,
      [int ptype = -1, String? strCompany]) {
    if (strFileName.isEmpty) {
      return '';
    }
    String strXmlHeader = '<?xml version="1.0" encoding="UTF-8"?>';
    if (strFileName.startsWith(RegExp(strXmlHeader, caseSensitive: false))) {
      return strFileName;
    }

    int nPtype = ptype;
    String strExt = path.extension(strFileName).toUpperCase();
    if (type == cIMAGETYPE && (ptype == cDIRECTPLAYTYPE || ptype == -1)) {
      // && ptype == -1
      if (strExt.isNotEmpty && !strExt.equalsIgnoreCase('.XML')) {
        nPtype = cDCMSINGLEIMAGETYPE;
      }
    }

    String strFilePath = getBasePath(type, nPtype);
    String strName = strFileName;
    bool bExt = (strExt == '.XML');
    switch (type) {
      case cIMAGETYPE:
      case cCAROUSELTYPE:
        {
          if (nPtype == cDCMSINGLEIMAGETYPE ||
              ptype == cDDETYPE ||
              ptype == cSITEPLAYLIST) {
            // || ptype == cDIRECTPLAYTYPE || ptype == cSITEPLAYLIST
          } else {
            strName += (bExt ? '' : '.xml');
          }
        }
        break;

      case cVIDEOTYPE:
        if (strFileName.startsWith(RegExp('udp://', caseSensitive: false)) ||
            strFileName.startsWith(RegExp('rtp://', caseSensitive: false)) ||
            strFileName.startsWith(RegExp('rtsp://', caseSensitive: false)) ||
            strFileName.startsWith(RegExp('HTTP://', caseSensitive: false)) ||
            strFileName.startsWith(RegExp('HTTPS://', caseSensitive: false))) {
          return strFileName;
        }
      case cPOWERPOINTTYPE:
        break;
      case cTEXTTYPE:
      case cWEATHERTYPE:
      case cCLOCKTYPE:
        strName += (bExt ? '' : '.xml');
        break;
      case cEVENTTYPE:
        return strFileName;
      case cTVCAPTURETYPE:
      case cWEBCAMTYPE:
      case cSTREAMINGTYPE:
      case cONLINETYPE:
      case cNETWORKVIDEOTYPE:
        return strFileName;
      case cWEBPAGETYPE:
      case cRSSTYPE:
        {
          //String strPre = strFileName.Left(7);
          if (strFileName.startsWith(RegExp('HTTP://', caseSensitive: false)) ||
              strFileName
                  .startsWith(RegExp('HTTPS://', caseSensitive: false))) {
            return strFileName;
          } else {
            if (strCompany != null && strCompany.isNotEmpty) {
              strFilePath = path.join(strFilePath, strCompany);
            }
            strFilePath = path.join(strFilePath, strFileName);

            return strFilePath;
          }
        }
      case cQUEUETYPE:
        {
          if (strCompany != null && strCompany.isNotEmpty) {
            strFilePath = path.join(strFilePath, strCompany);
          }
          strFilePath = path.join(strFilePath, strFileName);
          return strFilePath;
        }
      case cFLASHTYPE:
        break;
      case cDDETYPE:
        {
          DateTime dtCurr = DateTime.now();
          if (strCompany != null && strCompany.isNotEmpty) {
            strFilePath = path.join(strFilePath, strCompany);
          }
          strFilePath = path.join(strFilePath, strFileName);
          String strDDEPath = strFilePath;
          strFilePath =
              path.join(strDDEPath, DateFormat('yyyyMMdd').format(dtCurr));
          strFilePath += '.xml';
          int nDay = 0;
          while (!FileUtils.fileExistsSync(strFilePath)) {
            if (nDay > 365) {
              break;
            }

            nDay++;
            dtCurr = dtCurr.subtract(const Duration(days: 1));

            strFilePath =
                path.join(strDDEPath, DateFormat('yyyyMMdd').format(dtCurr));
            strFilePath += '.xml';
          }

          return strFilePath;
        }
      case cDIRECTPLAYTYPE:
      case cLINKAGETYPE:
        strName += (bExt ? '' : '.xml');
        break;
      case cTHUMBVIEWTYPE:
        return 'Thumbnails';
      case cSITEPLAYLIST:
        {
          if (strCompany != null && strCompany.isNotEmpty) {
            strFilePath = path.join(strFilePath, strCompany);
          }
          if (strFileName.toLowerCase() != 'site playlist') {
            strFilePath = path.join(strFilePath, strFileName);
          }

          return getLatestFile(strFilePath);
        }
      default:
        strName = ContentTypeManager.fixContentFileName(strName, type);
        break;
      //return strFileName;
    }

    if (strCompany != null && strCompany.isNotEmpty) {
      strFilePath = path.join(strFilePath, strCompany);
    }
    strFilePath = path.join(strFilePath, strName);

    return strFilePath;
  }

  static String getBasePath(int type, [int ptype = -1]) {
    if (ptype == cSITEPLAYLIST) {
      return DCMGlobal.siteContentPath;
    } else if (ptype == cDDETYPE) {
      return DCMGlobal.ddeDataPath;
    } else {
      switch (type) {
        case cIMAGETYPE:
        case cCAROUSELTYPE:
          if (ptype == cDCMSINGLEIMAGETYPE) // || ptype == cDIRECTPLAYTYPE
          {
            return DCMGlobal.imagePath;
          } else {
            return DCMGlobal.imageSettingPath;
          }
        case cVIDEOTYPE:
          return DCMGlobal.vcdPath;
        case cPOWERPOINTTYPE:
          return DCMGlobal.ppPath;
        case cTEXTTYPE:
          return DCMGlobal.textPath;
        case cWEATHERTYPE:
          return DCMGlobal.weatherPath;
        case cCLOCKTYPE:
          return DCMGlobal.clockPath;
        case cEVENTTYPE:
          return DCMGlobal.flashPath;
        case cWEBPAGETYPE:
          return DCMGlobal.webPath;
        case cQUEUETYPE:
          return DCMGlobal.webPath;
        case cFLASHTYPE:
          return DCMGlobal.flashPath;
        case cDDETYPE:
          return DCMGlobal.ddeDataPath;
        case cDIRECTPLAYTYPE:
          return DCMGlobal.contentListPath;
        case cLINKAGETYPE:
          return DCMGlobal.linkagePath;
        case cDCMMONTHTYPE:
          return DCMGlobal.monthPath;
        case cDCMCALENDARTYPE:
          return DCMGlobal.calendarPath;
        case cDCMDAYTYPE:
          return DCMGlobal.dayPath;
        case cDCMAHPLAYLISTTYPE:
          return DCMGlobal.ahPlaylistPath;
        case cDCMFILETYPE:
          return DCMGlobal.openPath;
        case cDCMSETTINGTYPE:
          return DCMGlobal.settingPath;
        case cDCMLAYOUTTYPE:
          return DCMGlobal.layoutImagePath;
        case cDCMGRAPHICSTYPE:
          return DCMGlobal.graphicsPath;
        case cDCMSKINSTYPE:
          return DCMGlobal.skinsPath;
        case cDCMAHMESSAGETYPE:
          return DCMGlobal.messagePath;
        case cDCMDDEOTHERTYPE:
          return DCMGlobal.ddeOthersPath;
        case cDCMCONTENTLISTDATATYPE:
          return DCMGlobal.ddeDataPath;
        case cDCMPREDATATYPE:
          return DCMGlobal.preDataPath;
        case cDCMSINGLEIMAGETYPE:
          return DCMGlobal.imagePath;
        //for Event system - room event
        case cDCMROOMTYPE:
          return DCMGlobal.roomPath;
        case cDCMROOMEVENTTYPE:
          return DCMGlobal.roomEventPath;
        case cDCMLOBBYTYPE:
          return DCMGlobal.lobbyPath;
        case cDCMDYNAMICDATATYPE:
          return DCMGlobal.dynamicDataPath;
        case cDCMRLTCONTENTTYPE:
          return DCMGlobal.rltContentPath;
        case cDCMSITEDATATYPE:
          return DCMGlobal.siteContentPath;
        case cSITEPLAYLIST:
          return path.join(DCMGlobal.siteContentPath, 'SitePlaylist');
        case cDCMUPDATETYPE:
          return path.join(DCMGlobal.updateFilePath, 'APUpdate');
        default:
          return path.join(DCMGlobal.cscPath, defaultDataPath);
      }
    }
  }

  static double getDCMTotalDuration(String strFile) {
    String strEdit = strFile;

    double dDuration = 0.00;

    XmlFilePro file = XmlFilePro('DCMDocument', Encodes.cDCMFILECRYPTKEY);
    if (file.open(strEdit, XfOpen.read, false)) {
      if (file.loadEx()) {
        if (file.decrypt()) {
          // file header info
          String sXmlHeader = file.getSignature();
          if (sXmlHeader == DCMFileImpl.lpszSignature) {
            int nProduct = file.getItemValueI('m_nQuantity');
            List<ProductData> lstProduct = [];
            // get Product information list
            XmlItem? pItem = file.getItem('m_lstProduct');
            if (pItem != null) {
              XmlItem? pXISibling = pItem.getItem('CProductData');
              while (pXISibling != null) {
                ProductData pData = ProductData();

                // get Player channel Inforamtion data
                pData.getFromXML(pXISibling);

                // add Player Channel data to list
                lstProduct.add(pData);

                pXISibling = pXISibling.getSibling();
              }
            }
            dDuration = getProductListDuration(lstProduct, nProduct);
          }
        }
      }
    }

    return dDuration;
  }

  static double getProductListDuration(
      List<ProductData> lstProduct, int nProduct) {
    double dDuration = 0.00;
    for (int i = 0; i < nProduct; i++) {
      ProductData? pData = getProductDataByIndex(lstProduct, i);
      if (pData != null) {
        dDuration += getMaxDuration(pData);
      }
    }

    return dDuration;
  }

  static ProductData? getProductDataByIndex(
      List<ProductData> lstProduct, int nIndex) {
    ProductData? pData;
    for (var productData in lstProduct) {
      if (productData.uiID == nIndex) {
        pData = productData;
        break;
      }
    }
    return pData;
  }

  static double getMaxDuration(ProductData? pProductData) {
    if (pProductData == null) {
      return 0.00;
    }

    double rtDuration = 0.00;
    for (var zoneData in pProductData.lstZone) {
      double dbZoneDuration = zoneData.nZoneDuration;
      if (dbZoneDuration > rtDuration) {
        rtDuration = dbZoneDuration; //pData->m_nZoneDuration;
      }
    }

    return rtDuration;
  }

  static double calcItemDuration(EventItemData pData, double dbDuration) {
    double dbTotal = 0;
    if (pData.arrDCMFile != null && pData.arrDCMFile!.isNotEmpty) {
      for (int i = 0; i < pData.arrDCMFile!.length; i++) {
        var result = DCMFileImpl.calcDCMDuration(
            pData.arrDCMFile![i], dbTotal, dbDuration);
        if (result.status) {
          return result.dbDuration;
        }
      }
    } else {
      dbTotal =
          DCMFileImpl.calcDCMDuration(pData.strDCMFile, dbTotal, dbDuration)
              .dbDuration;
    }

    return dbTotal;
  }

  /// Win32 SubtractRect 函数的 Dart 实现
  ///
  /// 此函数仅在矩形在x方向或y方向完全相交时从 lprcSrc1 中减去 lprcSrc2。
  /// 它返回的是几何差集的边界框，而不是真正的差集。
  ///
  /// 参数:
  ///   lprcDst - 输出参数，接收结果矩形
  ///   lprcSrc1 - 第一个矩形（被减数）
  ///   lprcSrc2 - 第二个矩形（减数）
  ///
  /// 返回:
  ///   如果结果矩形非空则返回 true，否则返回 false
  static bool subtractRect(Rect lprcDst, Rect lprcSrc1, Rect lprcSrc2) {
    // 如果两个矩形不相交，则结果是 lprcSrc1
    if (!lprcSrc1.overlaps(lprcSrc2)) {
      lprcDst = Rect.fromLTRB(
          lprcSrc1.left, lprcSrc1.top, lprcSrc1.right, lprcSrc1.bottom);
      return !lprcDst.isEmpty;
    }

    // 检查是否在x方向完全相交
    bool xIntersectComplete =
        lprcSrc1.left <= lprcSrc2.left && lprcSrc2.right <= lprcSrc1.right;
    // 检查是否在y方向完全相交
    bool yIntersectComplete =
        lprcSrc1.top <= lprcSrc2.top && lprcSrc2.bottom <= lprcSrc1.bottom;

    // 如果两个矩形相交但不是在x或y方向完全相交，则结果是 lprcSrc1
    if (!xIntersectComplete && !yIntersectComplete) {
      lprcDst = Rect.fromLTRB(
          lprcSrc1.left, lprcSrc1.top, lprcSrc1.right, lprcSrc1.bottom);
      return !lprcDst.isEmpty;
    }

    // 如果在x方向完全相交，计算y方向的差集
    if (xIntersectComplete) {
      // 如果 lprcSrc2 在 lprcSrc1 的上方
      if (lprcSrc2.top <= lprcSrc1.top && lprcSrc2.bottom >= lprcSrc1.bottom) {
        // lprcSrc2 完全覆盖 lprcSrc1，结果为空
        lprcDst = Rect.zero;
        return false;
      } else if (lprcSrc2.top <= lprcSrc1.top) {
        // lprcSrc2 在 lprcSrc1 的上方部分重叠，结果是下方部分
        lprcDst = Rect.fromLTRB(
            lprcSrc1.left, lprcSrc2.bottom, lprcSrc1.right, lprcSrc1.bottom);
      } else if (lprcSrc2.bottom >= lprcSrc1.bottom) {
        // lprcSrc2 在 lprcSrc1 的下方部分重叠，结果是上方部分
        lprcDst = Rect.fromLTRB(
            lprcSrc1.left, lprcSrc1.top, lprcSrc1.right, lprcSrc2.top);
      } else {
        // lprcSrc2 在 lprcSrc1 内部，结果是上方部分
        lprcDst = Rect.fromLTRB(
            lprcSrc1.left, lprcSrc1.top, lprcSrc1.right, lprcSrc2.top);
      }
    }
    // 如果在y方向完全相交，计算x方向的差集
    else if (yIntersectComplete) {
      // 如果 lprcSrc2 在 lprcSrc1 的左侧
      if (lprcSrc2.left <= lprcSrc1.left && lprcSrc2.right >= lprcSrc1.right) {
        // lprcSrc2 完全覆盖 lprcSrc1，结果为空
        lprcDst = Rect.zero;
        return false;
      } else if (lprcSrc2.left <= lprcSrc1.left) {
        // lprcSrc2 在 lprcSrc1 的左侧部分重叠，结果是右侧部分
        lprcDst = Rect.fromLTRB(
            lprcSrc2.right, lprcSrc1.top, lprcSrc1.right, lprcSrc1.bottom);
      } else if (lprcSrc2.right >= lprcSrc1.right) {
        // lprcSrc2 在 lprcSrc1 的右侧部分重叠，结果是左侧部分
        lprcDst = Rect.fromLTRB(
            lprcSrc1.left, lprcSrc1.top, lprcSrc2.left, lprcSrc1.bottom);
      } else {
        // lprcSrc2 在 lprcSrc1 内部，结果是左侧部分
        lprcDst = Rect.fromLTRB(
            lprcSrc1.left, lprcSrc1.top, lprcSrc2.left, lprcSrc1.bottom);
      }
    }

    return !lprcDst.isEmpty;
  }

  ///检查string是否为URL。
  static bool isURL(String s) => hasMatch(s,
      r"^((((H|h)(T|t)|(F|f))(T|t)(P|p)((S|s)?))://)?(www.|[a-zA-Z0-9].)[a-zA-Z0-9-.]+.[a-zA-Z]{2,6}(:[0-9]{1,5})*(/($|[a-zA-Z0-9.,;?'\+&amp;%$#=~_-]+))*$");

  ///检查字符串是否为email。
  static bool isEmail(String s) => hasMatch(s,
      r'^(([^<>()[]\.,;:\s@"]+(.[^<>()[]\.,;:\s@"]+)*)|(".+"))@(([[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}])|(([a-zA-Z-0-9]+.)+[a-zA-Z]{2,}))$');

  ///检查字符串是否为电话号码。
  static bool isPhoneNumber(String s) {
    if (s.length > 16 || s.length < 9) return false;
    return hasMatch(s, r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s./0-9]*$');
  }

  ///检查string是否为DateTime (UTC或Iso8601)。
  static bool isDateTime(String s) =>
      hasMatch(s, r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}.\d{3}Z?$');

  static bool hasMatch(String? value, String pattern) {
    return (value == null) ? false : RegExp(pattern).hasMatch(value);
  }
}
