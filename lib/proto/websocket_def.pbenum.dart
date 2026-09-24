//
//  Generated code. Do not modify.
//  source: websocket_def.protobuf
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// 映射 C++ 中的 PROTOCOLID
class ProtocolId extends $pb.ProtobufEnum {
  static const ProtocolId PROTOCOL_UNSPECIFIED = ProtocolId._(0, _omitEnumNames ? '' : 'PROTOCOL_UNSPECIFIED');
  static const ProtocolId PROTOCOL_ANY = ProtocolId._(-1, _omitEnumNames ? '' : 'PROTOCOL_ANY');
  static const ProtocolId PROTOCOL_AH = ProtocolId._(1, _omitEnumNames ? '' : 'PROTOCOL_AH');
  static const ProtocolId PROTOCOL_QC = ProtocolId._(2, _omitEnumNames ? '' : 'PROTOCOL_QC');
  static const ProtocolId PROTOCOL_LM = ProtocolId._(3, _omitEnumNames ? '' : 'PROTOCOL_LM');
  static const ProtocolId PROTOCOL_CS = ProtocolId._(4, _omitEnumNames ? '' : 'PROTOCOL_CS');

  static const ProtocolId PROTOCOL_NULL = PROTOCOL_UNSPECIFIED;

  static const $core.List<ProtocolId> values = <ProtocolId> [
    PROTOCOL_UNSPECIFIED,
    PROTOCOL_ANY,
    PROTOCOL_AH,
    PROTOCOL_QC,
    PROTOCOL_LM,
    PROTOCOL_CS,
  ];

  static final $core.Map<$core.int, ProtocolId> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ProtocolId? valueOf($core.int value) => _byValue[value];

  const ProtocolId._($core.int v, $core.String n) : super(v, n);
}

/// 映射 C++ 中的 Net_Command (网络命令 ID)
class CommandType extends $pb.ProtobufEnum {
  static const CommandType CMD_UNKNOWN = CommandType._(0, _omitEnumNames ? '' : 'CMD_UNKNOWN');
  static const CommandType CMD_REQUEST_SYNC_TIME = CommandType._(1, _omitEnumNames ? '' : 'CMD_REQUEST_SYNC_TIME');
  static const CommandType CMD_REGISTER_UPDATE = CommandType._(2, _omitEnumNames ? '' : 'CMD_REGISTER_UPDATE');
  static const CommandType CMD_REQUEST_DCM_CONTENT = CommandType._(3, _omitEnumNames ? '' : 'CMD_REQUEST_DCM_CONTENT');
  static const CommandType CMD_DCM_CONTENT = CommandType._(4, _omitEnumNames ? '' : 'CMD_DCM_CONTENT');
  static const CommandType CMD_AH_SENDER = CommandType._(5, _omitEnumNames ? '' : 'CMD_AH_SENDER');
  static const CommandType CMD_AH_MESSAGE = CommandType._(6, _omitEnumNames ? '' : 'CMD_AH_MESSAGE');
  static const CommandType CMD_EVENT_MESSAGE = CommandType._(7, _omitEnumNames ? '' : 'CMD_EVENT_MESSAGE');
  static const CommandType CMD_PLAYER_STATUS = CommandType._(8, _omitEnumNames ? '' : 'CMD_PLAYER_STATUS');
  static const CommandType CMD_TRANSFER_STATUS = CommandType._(9, _omitEnumNames ? '' : 'CMD_TRANSFER_STATUS');
  static const CommandType CMD_REGISTER = CommandType._(10, _omitEnumNames ? '' : 'CMD_REGISTER');
  static const CommandType CMD_RESET_TASKS = CommandType._(11, _omitEnumNames ? '' : 'CMD_RESET_TASKS');
  static const CommandType CMD_RESET_SETTINGS = CommandType._(12, _omitEnumNames ? '' : 'CMD_RESET_SETTINGS');
  static const CommandType CMD_RESET_TRANSFER = CommandType._(13, _omitEnumNames ? '' : 'CMD_RESET_TRANSFER');
  static const CommandType CMD_WEATHER = CommandType._(14, _omitEnumNames ? '' : 'CMD_WEATHER');
  static const CommandType CMD_CONTENT_LIST = CommandType._(15, _omitEnumNames ? '' : 'CMD_CONTENT_LIST');
  static const CommandType CMD_MONITOR = CommandType._(16, _omitEnumNames ? '' : 'CMD_MONITOR');
  static const CommandType CMD_RESET_DCM_PLAYER = CommandType._(17, _omitEnumNames ? '' : 'CMD_RESET_DCM_PLAYER');
  static const CommandType CMD_RESET_HOST = CommandType._(18, _omitEnumNames ? '' : 'CMD_RESET_HOST');
  static const CommandType CMD_SMS_CONTROL = CommandType._(19, _omitEnumNames ? '' : 'CMD_SMS_CONTROL');
  static const CommandType CMD_SHUTDOWN = CommandType._(20, _omitEnumNames ? '' : 'CMD_SHUTDOWN');
  static const CommandType CMD_UNIQUE_NAME = CommandType._(21, _omitEnumNames ? '' : 'CMD_UNIQUE_NAME');
  static const CommandType CMD_CONNECTION = CommandType._(22, _omitEnumNames ? '' : 'CMD_CONNECTION');
  static const CommandType CMD_LIGHT_BOX = CommandType._(23, _omitEnumNames ? '' : 'CMD_LIGHT_BOX');
  static const CommandType CMD_REFRESH = CommandType._(24, _omitEnumNames ? '' : 'CMD_REFRESH');
  static const CommandType CMD_DISK_CLEAN = CommandType._(25, _omitEnumNames ? '' : 'CMD_DISK_CLEAN');
  static const CommandType CMD_HEARTBEAT = CommandType._(26, _omitEnumNames ? '' : 'CMD_HEARTBEAT');

  static const $core.List<CommandType> values = <CommandType> [
    CMD_UNKNOWN,
    CMD_REQUEST_SYNC_TIME,
    CMD_REGISTER_UPDATE,
    CMD_REQUEST_DCM_CONTENT,
    CMD_DCM_CONTENT,
    CMD_AH_SENDER,
    CMD_AH_MESSAGE,
    CMD_EVENT_MESSAGE,
    CMD_PLAYER_STATUS,
    CMD_TRANSFER_STATUS,
    CMD_REGISTER,
    CMD_RESET_TASKS,
    CMD_RESET_SETTINGS,
    CMD_RESET_TRANSFER,
    CMD_WEATHER,
    CMD_CONTENT_LIST,
    CMD_MONITOR,
    CMD_RESET_DCM_PLAYER,
    CMD_RESET_HOST,
    CMD_SMS_CONTROL,
    CMD_SHUTDOWN,
    CMD_UNIQUE_NAME,
    CMD_CONNECTION,
    CMD_LIGHT_BOX,
    CMD_REFRESH,
    CMD_DISK_CLEAN,
    CMD_HEARTBEAT,
  ];

  static final $core.Map<$core.int, CommandType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CommandType? valueOf($core.int value) => _byValue[value];

  const CommandType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
