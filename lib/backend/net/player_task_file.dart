import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_log_impl.dart';
import 'package:dcm/backend/net/netdef.dart';
import 'package:dcm/backend/net/play_log_post.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

// use globalPlayer from player_global.dart

//Content Part Sync
const int cSyncALLCONTENT = 0xFFFF;
const int cSyncDCMDATA = 0x0001;
const int cSyncDDEDATA = 0x0002;
const int cSyncDDEDATAINLUDE = 0x0003;
const int cSyncEVENTDATA = 0x0004;
const int cSyncEVENTCONTENTLIST = 0x0006;
const int cSyncPREDATA = 0x0008;
const int cSyncAHPLAYLIST = 0x0010;
const int cSyncAPCONTENTLIST = 0x0012;
const int cSyncPLAYLISTUPDATE = 0x0020;
const int cSyncROOMEVENT = 0x0040;
const int cSyncAHMESSAGE = 0x0080;
const int cSyncDCMUPDATE = 0x0100;
const int cTASKCOMMAND = 0x0200;
const int cTASKCOMMANDSMS = 0x0400;
const int cTASKRESETSETTINGS = 0x0800;
const int cSyncDCMPLAYERLOG = 0x1000;
const int cSyncDCMTRANSFERLOG = 0x2000;

const int cSyncEXTRADATA = 0x1000;
const int cSyncDYNAMICDATA = 0x2000;
const int cSyncSITEPLAYLIST = 0x4000;
const int cSyncSITEPLAYLISTDEL = 0x8000;

//Setting Part DCM
const int cSETTINGSALL = 0xFFFF;
const int cSETTINGSGENERAL = 0xFFFE;
const int cSETTINGSLM = 0x0001;
const int cSETTINGSREG = 0x0002;
const int cSETTINGSNET = 0x0004;
const int cSETTINGSPLAYER = 0x0008;
const int cSETTINGSTASK = 0x0010;

// --------------------------------------------------------------------------
// 2. Player Object (Job Item) 实现
// --------------------------------------------------------------------------
/*
enum JobItemType
	{
		AUTO = 0,
		MANUAL = 1,
		HTTPGET,
	}
*/
enum JobItemType {
  eAUTO,
  eMANUAL,
  eHTTPGET,
}

/*
enum FileTransferStatus
	{
		WAITFOR_RETRY = -2,
		NOT_TRANSFER = -1,
		TRANSFER_FAILED = 0,
		TRANSFER_SUCCESS,
		GENERATED_FILELIST,
		FILTERED_FILELIST,
		TRANSFERING_TEMPFILE,
		TRANSFERED_TEMPFILE,
		UPDATING_PLAYLIST,

		TRANSFERED_CHANNEL = 21,
		TRANSFERED_SCHEDULE = 22,
		TRANSFERED_EVENT = 23,
		TRANSFERED_DCMFILE = 24,
		TRANSFERED_CONTENTLIST = 25,

		GENERATED_SCHEDULE = 221,
	};
*/
enum FileTransferStatus {
  eWAITFORRETRY(-2),
  eNOTTRANSFER(-1),
  eTRANSFERFAILED(0),
  eTRANSFERSUCCESS(1),
  eGENERATEDFILELIST(2),
  eFILTEREDFILELIST(3),
  eTRANSFERINGTEMPFILE(4),
  eTRANSFEREDTEMPFILE(5),
  eUPDATINGPLAYLIST(6),
  eTRANSFEREDCHANNEL(21),
  eTRANSFEREDSCHEDULE(22),
  eTRANSFEREDEVENT(23),
  eTRANSFEREDDCMFILE(24),
  eTRANSFEREDCONTENTLIST(25),
  eGENERATEDSCHEDULE(221);

  const FileTransferStatus(this.value);
  final int value;
}

class PlayerJobItem {
  String strJobItem = '';
  String strJobTime = '';
  String strFtpTime = '';
  String strTimeOuts = '';
  String strStartFtpTime = '';
  String strSyncContent = '';
  String strOtherInfo = '';

  bool bReplaceFile = false;
  JobItemType dwJobType = JobItemType.eAUTO;

  int nSyncPeriod = 7;
  int nBeforeDay = 1;
  int nRetries = 3;
  int nRetryCount = 0;
  int nMaximumLimit = 0;
  DateTime? dtValidity;

  int dwSyncContent = 0; // DWORD
  int nTaskAction = 0;

  FileTransferStatus dwJobStatus = FileTransferStatus.eNOTTRANSFER;

  int nAction = 0; // 0-waiting, 1-downloading, 2-stop
  bool bIsCurrent = false;

  PlayerJobItem();

  PlayerJobItem.copy(PlayerJobItem other) {
    copyFrom(other);
  }

  void copyFrom(PlayerJobItem other) {
    strJobItem = other.strJobItem;
    strJobTime = other.strJobTime;
    strFtpTime = other.strFtpTime;
    strTimeOuts = other.strTimeOuts;
    strStartFtpTime = other.strStartFtpTime;
    strSyncContent = other.strSyncContent;
    strOtherInfo = other.strOtherInfo;
    bReplaceFile = other.bReplaceFile;
    dwJobType = other.dwJobType;
    nSyncPeriod = other.nSyncPeriod;
    nBeforeDay = other.nBeforeDay;
    nRetries = other.nRetries;
    nRetryCount = other.nRetryCount;
    nMaximumLimit = other.nMaximumLimit;
    dwSyncContent = other.dwSyncContent;
    nTaskAction = other.nTaskAction;
    dwJobStatus = other.dwJobStatus;
    dtValidity = other.dtValidity;
    bIsCurrent = other.bIsCurrent;
    nAction = other.nAction;
  }

  void retry() {
    nRetryCount++;
  }

  bool isTimeForStart() {
    if (strFtpTime.isNotEmpty) {
      // 解析时间格式 'dd/MM/yyyy HH:mm:ss' 或其他
      // 简化比较
      return true;
    }
    return true;
  }

  bool taskFailed() {
    return nRetryCount + 1 > nRetries;
  }

  static bool isImm(JobItemType jobType) {
    return (jobType == JobItemType.eMANUAL || jobType == JobItemType.eHTTPGET);
  }

  bool isTiming() {
    return dwJobType == JobItemType.eAUTO;
  }

  bool hasExpired() {
    return (dtValidity != null &&
        dtValidity!.isAfter(fromOleDateTime()) &&
        dtValidity!.compareTo(DateTime.now()) <= 0);
  }

  // 模拟 XML 序列化
  Map<String, dynamic> toJson() {
    return {
      'strJobItem': strJobItem,
      'strJobTime': strJobTime,
      'strFtpTime': strFtpTime,
      'strTimeOuts': strTimeOuts,
      'strStartFtpTime': strStartFtpTime,
      'strSyncContent': strSyncContent,
      'strOtherInfo': strOtherInfo,
      'bReplaceFile': bReplaceFile ? 1 : 0,
      'dwJobType': dwJobType.index,
      'nSyncPeriod': nSyncPeriod,
      'nBeforeDay': nBeforeDay,
      'nRetries': nRetries,
      'nRetryCount': nRetryCount,
      'nMaximumLimit': nMaximumLimit,
      'dwSyncContent': dwSyncContent,
      'nTaskAction': nTaskAction,
      'dwJobStatus': dwJobStatus.index,
      'dtValidity': dtValidity?.toIso8601String(),
      'bIsCurrent': bIsCurrent ? 1 : 0,
    };
  }

  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_strJobItem', strJobItem);
    pXmlItem.addItem('m_strJobTime', strJobTime);
    pXmlItem.addItem('m_strFtpTime', strFtpTime);
    //pXmlItem.addItem('m_strReFtpTime', strReFtpTime);
    pXmlItem.addItem('m_strTimeOuts', strTimeOuts);
    pXmlItem.addItem('m_strStartFtpTime', strStartFtpTime);
    pXmlItem.addItem('m_strFtpContent', strSyncContent);
    pXmlItem.addItem('m_strOtherInfo', strOtherInfo);
    pXmlItem.addItem('m_bReplaceFile', bReplaceFile ? 1 : 0);
    pXmlItem.addItem('m_dwJobType', dwJobType);
    pXmlItem.addItem('m_nFtpPeriod', nSyncPeriod);
    pXmlItem.addItem('m_nBeforeDay', nBeforeDay);
    pXmlItem.addItem('m_nRetries', nRetries);
    pXmlItem.addItem('m_nRetryCount', nRetryCount);
    pXmlItem.addItem('m_nMaximumLimit', nMaximumLimit);
    pXmlItem.addItem('m_dwFtpContent', dwSyncContent);
    pXmlItem.addItem('m_nTaskAction', nTaskAction);
    pXmlItem.addItem('m_dwJobStatus', dwJobStatus);
    pXmlItem.addItem('m_dtValidity', dtValidity);
    pXmlItem.addItem('m_bIsCurrent', bIsCurrent ? 1 : 0);
  }

  void setXMLItem(XmlItem pXmlItem) {
    pXmlItem.setItemValue('m_strJobItem', strJobItem);
    pXmlItem.setItemValue('m_strJobTime', strJobTime);
    pXmlItem.setItemValue('m_strFtpTime', strFtpTime);
    //pXmlItem.setItemValue('m_strReFtpTime', strReFtpTime);
    pXmlItem.setItemValue('m_strTimeOuts', strTimeOuts);
    pXmlItem.setItemValue('m_strStartFtpTime', strStartFtpTime);
    pXmlItem.setItemValue('m_strFtpContent', strSyncContent);
    pXmlItem.setItemValue('m_strOtherInfo', strOtherInfo);
    pXmlItem.setItemValue('m_bReplaceFile', bReplaceFile ? 1 : 0);
    pXmlItem.setItemValue('m_dwJobType', dwJobType);
    pXmlItem.setItemValue('m_nFtpPeriod', nSyncPeriod);
    pXmlItem.setItemValue('m_nBeforeDay', nBeforeDay);
    pXmlItem.setItemValue('m_nRetries', nRetries);
    pXmlItem.setItemValue('m_nRetryCount', nRetryCount);
    pXmlItem.setItemValue('m_nMaximumLimit', nMaximumLimit);
    pXmlItem.setItemValue('m_dwFtpContent', dwSyncContent);
    pXmlItem.setItemValue('m_nTaskAction', nTaskAction);
    pXmlItem.setItemValue('m_dwJobStatus', dwJobStatus);
    pXmlItem.setItemValue('m_dtValidity', dtValidity);
    pXmlItem.setItemValue('m_bIsCurrent', bIsCurrent ? 1 : 0);
  }

  void getFromXML(XmlItem pXmlItem) {
    strJobItem = pXmlItem.getItemValue('m_strJobItem');
    strJobTime = pXmlItem.getItemValue('m_strJobTime');
    strFtpTime = pXmlItem.getItemValue('m_strFtpTime');
    //strReFtpTime = pXmlItem.getItemValue('m_strReFtpTime');
    strTimeOuts = pXmlItem.getItemValue('m_strTimeOuts');
    if (strTimeOuts.isEmpty) {
      strTimeOuts = PlayerTaskFile.strTimeOuts;
    }

    strStartFtpTime = pXmlItem.getItemValue('m_strStartFtpTime');
    strSyncContent = pXmlItem.getItemValue('m_strFtpContent');
    strOtherInfo = pXmlItem.getItemValue('m_strOtherInfo');
    bReplaceFile = pXmlItem.getItemValueB('m_bReplaceFile');
    dwJobType = JobItemType.values.firstWhere(
        (element) => element.index == pXmlItem.getItemValueI('m_dwJobType'),
        orElse: () => JobItemType.eAUTO);
    XmlItem? pXI = pXmlItem.getItem('m_bImm');
    if (pXI != null) {
      dwJobType = (pXmlItem.getItemValueI('m_bImm') > 0
          ? JobItemType.eMANUAL
          : JobItemType.eAUTO);
    }
    dwSyncContent = pXmlItem.getItemValueI('m_dwFtpContent');
    nSyncPeriod = pXmlItem.getItemValueI('m_nFtpPeriod');
    if (nSyncPeriod < 0 && dwSyncContent != cSyncDCMUPDATE) {
      nSyncPeriod = PlayerTaskFile.nSyncPeriod;
    }

    nBeforeDay = pXmlItem.getItemValueI('m_nBeforeDay');
    nRetries = pXmlItem.getItemValueI('m_nRetries');
    if (nRetries < 0) {
      nRetries = DCMGlobal.taskTransferRetries;
    }

    nRetryCount = pXmlItem.getItemValueI('m_nRetryCount');
    nMaximumLimit = pXmlItem.getItemValueI('m_nMaximumLimit');
    nTaskAction = pXmlItem.getItemValueI('m_nTaskAction');
    XmlItem? pXIJobStatus = pXmlItem.getItem('m_dwJobStatus');
    if (pXIJobStatus != null) {
      dwJobStatus = FileTransferStatus.values.firstWhere(
          (element) => element.value == pXmlItem.getItemValueI('m_dwJobStatus'),
          orElse: () => FileTransferStatus.eTRANSFERFAILED);
    }
    dtValidity = pXmlItem.getItemValueD('m_dtValidity') ?? fromOleDateTime(0);

    bIsCurrent = (pXmlItem.getItemValueI('m_bIsCurrent') > 0);
  }
}

// --------------------------------------------------------------------------
// 3. Player Task File Manager 实现
// --------------------------------------------------------------------------
class PlayerTaskFile {
  static PlayerJobItem? pCurrJob;
  static List<PlayerJobItem> vTaskQueue = [];
  static String strPlayerTaskFile = '';

  static bool bSyncTime = false;
  static DateTime dtSyncTime = fromOleDateTime(0.00);

  static String strFtpTime =
      '${DateFormat('yyyyMMdd').format(DateTime.now())}000000';
  static String strTimeOuts = '05:00';
  static int nSyncPeriod = 7;
  static int nBeforeDay = 1;
  static bool bReplaceFile = false;
  static bool bIsTimeForACU = false;
  static bool bReset = false;

  static void init() {
    strFtpTime =
        '${DateFormat('yyyyMMdd').format(DateTime.now())}${globalPlayer.strSyncTime}00';
    strFtpTime = strFtpTime.replaceAll(':', '');
    strTimeOuts = globalPlayer.strTimeOuts;
    nSyncPeriod = globalPlayer.nSyncPeriod;
    nBeforeDay = globalPlayer.nBeforeDay;
    bReplaceFile = globalPlayer.bReplaceFile;
  }

  Future<bool> isTaskTimeout(String szTask) async {
    //m_nStartupTimeoutDuration: 240
    String strRequest =
        '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$szTask&strStatus=GetStatus&nTimeout=240';

    String strResult = '';
    var contentSyncStatusUpdateUrl = DCMGlobal.cmsUrl;
    contentSyncStatusUpdateUrl = fADDSLASH(contentSyncStatusUpdateUrl);
    contentSyncStatusUpdateUrl += cmsSyncSTATUSURL;
    String strCMSLink =
        '$contentSyncStatusUpdateUrl?${Utils.urlEscape(strRequest)}';
    strCMSLink = Utils.addCMSParam(strCMSLink);
    var httpResult = await PlayerLogFile.httpPostAction(strCMSLink, '');
    if (httpResult.status) {
      strResult = httpResult.result!;
      if (strResult.equalsIgnoreCase('Downloading')) {
        return false;
      } else {
        logE('''Task:'$szTask' timeout\n''', syncTag);
      }
    } else {
      logE('Task timeout check HTTP Conection failure\n', syncTag);
    }

    return true;
  }

  static Future<bool> getTaskFromServer() async {
    // 检查是否启用任务检查
    if (!DCMGlobal.enableTaskCheck) return true;

    // 检查 CMS Backend
    return await getTaskFromCMS();
  }

  static Future<bool> getTaskFromCMS([String? strRequest]) async {
    if (DCMGlobal.cmsUrl.isEmpty) return false;

    String req = strRequest ?? '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}';
    req = Utils.urlEscape(req);

    String strResult = await getTaskFromCMSInternal(req);
    if (strResult.isNotEmpty) {
      if (strResult.length > 14 &&
          !strResult.startsWithIgnoreCase('no player task')) {
        var vTaskQueue = getTaskFromXml(strXML: strResult);
        await dispatchTask(vTaskQueue);
      }
    }
    return false;
  }

  static Future<String> getTaskFromCMSInternal(String strRequest) async {
    String strCMSLink = DCMGlobal.cmsUrl;
    if (!strCMSLink.endsWith('/')) strCMSLink += '/';
    strCMSLink += cmsPLAYERTASKURL;
    strCMSLink += '?${Utils.urlEscape(strRequest)}';

    // Add CMS Param
    strCMSLink = Utils.addCMSParam(strCMSLink);

    var result = await PlayerLogFile.httpPostAction(strCMSLink, '');
    return result.result ?? '';
  }

  static Future<void> checkForAutoDownload() async {
    if (bIsTimeForACU) {
      String strTask =
          strFtpTime; //COleDateTime::GetCurrentTime().Format('%Y%m%d');
      if (await PlayerLogImpl.isNewTaskSave(strTask)) {
        PlayerJobItem task = PlayerJobItem();
        task.strJobItem =
            strTask; //COleDateTime::GetCurrentTime().Format('%Y%m%d%H%M%S');
        task.strJobTime =
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
        task.strFtpTime = ''; //m_strFtpTime;
        //task.strReFtpTime = m_strFtpTime;
        task.strTimeOuts = strTimeOuts;
        task.strStartFtpTime = '';
        task.nMaximumLimit = 0;
        task.dwJobType = JobItemType.eAUTO;

        task.dwSyncContent = cSyncALLCONTENT;
        task.bReplaceFile = bReplaceFile;
        task.nSyncPeriod = nSyncPeriod;
        task.nBeforeDay = nBeforeDay;
        task.dwJobStatus = FileTransferStatus.eNOTTRANSFER;
        if (updateTask(task)) {
          writeTaskFile();
        }
      }
    }
  }

  static bool updateTask(PlayerJobItem pTask) {
    // 查找是否存在相同 JobItem
    int index =
        vTaskQueue.indexWhere((item) => item.strJobItem == pTask.strJobItem);

    if (index != -1) {
      PlayerJobItem existing = vTaskQueue[index];
      if (existing.bIsCurrent) {
        if (pTask.hasExpired()) {
          logW(
              '''Task: '${pTask.strJobItem}' has expired; Valid Time: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(pTask.dtValidity!)}'!''',
              syncTag);
          existing.nAction = 2; // Stop
        }
      } else {
        if (existing.strJobTime != pTask.strJobTime) {
          if (pTask.hasExpired()) {
            logW(
                '''Task: '${pTask.strJobItem}' has expired; Valid Time: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(pTask.dtValidity!)}'!''',
                syncTag);
            vTaskQueue.removeAt(index);
          } else {
            pTask.bIsCurrent = existing.bIsCurrent;
            pTask.dwJobType = existing.dwJobType;
            pTask.dwJobStatus = existing.dwJobStatus;

            existing.copyFrom(pTask);
          }
        } else {
          if (pTask.hasExpired()) {
            logW(
                '''Task: '${pTask.strJobItem}' has expired; Valid Time: '${pTask.dtValidity!.toIso8601String()}'!''',
                syncTag);
            vTaskQueue.removeAt(index);
          }
        }
      }
      return false;
    }

    vTaskQueue.add(pTask);
    return true;
  }

  static void removeTask(PlayerJobItem pTask) {
    logI('''CPlayerTaskFile::RemoveTask: '${pTask.strJobItem}'!''', syncTag);
    int index = vTaskQueue.indexOf(pTask);
    if (index != -1) {
      vTaskQueue.removeAt(index);
    }
    writeTaskFile();
  }

  static Future<bool> loadTaskFile() async {
    XmlFile file = XmlFile('PlayerTasks');
    bool bValid = true;
    XmlItem? pXmlItem;
    if (await File(strPlayerTaskFile).exists()) {
      if (!file.load(strPlayerTaskFile)) {
        bValid = false;
      } else {
        pXmlItem = file.getItem('FileTransfer');
        if (pXmlItem == null) {
          bValid = false;
        }
      }

      if (!bValid) {
        logD(
            '''Load Player task file failure: '$strPlayerTaskFile'; try to delete file to recreate\n''',
            syncTag);
        file.close();
        await File(strPlayerTaskFile).delete();
      }
    } else {
      bValid = false;
    }

    if (bValid) {
      if (pXmlItem != null) {
        XmlItem? pXISibling = pXmlItem.getItem('TaskItem');
        while (pXISibling != null) {
          PlayerJobItem pTask = PlayerJobItem();
          pTask.getFromXML(pXISibling);
          vTaskQueue.add(pTask);
          if (pTask.bIsCurrent) {
            pCurrJob = pTask;
          }

          pXISibling = pXISibling.getSibling();
        }
      }

      //return true;
    }
    String strTaskFile = path.join(DCMGlobal.ftpSettingPath, 'PlayerTasks.xml');
    XmlFile syncTassk = XmlFile('PlayerTasks');
    if (syncTassk.load(strTaskFile)) {
      var taskQueues = getTaskFromXml(syncTassk: syncTassk);
      dispatchTask(taskQueues);
    }

    return (vTaskQueue.isNotEmpty);
  }

  static Future<bool> writeTaskFile(
      [PlayerJobItem? pTask, FileTransferStatus? dwStatus]) async {
    if (pTask != null) {
      if (dwStatus != null) {
        pTask.dwJobStatus = dwStatus;
      }
      return writeTaskFile();
    } else {
      XmlFile file = XmlFile('PlayerTasks');

      // Save DCM Task information
      XmlItem? pXmlItem = file.addItem('FileTransfer');
      if (pXmlItem != null) {
        for (var it in vTaskQueue) {
          XmlItem? xi = pXmlItem.addItem('TaskItem');
          if (xi != null) {
            it.writeToXML(xi);
          }
        }

        return file.save(strPlayerTaskFile);
      }
    }

    return false;
  }

  static PlayerJobItem? getCurrentTask() {
    for (var task in vTaskQueue) {
      if (task.bIsCurrent) {
        return task;
      }
    }
    return null;
  }

  static Future<bool> dispatchTask(List<PlayerJobItem>? taskQueues) async {
    if (taskQueues == null) {
      return false;
    }

    bool bSave = false;
    while (taskQueues.isNotEmpty) {
      var it = taskQueues.first;
      if (it.hasExpired()) {
        logE(
            '''Task: '${it.strJobItem}' has expired; Validity: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(it.dtValidity!)}'!''',
            syncTag);
        taskQueues.remove(it);
        continue;
      }
      if (!PlayerLogImpl.isNewTask(it.strJobItem)) {
        /*CPlayerLogFile::Message(MSG_ERROR, ''%s' is repetitive tasks; Validity: '%s'!',
              it.current.strJobItem, it.current.dtValidity.Format('%Y-%m-%d %H:%M:%S'));*/
        taskQueues.remove(it);
        continue;
      }

      if (it.dwSyncContent == cSyncAHMESSAGE) {
        MessageInfo pMessage = MessageInfo();
        var strAHMessages = it.strSyncContent.split(';');
        String strAHMessageName = strAHMessages[0];
        pMessage.messageID = int.tryParse(strAHMessages[1]) ?? -1;
        pMessage.messageName = strAHMessageName;
        pMessage.status = it.nTaskAction;
        pMessage.task = it.strJobItem;
        /*if (pMessage.messageID == 97) {
          CMainFrame::AHMessageNotify(CFormat('%s;%d') % strAHMessageName % pMessage->status, AHDIRECT_NOTICE);
        } else {
          CMessageThread::AddAHMessage(pMessage);
        }*/
      } else {
        bSave = true;
        updateTask(it);
      }
      taskQueues.remove(it);
    }

    PlayerLogImpl.saveTaskLog();
    if (bSave) {
      writeTaskFile();
    }
    String strTaskFile = path.join(DCMGlobal.ftpSettingPath, 'PlayerTasks.xml');
    File tempFile = File(strTaskFile);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    return true;
  }

  static Future<bool> updateTaskStatus(String strXml) async {
    String strResult = '';
    String strLink = DCMGlobal.cmsUrl;
    strLink = fADDSLASH(strLink);
    strLink += cmsPLAYERTASKUPDATEURL;
    strLink = Utils.addCMSParam(strLink);

    var result = await PlayerLogFile.httpPostAction(strLink, strXml);
    if (result.status) {
      strResult = result.result!;
      if (strResult.equalsIgnoreCase('Successful')) {
        logI('Update task status successfully;', syncTag);
      } else {
        logE('Update task status failure', syncTag);
      }
    } else {
      logE('CPlayerTaskFile::UpdateTaskStatus - HTTP update failure!', syncTag);
    }

    return true;
  }

  static List<PlayerJobItem>? getTaskFromXml(
      {String? strXML, XmlFile? syncTassk}) {
    if (syncTassk == null) {
      if (isNotBlank(strXML)) {
        XmlFile xmlTask = XmlFile('PlayerTasks');
        if (xmlTask.loadXml(strXML!)) {
          String strTaskFile =
              path.join(DCMGlobal.ftpSettingPath, 'PlayerTasks.xml');
          xmlTask.save(strTaskFile);
          return getTaskFromXml(syncTassk: xmlTask);
        }
      }
      logE('CPlayerTaskFile::QueueTask - Empty XML orLoad XML failure!',
          syncTag);

      return null;
    }

    String ftpTime = syncTassk.getItemValue('m_strFtpTime');
    if (ftpTime.isNotEmpty) {
      strFtpTime = ftpTime;
      nBeforeDay = syncTassk.getItemValueI('m_nBeforeDay');
      bReplaceFile = syncTassk.getItemValueB('m_bReplaceFile');
    }
    String timeOuts = syncTassk.getItemValue('m_strTimeOuts');
    if (timeOuts.isNotEmpty) {
      strTimeOuts = timeOuts;
    }
    int syncPeriod = syncTassk.getItemValueI('m_nFtpPeriod');
    if (syncPeriod > 0) {
      nSyncPeriod = syncPeriod;
    }
    bIsTimeForACU = (syncTassk.getItemValueI('IsTimeForAutoUpdate') > 0);

    List<PlayerJobItem> taskQueue = [];
    XmlItem? pItem = syncTassk.getItem('TaskItem');
    if (pItem != null) {
      String strPlayerTask =
          '<?xml version="1.0" encoding="UTF-8"?><PlayerTasks $cHTTPUNIQUEKEY="${globalPlayer.strUniqueName}">';
      while (pItem != null) {
        PlayerJobItem pTaskItem = PlayerJobItem();
        taskQueue.add(pTaskItem);
        pTaskItem.getFromXML(pItem);
        //UpdateTask(&taskItem);
        String strTask =
            '<TaskItem strTask="${pTaskItem.strJobItem}" nAction="1"/>';
        strPlayerTask += strTask;

        pItem = pItem.getSibling();
      }
      strPlayerTask += '</PlayerTasks>';
      updateTaskStatus(strPlayerTask);
    }

    return taskQueue;
  }

  static PlayerJobItem? getTask() {
    PlayerJobItem? pTask;
    PlayerJobItem? pFirst;
    int index = 0;
    for (var it in vTaskQueue) {
      if (it.dwSyncContent == cTASKCOMMANDSMS ||
          it.dwSyncContent == cTASKCOMMAND ||
          it.dwSyncContent == cTASKRESETSETTINGS) {
        continue;
      }

      pFirst ??= it;
      if (it.bIsCurrent) {
        if (index + 1 < vTaskQueue.length) {
          pTask = vTaskQueue.elementAt(index + 1);
        }
        it.bIsCurrent = false;
        break;
      }
      index++;
    }
    pTask ??= pFirst;

    return pTask;
  }

  static PlayerJobItem? getCMDTask() {
    PlayerJobItem? pTask;
    for (var it in vTaskQueue) {
      if (it.dwSyncContent == cTASKCOMMANDSMS ||
          it.dwSyncContent == cTASKCOMMAND ||
          it.dwSyncContent == cTASKRESETSETTINGS) {
        pTask = it;
        vTaskQueue.remove(it);
        break;
      }
    }

    return pTask;
  }

  static void resetTasks() {
    vTaskQueue.clear();
    writeTaskFile();
  }

  static void removeAllTask() {
    writeTaskFile();
    vTaskQueue.clear();
  }

  static void resetSyncStatus() {
    if (pCurrJob != null) {
      pCurrJob!.nRetries = DCMGlobal.taskTransferRetries;
      writeTaskFile(pCurrJob, FileTransferStatus.eTRANSFERFAILED);
      PlayerLogFile.resetSyncStatus();
    }
    //restart app
  }

  static Future<void> synLocalTime() async {
    if (PlayLogPostService.isEnabled(PlayLogPostFlag.playerLog2) &&
        DCMGlobal.cmsUrl.isNotEmpty) {
      final request = PlayLogPostService.buildPlayerLogRequest(
          '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}',
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          PlayLogPostFlag.playerLog2,
          globalPlayer.strUniqueName,
          globalPlayer.strName);
      await PlayLogPostService.updatePlayerLog(request: request);
    }
  }

  static String genHTTPRequest(List<String> arrContent, int type, int nPeriod,
      int dwSyncContent, String strTask,
      [DateTime? dtStartFtpTime]) {
    if (arrContent.isEmpty) {
      return '';
    }
    dtStartFtpTime ??= DateTime.now();

    DateTime dtGMT = dtStartFtpTime.toUtc();
    String strRequest =
        '''<?xml version="1.0" encoding="UTF-8"?><ContentList ContentType="$type" StartFtpTime="${DateFormat('dd/MM/yyyy HH:mm:ss').format(dtGMT)}" FtpPeriod="$nPeriod" FtpContent="$dwSyncContent"
    strUniqueName="${globalPlayer.strUniqueName}" strPlayer="${globalPlayer.strName}" organization="${DCMGlobal.organization}" strTask="$strTask">''';
    for (int i = 0; i < arrContent.length; i++) {
      strRequest += '<Content Name="${arrContent[i]}" />';
    }
    strRequest += '</ContentList>';

    return strRequest;
  }

  static String genHTTPRequestByType(
      int type, int nPeriod, int dwSyncContent, String strTask) {
    DateTime dtGMT = DateTime.now().toUtc();
    String strRequest =
        '''<?xml version="1.0" encoding="UTF-8"?><ContentList ContentType="$type" StartFtpTime="${DateFormat('dd/MM/yyyy HH:mm:ss').format(dtGMT)}" FtpPeriod="$nPeriod" FtpContent="$dwSyncContent"
    strUniqueName="${globalPlayer.strUniqueName}" strPlayer="${globalPlayer.strName}" organization="${DCMGlobal.organization}" strTask="$strTask"></ContentList>''';

    return strRequest;
  }
}

// 示例用法
void main() {
  print('Player Task Manager Initialized');

  // 初始化
  PlayerTaskFile.init();

  // 创建一个任务
  PlayerJobItem job = PlayerJobItem();
  job.strJobItem = 'TestJob_001';
  job.strJobTime = DateTime.now().toIso8601String();
  job.dwJobType = JobItemType.eMANUAL;
  job.dwSyncContent = 1;

  // 更新任务队列
  PlayerTaskFile.updateTask(job);

  // 写入文件
  PlayerTaskFile.writeTaskFile();

  // 记录日志
  PlayerLogFile.openLogFile(job);

  PlayerLogFile.writeLogFile(cTRANSFERERR, 'Test Error Message');

  print('Tasks in queue: ${PlayerTaskFile.vTaskQueue.length}');
}
