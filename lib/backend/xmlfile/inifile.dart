import 'dart:convert';
import 'dart:io';

import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:path_provider/path_provider.dart';

/// INI文件类
class IniFile {
  Map<String, Map<String, String>> sections = {};
  String currentSection = '';
  String? _fileName;
  Map<String, String> currentProperties = {};

  IniFile([String? filename]) {
    if (isNotBlank(filename)) {
      _fileName = filename;
      try {
        String content = File(filename!).readAsStringSync();
        _parse(content);
      } catch (e) {
        logE('IniFile - Error loading ini file: $e.');
      }
    }
  }

  Future<void> loadFile(String filename) async {
    _fileName = filename;
    try {
      String content = await File(filename).readAsString();
      _parse(content);
    } catch (e) {
      logE(
          'IniFile - Error loading ini file: $e, getApplicationSupportDirectory: ${(await getApplicationSupportDirectory()).path}');
    }
  }

  void _parse(String content) {
    List<String> lines = LineSplitter.split(content).toList();
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty ||
          line.startsWith(';') ||
          line.startsWith('#') ||
          line.startsWith('//')) {
        continue;
      }

      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1);
        currentProperties = {};
        sections[currentSection] = currentProperties;
      } else if (line.contains('=')) {
        int index = line.indexOf('=');
        String name = line.substring(0, index).trim();
        String value = line.substring(index + 1).trim();
        currentProperties[name] = value;
      }
    }
  }

  String? getValue(String section, String name) {
    Map<String, String>? props = sections[section];
    return props?[name];
  }

  void setValue(String section, String name, dynamic value) {
    sections.putIfAbsent(section, () => {});
    sections[section]?[name] = value;
  }

  String readString(String section, String name, [String defaultValue = '']) {
    String? value = getValue(section, name);
    return value ?? defaultValue;
  }

  bool writeString(String section, String name, String value) {
    sections.putIfAbsent(section, () => {});
    sections[section]?[name] = value;
    return true;
  }

  int readInt(String section, String name, [int defaultValue = 0]) {
    String? value = getValue(section, name);
    return int.tryParse(value ?? '') ?? defaultValue;
  }

  bool writeInt(String section, String name, int value) {
    sections.putIfAbsent(section, () => {});
    sections[section]?[name] = value.toString();
    return true;
  }

  double readFloat(String section, String name, [double defaultValue = 0.0]) {
    String? value = getValue(section, name);
    return double.tryParse(value ?? '') ?? defaultValue;
  }

  bool writeFloat(String section, String name, double value) {
    sections.putIfAbsent(section, () => {});
    sections[section]?[name] = value.toString();
    return true;
  }

  bool readBool(String section, String name, [bool defaultValue = false]) {
    String? value = getValue(section, name);
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true' || value == '1';
  }

  bool writeBool(String section, String name, bool value) {
    sections.putIfAbsent(section, () => {});
    sections[section]?[name] = value ? 'true' : 'false';
    return true;
  }

  Future<bool> save([String? strFName]) async {
    strFName ??= _fileName;
    if (isBlank(strFName)) return false;

    final textfile = File(strFName!);
    String content = '';
    for (var i in sections.keys) {
      content += '[$i]';
      content += '\n';
      for (var isec in sections[i]!.keys) {
        content += '$isec=${sections[i]![isec]!}';
        content += '\n';
      }
      content += '\n';
    }
    try {
      await textfile.writeAsString(content, flush: true);
      return true;
    } catch (e) {
      logE('Error saving ini file: $e');
    }

    return false;
  }
}
