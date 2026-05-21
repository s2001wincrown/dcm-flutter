import 'package:dcm/backend/models/day_info_data.dart';

class ChannelScheduleData {
  String channelName = '';
  List<DayInfoData> lstDayInfo = [];

  ChannelScheduleData();

  ChannelScheduleData.copy(ChannelScheduleData other) {
    channelName = other.channelName;
    lstDayInfo =
        other.lstDayInfo.map((item) => DayInfoData.copy(item)).toList();
  }
}
