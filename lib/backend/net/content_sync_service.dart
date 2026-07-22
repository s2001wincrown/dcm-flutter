import 'dart:async';

import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/play_log_post.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_log_impl.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/net/transfer_action_service.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:intl/intl.dart';

class ContentSyncService {
  bool _bTransfering = false;

  bool _bStartupTime = false;
  bool _bPlayListUpdated = false;

  final DateTime _dtStartup = DateTime.now();

  String _strPublicIP = '';
  String _strDeviceID = '';
  String _strMACID = '';

  String _strVerInfo = 'Running';
  String _strImportVersion = '';
  String _strPlaylistVersion = '';
  String _strJob = '';

  //CDownloadDynamicDataThread *_pThreadDynamicDataUpdate;

  //CUploadThread  *_pThreadUpload;
  //CMessageThread *_pThreadMessage;
  //CRLTContentThread *_pThreadRLTContent;
  PlayLogPostService? _pPlayLogPost;
  //CDCMSocketImpl *_pTCPServer;

  Future<void> initPlayerRegisterInformation() async {
    //StopTimer(ID_TIMER_UPDATE_REG, true);

    bool bGetRegInfo = false;
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
      PlayerPathService.initLocalFiles();
      var versionInfo = await Utils.uploadVersionInfo();
      _strVerInfo = versionInfo.strVerInfo;
      _strPlaylistVersion = versionInfo.strPlaylistVersion;
      PlayerLogImpl.loadFTPLog();

      /*String strRequest = HTTP_PLAYERLOG) % HTTP_UNIQUE_KEY %
					globalPlayer.strUniqueName % dtStartup.Format('%Y-%m-%d %H:%M:%S') % strPublicIP % strVerInfo % strImportVersion % strPlaylistVersion;*/
      String strRequest =
          '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&dtStartup=${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartup)}&strPublicIP=$_strPublicIP&strLocalAddress=${globalPlayer.strLocalAddress}&strDCMVersion=$_strVerInfo&strUSBPlugin=$_strImportVersion&strPlaylistVersion=$_strPlaylistVersion';
      _bStartupTime =
          await PlayLogPostService.updatePlayerLog(request: strRequest);

      PlayLogPostService.updateShutdown();

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
						PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
					}*/
        if (PlayerTaskFile.pCurrJob != null &&
            (!PlayerTaskFile.pCurrJob!.isTiming() ||
                PlayerPathService.availableForACU())) {
          flagRetryJob(0, false);
        }
      }

      startFtpCheck();
      //StartMessageThread();
      //StartRLTContentThread();

      PlayLogPostService.updateDCMUpdateLog(
          globalPlayer.strUniqueName, globalPlayer.strName);

      if (PlayLogPostService.hasLogPost()) {
        /*if (CreatePlayLogPost()) {
						//if (pPlayLogPost.IsPlayLogPost())
						pPlayLogPost.ResetPostTime();
						pPlayLogPost.Start();
					}*/
      }
    }
    //StartTimer(ID_TIMER_STATUS_CHECK, PlayerPathService.dwStatusCheckInterval);
  }

  void startFtpCheck() {
    //startDynamicDataUpdateThread();
    //startUploadThread();
  }

  bool flagRetryJob(int nRetryInterval, [bool bWriteTaskFile = true]) {
    if (PlayerTaskFile.pCurrJob == null) {
      return false;
    }

    if (PlayerTaskFile.pCurrJob!.taskFailed()) {
      //dwJobStatus = FileTransferStatus.eTRANSFERFAILED;
      PlayerTaskFile.writeTaskFile(
          PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERFAILED);

      String strBatch = PlayerTaskFile.pCurrJob!.strJobItem;
      //DWORD dwStatus = PlayerTaskFile.pCurrJob!.dwJobStatus;
      //SAFE_DELETE(PlayerTaskFile.pCurrJob);
      PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);

      PlayerPathService().removeAllTempFile(strBatch);
      PlayerPathService().copyFileFinish(false);

      PlayerLogFile.closeLogFile('Transfer Failure!');

      _bTransfering = false;

      return false;
    }
    if (bWriteTaskFile) {
      PlayerTaskFile.writeTaskFile();
    }

    PlayerTaskFile.pCurrJob!.retry();
    String strLog;
    strLog =
        'Transfer Failure: Wait for retry (Attempt ${PlayerTaskFile.pCurrJob!.nRetryCount} of ${PlayerTaskFile.pCurrJob!.nRetries})';
    PlayerLogFile.closeLogFile(strLog, bFinished: false);

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
            '''Load Task: '${PlayerTaskFile.pCurrJob!.strJobItem}' successfully; Retry: '${PlayerTaskFile.pCurrJob!.nRetryCount}'; status: '${PlayerTaskFile.pCurrJob!.dwJobStatus}'.''');

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
          PlayerTaskFile.removeTask(pCurrent);
        }
      }
    }

    return false;
  }

  bool isFtpFinished() {
    return true; //m_WorkQueue.GetQueueStatus();
  }

  Future<void> startTempFileCopy() async {
    logI('Copy tempory file to playlist\n');
    if (isFtpFinished()) {
      logI('Start To Copy tempory file to playlist\n');

      //_bTransfering = false;
      _bTransfering = false;
      //CloseLogFile('Download Finished');
      _bPlayListUpdated = false;
      if (PlayerTaskFile.pCurrJob!.dwSyncContent == cSyncDCMPLAYERLOG ||
          PlayerTaskFile.pCurrJob!.dwSyncContent == cSyncDCMTRANSFERLOG) {
        //_bPlayListUpdated = true;
        //StartTimer(ID_TIMER_TEMPFILE_CHECK, 2000, true);
        return;
      }
      if (await PlayerPathService()
          .loadDownloadFileList(PlayerTaskFile.pCurrJob!.strJobItem)) {
        logI('Load Downloaded filelist To Copy tempory file to playlist\n');

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
        //StartTimer(ID_TIMER_TEMPFILE_CHECK, 2000, true);
      } else {
        logI(
            'Load Downloaded filelist failure To Copy tempory file to playlist\n');

        //_bTransfering = false;
        PlayerTaskFile.pCurrJob!.dwJobStatus =
            FileTransferStatus.eTRANSFERINGTEMPFILE;
        //_dwJobStatus = FileTransferStatus.eTRANSFERINGTEMPFILE;
        flagRetryJob(DCMGlobal.retryInterval);
      }
    }
  }

  Future<void> startTransferAction() async {
    if (!await startTransferActionLock()) {
      PlayerLogFile.openLogFile(PlayerTaskFile.pCurrJob!);
      flagRetryJob(DCMGlobal.retryInterval);
    }
  }

  Future<bool> startTransferActionLock() async {
    logI('Checking Task Queue!');
    if (_bTransfering) {
      return true;
    }
    //todo get download queue status
    /*if (!_WorkQueue.getQueueStatus())
    {
      return true;
    }*/
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
      PlayerTaskFile.writeTaskFile(pJob, FileTransferStatus.eNOTTRANSFER);
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
      bDownload = await transferActionEvent(transferAction, pJob, bClearLog);
    } else if (pJob.dwSyncContent == cSyncDCMPLAYERLOG ||
        pJob.dwSyncContent == cSyncDCMTRANSFERLOG) {
      bDownload = await transferActionUpload(transferAction, pJob, bClearLog);
    } else {
      bDownload = await transferActionSchedule(transferAction, pJob, bClearLog);
    }

    return (bDownload == true);
  }

  Future<bool> transferActionSchedule(TransferActionService transferAction,
      PlayerJobItem pJob, bool bClearLog) async {
    bool bDownload = false;
    if (pJob.dwJobStatus.value < FileTransferStatus.eGENERATEDFILELIST.value ||
        pJob.dwJobStatus.value >= FileTransferStatus.eTRANSFEREDCHANNEL.value) {
      PlayerLogFile.openLogFile(pJob, bClearLog);

      logI('Retrieving channel information from server......\n');
      if (pJob.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDCHANNEL.value) {
        PlayerTaskFile.writeTaskFile(
            pJob, FileTransferStatus.eTRANSFEREDCHANNEL);
      }
      //PlayerLogFile.UploadLogFile();
      if (transferAction.dwSyncContent != cSyncPREDATA) {
        logI('Retrieving file list from server......\n');

        if (await transferAction.downloadDailySchedule()) {
          //todo stop temp file copy
          //StopTimer(ID_TIMER_TEMPFILE_CHECK, true);

          if (await transferAction.genFileList()) {
            logI(
                '''Total Size '${FileUtils.formatBytesToMb(PlayerLogFile.nTotalBytesToDownload)}MB' will been download''');
            if (transferAction.isOverMaximumLimitSize()) {
              transferFailureAction();
              return true;
            }

            PlayerLogFile.writeLogFile(
                cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
            if (transferAction.isNoDownloadButScheduleChange()) {
              //_dwJobStatus = FileTransferStatus.eTRANSFEREDTEMPFILE;
              PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob,
                  FileTransferStatus.eTRANSFEREDTEMPFILE);
              startTempFileCopy();

              return true;
            } else {
              transferAction.download();
            }
            bDownload = true;
            //_dwJobStatus = FileTransferStatus.eTRANSFERINGTEMPFILE;
            PlayerTaskFile.writeTaskFile(
                pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
          }
        } else {
          //FlagRetryJob(DCMGlobal.retryInterval);

          logI('Retrieve file list failure\n');
        }
      } else {
        if (await transferAction.genFileList()) {
          if (transferAction.isOverMaximumLimitSize()) {
            transferFailureAction();
            return true;
          }

          PlayerLogFile.writeLogFile(
              cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
          //todo stop temp file copy
          //StopTimer(ID_TIMER_TEMPFILE_CHECK, true);

          transferAction.download();
          bDownload = true;
          //_dwJobStatus = FileTransferStatus.eTRANSFERINGTEMPFILE;
          PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      }
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      bDownload = await transferActionTransfer(transferAction, pJob);
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eUPDATINGPLAYLIST.value) {
      startTempFileCopy();
      bDownload = true;
    }

    return bDownload;
  }

  void transferFailureAction() {
    if (PlayerTaskFile.pCurrJob != null) {
      //_dwJobStatus = FileTransferStatus.eTRANSFERFAILED;
      PlayerTaskFile.pCurrJob!.nRetryCount = PlayerTaskFile.pCurrJob!.nRetries;
      PlayerTaskFile.writeTaskFile(
          PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERFAILED);
      PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);

      PlayerLogFile.closeLogFile('Transfer Failure!');
    }
  }

  Future<bool> transferActionUpload(TransferActionService transferAction,
      PlayerJobItem pJob, bool bClearLog) async {
    bool bDownload = false;
    if (pJob.dwJobStatus.value < FileTransferStatus.eGENERATEDFILELIST.value ||
        pJob.dwJobStatus.value >= FileTransferStatus.eTRANSFEREDCHANNEL.value) {
      PlayerLogFile.openLogFile(pJob, bClearLog);
      if (pJob.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDCHANNEL.value) {
        PlayerTaskFile.writeTaskFile(
            pJob, FileTransferStatus.eTRANSFEREDCHANNEL);
      }
      //PlayerLogFile.UploadLogFile();

      logI('Retrieving file list......\n');
      if (await transferAction.genDailySchedule()) {
        //todo stop temp file copy
        //StopTimer(ID_TIMER_TEMPFILE_CHECK, true);
        if (await transferAction.genFileList()) {
          PlayerLogFile.writeLogFile(
              cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
          if (transferAction.getFileCount() == 0) {
            PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob,
                FileTransferStatus.eTRANSFEREDTEMPFILE);
            startTempFileCopy();

            return true;
          } else {
            //todo upload contents
            //transferAction.upload();
          }
          bDownload = true;
          PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else {
        //FlagRetryJob(DCMGlobal.retryInterval);

        logE('Retrieve file list failure\n');
      }
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      bDownload = await transferActionTransfer(transferAction, pJob);
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eUPDATINGPLAYLIST.value) {
      startTempFileCopy();
      bDownload = true;
    }

    return bDownload;
  }

  Future<bool> transferActionEvent(TransferActionService transferAction,
      PlayerJobItem pJob, bool bClearLog) async {
    bool bDownload = false;
    if (pJob.dwJobStatus.value < FileTransferStatus.eGENERATEDFILELIST.value ||
        pJob.dwJobStatus.value >= FileTransferStatus.eTRANSFEREDCHANNEL.value) {
      PlayerLogFile.openLogFile(pJob, bClearLog);
      if (pJob.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDCHANNEL.value) {
        PlayerTaskFile.writeTaskFile(
            pJob, FileTransferStatus.eTRANSFEREDCHANNEL);
      }
      //PlayerLogFile.UploadLogFile();

      logI('Retrieving file list......\n');

      if (await transferAction.genDailySchedule()) {
        //todo stop temp file copy
        //StopTimer(ID_TIMER_TEMPFILE_CHECK, true);

        if (await transferAction.genFileList()) {
          if (transferAction.isOverMaximumLimitSize()) {
            transferFailureAction();
            return true;
          }

          PlayerLogFile.writeLogFile(
              cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
          if (transferAction.getFileCount() == 0) {
            PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob,
                FileTransferStatus.eTRANSFEREDTEMPFILE);
            startTempFileCopy();

            return true;
          } else {
            transferAction.download();
          }
          bDownload = true;
          PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else {
        //FlagRetryJob(DCMGlobal.retryInterval);

        logE('Retrieve file list failure\n');
      }
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      bDownload = await transferActionTransfer(transferAction, pJob);
    } else if (pJob.dwJobStatus.value <
        FileTransferStatus.eUPDATINGPLAYLIST.value) {
      startTempFileCopy();
      bDownload = true;
    }

    return bDownload;
  }

  Future<bool> transferActionTransfer(
      TransferActionService transferAction, PlayerJobItem pJob) async {
    bool bDownload = false;
    PlayerLogFile.openLogFile(pJob);
    if (await transferAction.genFileList()) {
      PlayerLogFile.writeLogFile(
          cTRANSFERFILECOUNT, '${transferAction.getFileCount()}');
      if (pJob.dwSyncContent == cSyncAPCONTENTLIST ||
          pJob.dwSyncContent == cSyncEVENTCONTENTLIST ||
          pJob.dwSyncContent == cSyncEVENTDATA) {
        if (transferAction.getFileCount() == 0) {
          //StartTempFileCopy();
          //PlayerTaskFile.writeTaskFile();
          PlayerTaskFile.writeTaskFile(
              PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          startTempFileCopy();
        } else {
          transferAction.download();
          PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else if (pJob.dwSyncContent == cSyncDCMPLAYERLOG ||
          pJob.dwSyncContent == cSyncDCMTRANSFERLOG) {
        if (transferAction.getFileCount() == 0) {
          PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          startTempFileCopy();
        } else {
          //todo upload contents
          //transferAction.upload();
          PlayerTaskFile.writeTaskFile(
              pJob, FileTransferStatus.eTRANSFERINGTEMPFILE);
        }
      } else {
        if (transferAction.isNoDownloadButScheduleChange()) {
          //StartTempFileCopy();
          //PlayerTaskFile.writeTaskFile();
          PlayerTaskFile.writeTaskFile(
              PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFEREDTEMPFILE);
          startTempFileCopy();
        } else {
          transferAction.download();
          PlayerTaskFile.writeTaskFile(
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
}
