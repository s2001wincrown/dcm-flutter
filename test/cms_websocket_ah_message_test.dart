import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/cms_websocket_service.dart';
import 'package:dcm/backend/net/message_sync_service.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/proto/websocket_def.pb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  test('dispatches CMD_AH_MESSAGE payload to the sync queue', () async {
    final tempDir = Directory.systemTemp.createTempSync('dcm_ah_ws_test_');
    final originalCmsUrl = AppGlobal.cmsUrl;
    final originalCmsToken = AppGlobal.cmsToken;
    final originalFtpSettingPath = AppGlobal.ftpSettingPath;
    AppGlobal.cmsUrl = 'http://cms.example.com';
    AppGlobal.cmsToken = 'test-token';
    AppGlobal.ftpSettingPath = tempDir.path;
    initFileLogger(Directory.systemTemp.path);

    final requestStarted = Completer<void>();
    String? requestBody;
    HttpServer? server;
    CmsWebSocketService? webSocketService;
    try {
      final messageSyncService = MessageSyncService(
        postAction: (url, request, contentType) async {
          requestBody = request;
          if (!requestStarted.isCompleted) requestStarted.complete();
          return (status: false, result: null);
        },
        batchDownload: (tasks) async =>
            const MessageSyncBatchResult(downloaded: 0, failed: 0),
      );

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final localServer = server;
      localServer.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        final wrapper = MessageWrapper(
          command: CommandType.CMD_AH_MESSAGE,
          payload: MessageInfo(
            messageId: 98,
            messageName: 'daily-notice',
            task: 'websocket-message-test',
          ).writeToBuffer(),
        );
        socket.add(Uint8List.fromList(wrapper.writeToBuffer()));
      });

      webSocketService = CmsWebSocketService(
        channelFactory: (_) => IOWebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:${localServer.port}/ws'),
        ),
        messageSyncService: messageSyncService,
      );
      await webSocketService.connect();
      await requestStarted.future.timeout(const Duration(seconds: 5));
      await messageSyncService.waitUntilIdle();

      expect(requestBody, contains('<Content Name="daily-notice" />'));
    } finally {
      await webSocketService?.dispose();
      await server?.close(force: true);
      AppGlobal.cmsUrl = originalCmsUrl;
      AppGlobal.cmsToken = originalCmsToken;
      AppGlobal.ftpSettingPath = originalFtpSettingPath;
      await tempDir.delete(recursive: true);
    }
  });
}
