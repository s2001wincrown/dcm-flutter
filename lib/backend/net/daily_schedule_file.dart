import 'package:xml/xml.dart';
import 'package:intl/intl.dart';

// ============================================================================
// 2. Core Logic Classes (对应 C++ 中的 Implementation 类)
// ============================================================================

/// 对应 CDailyScheduleFile
/// 负责解析和生成 DailySchedule XML
class DailyScheduleFile {
  String rootTagName;
  String? defaultEvent;
  Map<int, String> mapEventDefa = {};
  XmlDocument? _doc;

  DailyScheduleFile({this.rootTagName = 'Playlist'});

  /// 加载 XML 字符串
  bool loadXml(String xmlContent) {
    try {
      _doc = XmlDocument.parse(xmlContent);
      var root = _doc?.rootElement;
      if (root != null) {
        defaultEvent = root.getElement('Default')?.innerText ?? '';
        _getOutputsDefaEvent();
        return true;
      }
    } catch (e) {
      print("Error parsing XML: $e");
    }
    return false;
  }

  /// 模拟保存到本地路径 (实际需配合 path_provider 和 file_io)
  Future<bool> saveDailySchedule(String directoryPath) async {
    // In real Flutter app:
    // final file = File('$directoryPath/DailySchedule/DailySchedule.xml');
    // await file.writeAsString(_doc?.toXmlString() ?? '');
    return true;
  }

  void _getOutputsDefaEvent() {
    mapEventDefa.clear();
    var outputs = _doc?.findAllElements('Output');
    outputs?.forEach((item) {
      var idStr = item.getElement('ID')?.innerText;
      var defa = item.getElement('Default')?.innerText;
      if (idStr != null && defa != null && defa.isNotEmpty) {
        int? id = int.tryParse(idStr);
        if (id != null) {
          mapEventDefa[id] = defa;
        }
      }
    });
  }

  /// 获取指定日期的频道列表
  List<String> getChannels(DateTime date) {
    List<String> channels = [];
    String strDate = DateFormat('dd/MM/yyyy').format(date);

    var outputs = _doc?.findAllElements('Output');
    outputs?.forEach((output) {
      var dayItem = _getDayItem(output, strDate);
      if (dayItem != null) {
        var channel = dayItem.getElement('Channel')?.innerText;
        if (channel != null) {
          channels.add(channel);
        }
      }
    });
    return channels;
  }

  XmlElement? _getDayItem(XmlElement output, String dateStr) {
    var dayItems = output.findElements('DayItem');
    for (var day in dayItems) {
      var dateVal = day.getElement('m_nDay')?.innerText;
      if (dateVal != null && dateVal.toLowerCase() == dateStr.toLowerCase()) {
        return day;
      }
    }
    return null;
  }

  /// 添加调度信息
  bool addSchedule(DateTime date, String channel, int outputId) {
    // Logic to find or create Output and DayItem nodes would go here
    // Simplified for brevity
    return true;
  }
}
