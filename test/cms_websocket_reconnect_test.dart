import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/cms_websocket_service.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  test('reconnects after the CMS server closes the WebSocket', () async {
    final originalCmsUrl = AppGlobal.cmsUrl;
    final originalCmsToken = AppGlobal.cmsToken;
    AppGlobal.cmsUrl = 'http://cms.example.com';
    AppGlobal.cmsToken = 'test-token';
    initFileLogger(Directory.systemTemp.path);

    final secondConnection = Completer<void>();
    HttpServer? server;
    CmsWebSocketService? service;
    var connectionCount = 0;

    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final localServer = server;
      localServer.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        connectionCount++;
        if (connectionCount == 1) {
          await socket.close();
        } else if (!secondConnection.isCompleted) {
          secondConnection.complete();
        }
      });

      service = CmsWebSocketService(
        channelFactory: (_) => IOWebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:${localServer.port}/ws'),
        ),
        initialReconnectDelay: const Duration(milliseconds: 10),
        reconnectJitter: Duration.zero,
      );

      await service.connect();
      await secondConnection.future.timeout(const Duration(seconds: 5));

      expect(connectionCount, greaterThanOrEqualTo(2));
      expect(service.connectionState, CmsConnectionState.connected);
    } finally {
      await service?.dispose();
      await server?.close(force: true);
      AppGlobal.cmsUrl = originalCmsUrl;
      AppGlobal.cmsToken = originalCmsToken;
    }
  });

  test('retries when the WebSocket handshake does not complete', () async {
    final originalCmsUrl = AppGlobal.cmsUrl;
    final originalCmsToken = AppGlobal.cmsToken;
    AppGlobal.cmsUrl = 'http://cms.example.com';
    AppGlobal.cmsToken = 'test-token';
    initFileLogger(Directory.systemTemp.path);

    final secondConnection = Completer<void>();
    HttpServer? server;
    CmsWebSocketService? service;
    var connectionCount = 0;

    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final localServer = server;
      localServer.listen((request) async {
        connectionCount++;
        if (connectionCount == 1) {
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        if (!secondConnection.isCompleted) {
          secondConnection.complete();
        }
        socket.listen((_) {});
      });

      service = CmsWebSocketService(
        channelFactory: (_) => IOWebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:${localServer.port}/ws'),
        ),
        initialReconnectDelay: const Duration(milliseconds: 10),
        reconnectJitter: Duration.zero,
        connectionTimeout: const Duration(milliseconds: 50),
      );

      await service.connect();
      await secondConnection.future.timeout(const Duration(seconds: 5));

      expect(connectionCount, greaterThanOrEqualTo(2));
      expect(service.connectionState, CmsConnectionState.connected);
    } finally {
      await service?.dispose();
      await server?.close(force: true);
      AppGlobal.cmsUrl = originalCmsUrl;
      AppGlobal.cmsToken = originalCmsToken;
    }
  });
}
