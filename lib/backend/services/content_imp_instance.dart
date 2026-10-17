import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/services/content_file_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

enum USBImportStatus {
  notImport,
  importFailed,
  importSuccess,
  generatedFileList,
  filteredFileList,
  copyingTempFile,
  copiedTempFile,
  updatedPlaylist,
  contentClear,
  tempFileClear,
}

class USBImportTask {
  String driver;
  String batch;
  String taskFile;
  USBImportStatus status;
  int retries;
  int contentImpl;

  USBImportTask({
    required this.driver,
    required this.batch,
    this.taskFile = '',
    this.status = USBImportStatus.notImport,
    this.retries = 0,
    this.contentImpl = 0,
  });
}

class USBImportDriver {
  final String drive;
  final String batch;

  USBImportDriver(this.drive, this.batch);
}

class ContentImpInstance {
  static final List<USBImportTask> _taskQueue = [];
  static bool _isProcessing = false;
  static bool _stopRequested = false;

  static bool addTask(USBImportTask task) {
    _taskQueue.add(task);
    _startProcessing();
    return true;
  }

  static bool addTaskWithData(
    String driver,
    String batch,
    String taskFile,
    USBImportStatus status,
    int retries, {
    int contentImpl = 0,
  }) {
    return addTask(USBImportTask(
      driver: driver,
      batch: batch,
      taskFile: taskFile,
      status: status,
      retries: retries,
      contentImpl: contentImpl,
    ));
  }

  static void removeAllTask() {
    _taskQueue.clear();
  }

  static void start() {
    _stopRequested = false;
    _startProcessing();
  }

  static void stop() {
    _stopRequested = true;
  }

  static void startImport() {
    start();
  }

  static void _startProcessing() {
    if (_isProcessing) {
      return;
    }

    _processQueue();
  }

  static Future<void> _processQueue() async {
    _isProcessing = true;
    try {
      while (!_stopRequested) {
        final task = _dequeueTask();
        if (task == null) {
          break;
        }

        await _processTask(task);
        if (_stopRequested) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _isProcessing = false;
    }
  }

  static USBImportTask? _dequeueTask() {
    if (_taskQueue.isEmpty) {
      return null;
    }
    return _taskQueue.removeAt(0);
  }

  static Future<void> processTask(
    String driver,
    String batch,
    String taskFile,
    USBImportStatus status,
    int retries, {
    int contentImpl = 0,
  }) async {
    _isProcessing = true;
    try {
      await _processTask(USBImportTask(
        driver: driver,
        batch: batch,
        taskFile: taskFile,
        status: status,
        retries: retries,
        contentImpl: contentImpl,
      ));
    } finally {
      _isProcessing = false;
    }
  }

  static Future<void> _processTask(USBImportTask task) async {
    logI(
        'Start importing: Driver=${task.driver}; batch=${task.batch}; status=${task.status}; retries=${task.retries}');
    final importFolder = await _getImportFolder(task.driver);
    if (importFolder == null) {
      logI('Import folder not found for ${task.driver}');
      return;
    }

    final companyPath = path.join(AppGlobal.tempPath, task.batch);
    final usbPath = path.join(importFolder, task.batch);
    final fileImpl = ContentFileImpl(
      sourcePath: companyPath,
      batch: task.batch,
      usbPath: usbPath,
    );

    if (task.status.index < USBImportStatus.generatedFileList.index) {
      bool success = false;
      if (task.status == USBImportStatus.generatedFileList) {
        success = await fileImpl.loadFileList(generated: true);
      } else {
        success = await fileImpl.loadFileList(generated: false);
        if (success) {
          task.status = USBImportStatus.generatedFileList;
          await _writeTaskFile(task);
        }
      }
      if (!success) {
        logE('Failed to load file list for batch ${task.batch}');
        return;
      }
      if (task.status.index < USBImportStatus.filteredFileList.index) {
        if (fileImpl.filterFileList()) {
          task.status = USBImportStatus.filteredFileList;
          await _writeTaskFile(task);
        }
      }
    }

    if (task.status.index < USBImportStatus.updatedPlaylist.index) {
      bool copySuccess = true;
      while (task.retries < AppGlobal.copyFileRetries) {
        if (task.status.index > USBImportStatus.filteredFileList.index &&
            task.status.index < USBImportStatus.copiedTempFile.index) {
          copySuccess = await fileImpl.loadFileList(generated: true);
          fileImpl.filterDownloadedFile();
        }

        if (task.status.index < USBImportStatus.copiedTempFile.index) {
          task.status = USBImportStatus.copyingTempFile;
          await _writeTaskFile(task);

          copySuccess = await fileImpl.copyToTempFolder();
          if (copySuccess) {
            copySuccess = await fileImpl.getContentListAndChecksum(companyPath);
            if (copySuccess) {
              task.status = USBImportStatus.copiedTempFile;
              await _writeTaskFile(task);
            }
          }
        }

        if (copySuccess) {
          final companies = <String>[];
          copySuccess = await fileImpl.copyMonthFile(companyPath, companies) &&
              copySuccess;
          if (copySuccess) {
            copySuccess = await fileImpl.loadFileList(generated: true);
            if (copySuccess) {
              fileImpl.getEventList();
              copySuccess = await fileImpl.copyTempFile();
              fileImpl.saveDownloadFileList();
              if (copySuccess) {
                task.status = USBImportStatus.updatedPlaylist;
                await _writeTaskFile(task);
              }
            }
          }
        }

        if (copySuccess || task.retries >= AppGlobal.copyFileRetries) {
          break;
        }

        task.retries++;
        await _writeTaskFile(task);
      }

      if (!copySuccess) {
        logE(
            'Import failed for batch ${task.batch} after ${task.retries} retries');
      }
    }

    final updateLog = path.join(AppGlobal.tempPath, 'updatelog.xml');
    await _copyFileIfExists(
        updateLog, path.join(AppGlobal.logPath, 'updatelog.xml'));
    final usbLogPath = path.join(AppGlobal.logPath, 'PlayLog');
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    await _copyFileIfExists(
        updateLog, path.join(usbLogPath, 'USB$timestamp.xml'));

    await _removeFolder(companyPath);
    await _deleteUpdateLog(updateLog);
    await _deleteFile(
        path.join(AppGlobal.settingPath, 'Filelog', '${task.batch}.xml'));
    await _clearTempFolder(task.batch);
    ContentFileImpl.empty().copyDCMUpdateFile(task.driver, task.batch);

    if (task.status == USBImportStatus.updatedPlaylist) {
      final sourceVersionFile =
          path.join('${task.driver}:', task.batch, 'Version.txt');
      await _writeVersionFile(sourceVersionFile);
      task.status = USBImportStatus.importSuccess;
      await _writeTaskFile(task);
      logI('Import successful for batch ${task.batch}');
    }
  }

  static Future<bool> folderCheckForImport() async {
    try {
      await Directory(AppGlobal.settingPath).create(recursive: true);
      return true;
    } catch (e) {
      logE('Access folder ${AppGlobal.settingPath} failure: $e');
      return false;
    }
  }

  static Future<bool> reimportTaskCheck() async {
    if (!await folderCheckForImport()) {
      return false;
    }

    final index = await getLatestTaskFile();
    final taskFile = path.join(
      AppGlobal.settingPath,
      index == 0 ? 'DCMtask.xml' : 'DCMtask$index.xml',
    );
    if (!await File(taskFile).exists()) {
      return false;
    }

    final file = XmlFilePro('DCMTask');
    if (!file.load(taskFile, null, false)) {
      return false;
    }

    final xmlItem = file.getItem('USBImport');
    if (xmlItem == null) {
      return false;
    }

    final status = _statusFromInt(xmlItem.getItemValueI('Status'));
    final batch = xmlItem.getItemValue('Batch');
    final driver = xmlItem.getItemValue('Driver');
    if (status != USBImportStatus.importSuccess ||
        batch.isEmpty ||
        driver.isEmpty) {
      return false;
    }

    final sourceVersionFile = path.join('$driver:', batch, 'Version.txt');
    if (!await File(sourceVersionFile).exists()) {
      return false;
    }

    final version = await File(sourceVersionFile).readAsString();
    if (version.trim().isEmpty) {
      return false;
    }

    final importedVersionFile = path.join(AppGlobal.settingPath, 'Version.txt');
    final importedVersion = await File(importedVersionFile).exists()
        ? await File(importedVersionFile).readAsString()
        : '';
    if (version == importedVersion.trim()) {
      try {
        if (await File(importedVersionFile).exists()) {
          await File(importedVersionFile).delete();
        }
        await File(taskFile).delete();
      } catch (_) {}
      return true;
    }
    return false;
  }

  static Future<int> getLatestTaskFile() async {
    final dir = Directory(AppGlobal.settingPath);
    if (!await dir.exists()) return 0;

    final regex = RegExp(r'^DCMtask(\d+)\.xml\$', caseSensitive: false);
    int maxIndex = 0;
    var taskFiles = await dir.list(followLinks: false).toList();
    for (final entity in taskFiles) {
      if (entity is File) {
        final name = path.basename(entity.path);
        if (name.toLowerCase() == 'dcmtask.xml') {
          continue;
        }
        final match = regex.firstMatch(name);
        if (match != null) {
          final value = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (value > maxIndex) {
            maxIndex = value;
          }
        }
      }
    }
    return maxIndex;
  }

  static Future<USBImportDriver?> getImportDriver() async {
    for (var i = 0; i < 26; i++) {
      final driveLetter = String.fromCharCode('A'.codeUnitAt(0) + i);
      final desktopIni = path.join('$driveLetter:\\', 'desktop.ini');
      if (!await File(desktopIni).exists()) {
        continue;
      }
      final ini = IniFile(desktopIni);
      final platformFolder =
          ini.readString('.ShellClassInfo', 'DCMPlatformFolder');
      if (platformFolder.isEmpty) {
        continue;
      }
      final importFolder = path.join('$driveLetter:\\', platformFolder);
      if (await Directory(importFolder).exists()) {
        return USBImportDriver(driveLetter, platformFolder);
      }
    }
    return null;
  }

  static Future<String?> _getImportFolder(String driveLetter) async {
    final desktopIni = path.join('$driveLetter:\\', 'desktop.ini');
    if (!await File(desktopIni).exists()) {
      return null;
    }
    final ini = IniFile(desktopIni);
    final platformFolder =
        ini.readString('.ShellClassInfo', 'DCMPlatformFolder');
    if (platformFolder.isEmpty) {
      return null;
    }
    final importFolder = path.join('$driveLetter:\\', platformFolder);
    return await Directory(importFolder).exists() ? importFolder : null;
  }

  static Future<bool> _removeFolder(String folderPath) async {
    try {
      final directory = Directory(folderPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _writeTaskFile(USBImportTask task) async {
    if (task.taskFile.isEmpty) {
      return false;
    }
    final xmlFile = XmlFilePro('DCMTask');
    if (await File(task.taskFile).exists()) {
      xmlFile.load(task.taskFile, null, false);
    }
    XmlItem? xmlItem = xmlFile.getItem('USBImport');
    xmlItem ??= xmlFile.root().addItem('USBImport');
    if (xmlItem == null) {
      return false;
    }
    xmlItem.setItemValue('Batch', task.batch, XiType.element);
    xmlItem.setItemValue('Version', '', XiType.element);
    xmlItem.setItemValue('Driver', task.driver, XiType.element);
    xmlItem.setItemValue('Retries', task.retries.toString(), XiType.element);
    xmlItem.setItemValue('Status',
        USBImportStatus.values.indexOf(task.status).toString(), XiType.element);
    return xmlFile.save(task.taskFile);
  }

  static Future<bool> _clearTempFolder(String currentBatch) async {
    final tempDir = Directory(AppGlobal.tempPath);
    if (!await tempDir.exists()) {
      return true;
    }
    final guidRegex = RegExp(
        r'^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$');
    for (final entry in tempDir.listSync(followLinks: false)) {
      if (entry is Directory) {
        final name = path.basename(entry.path);
        if (name.toLowerCase() == currentBatch.toLowerCase()) {
          continue;
        }
        if (guidRegex.hasMatch(name)) {
          try {
            await entry.delete(recursive: true);
          } catch (_) {}
        }
      }
    }
    return true;
  }

  static Future<bool> _deleteUpdateLog(String updateLog) async {
    final tmpPath = '$updateLog.tmp';
    try {
      await File(updateLog).delete();
    } catch (_) {
      try {
        if (await File(updateLog).exists()) {
          await File(updateLog).rename(tmpPath);
        }
      } catch (_) {}
    }
    try {
      await File(tmpPath).delete();
    } catch (_) {}
    return true;
  }

  static Future<bool> _writeVersionFile(String sourceVersionFile) async {
    try {
      if (!await File(sourceVersionFile).exists()) {
        return false;
      }
      final targetVersionFile = path.join(AppGlobal.settingPath, 'Version.txt');
      await Directory(path.dirname(targetVersionFile)).create(recursive: true);
      await File(sourceVersionFile).copy(targetVersionFile);
      return true;
    } catch (e) {
      logE('WriteVersionFile failed: $e');
      return false;
    }
  }

  static Future<void> _copyFileIfExists(
      String source, String destination) async {
    try {
      if (await File(source).exists()) {
        await Directory(path.dirname(destination)).create(recursive: true);
        await File(source).copy(destination);
      }
    } catch (_) {}
  }

  static Future<bool> _deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static USBImportStatus _statusFromInt(int value) {
    if (value < 0) {
      return USBImportStatus.notImport;
    }
    if (value >= USBImportStatus.values.length) {
      return USBImportStatus.notImport;
    }
    return USBImportStatus.values[value];
  }
}
