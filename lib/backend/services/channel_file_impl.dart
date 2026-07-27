import 'dart:io';

import 'package:dcm/backend/models/channel_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

class ChannelFileImpl {
  String channelPath = AppGlobal.settingPath;

  String get channelFile => path.join(channelPath, 'channel.xml');

  bool saveChannelList(List<ChannelData> lstChannel, {String? filePath}) {
    String fullPath = filePath ?? channelFile;
    XmlFilePro file = XmlFilePro('ChannelInformation');
    XmlItem? root = file.root();
    if (root == null) return false;

    for (var channel in lstChannel) {
      XmlItem? xi = root.addItem('ChannelItem');
      if (xi != null) {
        xi.addItem('m_nID', channel.id);
        xi.addItem('m_strChannelName', channel.channelName);
        xi.addItem('m_strChannelDesc', channel.channelDesc);
      }
    }

    return file.save(fullPath);
  }

  bool loadChannelList(List<ChannelData> lstChannel, {String? filePath}) {
    String fullPath = filePath ?? channelFile;
    lstChannel.clear();

    File fileDisk = File(fullPath);
    if (!fileDisk.existsSync()) {
      return false;
    }

    XmlFilePro file = XmlFilePro('ChannelInformation');
    if (!file.open(fullPath, XfOpen.read)) {
      return false;
    }

    if (!file.loadEx()) {
      return false;
    }

    XmlItem? xiChannel = file.getItem('ChannelItem');
    while (xiChannel != null) {
      ChannelData data = ChannelData();
      data.id = xiChannel.getItemValueI('m_nID');
      data.channelName = xiChannel.getItemValue('m_strChannelName');
      data.channelDesc = xiChannel.getItemValue('m_strChannelDesc');
      lstChannel.add(data);
      xiChannel = xiChannel.getSibling();
    }

    return lstChannel.isNotEmpty;
  }

  bool deleteChannel(String channelName, {String? filePath}) {
    final channels = <ChannelData>[];
    if (!loadChannelList(channels, filePath: filePath)) {
      return false;
    }

    final before = channels.length;
    channels.removeWhere(
        (item) => item.channelName.toLowerCase() == channelName.toLowerCase());
    if (channels.length == before) {
      return false;
    }

    return saveChannelList(channels, filePath: filePath);
  }

  bool isChannelExisted(String channelName, {String? filePath}) {
    final channels = <ChannelData>[];
    if (!loadChannelList(channels, filePath: filePath)) {
      return false;
    }
    return channels.any(
        (item) => item.channelName.toLowerCase() == channelName.toLowerCase());
  }
}
