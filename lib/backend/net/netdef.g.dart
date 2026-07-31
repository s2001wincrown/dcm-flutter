// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'netdef.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageInfo _$MessageInfoFromJson(Map<String, dynamic> json) => MessageInfo()
  ..messageID = (json['messageID'] as num).toInt()
  ..messageName = json['messageName'] as String
  ..status = (json['status'] as num).toInt()
  ..task = json['task'] as String;

Map<String, dynamic> _$MessageInfoToJson(MessageInfo instance) =>
    <String, dynamic>{
      'messageID': instance.messageID,
      'messageName': instance.messageName,
      'status': instance.status,
      'task': instance.task,
    };
