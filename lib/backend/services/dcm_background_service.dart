import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/services/dcm_downloader.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:path/path.dart' as path;

class DcmBackgroundService {
  DcmBackgroundService._();

  static final DcmBackgroundService instance = DcmBackgroundService._();

  DcmDownloader? _downloader;
  bool _started = false;

  Future<void> init() async {
    if (_started) {
      return;
    }

    if (DCMGlobal.cmsUrl.isEmpty) {
      return;
    }

    final queuePath = path.join(App().dataPath, 'download_queue.json');
    _downloader = DcmDownloader(
      apiUrl: DCMGlobal.cmsUrl + cmsGETFILELISTURL,
      queue: DcmDownloadQueue(persistencePath: queuePath),
      pollingInterval: const Duration(minutes: 5),
      buildRequestBody: _buildRequestBody,
      onProgress: _onProgress,
      onTaskComplete: _onTaskComplete,
    );

    try {
      await _downloader?.startPolling();
      _started = true;
    } catch (e, stack) {
      stderr.writeln('DcmBackgroundService.init() failed: $e');
      stderr.writeln(stack);
    }
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
