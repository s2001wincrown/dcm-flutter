import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/message_sync_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/proto/websocket_def.pb.dart';
import 'package:flutter_test/flutter_test.dart';

const _signature =
    'DCM FTP Manager Version 1.00 - Publish File Information List';

String _manifest({String? fileName}) {
  final fileItem = fileName == null
      ? ''
      : '''<FileItem m_Status="0" m_dtEffDateFr="01/01/2020 00:00:00" m_dtEffDateTo="31/12/2099 23:59:59" m_dwFileSize="-1" m_nContentType="108" m_nTransferType="1" m_strDestFile="$fileName.xml" m_strFileTitle="$fileName" m_strMD5="" m_strSHA1="" m_strShortPath="api/ahMessages/$fileName?dt=Original&amp;type=xml" m_tmFileCreate="" m_tmFileModify="" m_uiID="1" uuid=""/>''';
  return '''<?xml version="1.0" encoding="utf-8"?>
<PublishFileInformation Signature="$_signature">$fileItem</PublishFileInformation>''';
}

void main() {
  group('MessageSyncService', () {
    late Directory tempDir;
    late String originalCmsUrl;
    late String originalCmsToken;
    late String originalOrganization;
    late String originalMessagePath;
    late String originalFtpSettingPath;
    late int originalSyncPeriod;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dcm_message_sync_test_');
      originalCmsUrl = AppGlobal.cmsUrl;
      originalCmsToken = AppGlobal.cmsToken;
      originalOrganization = AppGlobal.organization;
      originalMessagePath = AppGlobal.messagePath;
      originalFtpSettingPath = AppGlobal.ftpSettingPath;
      originalSyncPeriod = PlayerTaskFile.nSyncPeriod;
      AppGlobal.cmsUrl = 'https://cms.example.com/base';
      AppGlobal.cmsToken = 'test-token';
      AppGlobal.organization = 'test-org';
      AppGlobal.messagePath = tempDir.path;
      AppGlobal.ftpSettingPath = tempDir.path;
      PlayerTaskFile.nSyncPeriod = 9;
      initFileLogger(Directory.systemTemp.path);
    });

    tearDown(() {
      AppGlobal.cmsUrl = originalCmsUrl;
      AppGlobal.cmsToken = originalCmsToken;
      AppGlobal.organization = originalOrganization;
      AppGlobal.messagePath = originalMessagePath;
      AppGlobal.ftpSettingPath = originalFtpSettingPath;
      PlayerTaskFile.nSyncPeriod = originalSyncPeriod;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('posts manifest request and maps all returned file entries', () async {
      var postCount = 0;
      final service = MessageSyncService(
        clock: () => DateTime(2026, 9, 30, 12, 34, 56),
        statusAction: (task, actionStatus, actionDetails) async {},
        postAction: (url, request, contentType) async {
          postCount++;
          expect(
            url,
            'https://cms.example.com/base/api/pm/players/filelist?o=test-org&authentication-token=test-token',
          );
          expect(contentType, 'application/xml; charset=utf-8');
          expect(request, contains('ContentType="$cDCMAHMESSAGETYPE"'));
          expect(request, contains('FtpPeriod="9"'));
          expect(request, contains('FtpContent="$cSyncAHMESSAGE"'));
          expect(request, contains('strTask="20260930123456"'));
          expect(request, contains('<Content Name="morning" />'));
          return (status: true, result: _manifest(fileName: 'morning'));
        },
        batchDownload: (tasks) async {
          expect(tasks, hasLength(1));
          expect(
            tasks.single.url,
            'https://cms.example.com/base/api/ahMessages/morning?dt=Original&type=xml',
          );
          expect(tasks.single.targetPath, endsWith('morning.xml'));
          expect(tasks.single.contentType, cDCMAHMESSAGETYPE);
          final downloadedFile = File(tasks.single.targetPath);
          await downloadedFile.parent.create(recursive: true);
          await downloadedFile.writeAsString('downloaded');
          return const MessageSyncBatchResult(downloaded: 1, failed: 0);
        },
      );

      final result = await service.enqueue(MessageInfo(messageName: 'morning'));

      expect(postCount, 1);
      expect(result.succeeded, isTrue);
      expect(result.fileCount, 1);
      expect(result.downloadedCount, 1);
      await service.dispose();
    });

    test('processes messages serially and continues after a failed batch',
        () async {
      final firstBatchStarted = Completer<void>();
      final finishFirstBatch = Completer<void>();
      final startedBatches = <String>[];
      var activeBatches = 0;
      var maxActiveBatches = 0;

      final service = MessageSyncService(
        statusAction: (task, actionStatus, actionDetails) async {},
        postAction: (url, request, contentType) async {
          final name = request.contains('Name="first"') ? 'first' : 'second';
          return (status: true, result: _manifest(fileName: name));
        },
        batchDownload: (tasks) async {
          activeBatches++;
          if (activeBatches > maxActiveBatches) {
            maxActiveBatches = activeBatches;
          }
          final fileName = tasks.single.title;
          startedBatches.add(fileName);
          try {
            if (fileName == 'first') {
              firstBatchStarted.complete();
              await finishFirstBatch.future;
              throw StateError('simulated download failure');
            }
            final downloadedFile = File(tasks.single.targetPath);
            await downloadedFile.parent.create(recursive: true);
            await downloadedFile.writeAsString('downloaded');
            return const MessageSyncBatchResult(downloaded: 1, failed: 0);
          } finally {
            activeBatches--;
          }
        },
      );

      final first = service.enqueue(MessageInfo(messageName: 'first'));
      final second = service.enqueue(MessageInfo(messageName: 'second'));
      await firstBatchStarted.future;
      expect(startedBatches, ['first']);

      finishFirstBatch.complete();
      final results = await Future.wait([first, second]);
      await service.waitUntilIdle();

      expect(results.first.succeeded, isFalse);
      expect(results.first.error, contains('simulated download failure'));
      expect(results.last.succeeded, isTrue);
      expect(startedBatches, ['first', 'second']);
      expect(maxActiveBatches, 1);
      await service.dispose();
    });

    test('treats an empty manifest as a completed message', () async {
      var batchDownloadCalled = false;
      final service = MessageSyncService(
        statusAction: (task, actionStatus, actionDetails) async {},
        postAction: (url, request, contentType) async =>
            (status: true, result: _manifest()),
        batchDownload: (tasks) async {
          batchDownloadCalled = true;
          return const MessageSyncBatchResult(downloaded: 0, failed: 0);
        },
      );

      final result = await service.enqueue(MessageInfo(messageName: 'empty'));

      expect(result.succeeded, isTrue);
      expect(result.fileCount, 0);
      expect(batchDownloadCalled, isFalse);
      await service.dispose();
    });

    test('continues queue when the manifest request fails', () async {
      final requestedNames = <String>[];
      final service = MessageSyncService(
        statusAction: (task, actionStatus, actionDetails) async {},
        postAction: (url, request, contentType) async {
          final name = request.contains('Name="bad"') ? 'bad' : 'good';
          requestedNames.add(name);
          if (name == 'bad') return (status: false, result: null);
          return (status: true, result: _manifest());
        },
        batchDownload: (tasks) async =>
            const MessageSyncBatchResult(downloaded: 0, failed: 0),
      );

      final bad = service.enqueue(MessageInfo(messageName: 'bad'));
      final good = service.enqueue(MessageInfo(messageName: 'good'));
      final results = await Future.wait([bad, good]);

      expect(results.first.succeeded, isFalse);
      expect(results.last.succeeded, isTrue);
      expect(requestedNames, ['bad', 'good']);
      await service.dispose();
    });
  });
}
