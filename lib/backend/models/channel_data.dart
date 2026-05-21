class ChannelData {
  int id = 0;
  String channelName = '';
  String channelDesc = '';

  ChannelData();

  ChannelData.copy(ChannelData other) {
    id = other.id;
    channelName = other.channelName;
    channelDesc = other.channelDesc;
  }
}
