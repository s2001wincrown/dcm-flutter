import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SyncHttpClient {
  SyncHttpClient({
    http.Client? client,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    Map<String, String>? defaultHeaders,
    this.maxRetries = 2,
    this.backoffSeconds = 2,
  })  : _client = client ?? http.Client(),
        _defaultHeaders = defaultHeaders ?? {};

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> _defaultHeaders;
  final int maxRetries;
  final int backoffSeconds;

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _resolveUri(path)
        .replace(queryParameters: _toQueryParameters(queryParameters));
    return _sendRequest('GET', uri, headers: headers);
  }

  Future<http.Response> post(
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

  Future<http.Response> postString(
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

  Future<http.Response> postJson(
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

  Future<http.Response> _sendRequest(
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

  Future<http.Response> _sendOnce(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    late http.Response response;
    if (method == 'GET') {
      response = await _client.get(uri, headers: headers).timeout(timeout);
    } else if (method == 'POST') {
      if (body is String) {
        response = await _client
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
      } else if (body != null) {
        response = await _client
            .post(uri, headers: headers, body: body.toString())
            .timeout(timeout);
      } else {
        response = await _client.post(uri, headers: headers).timeout(timeout);
      }
    } else {
      throw UnsupportedError('Unsupported HTTP method: $method');
    }
    return response;
  }

  Uri _resolveUri(String path) {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.parse(baseUrl).resolve(path);
  }

  Map<String, String>? _toQueryParameters(
      Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return null;
    }
    return queryParameters
        .map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  void close() {
    _client.close();
  }
}

class SyncHttpClientFactory {
  SyncHttpClientFactory({http.Client? sharedClient})
      : _sharedClient = sharedClient;

  final http.Client? _sharedClient;
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
