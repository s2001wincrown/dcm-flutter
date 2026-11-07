import 'dart:convert';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/settings.dart';
import 'package:dcm/backend/services/channel_schedule_impl.dart';
import 'package:dcm/backend/services/http_management_server.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late HttpManagementServer server;
  late HttpClient client;
  late Directory logDirectory;

  setUpAll(() async {
    logDirectory = await Directory.systemTemp.createTemp('dcm-http-test-');
    initFileLogger(logDirectory.path);
  });

  setUp(() async {
    App().settings = AppSettings(httpManagementToken: 'test-management-token');
    server = HttpManagementServer(port: 0);
    client = HttpClient();
    await server.start();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  tearDownAll(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await logDirectory.delete(recursive: true);
  });

  Future<HttpClientResponse> get(String path, {String? token}) async {
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}$path'));
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    return request.close();
  }

  test('serves the hosted management page without exposing the API', () async {
    final pageResponse = await get('/');
    expect(pageResponse.statusCode, HttpStatus.ok);
    expect(await utf8.decodeStream(pageResponse), contains('DCM 播放机管理'));

    final apiResponse = await get('/api/capabilities');
    expect(apiResponse.statusCode, HttpStatus.unauthorized);
  });

  test('requires the configured bearer token for API routes', () async {
    final invalidResponse =
        await get('/api/capabilities', token: 'incorrect-token');
    expect(invalidResponse.statusCode, HttpStatus.unauthorized);

    final validResponse =
        await get('/api/capabilities', token: 'test-management-token');
    expect(validResponse.statusCode, HttpStatus.ok);
    final body = jsonDecode(await utf8.decodeStream(validResponse))
        as Map<String, dynamic>;
    expect(body['supported'], contains('catalogue-authoring'));
  });

  test('accepts the configured HTTP management password', () async {
    expect(
      App().settings.httpManagementPassword,
      AppSettings.defaultHttpManagementPassword,
    );
    expect(
      AppSettings.fromJson({}).httpManagementPassword,
      AppSettings.defaultHttpManagementPassword,
    );

    final response = await get(
      '/api/capabilities',
      token: App().settings.httpManagementPassword,
    );
    expect(response.statusCode, HttpStatus.ok);

    App().settings.httpManagementPassword = 'user-updated-password';
    final updatedPasswordResponse = await get(
      '/api/capabilities',
      token: 'user-updated-password',
    );
    expect(updatedPasswordResponse.statusCode, HttpStatus.ok);
  });

  test('provides unauthenticated health check for reachability', () async {
    final response = await get('/health');
    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(await utf8.decodeStream(response)), {'online': true});
  });

  test('creates a new monthly channel schedule at its requested path',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('dcm-channel-schedule-test-');
    final previousCalendarPath = AppGlobal.calendarPath;
    AppGlobal.calendarPath = directory.path;
    final scheduleFile = path.join(directory.path, '202611.xml');
    try {
      final saved = ChannelScheduleImpl().saveSchedule(
        [
          DayInfoData()
            ..day = 1
            ..event = 'sample'
        ],
        '',
        strSchedule: scheduleFile,
      );
      expect(saved, isTrue);
      expect(await File(scheduleFile).exists(), isTrue);
    } finally {
      AppGlobal.calendarPath = previousCalendarPath;
      await directory.delete(recursive: true);
    }
  });
}
