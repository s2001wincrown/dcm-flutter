import 'dart:io';

import 'package:dcm/backend/models/channel_data.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

class ChannelImpl {
  String get channelListFile =>
      path.join(DCMGlobal.settingPath, 'channels.xml');

  bool saveChannelList(List<ChannelData> lstChannel, {String? filePath}) {
    String fullPath = filePath ?? channelListFile;
    XmlFilePro file = XmlFilePro('ChannelList');
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
    file.setSignature('Channel List');
    return file.save(fullPath);
  }

  bool saveChannelItem(ChannelData channelData, {String? filePath}) {
    final channels = <ChannelData>[];
    if (!loadChannelList(channels, filePath: filePath)) {
      channels.clear();
    }
    channels.removeWhere((item) =>
        item.channelName.toLowerCase() ==
        channelData.channelName.toLowerCase());
    channels.add(channelData);
    return saveChannelList(channels, filePath: filePath);
  }

  bool loadChannelList(List<ChannelData> lstChannel, {String? filePath}) {
    String fullPath = filePath ?? channelListFile;
    lstChannel.clear();
    File fileDisk = File(fullPath);
    if (!fileDisk.existsSync()) {
      return false;
    }

    XmlFilePro file = XmlFilePro('ChannelList');
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

  bool deleteChannel(String strChannel, {String? filePath}) {
    final channels = <ChannelData>[];
    if (!loadChannelList(channels, filePath: filePath)) {
      return false;
    }
    final before = channels.length;
    channels.removeWhere(
        (item) => item.channelName.toLowerCase() == strChannel.toLowerCase());
    if (channels.length == before) {
      return false;
    }
    return saveChannelList(channels, filePath: filePath);
  }

  bool isChannelExisted(String strChannel, {String? filePath}) {
    final channels = <ChannelData>[];
    if (!loadChannelList(channels, filePath: filePath)) {
      return false;
    }
    return channels.any(
        (item) => item.channelName.toLowerCase() == strChannel.toLowerCase());
  }

  bool loadAllChannelSchedule(
      List<ChannelData> lstChannel, DateTime dtSchedule, Object file) {
    // The original C++ implementation depends on a specialized channel schedule
    // file parser. This method is preserved as a stub and should be implemented
    // once the schedule XML format is available.
    return false;
  }

  bool loadAllChannelScheduleByMonth(
      List<ChannelData> lstChannel, String month, Object file) {
    return false;
  }
}
