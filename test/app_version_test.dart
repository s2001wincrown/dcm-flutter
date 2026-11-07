import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dcm/backend/git_version.dart';

void main() {
  group('GitVersionResolver', () {
    test('reads the latest git tag when a repo is available', () {
      final tempDir =
          Directory.systemTemp.createTempSync('dcm_git_version_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final initResult = Process.runSync(
        'git',
        ['init'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(initResult.exitCode, 0, reason: initResult.stderr.toString());

      final configName = Process.runSync(
        'git',
        ['config', 'user.name', 'Test User'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(configName.exitCode, 0, reason: configName.stderr.toString());

      final configEmail = Process.runSync(
        'git',
        ['config', 'user.email', 'test@example.com'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(configEmail.exitCode, 0, reason: configEmail.stderr.toString());

      final commitResult = Process.runSync(
        'git',
        ['commit', '--allow-empty', '-m', 'initial commit'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(commitResult.exitCode, 0, reason: commitResult.stderr.toString());

      final tagResult = Process.runSync(
        'git',
        ['tag', 'v1.2.3'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      expect(tagResult.exitCode, 0, reason: tagResult.stderr.toString());

      expect(
        GitVersionResolver.resolveVersion(workingDirectory: tempDir.path),
        '1.2.3',
      );
    });
  });
}
