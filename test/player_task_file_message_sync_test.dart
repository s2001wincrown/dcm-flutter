import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/cms_websocket_service.dart';
import 'package:dcm/backend/net/message_sync_service.dart';
import 'package:dcm/backend/net/player_log_impl.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queues AHMessage tasks without waiting for manifest HTTP', () async {
    final tempDir =
        Directory.systemTemp.createTempSync('dcm_task_message_sync_');
    final originalCmsUrl = AppGlobal.cmsUrl;
    final originalCmsToken = AppGlobal.cmsToken;
    final originalFtpSettingPath = AppGlobal.ftpSettingPath;
    final originalTaskLogDirty = PlayerLogImpl.bIsDirty;
    AppGlobal.cmsUrl = 'https://cms.example.com';
    AppGlobal.cmsToken = 'test-token';
    AppGlobal.ftpSettingPath = tempDir.path;
    PlayerLogImpl.bIsDirty = false;
    initFileLogger(Directory.systemTemp.path);

    final manifestRequested = Completer<String>();
    final finishManifestRequest = Completer<void>();
    CmsWebSocketService? webSocketService;

    try {
      final messageSyncService = MessageSyncService(
        postAction: (url, request, contentType) async {
          if (!manifestRequested.isCompleted) {
            manifestRequested.complete(request);
          }
          await finishManifestRequest.future;
          return (status: false, result: null);
        },
      );
      webSocketService =
          CmsWebSocketService(messageSyncService: messageSyncService);

      final task = PlayerJobItem()
        ..strJobItem = 'task-1'
        ..strSyncContent = 'morning;98'
        ..dwSyncContent = cSyncAHMESSAGE;

      await PlayerTaskFile.dispatchTask([task]);
      final request =
          await manifestRequested.future.timeout(const Duration(seconds: 5));

      expect(request, contains('<Content Name="morning" />'));
      expect(request, contains('FtpContent="$cSyncAHMESSAGE"'));

      finishManifestRequest.complete();
      await messageSyncService.waitUntilIdle();
    } finally {
      if (!finishManifestRequest.isCompleted) {
        finishManifestRequest.complete();
      }
      await webSocketService?.dispose();
      AppGlobal.cmsUrl = originalCmsUrl;
      AppGlobal.cmsToken = originalCmsToken;
      AppGlobal.ftpSettingPath = originalFtpSettingPath;
      PlayerLogImpl.bIsDirty = originalTaskLogDirty;
      await tempDir.delete(recursive: true);
    }
  });
}
