import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/services/dcm_downloader.dart';
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

    if (DCMGlobal.cmsUrl.isEmpty) {
      return;
    }

    final queuePath = path.join(App().dataPath, 'download_queue.json');

    try {
      _started = true;
      unawaited(workerManager.executeGentle((_) async {
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
      stderr.writeln('DcmBackgroundService.init() failed: $e');
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
