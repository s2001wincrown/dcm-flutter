import 'dart:io';
import 'dart:math';

import 'package:dcm/backend/models/channel_schedule_data.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';
import 'package:path/path.dart' as path;

class ChannelScheduleFile extends XmlFile {
  static const String _scheduleRoot = 'MonthlySchedule';
  static const String _scheduleChannelItem = 'ChannelItem';
  static const String _scheduleDayItem = 'DayItem';
  static const String _scheduleDay = 'm_nDay';
  static const String _schedulePlayMeth = 'm_nPlayMeth';
  static const String _scheduleEvent = 'm_strEvent';
  static const String _scheduleArrEvent = 'm_arrEvent';
  static const String _scheduleInfo = 'm_strInfo';
  static const String _scheduleChannel = 'Channel';
  static const String _scheduleMonth = 'Month';
  static const String _scheduleDesc = 'Description';
  static const String _scheduleChannelID = 'ChannelID';
  static const String _scheduleID = 'ID';

  int _nextUniqueId = 1;

  String monthlyScheduleFile(String month) =>
      path.join(AppGlobal.calendarPath, '$month.xml');

  int getChannelScheduleCount() {
    return getItemCount();
  }

  String channelMonthScheduleFile(String channelName, String month) {
    return path.join(AppGlobal.monthPath, '$channelName$month.xml');
  }

  ChannelScheduleFile() : super(_scheduleRoot);

  @override
  bool load(String szFilePath,
      [String? szRootItemName, bool bDecrypt = false]) {
    bool bRes =
        super.load(szFilePath, szRootItemName ?? _scheduleRoot, bDecrypt);
    if (bRes) {
      _nextUniqueId = getItemValueI(XmlFilePro.xfDCMNEXTUNIQUEID);
      if (_nextUniqueId <= 0) _nextUniqueId = 1;
    }

    return bRes;
  }

  bool loadFile(
      {String? filePath, DateTime? dtSchedule, XfOpen mode = XfOpen.read}) {
    if ((filePath == null || filePath.isEmpty) && dtSchedule == null) {
      return false;
    }

    if ((filePath == null || filePath.isEmpty) && dtSchedule != null) {
      filePath = path.join(AppGlobal.calendarPath,
          '${DateFormat('yyyyMMdd').format(dtSchedule)}.xml');
    }

    final File fileDisk = File(filePath!);
    final bool existed = fileDisk.existsSync();
    if (existed && !load(filePath, _scheduleRoot)) {
      return false;
    }

    return true;
  }

  bool loadScheduleFile(String filePath, [XfOpen nMode = XfOpen.read]) {
    return loadFile(filePath: filePath, mode: nMode);
  }

  bool saveSchedule({String? month, String? description, String? filePath}) {
    final String scheduleMonth =
        month ?? DateFormat('yyyyMM').format(DateTime.now());
    final String fullPath = filePath ?? monthlyScheduleFile(scheduleMonth);

    setNextUniqueID(_nextUniqueId);
    return save(fullPath);
  }

  bool loadMonthlySchedule(List<ChannelScheduleData> lstSchedule,
      {String? month, String? filePath}) {
    final String scheduleMonth =
        month ?? DateFormat('yyyyMM').format(DateTime.now());
    final String fullPath = filePath ?? monthlyScheduleFile(scheduleMonth);

    lstSchedule.clear();
    final File fileDisk = File(fullPath);
    if (!fileDisk.existsSync()) {
      final Directory monthDir = Directory(AppGlobal.monthPath);
      if (!monthDir.existsSync()) {
        return false;
      }

      final fallbackFiles = monthDir
          .listSync()
          .whereType<File>()
          .where((f) => path.basename(f.path).endsWith('$scheduleMonth.xml'));

      for (final fallbackFile in fallbackFiles) {
        final XmlFilePro fallback = XmlFilePro(_scheduleRoot);
        if (!fallback.open(fallbackFile.path, XfOpen.read)) {
          continue;
        }
        if (!fallback.loadEx()) {
          continue;
        }

        _parseChannelScheduleFile(fallback, lstSchedule);
      }

      return lstSchedule.isNotEmpty;
    }

    final XmlFilePro file = XmlFilePro(_scheduleRoot);
    if (!file.open(fullPath, XfOpen.read)) {
      return false;
    }
    if (!file.loadEx()) {
      return false;
    }

    return _parseChannelScheduleFile(file, lstSchedule);
  }

  bool saveMonthlySchedule(List<ChannelScheduleData> lstSchedule,
      {String? month, String? description, String? filePath}) {
    final String scheduleMonth =
        month ?? DateFormat('yyyyMM').format(DateTime.now());
    final String fullPath = filePath ?? monthlyScheduleFile(scheduleMonth);

    final XmlFilePro file = XmlFilePro(_scheduleRoot);
    root().addItem(_scheduleMonth, scheduleMonth);
    if (description != null) {
      root().addItem(_scheduleDesc, description);
    }

    for (final channelSchedule in lstSchedule) {
      final XmlItem? xiChannel = root().addItem(_scheduleChannelItem);
      if (xiChannel == null) continue;

      xiChannel.addItem(_scheduleChannel, channelSchedule.channelName);
      for (final dayInfo in channelSchedule.lstDayInfo) {
        final XmlItem? xiDay = xiChannel.addItem(_scheduleDayItem);
        if (xiDay == null) continue;

        xiDay.addItem(_scheduleDay, dayInfo.day);
        xiDay.addItem(_schedulePlayMeth, dayInfo.playMeth);
        xiDay.addItem(_scheduleEvent, dayInfo.event);

        final XmlItem? xiArrEvent = xiDay.addItem(_scheduleArrEvent);
        if (xiArrEvent != null) {
          for (final eventEntry in dayInfo.arrEvent) {
            final XmlItem? xiEvent = xiArrEvent.addItem('EventItem');
            if (xiEvent != null) {
              xiEvent.addItem('Company', eventEntry.key);
              xiEvent.addItem('Event', eventEntry.value);
            }
          }
        }

        xiDay.addItem(_scheduleInfo, dayInfo.info);
        xiDay.addItem('m_nApprovalLevel', dayInfo.approvalLevel);
        xiDay.addItem('m_nApprovalStatus', dayInfo.approvalStatus);
        xiDay.addItem('m_strUserCode', dayInfo.userCode);
        xiDay.addItem('m_strGroupCode', dayInfo.groupCode);
        xiDay.addItem('m_dtmodified', dayInfo.modified);
        xiDay.addItem('m_dtCreated', dayInfo.created);
      }
    }

    return file.save(fullPath);
  }

  bool clear() {
    root().reset();
    root().setName(_scheduleRoot);
    _nextUniqueId = 1;
    return true;
  }

  bool copy(ChannelScheduleFile source) {
    clear();

    final Iterator<XmlItem> pos = source.root().getFirstItemPos();
    while (pos.moveNext()) {
      final XmlItem child = pos.current;
      final XmlItem copy = _duplicateItem(child, root());
      root().addItemObj(copy);
    }

    _nextUniqueId = source._nextUniqueId;
    return true;
  }

  XmlItem _duplicateItem(XmlItem source, XmlItem? parent) {
    final XmlItem copy =
        XmlItem(parent, source.getName(), source.getValue(), source.getType());

    final Iterator<XmlItem> pos = source.getFirstItemPos();
    while (pos.moveNext()) {
      final XmlItem child = pos.current;
      final XmlItem childCopy = _duplicateItem(child, copy);
      copy.addItemObj(childCopy);
    }

    return copy;
  }

  bool exportChannel(String channel, {String? filePath}) {
    return true;
  }

  int getNextUniqueID() {
    return _nextUniqueId;
  }

  bool setNextUniqueID(int nextID) {
    if (nextID < _nextUniqueId) return false;

    final XmlItem? pItem = setItemValue(XmlFilePro.xfDCMNEXTUNIQUEID, nextID);
    if (pItem == null) return false;

    _nextUniqueId = nextID;
    return true;
  }

  String getScheduleMonth() {
    return getItemValue(_scheduleMonth);
  }

  String getScheduleDesc() {
    return getItemValue(_scheduleDesc);
  }

  int getFileVersion() {
    return getItemValueI(XmlFilePro.xfDCMFILEVERSION);
  }

  bool setScheduleMonth(String value) {
    return setItemValue(_scheduleMonth, value) != null;
  }

  bool setScheduleDesc(String value) {
    return setItemValue(_scheduleDesc, value) != null;
  }

  bool setFileVersion(int version) {
    return setItemValue(XmlFilePro.xfDCMFILEVERSION, version) != null;
  }

  XmlItem? newChannelSchedule(int nDay, [XmlItem? parent, int? id]) {
    final XmlItem pXIParent = parent ?? root();

    final XmlItem pXINew = newItem(_scheduleDayItem);
    pXIParent.addItemObj(pXINew);

    final int assignedId = id == null || id <= 0 ? _nextUniqueId++ : id;
    if (id != null && id > 0) {
      _nextUniqueId = max(_nextUniqueId, id + 1);
    }

    setChannelScheduleDay(pXINew, nDay);
    setChannelScheduleID(pXINew, assignedId);
    return pXINew;
  }

  XmlItem? newChannelItem(String title, [XmlItem? parent, int? id]) {
    final XmlItem pXIParent = parent ?? root();

    final XmlItem pXINew = newItem(_scheduleChannelItem);
    pXIParent.addItemObj(pXINew);

    final int assignedId = id == null || id <= 0 ? _nextUniqueId++ : id;
    if (id != null && id > 0) {
      _nextUniqueId = max(_nextUniqueId, id + 1);
    }

    setChannelScheduleChannel(pXINew, title);
    setChannelScheduleID(pXINew, assignedId);
    return pXINew;
  }

  XmlItem? getChannelScheduleItem(String? channelName, {bool bNew = true}) {
    if (channelName == null || channelName.isEmpty) {
      final XmlItem? first = getFirstChannelSchedule();
      if (first != null) {
        return first;
      }
      return bNew ? newChannelItem(channelName ?? '') : null;
    }

    final XmlItem? pXI = root().findItem(_scheduleChannel, channelName, true);
    if (pXI == null) {
      return bNew ? newChannelItem(channelName) : null;
    }
    return pXI.getParent();
  }

  XmlItem? getChannelDayItem(int nDay, XmlItem hParent, {bool bNew = true}) {
    final XmlItem? found = findChannelItemByDay(nDay, hParent);
    if (found != null) {
      return found;
    }

    return bNew ? newChannelSchedule(nDay, hParent) : null;
  }

  XmlItem? findChannelItem(DateTime date, XmlItem? hChannelSchedule) {
    return findChannelItemByDay(date.day, hChannelSchedule);
  }

  XmlItem? findChannelItemByDay(int nDay, XmlItem? hChannelSchedule) {
    if (hChannelSchedule == null) {
      return null;
    }

    final XmlItem? first = getFirstChannelSchedule(hChannelSchedule);
    if (first == null) {
      return null;
    }

    final XmlItem? pXI = first.findItem(_scheduleDay, nDay, true);
    return pXI?.getParent();
  }

  XmlItem? getFirstChannelSchedule([XmlItem? parent]) {
    final XmlItem pXIParent = parent ?? root();

    return parent == null
        ? pXIParent.getItem(_scheduleChannelItem)
        : pXIParent.getItem(_scheduleDayItem);
  }

  XmlItem? getNextChannelSchedule(XmlItem hChannelSchedule) {
    return hChannelSchedule.getSibling();
  }

  bool deleteChannelScheduleAttributes(XmlItem hChannelSchedule) {
    final List<XmlItem> children = [];
    final Iterator<XmlItem> pos = hChannelSchedule.getFirstItemPos();
    while (pos.moveNext()) {
      children.add(pos.current);
    }

    for (final XmlItem child in children) {
      if (!child.nameIs(_scheduleDayItem)) {
        hChannelSchedule.deleteItem(pXI: child);
      }
    }

    return true;
  }

  bool deleteChannelDayItem(XmlItem hChannelSchedule) {
    XmlItem? dayItem = hChannelSchedule.getItem(_scheduleDayItem);
    while (dayItem != null) {
      final XmlItem? next = dayItem.getSibling();
      hChannelSchedule.deleteItem(pXI: dayItem);
      dayItem = next;
    }

    return true;
  }

  bool deleteChannelSchedule(XmlItem hChannelSchedule) {
    final XmlItem? parent = hChannelSchedule.getParent();
    if (parent == null) {
      return false;
    }

    return parent.deleteItem(pXI: hChannelSchedule);
  }

  int getChannelScheduleChannelID(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValueI(_scheduleChannelID);
  }

  String getChannelScheduleChannel(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValue(_scheduleChannel);
  }

  String getChannelScheduleEvent(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValue(_scheduleEvent);
  }

  String getChannelScheduleInfo(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValue(_scheduleInfo);
  }

  int getChannelScheduleDay(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValueI(_scheduleDay);
  }

  int getChannelSchedulePlayMeth(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValueI(_schedulePlayMeth);
  }

  int getChannelScheduleID(XmlItem hChannelSchedule) {
    return hChannelSchedule.getItemValueI(_scheduleID);
  }

  XmlItem? getChannelScheduleParent(XmlItem hChannelSchedule) {
    return hChannelSchedule.getParent();
  }

  bool setChannelScheduleChannelID(XmlItem hChannelSchedule, int value) {
    return hChannelSchedule.setItemValue(_scheduleChannelID, value) != null;
  }

  bool setChannelScheduleChannel(XmlItem hChannelSchedule, String value) {
    return hChannelSchedule.setItemValue(_scheduleChannel, value) != null;
  }

  bool setChannelScheduleEvent(XmlItem hChannelSchedule, String value) {
    return hChannelSchedule.setItemValue(_scheduleEvent, value) != null;
  }

  bool setChannelScheduleInfo(XmlItem hChannelSchedule, String value) {
    return hChannelSchedule.setItemValue(_scheduleInfo, value) != null;
  }

  bool setChannelScheduleDay(XmlItem hChannelSchedule, int value) {
    return hChannelSchedule.setItemValue(_scheduleDay, value) != null;
  }

  bool setChannelSchedulePlayMeth(XmlItem hChannelSchedule, int value) {
    return hChannelSchedule.setItemValue(_schedulePlayMeth, value) != null;
  }

  bool setChannelScheduleID(XmlItem hChannelSchedule, int value,
      [bool bVisible = true]) {
    final bool result =
        hChannelSchedule.setItemValue(_scheduleID, value) != null;
    if (result) {
      _nextUniqueId = max(_nextUniqueId, value + 1);
    }
    return result;
  }

  bool setChannelScheduleEvents(
      XmlItem hChannelSchedule, List<Pair<String, String>> arrEvents) {
    return setChannelScheduleArray(
        hChannelSchedule, _scheduleArrEvent, arrEvents);
  }

  List<Pair<String, String>> getChannelScheduleEvents(
      XmlItem hChannelSchedule) {
    return getChannelScheduleArray(hChannelSchedule, _scheduleArrEvent);
  }

  List<Pair<String, String>> getChannelScheduleArray(
      XmlItem hChannelSchedule, String tag) {
    final List<Pair<String, String>> items = [];
    final XmlItem? parent = hChannelSchedule.getItem(tag);
    if (parent == null) {
      return items;
    }

    XmlItem? eventItem = parent.getItem('EventItem');
    while (eventItem != null) {
      final Pair<String, String> key = Pair(
          eventItem.getItemValue('Company'), eventItem.getItemValue('Event'));
      items.add(key);
      eventItem = eventItem.getSibling();
    }

    return items;
  }

  bool setChannelScheduleArray(XmlItem hChannelSchedule, String tag,
      List<Pair<String, String>> arrEvents) {
    hChannelSchedule.deleteItem(szItemName: tag);

    final XmlItem? parent = hChannelSchedule.addItem(tag);
    if (parent == null) {
      return false;
    }

    for (final entry in arrEvents) {
      final XmlItem? eventItem = parent.addItem('EventItem');
      if (eventItem != null) {
        eventItem.addItem('Company', entry.key);
        eventItem.addItem('Event', entry.value);
      }
    }

    return true;
  }

  List<String> getArray(String tag) {
    final List<String> items = [];
    final XmlItem? pXI = getItem(tag);
    if (pXI == null) {
      return items;
    }

    int nCount = pXI.getItemCount();
    for (int nItem = 0; nItem < nCount; nItem++) {
      items.add(pXI.getItemValue('$tag$nItem'));
    }

    return items;
  }

  bool setArray(String tag, List<String> values) {
    deleteItem(itemName: tag);

    if (values.isEmpty) {
      return true;
    }

    final XmlItem? parent = addItem(tag);
    if (parent == null) {
      return false;
    }

    for (var index = 0; index < values.length; index++) {
      parent.addItem('$tag$index', values[index]);
    }

    return true;
  }

  bool _parseChannelScheduleFile(
      XmlFilePro file, List<ChannelScheduleData> lstSchedule) {
    XmlItem? xiChannel = file.getItem(_scheduleChannelItem);
    while (xiChannel != null) {
      final ChannelScheduleData schedule = ChannelScheduleData();
      schedule.channelName = xiChannel.getItemValue(_scheduleChannel);

      XmlItem? xiDay = xiChannel.getItem(_scheduleDayItem);
      while (xiDay != null) {
        final DayInfoData dayInfo = DayInfoData();
        dayInfo.getFromXML(xiDay);
        schedule.lstDayInfo.add(dayInfo);
        xiDay = xiDay.getSibling();
      }

      lstSchedule.add(schedule);
      xiChannel = xiChannel.getSibling();
    }

    return lstSchedule.isNotEmpty;
  }
}
