import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xml_settings/contenttype_manager.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xml_settings/eventfile_impl.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:unique_device_identifier/unique_device_identifier.dart';

class Utils {
  static int osVersion = -1;
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
      type = App().contentTypeManager.getContentTypeByFileName(pszFileName);
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
          strRoot.isEmpty ? getBasePath(type, ptype: ptype) : strRoot;
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

    String strFilePath = getBasePath(type, ptype: nPtype);
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
        strName = App().contentTypeManager.fixContentFileName(strName, type);
        break;
      //return strFileName;
    }

    if (strCompany != null && strCompany.isNotEmpty) {
      strFilePath = path.join(strFilePath, strCompany);
    }
    strFilePath = path.join(strFilePath, strName);

    return strFilePath;
  }

  static String getBasePath(int type, {int ptype = -1}) {
    String basePath;
    if (ptype == cSITEPLAYLIST) {
      basePath = DCMGlobal.siteContentPath;
    } else if (ptype == cDDETYPE) {
      basePath = DCMGlobal.ddeDataPath;
    } else {
      switch (type) {
        case cIMAGETYPE:
        case cCAROUSELTYPE:
          if (ptype == cDCMSINGLEIMAGETYPE) {
            // || ptype == cDIRECTPLAYTYPE
            basePath = DCMGlobal.imagePath;
          } else {
            basePath = DCMGlobal.imageSettingPath;
          }
          break;
        case cVIDEOTYPE:
          basePath = DCMGlobal.vcdPath;
          break;
        case cPOWERPOINTTYPE:
          basePath = DCMGlobal.ppPath;
          break;
        case cTEXTTYPE:
          basePath = DCMGlobal.textPath;
          break;
        case cWEATHERTYPE:
          basePath = DCMGlobal.weatherPath;
          break;
        case cCLOCKTYPE:
          basePath = DCMGlobal.clockPath;
          break;
        case cEVENTTYPE:
          basePath = DCMGlobal.flashPath;
          break;
        case cWEBPAGETYPE:
          basePath = DCMGlobal.webPath;
          break;
        case cQUEUETYPE:
          basePath = DCMGlobal.webPath;
          break;
        case cFLASHTYPE:
          basePath = DCMGlobal.flashPath;
          break;
        case cDDETYPE:
          basePath = DCMGlobal.ddeDataPath;
          break;
        case cDIRECTPLAYTYPE:
          basePath = DCMGlobal.contentListPath;
          break;
        case cLINKAGETYPE:
          basePath = DCMGlobal.linkagePath;
          break;
        case cDCMMONTHTYPE:
          basePath = DCMGlobal.monthPath;
          break;
        case cDCMCALENDARTYPE:
          basePath = DCMGlobal.calendarPath;
          break;
        case cDCMDAYTYPE:
          basePath = DCMGlobal.dayPath;
          break;
        case cDCMAHPLAYLISTTYPE:
          basePath = DCMGlobal.ahPlaylistPath;
          break;
        case cDCMFILETYPE:
          basePath = DCMGlobal.openPath;
          break;
        case cDCMSETTINGTYPE:
          basePath = DCMGlobal.settingPath;
          break;
        case cDCMLAYOUTTYPE:
          basePath = DCMGlobal.layoutImagePath;
          break;
        case cDCMGRAPHICSTYPE:
          basePath = DCMGlobal.graphicsPath;
          break;
        case cDCMSKINSTYPE:
          basePath = DCMGlobal.skinsPath;
          break;
        case cDCMAHMESSAGETYPE:
          basePath = DCMGlobal.messagePath;
          break;
        case cDCMDDEOTHERTYPE:
          basePath = DCMGlobal.ddeOthersPath;
          break;
        case cDCMCONTENTLISTDATATYPE:
          basePath = DCMGlobal.ddeDataPath;
          break;
        case cDCMPREDATATYPE:
          basePath = DCMGlobal.preDataPath;
          break;
        case cDCMSINGLEIMAGETYPE:
          basePath = DCMGlobal.imagePath;
          break;
        //for Event system - room event
        case cDCMROOMTYPE:
          basePath = DCMGlobal.roomPath;
          break;
        case cDCMROOMEVENTTYPE:
          basePath = DCMGlobal.roomEventPath;
          break;
        case cDCMLOBBYTYPE:
          basePath = DCMGlobal.lobbyPath;
          break;
        case cDCMDYNAMICDATATYPE:
          basePath = DCMGlobal.dynamicDataPath;
          break;
        case cDCMRLTCONTENTTYPE:
          basePath = DCMGlobal.rltContentPath;
          break;
        case cDCMSITEDATATYPE:
          basePath = DCMGlobal.siteContentPath;
          break;
        case cSITEPLAYLIST:
          basePath = path.join(DCMGlobal.siteContentPath, 'SitePlaylist');
          break;
        case cDCMUPDATETYPE:
          basePath = path.join(DCMGlobal.updateFilePath, 'APUpdate');
          break;
        default:
          basePath = path.join(DCMGlobal.cscPath, defaultDataPath);
      }
    }

    return basePath;
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

  static bool isValidIPAddress(String ip) {
    if (ip.isEmpty) return false;
    try {
      // InternetAddress 会自动识别 IPv4 和 IPv6
      InternetAddress(ip);
      return true;
    } on SocketException {
      return false;
    } catch (e) {
      return false;
    }
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

  static bool isValidUuid(String? value) {
    if (value == null) return false;
    // 标准的 UUID v4 正则表达式
    final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false);
    return regex.hasMatch(value);
  }

  static bool hasMatch(String? value, String pattern) {
    return (value == null) ? false : RegExp(pattern).hasMatch(value);
  }

  static Color fromRGB(int color) {
    return Color.fromARGB(
        255, (color >> 16) & 0xFF, (color >> 8) & 0xFF, (color >> 0) & 0xFF);
  }

  static Future<String?> getUniqueKey() async {
    String? udid;
    try {
      udid = await FlutterUdid.udid;
    } on PlatformException {
      logE('FlutterUdid: Failed to get UDID.');
    }
    if (udid == null || udid.isEmpty) {
      try {
        udid = await UniqueDeviceIdentifier.getUniqueIdentifier();
      } catch (e) {
        logE('UniqueDeviceIdentifier: Failed to get UDID. Error: $e');
      }
    }

    return udid?.trim();
  }

  static String urlEscape(String csURL) {
    csURL = csURL.replaceAll(' ', '+');
    csURL = csURL.replaceAll('[', '%5B');
    csURL = csURL.replaceAll(']', '%5D');
    csURL = csURL.replaceAll('"', '%22');

    return csURL;
  }

  static String addCMSParam(String strCMSLink, [bool bAddTokenOnly = false]) {
    String cmsParam = '';
    if (!bAddTokenOnly && DCMGlobal.organization.isNotEmpty) {
      cmsParam += 'o=${DCMGlobal.organization}';
    }
    if (DCMGlobal.cmsToken.isNotEmpty) {
      //authentication-token
      cmsParam += '&authentication-token=${DCMGlobal.cmsToken}';
      //strCMSLink += (strCMSLink.Find('?') != -1 ? '&authentication-token=' : '?authentication-token=');
      //strCMSLink += Settings.CMSToken;
    }
    if (cmsParam.isNotEmpty) {
      strCMSLink += (strCMSLink.contains('?') ? '&' : '?');
      strCMSLink += cmsParam;
    }

    return strCMSLink;
  }

  static String apiBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '';
    }
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String apiPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '';
    }
    return uri.path.isEmpty ? '/' : uri.path;
  }

  static String getImportVersion() {
    logI('Checking for USB plugin');
    return '';
  }

  static Future<int> getOSVersion() async {
    if (osVersion > 0) return osVersion;

    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      // Web 平台
      final webInfo = await deviceInfo.webBrowserInfo;
      logI('Web Browser: ${webInfo.browserName}');
      logI('User Agent: ${webInfo.userAgent}');
      // Web 平台通常无法直接获取宿主 OS 版本，只能获取浏览器信息
    } else if (Platform.isAndroid) {
      // Android 平台
      final androidInfo = await deviceInfo.androidInfo;
      logI('Android SDK Version: ${androidInfo.version.sdkInt}');
      logI(
          'Android Release Version: ${androidInfo.version.release}'); // 例如 "13"
      osVersion = int.tryParse(androidInfo.version.release) ?? -1;
    } else if (Platform.isIOS) {
      // iOS 平台
      final iosInfo = await deviceInfo.iosInfo;
      logI('iOS System Version: ${iosInfo.systemVersion}'); // 例如 "16.4"
      osVersion = int.tryParse(iosInfo.systemVersion) ?? -1;
      for (var match in RegExp(r'\d+').allMatches(iosInfo.systemVersion)) {
        osVersion = int.tryParse(match.group(0)!) ?? -1;
        break;
      }
    } else if (Platform.isMacOS) {
      // macOS 平台
      final macOsInfo = await deviceInfo.macOsInfo;
      logI('macOS Version: ${macOsInfo.osRelease}'); // 例如 "13.3.1"
      osVersion = macOsInfo.majorVersion;
    } else if (Platform.isWindows) {
      // Windows 平台
      final windowsInfo = await deviceInfo.windowsInfo;
      logI('Windows Version: ${windowsInfo.buildNumber}'); // 例如 "19045"
      osVersion = windowsInfo.majorVersion;
    } else if (Platform.isLinux) {
      // Linux 平台
      final linuxInfo = await deviceInfo.linuxInfo;
      logI(
          'Linux Version: ${linuxInfo.version}'); // 例如 "22.04.2 LTS (Jammy Jellyfish)"
      if (linuxInfo.version != null) {
        for (var match in RegExp(r'\d+').allMatches(linuxInfo.version!)) {
          osVersion = int.tryParse(match.group(0)!) ?? -1;
          break;
        }
      }
    }

    return osVersion;
  }

  static Future<({String strVerInfo, String strPlaylistVersion})>
      uploadVersionInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String strFTPVersion = packageInfo.version;
    String strDCMVersion = packageInfo.version;

    String strCurrMonth = DateFormat('yyyyMM').format(DateTime.now());
    String strPlaylist = '';

    String strVerInfo = '';
    String strPlaylistVersion = '';
    String strFileName1 = path.join(DCMGlobal.monthPath, '$strCurrMonth.xml');
    if (await File(strFileName1).exists()) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName1);
      if (xmlProfile.loadProfile()) {
        int nToday = DateTime.now().day;
        var lstDayInfo = DayInfoData.readDayInfoList(xmlProfile);
        for (var iter in lstDayInfo) {
          DayInfoData pData = iter;
          if (pData.day == nToday) {
            if (pData.arrEvent.isNotEmpty) {
              strPlaylist = pData.arrEvent[0].value;
            } else {
              strPlaylist = pData.event;
            }
            break;
          }
        }
      }
    }

    if (strPlaylist.isEmpty) {
      List<String> arrEvent = ['Default1', 'Default2', 'Default3'];
      for (int i = 0; i < arrEvent.length; i++) {
        String strFtpSettingFile =
            path.join(DCMGlobal.dayPath, '${arrEvent[i]}.xml');
        if (await File(strFtpSettingFile).exists()) {
          strPlaylist = arrEvent[i];
          break;
        }
      }
    } else {
      String strFileName = path.join(DCMGlobal.dayPath, '$strPlaylist.xml');
      strPlaylistVersion = getPlaylistVersion(strFileName) ?? '';
    }

    //m_strVerInfo = strDCMVersion + '\n' + strFTPVersion + '\n' + m_FtpSite.m_strMACAddress + '\n' + m_FtpSite.m_strMACAddress1 + '\n' + strPlaylist;
    //strVerInfo = strDCMVersion + '<br>' + strFTPVersion + '<br>' + strPlaylist;
    strVerInfo = '["$strDCMVersion", "$strFTPVersion", "$strPlaylist"]';
    //FTPMisc::SendStatusToMonitor(DCMVERSION_STATUS, 0, m_strVerInfo);
    return (strPlaylistVersion: strPlaylistVersion, strVerInfo: strVerInfo);
  }

  static String? getPlaylistVersion(String strFilename) {
    XmlFilePro file = XmlFilePro('EventDocument', null);
    if (!file.open(strFilename, XfOpen.read, false)) {
      return null;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == EventFileImpl.lpszEventSignature) {
        return file.getItemValue('m_strScheduleDesc');
      }
    }
    file.close();

    try {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFilename);
      if (xmlProfile.loadProfile(szRootItemName: 'PlayListAndSetting')) {
        return xmlProfile.getProfileString(
            'PlaySetting', 'm_strScheduleDesc', '');
      }
    } catch (_) {}

    return null;
  }
}
