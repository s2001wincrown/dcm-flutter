import 'package:mixin_logger/mixin_logger.dart';

const String _tag = "dcm";
const String syncTag = "content sync";
void initFileLogger(String dataPath) {
  // init logger with dir. then all logs will be saved to this dir.
  initLogger(
    '$dataPath/logs',
    maxFileCount: 10, // max 10 files.
    maxFileLength: 5 * 1024 * 1024, // max to 5 MB for single file.
  );
  logI('log_utils: after initLogger: $dataPath/logs');
}

void logV(String msg, [String tag = _tag]) {
  v("$tag :: $msg");
}

void logD(String msg, [String tag = _tag]) {
  d("$tag :: $msg");
}

void logI(String msg, [String tag = _tag]) {
  i("$tag :: $msg");
}

void logW(String msg, [String tag = _tag]) {
  w("$tag :: $msg");
}

void logE(String msg,
    [Object? error, StackTrace? stackTrace, String tag = _tag]) {
  e("$tag :: $msg", error, stackTrace);
}

void logWTF(String msg, [String tag = _tag]) {
  wtf("$tag :: $msg");
}
