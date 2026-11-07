import 'dart:io';

import 'package:dcm/backend/utils/log_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('redacts authentication-token values from log output', () async {
    final directory = await Directory.systemTemp.createTemp();
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    initFileLogger(directory.path);
    logI(
      'query authentication-token=query-secret '
      'and Authentication-Token: header-secret',
    );

    final logFile = File(path.join(directory.path, 'logs', 'player.log'));
    String contents = '';
    for (var attempt = 0; attempt < 50; attempt++) {
      if (await logFile.exists()) {
        contents = await logFile.readAsString();
        if (contents.contains('***')) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(contents, contains('authentication-token=***'));
    expect(contents, contains('Authentication-Token: ***'));
    expect(contents, isNot(contains('query-secret')));
    expect(contents, isNot(contains('header-secret')));
  });
}
