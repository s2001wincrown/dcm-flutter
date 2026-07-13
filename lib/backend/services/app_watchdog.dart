import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A lightweight app supervisor that launches the real UI process as a child.
///
/// A Dart isolate worker cannot survive the termination of the main process,
/// so process-level restart support is implemented using a separate parent
/// process instead of `worker_manager` alone.
class AppWatchdog {
  static const String _childArg = '--dcm-watchdog-child';
  static const String _noWatchdogArg = '--dcm-watchdog-no';
  static const int _maxRestartAttempts = 10;
  static const Duration _restartDelay = Duration(seconds: 3);

  static bool _isWatchdogChild(List<String> args) => args.contains(_childArg);

  static bool _hasNoWatchdogFlag(List<String> args) =>
      args.contains(_noWatchdogArg);

  static bool _isWatchdogSupported() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static Future<bool> runParentIfNeeded(List<String> arguments) async {
    if (kDebugMode) {
      // Avoid spawning child processes during development and debugging.
      return false;
    }

    if (!_isWatchdogSupported()) {
      return false;
    }

    if (_isWatchdogChild(arguments) || _hasNoWatchdogFlag(arguments)) {
      return false;
    }

    await _runParent(arguments);
    return true;
  }

  static Future<void> _runParent(List<String> arguments) async {
    final executable = Platform.resolvedExecutable;
    final executableFile = File(executable);
    if (!executableFile.existsSync()) {
      stderr.writeln('AppWatchdog: failed to locate executable: $executable');
      return;
    }

    final childArgs = <String>[];
    childArgs.addAll(Platform.executableArguments);

    final scriptPath = Platform.script.toFilePath(windows: Platform.isWindows);
    if (scriptPath.endsWith('.dart')) {
      childArgs.add(scriptPath);
    }

    childArgs.addAll(arguments);
    childArgs.add(_childArg);

    int restartCount = 0;
    while (true) {
      if (restartCount > 0) {
        stderr.writeln(
            'AppWatchdog: restarting child process attempt #$restartCount...');
        await Future.delayed(_restartDelay);
      }

      final child = await Process.start(
        executable,
        childArgs,
        environment: Platform.environment,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await child.exitCode;
      if (exitCode == 0) {
        stderr.writeln('AppWatchdog: child exited normally with code 0.');
        return;
      }

      stderr.writeln(
          'AppWatchdog: child exited with code $exitCode. Restarting...');
      restartCount += 1;
      if (restartCount >= _maxRestartAttempts) {
        stderr.writeln(
            'AppWatchdog: reached $_maxRestartAttempts restart attempts, giving up.');
        return;
      }
    }
  }
}
