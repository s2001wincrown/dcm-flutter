// integrity_check.dart
import 'dart:io';
import 'dart:convert';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/ah_message_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class IntegrityCheck {
  String _event = '';
  bool _writeLog = true;

  IntegrityCheck({bool writeLog = true, String? event, String? company}) {
    _event = event ?? '';
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

    writeLog("'$messageFile' not exist");
    return false;
  }

  bool integrityCheckPlaylist(String event, {String? company}) {
    _event = event;

    String filePath = path.join(AppGlobal.dayPath, '$_event.xml');

    if (!File(filePath).existsSync()) {
      writeLog("Event '$_event' not exist");
      return false;
    }

    // Simulate loading playlist
    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> data = json.decode(content);

      // Simulate processing playlist items
      List<dynamic> playlist = data['playlist'] as List? ?? [];

      for (dynamic item in playlist) {
        EventItemData eventItem = EventItemData()
          ..strDCMFile = item['strDCMFile'] ?? ''
          ..arrDCMFile = (item['arrDCMFile'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList()
          ..nItemType = EventItemType.values.firstWhere(
            (entry) => entry.value == (item['itemType'] ?? 0),
            orElse: () => EventItemType.normal,
          );

        if (eventItem.nItemType != EventItemType.rtGroup) {
          if (eventItem.arrDCMFile?.isNotEmpty == true) {
            for (String dcmFile in eventItem.arrDCMFile!) {
              if (!integrityCheckDCMFile(dcmFile)) {
                return false;
              }
            }
          } else {
            if (!integrityCheckDCMFile(eventItem.strDCMFile)) {
              return false;
            }
          }
        }
      }
    } catch (e) {
      writeLog("Playlist '$_event' open failure");
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
    String filePath = path.join(AppGlobal.openPath, '$dcmFile.dcm');

    if (!File(filePath).existsSync()) {
      writeLog('catalogue \'$dcmFile\' not exist');
      return false;
    }

    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> dcmData = json.decode(content);

      List<dynamic> products = dcmData['products'] as List? ?? [];

      for (dynamic product in products) {
        ProductData productData = ProductData()
          ..strProductName = product['name'] ?? '';

        // Process zones
        List<dynamic> zones = product['zones'] as List? ?? [];
        for (dynamic zone in zones) {
          ZoneData zoneData = ZoneData()
            ..strZoneFile = zone['strZoneFile'] ?? ''
            ..strZoneBGFile = zone['zoneBGFile'] ?? ''
            ..nZoneType = zone['nZoneType'] ?? 0;

          productData.lstZone.add(zoneData);
        }

        if (!integrityCheckProduct(productData, file: file)) {
          return false;
        }
      }

      // Check music file if exists
      String? musicFile = dcmData['musicFile'];
      if (musicFile != null && musicFile.isNotEmpty) {
        String musicPath = Utils.getFilePath(musicFile, 5, -1); // VCD_TYPE = 5
        if (!File(musicPath).existsSync()) {
          writeLog("'$musicFile' not exist");
          return false;
        }
      }
    } catch (e) {
      writeLog("catalogue '$dcmFile' open failure");
      return false;
    }

    return true;
  }

  bool integrityCheckProduct(ProductData? data,
      {int ptype = -1, dynamic file}) {
    if (data != null) {
      for (ZoneData zoneData in data.lstZone) {
        if (ptype == -1 && zoneData.nZoneType == 4) {
          // DDE_TYPE = 4
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
            case 6: // DIRECTPLAY_TYPE = 6
              if (!integrityCheckDirectType(filePath, file)) {
                return false;
              }
              break;
            case 0: // TEXT_TYPE = 0
              if (!integrityCheckTextSetting(zoneData.strZoneFile)) {
                return false;
              }
              break;
            case 2: // CLOCK_TYPE = 2
              if (!integrityCheckClockSetting(zoneData.strZoneFile)) {
                return false;
              }
              break;
            case 3: // WEATHER_TYPE = 3
              if (!integrityCheckWeatherSetting(zoneData.strZoneFile)) {
                return false;
              }
              break;
            case 1: // IMAGE_TYPE = 1
              if (ptype != 6) {
                // Not DIRECTPLAY_TYPE
                if (!integrityCheckImageSetting(zoneData.strZoneFile)) {
                  return false;
                }
              }
              break;
          }
        } else {
          switch (zoneData.nZoneType) {
            case 7: // TVCAPTURE_TYPE = 7
            case 8: // WEBPAGE_TYPE = 8
            case 9: // STREAMING_TYPE = 9
            case 10: // ONLINE_TYPE = 10
              break;
            default:
              if (valid < 0) {
                if (file == null) {
                  writeLog("'$zoneData.strZoneFile' not exist");
                }
              }
              return false;
          }
        }

        // Check background file
        if (zoneData.strZoneBGFile.isNotEmpty) {
          String bgPath = Utils.getFilePath(zoneData.strZoneBGFile, 1,
              0); // IMAGE_TYPE = 1, DCM_SINGLEIMAGE_TYPE = 0
          if (!File(bgPath).existsSync()) {
            writeLog("'${zoneData.strZoneBGFile}' not exist");
            return false;
          }
        }
      }
    }

    return true;
  }

  bool integrityCheckZone(ZoneData zoneData) {
    String filePath =
        Utils.getFilePath(zoneData.strZoneFile, zoneData.nZoneType, -1);

    if (!File(filePath).existsSync()) {
      writeLog("'${zoneData.strZoneFile}' not exist");
      return false;
    }

    if (zoneData.strZoneBGFile.isNotEmpty) {
      String bgPath = Utils.getFilePath(zoneData.strZoneBGFile, 1,
          0); // IMAGE_TYPE = 1, DCM_SINGLEIMAGE_TYPE = 0
      if (!File(bgPath).existsSync()) {
        writeLog("'${zoneData.strZoneBGFile}' not exist");
        return false;
      }
    }

    switch (zoneData.nZoneType) {
      case 0: // TEXT_TYPE = 0
        return integrityCheckTextSetting(zoneData.strZoneFile);
      case 1: // IMAGE_TYPE = 1
        return integrityCheckImageSetting(zoneData.strZoneFile);
      default:
        return true;
    }
  }

  bool integrityCheckTextSetting(String file) {
    String filePath = Utils.getFilePath(file, cTEXTTYPE);

    if (!File(filePath).existsSync()) {
      writeLog("'$file' not exist");
      return false;
    }

    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> textSetting = json.decode(content);

      String? imageFile = textSetting['imageFile'];
      if (imageFile != null && imageFile.isNotEmpty) {
        String imagePath = path.join(AppGlobal.imagePath, imageFile);
        if (!File(imagePath).existsSync()) {
          writeLog("'$imageFile' not exist");
          return false;
        }
      }

      List<dynamic> images = textSetting['images'] as List? ?? [];
      for (dynamic img in images) {
        String image = img.toString();

        if (image.startsWith('file:///')) {
          image = image.substring(8);
        }
        image = image.replaceAll('/', '\\');
        image = image.replaceAll('%20', ' ');

        String fileName = path.basename(image);
        String fullPath = path.join(AppGlobal.imagePath, fileName);

        if (!File(fullPath).existsSync()) {
          writeLog("'$fileName' not exist");
          return false;
        }
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  bool integrityCheckClockSetting(String file) {
    String filePath = path.join(AppGlobal.clockPath, file);

    if (!File(filePath).existsSync()) {
      writeLog("'$file' not exist");
      return false;
    }

    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> clockSetting = json.decode(content);

      String? imageFile = clockSetting['imageFile'];
      if (imageFile != null && imageFile.isNotEmpty) {
        String imagePath = path.join(AppGlobal.imagePath, imageFile);
        if (!File(imagePath).existsSync()) {
          writeLog("'$imageFile' not exist");
          return false;
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
      writeLog("'$file' not exist");
      return false;
    }

    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> weatherSetting = json.decode(content);

      String? imageFile = weatherSetting['imageFile'];
      if (imageFile != null && imageFile.isNotEmpty) {
        String imagePath = path.join(AppGlobal.imagePath, imageFile);
        if (!File(imagePath).existsSync()) {
          writeLog("'$imageFile' not exist");
          return false;
        }
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  bool integrityCheckImageSetting(String file) {
    String filePath = path.join(AppGlobal.imagePath, file);

    if (!File(filePath).existsSync()) {
      writeLog("'$file' not exist");
      return false;
    }

    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> imageSetting = json.decode(content);

      List<dynamic> imageFiles = imageSetting['images'] as List? ?? [];
      for (dynamic img in imageFiles) {
        String imageFile = img.toString();
        if (imageFile.isNotEmpty) {
          String imagePath = path.join(AppGlobal.imagePath, imageFile);
          if (!File(imagePath).existsSync()) {
            writeLog("'$imageFile' not exist");
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
    // Simulate checking direct type content
    Directory dir = Directory(folderPath);

    if (!dir.existsSync()) {
      writeLog("Directory '$folderPath' not exist");
      return false;
    }

    try {
      List<FileSystemEntity> entities = dir.listSync();

      for (FileSystemEntity entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.xml')) {
          ProductData product = ProductData()
            ..strProductName = path.basename(entity.path);

          // Simulate processing each product
          if (!integrityCheckProduct(product, ptype: 6, file: file)) {
            // DIRECTPLAY_TYPE = 6
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
      writeLog("IntegrityCheckRLTContent; Content '$filePath' does not exist!");
      return -1;
    }

    String ext = path.extension(filePath).toLowerCase();
    if (ext != '.swf') {
      return 1;
    }

    String fileName = path.basenameWithoutExtension(content);
    dynamic groupItem = file.getRLTContentGroupItem(fileName);

    if (groupItem != null) {
      dynamic currentItem = file.getFirstRLTContent(groupItem);

      while (currentItem != null) {
        String shortPath = file.getRLTContentShort(currentItem);

        if (shortPath.isNotEmpty) {
          String contentPath = path.join(AppGlobal.rltContentPath, shortPath);

          if (File(contentPath).existsSync()) {
            if (!integrityCheckValidityTime(contentPath)) {
              writeLog(
                  "IntegrityCheckRLTContent; Related Content '$contentPath' has expired for flash '$content'!");
              return 0;
            }
          } else {
            writeLog(
                "IntegrityCheckRLTContent; Content '$contentPath' not exist!");
            return 0;
          }
        }

        currentItem = file.getNextRLTContent(currentItem);
      }
    } else {
      return 0;
    }

    return 1;
  }

  bool integrityCheckValidityTime(String filePath) {
    String ext = path.extension(filePath).toLowerCase();
    if (ext != '.xml') {
      return true;
    }

    try {
      String content = File(filePath).readAsStringSync();
      Map<String, dynamic> xmlData = json.decode(content);

      String? validityTime = xmlData['ValidityTime'];

      if (validityTime != null) {
        DateTime validity = DateTime.parse(validityTime);

        if (validity.isAfter(DateTime.now())) {
          return true;
        }
      }
    } catch (e) {
      // If parsing fails, assume invalid
    }

    // Delete the file if it's invalid
    try {
      File(filePath).deleteSync();
      writeLog(
          "IntegrityCheckValidityTime; Delete file '$filePath' successfully!");
    } catch (e) {
      writeLog("IntegrityCheckValidityTime; Delete file '$filePath' failure!");
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
