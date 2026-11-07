import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/services/content_downloader.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dcm/backend/net/sync_http_client.dart';

class _MockAdapter implements HttpClientAdapter {
  const _MockAdapter(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options, requestStream, cancelFuture);
  }
}

Future<String> _streamToString(Stream<List<int>> stream) async {
  final bytes = await stream.fold<List<int>>(<int>[], (previous, element) {
    return previous..addAll(element);
  });
  return utf8.decode(bytes);
}

void main() {
  group('SyncHttpClient', () {
    test('posts XML payload with Dio client', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter(
        (options, requestStream, _) async {
          expect(options.method, 'POST');
          expect(options.uri.toString(), 'https://example.com/api/filelist');
          final body = await _streamToString(
            requestStream?.map((chunk) => chunk.toList()) ??
                const Stream.empty(),
          );
          expect(body, '<xml/>');
          expect(
            options.headers['content-type'],
            'application/xml; charset=UTF-8',
          );
          return ResponseBody.fromString('ok', 200, headers: {
            Headers.contentTypeHeader: ['text/plain']
          });
        },
      );

      final client = SyncHttpClient(
        client: dio,
        baseUrl: 'https://example.com',
      );

      final response = await client.postString(
        '/api/filelist',
        body: '<xml/>',
        headers: {'Content-Type': 'application/xml; charset=UTF-8'},
      );

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      client.close();
    });

    test('reuses shared clients for the same base URL', () async {
      final factory = SyncHttpClientFactory();
      final first = factory.clientFor(baseUrl: 'https://example.com');
      final second = factory.clientFor(baseUrl: 'https://example.com/');
      final other = factory.clientFor(baseUrl: 'https://example.org');

      expect(identical(first, second), isTrue);
      expect(identical(first, other), isFalse);

      factory.dispose();
    });

    test('accepts absolute URLs without requiring a path join', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter(
        (options, requestStream, _) async {
          expect(options.method, 'GET');
          expect(options.uri.toString(), 'https://cdn.example.com/file.bin');
          expect(
            await _streamToString(
              requestStream?.map((chunk) => chunk.toList()) ??
                  const Stream.empty(),
            ),
            '',
          );
          return ResponseBody.fromString('ok', 200, headers: {
            Headers.contentTypeHeader: ['text/plain']
          });
        },
      );

      final client = SyncHttpClient(
        client: dio,
        baseUrl: 'https://example.com',
      );

      final response = await client.get('https://cdn.example.com/file.bin');

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      client.close();
    });

    test('applyWorkerConfig restores CMS settings for worker execution', () {
      final originalSnapshot = AppGlobal.snapshot();
      AppGlobal.cmsUrl = '';
      AppGlobal.cmsToken = '';
      AppGlobal.organization = '';
      AppGlobal.statusCheckInterval = 1;

      AppGlobal.applyWorkerConfig(
        cmsUrl: 'https://cms.example.com',
        cmsToken: 'test-token',
        organization: 'org-a',
        statusCheckInterval: 7,
      );

      expect(AppGlobal.cmsUrl, 'https://cms.example.com');
      expect(AppGlobal.cmsToken, 'test-token');
      expect(AppGlobal.organization, 'org-a');
      expect(AppGlobal.statusCheckInterval, 7);

      AppGlobal.applyWorkerConfig(
        cmsUrl: originalSnapshot['cmsUrl']?.toString(),
        cmsToken: originalSnapshot['cmsToken']?.toString(),
        organization: originalSnapshot['organization']?.toString(),
        statusCheckInterval: originalSnapshot['statusCheckInterval'] as int?,
      );
    });
  });

  group('SyncDownloadQueue retry handling', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dcm_downloader_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('requeues failed tasks to the tail and removes them after max retries',
        () {
      final queue = ContentDownloadQueue(
        persistencePath: '${tempDir.path}/queue.json',
        queueMode: 'fifo',
      );

      final firstTask = ContentDownloadTask(
        id: 'first',
        url: 'https://example.com/a',
        targetPath: '/tmp/a.bin',
      );
      final secondTask = ContentDownloadTask(
        id: 'second',
        url: 'https://example.com/b',
        targetPath: '/tmp/b.bin',
      );

      queue.addTasks([firstTask, secondTask]);

      queue.handleTaskFailure(firstTask, maxRetries: 2);
      expect(firstTask.retryCount, 1);
      expect(firstTask.status, ContentDownloadStatus.failed);
      expect(queue.tasks.first.id, 'second');
      expect(queue.tasks.last.id, 'first');
      expect(queue.nextPendingTask()?.id, 'second');

      queue.handleTaskFailure(firstTask, maxRetries: 2);
      expect(firstTask.retryCount, 2);
      expect(queue.tasks.first.id, 'second');
      expect(queue.tasks.last.id, 'first');

      queue.handleTaskFailure(firstTask, maxRetries: 2);
      expect(firstTask.retryCount, 2);
      expect(queue.tasks.any((task) => task.id == 'first'), isFalse);
    });
  });

  group('ContentDownloader concurrency', () {
    late Directory tempDir;
    late String originalFtpSettingPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('dcm_downloader_concurrency_');
      originalFtpSettingPath = AppGlobal.ftpSettingPath;
      AppGlobal.ftpSettingPath = tempDir.path;
      initFileLogger(tempDir.path);
    });

    tearDown(() async {
      AppGlobal.ftpSettingPath = originalFtpSettingPath;
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('serializes overlapping queue snapshots and preserves the latest',
        () async {
      final queue = ContentDownloadQueue(
        persistencePath: '${tempDir.path}/queue.json',
      );
      final saves = <Future<void>>[];
      for (var index = 0; index < 30; index++) {
        queue.addTask(ContentDownloadTask(
          id: 'task-$index',
          url: 'https://example.com/$index',
          targetPath: '${tempDir.path}/$index.bin',
        ));
        saves.add(queue.save());
      }

      await Future.wait(saves);
      final persisted =
          jsonDecode(await File(queue.persistencePath).readAsString())
              as Map<String, dynamic>;
      final tasks = persisted['tasks'] as List<dynamic>;

      expect(tasks, hasLength(30));
      expect(tasks.last['id'], 'task-29');
    });

    test('can download without writing PlayerLogFile or sync status', () async {
      final statusServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var statusRequests = 0;
      final statusSubscription = statusServer.listen((request) async {
        statusRequests++;
        request.response
          ..statusCode = HttpStatus.ok
          ..write('Successful');
        await request.response.close();
      });
      final originalCmsUrl = AppGlobal.cmsUrl;
      final originalFileCount = PlayerLogFile.nFileDownloaded;
      final originalBytesDownloaded = PlayerLogFile.nTotalBytesDownloaded;
      AppGlobal.cmsUrl = 'http://127.0.0.1:${statusServer.port}';

      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options, _, __) async {
        expect(options.uri.path, '/quiet.bin');
        return ResponseBody.fromString('downloaded bytes', HttpStatus.ok);
      });
      final clientFactory = SyncHttpClientFactory(sharedClient: dio);
      final targetPath = '${tempDir.path}/quiet.bin';
      final downloader = ContentDownloader(
        apiUrl: AppGlobal.cmsUrl,
        queue: ContentDownloadQueue(
          persistencePath: '${tempDir.path}/quiet-queue.json',
        ),
        concurrency: 1,
        maxRetries: 0,
        reportToPlayerLog: false,
        httpClientFactory: clientFactory,
      );

      try {
        await downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'quiet',
            url: '${AppGlobal.cmsUrl}/quiet.bin',
            targetPath: targetPath,
            remoteSize: 16,
          ),
        ]);

        expect(await File(targetPath).readAsString(), 'downloaded bytes');
        expect(File('${tempDir.path}/ftperror.xml').existsSync(), isFalse);
        expect(PlayerLogFile.nFileDownloaded, originalFileCount);
        expect(PlayerLogFile.nTotalBytesDownloaded, originalBytesDownloaded);
        expect(statusRequests, 0);
      } finally {
        AppGlobal.cmsUrl = originalCmsUrl;
        await statusSubscription.cancel();
        await statusServer.close(force: true);
        clientFactory.dispose();
        dio.close(force: true);
      }
    });

    test('retries downloads that produce an empty file', () async {
      final dio = Dio();
      var attempts = 0;
      dio.httpClientAdapter = _MockAdapter((options, _, __) async {
        attempts++;
        if (attempts == 1) {
          return ResponseBody.fromString('', HttpStatus.ok);
        }
        return ResponseBody.fromString('downloaded bytes', HttpStatus.ok);
      });
      final clientFactory = SyncHttpClientFactory(sharedClient: dio);
      final queue = ContentDownloadQueue(
        persistencePath: '${tempDir.path}/empty-file-queue.json',
      );
      final targetPath = '${tempDir.path}/retried.bin';
      final downloader = ContentDownloader(
        apiUrl: 'https://example.com',
        queue: queue,
        concurrency: 1,
        maxRetries: 1,
        backoffBase: Duration.zero,
        reportToPlayerLog: false,
        httpClientFactory: clientFactory,
      );

      try {
        await downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'empty-response',
            url: 'https://example.com/retried.bin',
            targetPath: targetPath,
          ),
        ]);

        expect(attempts, 2);
        expect(await File(targetPath).readAsString(), 'downloaded bytes');
        expect(queue.tasks.single.status, ContentDownloadStatus.success);
        expect(queue.tasks.single.retryCount, 1);
      } finally {
        clientFactory.dispose();
        dio.close(force: true);
      }
    });

    test('redownloads an existing empty target instead of skipping it',
        () async {
      final dio = Dio();
      var attempts = 0;
      dio.httpClientAdapter = _MockAdapter((options, _, __) async {
        attempts++;
        return ResponseBody.fromString('downloaded bytes', HttpStatus.ok);
      });
      final clientFactory = SyncHttpClientFactory(sharedClient: dio);
      final targetPath = '${tempDir.path}/empty-target.bin';
      await File(targetPath).writeAsBytes([]);
      final downloader = ContentDownloader(
        apiUrl: 'https://example.com',
        queue: ContentDownloadQueue(
          persistencePath: '${tempDir.path}/empty-target-queue.json',
        ),
        concurrency: 1,
        maxRetries: 0,
        backoffBase: Duration.zero,
        reportToPlayerLog: false,
        httpClientFactory: clientFactory,
      );

      try {
        await downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'empty-target',
            url: 'https://example.com/empty-target.bin',
            targetPath: targetPath,
          ),
        ]);

        expect(attempts, 1);
        expect(await File(targetPath).readAsString(), 'downloaded bytes');
      } finally {
        clientFactory.dispose();
        dio.close(force: true);
      }
    });

    test('drains tasks added while a worker pool is finishing', () async {
      final dio = Dio();
      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      final requestPaths = <String>[];
      dio.httpClientAdapter = _MockAdapter((options, _, __) async {
        requestPaths.add(options.uri.path);
        if (options.uri.path.endsWith('/first')) {
          firstRequestStarted.complete();
          await releaseFirstRequest.future;
        }
        return ResponseBody.fromString(
            'failed', HttpStatus.internalServerError);
      });
      final clientFactory = SyncHttpClientFactory(sharedClient: dio);
      final queue = ContentDownloadQueue(
        persistencePath: '${tempDir.path}/active-queue.json',
      );
      final downloader = ContentDownloader(
        apiUrl: 'https://example.com',
        queue: queue,
        concurrency: 1,
        maxRetries: 0,
        backoffBase: Duration.zero,
        httpClientFactory: clientFactory,
      );

      try {
        final firstAdd = downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'first',
            url: 'https://example.com/first',
            targetPath: '${tempDir.path}/first.bin',
          ),
        ]);
        await firstRequestStarted.future;

        final secondAdd = downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'second',
            url: 'https://example.com/second',
            targetPath: '${tempDir.path}/second.bin',
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(queue.tasks.any((task) => task.id == 'second'), isTrue);

        releaseFirstRequest.complete();
        await Future.wait([firstAdd, secondAdd]);

        expect(requestPaths, ['/first', '/second']);
      } finally {
        if (!releaseFirstRequest.isCompleted) releaseFirstRequest.complete();
        clientFactory.dispose();
        dio.close(force: true);
      }
    });

    test('waits for active workers before reset and accepts later tasks',
        () async {
      final dio = Dio();
      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      final requestPaths = <String>[];
      dio.httpClientAdapter = _MockAdapter((options, _, __) async {
        requestPaths.add(options.uri.path);
        if (options.uri.path.endsWith('/first')) {
          firstRequestStarted.complete();
          await releaseFirstRequest.future;
        }
        return ResponseBody.fromString(
            'failed', HttpStatus.internalServerError);
      });
      final clientFactory = SyncHttpClientFactory(sharedClient: dio);
      final queue = ContentDownloadQueue(
        persistencePath: '${tempDir.path}/reset-queue.json',
      );
      final downloader = ContentDownloader(
        apiUrl: 'https://example.com',
        queue: queue,
        concurrency: 1,
        maxRetries: 0,
        backoffBase: Duration.zero,
        httpClientFactory: clientFactory,
      );

      try {
        final firstAdd = downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'first',
            url: 'https://example.com/first',
            targetPath: '${tempDir.path}/first.bin',
          ),
        ]);
        await firstRequestStarted.future;

        final reset = downloader.resetQueue();
        final secondAdd = downloader.addTasksToQueue([
          ContentDownloadTask(
            id: 'second',
            url: 'https://example.com/second',
            targetPath: '${tempDir.path}/second.bin',
          ),
        ]);
        releaseFirstRequest.complete();

        await reset;
        await Future.wait([firstAdd, secondAdd]);

        expect(requestPaths, ['/first', '/second']);
        expect(queue.tasks, isEmpty);
      } finally {
        if (!releaseFirstRequest.isCompleted) releaseFirstRequest.complete();
        clientFactory.dispose();
        dio.close(force: true);
      }
    });

    test('releases run state after a worker exception so start can retry',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options, _, __) async =>
          ResponseBody.fromString('failed', HttpStatus.internalServerError));
      final clientFactory = SyncHttpClientFactory(sharedClient: dio);
      final queuePath = '${tempDir.path}/blocked-queue.json';
      final blockedQueuePath = Directory(queuePath)..createSync();
      final queue = ContentDownloadQueue(persistencePath: queuePath);
      queue.addTask(ContentDownloadTask(
        id: 'retry-after-save-error',
        url: 'https://example.com/retry',
        targetPath: '${tempDir.path}/retry.bin',
      ));
      final downloader = ContentDownloader(
        apiUrl: 'https://example.com',
        queue: queue,
        concurrency: 1,
        maxRetries: 0,
        backoffBase: Duration.zero,
        httpClientFactory: clientFactory,
      );

      try {
        await expectLater(
            downloader.start(), throwsA(isA<FileSystemException>()));
        await blockedQueuePath.delete();

        await downloader.start();

        expect(queue.tasks, isEmpty);
        expect(queue.finalFailedTaskCount, 1);
      } finally {
        clientFactory.dispose();
        dio.close(force: true);
      }
    });
  });
}
