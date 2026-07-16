import 'package:dcm/backend/net/daily_schedule_file.dart';
import 'package:dcm/backend/net/transfer_action_service.dart';

/// 对应 CDailyScheduleData
class DailyScheduleData {
  String channelName = '';
  String month = '';
  List<String> days = [];
  String todayEventOld = '';
  String todayEventNew = '';

  void copyMonthFile() {
    // Logic to copy local calendar files
  }

  Future<bool> getEventList(DailyScheduleFile dailySchedule) async {
    // Complex logic from C++ GetEventList
    // 1. Iterate days
    // 2. Query dailySchedule for events
    // 3. Update global static lists (TransferActionService.globalEventList)

    for (var dayStr in days) {
      // Parse dayStr to DateTime
      // Call dailySchedule methods
      // Add to global list
      TransferActionService.globalEventList.add("Event_$dayStr");
    }

    return true;
  }

  static void clearStaticLists() {
    TransferActionService.globalEventList.clear();
    TransferActionService.globalDcmFileList.clear();
    TransferActionService.globalContentList.clear();
  }
}

// ============================================================================
// 3. Usage Example
// ============================================================================

/*
void main() {
  // Initialize Service
  final transferService = TransferActionService();
  
  // Prepare Schedule Data
  final scheduleData = DailyScheduleData();
  scheduleData.month = "202310";
  scheduleData.days.add("25");
  scheduleData.days.add("26");
  transferService.scheduleDataList.add(scheduleData);
  
  // Run Logic
  transferService.downloadDailyScheduleHttp("http://api.example.com/playlist", "PLAYER_01", 7).then((success) {
    if (success) {
      print("Schedule downloaded successfully.");
      print("Events found: ${TransferActionService.globalEventList}");
    } else {
      print("Failed to download schedule.");
    }
  });
}
*/
