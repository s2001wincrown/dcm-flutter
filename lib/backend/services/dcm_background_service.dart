import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/content_sync_service.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/services/dcm_downloader.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:worker_manager/worker_manager.dart';

class DcmBackgroundService {
  DcmBackgroundService._();

  static final DcmBackgroundService instance = DcmBackgroundService._();

  bool _started = false;

  Future<void> init() async {
    if (_started) {
      return;
    }

    if (!DCMGlobal.autoContentUpdate) {
      logW(
          '''Auto sync data width CMS is disabled, please check setting: 'Global.AutoContentUpdate'.''');
      return;
    }

    if (DCMGlobal.cmsUrl.isEmpty) {
      logW(
          '''Initialization settings failed for auto sync data, please check file 'server.txt' or settings in Server.''');
      return;
    }

    final workerConfig = DCMGlobal.snapshot();
    final snapshot = snapshotPlayer();
    // 1. 获取主 Isolate 的 Token
    final rootIsolateToken = RootIsolateToken.instance;

    try {
      _started = true;
      unawaited(workerManager.executeGentle((_) async {
        if (rootIsolateToken != null) {
          BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        }
        //WidgetsFlutterBinding.ensureInitialized();
        // Apply DCMGlobal config inside worker
        DCMGlobal.applyWorkerConfig(
          cscPath: workerConfig['cscPath']?.toString(),
          appDataPath: workerConfig['appDataPath']?.toString(),
          ddServerPath: workerConfig['ddServerPath']?.toString(),
          openPath: workerConfig['openPath']?.toString(),
          imagePath: workerConfig['imagePath']?.toString(),
          vcdPath: workerConfig['vcdPath']?.toString(),
          ppPath: workerConfig['ppPath']?.toString(),
          flashPath: workerConfig['flashPath']?.toString(),
          webPath: workerConfig['webPath']?.toString(),
          textPath: workerConfig['textPath']?.toString(),
          imageSettingPath: workerConfig['imageSettingPath']?.toString(),
          clockPath: workerConfig['clockPath']?.toString(),
          weatherPath: workerConfig['weatherPath']?.toString(),
          siteContentPath: workerConfig['siteContentPath']?.toString(),
          layoutImagePath: workerConfig['layoutImagePath']?.toString(),
          skinsPath: workerConfig['skinsPath']?.toString(),
          rltContentPath: workerConfig['rltContentPath']?.toString(),
          dynamicDataPath: workerConfig['dynamicDataPath']?.toString(),
          skinFile: workerConfig['skinFile']?.toString(),
          graphicsPath: workerConfig['graphicsPath']?.toString(),
          dayPath: workerConfig['dayPath']?.toString(),
          ahPlaylistPath: workerConfig['ahPlaylistPath']?.toString(),
          monthPath: workerConfig['monthPath']?.toString(),
          calendarPath: workerConfig['calendarPath']?.toString(),
          settingPath: workerConfig['settingPath']?.toString(),
          ftpSettingPath: workerConfig['ftpSettingPath']?.toString(),
          tempPath: workerConfig['tempPath']?.toString(),
          logPath: workerConfig['logPath']?.toString(),
          contentListPath: workerConfig['contentListPath']?.toString(),
          linkagePath: workerConfig['linkagePath']?.toString(),
          ddeOthersPath: workerConfig['ddeOthersPath']?.toString(),
          ddeDataPath: workerConfig['ddeDataPath']?.toString(),
          ddeXmlPath: workerConfig['ddeXmlPath']?.toString(),
          messagePath: workerConfig['messagePath']?.toString(),
          roomEventPath: workerConfig['roomEventPath']?.toString(),
          roomPath: workerConfig['roomPath']?.toString(),
          lobbyPath: workerConfig['lobbyPath']?.toString(),
          preDataPath: workerConfig['preDataPath']?.toString(),
          updateFilePath: workerConfig['updateFilePath']?.toString(),
          availableACUStart: workerConfig['availableACUStart']?.toString(),
          availableACUEnd: workerConfig['availableACUEnd']?.toString(),
          cmsUrl: workerConfig['cmsUrl']?.toString(),
          cmsToken: workerConfig['cmsToken']?.toString(),
          organization: workerConfig['organization']?.toString(),
          enableTaskCheck: workerConfig['enableTaskCheck'] as bool?,
          autoContentUpdate: workerConfig['autoContentUpdate'] as bool?,
          fileTransferRetries: workerConfig['fileTransferRetries'] as int?,
          taskTransferRetries: workerConfig['taskTransferRetries'] as int?,
          tempFileCopyRetries: workerConfig['tempFileCopyRetries'] as int?,
          logUploadInterval: workerConfig['logUploadInterval'] as int?,
          logUploadPeriod: workerConfig['logUploadPeriod'] as int?,
          statusCheckInterval: workerConfig['statusCheckInterval'] as int?,
          httpRetryTimes: workerConfig['httpRetryTimes'] as int?,
          fileIntegrityCheck: workerConfig['fileIntegrityCheck'] as bool?,
          deleteContentIfFTPFail:
              workerConfig['deleteContentIfFTPFail'] as bool?,
          retryInterval: workerConfig['retryInterval'] as int?,
          autoSyncTime: workerConfig['autoSyncTime'] as bool?,
        );
        dcmHttpClientFactory.dispose();

        // transfer player snapshot into worker and apply
        try {
          // `executeGentle` worker closure inherits isolate-local args via captured variables
          // but ensure applyWorkerPlayer is invoked inside the worker context.
          applyWorkerPlayer(snapshot);

          logI(
              'starting workerManager: ${globalPlayer.strUniqueName} - ${DCMGlobal.statusCheckInterval}',
              syncTag);

          PlayerPathService().init();
          PlayerTaskFile.strPlayerTaskFile =
              path.join(DCMGlobal.ftpSettingPath, 'synctask.xml');
          PlayerTaskFile.init();
          await ContentSyncService().init();
          await ContentSyncService().startPolling();
        } catch (e) {
          logE('Failed to apply player snapshot in worker: $e', syncTag);
        }
      }));
    } catch (e, stack) {
      _started = false;
      logE('DcmBackgroundService.init() failed: $e', syncTag);
      stderr.writeln(stack);
    }
  }

  Future<void> _startPollingInWorker({
    required String apiUrl,
    required String queuePath,
    required int pollingIntervalMinutes,
    required String token,
    required String organization,
  }) async {
    final downloader = DcmDownloader(
      apiUrl: apiUrl,
      queue: DcmDownloadQueue(persistencePath: queuePath),
      maxRetries: DCMGlobal.fileTransferRetries,
      pollingInterval: Duration(minutes: pollingIntervalMinutes),
      buildRequestBody: () async =>
          _buildRequestBodyForWorker(token, organization),
    );
    await downloader.startPolling();
  }

  Future<String> _buildRequestBodyForWorker(
      String token, String organization) async {
    final xml = XmlFile('PublishFileInformation');
    xml.setItemValue('Token', token);
    xml.setItemValue('Organization', organization);
    return xml.export();
  }

  Future<String> _buildRequestBody() async {
    final xml = XmlFile('PublishFileInformation');
    xml.setItemValue('Token', DCMGlobal.cmsToken);
    xml.setItemValue('Organization', DCMGlobal.organization);
    return xml.export();
  }

  void _onProgress(DcmDownloadTask task) {
    // keep a lightweight log entry for background progress
    stderr.writeln(
        'DcmDownloader progress: ${task.title} (${task.downloaded}/${task.remoteSize})');
  }

  void _onTaskComplete(DcmDownloadTask task) {
    stderr.writeln(
        'DcmDownloader completed task ${task.id} status=${task.status.name}');
  }
}
