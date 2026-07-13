import 'dart:io';

import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/net/netdef.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

// 模拟常量定义
const int cSTATSWOFF = 0x0001;
const int cSTATLOGOFF = 0x0002;
const int cSTATRESTART = 0x0004;

const int cSTATSWOFFTIMER = 0x0010;
const int cSTATLOGOFFTIMER = 0x0020;
const int cSTATRESTARTTIMER = 0x0040;

// 模拟任务信息结构体
class TaskInfo {
  String strTask;
  DateTime dtValidity;

  TaskInfo(this.strTask, this.dtValidity);
}

// --------------------------------------------------------------------------
// CNetLogImpl 实现
// --------------------------------------------------------------------------
class NetLogImpl {
  // 静态变量
  static DateTime dtFileList = DateTime.now();
  static DateTime dtLastReSync = DateTime(0);
  static DateTime dtLastSync = DateTime(0);
  static DateTime dtCMDTime = DateTime.now().subtract(Duration(days: 1));
  static DateTime dtShutdown = DateTime(0);
  static bool bIsDirty = false;

  // 任务列表
  static List<TaskInfo> lstTaskInfo = [];

  // 锁 (Dart 是单线程，但在异步操作中需注意。这里使用简单的同步逻辑，实际生产环境可能需要 isolate 或 mutex)
  // Dart 中没有直接的 CriticalSection，通常通过 await 和 async/await 保证原子性，或者使用 package:synchronized

  static const int cTASKMAXVALIDITYDAYS = 7;

  // 移除所有任务信息
  static void removeAllTaskInfo() {
    lstTaskInfo.clear();
    bIsDirty = true;
  }

  // 加载 FTP 日志 (tasklog.xml)
  static Future<bool> loadFTPLog() async {
    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'tasklog.xml');
    XmlFile file = XmlFile('PlayerTasks');
    if (file.load(strFileName)) {
      XmlItem? pItem = file.getItem('TaskList');
      if (pItem != null) {
        XmlItem? pTask = pItem.getItem('TaskItem');
        while (pTask != null) {
          DateTime? dtValidity = pTask.getItemValueD(
              'dtValidity'); //.add(Duration(days: cTASKMAXVALIDITYDAYS));
          if (dtValidity != null) {
            dtValidity =
                dtValidity.add(const Duration(days: cTASKMAXVALIDITYDAYS));
            if (dtValidity.isAfter(DateTime.now())) {
              TaskInfo pInfo =
                  TaskInfo(pTask.getItemValue('strTask'), dtValidity);
              lstTaskInfo.add(pInfo);
            }
          }
          pTask = pTask.getSibling();
        }
      }
    }

    return true;
  }

  // 保存任务日志
  static Future<bool> saveTaskLog() async {
    if (!bIsDirty) {
      return true;
    }

    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'tasklog.xml');
    XmlFile file = XmlFile('PlayerTasks');

    // Save DCM Task information
    XmlItem? pXmlItem = file.addItem('TaskList');
    if (pXmlItem != null) {
      for (var task in lstTaskInfo) {
        XmlItem? xi = pXmlItem.addItem('TaskItem');
        if (xi != null) {
          xi.addItem('dtValidity', task.dtValidity);
          xi.addItem('strTask', task.strTask);
        }
      }

      if (file.save(strFileName)) {
        bIsDirty = false;
        return true;
      }
    }

    return false;
  }

  // 检查是否为新任务并保存
  static Future<bool> isNewTaskSave(String strTask) async {
    for (var it in lstTaskInfo) {
      if (it.strTask.equalsIgnoreCase(strTask)) {
        logW(
            '''Task '$strTask' has been done; Recieved Date: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(it.dtValidity)}'!''');

        return false;
      }
    }

    TaskInfo pInfo = TaskInfo(strTask, DateTime.now());
    lstTaskInfo.add(pInfo);
    bIsDirty = true;
    saveTaskLog();

    return true;
  }

  // 检查是否为新任务 (不立即保存，仅标记 dirty)
  static bool isNewTask(String strTask) {
    for (var it in lstTaskInfo) {
      if (it.strTask.equalsIgnoreCase(strTask)) {
        logW(
            '''Task: '$strTask' has been processed; Recieved Date: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(it.dtValidity)}'; ignore it!''');
        return false;
      }
    }

    TaskInfo pInfo = TaskInfo(strTask, DateTime.now());
    lstTaskInfo.add(pInfo);
    bIsDirty = true;

    return true;
  }

  // 从 MessageInfo 检查新任务
  static Future<bool> isNewTaskFromMessage(MessageInfo pInfo) async {
    return await isNewTaskSave(pInfo.task);
  }

  // 从命令指针检查新 CMD 任务 (模拟)
  static Future<bool> isNewCMDTask(List<int> cmdData, int offset) async {
    // 模拟指针移动和数据解析
    // 在实际 Dart 实现中，这通常是一个对象或 Map
    if (offset >= cmdData.length) return false;

    // 假设解析出一个 MessageInfo
    // 这里简化处理，实际需要根据二进制协议解析
    String taskName = "CMD_Task_${cmdData[offset]}";
    return await isNewTask(taskName);
  }

  // 重启动作
  static Future<bool> restartAction(int dwAction) async {
    logI(
        'CNetLogImpl::RestartAction - Try to restart or power off system ... Action: $dwAction');

    bool success = false;

    // Dart 无法直接执行系统关机/重启，除非通过 Platform Channel 调用原生代码
    // 这里仅做逻辑模拟

    if (Platform.isWindows) {
      // Windows: shutdown /s /t 0, shutdown /r /t 0, etc.
      // Process.run('shutdown', ['/s', '/t', '0']);
      logI('Simulating Windows Shutdown/Restart');
      success = true;
    } else if (Platform.isLinux || Platform.isMacOS) {
      // Linux/Mac: sudo shutdown -h now, sudo reboot
      logI('Simulating Linux/Mac Shutdown/Restart');
      success = true;
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: Cannot shutdown via app usually
      logI('Mobile platform: Cannot perform system shutdown/restart directly');
      success = false;
    }

    return success;
  }

  // 关机动作
  static Future<bool> shutdownAction() async {
    // 检查关机时间是否有效 (模拟 IsDCMInvalidTime)
    if (dtShutdown.millisecondsSinceEpoch == 0) {
      return false;
    }

    DateTime now = DateTime.now();
    Duration diff = now.difference(dtShutdown);

    // C++ 逻辑: dts < 5 mins AND dts > -5 mins (即绝对值小于5分钟)
    // 注意: C++ COleDateTimeSpan 比较逻辑可能不同，这里简化为最近5分钟内
    if (diff.inMinutes.abs() < 5) {
      String strFileName = path.join(DCMGlobal.ftpSettingPath, 'tasklog.xml');

      // 更新 XML 中的 LastShutdown 为 0
      // 这里简化：直接调用 RestartAction
      return await restartAction(cSTATSWOFF);
    }

    return false;
  }
}
