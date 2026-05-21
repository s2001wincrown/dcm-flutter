import 'dart:io';

import 'package:path/path.dart';

extension FilesExt on FileSystemEntity {
  bool get isHidden => basename(path).startsWith('.');
}

extension CaseInsensitiveString on String {
  // Compare to another string case-insensitively
  int compareToIgnoreCase(String other) {
    return toLowerCase().compareTo(other.toLowerCase());
  }

  bool equalsIgnoreCase(String other) {
    return toLowerCase() == other.toLowerCase();
  }
}
