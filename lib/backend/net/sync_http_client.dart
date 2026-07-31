import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class SyncHttpResponse {
  SyncHttpResponse({
    required this.statusCode,
    required this.body,
    required this.bodyBytes,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Uint8List bodyBytes;
  final Map<String, List<String>> headers;
}

class SyncHttpClient {
  SyncHttpClient({
    Dio? client,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    Map<String, String>? defaultHeaders,
    this.maxRetries = 2,
    this.backoffSeconds = 2,
    this.maxConnectionsPerHost = 6,
    this.connectionTimeout = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 20),
  })  : _client = client ??
            _createDefaultDio(
              timeout: timeout,
              maxConnectionsPerHost: maxConnectionsPerHost,
              connectionTimeout: connectionTimeout,
              idleTimeout: idleTimeout,
            ),
        _defaultHeaders = defaultHeaders ?? {};

  static Dio _createDefaultDio({
    required Duration timeout,
    required int maxConnectionsPerHost,
    required Duration connectionTimeout,
    required Duration idleTimeout,
  }) {
    final dio = Dio(BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
    ));

    final adapter = IOHttpClientAdapter()
      ..createHttpClient = () {
        final httpClient = HttpClient()
          ..maxConnectionsPerHost = maxConnectionsPerHost
          ..connectionTimeout = connectionTimeout
          ..idleTimeout = idleTimeout;
        return httpClient;
      };

    dio.httpClientAdapter = adapter;
    return dio;
  }

  final Dio _client;
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> _defaultHeaders;
  final int maxRetries;
  final int backoffSeconds;
  final int maxConnectionsPerHost;
  final Duration connectionTimeout;
  final Duration idleTimeout;

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

  Future<SyncHttpResponse> download(
    String path,
    dynamic savePath, {
    Map<String, String>? headers,
    ProgressCallback? onReceiveProgress,
    bool deleteOnError = true,
  }) async {
    final requestHeaders = {..._defaultHeaders, ...?headers};

    int attempt = 0;
    while (true) {
      try {
        final response = await _sendDownloadOnce(
          _resolveUri(path),
          requestHeaders,
          savePath,
          onReceiveProgress: onReceiveProgress,
          deleteOnError: deleteOnError,
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
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

  Future<SyncHttpResponse> _sendRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    final requestHeaders = {..._defaultHeaders, ...?headers};

    int attempt = 0;
    while (true) {
      try {
        final response = await _sendOnce(
          method,
          uri,
          requestHeaders,
          body,
          queryParameters: queryParameters,
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
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
    Object? body, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    final options = Options(
      headers: headers,
      responseType: ResponseType.bytes,
      contentType: headers['Content-Type'],
      validateStatus: (_) => true,
    );

    late final Response response;
    if (method == 'GET') {
      response = await _client
          .getUri(
            uri,
            options: options,
          )
          .timeout(timeout);
    } else if (method == 'POST') {
      dynamic data = body;
      if (body != null &&
          body is! List<int> &&
          body is! Uint8List &&
          body is! Stream<Uint8List>) {
        data = body.toString();
      }
      response = await _client
          .postUri(
            uri,
            data: data,
            options: options,
          )
          .timeout(timeout);
    } else {
      throw UnsupportedError('Unsupported HTTP method: $method');
    }

    final bytes = response.data != null
        ? Uint8List.fromList(List<int>.from(response.data as List<int>))
        : Uint8List.fromList(<int>[]);
    final bodyText = utf8.decode(bytes, allowMalformed: true);

    return SyncHttpResponse(
      statusCode: response.statusCode ?? 0,
      body: bodyText,
      bodyBytes: bytes,
      headers: response.headers.map,
    );
  }

  Future<SyncHttpResponse> _sendDownloadOnce(
    Uri uri,
    Map<String, String> headers,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    bool deleteOnError = true,
  }) async {
    final options = Options(
      headers: headers,
      validateStatus: (_) => true,
    );

    final response = await _client.downloadUri(
      uri,
      savePath,
      options: options,
      onReceiveProgress: onReceiveProgress,
      deleteOnError: deleteOnError,
    );
    //.timeout(timeout);

    return SyncHttpResponse(
      statusCode: response.statusCode ?? 0,
      body: '',
      bodyBytes: Uint8List(0),
      headers: response.headers.map,
    );
  }

  Uri _resolveUri(String path) {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.parse(baseUrl).resolve(path);
  }

  Map<String, dynamic>? _toQueryParameters(
      Map<String, dynamic>? queryParameters) {
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

class SyncHttpClientFactory {
  SyncHttpClientFactory({
    Dio? sharedClient,
    this.maxConnectionsPerHost = 6,
    this.connectionTimeout = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 20),
  }) : _sharedClient = sharedClient ??
            SyncHttpClient._createDefaultDio(
              timeout: const Duration(seconds: 15),
              maxConnectionsPerHost: maxConnectionsPerHost,
              connectionTimeout: connectionTimeout,
              idleTimeout: idleTimeout,
            );

  final Dio _sharedClient;
  final int maxConnectionsPerHost;
  final Duration connectionTimeout;
  final Duration idleTimeout;
  final Map<String, SyncHttpClient> _clients = <String, SyncHttpClient>{};

  SyncHttpClient clientFor({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? defaultHeaders,
    int maxRetries = 2,
    int backoffSeconds = 2,
  }) {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    return _clients.putIfAbsent(
      normalizedBaseUrl,
      () => SyncHttpClient(
        client: _sharedClient,
        baseUrl: normalizedBaseUrl,
        timeout: timeout,
        defaultHeaders: defaultHeaders,
        maxRetries: maxRetries,
        backoffSeconds: backoffSeconds,
      ),
    );
  }

  void dispose() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final uri = Uri.parse(trimmed);
    final authority = uri.authority;
    final path = uri.path == '/' ? '' : uri.path;
    return '${uri.scheme}://$authority$path'.replaceAll(RegExp(r'\/$'), '');
  }
}

final SyncHttpClientFactory syncHttpClientFactory = SyncHttpClientFactory();

class SyncHttpException implements Exception {
  SyncHttpException(
      {required this.statusCode, required this.message, required this.url});

  final int statusCode;
  final String message;
  final String url;

  @override
  String toString() => 'SyncHttpException($statusCode, $url, $message)';
}
