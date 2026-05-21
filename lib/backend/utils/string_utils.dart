// check if target is sub-sequence of text

bool isSubsequence(String target, String text) {
  int n = target.length, m = text.length;

  int i = 0;
  for (int j = 0; j < m && i < n; j++) {
    if (text[j].toLowerCase() == target[i].toLowerCase()) {
      i++;
    }
  }

  return i == n;
}

// TODO: use normalize url from path package
String unifyPath(String path, {bool endSlash = true}) {
  String result = (path).replaceAll(r'\', '/');
  if (endSlash) {
    if (!result.endsWith('/')) result += '/';
  } else {
    if (result.endsWith('/')) {
      int n = result.length;
      result = result.substring(0, n - 1);
    }
  }

  return result;
}

/// Convert color int to RGB string
String toRGBString(int color) {
  //format color to 'R, G, B'
  return '${(color >> 16) & 0xFF},${(color >> 8) & 0xFF},${(color >> 0) & 0xFF}';
}

/// Convert RGB string to color int
int fromRGBString(String colorString) {
  List<String> components = colorString.split(',');
  int r = components.isNotEmpty ? (int.tryParse(components[0].trim()) ?? 0) : 0;
  int g = components.length > 1 ? (int.tryParse(components[1].trim()) ?? 0) : 0;
  int b = components.length > 2 ? (int.tryParse(components[2].trim()) ?? 0) : 0;
  return ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | ((b & 0xFF) << 0);
}

bool isNotBlank(String? s) {
  return s != null && s.trim().isNotEmpty;
}

bool isBlank(String? s) {
  return s == null || s.trim().isEmpty;
}
