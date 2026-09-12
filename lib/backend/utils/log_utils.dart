import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

const String _tag = "player";
const String syncTag = "content sync";
const int _maxLogFileBytes = 5 * 1024 * 1024;
const int _maxRotatedFiles = 10;

class _PlayerFileOutput extends LogOutput {
  _PlayerFileOutput(this.filePath);

  final String filePath;
  Future<void> _writeQueue = Future<void>.value();

  File get _lockFile => File('$filePath.lock');

  @override
  void output(OutputEvent event) {
    final lines = event.lines.map((line) => '$line\n').join();
    _writeQueue = _writeQueue.then((_) => _write(lines));
  }

  Future<void> _write(String content) async {
    File? lock;
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      lock = await _acquireLock();
      final contentLength = utf8.encode(content).length;
      final currentLength = await file.exists() ? await file.length() : 0;
      if (currentLength + contentLength > _maxLogFileBytes &&
          currentLength > 0) {
        await _rotate(file);
      }
      await file.writeAsString(content, mode: FileMode.append, flush: true);
    } catch (error, stackTrace) {
      debugPrint('Player log write failed: $error\n$stackTrace');
    } finally {
      if (lock != null) {
        try {
          await lock.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> _acquireLock() async {
    for (;;) {
      try {
        return await _lockFile.create(exclusive: true);
      } on FileSystemException {
        if (await _lockFile.exists()) {
          final modified = await _lockFile.lastModified();
          if (DateTime.now().difference(modified) >
              const Duration(seconds: 30)) {
            try {
              await _lockFile.delete();
            } catch (_) {}
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  Future<void> _rotate(File file) async {
    for (var index = _maxRotatedFiles - 1; index >= 1; index--) {
      final source = File('${file.path}.$index');
      final target = File('${file.path}.${index + 1}');
      if (await source.exists()) {
        await source.rename(target.path);
      }
    }
    final firstArchive = File('${file.path}.1');
    if (await firstArchive.exists()) {
      await firstArchive.delete();
    }
    await file.rename(firstArchive.path);
  }
}

late Logger _logger;
void initFileLogger(String dataPath) {
  final logFile = path.join(dataPath, 'logs', 'player.log');
  _logger = Logger(
    filter: ProductionFilter(),
    level: kReleaseMode ? Level.info : Level.trace,
    output: _PlayerFileOutput(logFile),
    printer: SimplePrinter(
      printTime: true,
      colors: false,
    ),
  );
  logI('log_utils: after initLogger: ${path.dirname(logFile)}');
}

void logV(String msg, [String tag = _tag]) {
  _logger.t("$tag :: $msg");
}

void logD(String msg, [String tag = _tag]) {
  _logger.d("$tag :: $msg");
}

void logI(String msg, [String tag = _tag]) {
  _logger.i("$tag :: $msg");
}

void logW(String msg, [String tag = _tag]) {
  _logger.w("$tag :: $msg");
}

void logE(String msg,
    [Object? error, StackTrace? stackTrace, String tag = _tag]) {
  _logger.e("$tag :: $msg", error: error, stackTrace: stackTrace);
}

void logWTF(String msg, [String tag = _tag]) {
  _logger.f("$tag :: $msg");
}
