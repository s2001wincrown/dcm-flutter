import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/services/content_file_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporaryDirectory;
  late Map<String, dynamic> previousConfig;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp();
    previousConfig = AppGlobal.snapshot();
    AppGlobal.applyWorkerConfig(
      openPath: path.join(temporaryDirectory.path, 'open'),
      imagePath: path.join(temporaryDirectory.path, 'image'),
      vcdPath: path.join(temporaryDirectory.path, 'vcd'),
      ppPath: path.join(temporaryDirectory.path, 'pp'),
      flashPath: path.join(temporaryDirectory.path, 'flash'),
      webPath: path.join(temporaryDirectory.path, 'web'),
      textPath: path.join(temporaryDirectory.path, 'text'),
      imageSettingPath: path.join(temporaryDirectory.path, 'image-setting'),
      clockPath: path.join(temporaryDirectory.path, 'clock'),
      weatherPath: path.join(temporaryDirectory.path, 'weather'),
      dayPath: path.join(temporaryDirectory.path, 'day'),
      contentListPath: path.join(temporaryDirectory.path, 'content-list'),
      linkagePath: path.join(temporaryDirectory.path, 'linkage'),
      ddeDataPath: path.join(temporaryDirectory.path, 'dde-data'),
      ddeXmlPath: path.join(temporaryDirectory.path, 'dde-xml'),
      siteContentPath: path.join(temporaryDirectory.path, 'site-content'),
      roomEventPath: path.join(temporaryDirectory.path, 'room-event'),
      lobbyPath: path.join(temporaryDirectory.path, 'lobby'),
    );
  });

  tearDown(() async {
    AppGlobal.applyWorkerConfig(
      openPath: previousConfig['openPath'] as String,
      imagePath: previousConfig['imagePath'] as String,
      vcdPath: previousConfig['vcdPath'] as String,
      ppPath: previousConfig['ppPath'] as String,
      flashPath: previousConfig['flashPath'] as String,
      webPath: previousConfig['webPath'] as String,
      textPath: previousConfig['textPath'] as String,
      imageSettingPath: previousConfig['imageSettingPath'] as String,
      clockPath: previousConfig['clockPath'] as String,
      weatherPath: previousConfig['weatherPath'] as String,
      dayPath: previousConfig['dayPath'] as String,
      contentListPath: previousConfig['contentListPath'] as String,
      linkagePath: previousConfig['linkagePath'] as String,
      ddeDataPath: previousConfig['ddeDataPath'] as String,
      ddeXmlPath: previousConfig['ddeXmlPath'] as String,
      siteContentPath: previousConfig['siteContentPath'] as String,
      roomEventPath: previousConfig['roomEventPath'] as String,
      lobbyPath: previousConfig['lobbyPath'] as String,
    );
    await temporaryDirectory.delete(recursive: true);
  });

  test('contentClearByCalendar waits for file cleanup', () async {
    final imageDirectory = Directory(AppGlobal.imagePath);
    await imageDirectory.create(recursive: true);
    final staleFile = File(path.join(imageDirectory.path, 'stale.png'));
    await staleFile.writeAsString('stale');

    await ContentFileImpl.empty().contentClearByCalendar();

    expect(await staleFile.exists(), isFalse);
  });
}
