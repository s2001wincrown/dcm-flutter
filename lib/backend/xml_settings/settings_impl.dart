import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

// --- Data Model: SettingData ---

class SettingData {
  final int id;
  final int groupId;
  final int type;
  final String group;
  final String name;
  final int valueType; // 0: String, 1: Int, etc. (Assumed mapping)
  final String defaultValue;
  final String value;

  SettingData({
    this.id = 0,
    this.groupId = 0,
    this.type = 0,
    this.group = '',
    this.name = '',
    this.valueType = 0,
    this.defaultValue = '',
    this.value = '',
  });

  // Copy constructor equivalent
  SettingData copyWith({
    int? id,
    int? groupId,
    int? type,
    String? group,
    String? name,
    int? valueType,
    String? defaultValue,
    String? value,
  }) {
    return SettingData(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      group: group ?? this.group,
      name: name ?? this.name,
      valueType: valueType ?? this.valueType,
      defaultValue: defaultValue ?? this.defaultValue,
      value: value ?? this.value,
    );
  }
}

// --- Manager: SettingsImpl ---

class SettingsImpl {
  /// Check if settings file exists and is valid
  static Future<bool> settingsIsOk({String? dcmPath}) async {
    final strDCMPath = dcmPath ?? App().dataPath;
    final filePath = path.join(strDCMPath, configFILENAME);
    if (!await File(filePath).exists()) {
      return false;
    }

    IniFile settingsFile = IniFile(filePath);
    return settingsFile.sections.isNotEmpty;
  }

  /// Reset/Delete the settings file
  static Future<void> reset({String? dcmPath}) async {
    try {
      final strDCMPath = dcmPath ?? App().dataPath;
      final filePath = path.join(strDCMPath, configFILENAME);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }

  static bool loadFromXml(String strXml) {
    XmlFile playbackSettings = XmlFile('PlaybackSetting');
    if (playbackSettings.loadXml(strXml)) {
      return (DCMGlobal.loadGlobalSetting(playbackSettings));
    }

    return false;
  }

  static void writeToXml(XmlItem pXmlItem, SettingData pSettings) {
    // write some stuff in the profile
    pXmlItem.addItem('m_uiID', pSettings.id);
    pXmlItem.addItem('m_uiGroupID', pSettings.groupId);
    pXmlItem.addItem('m_uiType', pSettings.type);
    pXmlItem.addItem('m_strGroup', pSettings.group);
    pXmlItem.addItem('m_strName', pSettings.name);
    pXmlItem.addItem('m_uiValueType', pSettings.valueType);
    pXmlItem.addItem('m_strDefaValue', pSettings.defaultValue);
    pXmlItem.addItem('m_strValue', pSettings.value);
  }

  static SettingData getFromXml(XmlItem pXmlItem) {
    return SettingData(
      id: pXmlItem.getItemValueI('m_uiID'),
      groupId: pXmlItem.getItemValueI('m_uiGroupID'),
      type: pXmlItem.getItemValueI('m_uiType'),
      group: pXmlItem.getItemValue('m_strGroup'),
      name: pXmlItem.getItemValue('m_strName'),
      valueType: pXmlItem.getItemValueI('m_uiValueType'),
      defaultValue: pXmlItem.getItemValue('m_strDefaValue'),
      value: pXmlItem.getItemValue('m_strValue'),
    );
  }
}
