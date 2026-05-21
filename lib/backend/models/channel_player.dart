import 'package:intl/intl.dart';

import 'package:dcm/backend/models/channel_player_data.dart';

class ChannelPlayer {
  int playerID = -1;
  List<ChannelPlayerData> lstChannelPlayer = [];
  String playerName = '';
  String diskSerial = '';
  String uniqueName = '';
  int outputs = 1;

  ChannelPlayer();

  ChannelPlayer.copy(ChannelPlayer other) {
    playerID = other.playerID;
    playerName = other.playerName;
    diskSerial = other.diskSerial;
    uniqueName = other.uniqueName;
    outputs = other.outputs;
    lstChannelPlayer = other.lstChannelPlayer
        .map((item) => ChannelPlayerData.copy(item))
        .toList();
  }

  bool isPlayer(String diskSerial, [String? uniqueName]) {
    if (uniqueName == null || uniqueName.isEmpty) {
      return diskSerial.toLowerCase() == this.diskSerial.toLowerCase();
    }
    return uniqueName.toLowerCase() == this.uniqueName.toLowerCase();
  }

  void addChannelPlayer(
      String diskSerial, String playerName, String location, String channel,
      [int output = 0]) {
    DateTime now = DateTime.now();
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    bool existed = false;

    for (var item in lstChannelPlayer) {
      if (item.output == output && item.endDate == null) {
        final startDate = item.startDate;
        if (startDate != null &&
            DateFormat('yyyyMMdd').format(startDate) ==
                DateFormat('yyyyMMdd').format(now)) {
          item.channelName = channel;
          existed = true;
        } else {
          if (item.channelName.toLowerCase() != channel.toLowerCase()) {
            item.endDate = endOfDay.subtract(const Duration(days: 1));
          } else {
            existed = true;
          }
        }
        break;
      }
    }

    if (!existed) {
      final newItem = ChannelPlayerData();
      newItem.startDate = DateTime(now.year, now.month, now.day);
      newItem.endDate = null;
      newItem.playerName = playerName;
      newItem.diskSerial = diskSerial;
      newItem.channelName = channel;
      newItem.output = output;
      lstChannelPlayer.add(newItem);
    }
  }

  void deleteChannelPlayer([int output = 0]) {
    DateTime now = DateTime.now();
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    for (var i = 0; i < lstChannelPlayer.length; i++) {
      var item = lstChannelPlayer[i];
      if (item.output == output && item.endDate == null) {
        final startDate = item.startDate;
        if (startDate != null &&
            DateFormat('yyyyMMdd').format(startDate) ==
                DateFormat('yyyyMMdd').format(now)) {
          lstChannelPlayer.removeAt(i);
        } else {
          item.endDate = endOfDay.subtract(const Duration(days: 1));
        }
        break;
      }
    }
  }
}
