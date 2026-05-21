import 'dart:io';

import 'package:dcm/backend/models/channel_player.dart';
import 'package:dcm/backend/models/channel_player_data.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

class ChannelPlayerImpl {
  bool replaceFile = false;
  String diskSerial = '';
  String channel = '';
  String channelPath = DCMGlobal.settingPath;
  String publishPath = DCMGlobal.ftpSettingPath;
  String ftpTime = '';
  int ftpPeriod = 7;
  DateTime? startDate;

  ChannelPlayerImpl() {
    loadPathSetting();
  }

  bool saveChannelList(List<ChannelPlayer> lstChannel, {String? channelFile}) {
    String fileName = channelFile ?? path.join(channelPath, 'ChannelList.xml');
    XmlFilePro file = XmlFilePro('ChannelList');
    XmlItem? root = file.root();
    if (root == null) return false;

    for (var channelPlayer in lstChannel) {
      XmlItem? pXISibling = root.addItem('PlayerItem');
      if (pXISibling != null) {
        pXISibling.addItem('m_strDiskSerial', channelPlayer.diskSerial);
        pXISibling.addItem('m_strUniqueName', channelPlayer.uniqueName);
        pXISibling.addItem('m_strPlayerName', channelPlayer.playerName);
        pXISibling.addItem('m_uiPlayerID', channelPlayer.playerID);
        pXISibling.addItem('m_uiOutput', channelPlayer.outputs);

        for (var pData in channelPlayer.lstChannelPlayer) {
          XmlItem? pItem = pXISibling.addItem('ChannelItem');
          if (pItem != null) {
            pData.writeToXML(pItem);
          }
        }
      }
    }

    file.setSignature('Channel Player List');
    return file.save(fileName);
  }

  bool loadChannelList(List<ChannelPlayer> lstChannel, {String? channelFile}) {
    String fileName = channelFile ?? path.join(channelPath, 'ChannelList.xml');
    lstChannel.clear();
    if (!File(fileName).existsSync()) {
      return false;
    }

    XmlFilePro file = XmlFilePro('ChannelList');
    if (!file.open(fileName, XfOpen.read)) {
      return false;
    }
    if (!file.loadEx()) {
      return false;
    }

    XmlItem? pXISibling = file.getItem('PlayerItem');
    while (pXISibling != null) {
      ChannelPlayer channelPlayer = ChannelPlayer();
      channelPlayer.diskSerial = pXISibling.getItemValue('m_strDiskSerial');
      channelPlayer.uniqueName = pXISibling.getItemValue('m_strUniqueName');
      channelPlayer.playerName = pXISibling.getItemValue('m_strPlayerName');
      channelPlayer.playerID = pXISibling.getItemValueI('m_uiPlayerID');
      channelPlayer.outputs = pXISibling.getItemValueI('m_uiOutput');

      XmlItem? pChannelItem = pXISibling.getItem('ChannelItem');
      while (pChannelItem != null) {
        ChannelPlayerData pData = ChannelPlayerData();
        pData.getFromXML(pChannelItem);
        channelPlayer.lstChannelPlayer.add(pData);
        pChannelItem = pChannelItem.getSibling();
      }
      lstChannel.add(channelPlayer);
      pXISibling = pXISibling.getSibling();
    }

    return lstChannel.isNotEmpty;
  }

  bool resetAll(List<ChannelPlayer> lstChannel) {
    lstChannel.clear();
    return saveChannelList(lstChannel);
  }

  bool serialize(
      List<ChannelPlayer> lstChannel, String fileName, bool storing) {
    const String signature =
        'DCM FTP Manager Version 1.00 - Player Information for FTP';

    if (storing) {
      XmlFilePro playerReg = XmlFilePro('PlayerFTPInformation');
      playerReg.setDataNode(null, 'm_strChannel', channel);
      playerReg.setDataNode(null, 'm_strDiskSerial', diskSerial);
      playerReg.setDataNode(null, 'm_nFtpPeriod', ftpPeriod);
      playerReg.setDataNode(null, 'm_dtStartDate', startDate);
      playerReg.setDataNode(null, 'm_strFtpTime', ftpTime);
      playerReg.setDataNode(null, 'm_bReplaceFile', replaceFile);

      for (var player in lstChannel) {
        String uniqueName = player.uniqueName.isNotEmpty
            ? player.uniqueName
            : player.diskSerial;
        if (diskSerial.toLowerCase() == uniqueName.toLowerCase()) {
          playerReg.setDataNode(null, 'm_uiOutput', player.outputs);
          for (var pData in player.lstChannelPlayer) {
            XmlItem? pItem = playerReg.addDataNode('ChannelItem', null);
            if (pItem != null) {
              pData.writeToXML(pItem);
            }
          }
          break;
        }
      }
      playerReg.setSignature(signature);
      return playerReg.save(fileName);
    }

    XmlFilePro file = XmlFilePro('PlayerRegisterInformation');
    if (!file.open(fileName, XfOpen.read)) {
      return false;
    }
    if (!file.loadEx()) {
      return false;
    }

    if (file.getSignature() != signature) {
      return false;
    }

    channel = file.getItemValue('m_strChannel');
    diskSerial = file.getItemValue('m_strDiskSerial');
    ftpPeriod = file.getItemValueI('m_nFtpPeriod');
    startDate = file.getItemValueD('m_dtStartDate');
    ftpTime = file.getItemValue('m_strFtpTime');
    replaceFile = file.getItemValueB('m_bReplaceFile');

    for (var channelPlayer in lstChannel) {
      if (diskSerial.toLowerCase() == channelPlayer.diskSerial.toLowerCase()) {
        channelPlayer.outputs = file.getItemValueI('m_uiOutput');
        XmlItem? pXISibling = file.getItem('ChannelItem');
        while (pXISibling != null) {
          ChannelPlayerData pData = ChannelPlayerData();
          pData.getFromXML(pXISibling);
          channelPlayer.lstChannelPlayer.add(pData);
          pXISibling = pXISibling.getSibling();
        }
        break;
      }
    }
    return true;
  }

  bool deleteChannelPlayer(List<ChannelPlayer> lstChannel, String diskSerial,
      [String? uniqueName, int output = 0]) {
    for (var channelPlayer in lstChannel) {
      if (uniqueName == null || uniqueName.isEmpty) {
        if (channelPlayer.diskSerial.toLowerCase() ==
            diskSerial.toLowerCase()) {
          channelPlayer.deleteChannelPlayer(output);
          return true;
        }
      } else if (channelPlayer.uniqueName.toLowerCase() ==
          uniqueName.toLowerCase()) {
        channelPlayer.deleteChannelPlayer(output);
        return true;
      }
    }
    return false;
  }

  void addChannelPlayer(List<ChannelPlayer> lstChannel, String diskSerial,
      String playerName, String location, String channel,
      [int output = 0]) {
    bool existed = false;
    for (var channelPlayer in lstChannel) {
      if (channelPlayer.diskSerial.toLowerCase() == diskSerial.toLowerCase()) {
        channelPlayer.addChannelPlayer(
            diskSerial, playerName, location, channel, output);
        existed = true;
        break;
      }
    }
    if (!existed) {
      ChannelPlayer player = ChannelPlayer();
      player.diskSerial = diskSerial;
      player.playerName = playerName;
      player.addChannelPlayer(
          diskSerial, playerName, location, channel, output);
      lstChannel.add(player);
    }
  }

  void addChannelPlayerWithUniqueName(
      List<ChannelPlayer> lstChannel,
      String diskSerial,
      String uniqueName,
      String playerName,
      String location,
      String channel,
      [int output = 0]) {
    bool existed = false;
    for (var channelPlayer in lstChannel) {
      if (uniqueName.isEmpty) {
        if (channelPlayer.diskSerial.toLowerCase() ==
            diskSerial.toLowerCase()) {
          channelPlayer.uniqueName = uniqueName;
          channelPlayer.addChannelPlayer(
              diskSerial, playerName, location, channel, output);
          existed = true;
          break;
        }
      } else if (channelPlayer.uniqueName.toLowerCase() ==
          uniqueName.toLowerCase()) {
        channelPlayer.diskSerial = diskSerial;
        channelPlayer.addChannelPlayer(
            diskSerial, playerName, location, channel, output);
        existed = true;
        break;
      }
    }
    if (!existed) {
      ChannelPlayer player = ChannelPlayer();
      player.diskSerial = diskSerial;
      player.uniqueName = uniqueName;
      player.playerName = playerName;
      player.addChannelPlayer(
          diskSerial, playerName, location, channel, output);
      lstChannel.add(player);
    }
  }

  void setOutputs(List<ChannelPlayer> lstChannel, String diskSerial,
      [String? uniqueName, int outputs = 1]) {
    for (var channelPlayer in lstChannel) {
      if (uniqueName == null || uniqueName.isEmpty) {
        if (channelPlayer.diskSerial.toLowerCase() ==
            diskSerial.toLowerCase()) {
          channelPlayer.outputs = outputs;
          return;
        }
      } else if (channelPlayer.uniqueName.toLowerCase() ==
          uniqueName.toLowerCase()) {
        channelPlayer.outputs = outputs;
        return;
      }
    }
  }

  bool getChannelListForPlayer(
      List<ChannelPlayer> lstAllChannel,
      String diskSerial,
      DateTime dtFrom,
      DateTime dtTo,
      List<ChannelPlayerData> lstChannel) {
    ChannelPlayer? player;
    for (var entry in lstAllChannel) {
      if (entry.diskSerial.toLowerCase() == diskSerial.toLowerCase()) {
        player = entry;
        break;
      }
    }

    if (player == null) {
      return false;
    }

    DateTime dtDay = dtFrom;
    ChannelPlayerData? first;
    ChannelPlayerData? current;
    DateTime endDay = dtTo.add(const Duration(days: 1));

    while (!dtDay.isAfter(endDay)) {
      for (var item in player.lstChannelPlayer) {
        if (item.isEffective(dtFrom)) {
          current = item;
          break;
        }
      }
      if (first == null && current != null) {
        first = current;
      } else if (current != null && current != first) {
        var copy = ChannelPlayerData.copy(first!);
        copy.startDate = first.startDate;
        copy.endDate = dtDay.subtract(const Duration(days: 1));
        lstChannel.add(copy);
        first = current;
      }
      dtDay = dtDay.add(const Duration(days: 1));
    }

    return lstChannel.isNotEmpty;
  }

  bool getPlayerListOfChannel(List<ChannelPlayer> lstChannel, String channel,
      DateTime dtDate, List<ChannelPlayer> lstPlayer) {
    bool found = false;
    for (var player in lstChannel) {
      for (var item in player.lstChannelPlayer) {
        if (item.channelName.toLowerCase() == channel.toLowerCase() &&
            (item.endDate == null || !dtDate.isAfter(item.endDate!))) {
          lstPlayer.add(player);
          found = true;
          break;
        }
      }
    }
    return found;
  }

  void loadPathSetting() {
    channelPath = DCMGlobal.settingPath;
    publishPath = DCMGlobal.ftpSettingPath;
    ftpPeriod = 7;
  }
}
