// integrity_check.dart
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/banner_data.dart';
import 'package:dcm/backend/models/clock_data.dart' hide DateFormat;
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/slideshow_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/ah_message_impl.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/contentlist_impl.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xml_settings/eventfile_impl.dart';
import 'package:dcm/backend/xml_settings/text_impl.dart';
import 'package:dcm/backend/xml_settings/xml_clock_setting.dart';
import 'package:dcm/backend/xml_settings/xml_multi_image_setting.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class IntegrityCheck {
  String _event = '';
  String? _company;
  bool _writeLog = true;

  IntegrityCheck({bool writeLog = true, String? event, String? company}) {
    _event = event ?? '';
    _company = company;
    _writeLog = writeLog;
  }

  void writeLog(String log) {
    if (_writeLog) {
      String timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      String logEntry = '$timestamp; $_event; $log';

      // In a real implementation, you might write to a log file
      logD(logEntry);
    }
  }

  bool integrityCheckAHMessage({String? filePath, MessageData? messageData}) {
    String messageFile = '';
    if (messageData != null) {
      filePath =
          path.join(AppGlobal.messagePath, '${messageData.strAHName}.xml');
      messageFile = messageData.strAHName;
    }
    if (File(filePath!).existsSync()) {
      if (messageData == null) {
        messageFile = path.basenameWithoutExtension(filePath);
        // Simulate loading message data
        messageData = AHMessageImpl.loadMessageData(messageFile);
      }

      if (messageData != null && messageData.getZoneData() != null) {
        return integrityCheckZone(messageData.getZoneData()!);
      }
    }

    writeLog(''''$messageFile' not exist.''');
    return false;
  }

  bool integrityCheckPlaylist(String event, {String? company}) {
    _event = event;

    String filePath = path.join(AppGlobal.dayPath, '$_event.xml');

    if (!File(filePath).existsSync()) {
      writeLog('''Event '$_event' not exist''');
      return false;
    }

    // Simulate loading playlist
    try {
      EventFileImpl fileImpl = EventFileImpl();
      EventFileData objList = EventFileData();
      if (!fileImpl.loadFromXML(_event, objList)) {
        fileImpl.loadPlayList(objList, _event);
      }
      if (objList.lstPlayList == null || objList.lstPlayList!.isEmpty) {
        writeLog('''Playlist '$_event' open failure''');

        return false;
      }

      for (var pPlayListData in objList.lstPlayList!) {
        if (pPlayListData.nItemType != EventItemType.rtGroup) {
          if (pPlayListData.arrDCMFile != null &&
              pPlayListData.arrDCMFile!.isNotEmpty) {
            for (int i = 0; i < pPlayListData.arrDCMFile!.length; i++) {
              if (!integrityCheckDCMFile(pPlayListData.arrDCMFile![i])) {
                return false;
              }
            }
          } else {
            if (!integrityCheckDCMFile(pPlayListData.strDCMFile)) {
              return false;
            }
          }
        }
      }
    } catch (e) {
      writeLog('''Playlist '$_event' open failure''');
      return false;
    }

    return true;
  }

  bool integrityCheckEventItem(EventItemData pPlayListData) {
    if (pPlayListData.nItemType != EventItemType.rtGroup) {
      logD('not related content group!');

      return true;
    }
    if (!File(AppGlobal.rltContentFile).existsSync()) {
      writeLog('File \'${AppGlobal.rltContentFile}\' does not exist!');
      return false;
    }

    /*CRelatedContentFile file;
    if (!file.LoadSetting(Settings.m_strRLTContentFile, XF_READ))
    {
      WriteMessage(MSG_INFO, 'Load File '%s' failure!', Settings.m_strRLTContentFile);

      return FALSE;
    }*/
    logD('Open File \'${AppGlobal.rltContentFile}\' successfully!');

    if (pPlayListData.arrDCMFile!.isNotEmpty) {
      for (int i = 0; i < pPlayListData.arrDCMFile!.length; i++) {
        writeLog('check DCMFile \'${pPlayListData.arrDCMFile![i]}\'!');
        if (!integrityCheckDCMFile(pPlayListData.strDCMFile, file: null)) {
          writeLog(
              'check DCMFile \'${pPlayListData.arrDCMFile![i]}\' failure!');
          return false;
        }
      }
    } else {
      writeLog('check DCMFile \'${pPlayListData.strDCMFile}\'!');
      if (!integrityCheckDCMFile(pPlayListData.strDCMFile, file: null)) {
        writeLog('check DCMFile \'${pPlayListData.strDCMFile}\' failure!');
        return false;
      }
    }

    return true;
  }

  bool integrityCheckDCMFile(String dcmFile, {dynamic file}) {
    String? filePath =
        DCMFileImpl.getDCMPath(dcmFile, AppGlobal.openPath, _company);

    if (filePath == null) {
      writeLog('catalogue \'$dcmFile\' not exist');
      return false;
    }

    try {
      DCMFileData? dcmFileData =
          DCMFileImpl.openCatalogue(szEdit: filePath, bShort: false);
      if (dcmFileData != null) {
        int nProduct = dcmFileData.nQuantity;
        for (int i = 0; i < nProduct; i++) {
          ProductData? pData = dcmFileData.getProductDataByIndex(i);
          if (!integrityCheckProduct(pData, ptype: -1, file: file)) {
            return false;
          }
        }

        if (dcmFileData.strMusicFile.isNotEmpty) {
          String strFilePath1 = Utils.getFilePath(
              dcmFileData.strMusicFile, cVIDEOTYPE, -1, _company);
          if (!File(strFilePath1).existsSync()) {
            writeLog(''''${dcmFileData.strMusicFile}' not exist''');
            return false;
          }
        }
      } else {
        writeLog('catalogue \'$dcmFile\' open failure');

        return false;
      }
    } catch (e) {
      writeLog('catalogue \'$dcmFile\' open failure');
      return false;
    }

    return true;
  }

  bool integrityCheckProduct(ProductData? data,
      {int ptype = -1, dynamic file}) {
    if (data != null) {
      for (ZoneData zoneData in data.lstZone) {
        if (ptype == -1 && zoneData.nZoneType == cDDETYPE) {
          continue;
        }

        String filePath =
            Utils.getFilePath(zoneData.strZoneFile, zoneData.nZoneType, ptype);
        int valid =
            -1; // -1 = content not existed; 0 - illegal Related content; 1-content is ok

        if (filePath.length <= 260) {
          // _MAX_PATH equivalent
          if (file == null) {
            valid = (File(filePath).existsSync() ? 1 : -1);
          } else {
            valid =
                integrityCheckRLTContent(zoneData.strZoneFile, filePath, file);
          }
        }

        if (valid > 0) {
          switch (zoneData.nZoneType) {
            case cDIRECTPLAYTYPE:
              if (!integrityCheckDirectType(filePath, file)) {
                return false;
              }
              break;
            case cTEXTTYPE:
              if (!integrityCheckTextSetting(zoneData.strZoneFile)) {
                return false;
              }
              break;
            case cCLOCKTYPE:
              if (!integrityCheckClockSetting(zoneData.strZoneFile)) {
                return false;
              }
              break;
            case cWEATHERTYPE:
              if (!integrityCheckWeatherSetting(zoneData.strZoneFile)) {
                return false;
              }
              break;
            case cIMAGETYPE:
              if (ptype != cDIRECTPLAYTYPE) {
                // Not content list
                if (!integrityCheckImageSetting(zoneData.strZoneFile)) {
                  return false;
                }
              }
              break;
          }
        } else {
          switch (zoneData.nZoneType) {
            case cTVCAPTURETYPE:
            //case cWEBCAMTYPE:
            case cWEBPAGETYPE:
            case cSTREAMINGTYPE:
            case cONLINETYPE:
              break;
            default:
              if (valid < 0) {
                if (file == null) {
                  writeLog(''''${zoneData.strZoneFile}' not exist''');
                }
              }
              return false;
          }
        }

        // Check background file
        if (zoneData.strZoneBGFile.isNotEmpty) {
          String bgPath = Utils.getFilePath(zoneData.strZoneBGFile, cIMAGETYPE,
              cDCMSINGLEIMAGETYPE, _company);
          if (!File(bgPath).existsSync()) {
            writeLog('\'${zoneData.strZoneBGFile}\' not exist');
            return false;
          }
        }
      }
    }

    return true;
  }

  bool integrityCheckZone(ZoneData zoneData) {
    String filePath = Utils.getFilePath(
        zoneData.strZoneFile, zoneData.nZoneType, -1, _company);

    if (!File(filePath).existsSync()) {
      writeLog('\'${zoneData.strZoneFile}\' not exist');
      return false;
    }

    if (zoneData.strZoneBGFile.isNotEmpty) {
      String bgPath = Utils.getFilePath(
          zoneData.strZoneBGFile, cIMAGETYPE, cDCMSINGLEIMAGETYPE, _company);
      if (!File(bgPath).existsSync()) {
        writeLog('\'${zoneData.strZoneBGFile}\' not exist');
        return false;
      }
    }

    switch (zoneData.nZoneType) {
      case cTEXTTYPE:
        return integrityCheckTextSetting(zoneData.strZoneFile);
      case cIMAGETYPE:
        return integrityCheckImageSetting(zoneData.strZoneFile);
      default:
        return true;
    }
  }

  bool integrityCheckTextSetting(String file) {
    try {
      BannerData? textobj = TextImpl.loadTextSetting(file, _company);
      if (textobj == null) {
        writeLog('Banner: \'$file\' not exist');
        return false;
      }

      if (textobj.strFile.isNotEmpty) {
        String strImageFile = Utils.getFilePath(
            textobj.strFile, cIMAGETYPE, cDCMSINGLEIMAGETYPE, _company);
        if (!File(strImageFile).existsSync()) {
          writeLog('''Banner image file:'$strImageFile' not exist.''');

          return false;
        }
      }
      var arrImages = TextImpl.getImagesPath(textobj);
      if (arrImages != null) {
        for (int i = 0; i < arrImages.length; i++) {
          var strImageFile = arrImages[i];

          if (strImageFile.startsWithIgnoreCase('file:///')) {
            strImageFile = strImageFile.substring(8);
          }
          strImageFile = strImageFile.replaceAll('/', '\\');
          strImageFile = strImageFile.replaceAll('%20', ' ');
          String fileName = path.basename(strImageFile);
          strImageFile = Utils.getFilePath(
              fileName, cIMAGETYPE, cDCMSINGLEIMAGETYPE, _company);
          if (!File(strImageFile).existsSync()) {
            writeLog('Banner image file:\'$fileName\' not exist');

            return false;
          }
        }
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  bool integrityCheckClockSetting(String file) {
    try {
      ClockData clockData = ClockData();
      if (XmlClockSetting.loadClockSetting(file, clockData, _company)) {
        if (clockData.strFile.isNotEmpty) {
          String strImageFile = Utils.getFilePath(
              clockData.strFile, cIMAGETYPE, cDCMSINGLEIMAGETYPE, _company);
          if (!File(strImageFile).existsSync()) {
            writeLog('''Clock image file: '$strImageFile' not exist''');
            return false;
          }
        }
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  bool integrityCheckWeatherSetting(String file) {
    String filePath = path.join(AppGlobal.weatherPath, file);

    if (!File(filePath).existsSync()) {
      writeLog('\'$file\' not exist');
      return false;
    }

    return true;
  }

  bool integrityCheckImageSetting(String file) {
    try {
      SlideShowData? slideShow = XmlMultiImageSetting.loadImageSetting(file);
      if (slideShow == null) {
        writeLog('''Slideshow: '$file' not exist.''');
        return false;
      }

      for (int i = 0; i < slideShow.arrImageFile!.length; i++) {
        //strImageFile.Replace('\\', '/');
        //strImageFile.Replace(' ', '%20');
        if (slideShow.arrImageFile![i].isNotEmpty) {
          String strImageFile = Utils.getFilePath(slideShow.arrImageFile![i],
              cIMAGETYPE, cDCMSINGLEIMAGETYPE, _company);
          if (!File(strImageFile).existsSync()) {
            writeLog('\'${slideShow.arrImageFile![i]}\' not exist');
            return false;
          }
        }
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  bool integrityCheckDirectType(String folderPath, dynamic file) {
    try {
      ContentListImpl contentList = ContentListImpl(cDIRECTPLAYTYPE);
      contentList.loadContentList(folderPath);
      if (contentList.lstProduct.isEmpty) {
        return false;
      }

      for (var pData in contentList.lstProduct) {
        if (!contentList.isOutdated(pData)) {
          if (!integrityCheckProduct(pData,
              ptype: cDIRECTPLAYTYPE, file: file)) {
            return false;
          }
        }
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  int integrityCheckRLTContent(String content, String filePath, dynamic file) {
    if (!File(filePath).existsSync()) {
      writeLog(
          'IntegrityCheckRLTContent; Content \'$filePath\' does not exist.');
      return -1;
    }

    return 1;
  }

  bool integrityCheckValidityTime(String filePath) {
    String ext = path.extension(filePath).toLowerCase();
    if (ext != '.xml') {
      return true;
    }

    try {
      XmlProfile xmlProfile = XmlProfile.fromFile(filePath);
      if (xmlProfile.loadProfile()) {
        String strValidityTime = xmlProfile.getNodeText(null, 'ValidityTime');
        if (strValidityTime.isNotEmpty) {
          logI('''Read file '$filePath' Validity Time:'$strValidityTime'.''');
          DateTime? dtValidity = fromDateTimeFormat(strValidityTime);
          if (dtValidity != null) {
            if (dtValidity.isAfter(DateTime.now())) {
              logI('''IntegrityCheckValidityTime; file '$filePath' is Valid''');

              return true;
            }
          }
        }
      }
      xmlProfile.close();
    } catch (e) {
      // If parsing fails, assume invalid
    }

    // Delete the file if it's invalid
    try {
      File(filePath).deleteSync();
      writeLog(
          'IntegrityCheckValidityTime; Delete file \'$filePath\' successfully.');
    } catch (e) {
      writeLog(
          'IntegrityCheckValidityTime; Delete file \'$filePath\' failure.');
    }

    return false;
  }

  bool integrityCheckDDEFile(String dcmFile, List<String> arrDDE) {
    // This method is not fully implemented in the original C++ code
    return true;
  }

  bool integrityCheckDDEType(DateTime start, DateTime end,
      {String folder = ""}) {
    // Simulate DDE type integrity check
    // This would typically iterate through DDE content and validate each item
    return true;
  }
}
