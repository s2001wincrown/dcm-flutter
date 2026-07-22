import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/net/daily_schedule_data.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

// ============================================================================
// 2. Core Logic Classes (对应 C++ 中的 Implementation 类)
// ============================================================================

/// 对应 CDailyScheduleFile
/// 负责解析和生成 DailySchedule XML
class DailyScheduleFile extends XmlFile {
  String? _strEventDefa;
  final Map<int, String> _mapEventDefa = {};

  Map<int, String> get mapEventDefa => _mapEventDefa;

  DailyScheduleFile() : super('Playlist');

  @override
  bool loadXml(String szXML, [String? szRootItemName]) {
    if (super.loadXml(szXML, szRootItemName) && getItemCount() > 0) {
      _strEventDefa = root().getItemValue('Default');
      getOutputsDefaEvent();

      return true;
    }

    return false;
  }

  bool saveDailySchedule() {
    String strEventDirectory =
        path.join(DCMGlobal.ftpSettingPath, 'DailySchedule');
    FileUtils.makeSureDirectoryPathExists(strEventDirectory);
    strEventDirectory = path.join(strEventDirectory, 'DailySchedule.xml');

    return save(strEventDirectory);
  }

  bool loadDailySchedule() {
    String strEventDirectory = path.join(
        DCMGlobal.ftpSettingPath, 'DailySchedule', 'DailySchedule.xml');
    if (load(strEventDirectory)) {
      _strEventDefa = root().getItemValue('Default');
      getOutputsDefaEvent();

      return true;
    }

    return false;
  }

  List<String> getChannels(DateTime dtDate) {
    String strDate = DateFormat('dd/MM/yyyy').format(dtDate);

    List<String> arrChannel = [];
    XmlItem? pItem = getItem('Output');
    while (pItem != null) {
      XmlItem? pDayItem = getDayItem(pItem, strDate);
      if (pDayItem != null) {
        String strChannel = pDayItem.getItemValue('Channel');
        arrChannel.add(strChannel);
      }

      pItem = pItem.getSibling();
    }

    return arrChannel;
  }

  int getOutputs(List<String> arrOutputs) {
    int nCnt = 0;
    XmlItem? pItem = getItem('Output');
    while (pItem != null) {
      nCnt++;
      arrOutputs.add(pItem.getItemValue('ID'));

      pItem = pItem.getSibling();
    }
    if (nCnt == 0) nCnt = 1;

    return nCnt;
  }

  int getOutputCount() {
    int nCnt = 0;
    XmlItem? pItem = getItem('Output');
    while (pItem != null) {
      nCnt++;

      pItem = pItem.getSibling();
    }
    if (nCnt == 0) {
      nCnt = 1;
    }

    return nCnt;
  }

  int getOutputsDefaEvent() {
    _mapEventDefa.clear();
    XmlItem? pItem = getItem('Output');
    while (pItem != null) {
      int nID = pItem.getItemValueI('ID');
      String strDefa = pItem.getItemValue('Default');
      if (strDefa.isNotEmpty && !_mapEventDefa.containsKey(nID)) {
        _mapEventDefa[nID] = strDefa;
      }

      pItem = pItem.getSibling();
    }

    return _mapEventDefa.length;
  }

  String getEvent(XmlItem pDayItem) {
    XmlItem? xiEvent = pDayItem.getItem('m_strEvent');
    if (xiEvent != null) {
      return xiEvent.getValue();
    }

    return '';
  }

  String getInfo(XmlItem pDayItem) {
    XmlItem? xiEvent = pDayItem.getItem('m_strInfo');
    if (xiEvent != null) {
      return xiEvent.getValue();
    }

    return '';
  }

  List<Pair<String, String>> getEvents(XmlItem pDayItem) {
    List<Pair<String, String>> aItems = [];
    XmlItem? xiEventArray = pDayItem.getItem('m_arrEvent');
    if (xiEventArray != null) {
      XmlItem? pEvent = xiEventArray.getItem('EventItem');
      while (pEvent != null) {
        String? strName;
        String? strValue;
        XmlItem? pName = pEvent.getItem('Company');
        if (pName != null) {
          strName = pName.getValue();
        }
        XmlItem? pValue = pEvent.getItem('Event');
        if (pValue != null) {
          strValue = pValue.getValue();
        }

        if (strName != null && strValue != null) {
          aItems.add(Pair<String, String>(strName, strValue));
        }

        pEvent = pEvent.getSibling();
      }
    }

    return aItems;
  }

  int getPMethod(XmlItem pDayItem) {
    XmlItem? xiPlayMeth = pDayItem.getItem('m_nPlayMeth');
    if (xiPlayMeth != null) {
      return xiPlayMeth.getValueI();
    }

    return 0;
  }

  void setEvent(XmlItem pDayItem, String strEvent) {
    pDayItem.setItemValue('m_strEvent', strEvent, XiType.element);
  }

  void setInfo(XmlItem pDayItem, String strInfo) {
    pDayItem.setItemValue('m_strInfo', strInfo, XiType.element);
  }

  void setEvents(XmlItem pDayItem, List<Pair<String, String>> aItems) {
    XmlItem? xiEventArray = pDayItem.getItem('m_arrEvent');
    if (xiEventArray != null) {
      xiEventArray.deleteAllItems();
      for (int i = 0; i < aItems.length; i++) {
        XmlItem? pEvent = xiEventArray.addItem('EventItem');
        if (pEvent != null) {
          pEvent.setItemValue('Company', aItems[i].key);
          pEvent.setItemValue('Event', aItems[i].value);
        }
      }
    }
  }

  void setPMethod(XmlItem pDayItem, int nPMethod) {
    pDayItem.setItemValue('m_mPlayMeth', nPMethod, XiType.element);
  }

  XmlItem? getDayItemByOutput(
      {DateTime? dtDate, String? strDate, int nOutput = 0}) {
    if (dtDate != null) {
      String strDate =
          DateFormat('dd/MM/yyyy').format(dtDate); //dtDate.Format('%d/%m/%Y');

      return getDayItemByOutput(strDate: strDate, nOutput: nOutput);
    } else {
      XmlItem? pDayItem;
      XmlItem? pItem;
      XmlItem? pxiID = findItem('ID', nOutput);
      if (pxiID != null) {
        pItem = pxiID.getParent();
      }

      pItem ??= root();

      pDayItem = pItem.getItem('DayItem');
      while (pDayItem != null) {
        XmlItem? xiDay = pDayItem.getItem('m_nDay');
        if (xiDay != null) {
          String strDateValue = xiDay.getValue();
          if (strDateValue.equalsIgnoreCase(strDate)) {
            break;
          }
        }

        pDayItem = pDayItem.getSibling();
      }

      return pDayItem;
    }
  }

  XmlItem? getDayItemD(XmlItem pOutput, DateTime dtDate) {
    String strDate = DateFormat('dd/MM/yyyy').format(dtDate);

    return getDayItem(pOutput, strDate, true);
  }

  XmlItem? getDayItem(XmlItem pOutput, String strDate, [bool bCreate = false]) {
    XmlItem? pDayItem = pOutput.getItem('DayItem');
    while (pDayItem != null) {
      XmlItem? xiDay = pDayItem.getItem('m_nDay');
      if (xiDay != null) {
        String strDateValue = xiDay.getValue();
        if (strDateValue.equalsIgnoreCase(strDate)) {
          break;
        }
      }

      pDayItem = pDayItem.getSibling();
    }

    if (pDayItem == null && bCreate) {
      pDayItem = pOutput.addItem('DayItem');
      if (pDayItem != null) {
        pDayItem.setItemValue('m_nDay', strDate, XiType.element);
      }
    }

    return pDayItem;
  }

  XmlItem? getOutputItem([int nOutput = 0]) {
    XmlItem? pItem;
    XmlItem? pxiID = findItem('ID', nOutput);
    if (pxiID != null) {
      pItem = pxiID.getParent();
    } else {
      pItem = addItem('Output');
      if (pItem != null) {
        pItem.addItem('ID', nOutput);
      }
    }

    return pItem;
  }

  List<String> getEventList() {
    List<String> arrEvent = [];
    if (_strEventDefa != null && _strEventDefa!.isNotEmpty) {
      DailyScheduleData.addToEventList('dcmplay');
    }

    for (var it in _mapEventDefa.values) {
      DailyScheduleData.addToEventList(it);
    }

    XmlItem? pItem = getItem('Output');
    while (pItem != null) {
      XmlItem? pDayItem = pItem.getItem('DayItem');
      while (pDayItem != null) {
        String strEvent = '';
        strEvent = getEvent(pDayItem);
        List<Pair<String, String>> arrEvents = getEvents(pDayItem);
        if (arrEvents.isNotEmpty) {
          DailyScheduleData.addToEventLists(arrEvents);
        } else {
          DailyScheduleData.addToEventList(strEvent);
        }

        pDayItem = pDayItem.getSibling();
      }

      pItem = pItem.getSibling();
    }

    return arrEvent;
  }

  bool getEventByOutput(
      String strEvent, DateTime dtDate, int nOutput /* = 0*/) {
    //XmlItem? pItem = getItem('Output');
    XmlItem? pItem;
    XmlItem? pxiID = findItem('ID', nOutput);
    if (pxiID != null) {
      pItem = pxiID.getParent();
    }

    pItem ??= root();

    XmlItem? pDayItem = pItem.getItem('DayItem');
    while (pDayItem != null) {
      XmlItem? xiDay = pDayItem.getItem('m_nDay');
      if (xiDay != null) {
        String strDate = xiDay.getValue();
        if (strDate.equalsIgnoreCase(DateFormat('dd/MM/yyyy').format(dtDate))) {
          XmlItem? xiEvent = pDayItem.getItem('m_strEvent');
          if (xiEvent != null) {
            strEvent = xiEvent.getValue();
          }

          return true;
        }
      }

      pDayItem = pDayItem.getSibling();
    }

    return false;
  }

  bool addSchedule(DateTime dtDate, String strChannel, [int nOutput = 0]) {
    XmlItem? pItem = getOutputItem(nOutput);
    if (pItem != null) {
      XmlItem? pDayItem = getDayItemD(pItem, dtDate);
      if (pDayItem != null) {
        pDayItem.setItemValue('Channel', strChannel);

        return true;
      }
    }

    return false;
  }

  bool hasDCMPlay() {
    if (_strEventDefa != null) return (_strEventDefa!.isNotEmpty);

    return false;
  }
}
