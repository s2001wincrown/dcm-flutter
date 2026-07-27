import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/services/content_file_impl.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class PlayerPublish {
  String errorMessage = '';
  bool includeDDEContent = false;
  bool hashData = false;

  final ContentFileImpl contentFile;

  PlayerPublish({
    required String sourcePath,
    required String batch,
    required String usbPath,
    String company = '',
  }) : contentFile = ContentFileImpl(
          sourcePath: sourcePath,
          batch: batch,
          usbPath: usbPath,
          company: company,
        );

  PlayerPublish.empty() : contentFile = ContentFileImpl.empty();

  String getErrorMessage() => errorMessage;

  void clearError() {
    errorMessage = '';
  }

  void setIncludeDDEContent(bool value) {
    includeDDEContent = value;
  }

  void setHashData(bool value) {
    hashData = value;
  }

  String getExportPath(int type) {
    return contentFile.getExportPath(contentFile.sourcePath, type);
  }

  String getShortPath(String fileName,
      [int type = -1, int ptype = -1, String root = '']) {
    return Utils.getShortPath(fileName, type, ptype, root);
  }

  String getFilePath(String fileName, int type,
      [int ptype = -1, String? company]) {
    if (fileName.isEmpty) {
      return '';
    }

    if (path.isAbsolute(fileName)) {
      return fileName;
    }

    return Utils.getFilePath(fileName, type, ptype, company);
  }

  bool publishFile(String fileName, int type,
      {int ptype = -1, String contentRoot = ''}) {
    final resolvedPath = _resolveFilePath(fileName, type, ptype, contentRoot);
    if (resolvedPath.isEmpty) {
      _setErrorMessage('Publish file not found: $fileName');
      return false;
    }

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      _setErrorMessage('Publish file not found: $resolvedPath');
      return false;
    }

    final shortPath = contentRoot.isEmpty
        ? getShortPath(resolvedPath, type, ptype)
        : _relativeShortPath(resolvedPath, contentRoot);
    final destFile = shortPath;
    return _addFileInfo(resolvedPath, shortPath, destFile, type, ptype);
  }

  bool publishFiles(List<String> fileNames, int type,
      {int ptype = -1, String contentRoot = ''}) {
    var success = true;
    for (final fileName in fileNames) {
      if (fileName.isNotEmpty) {
        success = publishFile(fileName, type,
                ptype: ptype, contentRoot: contentRoot) &&
            success;
      }
    }
    return success;
  }

  bool publishFileTo(String fileName, int type,
      {int ptype = -1, String? destFile}) {
    final resolvedPath = _resolveFilePath(fileName, type, ptype, '');
    if (resolvedPath.isEmpty) {
      _setErrorMessage('Publish file not found: $fileName');
      return false;
    }

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      _setErrorMessage('Publish file not found: $resolvedPath');
      return false;
    }

    final shortPath = getShortPath(resolvedPath, type, ptype);
    final targetDestFile =
        destFile != null && destFile.isNotEmpty ? destFile : shortPath;

    return _addFileInfo(resolvedPath, shortPath, targetDestFile, type, ptype);
  }

  bool publishPathFile(String filePath, int contentType) {
    return publishFile(filePath, contentType);
  }

  bool publishAHMessage(String messageName) {
    if (messageName.isEmpty) {
      _setErrorMessage('AH message name is empty');
      return false;
    }

    final normalized = path.basename(messageName);
    final fileName =
        path.extension(normalized).isEmpty ? '$normalized.xml' : normalized;
    final messageFile = path.join(AppGlobal.messagePath, fileName);
    return publishFileTo(messageFile, cDCMAHMESSAGETYPE);
  }

  bool publishAHMessageData(MessageData messageData) {
    if (messageData.strAHName.isEmpty) {
      _setErrorMessage('AH message name is empty');
      return false;
    }

    final fileName =
        path.join(AppGlobal.messagePath, '${messageData.strAHName}.xml');
    if (!File(fileName).existsSync()) {
      _setErrorMessage(
          'AH message file not found: ${messageData.strAHName}.xml');
      return false;
    }

    final short = path.basename(fileName);
    final added = _addFileInfo(fileName, short, short, cDCMAHMESSAGETYPE, -1);

    final zone = messageData.getZoneData();
    if (zone != null) {
      _publishZoneData(zone);
    }

    return added;
  }

  bool publishDirectType(String fileName) {
    return publishFile(fileName, cDIRECTPLAYTYPE);
  }

  bool publishDDEType(String fileName) {
    return publishFile(fileName, cDDETYPE);
  }

  bool publishTextSetting(String fileName) {
    return publishFile(fileName, cTEXTTYPE);
  }

  bool publishClockSetting(String fileName) {
    return publishFile(fileName, cCLOCKTYPE);
  }

  bool publishWeatherSetting(String fileName) {
    return publishFile(fileName, cWEATHERTYPE);
  }

  bool publishSitePlaylist(
      String player, String sitePlaylist, DateTime startFtpTime, int period) {
    if (player.isEmpty || sitePlaylist.isEmpty || period <= 0) {
      _setErrorMessage('Invalid parameters for site playlist publishing');
      return false;
    }

    final sitePath = Utils.getBasePath(cSITEPLAYLIST);
    if (sitePath.isEmpty) {
      _setErrorMessage('Site playlist folder is not configured');
      return false;
    }

    final formatter = DateFormat('yyyyMMdd');
    var success = true;

    if (sitePlaylist.toLowerCase() == 'site playlist') {
      for (var i = 0; i < period; i++) {
        final date = formatter.format(startFtpTime.add(Duration(days: i)));
        final publishFile = path.join(sitePath, date, '$player.xml');
        if (File(publishFile).existsSync()) {
          success = publishFileTo(publishFile, cSITEPLAYLIST,
                  destFile: '$date\\$player.xml') &&
              success;
        }
      }
    } else {
      for (var i = 0; i < period; i++) {
        final date = formatter.format(startFtpTime.add(Duration(days: i)));
        final publishFile = path.join(sitePath, sitePlaylist, '$date.xml');
        if (File(publishFile).existsSync()) {
          success = publishFileTo(publishFile, cSITEPLAYLIST,
                  destFile: '$sitePlaylist\\$date.xml') &&
              success;
        }
      }

      final defaultFile = path.join(sitePath, sitePlaylist, 'Default.xml');
      if (File(defaultFile).existsSync()) {
        success = publishFileTo(defaultFile, cSITEPLAYLIST,
                destFile: '$sitePlaylist\\Default.xml') &&
            success;
      }
    }

    return success;
  }

  String _resolveFilePath(
      String fileName, int type, int ptype, String contentRoot) {
    if (fileName.isEmpty) {
      return '';
    }

    if (path.isAbsolute(fileName)) {
      return fileName;
    }

    if (contentRoot.isNotEmpty) {
      final candidate = path.join(contentRoot, fileName);
      if (File(candidate).existsSync()) {
        return candidate;
      }
      return getFilePath(fileName, type, ptype);
    }

    final candidate = File(fileName);
    if (candidate.existsSync()) {
      return candidate.path;
    }

    return getFilePath(fileName, type, ptype);
  }

  String _relativeShortPath(String filePath, String contentRoot) {
    try {
      return path.relative(filePath, from: contentRoot).replaceAll('/', '\\');
    } catch (_) {
      return getShortPath(filePath);
    }
  }

  bool _addFileInfo(
      String filePath, String shortPath, String destFile, int type, int ptype) {
    final dstType = _adjustContentType(type, ptype);
    final file = File(filePath);
    final stat = file.statSync();

    final fileInfo = FileInfoData.create(
      strFileTitle: path.basename(filePath),
      strShortPath: shortPath,
      strDestFile: destFile,
      dwFileSize: BigInt.from(stat.size),
      nContentType: dstType,
      tmFileCreate: stat.changed,
      tmFileModify: stat.modified,
    );
    fileInfo.strFilePath = file.path;

    if (!_loadHashData(file.path, fileInfo)) {
      // If hash data is requested and missing, treat as publish failure.
      if (hashData) {
        _setErrorMessage('Missing hash metadata for $filePath');
        return false;
      }
    }

    return contentFile.addFileList(fileInfo);
  }

  bool _loadHashData(String filePath, FileInfoData fileInfo) {
    if (!hashData) {
      return true;
    }

    final md5File = File('$filePath.MD5');
    if (!md5File.existsSync()) {
      final md5LowerFile = File('$filePath.md5');
      if (!md5LowerFile.existsSync()) {
        return false;
      }
      return _parseHashData(md5LowerFile.readAsStringSync(), fileInfo);
    }

    return _parseHashData(md5File.readAsStringSync(), fileInfo);
  }

  bool _parseHashData(String hashData, FileInfoData fileInfo) {
    final parts = hashData.split('||').map((part) => part.trim()).toList();
    if (parts.isEmpty || parts[0].isEmpty) {
      return false;
    }
    fileInfo.strMD5 = parts[0];
    if (parts.length > 1) {
      fileInfo.strSHA1 = parts[1];
    }
    return true;
  }

  int _adjustContentType(int type, int ptype) {
    if (ptype < 0) {
      return type;
    }
    if (ptype == cDDETYPE) {
      return cDDETYPE;
    }
    if (ptype == cSITEPLAYLIST) {
      return cDCMSITEDATATYPE;
    }
    return type;
  }

  void _setErrorMessage(String message) {
    errorMessage = message;
  }

  // ----- Additional parity helpers (ported from C++) -----

  void _publishZoneData(ZoneData pZoneData) {
    if (pZoneData.strZoneFile.isEmpty) return;

    final strFilePath = getFilePath(pZoneData.strZoneFile, pZoneData.nZoneType);
    if (!contentFile.isInFileList(strFilePath, pZoneData.nZoneType)) {
      if (File(strFilePath).existsSync()) {
        final shortPath =
            getShortPath(pZoneData.strZoneFile, pZoneData.nZoneType);
        _addFileInfo(
            strFilePath, shortPath, shortPath, pZoneData.nZoneType, -1);
        // Publish any related files for this zone (background image, etc.)
        publishOtherFileByZone(pZoneData);
      } else {
        _setErrorMessage('Zone file not found: ${pZoneData.strZoneFile}');
      }
    }

    if (pZoneData.strZoneBGFile.isNotEmpty) {
      final bgPath =
          getFilePath(pZoneData.strZoneBGFile, cIMAGETYPE, cDCMSINGLEIMAGETYPE);
      if (!contentFile.isInFileList(bgPath, cIMAGETYPE)) {
        if (File(bgPath).existsSync()) {
          final shortPath = getShortPath(
              pZoneData.strZoneBGFile, cIMAGETYPE, cDCMSINGLEIMAGETYPE);
          _addFileInfo(bgPath, shortPath, shortPath, cIMAGETYPE, -1);
        } else {
          _setErrorMessage(
              'Zone background not found: ${pZoneData.strZoneBGFile}');
        }
      }
    }

    // Handle certain zone-specific types
    switch (pZoneData.nZoneType) {
      case cTEXTTYPE:
        publishTextSetting(pZoneData.strZoneFile);
        break;
      case cIMAGETYPE:
        // image slideshow or multi-image handled elsewhere; keep parity minimal
        break;
      default:
        break;
    }
  }

  void publishOtherFileByZone(ZoneData pZoneData) {
    // Intentionally small: when a zone refers to additional content types,
    // check and add related files (for example FLV for flash content).
    final strFile = pZoneData.strZoneFile;
    final contentType = pZoneData.nZoneType;
    final short = getShortPath(strFile, contentType);
    // If the zone references a flash file, try to add corresponding .flv
    if (contentType == cFLASHTYPE) {
      final ext = path.extension(strFile);
      if (ext.isNotEmpty) {
        final flv = '${strFile.substring(0, strFile.length - ext.length)}.flv';
        final flvPath = getFilePath(flv, contentType);
        if (!contentFile.isInFileList(flvPath, contentType) &&
            File(flvPath).existsSync()) {
          final shortFlv = getShortPath(flvPath, contentType);
          _addFileInfo(flvPath, shortFlv, shortFlv, contentType, -1);
        }
      }
    }
  }

  bool publishOtherFile(FileInfoData pFileInfo) {
    // Mirror C++ behavior for other-file publication (eg. flash->flv)
    switch (pFileInfo.nContentType) {
      case cFLASHTYPE:
        final strFilePath = pFileInfo.strFilePath ?? '';
        if (strFilePath.isEmpty) return false;
        final ext = path.extension(strFilePath);
        if (ext.isEmpty) return false;

        final candidate =
            '${strFilePath.substring(0, strFilePath.length - ext.length)}.flv';
        if (!contentFile.isInFileList(candidate, pFileInfo.nContentType) &&
            File(candidate).existsSync()) {
          final stat = File(candidate).statSync();
          final fileInfo = FileInfoData.create(
            strFileTitle: path.basename(candidate),
            strShortPath: path.basename(candidate),
            strDestFile: path.basename(candidate),
            dwFileSize: BigInt.from(stat.size),
            nContentType: pFileInfo.nContentType,
            tmFileCreate: stat.changed,
            tmFileModify: stat.modified,
          );
          fileInfo.strFilePath = candidate;
          _loadHashData(candidate, fileInfo);
          return contentFile.addFileList(fileInfo);
        }
        return false;
      default:
        return false;
    }
  }

  bool publishProduct(ProductData product, [int ptype = -1]) {
    if (product.lstZone.isEmpty) return true;
    var success = true;
    for (final zone in product.lstZone) {
      if (zone.strZoneFile.isNotEmpty) {
        final fp = getFilePath(zone.strZoneFile, zone.nZoneType);
        if (fp.isNotEmpty && File(fp).existsSync()) {
          final short = getShortPath(zone.strZoneFile, zone.nZoneType);
          success =
              _addFileInfo(fp, short, short, zone.nZoneType, ptype) && success;
          _publishZoneData(zone);
        } else {
          // try publishFile which will set error message if missing
          success =
              publishFile(zone.strZoneFile, zone.nZoneType, ptype: ptype) &&
                  success;
        }
      }
    }
    return success;
  }
}
