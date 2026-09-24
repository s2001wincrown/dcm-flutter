//
//  Generated code. Do not modify.
//  source: websocket_def.protobuf
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use protocolIdDescriptor instead')
const ProtocolId$json = {
  '1': 'ProtocolId',
  '2': [
    {'1': 'PROTOCOL_UNSPECIFIED', '2': 0},
    {'1': 'PROTOCOL_ANY', '2': -1},
    {'1': 'PROTOCOL_NULL', '2': 0},
    {'1': 'PROTOCOL_AH', '2': 1},
    {'1': 'PROTOCOL_QC', '2': 2},
    {'1': 'PROTOCOL_LM', '2': 3},
    {'1': 'PROTOCOL_CS', '2': 4},
  ],
  '3': {'2': true},
};

/// Descriptor for `ProtocolId`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List protocolIdDescriptor = $convert.base64Decode(
    'CgpQcm90b2NvbElkEhgKFFBST1RPQ09MX1VOU1BFQ0lGSUVEEAASGQoMUFJPVE9DT0xfQU5ZEP'
    '///////////wESEQoNUFJPVE9DT0xfTlVMTBAAEg8KC1BST1RPQ09MX0FIEAESDwoLUFJPVE9D'
    'T0xfUUMQAhIPCgtQUk9UT0NPTF9MTRADEg8KC1BST1RPQ09MX0NTEAQaAhAB');

@$core.Deprecated('Use commandTypeDescriptor instead')
const CommandType$json = {
  '1': 'CommandType',
  '2': [
    {'1': 'CMD_UNKNOWN', '2': 0},
    {'1': 'CMD_REQUEST_SYNC_TIME', '2': 1},
    {'1': 'CMD_REGISTER_UPDATE', '2': 2},
    {'1': 'CMD_REQUEST_DCM_CONTENT', '2': 3},
    {'1': 'CMD_DCM_CONTENT', '2': 4},
    {'1': 'CMD_AH_SENDER', '2': 5},
    {'1': 'CMD_AH_MESSAGE', '2': 6},
    {'1': 'CMD_EVENT_MESSAGE', '2': 7},
    {'1': 'CMD_PLAYER_STATUS', '2': 8},
    {'1': 'CMD_TRANSFER_STATUS', '2': 9},
    {'1': 'CMD_REGISTER', '2': 10},
    {'1': 'CMD_RESET_TASKS', '2': 11},
    {'1': 'CMD_RESET_SETTINGS', '2': 12},
    {'1': 'CMD_RESET_TRANSFER', '2': 13},
    {'1': 'CMD_WEATHER', '2': 14},
    {'1': 'CMD_CONTENT_LIST', '2': 15},
    {'1': 'CMD_MONITOR', '2': 16},
    {'1': 'CMD_RESET_DCM_PLAYER', '2': 17},
    {'1': 'CMD_RESET_HOST', '2': 18},
    {'1': 'CMD_SMS_CONTROL', '2': 19},
    {'1': 'CMD_SHUTDOWN', '2': 20},
    {'1': 'CMD_UNIQUE_NAME', '2': 21},
    {'1': 'CMD_CONNECTION', '2': 22},
    {'1': 'CMD_LIGHT_BOX', '2': 23},
    {'1': 'CMD_REFRESH', '2': 24},
    {'1': 'CMD_DISK_CLEAN', '2': 25},
    {'1': 'CMD_HEARTBEAT', '2': 26},
  ],
};

/// Descriptor for `CommandType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List commandTypeDescriptor = $convert.base64Decode(
    'CgtDb21tYW5kVHlwZRIPCgtDTURfVU5LTk9XThAAEhkKFUNNRF9SRVFVRVNUX1NZTkNfVElNRR'
    'ABEhcKE0NNRF9SRUdJU1RFUl9VUERBVEUQAhIbChdDTURfUkVRVUVTVF9EQ01fQ09OVEVOVBAD'
    'EhMKD0NNRF9EQ01fQ09OVEVOVBAEEhEKDUNNRF9BSF9TRU5ERVIQBRISCg5DTURfQUhfTUVTU0'
    'FHRRAGEhUKEUNNRF9FVkVOVF9NRVNTQUdFEAcSFQoRQ01EX1BMQVlFUl9TVEFUVVMQCBIXChND'
    'TURfVFJBTlNGRVJfU1RBVFVTEAkSEAoMQ01EX1JFR0lTVEVSEAoSEwoPQ01EX1JFU0VUX1RBU0'
    'tTEAsSFgoSQ01EX1JFU0VUX1NFVFRJTkdTEAwSFgoSQ01EX1JFU0VUX1RSQU5TRkVSEA0SDwoL'
    'Q01EX1dFQVRIRVIQDhIUChBDTURfQ09OVEVOVF9MSVNUEA8SDwoLQ01EX01PTklUT1IQEBIYCh'
    'RDTURfUkVTRVRfRENNX1BMQVlFUhAREhIKDkNNRF9SRVNFVF9IT1NUEBISEwoPQ01EX1NNU19D'
    'T05UUk9MEBMSEAoMQ01EX1NIVVRET1dOEBQSEwoPQ01EX1VOSVFVRV9OQU1FEBUSEgoOQ01EX0'
    'NPTk5FQ1RJT04QFhIRCg1DTURfTElHSFRfQk9YEBcSDwoLQ01EX1JFRlJFU0gQGBISCg5DTURf'
    'RElTS19DTEVBThAZEhEKDUNNRF9IRUFSVEJFQVQQGg==');

@$core.Deprecated('Use messageWrapperDescriptor instead')
const MessageWrapper$json = {
  '1': 'MessageWrapper',
  '2': [
    {'1': 'command', '3': 1, '4': 1, '5': 14, '6': '.com.digitalsignage.protocol.CommandType', '10': 'command'},
    {'1': 'protocol_id', '3': 2, '4': 1, '5': 14, '6': '.com.digitalsignage.protocol.ProtocolId', '10': 'protocolId'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'timestamp', '3': 4, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `MessageWrapper`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageWrapperDescriptor = $convert.base64Decode(
    'Cg5NZXNzYWdlV3JhcHBlchJCCgdjb21tYW5kGAEgASgOMiguY29tLmRpZ2l0YWxzaWduYWdlLn'
    'Byb3RvY29sLkNvbW1hbmRUeXBlUgdjb21tYW5kEkgKC3Byb3RvY29sX2lkGAIgASgOMicuY29t'
    'LmRpZ2l0YWxzaWduYWdlLnByb3RvY29sLlByb3RvY29sSWRSCnByb3RvY29sSWQSGAoHcGF5bG'
    '9hZBgDIAEoDFIHcGF5bG9hZBIcCgl0aW1lc3RhbXAYBCABKANSCXRpbWVzdGFtcA==');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {'1': 'playerId', '3': 1, '4': 1, '5': 9, '10': 'playerId'},
    {'1': 'status', '3': 2, '4': 1, '5': 9, '10': 'status'},
  ],
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor = $convert.base64Decode(
    'CglIZWFydGJlYXQSGgoIcGxheWVySWQYASABKAlSCHBsYXllcklkEhYKBnN0YXR1cxgCIAEoCV'
    'IGc3RhdHVz');

@$core.Deprecated('Use dcmContentDescriptor instead')
const DcmContent$json = {
  '1': 'DcmContent',
  '2': [
    {'1': 'file_path', '3': 1, '4': 1, '5': 9, '10': 'filePath'},
    {'1': 'pid', '3': 2, '4': 1, '5': 5, '10': 'pid'},
    {'1': 'all_content', '3': 3, '4': 1, '5': 8, '10': 'allContent'},
    {'1': 'include_today', '3': 4, '4': 1, '5': 8, '10': 'includeToday'},
    {'1': 'immediate', '3': 5, '4': 1, '5': 8, '10': 'immediate'},
    {'1': 'ftp_time', '3': 6, '4': 1, '5': 9, '10': 'ftpTime'},
    {'1': 'timeout', '3': 7, '4': 1, '5': 9, '10': 'timeout'},
    {'1': 'start_ftp_time', '3': 8, '4': 1, '5': 9, '10': 'startFtpTime'},
    {'1': 'ftp_content', '3': 9, '4': 1, '5': 5, '10': 'ftpContent'},
    {'1': 'period', '3': 10, '4': 1, '5': 5, '10': 'period'},
    {'1': 'task', '3': 11, '4': 1, '5': 9, '10': 'task'},
    {'1': 'validity', '3': 12, '4': 1, '5': 9, '10': 'validity'},
    {'1': 'retries', '3': 13, '4': 1, '5': 5, '10': 'retries'},
  ],
};

/// Descriptor for `DcmContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dcmContentDescriptor = $convert.base64Decode(
    'CgpEY21Db250ZW50EhsKCWZpbGVfcGF0aBgBIAEoCVIIZmlsZVBhdGgSEAoDcGlkGAIgASgFUg'
    'NwaWQSHwoLYWxsX2NvbnRlbnQYAyABKAhSCmFsbENvbnRlbnQSIwoNaW5jbHVkZV90b2RheRgE'
    'IAEoCFIMaW5jbHVkZVRvZGF5EhwKCWltbWVkaWF0ZRgFIAEoCFIJaW1tZWRpYXRlEhkKCGZ0cF'
    '90aW1lGAYgASgJUgdmdHBUaW1lEhgKB3RpbWVvdXQYByABKAlSB3RpbWVvdXQSJAoOc3RhcnRf'
    'ZnRwX3RpbWUYCCABKAlSDHN0YXJ0RnRwVGltZRIfCgtmdHBfY29udGVudBgJIAEoBVIKZnRwQ2'
    '9udGVudBIWCgZwZXJpb2QYCiABKAVSBnBlcmlvZBISCgR0YXNrGAsgASgJUgR0YXNrEhoKCHZh'
    'bGlkaXR5GAwgASgJUgh2YWxpZGl0eRIYCgdyZXRyaWVzGA0gASgFUgdyZXRyaWVz');

@$core.Deprecated('Use transferStatusDescriptor instead')
const TransferStatus$json = {
  '1': 'TransferStatus',
  '2': [
    {'1': 'err_id', '3': 1, '4': 1, '5': 5, '10': 'errId'},
    {'1': 'tf_status', '3': 2, '4': 1, '5': 9, '10': 'tfStatus'},
  ],
};

/// Descriptor for `TransferStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferStatusDescriptor = $convert.base64Decode(
    'Cg5UcmFuc2ZlclN0YXR1cxIVCgZlcnJfaWQYASABKAVSBWVycklkEhsKCXRmX3N0YXR1cxgCIA'
    'EoCVIIdGZTdGF0dXM=');

@$core.Deprecated('Use playerStatusDescriptor instead')
const PlayerStatus$json = {
  '1': 'PlayerStatus',
  '2': [
    {'1': 'site_id', '3': 1, '4': 1, '5': 9, '10': 'siteId'},
    {'1': 'status', '3': 2, '4': 1, '5': 13, '10': 'status'},
    {'1': 'tf_status', '3': 3, '4': 1, '5': 9, '10': 'tfStatus'},
    {'1': 'ip', '3': 4, '4': 1, '5': 13, '10': 'ip'},
  ],
};

/// Descriptor for `PlayerStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerStatusDescriptor = $convert.base64Decode(
    'CgxQbGF5ZXJTdGF0dXMSFwoHc2l0ZV9pZBgBIAEoCVIGc2l0ZUlkEhYKBnN0YXR1cxgCIAEoDV'
    'IGc3RhdHVzEhsKCXRmX3N0YXR1cxgDIAEoCVIIdGZTdGF0dXMSDgoCaXAYBCABKA1SAmlw');

@$core.Deprecated('Use messageInfoDescriptor instead')
const MessageInfo$json = {
  '1': 'MessageInfo',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 5, '10': 'messageId'},
    {'1': 'message_name', '3': 2, '4': 1, '5': 9, '10': 'messageName'},
    {'1': 'status', '3': 3, '4': 1, '5': 5, '10': 'status'},
    {'1': 'task', '3': 4, '4': 1, '5': 9, '10': 'task'},
  ],
};

/// Descriptor for `MessageInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageInfoDescriptor = $convert.base64Decode(
    'CgtNZXNzYWdlSW5mbxIdCgptZXNzYWdlX2lkGAEgASgFUgltZXNzYWdlSWQSIQoMbWVzc2FnZV'
    '9uYW1lGAIgASgJUgttZXNzYWdlTmFtZRIWCgZzdGF0dXMYAyABKAVSBnN0YXR1cxISCgR0YXNr'
    'GAQgASgJUgR0YXNr');

@$core.Deprecated('Use dcmEventInfoDescriptor instead')
const DcmEventInfo$json = {
  '1': 'DcmEventInfo',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 5, '10': 'messageId'},
    {'1': 'message_name', '3': 2, '4': 1, '5': 9, '10': 'messageName'},
    {'1': 'ip', '3': 3, '4': 1, '5': 13, '10': 'ip'},
    {'1': 'port', '3': 4, '4': 1, '5': 13, '10': 'port'},
    {'1': 'status', '3': 5, '4': 1, '5': 5, '10': 'status'},
  ],
};

/// Descriptor for `DcmEventInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dcmEventInfoDescriptor = $convert.base64Decode(
    'CgxEY21FdmVudEluZm8SHQoKbWVzc2FnZV9pZBgBIAEoBVIJbWVzc2FnZUlkEiEKDG1lc3NhZ2'
    'VfbmFtZRgCIAEoCVILbWVzc2FnZU5hbWUSDgoCaXAYAyABKA1SAmlwEhIKBHBvcnQYBCABKA1S'
    'BHBvcnQSFgoGc3RhdHVzGAUgASgFUgZzdGF0dXM=');

@$core.Deprecated('Use ahSenderDescriptor instead')
const AhSender$json = {
  '1': 'AhSender',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 5, '10': 'messageId'},
    {'1': 'message_name', '3': 2, '4': 1, '5': 9, '10': 'messageName'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 9, '10': 'startTime'},
    {'1': 'end_time', '3': 4, '4': 1, '5': 9, '10': 'endTime'},
    {'1': 'create_time', '3': 5, '4': 1, '5': 9, '10': 'createTime'},
    {'1': 'status', '3': 6, '4': 1, '5': 5, '10': 'status'},
    {'1': 'end_manual', '3': 7, '4': 1, '5': 8, '10': 'endManual'},
  ],
};

/// Descriptor for `AhSender`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ahSenderDescriptor = $convert.base64Decode(
    'CghBaFNlbmRlchIdCgptZXNzYWdlX2lkGAEgASgFUgltZXNzYWdlSWQSIQoMbWVzc2FnZV9uYW'
    '1lGAIgASgJUgttZXNzYWdlTmFtZRIdCgpzdGFydF90aW1lGAMgASgJUglzdGFydFRpbWUSGQoI'
    'ZW5kX3RpbWUYBCABKAlSB2VuZFRpbWUSHwoLY3JlYXRlX3RpbWUYBSABKAlSCmNyZWF0ZVRpbW'
    'USFgoGc3RhdHVzGAYgASgFUgZzdGF0dXMSHQoKZW5kX21hbnVhbBgHIAEoCFIJZW5kTWFudWFs');

