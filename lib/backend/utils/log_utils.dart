import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:logging/logging.dart';

const String _tag = "dcm";

Logger _logger = initFileLogger(_tag);
Logger initFileLogger(String name) {
  hierarchicalLoggingEnabled = true;
  final logger = Logger(name);
  final now = DateTime.now();

  final dir = Directory('${App().dataPath}/logs');
  if (!dir.existsSync()) dir.createSync();
  final logFile = File(
    '${dir.path}/${now.year}_${now.month}_${now.day}_$name.log',
  );

  // Set the logger level to ALL, so it logs all messages regardless of severity.
  // Level.ALL is useful for development and debugging, but you'll likely want to
  // use a more restrictive level like Level.INFO or Level.WARNING in production.
  logger.level = Level.ALL;

  // Listen for log records and write each one to the log file.
  logger.onRecord.listen((record) {
    final msg =
        '[${record.time} - ${record.loggerName}] ${record.level.name}: ${record.message}';
    logFile.writeAsStringSync('$msg \n', mode: FileMode.append);
  });

  return logger;
}

logV(String msg) {
  _logger.fine("$_tag :: $msg");
}

logD(String msg) {
  _logger.shout("$_tag :: $msg");
}

logI(String msg) {
  _logger.info("$_tag :: $msg");
}

logW(String msg) {
  _logger.warning("$_tag :: $msg");
}

logE(String msg) {
  _logger.severe("$_tag :: $msg");
}

logWTF(String msg) {
  _logger.severe("$_tag :: $msg");
}
