import 'package:dcm/backend/models/channel_data.dart';
import 'package:dcm/backend/models/channel_schedule_data.dart';
import 'package:dcm/backend/services/channel_file_impl.dart';
import 'package:dcm/backend/xml_settings/channel_schedule_file.dart';
import 'package:intl/intl.dart';

class ScheduleImpl {
  final ChannelFileImpl channelFile = ChannelFileImpl();
  final ChannelScheduleFile scheduleFile = ChannelScheduleFile();

  bool deleteChannel(String channelName) {
    return channelFile.deleteChannel(channelName);
  }

  bool isChannelExisted(String channelName) {
    return channelFile.isChannelExisted(channelName);
  }

  bool saveChannelList(List<ChannelData> lstChannel) {
    return channelFile.saveChannelList(lstChannel);
  }

  bool loadChannelList(List<ChannelData> lstChannel) {
    return channelFile.loadChannelList(lstChannel);
  }

  bool loadAllChannelSchedule(List<ChannelData> lstChannel, DateTime dtSchedule,
      List<ChannelScheduleData> lstSchedule) {
    final String scheduleMonth = DateFormat('yyyyMM').format(dtSchedule);
    return loadAllChannelScheduleByMonth(
        lstChannel, scheduleMonth, lstSchedule);
  }

  bool loadAllChannelScheduleByMonth(List<ChannelData> lstChannel,
      String scheduleMonth, List<ChannelScheduleData> lstSchedule) {
    lstSchedule.clear();

    if (!scheduleFile.loadMonthlySchedule(lstSchedule, month: scheduleMonth)) {
      return false;
    }

    if (lstChannel.isNotEmpty) {
      final channelNames = lstChannel
          .map((channel) => channel.channelName.toLowerCase())
          .toSet();
      lstSchedule.removeWhere((schedule) =>
          !channelNames.contains(schedule.channelName.toLowerCase()));
    }

    return lstSchedule.isNotEmpty;
  }
}
