import 'dart:io';

import 'package:path/path.dart';

extension FilesExt on FileSystemEntity {
  bool get isHidden => basename(path).startsWith('.');
}

extension CaseInsensitiveString on String {
  // Compare to another string case-insensitively
  int compareToIgnoreCase(String? other) {
    if (other == null) return 1;
    return toLowerCase().compareTo(other.toLowerCase());
  }

  bool equalsIgnoreCase(String? other) {
    if (other == null) return false;
    return toLowerCase() == other.toLowerCase();
  }

  bool containsIgnoreCase(String? other) {
    if (other == null) return false;

    return toLowerCase().contains(other.toLowerCase());
  }

  bool startsWithIgnoreCase(String? other) {
    if (other == null) return false;

    return toLowerCase().startsWith(other.toLowerCase());
  }

  bool endsWithIgnoreCase(String? other) {
    if (other == null) return false;

    return toLowerCase().endsWith(other.toLowerCase());
  }
}
