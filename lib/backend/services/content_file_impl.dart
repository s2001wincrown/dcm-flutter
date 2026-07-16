import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/utils/file_info_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/contenttype_manager.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class ContentFileImpl {
  static const String _signature =
      'DCM FTP Manager Version 1.00 - Publish File Information List';

  final String sourcePath;
  final String batch;
  final String usbPath;
  final String company;

  final List<FileInfoData> lstFileInfo = [];
  final List<String> lstPlayerChannel = [];
  final List<String> arrEvents = [];
  final List<_TempFileInfo> _arrTempFile = [];

  ContentFileImpl({
    required this.sourcePath,
    required this.batch,
    required this.usbPath,
    this.company = '',
  });

  ContentFileImpl.empty()
      : sourcePath = '',
        batch = '',
        usbPath = '',
        company = '';

  bool addFileList(FileInfoData data) {
    for (final existing in lstFileInfo) {
      if (data.isSameAs(pFileInfo: existing)) {
        return false;
      }
    }
    lstFileInfo.add(data);
    return true;
  }

  void removeFileList() {
    lstFileInfo.clear();
  }

  bool serialize(String fileName, bool storing) {
    final xmlFile = XmlFilePro('PublishFileInformation');

    if (storing) {
      for (final fileInfo in lstFileInfo) {
        final XmlItem? xi = xmlFile.addDataNode('FileItem', null);
        if (xi != null) {
          fileInfo.writeToXML(xi, true);
        }
      }
      xmlFile.setSignature(_signature);
      return xmlFile.save(fileName);
    }

    if (!xmlFile.open(fileName, XfOpen.read, false)) {
      return false;
    }

    if (!xmlFile.loadEx()) {
      return false;
    }

    if (xmlFile.getSignature() != _signature) {
      return false;
    }

    XmlItem? item = xmlFile.getItem('FileItem');
    while (item != null) {
      final fileInfo = FileInfoData.create(
        strFileTitle: '',
        strShortPath: '',
        strDestFile: '',
        dwFileSize: BigInt.zero,
      );
      fileInfo.getFromXML(item);
      addFileList(fileInfo);
      item = item.getSibling();
    }

    return true;
  }

  bool loadFileList({bool generated = false}) {
    bool bFileList = true;
    if (!generated) {
      final usbDir = Directory(usbPath);
      if (usbDir.existsSync()) {
        final datFiles = usbDir
            .listSync(followLinks: false)
            .whereType<File>()
            .where((file) => path.extension(file.path).toLowerCase() == '.dat');

        if (datFiles.isEmpty) {
          bFileList = false;
        } else {
          for (final file in datFiles) {
            bFileList = bFileList && serialize(file.path, false);
          }
        }
      } else {
        bFileList = false;
      }

      if (bFileList) {
        final fileName =
            path.join(DCMGlobal.settingPath, 'Filelog', '$batch.xml');
        Directory(path.dirname(fileName)).createSync(recursive: true);
        bFileList = serialize(fileName, true);
      }
    } else {
      removeFileList();
      final fileName =
          path.join(DCMGlobal.settingPath, 'Filelog', '$batch.xml');
      bFileList = serialize(fileName, false);
    }

    return bFileList;
  }

  bool findContents() {
    final usbDir = Directory(usbPath);
    if (!usbDir.existsSync()) {
      return false;
    }

    final today = DateTime.now();
    final List<String> dates = [];

    for (final entity in usbDir.listSync(followLinks: false)) {
      if (entity is File) {
        final fileName = path.basenameWithoutExtension(entity.path);
        if (fileName.length == 8) {
          final parsedDate = _tryParseDate(fileName);
          if (parsedDate != null &&
              !parsedDate.isBefore(DateTime(
                today.year,
                today.month,
                today.day,
              ))) {
            dates.add(fileName);
          }
        }
      }
    }

    for (final date in dates) {
      genFileListByContents(date);
    }

    return lstFileInfo.isNotEmpty;
  }

  bool genFileListByContents(String strDate) {
    final strPath = path.join(usbPath, strDate);
    final fileList = path.join(strPath, 'FileList.ini');
    if (!File(fileList).existsSync()) {
      return false;
    }

    final iniFile = IniFile(fileList);
    final fileLists = iniFile.sections['FileLists'];
    if (fileLists == null || fileLists.isEmpty) {
      return false;
    }

    bool bSave = false;
    for (final fileName in fileLists.keys) {
      final source = path.join(strPath, fileName);
      final contentType = ContentTypeManager.getContentTypeByFileName(source);
      if (contentType == -1) {
        continue;
      }

      final dest = path.join(
        sourcePath,
        _getRelativeExportPath(contentType),
        fileName,
      );
      if (_copyFileOrDirectory(source, dest)) {
        final fileInfo = FileInfoUtils.loadFileInfo(dest, contentType);
        if (fileInfo != null) {
          fileInfo.fileStatus = FileItemStatus.temporary;
          fileInfo.strFilePath = source;
          lstFileInfo.add(fileInfo);
          bSave = true;
        }
      }
    }

    return bSave;
  }

  String genTextContent([String textContent = '']) {
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    return textContent.isEmpty ? timestamp : '$textContent-$timestamp';
  }

  bool filterFileList() {
    for (final fileInfo in lstFileInfo) {
      if (fileInfo.fileStatus == FileItemStatus.download) {
        fileInfo.fileStatus = FileItemStatus.temporary;
      }
    }
    return true;
  }

  void filterDownloadedFile() {
    for (final fileInfo in lstFileInfo) {
      if (fileInfo.fileStatus == FileItemStatus.download) {
        final exportPath = getExportPath(sourcePath, fileInfo.nContentType);
        final dest = path.join(exportPath, fileInfo.strDestFile);
        final file = File(dest);
        if (file.existsSync()) {
          final stat = file.statSync();
          if (fileInfo.dwFileSize == BigInt.from(stat.size)) {
            fileInfo.fileStatus = FileItemStatus.temporary;
          }
        }
      }
    }
  }

  bool copyToTempFolder() {
    bool success = true;
    final priorities = [0, 1, 2, 3, 4];
    for (final priority in priorities) {
      success = _copyTempFile(priority) && success;
    }

    final fileName = path.join(DCMGlobal.settingPath, 'Filelog', '$batch.xml');
    Directory(path.dirname(fileName)).createSync(recursive: true);
    bool saved = serialize(fileName, true);
    success = success && saved;

    final updateLogPath = path.join(DCMGlobal.tempPath, 'updatelog.xml');
    final xmlProfile = XmlProfile.fromFile(updateLogPath);
    if (!File(updateLogPath).existsSync()) {
      xmlProfile.createProfile('FileList');
    } else {
      xmlProfile.loadProfile(
          lpszFileName: updateLogPath, szRootItemName: 'FileList');
    }
    xmlProfile.writeProfileDateTime(
        'USBContentImport', 'EndTime', DateTime.now());
    xmlProfile.saveProfile('FileList.xsl');

    return success;
  }

  bool _copyTempFile(int priorityFlag) {
    bool allSuccess = true;
    for (var i = _arrTempFile.length - 1; i >= 0; i--) {
      final entry = _arrTempFile[i];
      if (entry.priorityFlag == priorityFlag) {
        Directory(path.dirname(entry.destPath)).createSync(recursive: true);
        if (_copyFileOrDirectory(entry.sourcePath, entry.destPath)) {
          _arrTempFile.removeAt(i);
        } else {
          allSuccess = false;
        }
      }
    }
    return allSuccess;
  }

  bool _copyFileOrDirectory(String source, String dest) {
    final sourceFile = File(source);
    if (sourceFile.existsSync()) {
      try {
        final targetFile = File(dest);
        Directory(path.dirname(dest)).createSync(recursive: true);
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
        sourceFile.copySync(dest);
        return true;
      } catch (_) {
        return false;
      }
    }

    final sourceDir = Directory(source);
    if (!sourceDir.existsSync()) {
      return false;
    }

    try {
      for (final entity in sourceDir.listSync(followLinks: false)) {
        final relative = path.basename(entity.path);
        if (entity is File) {
          if (path.extension(entity.path).toLowerCase() == '.md5') {
            continue;
          }
          final destination = path.join(dest, relative);
          Directory(path.dirname(destination)).createSync(recursive: true);
          if (File(destination).existsSync()) {
            File(destination).deleteSync();
          }
          entity.copySync(destination);
        } else if (entity is Directory) {
          final childDest = path.join(dest, relative);
          _copyFileOrDirectory(entity.path, childDest);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool getContentListAndChecksum(String folder) {
    var ok = true;
    for (final fileInfo in lstFileInfo) {
      if (fileInfo.fileStatus == FileItemStatus.temporary) {
        final exportPath = getExportPath(folder, fileInfo.nContentType);
        final filePath = path.join(exportPath, fileInfo.strDestFile);
        if (!checksum(filePath, fileInfo)) {
          try {
            File(filePath).deleteSync();
          } catch (_) {}
          ok = false;
        }
      }
    }

    if (ok) {
      final fileName =
          path.join(DCMGlobal.settingPath, 'Filelog', '$batch.xml');
      ok = serialize(fileName, true);
      getExportPath(folder, cDCMCALENDARTYPE);
      getExportPath(folder, cDCMMONTHTYPE);
    }

    return ok;
  }

  void getEventList() {
    for (final fileInfo in lstFileInfo) {
      getExportPath(sourcePath, fileInfo.nContentType);
      if (fileInfo.nContentType == cDCMDAYTYPE) {
        final eventName = path.basenameWithoutExtension(fileInfo.strDestFile);
        if (!arrEvents.contains(eventName)) {
          arrEvents.add(eventName);
        }
      }
    }
    getExportPath(sourcePath, cDCMCALENDARTYPE);
    getExportPath(sourcePath, cDCMMONTHTYPE);
  }

  void contentClear() {
    final contentPaths = _getContentPaths();
    for (final source in contentPaths) {
      deleteContentNotInFileList(source, lstFileInfo);
    }
  }

  void contentClearByCalendar() {
    final contentPaths = _getContentPaths();
    for (final source in contentPaths) {
      deleteContentNotInFileList(source, lstFileInfo);
    }
  }

  List<String> _getContentPaths() {
    final List<String> contentPaths = [];
    _addContentPath(DCMGlobal.imagePath, contentPaths);
    _addContentPath(DCMGlobal.clockPath, contentPaths);
    _addContentPath(DCMGlobal.ddeDataPath, contentPaths);
    _addContentPath(DCMGlobal.ddeXmlPath, contentPaths);
    _addContentPath(DCMGlobal.flashPath, contentPaths);
    _addContentPath(DCMGlobal.imageSettingPath, contentPaths);
    _addContentPath(DCMGlobal.linkagePath, contentPaths);
    _addContentPath(DCMGlobal.ppPath, contentPaths);
    _addContentPath(DCMGlobal.contentListPath, contentPaths);
    _addContentPath(DCMGlobal.textPath, contentPaths);
    _addContentPath(DCMGlobal.vcdPath, contentPaths);
    _addContentPath(DCMGlobal.weatherPath, contentPaths);
    _addContentPath(DCMGlobal.webPath, contentPaths);
    _addContentPath(DCMGlobal.openPath, contentPaths);
    _addContentPath(DCMGlobal.dayPath, contentPaths);
    _addContentPath(DCMGlobal.siteContentPath, contentPaths);
    _addContentPath(DCMGlobal.roomEventPath, contentPaths);
    _addContentPath(DCMGlobal.lobbyPath, contentPaths);
    return contentPaths;
  }

  void _addContentPath(String? contentPath, List<String> contentPaths) {
    if (contentPath == null || contentPath.isEmpty) {
      return;
    }
    final normalized = path.normalize(contentPath);
    final lower = normalized.toLowerCase();
    for (var i = 0; i < contentPaths.length; i++) {
      final existing = path.normalize(contentPaths[i]).toLowerCase();
      if (existing == lower) {
        return;
      }
      if (path.isWithin(existing, normalized)) {
        return;
      }
      if (path.isWithin(lower, existing)) {
        contentPaths[i] = normalized;
        return;
      }
    }
    contentPaths.add(normalized);
  }

  void deleteContentNotInFileList(String source, List<FileInfoData> fileList,
      {Set<String>? tempPath, Set<String>? ignoreList}) {
    final normalizedSource = path.normalize(source);
    if (tempPath != null && tempPath.isNotEmpty) {
      for (final temp in tempPath) {
        if (normalizedSource.toLowerCase().contains(temp.toLowerCase())) {
          return;
        }
      }
    }

    final directory = Directory(normalizedSource);
    if (!directory.existsSync()) {
      return;
    }

    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        if (path.extension(entity.path).toLowerCase() == '.md5') {
          try {
            entity.deleteSync();
          } catch (_) {}
          continue;
        }

        if (ignoreList != null && ignoreList.contains(fileName.toLowerCase())) {
          continue;
        }

        final normalizedEntity = path.normalize(entity.path).toLowerCase();
        final existed = fileList.any((data) {
          if (data.strFilePath != null && data.strFilePath!.isNotEmpty) {
            return path.normalize(data.strFilePath!).toLowerCase() ==
                normalizedEntity;
          }
          return path.normalize(data.strDestFile).toLowerCase() ==
              fileName.toLowerCase();
        });

        if (!existed) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }

    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        if (ignoreList != null && ignoreList.contains(dirName.toLowerCase())) {
          continue;
        }
        deleteContentNotInFileList(entity.path, fileList,
            tempPath: tempPath, ignoreList: ignoreList);
      }
    }
  }

  bool deleteMonthContents(String folder,
      {bool includeSubFolders = true,
      String fileMask = '',
      bool processMsgLoop = false}) {
    final directory = Directory(folder);
    if (!directory.existsSync()) {
      return true;
    }

    final now = DateTime.now();
    final currentMonth = DateFormat('yyyyMM').format(now);
    var result = true;

    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File) {
        final fileName = path.basenameWithoutExtension(entity.path);
        if (fileName.compareTo(currentMonth) < 0) {
          try {
            entity.deleteSync();
          } catch (_) {
            result = false;
          }
        }
      } else if (entity is Directory) {
        if (includeSubFolders) {
          final subResult = deleteMonthContents(entity.path,
              includeSubFolders: includeSubFolders,
              fileMask: fileMask,
              processMsgLoop: processMsgLoop);
          if (!subResult) {
            result = false;
          }
        }
      }
    }

    return result;
  }

  String getExportPath(String folder, int type) {
    final exportSourcePath = path.join(folder, _getRelativeExportPath(type));
    if (!_hasTempPath(type)) {
      final destPath = _getBasePath(type);
      addTempFile(type, exportSourcePath, destPath, _getPriorityFlag(type));
    }
    return exportSourcePath;
  }

  bool _hasTempPath(int type) {
    for (final item in _arrTempFile) {
      if (item.contentType == type) {
        return true;
      }
    }
    return false;
  }

  void addTempFile(
      int contentType, String source, String dest, int priorityFlag) {
    _arrTempFile.add(_TempFileInfo(
      contentType: contentType,
      sourcePath: source,
      destPath: dest,
      priorityFlag: priorityFlag,
    ));
  }

  bool checksum(String filePath, FileInfoData fileInfo) {
    if ((DCMGlobal.globalSetting & settingCHECKSUM) == 0) {
      return true;
    }

    if (path.extension(filePath).toLowerCase() == '.xml') {
      final md5File = '$filePath.MD5';
      if (!File(md5File).existsSync()) {
        _writeLogFile(filePath, fileInfo.strDestFile, 2,
            "Checksum file '$md5File' does not exist");
        return false;
      }

      final hash = File(md5File).readAsStringSync();
      final md5 = hash.split('||').first.trim();
      if (fileInfo.strMD5 != null && fileInfo.strMD5!.isNotEmpty) {
        if (md5.toLowerCase() == fileInfo.strMD5!.toLowerCase()) {
          return true;
        }
        _writeLogFile(filePath, fileInfo.strDestFile, 2,
            "MD5 '$md5' not match source MD5 '${fileInfo.strMD5}'!");
        return false;
      }
      _writeLogFile(filePath, fileInfo.strDestFile, 2,
          "Missing source hash for '${fileInfo.strDestFile}'");
      return false;
    }

    return true;
  }

  bool saveDownloadFileList() {
    if (!loadFileList(generated: true)) {
      return false;
    }

    final fileName = path.join(DCMGlobal.settingPath, 'Filelog', '$batch.xml');
    Directory(path.dirname(fileName)).createSync(recursive: true);
    return serialize(fileName, true);
  }

  bool copyTempFile([int? priorityFlag]) {
    if (priorityFlag == null) {
      var success = true;
      for (final priority in [0, 1, 2, 3, 4]) {
        success = _copyTempFile(priority) && success;
      }

      final fileName =
          path.join(DCMGlobal.settingPath, 'Filelog', '$batch.xml');
      Directory(path.dirname(fileName)).createSync(recursive: true);
      final saved = serialize(fileName, true);
      return success && saved;
    }

    return _copyTempFile(priorityFlag);
  }

  bool loadPlayerChannels() {
    // Simplified port: channel metadata is optional for import flow.
    return true;
  }

  bool copyMonthFile(String folder, List<String> companies) {
    if (!loadPlayerChannels()) {
      return false;
    }

    var success = true;
    final calendarSource = path.join(usbPath, 'calendar');
    final monthSource = path.join(usbPath, 'month');
    final calendarTarget = path.join(folder, 'calendar');
    final monthTarget = path.join(folder, 'month');

    if (Directory(calendarSource).existsSync()) {
      success = _copyFileOrDirectory(calendarSource, calendarTarget) && success;
    }
    if (Directory(monthSource).existsSync()) {
      success = _copyFileOrDirectory(monthSource, monthTarget) && success;
    }

    if (companies.isEmpty) {
      final usbDir = Directory(usbPath);
      if (usbDir.existsSync()) {
        for (final entity in usbDir.listSync(followLinks: false)) {
          if (entity is Directory) {
            final name = path.basename(entity.path);
            final lower = name.toLowerCase();
            if ([
              'calendar',
              'month',
              'setting',
              'apupdate',
              'filelog',
              'dcmfile',
              'image',
              'linkage',
              'update'
            ].contains(lower)) {
              continue;
            }
            companies.add(name);
          }
        }
      }
    }

    return success;
  }

  bool copyDCMUpdateFile(String drive, String batch) {
    if (batch.isEmpty) {
      return false;
    }

    final usbPath = '$drive:\\$batch';
    final source = path.join(usbPath, 'APUpdate');
    final target = path.join(DCMGlobal.tempPath, 'APUpdate');

    if (!Directory(source).existsSync()) {
      return false;
    }

    Directory(target).createSync(recursive: true);
    return _copyFileOrDirectory(source, target);
  }

  bool checkDCMUpdate(String updateFolder) {
    final directory = Directory(updateFolder);
    if (!directory.existsSync()) {
      return false;
    }

    return directory.listSync(followLinks: false).isNotEmpty;
  }

  bool restoreToDefaultEvent() {
    return true;
  }

  bool isInFileList(String fileName, int contentType) {
    return lstFileInfo.any((data) =>
        data.isSameAs(strFileInfo: fileName, nContentType: contentType));
  }

  void removeFromFileList(String fileName, int contentType) {
    lstFileInfo.removeWhere((data) =>
        data.isSameAs(strFileInfo: fileName, nContentType: contentType));
  }

  bool isInCompanyList(String companyName, List<String> companyList) {
    return companyList
        .map((company) => company.toLowerCase())
        .contains(companyName.toLowerCase());
  }

  int _getPriorityFlag(int type) {
    switch (type) {
      case cDCMFILETYPE:
        return 1;
      case cDCMDAYTYPE:
        return 2;
      case cDCMMONTHTYPE:
      case cDCMCALENDARTYPE:
        return 3;
      case cDCMSETTINGTYPE:
        return 4;
      default:
        return 0;
    }
  }

  String _getRelativeExportPath(int type) {
    switch (type) {
      case cDCMMONTHTYPE:
        return 'month';
      case cDCMDAYTYPE:
        return 'day';
      case cDCMFILETYPE:
        return 'dcmfile';
      case cDCMSETTINGTYPE:
        return 'setting';
      case cDCMLAYOUTTYPE:
        return 'layout';
      case cDCMGRAPHICSTYPE:
        return 'graphics';
      case cDCMSKINSTYPE:
        return 'skins';
      case cDCMCALENDARTYPE:
        return 'calendar';
      case cDCMAHMESSAGETYPE:
        return 'ahmessage';
      case cDCMDDEOTHERTYPE:
        return 'ddeothers';
      case cDCMCONTENTLISTDATATYPE:
        return 'contentlist';
      case cDCMPREDATATYPE:
        return 'predata';
      case cDCMROOMTYPE:
        return 'room';
      case cDCMROOMEVENTTYPE:
        return 'roomevent';
      case cDCMLOBBYTYPE:
        return 'lobby';
      case cDCMDYNAMICDATATYPE:
        return 'dynamicdata';
      case cDCMRLTCONTENTTYPE:
        return 'rltcontent';
      case cDCMSITEDATATYPE:
        return 'sitecontent';
      case cDCMUPDATETYPE:
        return 'update';
      default:
        return '';
    }
  }

  String _getBasePath(int type) {
    var basePath = Utils.getBasePath(type);
    if (company.isNotEmpty &&
        (type == cIMAGETYPE ||
            type == cDCMDAYTYPE ||
            type == cDCMMONTHTYPE ||
            type == cDCMCALENDARTYPE ||
            type == cDCMFILETYPE ||
            type == cDCMSETTINGTYPE ||
            type == cDCMAHMESSAGETYPE ||
            type == cDCMROOMEVENTTYPE ||
            type == cDCMLOBBYTYPE ||
            type == cDCMSITEDATATYPE)) {
      basePath = path.join(basePath, company);
    }
    return basePath;
  }

  DateTime? _tryParseDate(String input) {
    try {
      final year = int.parse(input.substring(0, 4));
      final month = int.parse(input.substring(4, 6));
      final day = int.parse(input.substring(6, 8));
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  void _writeLogFile(String source, String dest, int result, String message) {
    final logPath = path.join(DCMGlobal.tempPath, 'updatelog.xml');
    final xmlProfile = XmlProfile.fromFile(logPath);
    if (!File(logPath).existsSync()) {
      xmlProfile.createProfile('FileList');
    } else {
      xmlProfile.loadProfile(lpszFileName: logPath, szRootItemName: 'FileList');
    }

    if (result == 0) {
      final nSec = xmlProfile.appendSection('SuccessItem');
      if (nSec != null) {
        xmlProfile.createDataNode(nSec, 'Source', source);
        xmlProfile.createDataNode(nSec, 'Destination', dest);
      }
    } else if (result == 1) {
      final nSec = xmlProfile.appendSection('ErrorItem');
      if (nSec != null) {
        xmlProfile.createDataNode(nSec, 'Source', source);
        xmlProfile.createDataNode(nSec, 'Destination', dest);
        xmlProfile.createDataNode(nSec, 'ErrorMesssage', message);
      }
    } else if (result == 2) {
      final nSec = xmlProfile.appendSection('ChecksumErrorItem');
      if (nSec != null) {
        xmlProfile.createDataNode(nSec, 'Source', source);
        xmlProfile.createDataNode(nSec, 'Destination', dest);
        xmlProfile.createDataNode(nSec, 'ErrorMesssage', message);
      }
    } else {
      final nSec = xmlProfile.appendSection('OtherErrorItem');
      if (nSec != null) {
        xmlProfile.createDataNode(nSec, 'Source', source);
        xmlProfile.createDataNode(nSec, 'Destination', dest);
        xmlProfile.createDataNode(nSec, 'ErrorMesssage', message);
      }
    }

    xmlProfile.saveProfile('FileList.xsl');
  }
}

class _TempFileInfo {
  final int contentType;
  final String sourcePath;
  final String destPath;
  final int priorityFlag;

  _TempFileInfo({
    required this.contentType,
    required this.sourcePath,
    required this.destPath,
    required this.priorityFlag,
  });
}
