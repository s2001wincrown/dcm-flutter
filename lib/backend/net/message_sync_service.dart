import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/file_replace_service.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/services/content_downloader.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/proto/websocket_def.pb.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

typedef MessageSyncPostAction = Future<({bool status, String? result})>
    Function(
  String url,
  String request,
  String contentType,
);

typedef MessageSyncBatchDownload = Future<MessageSyncBatchResult> Function(
  List<ContentDownloadTask> tasks,
);

class MessageSyncBatchResult {
  const MessageSyncBatchResult(
      {required this.downloaded, required this.failed});

  final int downloaded;
  final int failed;
}

class MessageSyncResult {
  const MessageSyncResult({
    required this.messageName,
    required this.fileCount,
    required this.downloadedCount,
    required this.skippedCount,
    required this.failedCount,
    this.error,
    this.cancelled = false,
    this.copyFailedCount = 0,
  });

  final String messageName;
  final int fileCount;
  final int downloadedCount;
  final int skippedCount;
  final int failedCount;
  final int copyFailedCount;
  final String? error;
  final bool cancelled;

  bool get succeeded => failedCount == 0 && !cancelled && copyFailedCount == 0;
}

class _QueuedMessage {
  _QueuedMessage(this.message);

  final MessageInfo message;
  final Completer<MessageSyncResult> completer = Completer<MessageSyncResult>();
}

class MessageSyncService {
  MessageSyncService({
    MessageSyncPostAction? postAction,
    MessageSyncBatchDownload? batchDownload,
    DateTime Function()? clock,
  })  : _postAction = postAction ?? _defaultPostAction,
        _batchDownloadOverride = batchDownload,
        _clock = clock ?? DateTime.now;

  static const _contentType = 'application/xml; charset=utf-8';

  final MessageSyncPostAction _postAction;
  final MessageSyncBatchDownload? _batchDownloadOverride;
  final DateTime Function() _clock;
  final Queue<_QueuedMessage> _queue = Queue<_QueuedMessage>();
  Completer<void> _idle = Completer<void>()..complete();
  Future<void>? _drainFuture;
  ContentDownloadQueue? _downloadQueue;
  ContentDownloader? _downloader;
  bool _disposed = false;

  Future<MessageSyncResult> enqueue(MessageInfo message) {
    if (_disposed) {
      return Future<MessageSyncResult>.error(
          StateError('MessageSyncService is disposed'));
    }

    if (_idle.isCompleted) {
      _idle = Completer<void>();
    }
    final queuedMessage = _QueuedMessage(message);
    _queue.addLast(queuedMessage);
    _startDrain();
    return queuedMessage.completer.future;
  }

  Future<void> waitUntilIdle() => _drainFuture == null && _queue.isEmpty
      ? Future<void>.value()
      : _idle.future;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    while (_queue.isNotEmpty) {
      final queuedMessage = _queue.removeFirst();
      if (!queuedMessage.completer.isCompleted) {
        queuedMessage.completer.complete(_cancelled(queuedMessage.message));
      }
    }

    await _drainFuture;
    if (!_idle.isCompleted) _idle.complete();
  }

  void _startDrain() {
    if (_drainFuture != null || _disposed) return;
    final drainFuture = _drainQueue();
    _drainFuture = drainFuture;
    unawaited(drainFuture.whenComplete(() {
      if (identical(_drainFuture, drainFuture)) {
        _drainFuture = null;
      }
      if (!_disposed && _queue.isNotEmpty) {
        _startDrain();
      } else if (!_idle.isCompleted) {
        _idle.complete();
      }
    }));
  }

  Future<void> _drainQueue() async {
    while (!_disposed && _queue.isNotEmpty) {
      final queuedMessage = _queue.removeFirst();
      try {
        final result = await _syncMessage(queuedMessage.message);
        queuedMessage.completer.complete(result);
      } catch (error, stackTrace) {
        if (!queuedMessage.completer.isCompleted) {
          queuedMessage.completer.complete(
            _failed(queuedMessage.message, error.toString()),
          );
        }
        _logError('AHMessage sync failed: $error', stackTrace);
      }
    }
  }

  Future<MessageSyncResult> _syncMessage(MessageInfo message) async {
    final messageName = message.messageName.trim();
    if (messageName.isEmpty) {
      return _failed(message, 'Message command is empty');
    }

    var messageDetails = messageName.split(';');
    if (messageDetails.length < 3) {
      return _failed(message, 'Invalid message command: $messageName');
    }
    final request = PlayerTaskFile.genHTTPRequest(
        [messageDetails[3]],
        cDCMAHMESSAGETYPE,
        PlayerTaskFile.nSyncPeriod,
        cSyncAHMESSAGE,
        messageDetails[1] //DateFormat('yyyyMMddHHmmss').format(_clock()),
        );
    if (request.isEmpty) {
      return _failed(message, 'Message manifest request is empty');
    }

    final endpoint = Utils.addCMSParam(
      '${fADDSLASH(AppGlobal.cmsUrl)}$cmsGETFILELISTURL',
    );
    final response = await _postAction(endpoint, request, _contentType);
    final responseBody = response.result;
    if (!response.status || responseBody == null || responseBody.isEmpty) {
      return _failed(message, 'Message manifest request failed');
    }

    final fileInfos = _parseManifest(responseBody);
    if (fileInfos == null) {
      return _failed(message, 'Message manifest XML or signature is invalid');
    }
    await _filterMessageContent(fileInfos);

    final tasks = <ContentDownloadTask>[];
    var skippedCount = 0;
    var failedCount = 0;
    for (final fileInfo in fileInfos) {
      if (fileInfo.strShortPath.trim().isEmpty ||
          fileInfo.strDestFile.trim().isEmpty) {
        failedCount++;
        continue;
      }

      try {
        String strRemotePath = '/';
        String strDestFile = fileInfo.strDestFile;
        strDestFile = FileUtils.fixPathSeparators(strDestFile);
        String strDest = path.join(
            await PlayerPathService.getLocalPath(fileInfo.nContentType, true),
            strDestFile);
        String strRemoteFile = fileInfo.strShortPath;
        strRemoteFile = FileUtils.appendUrls(strRemotePath, strRemoteFile);
        var task = ContentDownloadTask.fromFileInfoData(
            fileInfo, AppGlobal.cmsUrl, strDest);
        logI(
            '''Add remote file '$strRemoteFile' to download queue; target file '$strDest'.''',
            syncTag);

        if (task.url.isEmpty || task.targetPath.isEmpty) {
          failedCount++;
        } else {
          tasks.add(task);
        }
      } catch (error, stackTrace) {
        failedCount++;
        _logError('Invalid AHMessage file entry: $error', stackTrace);
      }
    }

    if (tasks.isEmpty || failedCount > 0) {
      return MessageSyncResult(
        messageName: messageName,
        fileCount: fileInfos.length,
        downloadedCount: 0,
        skippedCount: skippedCount,
        failedCount: failedCount,
      );
    }

    final batchResult = await (_batchDownloadOverride ?? _downloadBatch)(tasks);
    int copyFailedCount = 0;
    if (batchResult.failed == 0) {
      copyFailedCount = await _copyMessageContent(fileInfos);
    }
    final totalFailed = failedCount + batchResult.failed;
    final result = MessageSyncResult(
      messageName: messageName,
      fileCount: fileInfos.length,
      downloadedCount: batchResult.downloaded,
      skippedCount: skippedCount,
      failedCount: totalFailed,
      copyFailedCount: copyFailedCount,
    );
    _logInfo(
      'AHMessage sync finished: $messageName; files: ${result.fileCount}; downloaded: ${result.downloadedCount}; skipped: ${result.skippedCount}; failed: ${result.failedCount}; copy file failed: ${result.copyFailedCount}; total failed: ${result.failedCount}.',
    );
    return result;
  }

  List<FileInfoData>? _parseManifest(String xml) {
    final file = XmlFilePro('PublishFileInformation');
    if (!file.loadXml(xml) || file.getSignature() != cFLSignature) {
      return null;
    }

    final fileInfos = <FileInfoData>[];
    XmlItem? item = file.getItem('FileItem');
    while (item != null) {
      final fileInfo = FileInfoData()..getFromXML(item);
      fileInfos.add(fileInfo);
      item = item.getSibling();
    }
    return fileInfos;
  }

  Future<void> _filterMessageContent(List<FileInfoData> lstFileInfo) async {
    FileReplaceService fileReplaceImpl = FileReplaceService();
    fileReplaceImpl.loadFileInfo();

    for (int i = lstFileInfo.length - 1; i >= 0; i--) {
      FileInfoData pFileInfo = lstFileInfo[i];
      logD('Found message content; \'${pFileInfo.strDestFile}\'\n');
      if (!fileReplaceImpl.isReplace(pFileInfo, false)) {
        if (pFileInfo.fileStatus == FileItemStatus.normal) {
          bool bSkip = true;
          if (pFileInfo.nContentType == cDCMAHMESSAGETYPE) {
            String strTempPath = await PlayerPathService.getLocalPath(
                pFileInfo.nContentType, true);
            String strSource = path.join(strTempPath, pFileInfo.strDestFile);
            bSkip = await File(strSource).exists();
          }

          if (bSkip) {
            logD(
                'Downloading Message Contents - FilterMessageFile; \'${pFileInfo.strDestFile}\' has been updated\n');
            lstFileInfo.removeAt(i);
          }
        }
      }
    }
  }

  Future<int> _copyMessageContent(List<FileInfoData> lstFileInfo) async {
    List<FileInfoData> lstSuccess = [];
    int nRetries = 0;
    while (lstFileInfo.isNotEmpty) {
      for (int i = lstFileInfo.length - 1; i >= 0; i--) {
        FileInfoData pFileInfo = lstFileInfo[i];
        String strTempPath =
            await PlayerPathService.getLocalPath(pFileInfo.nContentType, true);
        String strLocalPath =
            await PlayerPathService.getLocalPath(pFileInfo.nContentType);

        String strSource = path.join(strTempPath, pFileInfo.strDestFile);
        String strDestination = path.join(strLocalPath, pFileInfo.strDestFile);
        if (pFileInfo.nContentType == cDCMAHMESSAGETYPE) {
          String strBackupDestination =
              path.join(strLocalPath, 'messagebackup', pFileInfo.strDestFile);
          PlayerPathService().copyTempFileOnly(strSource, strBackupDestination);
        }

        if (await PlayerPathService().copyTempFile(strSource, strDestination)) {
          lstSuccess.add(pFileInfo);
          lstFileInfo.removeAt(i);
        }
      }

      nRetries++;
      if (lstFileInfo.isEmpty || nRetries > AppGlobal.tempFileCopyRetries) {
        break;
      }
      //Doze(1000);
    }
    if (lstSuccess.isNotEmpty) {
      //Load File List
      FileReplaceService fileReplaceImpl = FileReplaceService();
      fileReplaceImpl.loadFileInfo();

      // copy all downloaded  files
      //CObList lstDownloaded;
      for (var iter in lstSuccess) {
        fileReplaceImpl.addDownloadFile(iter);
      }
      fileReplaceImpl.saveFileInfo();
    }

    return lstFileInfo.length;
  }

  bool _isDownloadable(FileInfoData fileInfo, DateTime now) {
    if (fileInfo.fileStatus == FileItemStatus.skip ||
        fileInfo.fileStatus == FileItemStatus.remove ||
        fileInfo.fileStatus == FileItemStatus.copied) {
      return false;
    }
    if (fileInfo.dtEffDateFr != null && now.isBefore(fileInfo.dtEffDateFr!)) {
      return false;
    }
    if (fileInfo.dtEffDateTo != null && now.isAfter(fileInfo.dtEffDateTo!)) {
      return false;
    }
    return true;
  }

  Future<MessageSyncBatchResult> _downloadBatch(
      List<ContentDownloadTask> tasks) async {
    if (AppGlobal.appDataPath.isEmpty) {
      throw StateError('AppGlobal.appDataPath is empty');
    }
    final queue = _downloadQueue ??= ContentDownloadQueue(
      persistencePath:
          path.join(AppGlobal.appDataPath, 'message_sync_download_queue.json'),
    );
    final downloader = _downloader ??= ContentDownloader(
      apiUrl: AppGlobal.cmsUrl,
      queue: queue,
      maxRetries: AppGlobal.fileTransferRetries,
      reportToPlayerLog: false,
    );
    final taskIds = tasks.map((task) => task.id).toList(growable: false);
    final taskUrls = tasks.map((task) => task.url).toSet();
    try {
      await queue.load();
      final failedBefore = queue.finalFailedTaskCount;
      for (final queuedTask in queue.tasks) {
        if (queuedTask.status == ContentDownloadStatus.running) {
          queuedTask.status = ContentDownloadStatus.pending;
        }
      }
      queue.tasks.removeWhere((task) => taskUrls.contains(task.url));
      await queue.save();
      await downloader.addTasksToQueue(tasks);
      final downloaded = queue.tasks
          .where((task) =>
              taskIds.contains(task.id) &&
              task.status == ContentDownloadStatus.success)
          .length;
      return MessageSyncBatchResult(
        downloaded: downloaded,
        failed: queue.finalFailedTaskCount - failedBefore,
      );
    } finally {
      queue.removeTasksByIds(taskIds);
      await queue.save();
    }
  }

  Future<bool> _isAlreadyCurrent(ContentDownloadTask task) async {
    final target = File(task.targetPath);
    if (!await target.exists()) return false;
    final modified = await target.lastModified();
    final remoteModified = task.remoteModified;
    return remoteModified == null || !modified.isBefore(remoteModified);
  }

  static Future<({bool status, String? result})> _defaultPostAction(
    String url,
    String request,
    String contentType,
  ) =>
      PlayerLogFile.httpPostAction(url, request, contentType);

  MessageSyncResult _failed(MessageInfo message, String error) {
    _logWarning('AHMessage sync failed for ${message.messageName}: $error');
    return MessageSyncResult(
      messageName: message.messageName,
      fileCount: 0,
      downloadedCount: 0,
      skippedCount: 0,
      failedCount: 1,
      error: error,
    );
  }

  MessageSyncResult _cancelled(MessageInfo message) => MessageSyncResult(
        messageName: message.messageName,
        fileCount: 0,
        downloadedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        cancelled: true,
      );

  void _logError(String message, [StackTrace? stackTrace]) {
    try {
      logE(message, stackTrace);
    } catch (_) {}
  }

  void _logWarning(String message) {
    try {
      logW(message, syncTag);
    } catch (_) {}
  }

  void _logInfo(String message) {
    try {
      logI(message, syncTag);
    } catch (_) {}
  }
}
