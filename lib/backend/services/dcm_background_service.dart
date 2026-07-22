import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/services/dcm_downloader.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
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

    final queuePath = path.join(App().dataPath, 'download_queue.json');
    final workerConfig = DCMGlobal.snapshot();

    try {
      _started = true;
      unawaited(workerManager.executeGentle((_) async {
        // Apply DCMGlobal config inside worker
        DCMGlobal.applyWorkerConfig(
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
        );
        dcmHttpClientFactory.dispose();

        // transfer player snapshot into worker and apply
        try {
          final snapshot = snapshotPlayer();
          // `executeGentle` worker closure inherits isolate-local args via captured variables
          // but ensure applyWorkerPlayer is invoked inside the worker context.
          applyWorkerPlayer(snapshot);
        } catch (e) {
          logE('Failed to apply player snapshot in worker: $e');
        }

        PlayerTaskFile.strPlayerTaskFile =
            path.join(DCMGlobal.settingPath, 'FTPtask.xml');
        PlayerTaskFile.init();

        //PlayerLogFile.cleanLogFile();

        await _startPollingInWorker(
          apiUrl: DCMGlobal.cmsUrl + cmsGETFILELISTURL,
          queuePath: queuePath,
          pollingIntervalMinutes: DCMGlobal.statusCheckInterval,
          token: DCMGlobal.cmsToken,
          organization: DCMGlobal.organization,
        );
      }));
    } catch (e, stack) {
      _started = false;
      logE('DcmBackgroundService.init() failed: $e');
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
