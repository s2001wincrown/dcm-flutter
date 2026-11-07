import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('local player configuration disables CMS content updates', () async {
    final directory =
        await Directory.systemTemp.createTemp('initial_setup_local_player_');
    addTearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    initFileLogger(directory.path);

    await AppGlobal.genConfigFile(directory.path, false);

    final configFile = File(path.join(directory.path, configFILENAME));
    expect(await configFile.exists(), isTrue);

    final settings = IniFile();
    await settings.loadFile(configFile.path);
    expect(
      settings.readBool('ContentSync', 'AutoContentUpdate', true),
      isFalse,
    );
  });
}
