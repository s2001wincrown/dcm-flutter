import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/sync_http_client.dart';
import 'package:dcm/backend/net/netdef.dart' hide PlayerStatus;
import 'package:dcm/backend/net/play_log_post.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_log_impl.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/net/transfer_action_service.dart';
import 'package:dcm/backend/services/content_downloader.dart';
import 'package:dcm/backend/services/player_register_impl.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

const String kContentSyncPlayerRefreshPortName =
    'content_sync_player_refresh_port';

class ContentSyncService {
  static final ContentSyncService _instance = ContentSyncService._internal();
  factory ContentSyncService() => _instance;
  ContentSyncService._internal();

  bool _bTransfering = false;

  bool bStartupTime = false; // true: successful to player log post at startup
  bool _bPlayListUpdated = false;

  final DateTime _dtStartup = DateTime.now();

  String _strPublicIP = '';
  String _strDeviceID = '';
  String _strMACID = '';

  String _strVerInfo = 'Running';
  String _strImportVersion = '';
  String _strPlaylistVersion = '';
  String _strJob = '';

  bool _isRunning = false;
  Timer? _pollTimer;
  Timer? _tempFileCopyTimer;
  Timer? _syncStatusTimer;
  bool _pollInProgress = false;

  //CDownloadDynamicDataThread *_pThreadDynamicDataUpdate;

  //CUploadThread  *_pThreadUpload;
  //CMessageThread *_pThreadMessage;
  //CRLTContentThread *_pThreadRLTContent;
  PlayLogPostService? _pPlayLogPost;
  //CDCMSocketImpl *_pTCPServer;

  late ContentDownloader _workQueue;

  ContentDownloader get workQueue => _workQueue;
  DateTime get dtStartup => _dtStartup;

  void _notifyMainIsolatePlaylistRefresh(int nCmd, int ntype,
      [String? content]) {
    final SendPort? sendPort =
        IsolateNameServer.lookupPortByName(kContentSyncPlayerRefreshPortName);
    var messageInfo = MessageInfo();
    messageInfo.messageID = nCmd;
    messageInfo.status = ntype;
    messageInfo.messageName = content ?? '';
    String msgInfo = jsonEncode(messageInfo.toJson());
    sendPort?.send(msgInfo);
  }

  Future<void> init() async {
    await initPlayerRegisterInformation();
    _workQueue = ContentDownloader(
      apiUrl: AppGlobal.cmsUrl,
      queue: ContentDownloadQueue(
          persistencePath:
              path.join(AppGlobal.appDataPath, 'download_queue.json')),
      maxRetries: AppGlobal.fileTransferRetries,
      pollingInterval: null,
    );
  }

  Future<void> startPolling() async {
    if (_pollTimer != null) {
      return;
    }
    _pollTimer = Timer.periodic(
        Duration(seconds: AppGlobal.statusCheckInterval), (_) => _pollTick());
    await _pollOnce();
  }

  Future<void> stopPolling() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInProgress = false;
  }

  bool get isPolling => _pollTimer != null;

  Future<void> _pollTick() async {
    if (_pollInProgress) {
      logW('Content sync status check InProgress', syncTag);
      return;
    }
    _pollInProgress = true;
    try {
      await _pollOnce();
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _pollOnce() async {
    try {
      await _contentSyncStatusCheck();
    } catch (e, stack) {
      logE('Content sync status check failed: $e, stack: $stack', syncTag);
    }
  }

  Future<void> startTempFileCopyTimer() async {
    if (_tempFileCopyTimer != null) {
      return;
    }
    _tempFileCopyTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _copyTempFileCheck());
  }

  Future<void> stopTempFileCopyTimer() async {
    _tempFileCopyTimer?.cancel();
    _tempFileCopyTimer = null;
  }

  void startSyncStatusTimer() {
    if (_syncStatusTimer != null) {
      return;
    }

    _bTransfering = true;
    _syncStatusTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _syncStatusCheck());
  }

  Future<void> stopSyncStatusTimer() async {
    _syncStatusTimer?.cancel();
    _syncStatusTimer = null;
  }

  Future<void> _syncStatusCheck() async {
    if (isFtpFinished()) {
      await stopSyncStatusTimer();

      _bTransfering = false;
      if (PlayerLogFile.bSyncFail) {
        PlayerLogFile.bSyncFail = false;
        await flagRetryJob(AppGlobal.retryInterval);
      } else {
        if (PlayerTaskFile.pCurrJob != null) {
          //m_dwJobStatus = TRANSFERED_TEMPFILE;
          await PlayerTaskFile.writeTaskFile(
              PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          await startTempFileCopy();
        }
      }
      return;
    }

    if (!isTimeOuts()) {
      await PlayerTaskFile.resetSyncStatus();
      return;
    }
  }

  bool isWorking() {
    return (_bTransfering && PlayerTaskFile.pCurrJob != null);
  }

  bool isTimeOuts() {
    if (_bTransfering && PlayerTaskFile.pCurrJob != null) {
      DateTime dtDate = PlayerLogFile.dtDownloadStartTime;
      String strTimeOuts = PlayerTaskFile.pCurrJob!.strTimeOuts;
      int nHour = int.tryParse(strTimeOuts.substring(0, 2)) ?? 0;
      int nMin = int.tryParse(strTimeOuts.substring(2, 4)) ?? 0;
      if (dtDate
          .add(Duration(hours: nHour, minutes: nMin))
          .isAfter(DateTime.now())) {
        return true;
      }
    } else if (!_bTransfering) {
      return true;
    }

    return false;
  }

  Future<void> initPlayerRegisterInformation() async {
    //StopTimer(ID_TIMER_UPDATE_REG, true);

    /*if (!kDebugMode){
			  wxMilliSleep(StartupDelay);
      }*/
    //strImportVersion = Utils.getImportVersion();
    //FTPMisc::NetworkCheck();

    //Start TCP Server
    //pTCPServer = new CDCMSocketImpl(this);
    //Start UDP Server
    //InitUDPManager(globalPlayer);

    if (globalPlayer.strUniqueName.isNotEmpty) {
      await PlayerPathService.initLocalFiles();
      var versionInfo = await Utils.uploadVersionInfo();
      _strVerInfo = versionInfo.strVerInfo;
      _strPlaylistVersion = versionInfo.strPlaylistVersion;
      await PlayerLogImpl.loadFTPLog();

      /*String strRequest = HTTP_PLAYERLOG) % HTTP_UNIQUE_KEY %
					globalPlayer.strUniqueName % dtStartup.Format('%Y-%m-%d %H:%M:%S') % strPublicIP % strVerInfo % strImportVersion % strPlaylistVersion;*/
      String strRequest =
          '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&dtStartup=${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartup)}&strPublicIP=$_strPublicIP&strLocalAddress=${globalPlayer.strLocalAddress}&strDCMVersion=$_strVerInfo&strUSBPlugin=$_strImportVersion&strPlaylistVersion=$_strPlaylistVersion';
      bStartupTime =
          await PlayLogPostService.updatePlayerLog(request: strRequest);

      await PlayLogPostService.updateShutdown();

      //if (LoadFtpSetting())//globalPlayer.LoadFTPSetting() Modify by John 20/06/2007
      //{
      //todo sync time and send sms when player startup
      /*try {
        //UpdatePlayerReg();
        if (!PlayerTaskFile.bSyncTime && PlayerPathService.bAutoSyncTime) {
          logI('Try to Sync Time.');

          PlayerTaskFile.SynLocalTime();
        }

        //todo send sms when player startup
      } catch (_) {}*/

      if (await loadPlayerTask()) {
        //Load Player task
        //todo check task status from server
        /*if (!await PlayerTaskFile.isTaskTimeout(PlayerTaskFile.pCurrJob!.strJobItem))
					{
						flagRetryJob(0, false);
					} else {
						await PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
            PlayerTaskFile.pCurrJob = null;
					}*/
        if (PlayerTaskFile.pCurrJob != null &&
            (!PlayerTaskFile.pCurrJob!.isTiming() ||
                PlayerPathService.availableForACU())) {
          await flagRetryJob(0, false);
        }
      }

      startSyncCheck();
      //StartMessageThread();
      //StartRLTContentThread();

      await PlayLogPostService.updateDCMUpdateLog(
          globalPlayer.strUniqueName, globalPlayer.strName);

      if (PlayLogPostService.hasLogPost()) {
        if (createPlayLogPost()) {
          //if (pPlayLogPost.IsPlayLogPost())
          _pPlayLogPost!.resetPostTime();
          _pPlayLogPost!.start();
        }
      }
    }
    //StartTimer(ID_TIMER_STATUS_CHECK, PlayerPathService.dwStatusCheckInterval);
  }

  Future<void> _contentSyncStatusCheck() async {
    //todo wifi check
    //FTPMisc::NetworkCheck();

    //todo UDP server init
    /*if (g_UDPManager == null || (g_UDPManager && !g_UDPManager.IsOk()))
		{
			bool bUDP = InitUDPManager(globalPlayer);

			PlayerLogFile.Message(MSG_INFO, bUDP ? 'Init UDP Socket Successfully!' : 'Init UDP Socket Failure!');

			//FTPMisc::SendStatusToMonitor(0, 0, 'Init UDP Socket Successfully!');
		}*/

    //todo sync time check
    /*if (!PlayerTaskFile.bSyncTime && PlayerPathService.bAutoSyncTime)
		{

			PlayerLogFile.Message(MSG_INFO, 'Try to Sync Time.');

			PlayerTaskFile.SynLocalTime();
		}*/

    if (PlayerTaskFile.bReset) {
      logW('Try to reset all tasks', syncTag);
      await stopSyncStatusTimer();
      _bTransfering = false;
      await _workQueue.resetQueue();
      await PlayerTaskFile.resetTasks();
    }

    logI(
        '''Content Sync Task check: '${globalPlayer.strUniqueName}'; CMS url: '${AppGlobal.cmsUrl}', _bTransfering: '$_bTransfering'.''',
        syncTag);

    if (globalPlayer.strUniqueName.isNotEmpty) {
      await PlayerTaskFile.getTaskFromServer();
      await processCMDTask();

      await PlayLogPostService.updatePlayerLog2();
      await PlayLogPostService.updateShutdown();
      await PlayLogPostService.updateContentLog(
          globalPlayer.strUniqueName, globalPlayer.strName);
      if (PlayerTaskFile.pCurrJob != null) {
        if (PlayerTaskFile.pCurrJob!.nAction == 2) {
          await _workQueue.resetQueue();
          await stopSyncStatusTimer();
          _bTransfering = false;
          await PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
          PlayerTaskFile.pCurrJob = null;
        } else {
          await PlayerLogFile.timeForSyncStatusUpdate();
        }
      }
      await PlayLogPostService.updatePlayerLogRetry();
      if (!_bTransfering) {
        await startSyncAction();
      }
    }
  }

  void startSyncCheck() {
    //startDynamicDataUpdateThread();
    //startUploadThread();
  }

  Future<bool> flagRetryJob(int nRetryInterval,
      [bool bWriteTaskFile = true]) async {
    if (PlayerTaskFile.pCurrJob == null) {
      return false;
    }

    if (PlayerTaskFile.pCurrJob!.taskFailed()) {
      //dwJobStatus = FileTransferStatus.eTRANSFERFAILED;
      await PlayerTaskFile.writeTaskFile(
          PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERFAILED);

      String strBatch = PlayerTaskFile.pCurrJob!.strJobItem;
      //int dwStatus = PlayerTaskFile.pCurrJob!.dwJobStatus;
      //SAFE_DELETE(PlayerTaskFile.pCurrJob);
      await PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
      PlayerTaskFile.pCurrJob = null;

      await PlayerPathService().removeAllTempFile(strBatch);
      await PlayerPathService().copyFileFinish(strBatch, false);

      await PlayerLogFile.closeLogFile('Transfer Failure!');

      _bTransfering = false;

      return false;
    }
    if (bWriteTaskFile) {
      await PlayerTaskFile.writeTaskFile();
    }

    PlayerTaskFile.pCurrJob!.retry();
    String strLog;
    strLog =
        'Transfer Failure: Wait for retry (Attempt ${PlayerTaskFile.pCurrJob!.nRetryCount} of ${PlayerTaskFile.pCurrJob!.nRetries})';
    await PlayerLogFile.closeLogFile(strLog, bFinished: false);

    //DateTime dtCurr = DateTime.now() + Duration(0, 0, 0, nRetryInterval);
    DateTime dtCurr = DateTime.now().add(Duration(seconds: nRetryInterval));
    String strFtpTime = DateFormat('dd/MM/yyyy HH:mm:ss')
        .format(dtCurr); //dtCurr.Format('%d/%m/%Y %H:%M:%S');
    PlayerTaskFile.pCurrJob!.dwJobType = JobItemType.eMANUAL;
    //PlayerTaskFile.pCurrJob!.strReFtpTime = strFtpTime;
    PlayerTaskFile.pCurrJob!.strFtpTime = strFtpTime;
    PlayerTaskFile.pCurrJob!.nAction = 0;

    //PlayerTaskFile.pCurrJob!.strJobItem = strFtpTime;
    //PlayerTaskFile.pCurrJob!.dwJobStatus = WAITFOR_RETRY;
    return true;
  }

  Future<bool> loadPlayerTask() async {
    if (await PlayerTaskFile.loadTaskFile()) {
      PlayerJobItem? pCurrent = PlayerTaskFile.getCurrentTask();
      if (pCurrent != null) {
        PlayerLogFile.strJob = PlayerTaskFile.pCurrJob!.strJobItem;

        logI(
            '''Load Task: '${PlayerTaskFile.pCurrJob!.strJobItem}' successfully; Retry: '${PlayerTaskFile.pCurrJob!.nRetryCount}'; status: '${PlayerTaskFile.pCurrJob!.dwJobStatus}'.''',
            syncTag);

        if (PlayerTaskFile.pCurrJob!.dwJobStatus.value <
                FileTransferStatus.eTRANSFERFAILED.value ||
            PlayerTaskFile.pCurrJob!.dwJobStatus.value >
                FileTransferStatus.eTRANSFERSUCCESS.value ||
            (PlayerTaskFile.pCurrJob!.dwJobStatus ==
                    FileTransferStatus.eTRANSFERFAILED &&
                !PlayerTaskFile.pCurrJob!.taskFailed())) {
          PlayerTaskFile.pCurrJob = pCurrent;

          return true;
        } else {
          await PlayerTaskFile.removeTask(pCurrent);
        }
      }
    }

    return false;
  }

  bool isFtpFinished() {
    return _workQueue.getQueueStatus().allTasksFinished;
  }

  Future<void> startTempFileCopy() async {
    logI('Copy tempory file to playlist\n', syncTag);
    if (isFtpFinished()) {
      logI('Start To Copy tempory file to playlist\n', syncTag);

      //_bTransfering = false;
      _bTransfering = false;
      //CloseLogFile('Download Finished');
      _bPlayListUpdated = false;
      if (PlayerTaskFile.pCurrJob!.dwSyncContent == cSyncDCMPLAYERLOG ||
          PlayerTaskFile.pCurrJob!.dwSyncContent == cSyncDCMTRANSFERLOG) {
        //_bPlayListUpdated = true;
        await startTempFileCopyTimer();
        return;
      }
      if (await PlayerPathService()
          .loadDownloadFileList(PlayerTaskFile.pCurrJob!.strJobItem)) {
        if (PlayerTaskFile.pCurrJob!.dwSyncContent != cSyncDDEDATA &&
            PlayerTaskFile.pCurrJob!.dwSyncContent != cSyncDCMPLAYERLOG &&
            PlayerTaskFile.pCurrJob!.dwSyncContent != cSyncDCMTRANSFERLOG) {
          if (PlayerTaskFile.pCurrJob!.dwSyncContent != cSyncROOMEVENT ||
              (PlayerTaskFile.pCurrJob!.dwSyncContent == cSyncROOMEVENT &&
                  PlayerTaskFile.pCurrJob!.nSyncPeriod != 1)) {
            //String strCmd = String::Format(ddeformat, BLACKSCRN_NOTICE, 0, '');
            //DDENotify(strCmd);
            //::PostMessage(HWND_BROADCAST, wm_Message, (WPARAM)m_hWnd, BLACKSCRN_NOTICE);
          }
        }
        await startTempFileCopyTimer();
      } else {
        logI(
            'Load Downloaded filelist failure To Copy tempory file to playlist\n',
            syncTag);

        //_bTransfering = false;
        PlayerTaskFile.pCurrJob!.dwJobStatus =
            FileTransferStatus.eTRANSFERINGTEMPFILE;
        //_dwJobStatus = FileTransferStatus.eTRANSFERINGTEMPFILE;
        await flagRetryJob(AppGlobal.retryInterval);
      }
    }
  }

  Future<void> _copyTempFileCheck() async {
    String strBatch = PlayerTaskFile.pCurrJob!.strJobItem;
    if (!_bPlayListUpdated) {
      if (PlayerTaskFile.pCurrJob!.dwSyncContent != cSyncDCMPLAYERLOG &&
          PlayerTaskFile.pCurrJob!.dwSyncContent != cSyncDCMTRANSFERLOG) {
        _bPlayListUpdated = await PlayerPathService().tryToCopyTempFile();
      } else {
        _bPlayListUpdated = true;
      }
      if (_bPlayListUpdated) {
        //m_dwJobStatus = TRANSFER_SUCCESS;
        PlayerTaskFile.writeTaskFile(
            PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERSUCCESS);

        await PlayerPathService().copyFileFinish(strBatch);
      } else {
        //PlayerPathService().SaveDownloadFileList();
        if (PlayerPathService().nCopyCount > AppGlobal.tempFileCopyRetries) {
          PlayerPathService().nCopyCount = 0;
          stopTempFileCopyTimer();
          try {
            _notifyMainIsolatePlaylistRefresh(
                PlayerNotice.eSyncFINISHEDNOTICE.index, 0);
          } catch (e) {
            logE('Failed to notify player after room event sync finished: $e',
                syncTag);
          }
          //PlayerPathService().CopyFileFinish(false);
          //PlayerPathService().bCopyTempFile = false;
          await PlayerPathService().saveDownloadFileList(strBatch);
          await flagRetryJob(AppGlobal.retryInterval);
        }
      }
    } else {
      logI('Finished Copy tempory file to playlist\n', syncTag);

      String strLatestPlaylistVersion = PlayerTaskFile.pCurrJob!.strJobItem;
      int dwSyncContent = PlayerTaskFile.pCurrJob!.dwSyncContent;
      int nEventDisplay = PlayerTaskFile.pCurrJob!.nSyncPeriod;
      String strSyncContent = PlayerTaskFile.pCurrJob!.strSyncContent;
      JobItemType dwJobType = PlayerTaskFile.pCurrJob!.dwJobType;

      //m_dwJobStatus = TRANSFER_SUCCESS;
      await PlayerTaskFile.writeTaskFile(
          PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERSUCCESS);
      await PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
      PlayerTaskFile.pCurrJob = null;

      await stopTempFileCopyTimer();

      _bPlayListUpdated = true;
      await PlayerLogFile.closeLogFile('Download Finished');

      _bTransfering = false;
      if (dwSyncContent == cSyncROOMEVENT) {
        //COleDateTime dtCurr = COleDateTime::GetCurrentTime();
        //if (strSyncContent.CmpNoCase(dtCurr.Format(_T("%Y%m%d')) == 0 || strSyncContent.CmpNoCase(_T("DefaultXML') == 0)
        if (nEventDisplay != 1) {
          try {
            _notifyMainIsolatePlaylistRefresh(
                PlayerNotice.eSyncFINISHEDNOTICE.index, 0);
          } catch (e) {
            logE('Failed to notify player after room event sync finished: $e',
                syncTag);
          }
        }

        logI('Send room event sync finished notify to player successfully\n',
            syncTag);
      } else if (dwSyncContent == cSyncDCMUPDATE) {
        String strLocalFile =
            path.join(AppGlobal.ftpSettingPath, 'DCMUpdate.xml');

        String strLocalFile1 = path.join(AppGlobal.ftpSettingPath, 'DCMUpdate');
        await FileUtils.makeSureDirectoryPathExists(strLocalFile1);
        strLocalFile1 = path.join(strLocalFile1, '$strSyncContent.xml');
        String strLocalFile2 = path.join(
            await PlayerPathService.getLocalPath(cDCMUPDATETYPE),
            '$strSyncContent.DCMUP');
        await File(strLocalFile).copy(strLocalFile1);
        await File(strLocalFile).copy(strLocalFile2);
        if (!kDebugMode) {
          if (PlayerJobItem.isImm(dwJobType)) {
            logI('Try to restart player for DCM Update\n', syncTag);

            await PlayerLogImpl.restartAction();
          }
        }
      } else if (dwSyncContent != cSyncDCMPLAYERLOG &&
          dwSyncContent != cSyncDCMTRANSFERLOG) {
        try {
          await Utils.savePlaylistVersion(strLatestPlaylistVersion);
          await PlayerLogFile.genPlaylistContent(nEventDisplay);
          _notifyMainIsolatePlaylistRefresh(
              PlayerNotice.eSyncFINISHEDNOTICE.index, dwSyncContent);
          logI('Send playlist sync finished notify to player successfully\n',
              syncTag);
        } catch (e, stack) {
          logE(
              'Failed to notify player after playlist sync finished: $e, stack: $stack',
              syncTag);
        }
      }
    }
  }

  Future<void> startSyncAction() async {
    if (!await startSyncActionLock()) {
      await PlayerLogFile.openLogFile(PlayerTaskFile.pCurrJob!);
      await flagRetryJob(AppGlobal.retryInterval);
    }
  }

  Future<bool> startSyncActionLock() async {
    logI('Checking Task Queue!', syncTag);
    if (_bTransfering) {
      return true;
    }

    if (!_workQueue.getQueueStatus().allTasksFinished) {
      return true;
    }
    bool bClearLog = false;
    PlayerJobItem? pJob;
    if (PlayerTaskFile.pCurrJob != null) {
      //&& PlayerTaskFile.pCurrJob!.dwJobStatus == WAITFOR_RETRY
      if (PlayerTaskFile.pCurrJob!.nAction == 1) {
        return true;
      }

      if (PlayerTaskFile.pCurrJob!.isTiming() &&
          !PlayerPathService.availableForACU()) {
        return true;
      }

      if (!PlayerTaskFile.pCurrJob!.isTimeForStart()) {
        return true;
      }

      PlayerTaskFile.pCurrJob!.nAction = 1;
      pJob = PlayerTaskFile.pCurrJob;
    } else {
      pJob = PlayerTaskFile.getTask();
      if (pJob != null) {
        pJob.bIsCurrent = true;
        if (pJob.isTiming() && !PlayerPathService.availableForACU()) {
          return true;
        }
        if (!pJob.isTimeForStart()) {
          return true;
        }
        bClearLog = true;
      } else {
        return true;
      }
    }
    if (pJob!.nRetryCount > 0) {
      _strJob = '${pJob.strJobItem} Retry: ${pJob.nRetryCount}';
    } else {
      _strJob = pJob.strJobItem;
    }
    PlayerLogFile.strJob = pJob.strJobItem;

    if (PlayerTaskFile.pCurrJob != pJob) {
      //_dwJobStatus = NOT_TRANSFER;
      await PlayerTaskFile.writeTaskFile(pJob, FileTransferStatus.eNOTTRANSFER);
      PlayerTaskFile.pCurrJob = pJob;
      PlayerTaskFile.pCurrJob!.nAction = 1;
    }

    PlayerLogFile.bSyncFail = false;
    TransferActionService transferAction = TransferActionService(pJob);
    //transferAction.bReplaceFile = pJob.bReplaceFile;
    transferAction.nSyncPeriod = pJob.nSyncPeriod;
    //transferAction.nBeforeDay = pJob.nBeforeDay;
    transferAction.dwSyncContent = pJob.dwSyncContent;
    //transferAction.strSyncContent = pJob.strSyncContent;
    bool bDownload = false;
    if (pJob.dwSyncContent == cSyncAPCONTENTLIST ||
        pJob.dwSyncContent == cSyncEVENTCONTENTLIST ||
        pJob.dwSyncContent == cSyncEVENTDATA ||
        pJob.dwSyncContent == cSyncPLAYLISTUPDATE ||
        pJob.dwSyncContent == cSyncROOMEVENT ||
        pJob.dwSyncContent == cSyncDCMUPDATE ||
        pJob.dwSyncContent == cSyncAHMESSAGE ||
        pJob.dwSyncContent == cSyncSITEPLAYLIST) {
      bDownload = await syncActionEvent(transferAction, pJob, bClearLog);
    } else if (pJob.dwSyncContent == cSyncDCMPLAYERLOG ||
        pJob.dwSyncContent == cSyncDCMTRANSFERLOG) {
      bDownload = await syncActionUpload(transferAction, pJob, bClearLog);
    } else {
      bDownload = await syncActionSchedule(transferAction, pJob, bClearLog);
    }

    return bDownload;
  }

  Future<bool> syncActionSchedule(TransferActionService transferAction,
      PlayerJobItem pJob, bool bClearLog) async {
    bool bDownload = false;
    if (pJob.dwJobStatus.value < FileTransferStatus.eGENERATEDFILELIST.value ||
        pJob.dwJobStatus.value >= FileTransferStatus.eTRANSFEREDCHANNEL.value) {
      await PlayerLogFile.openLogFile(pJob, bClearLog);

      logI('Retrieving channel information from server......\n', syncTag);
      if (pJob.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDCHANNEL.value) {
        await PlayerTaskFile.writeTaskFile(
            pJob, FileTransferStatus.eTRANSFEREDCHANNEL);
      }
      //PlayerLogFile.UploadLogFile();
      if (transferAction.dwSyncContent != cSyncPREDATA) {
        logI('Retrieving file list from server......\n', syncTag);

        if (await transferAction.downloadDailySchedule()) {
          await stopTempFileCopyTimer();

          if (await transferAction.genFileList()) {
            logI(
                '''Total Size '${FileUtils.formatBytesToMb(PlayerLogFile.nTotalBytesToDownload)}MB' will been download''',
                syncTag);
            if (await transferAction.isOverMaximumLimitSize()) {
              await transferFailureAction();
              return true;
            }

            await PlayerLogFile.writeLogFile(
                cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');

            startSyncStatusTimer();
            if (transferAction.isNoDownloadButScheduleChange()) {
              await stopSyncStatusTimer();
              //_dwJobStatus = FileTransferStatus.eTRANSFEREDTEMPFILE;
              await PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob,
                  FileTransferStatus.eTRANSFEREDTEMPFILE);
              await startTempFileCopy();

              return true;
            } else {
              await transferAction.download();
            }
            bDownload = true;
            //_dwJobStatus = FileTransferStatus.eTRANSFERINGTEMPFILE;
            await PlayerTaskFile.writeTaskFile(
                pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
          }
        } else {
          //FlagRetryJob(AppGlobal.retryInterval);

          logI('Retrieve file list failure\n', syncTag);
        }
      } else {
        if (await transferAction.genFileList()) {
          if (await transferAction.isOverMaximumLimitSize()) {
            await transferFailureAction();
            return true;
          }

          await PlayerLogFile.writeLogFile(
              cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
          await stopTempFileCopyTimer();

          await transferAction.download();
          bDownload = true;
          //_dwJobStatus = FileTransferStatus.eTRANSFERINGTEMPFILE;
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      }
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      bDownload = await syncActionTransfer(transferAction, pJob);
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eUPDATINGPLAYLIST.value) {
      await startTempFileCopy();
      bDownload = true;
    }

    return bDownload;
  }

  Future<void> transferFailureAction() async {
    if (PlayerTaskFile.pCurrJob != null) {
      //_dwJobStatus = FileTransferStatus.eTRANSFERFAILED;
      PlayerTaskFile.pCurrJob!.nRetryCount = PlayerTaskFile.pCurrJob!.nRetries;
      await PlayerTaskFile.writeTaskFile(
          PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERFAILED);
      await PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
      PlayerTaskFile.pCurrJob = null;

      await PlayerLogFile.closeLogFile('Transfer Failure!');
    }
  }

  Future<bool> syncActionUpload(TransferActionService transferAction,
      PlayerJobItem pJob, bool bClearLog) async {
    bool bDownload = false;
    if (pJob.dwJobStatus.value < FileTransferStatus.eGENERATEDFILELIST.value ||
        pJob.dwJobStatus.value >= FileTransferStatus.eTRANSFEREDCHANNEL.value) {
      await PlayerLogFile.openLogFile(pJob, bClearLog);
      if (pJob.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDCHANNEL.value) {
        await PlayerTaskFile.writeTaskFile(
            pJob, FileTransferStatus.eTRANSFEREDCHANNEL);
      }
      //PlayerLogFile.UploadLogFile();

      logI('Retrieving file list......\n', syncTag);
      if (await transferAction.genDailySchedule()) {
        await stopTempFileCopyTimer();
        if (await transferAction.genFileList()) {
          PlayerLogFile.writeLogFile(
              cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
          startSyncStatusTimer();
          if (transferAction.getFileCount() == 0) {
            await stopSyncStatusTimer();
            await PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob,
                FileTransferStatus.eTRANSFEREDTEMPFILE);
            await startTempFileCopy();

            return true;
          } else {
            //todo upload contents
            //transferAction.upload();
          }
          bDownload = true;
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else {
        //flagRetryJob(AppGlobal.retryInterval);

        logE('Retrieve file list failure\n', syncTag);
      }
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      bDownload = await syncActionTransfer(transferAction, pJob);
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eUPDATINGPLAYLIST.value) {
      await startTempFileCopy();
      bDownload = true;
    }

    return bDownload;
  }

  Future<bool> syncActionEvent(TransferActionService transferAction,
      PlayerJobItem pJob, bool bClearLog) async {
    bool bDownload = false;
    if (pJob.dwJobStatus.value < FileTransferStatus.eGENERATEDFILELIST.value ||
        pJob.dwJobStatus.value >= FileTransferStatus.eTRANSFEREDCHANNEL.value) {
      await PlayerLogFile.openLogFile(pJob, bClearLog);
      if (pJob.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDCHANNEL.value) {
        await PlayerTaskFile.writeTaskFile(
            pJob, FileTransferStatus.eTRANSFEREDCHANNEL);
      }
      //PlayerLogFile.UploadLogFile();

      logI('Retrieving file list......\n', syncTag);

      if (await transferAction.genDailySchedule()) {
        await stopTempFileCopyTimer();

        if (await transferAction.genFileList()) {
          if (await transferAction.isOverMaximumLimitSize()) {
            await transferFailureAction();
            return true;
          }

          PlayerLogFile.writeLogFile(
              cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
          startSyncStatusTimer();
          if (transferAction.getFileCount() == 0) {
            await stopSyncStatusTimer();
            await PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob,
                FileTransferStatus.eTRANSFEREDTEMPFILE);
            await startTempFileCopy();

            return true;
          } else {
            await transferAction.download();
          }
          bDownload = true;
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else {
        //FlagRetryJob(AppGlobal.retryInterval);

        logE('Retrieve file list failure\n', syncTag);
      }
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      bDownload = await syncActionTransfer(transferAction, pJob);
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eUPDATINGPLAYLIST.value) {
      await startTempFileCopy();
      bDownload = true;
    }

    return bDownload;
  }

  Future<bool> syncActionTransfer(
      TransferActionService transferAction, PlayerJobItem pJob) async {
    bool bDownload = false;
    await PlayerLogFile.openLogFile(pJob);
    if (await transferAction.genFileList()) {
      await PlayerLogFile.writeLogFile(
          cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
      startSyncStatusTimer();
      if (pJob.dwSyncContent == cSyncAPCONTENTLIST ||
          pJob.dwSyncContent == cSyncEVENTCONTENTLIST ||
          pJob.dwSyncContent == cSyncEVENTDATA) {
        if (transferAction.getFileCount() == 0) {
          await stopSyncStatusTimer();
          //StartTempFileCopy();
          //PlayerTaskFile.writeTaskFile();
          await PlayerTaskFile.writeTaskFile(
              PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          await startTempFileCopy();
        } else {
          await transferAction.download();
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else if (pJob.dwSyncContent == cSyncDCMPLAYERLOG ||
          pJob.dwSyncContent == cSyncDCMTRANSFERLOG) {
        if (transferAction.getFileCount() == 0) {
          await stopSyncStatusTimer();
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          await startTempFileCopy();
        } else {
          //todo upload contents
          //transferAction.upload();
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else {
        if (transferAction.isNoDownloadButScheduleChange()) {
          await stopSyncStatusTimer();
          //StartTempFileCopy();
          //PlayerTaskFile.writeTaskFile();
          await PlayerTaskFile.writeTaskFile(
              PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          await startTempFileCopy();
        } else {
          await transferAction.download();
          await PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      }
      bDownload = true;
    }

    return bDownload;
  }

  Future<bool> getPublicIP() async {
    //todo retrieve Mobile network information

    var result = await httpGetPublicIP();
    if (isNotBlank(result)) {
      globalPlayer.strPublicIP = result!;
    } else {
      globalPlayer.strPublicIP = globalPlayer.strLocalAddress;
    }
    _strPublicIP = globalPlayer.strPublicIP;

    return (globalPlayer.strPublicIP.isNotEmpty);
  }

  Future<void> processCMDTask() async {
    PlayerJobItem? pTask = PlayerTaskFile.getCMDTask();
    if (pTask == null) {
      return;
    }
    await PlayerTaskFile.writeTaskFile();

    logI(
        '''Get Command:'${pTask.dwSyncContent}' from task list; Action:'${pTask.nTaskAction}' \n''',
        syncTag);
    if (pTask.dwSyncContent == cTASKRESETSETTINGS) {
      await resetSettings(pTask.nTaskAction);
    } else if (pTask.dwSyncContent == cTASKCOMMAND) {
      var taskCommand = netCommandFrom(pTask.nTaskAction);
      if (taskCommand != null) {
        switch (taskCommand) {
          case NetCommand.resetSelf:
            {
              //todo restart dcmplayer.exe
              //EnumAndKillProcess('DCMPlayer.exe');
            }
            break;
          case NetCommand.resetHost:
            {
              await PlayerLogImpl.restartAction();
            }
            break;

          case NetCommand.shutdown:
            {
              await PlayerLogImpl.shutdownDevice();
            }
            break;

          case NetCommand.requestSyncTime:
            {
              //todo: sync time from time server
              await PlayerTaskFile.synLocalTime();
            }
            break;
          case NetCommand.resetSettings:
            {
              await resetSettings(cSETTINGSGENERAL);
            }
            break;

          case NetCommand.resetTransfer:
            await PlayerTaskFile.resetSyncStatus();
            break;

          case NetCommand.resetTasks:
            PlayerTaskFile.bReset = true;
            break;

          case NetCommand.monitor:
            {
              MessageInfo msgInfo = MessageInfo();
              msgInfo.status = fMAKEDWORD(
                  pTask.nRetries, pTask.nSyncPeriod); //Port Number + nFormat
              msgInfo.messageID = pTask.nMaximumLimit;
              String strContent = '';
              if (pTask.strSyncContent.length > 50) {
                strContent = pTask.strSyncContent;
              } else {
                msgInfo.messageName = pTask.strSyncContent;
              }
              processCMDMonitor(msgInfo, strContent);
            }
            break;
          default:
            break;
        }
      }
    } else if (pTask.dwSyncContent == cTASKCOMMANDSMS) {
      MessageInfo msgInfo = MessageInfo();
      msgInfo.status = pTask.nTaskAction;
      msgInfo.messageName = pTask.strSyncContent;
      processSMSControl(msgInfo);
    }
  }

  Future<void> processSMSControl(MessageInfo pData) async {
    int dwLogPost = PlayLogPostService.logPostFlags;
    int dwSMSCommand = pData.status;
    if (dwSMSCommand & kSMSCOMMANDRESET > 0) {
      _bTransfering = false;
      //m_dwJobStatus = TRANSFER_FAILED;
      await PlayerTaskFile.resetSyncStatus();

      return;
    }

    if (dwSMSCommand & kSMSCOMMANDPLAYLOG > 0) {
      PlayLogPostService.logPostFlags |= PlayLogPostFlag.playLog.value;

      //todo: send sms
      /*String strSMS;
      strSMS = '%s=%s&SMSCommand=%d') % HTTP_UNIQUE_KEY % globalPlayer.strUniqueName % kSMSCOMMANDPLAYLOG;
      String strResult;
      SendSMS(strSMS, strResult, 3);*/
    }

    if (dwSMSCommand & kSMSCOMMANDUSBDTLLOG > 0) {
      PlayLogPostService.logPostFlags |= PlayLogPostFlag.usbDtlLog.value;

      //todo: send sms
      /*String strSMS;
      strSMS = '%s=%s&SMSCommand=%d') % HTTP_UNIQUE_KEY % globalPlayer.strUniqueName % kSMSCOMMANDUSBDTLLOG;
      String strResult;
      SendSMS(strSMS, strResult, 3);*/
    }

    if (dwSMSCommand & kSMSCOMMANDFTPLOG > 0) {
      //PlayLogPostService.logPostFlags |= FTPDTLLOG_POST;

      /*String strSMS;
      strSMS = '%s=%s&SMSCommand=%d') % HTTP_UNIQUE_KEY % globalPlayer.strUniqueName % kSMSCOMMANDFTPLOG;
      String strResult;
      SendSMS(strSMS, strResult, 3);*/
    }

    if (dwSMSCommand & kSMSCOMMANDPLAYLIST > 0) {
      //String strMessage = pData.messageName;
      //todo: change playlist and send sms
      // write text to memory-mapped file
      /*if ( !strMessage.IsEmpty() && m_pViewOfFile  &&  m_pLock )
      {
        // get write access to common memory block
        if ( m_pLock.WaitToWrite() )
        {
          lstrcpy( (LPTSTR) m_pViewOfFile, strMessage);
          m_pLock.Done();

          // Notify all running instances that text was changed
          ::PostMessage(HWND_BROADCAST, wm_Message, (WPARAM)m_hWnd, CHANGEPLAYLIST_NOTICE);
        }
      }

      String strSMS;
      strSMS  = '%s=%s&SMSCommand=%d&strPlaylist=%s') % HTTP_UNIQUE_KEY % globalPlayer.strUniqueName % kSMSCOMMANDPLAYLIST % strMessage;
      String strResult;
      SendSMS(strSMS, strResult, 3);*/
    }

    if (dwSMSCommand & kSMSCOMMANDBPSSTATUS > 0) {
      /*String strRequest;
      String strFormat = '%s=%s&dtStartup=%s&dtLastSyncTime=%s&strPublicIP=%s&strMACID=%s&strDeviceID=%s&strMACAddress=%s&strMACAddress1=%s&strLocalAddress=%s&strDCMVersion=%s';
      strRequest  = strFormat) % HTTP_UNIQUE_KEY %
        globalPlayer.strUniqueName % m_dtStartup.Format('%Y-%m-%d %H:%M:%S') % m_dtSyncTime.Format('%Y-%m-%d %H:%M:%S') %
        m_strPublicIP % m_strMACID % m_strDeviceID % globalPlayer.strMACAddress % globalPlayer.strMACAddress1 %
        globalPlayer.strLocalAddress % m_strVerInfo);*/
      //todo: get player information and send sms
      /*DateTime dtCurr = DateTime.now();
      String strRequest;
      String strFormat = '%s=%s&dtStartup=%s&dtLastSyncTime=%s&strPublicIP=%s&strMACID=%s&strDeviceID=%s&dtLogDate=%s';
      strRequest = strFormat) % HTTP_UNIQUE_KEY %
        globalPlayer.strUniqueName % m_dtStartup.Format('%Y-%m-%d %H:%M:%S') % m_dtSyncTime.Format('%Y-%m-%d %H:%M:%S') %
        m_strPublicIP % m_strMACID % m_strDeviceID % dtCurr.Format('%Y-%m-%d %H:%M:%S');

      String strResult;
      SendSMS(strRequest, strResult, 3);

      strFormat = '%s=%s&dtStartup=%s&strMACAddress=%s&strMACAddress1=%s&strLocalAddress=%s&strDCMVersion=%s&dtLogDate=%s';
      strRequest = strFormat) % HTTP_UNIQUE_KEY %
        globalPlayer.strUniqueName % m_dtStartup.Format('%Y-%m-%d %H:%M:%S') % globalPlayer.strMACAddress % globalPlayer.strMACAddress1 %
        '' % m_strVerInfo % dtCurr.Format('%Y-%m-%d %H:%M:%S'); //globalPlayer.strLocalAddress
      SendSMS(strRequest, strResult, 3);*/
    }

    if (dwSMSCommand & kSMSCOMMANDTIMESYNC > 0) {
      //todo: sync time and send sms
      /*SynLocalTime();

      String strSMS;
      strSMS = '%s=%s&SMSCommand=%d') % HTTP_UNIQUE_KEY % globalPlayer.strUniqueName % kSMSCOMMANDTIMESYNC;
      String strResult;
      SendSMS(strSMS, strResult, 3);*/
    }
    if (PlayLogPostService.logPostFlags != dwLogPost) {
      PlayLogPostService.processLogPostFlag(PlayLogPostService.logPostFlags);
      if (PlayLogPostService.hasLogPost()) {
        if (createPlayLogPost()) {
          _pPlayLogPost!.start();
        }
      }
    }
  }

  //Startup Play log post thread
  bool createPlayLogPost() {
    if (_pPlayLogPost == null) {
      _pPlayLogPost = PlayLogPostService(
        uniqueName: globalPlayer.strUniqueName,
        playerName: globalPlayer.strName,
        logUploadInterval: AppGlobal.logUploadInterval,
        logUploadPeriod: AppGlobal.logUploadPeriod,
        httpClientFactory: syncHttpClientFactory,
      );
      if (_pPlayLogPost != null) {
        //todo: create log upload thread
        String strLogPath = AppGlobal.logPath;
        String strPlayLogPath = '${strLogPath}PlayLog';
        String strPlaylistLogPath = '${strLogPath}PlaylistLog';
        String strUSBLogPath = '${strLogPath}USBLog';
        String strMSGLogPath = '${strLogPath}MSGLog';
        String strCOMLogPath = '${strLogPath}COMLog';
        String strAHPlayLogPath = '${strLogPath}AHPlayLog';
        String strAPPlayLogPath = '${strLogPath}APPlayLog';
        String strDDELogPath = '${strLogPath}DDELog';
        String strContentLogPath = '${strLogPath}ContentLog';

        _pPlayLogPost!.logFolders.add(strPlayLogPath); //0
        _pPlayLogPost!.logFolders.add(strAHPlayLogPath); //1
        _pPlayLogPost!.logFolders.add(strAPPlayLogPath); //2
        _pPlayLogPost!.logFolders.add(strPlaylistLogPath); //3
        _pPlayLogPost!.logFolders.add(strUSBLogPath); //4
        _pPlayLogPost!.logFolders.add(strMSGLogPath); //5
        _pPlayLogPost!.logFolders.add(strCOMLogPath); //6
        _pPlayLogPost!.logFolders.add(strDDELogPath); //7
        _pPlayLogPost!.logFolders.add(strContentLogPath); //8
      }
    }

    return (_pPlayLogPost != null);
  }

  void processCMDMonitor(MessageInfo pData, String strContent) {
    //todo: control monitor status through serial port
    String strCmd = pData.messageName;
    if (strContent.isNotEmpty) {
      strCmd = strContent;
    }
    logI('''Try to Send serial port Command:'$strCmd'\n''', syncTag);

    /*logI('Send serial port Command:'%s' %s\n') % strCmd % (bSuccess ? 'Successfully!' : 'Failure!'));
    if (!bSuccess)
    {
      logI('Send serial port Command:'%s' %s\n') % strCmd % pSerialControl.GetLastErrMsg());
    }*/
  }

  void queryMonitorStatus(String strCmd) {
    //todo: query monitor status through serial port
    logI('''Serial port Command:'$strCmd' has been not sent!\n''',
        syncTag); //${false ? '' : 'not'}
  }

  Future<void> resetSettings(int dwSettings) async {
    await stopSyncStatusTimer();
    await stopTempFileCopyTimer();
    await stopPolling();
    _bTransfering = false;
    await workQueue.resetQueue();
    await PlayerTaskFile.resetTasks();

    if ((dwSettings & cSETTINGSNET) > 0) {
      await PlayerPathService().reset();
    }
    if (dwSettings & cSETTINGSREG > 0) {
      await PlayerRegisterImpl.reset();
    }
    //todo: reset license
    /*if (dwSettings & cSETTINGSLM > 0)
      wxGetApp().reset();*/

    if (dwSettings & cSETTINGSPLAYER > 0) {
      await resetPlayerSettings();
      String strIniFile = path.join(AppGlobal.appDataPath, 'ContentTypes.xml');
      var file = File(strIniFile);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!kDebugMode) {
      await PlayerLogImpl.restartAction();
    }
  }
}
