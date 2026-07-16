import 'package:dcm/backend/net/channel_player_manager.dart';
import 'package:dcm/backend/net/daily_schedule_data.dart';
import 'package:dcm/backend/net/daily_schedule_file.dart';

/// 对应 CFtpActionImpl 的核心调度逻辑
class TransferActionService {
  DailyScheduleFile dailySchedule = DailyScheduleFile();
  ChannelPlayerManager fileManager = ChannelPlayerManager();
  List<DailyScheduleData> scheduleDataList = [];

  // Static-like state moved to instance or singleton
  static List<String> globalEventList = [];
  static List<String> globalDcmFileList = [];
  static List<String> globalContentList = [];

  /// 对应 DownloadDailyScheduleHTTP
  Future<bool> downloadDailyScheduleHttp(
      String playlistUrl, String playerId, int period) async {
    // 1. HTTP Request (Use Dio/HttpClient in real app)
    // String result = await httpClient.get(playlistUrl);

    // Mocking result for demonstration
    String mockResult = """
    <Playlist>
      <Default>dcmplay</Default>
      <Output>
        <ID>1</ID>
        <Default>DefaultEvent1</Default>
        <DayItem>
          <m_nDay>25/10/2023</m_nDay>
          <Channel>ChannelA</Channel>
        </DayItem>
      </Output>
    </Playlist>
    """;

    if (dailySchedule.loadXml(mockResult)) {
      await dailySchedule.saveDailySchedule('/mock/path');

      // Process Schedule Data
      for (var data in scheduleDataList) {
        data.copyMonthFile(); // Local logic
        bool success = await data.getEventList(dailySchedule);
        if (!success) {
          print("Generate calendar file failure for ${data.month}");
          return false;
        }
      }
      return true;
    }
    return false;
  }

  /// 对应 GenFileListByDailyScheduleViaHTTP
  Future<bool> generateFileListViaHttp(String requestParams) async {
    // Construct URL
    // Fetch XML
    // Parse using fileManager.loadFromXml

    // Mocking
    String mockFileListXml = """
    <PublishFileInformation>
      <FileItem>
        <FilePath>/remote/video.mp4</FilePath>
        <FileTitle>video.mp4</FileTitle>
        <DestFile>video.mp4</DestFile>
        <FileSize>102400</FileSize>
        <ContentType>1</ContentType>
      </FileItem>
    </PublishFileInformation>
    """;

    return fileManager.loadFromXml(mockFileListXml);
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
