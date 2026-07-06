import 'package:mixin_logger/mixin_logger.dart';

const String _tag = "dcm";
void initFileLogger(String dataPath) {
  // init logger with dir. then all logs will be saved to this dir.
  initLogger(
    '$dataPath/logs',
    maxFileCount: 10, // max 10 files.
    maxFileLength: 5 * 1024 * 1024, // max to 5 MB for single file.
  );
  logI('log_utils: after initLogger');
}

void logV(String msg) {
  v("$_tag :: $msg");
}

void logD(String msg) {
  d("$_tag :: $msg");
}

void logI(String msg) {
  i("$_tag :: $msg");
}

void logW(String msg) {
  w("$_tag :: $msg");
}

void logE(String msg) {
  e("$_tag :: $msg");
}

void logWTF(String msg) {
  wtf("$_tag :: $msg");
}
