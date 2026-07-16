import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/net/play_log_post.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/services/dcm_downloader.dart';
import 'package:dcm/backend/services/player_register_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:worker_manager/worker_manager.dart';

class DcmBackgroundService {
  DcmBackgroundService._();

  static final DcmBackgroundService instance = DcmBackgroundService._();

  bool _started = false;

  Future<void> init() async {
    if (_started) {
      return;
    }

    if (!DCMGlobal.autoContentUpdate) {
      logW('''Auto sync data width CMS is disabled, please check setting: 'Global.AutoContentUpdate'.''');
      return;
    }

    if (DCMGlobal.cmsUrl.isEmpty) {
      logW('''Initialization settings failed for auto sync data, please check file 'server.txt' or settings in Server.''');
      return;
    }

    final queuePath = path.join(App().dataPath, 'download_queue.json');
    final workerConfig = DCMGlobal.snapshot();

    try {
      _started = true;
      unawaited(workerManager.executeGentle((_) async {
        // Apply DCMGlobal config inside worker
        DCMGlobal.applyWorkerConfig(
          cmsUrl: workerConfig['cmsUrl']?.toString(),
          cmsToken: workerConfig['cmsToken']?.toString(),
          organization: workerConfig['organization']?.toString(),
          enableTaskCheck: workerConfig['enableTaskCheck'] as bool?,
          autoContentUpdate: workerConfig['autoContentUpdate'] as bool?,
          fileTransferRetries: workerConfig['fileTransferRetries'] as int?,
          taskTransferRetries: workerConfig['taskTransferRetries'] as int?,
          tempFileCopyRetries: workerConfig['tempFileCopyRetries'] as int?,
          logUploadInterval: workerConfig['logUploadInterval'] as int?,
          logUploadPeriod: workerConfig['logUploadPeriod'] as int?,
          statusCheckInterval: workerConfig['statusCheckInterval'] as int?,
          httpRetryTimes: workerConfig['httpRetryTimes'] as int?,
        );
        dcmHttpClientFactory.dispose();

        // transfer player snapshot into worker and apply
        try {
          final snapshot = snapshotPlayer();
          // `executeGentle` worker closure inherits isolate-local args via captured variables
          // but ensure applyWorkerPlayer is invoked inside the worker context.
          applyWorkerPlayer(snapshot);
        } catch (e) {
          logE('Failed to apply player snapshot in worker: $e');
        }

        PlayerTaskFile.strPlayerTaskFile =
            path.join(DCMGlobal.settingPath, 'FTPtask.xml');
        PlayerTaskFile.init();

        //PlayerLogFile.cleanLogFile();

        await _startPollingInWorker(
          apiUrl: DCMGlobal.cmsUrl + cmsGETFILELISTURL,
          queuePath: queuePath,
          pollingIntervalMinutes: DCMGlobal.statusCheckInterval,
          token: DCMGlobal.cmsToken,
          organization: DCMGlobal.organization,
        );
      }));
    } catch (e, stack) {
      _started = false;
      logE('DcmBackgroundService.init() failed: $e');
      stderr.writeln(stack);
    }
  }

  Future<void> _startPollingInWorker({
    required String apiUrl,
    required String queuePath,
    required int pollingIntervalMinutes,
    required String token,
    required String organization,
  }) async {
    final downloader = DcmDownloader(
      apiUrl: apiUrl,
      queue: DcmDownloadQueue(persistencePath: queuePath),
      pollingInterval: Duration(minutes: pollingIntervalMinutes),
      buildRequestBody: () async =>
          _buildRequestBodyForWorker(token, organization),
    );
    await downloader.startPolling();
  }

  Future<String> _buildRequestBodyForWorker(
      String token, String organization) async {
    final xml = XmlFile('PublishFileInformation');
    xml.setItemValue('Token', token);
    xml.setItemValue('Organization', organization);
    return xml.export();
  }

  Future<String> _buildRequestBody() async {
    final xml = XmlFile('PublishFileInformation');
    xml.setItemValue('Token', DCMGlobal.cmsToken);
    xml.setItemValue('Organization', DCMGlobal.organization);
    return xml.export();
  }

  void _onProgress(DcmDownloadTask task) {
    // keep a lightweight log entry for background progress
    stderr.writeln(
        'DcmDownloader progress: ${task.title} (${task.downloaded}/${task.remoteSize})');
  }

  void _onTaskComplete(DcmDownloadTask task) {
    stderr.writeln(
        'DcmDownloader completed task ${task.id} status=${task.status.name}');
  }

  void initPlayerRegisterInformation(){
			//StopTimer(ID_TIMER_UPDATE_REG, true);

			bool bGetRegInfo = false;
      /*if (!kDebugMode){
			  wxMilliSleep(StartupDelay);
      }*/
			//strImportVersion = Utils.getImportVersion();
			FTPMisc::NetworkCheck();

			//Start TCP Server
			//pTCPServer = new CDCMSocketImpl(this);
      //Start UDP Server
      //InitUDPManager(globalPlayer);

			if (globalPlayer.strUniqueName.isNotEmpty) {
				CFTPPathImpl::InitLocalFiles();
				FTPMisc::UploadVersionInfo(strVerInfo, strPlaylistVersion);
				PlayerLogImpl.loadFTPLog();

#ifdef OLEVIA_PLAYER
				String strRequest = CFormat(HTTP_PLAYERLOG) % HTTP_UNIQUE_KEY %
					globalPlayer.strUniqueName % dtStartup.Format('%Y-%m-%d %H:%M:%S') % strPublicIP % strVerInfo % strImportVersion % strPlaylistVersion;
#else
				String strRequest = CFormat(HTTP_PLAYERLOG) % HTTP_UNIQUE_KEY %
					globalPlayer.strUniqueName % dtStartup.Format('%Y-%m-%d %H:%M:%S') % strPublicIP % globalPlayer.strLocalAddress % strVerInfo % strImportVersion % strPlaylistVersion;
#endif
				bStartupTime = await PlayLogPostService.updatePlayerLog(strRequest);

				PlayLogPostService.updateShutdown();

			//if (LoadFtpSetting())//globalPlayer.LoadFTPSetting() Modify by John 20/06/2007
			//{
				try
				{
					//UpdatePlayerReg();
					if (!PlayerTaskFile.bSyncTime && FTPPathImpl.bAutoSyncTime)
					{
#ifdef FTP_DEBUG
						PlayerLogFile.Message(MSG_INFO, 'Try to Sync Time.');
#endif
						PlayerTaskFile.SynLocalTime();
					}

#ifdef SMS_SUPPORT
					InitSMS();
					if (bGetRegInfo && globalPlayer.strPhoneNumber.IsEmpty())
					{
						String strSMS;
						SendSMS(globalPlayer.strUniqueName, strSMS, 1);
					}
#endif
				}
				catch( ... ) { ;}

				if (LoadFTPTask()) //Load FTP task
				{
#ifdef OLEVIA_PLAYER
					if (!PlayerLogFile.isTaskTimeout(PlayerTaskFile.pCurrJob!.strJobItem))
					{
						flagRetryJob(0, false);
					}
					else
					{
						PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);
					}
#else
					if (PlayerTaskFile.pCurrJob != null && (!PlayerTaskFile.pCurrJob.isTiming() || FTPPathImpl.AvailableForACU())) 
					{
						flagRetryJob(0, false);
					}
#endif
				}

				startFtpCheck();
				//StartMessageThread();
				//StartRLTContentThread();

				PlayLogPostService.updateDCMUpdateLog(globalPlayer.strUniqueName, globalPlayer.strName);

				if (PlayLogPostService.hasLogPost()) {
					if (CreatePlayLogPost()) {
						//if (pPlayLogPost.IsPlayLogPost())
						pPlayLogPost.ResetPostTime();
						pPlayLogPost.Start();
					}
				}
			}
			//StartTimer(ID_TIMER_STATUS_CHECK, FTPPathImpl.dwStatusCheckInterval);
  }

  void startFtpCheck() {
    //startDynamicDataUpdateThread();
    //startUploadThread();
  }

  bool flagRetryJob(int nRetryInterval, [bool bWriteTaskFile = true]) {
    //wxCriticalSectionLocker cs(FTPActionLock);
    if (PlayerTaskFile.pCurrJob == null) {
      return false;
    }

    if (PlayerTaskFile.pCurrJob!.taskFailed()) {
      //dwJobStatus = TRANSFER_FAILED;
      PlayerTaskFile.writeTaskFile(PlayerTaskFile.pCurrJob, FileTransferStatus.eTRANSFERFAILED);

      String strBatch = PlayerTaskFile.pCurrJob!.strJobItem;
      //DWORD dwStatus = PlayerTaskFile.pCurrJob.dwJobStatus;
      //SAFE_DELETE(PlayerTaskFile.pCurrJob);
      PlayerTaskFile.removeTask(PlayerTaskFile.pCurrJob!);

      FTPPathImpl.RemoveAllTempFile(strBatch);
      FTPPathImpl.CopyFileFinish(false);

      PlayerLogFile.closeLogFile('Transfer Failure!');

      bFtping = false;

      return false;
    }
    if (bWriteTaskFile) {
      PlayerTaskFile.writeTaskFile();
    }

    PlayerTaskFile.pCurrJob!.retry();
    String strLog;
    strLog = 'Transfer Failure: Wait for retry (Attempt ${PlayerTaskFile.pCurrJob!.nRetryCount} of ${PlayerTaskFile.pCurrJob!.nRetries})';
    PlayerLogFile.closeLogFile(strLog, bFinished: false);

    //DateTime dtCurr = DateTime.now() + Duration(0, 0, 0, nRetryInterval);
    DateTime dtCurr = DateTime.now().add(Duration(seconds: nRetryInterval));
    String strFtpTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(dtCurr); //dtCurr.Format('%d/%m/%Y %H:%M:%S');
    PlayerTaskFile.pCurrJob!.dwJobType = JobItemType.eMANUAL;
    //PlayerTaskFile.pCurrJob.strReFtpTime = strFtpTime;
    PlayerTaskFile.pCurrJob!.strFtpTime = strFtpTime;
    PlayerTaskFile.pCurrJob!.nAction = 0;

    //PlayerTaskFile.pCurrJob.strJobItem = strFtpTime;
    //PlayerTaskFile.pCurrJob.dwJobStatus = WAITFOR_RETRY;
    return true;
  }

  BOOL loadPlayerTask() {
    if (CFTPTaskFile::LoadTaskFile())
    {
      CFTPJobItem *pCurrent = CFTPTaskFile::GetCurrentTask();
      if (pCurrent != NULL)
      {
        CFTPLogFile::m_strJob = CFTPTaskFile::m_pCurrJob->m_strJobItem;
  #ifdef FTP_DEBUG
        CFTPLogFile::Message(MSG_INFO, CFormat(_T("Load Task: '%s' successfully; Retry: '%d'; status: '%d'")) % \
          CFTPTaskFile::m_pCurrJob->m_strJobItem % CFTPTaskFile::m_pCurrJob->m_nRetryCount % (int)CFTPTaskFile::m_pCurrJob->m_dwJobStatus);
  #endif
        if (CFTPTaskFile::m_pCurrJob->m_dwJobStatus < (DWORD)TRANSFER_FAILED || CFTPTaskFile::m_pCurrJob->m_dwJobStatus > (DWORD)TRANSFER_SUCCESS
          || (CFTPTaskFile::m_pCurrJob->m_dwJobStatus == (DWORD)TRANSFER_FAILED && !CFTPTaskFile::m_pCurrJob->TaskFailed()))
        {
          CFTPTaskFile::m_pCurrJob = pCurrent;

          return TRUE;
        }
        else
        {
          CFTPTaskFile::RemoveTask(pCurrent);
        }
      }
    }

    return FALSE;
  }

  void transferFailureAction() {
    if (CFTPTaskFile::m_pCurrJob != NULL)
    {
      //m_dwJobStatus = TRANSFER_FAILED;
      CFTPTaskFile::m_pCurrJob->m_nRetryCount = CFTPTaskFile::m_pCurrJob->m_nRetries;
      CFTPTaskFile::WriteTaskFile(CFTPTaskFile::m_pCurrJob, TRANSFER_FAILED);
      CFTPTaskFile::RemoveTask(CFTPTaskFile::m_pCurrJob);

      CFTPLogFile::CloseLogFile(_T("Transfer Failure!"));
    }
  }
}
