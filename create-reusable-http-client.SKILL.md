---
name: create-reusable-http-client
summary: '面向当前 DCM 项目网络层的 Dart HTTP 客户端封装技能，优先复用现有下载任务、队列与状态更新结构，并强调共享连接池与客户端复用。'
description: |
  该技能用于为当前仓库里的 DCM 网络层生成更贴近实际代码的封装模板，重点对齐现有文件结构和数据模型，而不是泛化地讲解一个通用 HTTP 客户端。

  当前仓库已经具备一套较完整的落地实现：
  - lib/backend/net/sync_http_client.dart 中已有 `SyncHttpClient`，负责统一 baseUrl、headers、timeout、retry 与响应处理。
  - lib/backend/services/content_downloader.dart 中已有 `ContentDownloadTask`、`ContentDownloadQueue`、`ContentDownloader`，用于把 CMS 文件列表转成下载任务并串联 HTTP 逻辑。
  - lib/backend/services/content_sync_background_service.dart 中已通过 `ContentDownloader` 接入后台轮询流程。
  - lib/backend/net/player_task_file.dart 与 lib/backend/net/player_log_file.dart 中仍保留 HTTP内容同步 / 任务状态相关的网络与日志逻辑，适合继续收敛为统一封装。

  因此，这个技能不应该引入一套完全新的抽象，而是优先扩展和规范现有的 `SyncHttpClient` / `ContentDownloader` 结构，并在需要时把 HTTP内容同步状态上报逻辑也纳入统一客户端。

  关键原则：在同一个模块或服务里复用一个 `Dio` 实例，让底层连接池得到共享；避免在每个请求里都创建新的客户端。对于不同 baseUrl 或不同业务域名，可以通过一个轻量工厂/池来管理多个共享客户端。

  适配的现有代码场景：
  - lib/backend/services/content_downloader.dart 中的 `ContentDownloadTask`、`ContentDownloadQueue`、`ContentDownloadWorkerPayload`、`ContentDownloader`
  - lib/backend/net/sync_http_client.dart 中已有的 `SyncHttpClient` 与 `SyncHttpException`
  - lib/backend/services/content_sync_background_service.dart 中的后台轮询与下载任务调度
  - lib/backend/net/player_task_file.dart 中的 HTTP / 任务相关状态模型
  - lib/backend/net/player_log_file.dart 中的HTTP内容同步日志与状态更新逻辑
  - lib/backend/models/app_global.dart 与 lib/backend/utils/utils.dart 中的配置与路径辅助逻辑

  设计重点：
  - 优先复用现有 `SyncHttpClient`，而不是新增一套并行网络封装
  - 以 DCM 的下载任务、队列和状态模型为中心封装网络调用
  - 支持注入可替换的客户端，便于测试和 mock
  - 统一处理 baseUrl、headers、timeout、retry、异常与进度上报
  - 保持和现有下载逻辑兼容，避免重写整个网络层

arguments:
  - name: moduleName
    description: '当前模块名，例如 download、http、cms、player。'
    type: string
  - name: baseUrl
    description: 'CMS 或下载服务的基础地址。'
    type: string
  - name: timeoutSeconds
    description: '请求超时时间，单位秒。'
    type: integer
  - name: defaultHeaders
    description: '默认请求头，如 Content-Type、Authorization。'
    type: object
  - name: retryPolicy
    description: '重试策略，例如 maxRetries、backoffSeconds。'
    type: object
  - name: targetModel
    description: '目标模型类型，例如 ContentDownloadTask、PlayerJobItem、FileInfoData。'
    type: string
---

## 使用说明

1. 先确认当前要接入的场景是下载任务、HTTP内容同步状态上报，还是 CMS 文件列表查询；优先从现有的 `ContentDownloader` / `SyncHttpClient` 入口出发，而不是重新发明一套独立抽象。
2. 复用当前仓库已有类型，而不是引入完全不同的模型：
   - 下载流程优先围绕 `ContentDownloadTask` / `ContentDownloadQueue` / `ContentDownloadWorkerPayload` 设计。
   - HTTP / 日志场景优先考虑与 `PlayerJobItem`、`player_log_file.dart` 的调用方式兼容。
3. 让网络层在整个服务生命周期内共享一个客户端实例，复用底层连接池，避免频繁创建和关闭 `Dio`；只在应用退出或服务销毁时调用 `close()`。
4. 如果存在多个业务域名或多个 baseUrl，建议通过 `SyncHttpClientFactory` / `SyncHttpClientPool` 统一创建和维护共享客户端，而不是在业务代码中到处 `new SyncHttpClient(...)`。
5. 生成或扩展一个轻量封装类，职责包括：
   - 持有一个可注入的 `Dio` 实例
   - 统一拼接 `baseUrl`
   - 统一设置默认 headers
   - 统一处理 timeout、异常和重试
   - 允许把响应结果映射为当前项目中的任务模型或状态对象
6. 对外暴露简洁的高层方法，例如：
   - `fetchFileList()`
   - `downloadFile()`
   - `updateTaskStatus()`
   - `submitTask()`
7. 如果要和当前下载器集成，确保生成的代码可以直接被 `ContentDownloader` 或现有后台轮询流程调用。
8. 默认优先复用一个共享客户端实例，测试环境则通过注入 `MockAdapter` 或 `Dio` 替换，保持对业务代码的影响最小。

## 目标输出

- 一个面向 DCM 项目的 `SyncHttpClient` 或 `SyncApiClient` 封装类
- 可注入的 `HttpClient` 构造方式，便于 mock 和单元测试
- 针对当前任务模型的请求/响应映射逻辑
- 统一的重试、超时、异常处理模板
- 可直接接入当前下载器或 HTTP内容同步状态上报逻辑的代码片段

## 何时使用

- 需要把当前 DCM 下载任务逻辑中的网络部分抽成复用层时
- 需要给 DCM 的 CMS 拉取、文件下载、状态上报统一封装时
- 需要让现有下载逻辑更容易测试、替换和扩展时
- 需要在不重写整个网络层的前提下，接入 token、重试、日志时

## 推荐接入点

- DCM 下载器：在 lib/backend/services/dcm_downloader.dart 中，把下载 URL 请求和文件状态更新收敛到统一客户端。
- HTTP内容同步日志上报：在 lib/backend/net/player_log_file.dart 中，把 `updateSyncStatus` 相关逻辑改造为统一封装的服务调用。
- 任务模型：把 `ContentDownloadTask`、`PlayerJobItem` 的字段映射到统一响应对象中，减少散落的请求代码。
- 配置来源：优先使用 AppGlobal 中的 URL、token、路径等配置，而不是在业务代码里硬编码。

## 建议的类结构

- `SyncHttpClient`：优先扩展当前仓库已经存在的实现，负责共享 `Dio`、baseUrl、headers、timeout。
- `SyncHttpException`：统一异常类型，包含 statusCode、message、url。
- `SyncHttpRetryPolicy`：重试策略配置，包含 `maxRetries`、`backoffSeconds`、`retryOnStatusCodes`。
- `SyncHttpLogger`：可选日志接口，用于记录请求、响应和异常。
- `SyncHttpClientFactory` / `SyncHttpClientPool`：可选的客户端管理层，负责基于 baseUrl 或业务域名返回共享客户端实例。
- `ContentDownloadService` / `SyncHttpService`：业务层封装，负责调用 `SyncHttpClient` 并映射到当前项目模型。
- `ContentDownloader`：现有业务层入口，已在仓库中与 `ContentDownloadTask` / `ContentSyncBackgroundService` 对接，可作为集成点。

## DCM 代码模板（面向当前仓库）

当前仓库里已经有一份可直接对齐的实现，位于 lib/backend/net/sync_http_client.dart。下面的模板与当前项目的结构保持一致，重点是“复用现有 `SyncHttpClient`，并把下载任务与后台轮询接起来”。

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class SyncHttpClient {
  SyncHttpClient({
    Dio? client,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    Map<String, String>? defaultHeaders,
    this.maxRetries = 2,
    this.backoffSeconds = 2,
  })  : _client = client ?? Dio(BaseOptions()),
        _defaultHeaders = defaultHeaders ?? {};

  final Dio _client;
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> _defaultHeaders;
  final int maxRetries;
  final int backoffSeconds;

  Future<SyncHttpResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _sendRequest(
      'GET',
      _resolveUri(path),
      headers: headers,
      queryParameters: _toQueryParameters(queryParameters),
    );
  }

  Future<SyncHttpResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      'POST',
      _resolveUri(path),
      headers: headers,
      body: body,
    );
  }

  Future<SyncHttpResponse> postString(
    String path, {
    required String body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      'POST',
      _resolveUri(path),
      headers: headers,
      body: body,
    );
  }

  Future<SyncHttpResponse> postJson(
    String path, {
    required Object body,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = <String, String>{
      ..._defaultHeaders,
      ...?headers,
      'Content-Type': 'application/json; charset=utf-8',
    };
    return _sendRequest(
      'POST',
      _resolveUri(path),
      headers: requestHeaders,
      body: jsonEncode(body),
    );
  }

  Future<SyncHttpResponse> _sendRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final requestHeaders = {..._defaultHeaders, ...?headers};
    int attempt = 0;
    while (true) {
      try {
        final response = await _sendOnce(method, uri, requestHeaders, body);
        if (response.statusCode >= HttpStatus.ok &&
            response.statusCode < HttpStatus.multipleChoices) {
          return response;
        }
        if (attempt >= maxRetries) {
          return response;
        }
        attempt++;
        await Future.delayed(Duration(seconds: backoffSeconds * attempt));
      } catch (e) {
        if (attempt >= maxRetries) {
          rethrow;
        }
        attempt++;
        await Future.delayed(Duration(seconds: backoffSeconds * attempt));
      }
    }
  }

  Future<SyncHttpResponse> _sendOnce(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final options = Options(
      headers: headers,
      responseType: ResponseType.bytes,
      contentType: headers['Content-Type'],
      validateStatus: (_) => true,
    );

    dynamic data = body;
    if (body != null &&
        body is! List<int> &&
        body is! Uint8List &&
        body is! Stream<List<int>>) {
      data = body.toString();
    }

    late final Response<List<int>> response;
    if (method == 'GET') {
      response = await _client.getUri(
        uri,
        options: options,
      ).timeout(timeout);
    } else if (method == 'POST') {
      response = await _client.postUri(
        uri,
        data: data,
        options: options,
      ).timeout(timeout);
    } else {
      throw UnsupportedError('Unsupported HTTP method: $method');
    }

    final bytes = response.data != null
        ? Uint8List.fromList(response.data!)
        : Uint8List.fromList(<int>[]);
    final bodyText = utf8.decode(bytes, allowMalformed: true);

    return SyncHttpResponse(
      statusCode: response.statusCode ?? 0,
      body: bodyText,
      bodyBytes: bytes,
      headers: response.headers.map,
    );
  }

  Map<String, dynamic>? _toQueryParameters(Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return null;
    }
    return queryParameters
        .map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  void close() {
    _client.close(force: true);
  }
}

class SyncHttpException implements Exception {
  SyncHttpException({required this.statusCode, required this.message, required this.url});

  final int statusCode;
  final String message;
  final String url;

  @override
  String toString() => 'SyncHttpException($statusCode, $url, $message)';
}
```

### 与当前下载器的接入方式

- `ContentDownloader.fetchTasksFromApi()` 负责把 XML 响应解析成 `ContentDownloadTask`，随后由 `ContentDownloadQueue` 管理；这里优先复用 `SyncHttpClient.postString()`。
- `ContentSyncBackgroundService` 通过 `ContentDownloader` 触发轮询；如果要把 HTTP 逻辑继续抽象，可以把 `ContentDownloader` 中的 `_client` 初始化逻辑替换为共享工厂模式，避免每次轮询都创建新的客户端。
- 对 HTTP / 任务状态上报场景，可在 `player_task_file.dart` / `player_log_file.dart` 中把原先分散的网络调用改成统一的 `updateTaskStatus()` 或 `submitTask()` 接口。

## 与当前模型的映射建议

- 对于 `ContentDownloadTask`，把下载请求结果映射为：`url`、`targetPath`、`remoteSize`、`remoteModified`、`status`。
- 对于 `PlayerJobItem`，把请求结果映射为：`nRetryCount`、`dwJobStatus`、错误信息和进度信息。
- 对于 `FileInfoData`，把 CMS 返回的字段映射为当前项目里已有的 `strShortPath`、`strDestFile`、`nContentType`、`dwFileSize` 等属性。
- 对于状态上报场景，建议把 `PlayerLogFile` 里的上报逻辑收敛为一个 `updateTaskStatus()` 方法，而不是散落在多个地方。

## 测试建议

- 用一个可注入的 `Dio` 或 `MockAdapter` 来替换真实网络调用。
- 重点测试：
  - baseUrl 拼接是否正确
  - headers 是否成功注入
  - timeout 是否被正确触发
  - retry 是否在 5xx / 429 / 超时下生效
  - 非 2xx 状态码是否抛出 `SyncHttpException`
- 推荐把测试目标放在业务层，而不是直接测底层 `HttpClient` 的实现细节。

## 示例提示词

- “请生成一个面向当前 DCM 仓库的 `SyncHttpClient`，并和 `ContentDownloadTask` / `ContentDownloadQueue` 兼容。”
- “把当前下载器里的 HTTP 请求抽成一个可复用的 DCM 客户端，支持超时、重试和 token 注入。”
- “基于现有的 `PlayerLogFile` 和 `ContentDownloadTask` 结构，生成一个更贴近项目的网络封装模板。”

## 后续扩展建议

- 对接认证 token：从 AppGlobal 或登录态中动态获取 token，并统一注入到请求头。
- 对接请求日志：把请求耗时、状态码和失败原因记录到当前项目的日志系统。
- 对接缓存与离线兜底：对只读接口优先返回缓存结果，离线时可使用已有的本地文件或默认配置。
- 对接进度上报：把下载进度回传给当前任务状态或 UI 层，减少网络逻辑与业务逻辑的耦合。
