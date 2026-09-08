import 'dart:io';

class GitVersionResolver {
  const GitVersionResolver._();

  static String resolveVersion({
    String? workingDirectory,
    String fallback = '0.25.3',
  }) {
    final repoRoot = workingDirectory ?? _findGitRepoRoot();
    if (repoRoot == null || repoRoot.isEmpty) {
      return fallback;
    }

    final possibleCommands = [
      ['describe', '--tags', '--abbrev=0'],
      ['describe', '--tags', '--always', '--dirty'],
      ['tag', '--list', '--sort=-version:refname'],
    ];

    for (final command in possibleCommands) {
      try {
        final result = Process.runSync(
          'git',
          command,
          workingDirectory: repoRoot,
          runInShell: true,
        );

        if (result.exitCode != 0) {
          continue;
        }

        final output = result.stdout.toString().trim();
        if (output.isEmpty) {
          continue;
        }

        final version = _normalizeVersion(output);
        if (version.isNotEmpty) {
          return version;
        }
      } catch (_) {
        continue;
      }
    }

    return fallback;
  }

  static String _normalizeVersion(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }

    final lines = value.split(RegExp(r'\r?\n'));
    final tag = lines.first.trim();
    if (tag.isEmpty) {
      return '';
    }

    final normalized = tag.replaceFirst(RegExp(r'^[vV]'), '');
    return normalized.split(RegExp(r'\s+')).first.trim();
  }

  static String? _findGitRepoRoot() {
    var current = Directory.current;

    for (var i = 0; i < 16; i++) {
      if (Directory('${current.path}${Platform.pathSeparator}.git')
          .existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }

    return null;
  }
}
