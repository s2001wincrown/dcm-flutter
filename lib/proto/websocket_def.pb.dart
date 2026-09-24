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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'websocket_def.pbenum.dart';

export 'websocket_def.pbenum.dart';

/// 统一消息包装器 (替代 C++ 的 Header_Struct)
/// WebSocket 自带帧边界，无需再定义 packetlength
class MessageWrapper extends $pb.GeneratedMessage {
  factory MessageWrapper({
    CommandType? command,
    ProtocolId? protocolId,
    $core.List<$core.int>? payload,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (command != null) {
      result.command = command;
    }
    if (protocolId != null) {
      result.protocolId = protocolId;
    }
    if (payload != null) {
      result.payload = payload;
    }
    if (timestamp != null) {
      result.timestamp = timestamp;
    }
    return result;
  }
  MessageWrapper._() : super();
  factory MessageWrapper.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MessageWrapper.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MessageWrapper', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..e<CommandType>(1, _omitFieldNames ? '' : 'command', $pb.PbFieldType.OE, defaultOrMaker: CommandType.CMD_UNKNOWN, valueOf: CommandType.valueOf, enumValues: CommandType.values)
    ..e<ProtocolId>(2, _omitFieldNames ? '' : 'protocolId', $pb.PbFieldType.OE, defaultOrMaker: ProtocolId.PROTOCOL_UNSPECIFIED, valueOf: ProtocolId.valueOf, enumValues: ProtocolId.values)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MessageWrapper clone() => MessageWrapper()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MessageWrapper copyWith(void Function(MessageWrapper) updates) => super.copyWith((message) => updates(message as MessageWrapper)) as MessageWrapper;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageWrapper create() => MessageWrapper._();
  MessageWrapper createEmptyInstance() => create();
  static $pb.PbList<MessageWrapper> createRepeated() => $pb.PbList<MessageWrapper>();
  @$core.pragma('dart2js:noInline')
  static MessageWrapper getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageWrapper>(create);
  static MessageWrapper? _defaultInstance;

  @$pb.TagNumber(1)
  CommandType get command => $_getN(0);
  @$pb.TagNumber(1)
  set command(CommandType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCommand() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommand() => clearField(1);

  @$pb.TagNumber(2)
  ProtocolId get protocolId => $_getN(1);
  @$pb.TagNumber(2)
  set protocolId(ProtocolId v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasProtocolId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProtocolId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestamp => $_getI64(3);
  @$pb.TagNumber(4)
  set timestamp($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTimestamp() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestamp() => clearField(4);
}

/// 心跳消息
class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat({
    $core.String? playerId,
    $core.String? status,
  }) {
    final result = create();
    if (playerId != null) {
      result.playerId = playerId;
    }
    if (status != null) {
      result.status = status;
    }
    return result;
  }
  Heartbeat._() : super();
  factory Heartbeat.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Heartbeat.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Heartbeat', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'playerId', protoName: 'playerId')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Heartbeat clone() => Heartbeat()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Heartbeat copyWith(void Function(Heartbeat) updates) => super.copyWith((message) => updates(message as Heartbeat)) as Heartbeat;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Heartbeat create() => Heartbeat._();
  Heartbeat createEmptyInstance() => create();
  static $pb.PbList<Heartbeat> createRepeated() => $pb.PbList<Heartbeat>();
  @$core.pragma('dart2js:noInline')
  static Heartbeat getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Heartbeat>(create);
  static Heartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get playerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set playerId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPlayerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlayerId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => clearField(2);
}

/// 映射 C++ DCM_Content (去掉了 hton/ntoh 和 定长数组)
class DcmContent extends $pb.GeneratedMessage {
  factory DcmContent({
    $core.String? filePath,
    $core.int? pid,
    $core.bool? allContent,
    $core.bool? includeToday,
    $core.bool? immediate,
    $core.String? ftpTime,
    $core.String? timeout,
    $core.String? startFtpTime,
    $core.int? ftpContent,
    $core.int? period,
    $core.String? task,
    $core.String? validity,
    $core.int? retries,
  }) {
    final result = create();
    if (filePath != null) {
      result.filePath = filePath;
    }
    if (pid != null) {
      result.pid = pid;
    }
    if (allContent != null) {
      result.allContent = allContent;
    }
    if (includeToday != null) {
      result.includeToday = includeToday;
    }
    if (immediate != null) {
      result.immediate = immediate;
    }
    if (ftpTime != null) {
      result.ftpTime = ftpTime;
    }
    if (timeout != null) {
      result.timeout = timeout;
    }
    if (startFtpTime != null) {
      result.startFtpTime = startFtpTime;
    }
    if (ftpContent != null) {
      result.ftpContent = ftpContent;
    }
    if (period != null) {
      result.period = period;
    }
    if (task != null) {
      result.task = task;
    }
    if (validity != null) {
      result.validity = validity;
    }
    if (retries != null) {
      result.retries = retries;
    }
    return result;
  }
  DcmContent._() : super();
  factory DcmContent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DcmContent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DcmContent', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'filePath')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'pid', $pb.PbFieldType.O3)
    ..aOB(3, _omitFieldNames ? '' : 'allContent')
    ..aOB(4, _omitFieldNames ? '' : 'includeToday')
    ..aOB(5, _omitFieldNames ? '' : 'immediate')
    ..aOS(6, _omitFieldNames ? '' : 'ftpTime')
    ..aOS(7, _omitFieldNames ? '' : 'timeout')
    ..aOS(8, _omitFieldNames ? '' : 'startFtpTime')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'ftpContent', $pb.PbFieldType.O3)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'period', $pb.PbFieldType.O3)
    ..aOS(11, _omitFieldNames ? '' : 'task')
    ..aOS(12, _omitFieldNames ? '' : 'validity')
    ..a<$core.int>(13, _omitFieldNames ? '' : 'retries', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DcmContent clone() => DcmContent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DcmContent copyWith(void Function(DcmContent) updates) => super.copyWith((message) => updates(message as DcmContent)) as DcmContent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DcmContent create() => DcmContent._();
  DcmContent createEmptyInstance() => create();
  static $pb.PbList<DcmContent> createRepeated() => $pb.PbList<DcmContent>();
  @$core.pragma('dart2js:noInline')
  static DcmContent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DcmContent>(create);
  static DcmContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get filePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set filePath($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFilePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearFilePath() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get pid => $_getIZ(1);
  @$pb.TagNumber(2)
  set pid($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPid() => $_has(1);
  @$pb.TagNumber(2)
  void clearPid() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get allContent => $_getBF(2);
  @$pb.TagNumber(3)
  set allContent($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAllContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearAllContent() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get includeToday => $_getBF(3);
  @$pb.TagNumber(4)
  set includeToday($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIncludeToday() => $_has(3);
  @$pb.TagNumber(4)
  void clearIncludeToday() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get immediate => $_getBF(4);
  @$pb.TagNumber(5)
  set immediate($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasImmediate() => $_has(4);
  @$pb.TagNumber(5)
  void clearImmediate() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get ftpTime => $_getSZ(5);
  @$pb.TagNumber(6)
  set ftpTime($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasFtpTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearFtpTime() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get timeout => $_getSZ(6);
  @$pb.TagNumber(7)
  set timeout($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimeout() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimeout() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get startFtpTime => $_getSZ(7);
  @$pb.TagNumber(8)
  set startFtpTime($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasStartFtpTime() => $_has(7);
  @$pb.TagNumber(8)
  void clearStartFtpTime() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get ftpContent => $_getIZ(8);
  @$pb.TagNumber(9)
  set ftpContent($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasFtpContent() => $_has(8);
  @$pb.TagNumber(9)
  void clearFtpContent() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get period => $_getIZ(9);
  @$pb.TagNumber(10)
  set period($core.int v) { $_setSignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasPeriod() => $_has(9);
  @$pb.TagNumber(10)
  void clearPeriod() => clearField(10);

  @$pb.TagNumber(11)
  $core.String get task => $_getSZ(10);
  @$pb.TagNumber(11)
  set task($core.String v) { $_setString(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasTask() => $_has(10);
  @$pb.TagNumber(11)
  void clearTask() => clearField(11);

  @$pb.TagNumber(12)
  $core.String get validity => $_getSZ(11);
  @$pb.TagNumber(12)
  set validity($core.String v) { $_setString(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasValidity() => $_has(11);
  @$pb.TagNumber(12)
  void clearValidity() => clearField(12);

  @$pb.TagNumber(13)
  $core.int get retries => $_getIZ(12);
  @$pb.TagNumber(13)
  set retries($core.int v) { $_setSignedInt32(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasRetries() => $_has(12);
  @$pb.TagNumber(13)
  void clearRetries() => clearField(13);
}

/// 映射 C++ Transfer_Status
class TransferStatus extends $pb.GeneratedMessage {
  factory TransferStatus({
    $core.int? errId,
    $core.String? tfStatus,
  }) {
    final result = create();
    if (errId != null) {
      result.errId = errId;
    }
    if (tfStatus != null) {
      result.tfStatus = tfStatus;
    }
    return result;
  }
  TransferStatus._() : super();
  factory TransferStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransferStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TransferStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'errId', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'tfStatus')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransferStatus clone() => TransferStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransferStatus copyWith(void Function(TransferStatus) updates) => super.copyWith((message) => updates(message as TransferStatus)) as TransferStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransferStatus create() => TransferStatus._();
  TransferStatus createEmptyInstance() => create();
  static $pb.PbList<TransferStatus> createRepeated() => $pb.PbList<TransferStatus>();
  @$core.pragma('dart2js:noInline')
  static TransferStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferStatus>(create);
  static TransferStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get errId => $_getIZ(0);
  @$pb.TagNumber(1)
  set errId($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasErrId() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get tfStatus => $_getSZ(1);
  @$pb.TagNumber(2)
  set tfStatus($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTfStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearTfStatus() => clearField(2);
}

/// 映射 C++ Player_Status
class PlayerStatus extends $pb.GeneratedMessage {
  factory PlayerStatus({
    $core.String? siteId,
    $core.int? status,
    $core.String? tfStatus,
    $core.int? ip,
  }) {
    final result = create();
    if (siteId != null) {
      result.siteId = siteId;
    }
    if (status != null) {
      result.status = status;
    }
    if (tfStatus != null) {
      result.tfStatus = tfStatus;
    }
    if (ip != null) {
      result.ip = ip;
    }
    return result;
  }
  PlayerStatus._() : super();
  factory PlayerStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PlayerStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PlayerStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'siteId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'tfStatus')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'ip', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PlayerStatus clone() => PlayerStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PlayerStatus copyWith(void Function(PlayerStatus) updates) => super.copyWith((message) => updates(message as PlayerStatus)) as PlayerStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayerStatus create() => PlayerStatus._();
  PlayerStatus createEmptyInstance() => create();
  static $pb.PbList<PlayerStatus> createRepeated() => $pb.PbList<PlayerStatus>();
  @$core.pragma('dart2js:noInline')
  static PlayerStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayerStatus>(create);
  static PlayerStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get siteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set siteId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSiteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSiteId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get status => $_getIZ(1);
  @$pb.TagNumber(2)
  set status($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get tfStatus => $_getSZ(2);
  @$pb.TagNumber(3)
  set tfStatus($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTfStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearTfStatus() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get ip => $_getIZ(3);
  @$pb.TagNumber(4)
  set ip($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIp() => $_has(3);
  @$pb.TagNumber(4)
  void clearIp() => clearField(4);
}

/// 映射 C++ Message_Info
class MessageInfo extends $pb.GeneratedMessage {
  factory MessageInfo({
    $core.int? messageId,
    $core.String? messageName,
    $core.int? status,
    $core.String? task,
  }) {
    final result = create();
    if (messageId != null) {
      result.messageId = messageId;
    }
    if (messageName != null) {
      result.messageName = messageName;
    }
    if (status != null) {
      result.status = status;
    }
    if (task != null) {
      result.task = task;
    }
    return result;
  }
  MessageInfo._() : super();
  factory MessageInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MessageInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MessageInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'messageId', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'messageName')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'status', $pb.PbFieldType.O3)
    ..aOS(4, _omitFieldNames ? '' : 'task')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MessageInfo clone() => MessageInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MessageInfo copyWith(void Function(MessageInfo) updates) => super.copyWith((message) => updates(message as MessageInfo)) as MessageInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageInfo create() => MessageInfo._();
  MessageInfo createEmptyInstance() => create();
  static $pb.PbList<MessageInfo> createRepeated() => $pb.PbList<MessageInfo>();
  @$core.pragma('dart2js:noInline')
  static MessageInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageInfo>(create);
  static MessageInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get messageId => $_getIZ(0);
  @$pb.TagNumber(1)
  set messageId($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageName => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageName() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageName() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get status => $_getIZ(2);
  @$pb.TagNumber(3)
  set status($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get task => $_getSZ(3);
  @$pb.TagNumber(4)
  set task($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTask() => $_has(3);
  @$pb.TagNumber(4)
  void clearTask() => clearField(4);
}

/// 映射 C++ DCM_Event_Info
class DcmEventInfo extends $pb.GeneratedMessage {
  factory DcmEventInfo({
    $core.int? messageId,
    $core.String? messageName,
    $core.int? ip,
    $core.int? port,
    $core.int? status,
  }) {
    final result = create();
    if (messageId != null) {
      result.messageId = messageId;
    }
    if (messageName != null) {
      result.messageName = messageName;
    }
    if (ip != null) {
      result.ip = ip;
    }
    if (port != null) {
      result.port = port;
    }
    if (status != null) {
      result.status = status;
    }
    return result;
  }
  DcmEventInfo._() : super();
  factory DcmEventInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DcmEventInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DcmEventInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'messageId', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'messageName')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'ip', $pb.PbFieldType.OU3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'port', $pb.PbFieldType.OU3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'status', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DcmEventInfo clone() => DcmEventInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DcmEventInfo copyWith(void Function(DcmEventInfo) updates) => super.copyWith((message) => updates(message as DcmEventInfo)) as DcmEventInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DcmEventInfo create() => DcmEventInfo._();
  DcmEventInfo createEmptyInstance() => create();
  static $pb.PbList<DcmEventInfo> createRepeated() => $pb.PbList<DcmEventInfo>();
  @$core.pragma('dart2js:noInline')
  static DcmEventInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DcmEventInfo>(create);
  static DcmEventInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get messageId => $_getIZ(0);
  @$pb.TagNumber(1)
  set messageId($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageName => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageName() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageName() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get ip => $_getIZ(2);
  @$pb.TagNumber(3)
  set ip($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIp() => $_has(2);
  @$pb.TagNumber(3)
  void clearIp() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get port => $_getIZ(3);
  @$pb.TagNumber(4)
  set port($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPort() => $_has(3);
  @$pb.TagNumber(4)
  void clearPort() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get status => $_getIZ(4);
  @$pb.TagNumber(5)
  set status($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => clearField(5);
}

/// 映射 C++ AH_Sender
class AhSender extends $pb.GeneratedMessage {
  factory AhSender({
    $core.int? messageId,
    $core.String? messageName,
    $core.String? startTime,
    $core.String? endTime,
    $core.String? createTime,
    $core.int? status,
    $core.bool? endManual,
  }) {
    final result = create();
    if (messageId != null) {
      result.messageId = messageId;
    }
    if (messageName != null) {
      result.messageName = messageName;
    }
    if (startTime != null) {
      result.startTime = startTime;
    }
    if (endTime != null) {
      result.endTime = endTime;
    }
    if (createTime != null) {
      result.createTime = createTime;
    }
    if (status != null) {
      result.status = status;
    }
    if (endManual != null) {
      result.endManual = endManual;
    }
    return result;
  }
  AhSender._() : super();
  factory AhSender.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AhSender.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AhSender', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.digitalsignage.protocol'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'messageId', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'messageName')
    ..aOS(3, _omitFieldNames ? '' : 'startTime')
    ..aOS(4, _omitFieldNames ? '' : 'endTime')
    ..aOS(5, _omitFieldNames ? '' : 'createTime')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'status', $pb.PbFieldType.O3)
    ..aOB(7, _omitFieldNames ? '' : 'endManual')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AhSender clone() => AhSender()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AhSender copyWith(void Function(AhSender) updates) => super.copyWith((message) => updates(message as AhSender)) as AhSender;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AhSender create() => AhSender._();
  AhSender createEmptyInstance() => create();
  static $pb.PbList<AhSender> createRepeated() => $pb.PbList<AhSender>();
  @$core.pragma('dart2js:noInline')
  static AhSender getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AhSender>(create);
  static AhSender? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get messageId => $_getIZ(0);
  @$pb.TagNumber(1)
  set messageId($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageName => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageName() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get startTime => $_getSZ(2);
  @$pb.TagNumber(3)
  set startTime($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartTime() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get endTime => $_getSZ(3);
  @$pb.TagNumber(4)
  set endTime($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasEndTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndTime() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get createTime => $_getSZ(4);
  @$pb.TagNumber(5)
  set createTime($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasCreateTime() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreateTime() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get status => $_getIZ(5);
  @$pb.TagNumber(6)
  set status($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => clearField(6);

  @$pb.TagNumber(7)
  $core.bool get endManual => $_getBF(6);
  @$pb.TagNumber(7)
  set endManual($core.bool v) { $_setBool(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasEndManual() => $_has(6);
  @$pb.TagNumber(7)
  void clearEndManual() => clearField(7);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
