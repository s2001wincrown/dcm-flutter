import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:worker_manager/worker_manager.dart';

enum DcmDownloadStatus {
  pending,
  running,
  success,
  failed,
  skipped,
}

class DcmDownloadTask {
  DcmDownloadTask({
    required this.id,
    required this.url,
    required this.targetPath,
    this.remoteModified,
    this.remoteSize = -1,
    this.contentType = -1,
    this.statusValue = 0,
    this.title = '',
    this.uuid = '',
    this.priority = 0,
  })  : status = DcmDownloadStatus.pending,
        downloaded = 0,
        retryCount = 0,
        errorMessage = null,
        lastUpdated = DateTime.now();

  final String id;
  final String url;
  final String targetPath;
  final DateTime? remoteModified;
  final int remoteSize;
  final int contentType;
  final int statusValue;
  final String title;
  final String uuid;
  final int priority;

  int downloaded;
  int retryCount;
  DcmDownloadStatus status;
  String? errorMessage;
  DateTime? lastUpdated;

  String get partialPath => '$targetPath.part';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'targetPath': targetPath,
      'remoteModified': remoteModified?.toIso8601String(),
      'remoteSize': remoteSize,
      'contentType': contentType,
      'statusValue': statusValue,
      'title': title,
      'uuid': uuid,
      'priority': priority,
      'downloaded': downloaded,
      'retryCount': retryCount,
      'status': status.name,
      'errorMessage': errorMessage,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory DcmDownloadTask.fromJson(Map<String, dynamic> json) {
    return DcmDownloadTask(
      id: json['id']?.toString() ?? UniqueKeyGenerator.generate(),
      url: json['url']?.toString() ?? '',
      targetPath: json['targetPath']?.toString() ?? '',
      remoteModified: json['remoteModified'] != null
          ? DateTime.parse(json['remoteModified'] as String)
          : null,
      remoteSize: json['remoteSize'] is int
          ? json['remoteSize'] as int
          : int.tryParse(json['remoteSize']?.toString() ?? '-1') ?? -1,
      contentType: json['contentType'] is int
          ? json['contentType'] as int
          : int.tryParse(json['contentType']?.toString() ?? '-1') ?? -1,
      statusValue: json['statusValue'] is int
          ? json['statusValue'] as int
          : int.tryParse(json['statusValue']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      uuid: json['uuid']?.toString() ?? '',
      priority: json['priority'] is int
          ? json['priority'] as int
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
    )
      ..downloaded = json['downloaded'] is int
          ? json['downloaded'] as int
          : int.tryParse(json['downloaded']?.toString() ?? '0') ?? 0
      ..retryCount = json['retryCount'] is int
          ? json['retryCount'] as int
          : int.tryParse(json['retryCount']?.toString() ?? '0') ?? 0
      ..status = DcmDownloadStatus.values.firstWhere(
        (element) => element.name == json['status']?.toString(),
        orElse: () => DcmDownloadStatus.pending,
      )
      ..errorMessage = json['errorMessage']?.toString()
      ..lastUpdated = json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null;
  }

  factory DcmDownloadTask.fromFileInfoData(
      FileInfoData fileInfo, String cmsUrl) {
    final String shortPath = fileInfo.strShortPath.trim();
    final String destFile = fileInfo.strDestFile.trim();
    final int contentType = fileInfo.nContentType;
    final int remoteSize = fileInfo.dwFileSize.toInt();
    final DateTime? remoteModified = fileInfo.tmFileModify;
    final String id = (fileInfo.uiID != null && fileInfo.uiID! > 0)
        ? fileInfo.uiID!.toString()
        : (fileInfo.uuid?.isNotEmpty == true)
            ? fileInfo.uuid!
            : UniqueKeyGenerator.generate();
    final String url = buildCmsUrl(cmsUrl, shortPath);
    final String targetPath = Utils.getFilePath(destFile, contentType);

    return DcmDownloadTask(
      id: id,
      url: url,
      targetPath: targetPath,
      remoteModified: remoteModified,
      remoteSize: remoteSize,
      contentType: contentType,
      statusValue: fileInfo.fileStatus.status,
      title: fileInfo.strFileTitle,
      uuid: fileInfo.uuid ?? '',
    );
  }
}

class TempFileInfo {
  TempFileInfo({
    required this.nContentType,
    required this.strSourcePath,
    required this.strDestPath,
    required this.nPriorityFlag,
  });

  int nContentType;
  String strSourcePath;
  String strDestPath;
  int nPriorityFlag;

  Map<String, dynamic> toJson() {
    return {
      'nContentType': nContentType,
      'strSourcePath': strSourcePath,
      'strDestPath': strDestPath,
      'nPriorityFlag': nPriorityFlag,
    };
  }

  factory TempFileInfo.fromJson(Map<String, dynamic> json) {
    return TempFileInfo(
      nContentType: json['nContentType'] is int
          ? json['nContentType'] as int
          : int.tryParse(json['nContentType']?.toString() ?? '-1') ?? -1,
      strSourcePath: json['strSourcePath']?.toString() ?? '',
      strDestPath: json['strDestPath']?.toString() ?? '',
      nPriorityFlag: json['nPriorityFlag'] is int
          ? json['nPriorityFlag'] as int
          : int.tryParse(json['nPriorityFlag']?.toString() ?? '-1') ?? -1,
    );
  }
}

class DcmDownloadQueue {
  DcmDownloadQueue({required this.persistencePath, this.queueMode = 'fifo'})
      : tasks = [];

  final String persistencePath;
  final String queueMode;
  final List<DcmDownloadTask> tasks;
  //Download temporary path

  Future<void> load() async {
    final file = File(persistencePath);
    if (!await file.exists()) {
      return;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as List<dynamic>;
      tasks.clear();
      tasks.addAll(decoded
          .cast<Map<String, dynamic>>()
          .map(DcmDownloadTask.fromJson)
          .toList());
    } catch (e) {
      stderr.writeln('DcmDownloadQueue.load() failed: $e');
    }
  }

  Future<void> save() async {
    final file = File(persistencePath);
    await file.parent.create(recursive: true);
    final payload = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await file.writeAsString(payload, flush: true);
  }

  bool containsUrl(String url) {
    return tasks.any((task) => task.url == url);
  }

  void addTasks(List<DcmDownloadTask> newTasks) {
    for (final task in newTasks) {
      if (!containsUrl(task.url)) {
        tasks.add(task);
      }
    }
  }

  DcmDownloadTask? nextPendingTask() {
    final pending = tasks.where((task) {
      return task.status == DcmDownloadStatus.pending ||
          task.status == DcmDownloadStatus.failed;
    }).toList();
    if (pending.isEmpty) return null;

    if (queueMode == 'lifo') {
      return pending.last;
    }
    if (queueMode == 'priority') {
      pending.sort((a, b) => b.priority.compareTo(a.priority));
      return pending.first;
    }
    return pending.first;
  }
}

class DcmDownloadWorkerPayload {
  DcmDownloadWorkerPayload({
    required this.apiUrl,
    required this.persistencePath,
    required this.timeoutSeconds,
    required this.maxRetries,
    required this.backoffSeconds,
    required this.taskJson,
  });

  final String apiUrl;
  final String persistencePath;
  final int timeoutSeconds;
  final int maxRetries;
  final int backoffSeconds;
  final Map<String, dynamic> taskJson;

  Map<String, dynamic> toJson() {
    return {
      'apiUrl': apiUrl,
      'persistencePath': persistencePath,
      'timeoutSeconds': timeoutSeconds,
      'maxRetries': maxRetries,
      'backoffSeconds': backoffSeconds,
      'taskJson': taskJson,
    };
  }

  factory DcmDownloadWorkerPayload.fromJson(Map<String, dynamic> json) {
    return DcmDownloadWorkerPayload(
      apiUrl: json['apiUrl']?.toString() ?? '',
      persistencePath: json['persistencePath']?.toString() ?? '',
      timeoutSeconds: json['timeoutSeconds'] is int
          ? json['timeoutSeconds'] as int
          : int.tryParse(json['timeoutSeconds']?.toString() ?? '30') ?? 30,
      maxRetries: json['maxRetries'] is int
          ? json['maxRetries'] as int
          : int.tryParse(json['maxRetries']?.toString() ?? '3') ?? 3,
      backoffSeconds: json['backoffSeconds'] is int
          ? json['backoffSeconds'] as int
          : int.tryParse(json['backoffSeconds']?.toString() ?? '2') ?? 2,
      taskJson: Map<String, dynamic>.from(json['taskJson'] ?? const {}),
    );
  }
}

class DcmDownloadWorkerResult {
  DcmDownloadWorkerResult({required this.taskJson, required this.success});

  final Map<String, dynamic> taskJson;
  final bool success;

  Map<String, dynamic> toJson() {
    return {
      'taskJson': taskJson,
      'success': success,
    };
  }

  factory DcmDownloadWorkerResult.fromJson(Map<String, dynamic> json) {
    return DcmDownloadWorkerResult(
      taskJson: Map<String, dynamic>.from(json['taskJson'] ?? const {}),
      success: json['success'] == true,
    );
  }
}

class DcmDownloader {
  DcmDownloader({
    required this.apiUrl,
    required this.queue,
    this.concurrency = 4,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.backoffBase = const Duration(seconds: 2),
    this.onProgress,
    this.onTaskComplete,
    this.pollingInterval,
    this.buildRequestBody,
    DcmHttpClientFactory? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? dcmHttpClientFactory {
    _client = _createClient();
  }

  final String apiUrl;
  final DcmDownloadQueue queue;
  final int concurrency;
  final Duration timeout;
  final int maxRetries;
  final Duration backoffBase;
  final void Function(DcmDownloadTask task)? onProgress;
  final void Function(DcmDownloadTask task)? onTaskComplete;
  final Duration? pollingInterval;
  final Future<String> Function()? buildRequestBody;
  final DcmHttpClientFactory _httpClientFactory;

  late final DcmHttpClient _client;
  bool _isRunning = false;
  Timer? _pollTimer;
  bool _pollInProgress = false;

  Future<List<DcmDownloadTask>> fetchTasksFromApi(String xmlBody) async {
    _client = _createClient();

    final response = await _client.postString(
      _apiPath(apiUrl),
      body: xmlBody,
      headers: {'Content-Type': 'application/xml; charset=UTF-8'},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Unexpected response status ${response.statusCode}',
        uri: Uri.parse(apiUrl),
      );
    }

    final body = response.body;
    final fileInfoList = _parsePublishFileInformation(body);
    return fileInfoList
        .map((fileInfo) =>
            DcmDownloadTask.fromFileInfoData(fileInfo, apiUrlToCmsBase(apiUrl)))
        .where((task) => task.url.isNotEmpty && task.targetPath.isNotEmpty)
        .toList();
  }

  DcmHttpClient _createClient() {
    return _httpClientFactory.clientFor(
      baseUrl: apiUrlToCmsBase(apiUrl),
      timeout: timeout,
      defaultHeaders: {'Content-Type': 'application/xml; charset=UTF-8'},
      maxRetries: maxRetries,
      backoffSeconds: backoffBase.inSeconds,
    );
  }

  List<FileInfoData> _parsePublishFileInformation(String xmlBody) {
    final xmlFile = XmlFile('PublishFileInformation');
    if (!xmlFile.loadXml(xmlBody)) {
      return <FileInfoData>[];
    }

    final List<FileInfoData> fileInfoList = [];
    XmlItem? item = xmlFile.getItem('FileItem');
    while (item != null) {
      final fileInfo = FileInfoData(
        strFileTitle: '',
        strShortPath: '',
        strDestFile: '',
        dwFileSize: BigInt.zero,
      );
      fileInfo.getFromXML(item);
      fileInfoList.add(fileInfo);
      item = item.getSibling();
    }
    return fileInfoList;
  }

  Future<void> addTasksFromApi(String xmlBody) async {
    final tasks = await fetchTasksFromApi(xmlBody);
    queue.addTasks(tasks);
    await queue.save();
  }

  Future<void> start() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    await queue.load();
    final workers = List.generate(concurrency, (_) => _workerLoop());
    await Future.wait(workers);
    _isRunning = false;
  }

  Future<void> startPolling() async {
    if (pollingInterval == null || buildRequestBody == null) {
      throw ArgumentError(
          'pollingInterval and buildRequestBody must be provided to start polling');
    }
    if (_pollTimer != null) {
      return;
    }
    _pollTimer = Timer.periodic(pollingInterval!, (_) => _pollTick());
    await _pollOnce();
  }

  Future<void> stopPolling() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInProgress = false;
  }

  bool get isPolling => _pollTimer != null;

  Future<void> _pollTick() async {
    if (_pollInProgress) {
      return;
    }
    _pollInProgress = true;
    try {
      await _pollOnce();
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _pollOnce() async {
    if (buildRequestBody == null) {
      return;
    }
    try {
      final xmlBody = await buildRequestBody!();
      await addTasksFromApi(xmlBody);
      if (!_isRunning && queue.nextPendingTask() != null) {
        await start();
      }
    } catch (e, stack) {
      stderr.writeln('DcmDownloader polling failed: $e');
      stderr.writeln(stack);
    }
  }

  Future<void> _workerLoop() async {
    while (true) {
      final task = queue.nextPendingTask();
      if (task == null) {
        return;
      }
      task.status = DcmDownloadStatus.running;
      task.lastUpdated = DateTime.now();
      await queue.save();

      try {
        final processedTask = await _processTaskWithWorker(task);
        task.downloaded = processedTask.downloaded;
        task.retryCount = processedTask.retryCount;
        task.status = processedTask.status;
        task.errorMessage = processedTask.errorMessage;
        task.lastUpdated = processedTask.lastUpdated;
        await queue.save();
        onProgress?.call(task);
        onTaskComplete?.call(task);
      } catch (e) {
        task.status = DcmDownloadStatus.failed;
        task.errorMessage = e.toString();
        task.lastUpdated = DateTime.now();
        await queue.save();
        onTaskComplete?.call(task);
      }
    }
  }

  Future<DcmDownloadTask> _processTaskWithWorker(DcmDownloadTask task) async {
    final payload = DcmDownloadWorkerPayload(
      apiUrl: apiUrl,
      persistencePath: queue.persistencePath,
      timeoutSeconds: timeout.inSeconds,
      maxRetries: maxRetries,
      backoffSeconds: backoffBase.inSeconds,
      taskJson: task.toJson(),
    );

    final result = await workerManager.executeGentle(
      (_) => DcmDownloader.executeTaskInWorker(payload),
    );

    return DcmDownloadTask.fromJson(result.taskJson);
  }

  static Future<DcmDownloadWorkerResult> executeTaskInWorker(
      DcmDownloadWorkerPayload payload) async {
    final task = DcmDownloadTask.fromJson(payload.taskJson);
    final downloader = DcmDownloader(
      apiUrl: payload.apiUrl,
      queue: DcmDownloadQueue(persistencePath: payload.persistencePath),
      timeout: Duration(seconds: payload.timeoutSeconds),
      maxRetries: payload.maxRetries,
      backoffBase: Duration(seconds: payload.backoffSeconds),
    );

    final success =
        await downloader._attemptDownload(task, persistState: false);
    task.status =
        success ? DcmDownloadStatus.success : DcmDownloadStatus.failed;
    task.lastUpdated = DateTime.now();
    return DcmDownloadWorkerResult(taskJson: task.toJson(), success: success);
  }

  Future<bool> _attemptDownload(DcmDownloadTask task,
      {bool persistState = true}) async {
    while (task.retryCount <= maxRetries) {
      try {
        await _downloadTask(task);
        return true;
      } catch (e) {
        task.retryCount += 1;
        task.errorMessage = e.toString();
        task.status = DcmDownloadStatus.failed;
        task.lastUpdated = DateTime.now();
        if (persistState) {
          await queue.save();
        }
        if (task.retryCount > maxRetries) {
          return false;
        }
        final delay = Duration(
          seconds: backoffBase.inSeconds * task.retryCount,
        );
        await Future.delayed(delay);
      }
    }
    return false;
  }

  Future<void> _downloadTask(DcmDownloadTask task) async {
    final targetFile = File(task.targetPath);
    final partialFile = File(task.partialPath);
    await partialFile.parent.create(recursive: true);

    final currentBytes = await _prepareResume(task, targetFile, partialFile);
    task.downloaded = currentBytes;
    task.status = DcmDownloadStatus.running;
    task.lastUpdated = DateTime.now();

    final headers = <String, String>{};
    if (currentBytes > 0) {
      headers[HttpHeaders.rangeHeader] = 'bytes=$currentBytes-';
    }
    final response = await _client.get(
      _urlPath(task.url),
      headers: headers,
    );
    if (currentBytes > 0 && response.statusCode == HttpStatus.ok) {
      // server ignored the range request, restart from scratch.
      await partialFile.delete();
      task.downloaded = 0;
      return _downloadTask(task);
    }
    if (response.statusCode != HttpStatus.partialContent &&
        response.statusCode != HttpStatus.ok) {
      throw HttpException('Unexpected download status ${response.statusCode}',
          uri: Uri.parse(task.url));
    }

    final raf = await partialFile.open(mode: FileMode.append);
    try {
      int saveCounter = 0;
      int bytesSincePersist = 0;
      final bodyBytes = response.bodyBytes;
      if (bodyBytes.isNotEmpty) {
        await raf.writeFrom(bodyBytes);
        task.downloaded += bodyBytes.length;
        bytesSincePersist += bodyBytes.length;
        saveCounter += 1;
        if (bytesSincePersist >= 512 * 1024 || saveCounter % 10 == 0) {
          task.lastUpdated = DateTime.now();
          await queue.save();
          onProgress?.call(task);
          bytesSincePersist = 0;
        }
      }
    } finally {
      await raf.close();
    }

    await partialFile.rename(task.targetPath);
    task.errorMessage = null;
    task.lastUpdated = DateTime.now();
    await queue.save();
    onProgress?.call(task);
  }

  Future<int> _prepareResume(
      DcmDownloadTask task, File targetFile, File partialFile) async {
    if (await targetFile.exists()) {
      final localModified = await targetFile.lastModified();
      if (task.remoteModified == null ||
          !localModified.isBefore(task.remoteModified!)) {
        task.status = DcmDownloadStatus.skipped;
        task.errorMessage = 'Target already up to date';
        return 0;
      }
    }

    if (await partialFile.exists()) {
      if (task.remoteModified != null) {
        final partialModified = await partialFile.lastModified();
        if (task.remoteModified!.isAfter(partialModified)) {
          await partialFile.delete();
          return 0;
        }
      }
      return await partialFile.length();
    }

    return 0;
  }

  static String apiUrlToCmsBase(String apiUrl) {
    final uri = Uri.parse(apiUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  String _apiPath(String apiUrl) {
    final uri = Uri.parse(apiUrl);
    return uri.path.isEmpty ? '/' : uri.path;
  }

  String _urlPath(String url) {
    final uri = Uri.parse(url);
    return uri.path.isEmpty ? '/' : uri.path;
  }
}

class UniqueKeyGenerator {
  static int _counter = 0;

  static String generate() {
    _counter += 1;
    return 'dcm-task-${DateTime.now().microsecondsSinceEpoch}--$_counter';
  }
}

String buildCmsUrl(String cmsUrl, String shortPath) {
  if (shortPath.isEmpty) return cmsUrl;
  if (shortPath.startsWith(RegExp(r'https?://', caseSensitive: false))) {
    return shortPath;
  }

  final trimmedHost =
      cmsUrl.endsWith('/') ? cmsUrl.substring(0, cmsUrl.length - 1) : cmsUrl;
  final trimmedPath =
      shortPath.startsWith('/') ? shortPath.substring(1) : shortPath;
  return '$trimmedHost/$trimmedPath';
}
