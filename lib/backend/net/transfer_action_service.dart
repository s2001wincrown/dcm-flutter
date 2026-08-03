import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/channel_player_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/content_sync_service.dart';
import 'package:dcm/backend/net/daily_schedule_data.dart';
import 'package:dcm/backend/net/daily_schedule_file.dart';
import 'package:dcm/backend/net/play_log_post.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/net/file_filter_service.dart';
import 'package:dcm/backend/services/content_downloader.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_info_utils.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/app_update_file.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// 对应 CFtpActionImpl 的核心调度逻辑
class TransferActionService {
  static const String lpszSignature =
      'DCM FTP Manager Version 1.00 - Player Information for FTP';
  static const String lpszMessageSignature =
      'dcCatalogue Version 4.00 - Ad hoc Message List';

  DailyScheduleFile dailySchedule = DailyScheduleFile();

  final List<ChannelPlayerData> _lstChannelPlayer = [];
  late int nSyncPeriod;
  late int _nBeforeDay;
  int dwSyncContent = cSyncALLCONTENT;
  late DateTime _dtStartFtpTime;
  String _strSyncContent = '';

  final FileFilterService _fileListImpl = FileFilterService();
  final List<DailyScheduleData> _lstDailySchedule = [];
  late final PlayerJobItem _pTaskItem;

  late String _strBatch;
  late int _nTaskAction;

  TransferActionService(this._pTaskItem) {
    _strBatch = _pTaskItem.strJobItem;
    _nTaskAction = _pTaskItem.nTaskAction;
    nSyncPeriod = _pTaskItem.nSyncPeriod;
    _nBeforeDay = _pTaskItem.nBeforeDay;
    dwSyncContent = _pTaskItem.dwSyncContent;
    _strSyncContent = _pTaskItem.strSyncContent;
    _calcStartTime(_pTaskItem);
  }

  void _calcStartTime(PlayerJobItem pJob) {
    DateTime dtCurr = DateTime.now();
    DateTime? dtStartFtpTime;
    if (pJob.strStartFtpTime.isEmpty) {
      dtStartFtpTime = dtCurr.copyWith(hour: 23, minute: 59, second: 59);
      dtStartFtpTime = dtStartFtpTime.subtract(Duration(days: _nBeforeDay));
    } else {
      dtStartFtpTime = fromDateTimeFormat(pJob.strStartFtpTime);
      if (dtStartFtpTime != null) {
        dtCurr = dtStartFtpTime.toLocal();
      }
      dtStartFtpTime = dtCurr.copyWith(hour: 23, minute: 59, second: 59);
    }
    _dtStartFtpTime = dtStartFtpTime;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : Download 										*/
  /* Description   : Download all file list                       	*/
  /*																	*/
  /// *****************************************************************
  Future<bool> download() async {
    if (_pTaskItem.nRetries > 0) {
      List<ContentDownloadTask> syncTasks = [];
      for (var iter in _fileListImpl.fileList) {
        FileInfoData pData = iter;
        if (pData.fileStatus == FileItemStatus.download) {
          String strRemotePath = '/';
          String strDestFile = pData.strDestFile;
          strDestFile = FileUtils.fixPathSeparators(strDestFile);
          String strDest = path.join(
              await PlayerPathService.getLocalPath(pData.nContentType, true),
              strDestFile); //pData.strShortPath
          String strRemoteFile = pData.strShortPath;
          if (pData.nContentType != cDCMPREDATATYPE) {
            strRemoteFile = FileUtils.appendUrls(strRemotePath, strRemoteFile);
            syncTasks.add(ContentDownloadTask.fromFileInfoData(
                pData, AppGlobal.cmsUrl, strDest));
            logI(
                '''Add remote file '$strRemoteFile' to download queue; target file '$strDest'.''',
                syncTag);
          } else {
            String strPreRemoteFile =
                FileUtils.appendUrls(strRemotePath, strRemoteFile);
            downloadPreDataFile(strPreRemoteFile, pData.dwFileSize, strDest);
          }
        }
      }
      ContentSyncService().workQueue.addTasksToQueue(syncTasks);

      return true;
    }

    return false;
  }

  void downloadUpdateFile() {
    /*String strDirectory = PlayerPathService.getServerPath(DCM_UPDATE_TYPE);
    if (!strDirectory.isEmpty)
      DownloadDirectory(strDirectory, null, DCM_UPDATE_TYPE);*/
  }

  /********************************************************************/
  /*																	*/
  /* Function name : DoFileDownload									*/
  /* Description   : Download a file or directory to specific	        */
  /*				   path.											*/
  /*																	*/
  /// *****************************************************************
  void doFileDownload(
      String strFile,
      String strFileTitle,
      int nContentType,
      BigInt dwFileLength,
      String strLocalName,
      int dwTransferType,
      bool bIsDirectory) {
    String strRemoteFile = strFile;
    if (!strRemoteFile.startsWith('/')) {
      strRemoteFile = '/$strRemoteFile';
    }
    // is selected item a directory ?
    if (bIsDirectory) {
      //downloadDirectory(strRemoteFile, strLocalName);
    } else {
      downloadFile(strRemoteFile, strFileTitle, nContentType, dwFileLength,
          dwTransferType, strLocalName);
    }
  }

  /********************************************************************/
  /*																	                                */
  /* Function name : DownloadFile										                  */
  /* Description   : Download a file									                */
  /*																	                                */
  /// *****************************************************************
  void downloadFile(String lpszFileName, String strFileTitle, int nContentType,
      BigInt dwFileLength, int dwTransferType, String lpszDestination) {
    //wxMessageBox(strRemoteFile + '\n' + strLocalFile);
    //ContentSyncService().workQueue.addTask(task);
    //m_WorkQueue.InsertWorkItem(new CTransferWorkItem((_nTaskAction == 0 ? 0 : dwSyncContent), 0, strRemoteFile, strLocalFile, dwFileLength, dwTransferType, strFileTitle, nContentType));
  }

  /********************************************************************/
  /*																	*/
  /* Function name : DownloadFile										*/
  /* Description   : Download a file by file name 					*/
  /*																	*/
  /// *****************************************************************
  void downloadFile1(String lpszFileName, int dwTransferType) {
    String strCurrentDirectory = '';
    String strLocalName =
        FileUtils.appendPaths(globalPlayer.strLocalPath, lpszFileName);

    downloadFile('$strCurrentDirectory/$lpszFileName', '', -1, BigInt.zero,
        dwTransferType, strLocalName);
  }

  void downloadPreDataFile(String lpszFileName, BigInt dwFileLength,
      [String? lpszDestination]) {
    //AddTraceLine(2, '[%d] Downloading File: "%s"', wxGetProcessId(), lpszFileName);

    //m_WorkQueue.InsertWorkItem(new CTransferWorkItem((_nTaskAction == 0 ? 0 : dwSyncContent), 0, strRemoteFile, strLocalFile, dwFileLength, 0, '', -1));
  }

  /********************************************************************/
  /*																	*/
  /* Function name : UploadFile										*/
  /* Description   : Upload a file									*/
  /*																	*/
  /// *****************************************************************
  void uploadFile(String lpszFileName, String lpszDestination,
      String strFileTitle, int nContentType) {
    //m_WorkQueue.InsertWorkItem(new CTransferWorkItem((_nTaskAction == 0 ? 0 : dwSyncContent), 1, strRemoteFile, strLocalFile, 0, 0, strFileTitle, nContentType));
  }

  int getFileCount() {
    int nCount = 0;
    for (var iter in _fileListImpl.fileList) {
      if (iter.fileStatus == FileItemStatus.download) {
        // || iter.status == FileItemStatus.REMOVE
        nCount++;
      }
    }
    //return _fileListImpl.m_lstFileInfo.size();
    return nCount;
  }

  Future<bool> getFileListViaHTTP(String strRequest) async {
    if (strRequest.isEmpty) {
      return false;
    }

    String strGetFileListHttpLink = AppGlobal.cmsUrl;
    strGetFileListHttpLink = fADDSLASH(strGetFileListHttpLink);
    strGetFileListHttpLink += cmsGETFILELISTURL;
    strGetFileListHttpLink = Utils.addCMSParam(strGetFileListHttpLink);

    String strResult = '';
    var httpResult = await PlayerLogFile.httpPostAction(
        strGetFileListHttpLink, strRequest, 'application/xml; charset=utf-8');
    if (httpResult.status) {
      strResult = httpResult.result ?? '';
      if (strResult.length > 9 && !strResult.equalsIgnoreCase('Not Found')) {
        //_fileListImpl.m_bGenSitePlaylist = GetSitePlaylistHttpLink.isEmpty ? false : true;
        _fileListImpl.bGenSitePlaylist = false;
        int nEventDisplay = -1;
        var fileListResult = _fileListImpl.loadXml(strResult);
        if (fileListResult.status) {
          nEventDisplay = fileListResult.nEventDisplay ?? -1;
          /*if (fileListResult.arrSitePlaylist != null) {
            if (fileListResult.arrSitePlaylist!.isNotEmpty) {
              if (await getSitePlaylistViaWebApi(
                  fileListResult.arrSitePlaylist!)) {
                findNeedRemoveFiles(fileListResult.arrSitePlaylist!);
              }
            } else if (fileListResult.arrSitePlaylist!.isNotEmpty) {
              findNeedRemoveFiles(fileListResult.arrSitePlaylist!);
            }
          }*/
          if (fileListResult.arrSitePlaylist != null &&
              fileListResult.arrSitePlaylist!.isNotEmpty) {
            findNeedRemoveFiles(fileListResult.arrSitePlaylist!);
          }

          /*if (fileListResult.arrContentList != null &&
              fileListResult.arrContentList!.isNotEmpty) {
            if (!await getContentListViaWebApi(
                fileListResult.arrContentList!)) {
              return false;
            }
          }*/

          //Get event display by webapi
          if (AppGlobal.getEventDisplay && nEventDisplay >= 0) {
            if (!await getEventDisplayViaWebApi()) {
              return false;
            }
          }

          return true;
        } else {
          logE('GetFileListViaHTTP - Load XML failure!', syncTag);
        }
      }
    } else {
      logE('GetFileListViaHTTP; HTTP Get failure!', syncTag);
    }

    return false;
  }

  Future<bool> getSitePlaylistViaWebApi(List<String> arrSitePlaylist) async {
    if (arrSitePlaylist.isNotEmpty) {
      String strTempPath =
          await PlayerPathService.getLocalPath(cSITEPLAYLIST, true);
      String strSiteDataLocalPath =
          await PlayerPathService.getLocalPath(cDCMSITEDATATYPE);

      String strSitePlaylists = arrSitePlaylist.join(',');

      logI(
          '''Get Site Playlists for '${globalPlayer.strName}' successfully; Site Playlists: '$strSitePlaylists'!''',
          syncTag);

      String strResult = '';
      String strRequest;
      var getSitePlaylistHttpLink = AppGlobal.cmsUrl;
      getSitePlaylistHttpLink = fADDSLASH(getSitePlaylistHttpLink);
      getSitePlaylistHttpLink += cmsDAILYLISTURL;
      strRequest = 'o=$strSitePlaylists&d=$nSyncPeriod';
      String strLink =
          '$getSitePlaylistHttpLink?${Utils.urlEscape(strRequest)}';
      strLink = Utils.addCMSParam(strLink, true);
      var result = await PlayerLogFile.httpPostAction(strLink, '');
      if (result.status) {
        strResult = result.result ?? '';
        XmlFilePro file = XmlFilePro('AHMessage', null); //szPassword
        if (file.loadXml(strResult)) {
          // file header info
          String sXmlHeader = file.getSignature();
          if (sXmlHeader == lpszMessageSignature) {
            logI('''Site Playlist '$strResult' is invalid format!''', syncTag);
            return false;
          }

          XmlItem? pMessageItem = file.getItem('MessageItem');
          while (pMessageItem != null) {
            DateTime? dtDate = pMessageItem.getItemValueD('m_dtStartTime');
            String strDate = dtDate == null
                ? 'default'
                : DateFormat('yyyyMMdd').format(dtDate);
            String strSitePlaylist = pMessageItem.getItemValue('m_strAHName');
            String strRemoteFile = '$strSitePlaylist/$strDate.xml';
            String strShortPath = path.join(strSitePlaylist, '$strDate.xml');
            String strSitePlaylistPath =
                FileUtils.appendPaths(strTempPath, strSitePlaylist);
            FileUtils.makeSureDirectoryPathExists(strSitePlaylistPath);
            String strRemoteName = strRemoteFile;
            String strLocalName = path.join(strTempPath, strShortPath);

            {
              //save as site playlist xml file
              XmlFilePro fileLocal = XmlFilePro('AHMessage', null);
              XmlItem? pMessageItemLocal = fileLocal.addItem('MessageItem');
              if (pMessageItemLocal != null) {
                pMessageItemLocal.copy(pMessageItem, false);
              }
              fileLocal.setSignature(lpszMessageSignature);
              fileLocal.save(strLocalName);
              fileLocal.close();
            }
            if (!await addLocalTempFile(strLocalName, strRemoteName,
                cSITEPLAYLIST, strShortPath, FileItemStatus.temporary)) {
              logI(
                  '''Generate Site Playlist xml file '$strSitePlaylist' failure!''',
                  syncTag);
              return false;
            }

            XmlItem? pXISibling = pMessageItem.getItem('m_ZoneData');
            while (pXISibling != null) {
              String strContent = pXISibling.getItemValue('m_strZoneFile');
              DateTime? dtFileModify =
                  pXISibling.getItemValueD('m_dtFileModify');
              BigInt dwFileSize = pXISibling.getItemValueI64('m_dwFileSize');

              FileInfoData pFileInfo = FileInfoData();
              pFileInfo.strFilePath =
                  path.join(strSiteDataLocalPath, strContent);
              pFileInfo.strFileTitle =
                  path.basenameWithoutExtension(pFileInfo.strFilePath!);
              pFileInfo.strDestFile = strContent;
              pFileInfo.strShortPath = FileUtils.fixPathSeparators(strContent);
              pFileInfo.dwFileSize = dwFileSize;
              pFileInfo.nContentType = cDCMSITEDATATYPE;
              if (dtFileModify != null) {
                pFileInfo.tmFileModify = dtFileModify;
              }
              pFileInfo.tmFileCreate = DateTime.now();

              _fileListImpl.addFileList(pData: pFileInfo);

              pXISibling = pXISibling.getSibling();
            }

            pMessageItem = pMessageItem.getSibling();
          }
        }
      } else {
        logE(
            '''Generate file list from Site Playlist '$strSitePlaylists' failure!''',
            syncTag);
        await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR,
            '''Generate file list from Site Playlist '$strSitePlaylists' failure!''');

        return false;
      }
    } else {
      logI('''No Site Playlist for Player '${globalPlayer.strName}'!''',
          syncTag);
    }

    return true;
  }

  Future<bool> getContentListViaWebApi(List<String> arrContentList) async {
    if (arrContentList.isNotEmpty) {
      //String strRemotePath = PlayerPathService.getServerPath(DIRECTPLAY_TYPE);
      String strTempPath =
          await PlayerPathService.getLocalPath(cDIRECTPLAYTYPE, true);

      String strContentLists = arrContentList.join(',');

      logI(
          '''Get Content Lists for '${globalPlayer.strName}' successfully; Content Lists: '$strContentLists'.''',
          syncTag);

      String strResult = '';
      String strRequest;
      strRequest = 'c=$strContentLists&p=${globalPlayer.strUniqueName}';
      String strLink = AppGlobal.cmsUrl;
      strLink = fADDSLASH(strLink);
      strLink += cmsCONTENTLISTURL;
      strLink += '?${Utils.urlEscape(strRequest)}';
      var httpResult = await PlayerLogFile.httpPostAction(strLink, '');
      if (httpResult.status) {
        strResult = httpResult.result ?? '';
        XmlFilePro file = XmlFilePro('AHMessage', null); //szPassword
        if (file.loadXml(strResult)) {
          // file header info
          String sXmlHeader = file.getSignature();
          if (sXmlHeader == lpszMessageSignature) {
            logI('''Content List '$strResult' is invalid format!''', syncTag);
            return false;
          }

          XmlItem? pMessageItem = file.getItem('MessageItem');
          while (pMessageItem != null) {
            String strContentList = pMessageItem.getItemValue('m_strAHName');
            String strRemoteFile = '$strContentList.xml';
            String strShortPath = '$strContentList.xml';
            String strRemoteName = '/$strRemoteFile';
            String strLocalName = path.join(strTempPath, strShortPath);

            {
              //save as Content List xml file
              XmlFilePro fileLocal = XmlFilePro('AHMessage', null);
              XmlItem? pMessageItemLocal = fileLocal.addItem('MessageItem');
              if (pMessageItemLocal != null) {
                pMessageItemLocal.copy(pMessageItem, false);
              }
              fileLocal.setSignature(lpszMessageSignature);
              fileLocal.save(strLocalName);
              fileLocal.close();
            }
            if (!await addLocalTempFile(strLocalName, strRemoteName,
                cDIRECTPLAYTYPE, strShortPath, FileItemStatus.temporary)) {
              logI(
                  '''Generate Content List xml file '$strContentList' failure!''',
                  syncTag);
              return false;
            }

            XmlItem? pXISibling = pMessageItem.getItem('m_ZoneData');
            while (pXISibling != null) {
              String strContent = pXISibling.getItemValue('m_strZoneFile');
              DateTime? dtFileModify =
                  pXISibling.getItemValueD('m_dtFileModify');
              BigInt dwFileSize = pXISibling.getItemValueI64('m_dwFileSize');
              int nZoneType = pXISibling.getItemValueI('m_nZoneType');
              if (nZoneType == cIMAGETYPE) {
                int nContentType = PlayerPathService.contentTypeManager
                    .getContentTypeByFileName(strContent);
                if (nContentType == cIMAGETYPE) {
                  nZoneType = cDCMSINGLEIMAGETYPE;
                }
              }

              //String strDataPath = PlayerPathService.getServerPath(nZoneType);
              String strDataPath =
                  await PlayerPathService.getLocalPath(nZoneType);

              FileInfoData pFileInfo = FileInfoData();
              pFileInfo.strFilePath = path.join(strDataPath, strContent);
              pFileInfo.strFileTitle =
                  path.basenameWithoutExtension(pFileInfo.strFilePath!);
              pFileInfo.strDestFile = strContent;
              pFileInfo.strShortPath = FileUtils.fixPathSeparators(strContent);
              pFileInfo.dwFileSize = dwFileSize;
              pFileInfo.nContentType = nZoneType;
              if (dtFileModify != null) {
                pFileInfo.tmFileModify = dtFileModify;
              }
              pFileInfo.tmFileCreate = DateTime.now();

              _fileListImpl.addFileList(pData: pFileInfo);

              pXISibling = pXISibling.getSibling();
            }

            pMessageItem = pMessageItem.getSibling();
          }
        }
      } else {
        logE(
            '''Generate file list from Content Lists '$strContentLists' failure!''',
            syncTag);
        await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR,
            '''Generate file list from Content Lists '$strContentLists' failure!''');

        return false;
      }
    } else {
      logI('''No Content Lists for Player '${globalPlayer.strName}'!''',
          syncTag);
    }

    return true;
  }

  //Get Event Display from Event system by webapi
  Future<bool> getEventDisplayViaWebApi() async {
    String strTempPath =
        await PlayerPathService.getLocalPath(cDCMROOMEVENTTYPE, true);
    String strLocalPath =
        await PlayerPathService.getLocalPath(cDCMROOMEVENTTYPE, false);
    String strLobbyTempPath =
        await PlayerPathService.getLocalPath(cDCMLOBBYTYPE, true);
    String strLobbyLocalPath =
        await PlayerPathService.getLocalPath(cDCMLOBBYTYPE, false);

    logI('''Get Event Display for player: '${globalPlayer.strName}'.''',
        syncTag);

    String strResult = '';
    String strRequest;
    DateTime dtStart = _dtStartFtpTime.add(const Duration(days: 1));
    strRequest =
        'p=${globalPlayer.strName}&d=$nSyncPeriod&ds=${DateFormat('yyyyMMdd').format(dtStart)}';
    String strLink = AppGlobal.cmsUrl;
    strLink = fADDSLASH(strLink);
    strLink += cmsEVENTDISPLAYURL;
    strLink += '?${Utils.urlEscape(strRequest)}';
    strLink += Utils.addCMSParam(strLink);
    var httpResult = await PlayerLogFile.httpPostAction(strLink, '');
    if (httpResult.status) {
      strResult = httpResult.result ?? '';
      XmlFilePro file = XmlFilePro('Events', null); //szPassword
      if (file.loadXml(strResult)) {
        List<String> arrRoomDate = [];
        XmlItem? pRoomDisplay = file.getItem('RoomDisplay');
        if (pRoomDisplay != null) {
          XmlItem? pEventItem = pRoomDisplay.getItem('Event');
          while (pEventItem != null) {
            String strDate = pEventItem.getItemValue('DateTime');
            arrRoomDate.add(strDate);
            String strEventDate = strDate;
            if (!strDate.equalsIgnoreCase('defaultXML')) {
              DateTime? date = pEventItem.getItemValueD('DateTime');
              if (date != null) {
                strEventDate = DateFormat('yyyyMMdd').format(date);
              }
            }
            String strRemoteFile = '$strEventDate.xml';
            String strShortPath = '$strEventDate.xml';
            String strRemoteName = strRemoteFile;
            String strLocalName = path.join(strTempPath, strShortPath);
            {
              //save as Content List xml file
              XmlFilePro fileLocal = XmlFilePro('Event', null);
              //XmlItem? pEventItemLocal = fileLocal.addItem('Event');
              //pEventItemLocal.Copy(pEventItem, false);
              fileLocal.root().copy(pEventItem, false);
              fileLocal.save(strLocalName);
              fileLocal.close();
            }

            if (!await addLocalTempFile(strLocalName, strRemoteName,
                cDCMROOMEVENTTYPE, strShortPath, FileItemStatus.temporary)) {
              logI(
                  '''Generate room display xml file date '$strEventDate' failure!''',
                  syncTag);
              return false;
            }

            XmlItem? pXIRoomSibling = pEventItem.getItem('Room');
            while (pXIRoomSibling != null) {
              XmlItem? pXISectionSibling = pXIRoomSibling.getItem('Section');
              while (pXISectionSibling != null) {
                XmlItem? pXIContents = pXISectionSibling.getItem('Contents');
                if (pXIContents != null) {
                  XmlItem? pXIContentSibling = pXIContents.getItem('Content');
                  while (pXIContentSibling != null) {
                    String strContent =
                        pXIContentSibling.getItemValue('fileName');
                    DateTime? dtFileModify =
                        pXIContentSibling.getItemValueD('fileModify');
                    BigInt dwFileSize =
                        pXIContentSibling.getItemValueI64('fileSize');
                    int nZoneType =
                        pXIContentSibling.getItemValueI('contentType');
                    if (nZoneType == cIMAGETYPE) {
                      int nContentType = PlayerPathService.contentTypeManager
                          .getContentTypeByFileName(strContent);
                      if (nContentType == cIMAGETYPE) {
                        nZoneType = cDCMSINGLEIMAGETYPE;
                      }
                    }

                    //String strDataPath = PlayerPathService.getServerPath(nZoneType);
                    String strDataPath =
                        await PlayerPathService.getLocalPath(nZoneType);

                    FileInfoData pFileInfo = FileInfoData();
                    pFileInfo.strFilePath = path.join(strDataPath, strContent);
                    pFileInfo.strFileTitle =
                        path.basenameWithoutExtension(pFileInfo.strFilePath!);
                    pFileInfo.strDestFile = strContent;
                    pFileInfo.strShortPath =
                        FileUtils.fixPathSeparators(strContent);
                    pFileInfo.dwFileSize = dwFileSize;
                    pFileInfo.nContentType = nZoneType;
                    if (dtFileModify != null) {
                      pFileInfo.tmFileModify = dtFileModify;
                    }
                    pFileInfo.tmFileCreate = DateTime.now();

                    _fileListImpl.addFileList(pData: pFileInfo);

                    pXIContentSibling = pXIContentSibling.getSibling();
                  }
                }

                pXISectionSibling = pXISectionSibling.getSibling();
              }

              pXIRoomSibling = pXIRoomSibling.getSibling();
            }

            pEventItem = pEventItem.getSibling();
          }
        }
        DateTime dtDate = dtStart;
        for (int i = 0; i < nSyncPeriod; i++) {
          String strEventDate = DateFormat('yyyyMMdd').format(dtDate);
          if (!arrRoomDate.contains(strEventDate)) {
            String strShortPath = '$strEventDate.xml';
            String strLocalName = path.join(strLocalPath, strShortPath);
            var dateFile = File(strLocalName);
            if (await dateFile.exists()) {
              await dateFile.delete();
            }
          }
          dtDate = dtDate.add(Duration(days: i + 1));
        }
        if (!arrRoomDate.contains('defaultXML')) {
          String strLocalName = path.join(strLocalPath, 'defaultXML.xml');
          var dxmlFile = File(strLocalName);
          if (await dxmlFile.exists()) {
            await dxmlFile.delete();
          }
        }
        arrRoomDate.clear();

        XmlItem? pLobbyDisplay = file.getItem('LobbyDisplay');
        if (pLobbyDisplay != null) {
          XmlItem? pEventItem = pLobbyDisplay.getItem('EventDate');
          while (pEventItem != null) {
            DateTime? date = pEventItem.getItemValueD('DateTime');
            if (date != null) {
              String strEventDate = DateFormat('yyyyMMdd').format(date);
              arrRoomDate.add(strEventDate);
              String strRemoteFile = '$strEventDate.xml';
              String strShortPath = '$strEventDate.xml';
              String strRemoteName = '/$strRemoteFile';
              String strLocalName = path.join(strLobbyTempPath, strShortPath);
              {
                //save as Content List xml file
                XmlFilePro fileLocal = XmlFilePro('EventDate', null);
                //XmlItem? pEventItemLocal = fileLocal.addItem('EventDate');
                //pEventItemLocal.Copy(pEventItem, false);
                fileLocal.root().copy(pEventItem, false);
                fileLocal.save(strLocalName);
                fileLocal.close();
              }

              if (!await addLocalTempFile(strLocalName, strRemoteName,
                  cDCMLOBBYTYPE, strShortPath, FileItemStatus.temporary)) {
                logI(
                    '''Generate lobby display xml file date '$strEventDate' failure.''',
                    syncTag);
                return false;
              }
            }
            pEventItem = pEventItem.getSibling();
          }
        }
        dtDate = dtStart;
        for (int i = 0; i < nSyncPeriod; i++) {
          String strEventDate = DateFormat('yyyyMMdd').format(dtDate);
          if (!arrRoomDate.contains(strEventDate)) {
            String strShortPath = '$strEventDate.xml';
            String strLocalName = path.join(strLobbyLocalPath, strShortPath);
            var dateFile = File(strLocalName);
            if (await dateFile.exists()) {
              await dateFile.delete();
            }
          }
          dtDate = dtDate.add(Duration(days: i + 1));
        }
      } else {
        logE(
            '''Event Display: Parse XML result for '${globalPlayer.strName}' failure!''',
            syncTag);
        await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR,
            '''Event Display: Parse XML result for '${globalPlayer.strName}' failure!''');

        return false;
      }
    } else {
      logE(
          '''Event Display: Generate file list for '${globalPlayer.strName}' failure!''',
          syncTag);
      await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR,
          '''Event Display: Generate file list for '${globalPlayer.strName}' failure!''');

      return false;
    }

    return true;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : DownloadDailySchedule       						*/
  /* Description   : Download all Daily Schedule        	*/
  /*																	*/
  /// *****************************************************************
  Future<bool> downloadDailySchedule() async {
    DailyScheduleData.clear();
    try {
      if ((dwSyncContent & cSyncDCMDATA) > 0) {
        bool bOK = false;
        await PlayerPathService.getLocalPath(cDCMMONTHTYPE, true);
        await PlayerPathService.getLocalPath(cDCMCALENDARTYPE, true);
        var result = await getChannelList(false);
        if (result.lstDailySchedule != null) {
          _lstDailySchedule.addAll(result.lstDailySchedule!);
        }

        DailyScheduleFile dailySchedule = DailyScheduleFile();
        if (_pTaskItem.dwJobStatus == FileTransferStatus.eTRANSFEREDCHANNEL) {
          logI('Retrieving calendar and playlist information via HTTP\n',
              syncTag);

          String strRequest =
              '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&nDays=$nSyncPeriod';
          String strResult = '';
          String strLink = AppGlobal.cmsUrl;
          strLink = fADDSLASH(strLink);
          strLink += '$cmsGETPLAYLISTURL?${Utils.urlEscape(strRequest)}';
          strLink = Utils.addCMSParam(strLink);
          var httpResult = await PlayerLogFile.httpPostAction(strLink, '');
          if (httpResult.status) {
            strResult = httpResult.result ?? '';
            if (strResult.length > 11 &&
                !strResult.equalsIgnoreCase('No Playlist')) {
              if (dailySchedule.loadXml(strResult)) {
                dailySchedule.saveDailySchedule();
                await PlayerTaskFile.writeTaskFile(
                    _pTaskItem, FileTransferStatus.eTRANSFEREDSCHEDULE);
                bOK = true;
              } else {
                logE('DownloadDailySchedule - Load XML failure!', syncTag);
              }
            } else {
              logE(
                  '''DownloadDailySchedule; Result: '$strResult'; please make sure channel mapping for the player!''',
                  syncTag);
            }
          } else {
            logE('DownloadDailySchedule; HTTP Get failure!', syncTag);
          }
        } else {
          bOK = dailySchedule.loadDailySchedule();
        }
        if (!bOK) {
          await PlayerLogFile.writeLogFile(
              cTRANSFEROTHERERR, 'Get calendar and playlist via HTTP failure!');
          return false;
        }

        if (_pTaskItem.dwJobStatus == FileTransferStatus.eTRANSFEREDSCHEDULE) {
          logI('Start Generate calendar xml file\n', syncTag);
          //clearScheduleLog();
          for (var it in _lstDailySchedule) {
            DailyScheduleData pData = it;
            await pData.copyMonthFile();
            if (!await pData.getEventList(dailySchedule)) {
              logE('''Generate calendar file '${pData.strMonth}' failure''');
              await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR,
                  '''Generate calendar file '${pData.strMonth}' failure''');
              return false;
              //AfxMessageBox('DownloadMonthSchedule - successfully!!!');
            } else {
              logI(
                  '''Generate calendar file '${pData.strMonth}' successfully''',
                  syncTag);

              await PlayerLogFile.writeLogFile(cTRANSFEROTHERMSG,
                  '''Generate calendar file '${pData.strMonth}' successfully''');
            }
          }
          await PlayerTaskFile.writeTaskFile(
              _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
        } else {
          DailyScheduleData.arrEvent = dailySchedule.getEventList();
        }
      }

      if ((dwSyncContent & cSyncDDEDATA) > 0 &&
          (dwSyncContent & cSyncDCMDATA) == 0) {
        //return DownloadDDEFile();
      }
    } catch (e, stack) {
      logE('DownloadDailySchedule: $e, stack: $stack', syncTag);

      return false;
    }

    return true;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : AddLocalTempFile	      				    		*/
  /* Description   : Add Temp file in local to download list         	*/
  /*																	*/
  /// *****************************************************************
  Future<bool> addLocalTempFile(String lpszPath, String lpszRemoteFile,
      int nContentType, String lpszShortPath, FileItemStatus nStatus) async {
    // find special file
    String strLocalPath = lpszPath;
    String strRemoteFile = lpszRemoteFile;

    bool bAdd = false;
    FileInfoData? pFileInfo =
        FileInfoUtils.loadFileInfo(strLocalPath, nContentType);
    if (pFileInfo != null) {
      pFileInfo.strDestFile = lpszShortPath;
      pFileInfo.strShortPath = strRemoteFile;
      pFileInfo.fileStatus = nStatus;
      pFileInfo.strMD5 = '';
      _fileListImpl.addFileList(pData: pFileInfo);

      bAdd = true;
    }

    return bAdd;
  }

  Future<bool> genDailyScheduleRoomEvent([bool bAutoDownload = false]) async {
    return await genDailyScheduleRoomEventHTTP(bAutoDownload);
  }

  Future<bool> genDailyScheduleRoomEventHTTP(
      [bool bAutoDownload = false]) async {
    String strMacAddress = globalPlayer.strUniqueName;
    if (strMacAddress.isEmpty) {
      strMacAddress = await Utils.getUniqueKey() ?? '';
    }
    if (_strSyncContent.isNotEmpty) {
      String strEventFile = _strSyncContent;
      String strMessageFile = _strSyncContent;
      String strOtherInfo = _pTaskItem.strOtherInfo;
      int uiSection = -1;
      var otherInfos = strOtherInfo.split(';');
      if (otherInfos.isNotEmpty) {
        String strRoomName = otherInfos[0];
        if (otherInfos.length > 1) {
          String strStartTime = otherInfos[1];
        }
        if (otherInfos.length > 2) {
          uiSection = int.tryParse(otherInfos[2]) ?? -1;
        }
      }
      DailyScheduleData pDailySchedule = DailyScheduleData();
      _lstDailySchedule.add(pDailySchedule);
      pDailySchedule.strMonth = strEventFile;
      if (uiSection != -1) {
        String strSec = '$uiSection';
        pDailySchedule.arrDay.add(strSec);
      }

      return true;
    } else {
      try {
        bool bLoad = false;
        String strRequest =
            'strUniqueName=$strMacAddress&strTask=${_pTaskItem.strJobItem}';
        String strResult = '';
        var eventHttpLink = AppGlobal.cmsUrl;
        eventHttpLink = fADDSLASH(eventHttpLink);
        eventHttpLink += cmsEVENTDISPLAYURL;
        eventHttpLink += ('?${Utils.urlEscape(strRequest)}');
        eventHttpLink = Utils.addCMSParam(eventHttpLink);
        var httpResutl = await PlayerLogFile.httpPostAction(eventHttpLink, '');
        if (httpResutl.status) {
          if (strResult.length > 13 &&
              !strResult.equalsIgnoreCase('No Room Event')) {
            XmlFilePro eventList = XmlFilePro('EventList');
            if (eventList.loadXml(strResult)) {
              String str = eventList.export();
              await PlayerLogFile.writeLogFile(99999, str);

              bLoad = true;
              int nEventDisplay =
                  eventList.root().getItemValueI('m_nEventDisplay');
              nSyncPeriod = nEventDisplay;
              XmlItem? pEvent = eventList.getItem('Event');
              if (pEvent != null) {
                while (pEvent != null) {
                  //std::vector<int> lstSection;
                  DailyScheduleData pDailySchedule = DailyScheduleData();
                  _lstDailySchedule.add(pDailySchedule);
                  String strEventFile = pEvent.getItemValue('m_dtEventDate');
                  pDailySchedule.strMonth = strEventFile;
                  XmlItem? pItem = pEvent.getItem('Item');
                  while (pItem != null) {
                    //int uiEventID = pItem.getItemValueI('m_uiEventID');
                    //lstSection.add(uiEventID);
                    pDailySchedule.arrDay
                        .add(pItem.getItemValue('m_uiEventID'));

                    pItem = pItem.getSibling();
                  }

                  pEvent = pEvent.getSibling();
                }
              }
            }
          }
        }

        return bLoad;
      } catch (_) {}
    }

    return false;
  }

  Future<bool> genDailyScheduleAppUpdate() async {
    String strRequest;
    strRequest =
        'strBatch=$_strSyncContent&OSVersion=${await Utils.getOSVersion()}';
    String strResult = '';
    String strLink = AppGlobal.cmsUrl;
    strLink = fADDSLASH(strLink);
    strLink += cmsAPPUPDATEURL;
    strLink += '?${Utils.urlEscape(strRequest)}'; //cmsAPPUPDATEURL
    strLink = Utils.addCMSParam(strLink);
    var result = await PlayerLogFile.httpPostAction(strLink, '');
    if (result.status) {
      strResult = result.result ?? '';
      if (strResult.length > 9 && !strResult.equalsIgnoreCase('Not Found')) {
        AppUpdateFile updateFile = AppUpdateFile();
        if (updateFile.loadXml(strResult)) {
          updateFile.setItemValue('strUniqueName', globalPlayer.strUniqueName);
          updateFile.setItemValue('strPlayerName', globalPlayer.strName);
          updateFile.setItemValue('strTask', _strBatch);
          updateFile.setItemValue('strBatch', _strSyncContent);
          updateFile.setItemValue('RootHttpLink', AppGlobal.cmsUrl);
          XmlItem? hItem = updateFile.getFirstUpdateItem();
          if (hItem != null) {
            XmlItem? hUpdateItem = updateFile.getFirstUpdateItem(hItem);
            while (hUpdateItem != null) {
              String strFile = updateFile.getUpdateItemSource(hUpdateItem);
              if (strFile.isEmpty) {
                continue;
              }

              FileInfoData pFileInfo = FileInfoData();
              pFileInfo.strFilePath = strFile;
              pFileInfo.strFileTitle = strFile;
              pFileInfo.strDestFile = strFile;
              pFileInfo.strShortPath = path.join(_strSyncContent, strFile);
              pFileInfo.strShortPath =
                  FileUtils.fixPathSeparators(pFileInfo.strShortPath);
              pFileInfo.dwFileSize =
                  updateFile.getUpdateItemFileSize(hUpdateItem);
              pFileInfo.nContentType = cDCMUPDATETYPE;
              pFileInfo.strMD5 = updateFile.getUpdateItemMD5(hUpdateItem);
              DateTime? dtFileModify =
                  updateFile.getUpdateLastModified(hUpdateItem);
              if (dtFileModify != null) {
                pFileInfo.tmFileModify = dtFileModify;
              }
              pFileInfo.tmFileCreate = fromOleDateTime(0.00);

              _fileListImpl.addFileList(pData: pFileInfo);

              hUpdateItem = updateFile.getNextUpdateItem(hUpdateItem);
            }

            String strUpdatePath = path.join(
                await PlayerPathService.getLocalPath(cDCMUPDATETYPE, true),
                'DCMUpdate.xml');
            if (updateFile.save(strUpdatePath)) {
              return _fileListImpl.addFileList(
                  tempFile: strUpdatePath, contentType: cDCMUPDATETYPE);
            }
          }
        }
      } else if (strResult.equalsIgnoreCase('Not Found')) {
        PlayLogPostService.updateAPUpdateLog(
            globalPlayer.strUniqueName,
            globalPlayer.strName,
            _strSyncContent,
            _strBatch,
            '''Package files: '$_strSyncContent' not found or OS version:'$nSyncPeriod' not match current player OS version: '${await Utils.getOSVersion()}'.''',
            0);
      }
      logE(
          '''Invalid DCM update file list or Batch:'$_strSyncContent' not found!''',
          syncTag);
    } else {
      logE(
          '''HTTP Get DCM update file list failure; Batch:'$_strSyncContent'!''',
          syncTag);
    }

    return false;
  }

  Future<bool> genDailyScheduleDCMPlayerLog() async {
    Directory dir = Directory(AppGlobal.logPath);
    List<FileInfoData> fileInfos = [];

    if (await dir.exists()) {
      await for (FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File &&
            path.basename(entity.path).startsWithIgnoreCase('dcmplayer') &&
            entity.path.endsWithIgnoreCase('.log')) {
          FileInfoData? fileInfo;
          var strFileTitle = path.basenameWithoutExtension(entity.path);
          if (strFileTitle.length < 12) {
            String strPath =
                path.join(path.dirname(entity.path), 'logupload-dcmplayer.log');
            await entity.copy(strPath);
            fileInfo =
                await FileInfoUtils.loadFile(File(strPath), cDCMPLAYERLOGTYPE);
          } else {
            fileInfo = await FileInfoUtils.loadFile(entity, cDCMPLAYERLOGTYPE);
          }
          //pFileInfo.strDestFile = 'dcmplayerlog/' + strFileName + '/' + ff.getFileName();
          //pFileInfo.strShortPath = 'dcmplayerlog/' + strFileName + '/' + ff.getFileName();
          //pFileInfo.strShortPath.Replace('\\', wxFileName::GetPathSeparator());
          if (fileInfo != null) {
            fileInfos.add(fileInfo);
          }
        }
      }

      return true;
    }

    return false;
  }

  Future<bool> genDailyScheduleDCMTransferLog() async {
    //String strFileName = globalPlayer.strUniqueName.isEmpty ? await Utils.getUniqueKey() ??'' : globalPlayer.strUniqueName;
    Directory dir = Directory(AppGlobal.ftpSettingPath);
    List<FileInfoData> fileInfos = [];

    if (await dir.exists()) {
      await for (FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File &&
            path.basename(entity.path).startsWithIgnoreCase('dcmtransfer') &&
            entity.path.endsWithIgnoreCase('.log')) {
          FileInfoData? fileInfo;
          var strFileTitle = path.basenameWithoutExtension(entity.path);
          if (strFileTitle.length < 12) {
            String strPath = path.join(
                path.dirname(entity.path), 'logupload-dcmtransfer.log');
            await entity.copy(strPath);
            fileInfo = await FileInfoUtils.loadFile(
                File(strPath), cDCMTRANSFERLOGTYPE);
          } else {
            fileInfo =
                await FileInfoUtils.loadFile(entity, cDCMTRANSFERLOGTYPE);
          }
          //fileInfo.strDestFile = 'dcmtransferlog/' + strFileName + '/' + ff.GetFileName();
          //fileInfo.strShortPath = 'dcmtransferlog/' + strFileName + '/' + ff.GetFileName();
          //fileInfo.strShortPath.Replace('\\', wxFileName::GetPathSeparator());
          if (fileInfo != null) {
            fileInfos.add(fileInfo);
          }
        }
      }

      return true;
    }

    return false;
  }

  Future<bool> genDailySchedule() async {
    await PlayerPathService.getLocalPath(cDCMMONTHTYPE, true);
    await PlayerPathService.getLocalPath(cDCMCALENDARTYPE, true);

    // playlist update
    if (dwSyncContent == cSyncPLAYLISTUPDATE) {
      //todo : implement playlist update

      return false;
    } else if (dwSyncContent == cSyncROOMEVENT) {
      // for Event System - room event
      if (await genDailyScheduleRoomEvent(
          (_pTaskItem.dwJobType == JobItemType.eAUTO))) {
        if (_pTaskItem.dwJobStatus.value <
            FileTransferStatus.eTRANSFEREDEVENT.value) {
          await PlayerTaskFile.writeTaskFile(
              _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
        }

        return true;
      }

      logE('Get room event file list failure', syncTag);
      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Get room event file list failure');

      return false;
    } else if (dwSyncContent == cSyncSITEPLAYLIST) {
      // for site playlist
      List<String> arrContent = [];
      arrContent.add(_strSyncContent);
      if (await genFileListViaHTTP(arrContent, cSITEPLAYLIST)) {
        //FindNeedRemoveFiles();
        if (_pTaskItem.dwJobStatus.value <
            FileTransferStatus.eTRANSFEREDEVENT.value) {
          await PlayerTaskFile.writeTaskFile(
              _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
        }

        return true;
      }

      return false;
    } else if (dwSyncContent == cSyncSITEPLAYLISTDEL) {
      // for site playlist
      List<String> arrContent = _strSyncContent.split(';');
      if (arrContent.isNotEmpty) {}

      return false;
    } else if (dwSyncContent == cSyncDCMUPDATE) {
      // for DCM Update
      if (_pTaskItem.nSyncPeriod != -1 &&
          _pTaskItem.nSyncPeriod != await Utils.getOSVersion()) {
        String strLog =
            '''Package files: '${_pTaskItem.strSyncContent}', OS version:'${_pTaskItem.nSyncPeriod}' not match current player OS version: '${await Utils.getOSVersion()}'.''';
        logI(strLog, syncTag);
        await PlayLogPostService.updateAPUpdateLog(globalPlayer.strUniqueName,
            globalPlayer.strName, _strSyncContent, _strBatch, strLog, 0);

        _pTaskItem.nRetryCount = _pTaskItem.nRetries;
        await PlayerTaskFile.writeTaskFile(
            _pTaskItem, FileTransferStatus.eTRANSFERFAILED);

        return false;
      }

      if (await genDailyScheduleAppUpdate()) {
        if (_pTaskItem.dwJobStatus.value <
            FileTransferStatus.eTRANSFEREDEVENT.value) {
          await PlayerTaskFile.writeTaskFile(
              _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
        }

        return true;
      }
      logE('Get DCM update file list failure', syncTag);

      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Get DCM Update file list failure');

      return false;
    } else if (dwSyncContent == cSyncDCMPLAYERLOG) {
      // for DCMPlayer log upload
      if (await genDailyScheduleDCMPlayerLog()) {
        if (_pTaskItem.dwJobStatus.value <
            FileTransferStatus.eTRANSFEREDEVENT.value) {
          await PlayerTaskFile.writeTaskFile(
              _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
        }

        return true;
      }

      logE('Generate DCMPlayer Log file list failure', syncTag);

      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Generate DCMPlayer Log file list failure');

      return false;
    } else if (dwSyncContent == cSyncDCMTRANSFERLOG) {
      // for DCMTransfer log upload
      if (await genDailyScheduleDCMTransferLog()) {
        if (_pTaskItem.dwJobStatus.value <
            FileTransferStatus.eTRANSFEREDEVENT.value) {
          await PlayerTaskFile.writeTaskFile(
              _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
        }

        return true;
      }
      logE('Generate DCMTransfer Log file list failure', syncTag);
      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Generate DCMTransfer Log file list failure');

      return false;
    } else {
      DateTime dtDate = DateTime.now();
      DailyScheduleData pData = DailyScheduleData();
      _lstDailySchedule.add(pData);

      //pData.strChannelName = strChannel;
      //pData.arrChannelName.add(strChannel);
      pData.strMonth = DateFormat('yyyyMM').format(dtDate);
      String strDay = '${dtDate.day}';
      //pData.arrDay.add(strDay);
      pData.arrDay.add(strDay);
      logI('Start Download calendar file\n', syncTag);

      await pData.copyMonthFile();
      if (_pTaskItem.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDSCHEDULE.value) {
        await PlayerTaskFile.writeTaskFile(
            _pTaskItem, FileTransferStatus.eTRANSFEREDSCHEDULE);
      }

      logI('Start Download Event file\n', syncTag);

      //todo : download event
      if (_pTaskItem.dwJobStatus.value <
          FileTransferStatus.eTRANSFEREDEVENT.value) {
        await PlayerTaskFile.writeTaskFile(
            _pTaskItem, FileTransferStatus.eTRANSFEREDEVENT);
      }

      return true;
    }
  }

  Future<void> findNeedRemoveFiles(List<String> arrSitePlaylist) async {
    String strBasePath = Utils.getBasePath(cSITEPLAYLIST);
    for (int j = 0; j < arrSitePlaylist.length; j++) {
      logI(
          '''Check site playlist need to delete for site '${arrSitePlaylist[j]}'; days: '$nSyncPeriod'.''',
          syncTag);

      DateTime dtDate = DateTime.now();
      for (int i = 0; i < nSyncPeriod + 1; i++) {
        String strDate = nSyncPeriod == i
            ? 'default'
            : DateFormat('yyyyMMdd').format(dtDate);
        String strFilePath = strBasePath;
        if (!arrSitePlaylist[j].equalsIgnoreCase('Site Playlist')) {
          strFilePath =
              path.join(strFilePath, arrSitePlaylist[j], '$strDate.xml');
        } else {
          strFilePath = path.join(strFilePath, '$strDate.xml');
        }
        if (await File(strFilePath).exists()) {
          String strContent =
              !arrSitePlaylist[j].equalsIgnoreCase('Site Playlist')
                  ? '${arrSitePlaylist[j]}\\$strDate.xml'
                  : '$strDate.xml';
          if (!_fileListImpl.fileInList(strContent, cSITEPLAYLIST)) {
            logI('''Found File '$strFilePath' need to delete''', syncTag);

            //wxRemoveFile(strFilePath);
            FileInfoData pFileInfo = FileInfoData();
            pFileInfo.strFilePath = strFilePath;
            pFileInfo.strFileTitle = path.basenameWithoutExtension(strFilePath);
            pFileInfo.strDestFile = strContent;
            pFileInfo.strShortPath = FileUtils.fixPathSeparators(strContent);
            pFileInfo.dwFileSize = BigInt.zero;
            pFileInfo.nContentType = cSITEPLAYLIST;
            pFileInfo.fileStatus = FileItemStatus.remove;
            pFileInfo.tmFileModify = dtDate;
            pFileInfo.tmFileCreate = dtDate;

            _fileListImpl.addFileList(pData: pFileInfo);
          }
        }
        dtDate = dtDate.add(const Duration(days: 1));
      }
    }
  }

  /********************************************************************/
/*																	*/
/* Function name : GenFileList  									*/
/* Description   : Generate schedule daily file list               	*/
/*																	*/
  /// *****************************************************************
  Future<bool> genFileList() async {
    logI('''call generate file list program: '$_strSyncContent'.''', syncTag);

    PlayerLogFile.nTotalBytesDownloaded = BigInt.zero;
    PlayerLogFile.nTotalBytesToDownload = BigInt.zero;
    PlayerLogFile.nFileDownloaded = 0;
    if (_pTaskItem.dwJobStatus == FileTransferStatus.eGENERATEDFILELIST) {
      await _fileListImpl.loadUnFilterFileList(_pTaskItem.strJobItem);
      await _fileListImpl.filterReplaceFile(_pTaskItem.bReplaceFile);
      await _fileListImpl.saveDownloadFileList(_pTaskItem.strJobItem);
      await PlayerTaskFile.writeTaskFile(
          _pTaskItem, FileTransferStatus.eFILTEREDFILELIST);
      _fileListImpl.calcTotalBytesToDownload();
      return true;
    }

    if (_pTaskItem.dwJobStatus == FileTransferStatus.eFILTEREDFILELIST) {
      if (await _fileListImpl.loadDownloadFileList(_pTaskItem.strJobItem)) {
        _fileListImpl.calcTotalBytesToDownload();
        return true;
      }
      return false;
    }

    if (_pTaskItem.dwJobStatus.value >
            FileTransferStatus.eFILTEREDFILELIST.value &&
        _pTaskItem.dwJobStatus.value <
            FileTransferStatus.eTRANSFEREDTEMPFILE.value) {
      await _fileListImpl.loadDownloadFileList(_pTaskItem.strJobItem);
      _fileListImpl.calcTotalBytesToDownload();
      await _fileListImpl.filterDownloadedFile();

      return true;
    }

    // prepare data download
    if (dwSyncContent == cSyncPREDATA) {
      //todo get pre data file list
      /*if(!getPreDataFileListViaFTP()) {
        return false;
      }

      await processFileList();*/

      return true;
    }

    // playlist update or dcm system update
    if (dwSyncContent == cSyncPLAYLISTUPDATE ||
        dwSyncContent == cSyncDCMUPDATE ||
        dwSyncContent == cSyncSITEPLAYLIST ||
        dwSyncContent == cSyncDCMPLAYERLOG ||
        dwSyncContent == cSyncDCMTRANSFERLOG) {
      await processFileList();

      return true;
    }

    //event system - room event
    if (dwSyncContent == cSyncROOMEVENT) {
      if (!await genRoomEventFileList()) {
        return false;
      }

      await processFileList();

      return true;
    }

    if (dwSyncContent == cSyncEVENTCONTENTLIST ||
        dwSyncContent == cSyncEVENTDATA ||
        dwSyncContent == cSyncAPCONTENTLIST) {
      logI('''Start to Generate file list for event: '$_strSyncContent'.''',
          syncTag);
      if (!await genFileListByDailySchedule()) {
        return false;
      }

      await processFileList();

      return true;
    }

    if ((dwSyncContent & cSyncDDEDATA) > 0) {
      await PlayerPathService.getLocalPath(cDCMCONTENTLISTXMLTYPE, true);
      await PlayerPathService.getLocalPath(cDCMCONTENTLISTDATATYPE, true);
    }

    if ((dwSyncContent & cSyncDDEDATA) > 0 &&
        (dwSyncContent & cSyncDCMDATA) == 0) {
      //todo get dde file list
      /*if (!genDDEFileList()) {
        String str;
        str = 'Generate file list for DDE Content '%s' failure!') % _strSyncContent;

        logE(str);

        PlayerLogFile.writeLogFile(cTRANSFEROTHERERR, str);
        return false;
      }
      if (!GetDDEOthersFileListViaFTP()) {
        return false;
      }*/
      return false;
    } else {
      if (!await genFileListByDailySchedule()) {
        return false;
      }
    }

    await processFileList();

    return true;
  }

  Future<void> processFileList() async {
    await _fileListImpl.saveUnFilterFileList(_pTaskItem.strJobItem);
    if (await PlayerTaskFile.writeTaskFile(
        _pTaskItem, FileTransferStatus.eGENERATEDFILELIST)) {
      await deleteTempFile();
    }
    if (!(dwSyncContent == cSyncDCMPLAYERLOG ||
        dwSyncContent == cSyncDCMTRANSFERLOG)) {
      await _fileListImpl.filterReplaceFile(_pTaskItem.bReplaceFile);
    }
    await _fileListImpl.saveDownloadFileList(_pTaskItem.strJobItem);
    await PlayerTaskFile.writeTaskFile(
        _pTaskItem, FileTransferStatus.eFILTEREDFILELIST);
    _fileListImpl.calcTotalBytesToDownload();
  }

  Future<bool> isOverMaximumLimitSize() async {
    if (_pTaskItem.nMaximumLimit == 0) {
      logI('maximum limit size: 0 MB; Ignore maximum limit size check!',
          syncTag);
      return false;
    }

    if (PlayerLogFile.nTotalBytesToDownload >
        BigInt.from(_pTaskItem.nMaximumLimit * 1024 * 1024)) {
      await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR,
          'Total Size: ${FileUtils.formatBytesToMb(PlayerLogFile.nTotalBytesToDownload)}MB over maximum limit size: ${_pTaskItem.nMaximumLimit}MB');
      logE(
          'Total Size: ${FileUtils.formatBytesToMb(PlayerLogFile.nTotalBytesToDownload)}MB over maximum limit size: ${_pTaskItem.nMaximumLimit}MB',
          syncTag);

      return true;
    }

    logI(
        'Doanload Total Size: ${FileUtils.formatBytesToMb(PlayerLogFile.nTotalBytesToDownload)}MB; maximum limit size: ${_pTaskItem.nMaximumLimit}MB',
        syncTag);

    return false;
  }

  Future<bool> genFileListByDailySchedule() async {
    int syncContent = dwSyncContent;

    String strRequest = PlayerTaskFile.genHTTPRequest(
        DailyScheduleData.arrEvent,
        cDCMDAYTYPE,
        nSyncPeriod,
        syncContent,
        _pTaskItem.strJobItem);
    if (!await getFileListViaHTTP(strRequest)) {
      logE(
          '''GenFileListByDailySchedule: '$strRequest'; Get file list failure!''',
          syncTag);

      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Get file list via HTTP failure!');

      return false;
    }

    return true;
  }

  Future<bool> genFileListViaHTTP(List<String> arrContent, int type) async {
    int syncContent = dwSyncContent;
    String strRequest = PlayerTaskFile.genHTTPRequest(
        arrContent, type, nSyncPeriod, syncContent, _pTaskItem.strJobItem);
    if (!await getFileListViaHTTP(strRequest)) {
      logE('''GenFileListViaHTTP: '$strRequest'; Get file list failure!''',
          syncTag);
      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Get file list via HTTP failure!');

      return false;
    }

    return true;
  }

  Future<bool> genRoomEventFileList() async {
    String strHeader =
        '''<?xml version="1.0" encoding="UTF-8"?><ContentList ContentType="$cDCMROOMEVENTTYPE" FtpPeriod="$nSyncPeriod" FtpContent="$dwSyncContent" 
  strUniqueName="${globalPlayer.strUniqueName}" strPlayer="${globalPlayer.strName}" strTask="${_pTaskItem.strJobItem}">''';
    String strRequest = strHeader;
    for (var it in _lstDailySchedule) {
      DailyScheduleData pData = it;

      String strDayItem = '<Content Name="${pData.strMonth}">';
      strRequest += strDayItem;
      for (int i = 0; i < pData.arrDay.length; i++) {
        String strContent = pData.arrDay[i];
        String strContentItem = '<Item Value="$strContent" />';
        strRequest += strContentItem;
      }
      strRequest += '</Content>';
    }
    strRequest += '</ContentList>';

    if (!await getFileListViaHTTP(strRequest)) {
      logE('''GenRoomEventFileList: '$strRequest'; Get file list failure!''',
          syncTag);
      await PlayerLogFile.writeLogFile(
          cTRANSFEROTHERERR, 'Get file list via HTTP failure!');

      return false;
    }

    return true;
  }

  Future<void> deleteTempFile() async {
    int i = 0;
    if (dwSyncContent == cSyncDDEDATA) {
      // && (!(dwSyncContent & cSyncDCMDATA)) && (dwSyncContent != cSyncEVENT_CONTENTLIST) && (dwSyncContent != cSyncEVENTDATA)
      List<String> arrDDE = _strSyncContent.split(';');
      for (i = 0; i < arrDDE.length; i++) {
        String strDDE = arrDDE[i];
        String strFtpSettingFile =
            path.join(AppGlobal.ftpSettingPath, 'contentlist');
        strFtpSettingFile = path.join(strFtpSettingFile, '$strDDE.dat');
        var ddeFile = File(strFtpSettingFile);
        if (await ddeFile.exists()) {
          await ddeFile.delete();
        }
      }
    } else {
      if ((dwSyncContent & cSyncDCMDATA) > 0 ||
          dwSyncContent == cSyncEVENTCONTENTLIST ||
          dwSyncContent == cSyncEVENTDATA ||
          dwSyncContent == cSyncAPCONTENTLIST) {
        for (i = 0; i < DailyScheduleData.arrEvent.length; i++) {
          String strFtpSettingFile =
              path.join(AppGlobal.ftpSettingPath, 'DailySchedule');
          strFtpSettingFile = path.join(
              strFtpSettingFile, '${DailyScheduleData.arrEvent[i]}.dat');
          var eventFile = File(strFtpSettingFile);
          if (await eventFile.exists()) {
            await eventFile.delete();
          }
        }
        for (i = 0; i < DailyScheduleData.arrDCMFile.length; i++) {
          String strFtpSettingFile =
              path.join(AppGlobal.ftpSettingPath, 'DCMFile');
          strFtpSettingFile = path.join(
              strFtpSettingFile, '${DailyScheduleData.arrDCMFile[i]}.dat');
          var dcmFile = File(strFtpSettingFile);
          if (await dcmFile.exists()) {
            await dcmFile.delete();
          }
        }
      }
      if ((dwSyncContent & cSyncDDEDATA) > 0) {
        for (i = 0; i < DailyScheduleData.arrContentList.length; i++) {
          String strFtpSettingFile = path.join(AppGlobal.ftpSettingPath,
              'contentlist', '${DailyScheduleData.arrContentList[i]}.dat');
          var clFile = File(strFtpSettingFile);
          if (await clFile.exists()) {
            await clFile.delete();
          }
        }
      }
    }
    if ((dwSyncContent & cSyncPLAYLISTUPDATE) > 0) {
      String strFtpSettingFile = path.join(AppGlobal.ftpSettingPath, 'Playlist',
          '${globalPlayer.strUniqueName.isEmpty ? await Utils.getUniqueKey() ?? '' : globalPlayer.strUniqueName}.dat');
      var plFile = File(strFtpSettingFile);
      if (await plFile.exists()) {
        await plFile.delete();
      }
    }
  }

  bool isNoDownloadButScheduleChange() {
    if (getFileCount() == 0) {
      for (var it in _lstDailySchedule) {
        DailyScheduleData pData = it;
        if (pData.isTodayInclude()) {
          return (!pData.strTodayEventNew
              .equalsIgnoreCase(pData.strTodayEventOld));
        }
      }
    }

    return false;
  }

  Future<bool> isDownloadEventExisted() async {
    for (int i = 0; i < DailyScheduleData.arrEvent.length; i++) {
      String strFtpSettingFile =
          path.join(AppGlobal.dayPath, '${DailyScheduleData.arrEvent[i]}.xml');
      if (!await File(strFtpSettingFile).exists()) {
        String str = '''PlayList '$strFtpSettingFile' not exist in player!''';
        logE(str, syncTag);
        await PlayerLogFile.writeLogFile(cTRANSFEROTHERERR, str);
        return false;
      }
    }

    return true;
  }

/********************************************************************/
/*																	*/
/* Function name : GetChannelByDate									*/
/* Description   : Get channel Name by Date                        	*/
/*																	*/
  /// *****************************************************************
  bool getChannelByDate(DateTime dtDate, String strChannel) {
    for (var iter in _lstChannelPlayer) {
      ChannelPlayerData pData = iter;
      if (dtDate.compareTo(pData.startDate!) >= 0) {
        if (isDCMInvalidTime(pData.endDate)) {
          strChannel = pData.channelName;
          return true;
        } else {
          if (dtDate.compareTo(pData.endDate!) <= 0) {
            strChannel = pData.channelName;
            return true;
          }
        }
      }
    }

    return false;
  }

  List<String> getChannelListByDate(
      DateTime dtDate, DailyScheduleFile dailySchedule) {
    //bool bExisted = false;
    List<String> arrChannel = [];
    for (var iter in _lstChannelPlayer) {
      ChannelPlayerData pData = iter;

      if (dtDate.compareTo(pData.startDate!) >= 0) {
        if (isDCMInvalidTime(pData.endDate)) {
          logI(
              '''Date: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtDate)}'; Output: '${pData.output}'; Channel Name: '${pData.channelName}'\n''',
              syncTag);

          dailySchedule.addSchedule(dtDate, pData.channelName, pData.output);
          arrChannel.add(pData.channelName);
          //bExisted = true;
          //return true;
        } else {
          if (dtDate.compareTo(pData.endDate!) <= 0) {
            logI(
                '''Date: '${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtDate)}'; Output: '${pData.output}'; Channel Name: '${pData.channelName}'\n''',
                syncTag);
            dailySchedule.addSchedule(dtDate, pData.channelName, pData.output);
            arrChannel.add(pData.channelName);
            //bExisted = true;
            //return true;
          }
        }
      }
    }
    return arrChannel;
  }

  Future<
          ({
            DailyScheduleFile? dailySchedule,
            List<DailyScheduleData>? lstDailySchedule
          })>
      getChannelList(bool isDailyScheduleFile,
          [bool bCreateDailySchedule = true]) async {
    await PlayerPathService.getExistedTempPath(cDCMCALENDARTYPE);
    DateTime dtCurr = _dtStartFtpTime;
    if (!isDailyScheduleFile) {
      List<DailyScheduleData> lstDailySchedule = [];
      for (int i = 0; i < nSyncPeriod; i++) {
        DateTime dtDate = dtCurr.add(Duration(days: i + 1));
        if (!addChannelDay(dtDate, lstDailySchedule)) {
          DailyScheduleData pData = DailyScheduleData();

          pData.strMonth = DateFormat('yyyyMM').format(dtDate);
          pData.arrDay.add('${dtDate.day}');

          lstDailySchedule.add(pData);
        }
      }
      return (lstDailySchedule: lstDailySchedule, dailySchedule: null);
    } else {
      DailyScheduleFile dailySchedule = DailyScheduleFile();
      for (int i = 0; i < nSyncPeriod; i++) {
        DateTime dtDate = dtCurr.add(Duration(days: i + 1));
        List<String> arrChannel;
        if (bCreateDailySchedule) {
          arrChannel = getChannelListByDate(dtDate, dailySchedule);
          if (arrChannel.isEmpty) {
            return (lstDailySchedule: null, dailySchedule: null);
          }
        } else {
          arrChannel = dailySchedule!.getChannels(dtDate);
          if (arrChannel.isEmpty) {
            return (lstDailySchedule: null, dailySchedule: null);
          }
        }

        for (int j = 0; j < arrChannel.length; j++) {
          String strChannel = arrChannel[j];
          if (!addChannelDay(dtDate, _lstDailySchedule, strChannel)) {
            DailyScheduleData pData = DailyScheduleData();
            _lstDailySchedule.add(pData);

            pData.arrChannelName.add(strChannel);
            pData.strMonth = DateFormat('yyyyMM').format(dtDate);
            pData.arrDay.add('${dtDate.day}');
          }
        }
      }
      return (lstDailySchedule: null, dailySchedule: dailySchedule);
    }
  }

/********************************************************************/
/*																	*/
/* Function name : AddChannelDay									*/
/* Description   : Add Day to Daily Schedule                      	*/
/*																	*/
  /// *****************************************************************
  bool addChannelDay(DateTime dtDate, List<DailyScheduleData> lstDailySchedule,
      [String strChannel = '']) {
    var currMonth = DateFormat('yyyyMM').format(dtDate);
    for (var it in lstDailySchedule) {
      DailyScheduleData pData = it;

      if (pData.strMonth == currMonth) {
        if (strChannel.isNotEmpty &&
            !pData.arrChannelName.contains(strChannel)) {
          pData.arrChannelName.add(strChannel);
        }

        bool bExisted = false;
        String strDay = '${dtDate.day}';
        for (int i = 0; i < pData.arrDay.length; i++) {
          if (pData.arrDay[i] == strDay) {
            bExisted = true;
            break;
          }
        }
        if (!bExisted) {
          pData.arrDay.add(strDay);
        }

        return true;
      }
    }

    return false;
  }

/********************************************************************/
/*																	*/
/* Function name : Serialize										*/
/* Description   : Call this function to store/load the site data	*/
/*																	*/
  /// *****************************************************************
  bool serialize(String strFilename, bool bStoring) {
    if (bStoring) {
      XmlFilePro playerReg = XmlFilePro('PlayerFTPInformation');
      // Save the File information
      for (var iter in _lstChannelPlayer) {
        ChannelPlayerData pData = iter;

        XmlItem? xi = playerReg.addDataNode('ChannelItem', null);
        if (xi != null) {
          pData.writeToXML(xi);
        }
      }

      playerReg.setSignature(lpszSignature);

      // encrypt prior to setting checkout status and file info (so these are visible without decryption)
      // this simply fails if password is empty
      playerReg.encrypt(Encodes.cCONTENTFILECRYPTKEY);

      return playerReg.save(strFilename);
    } else {
      XmlFilePro file =
          XmlFilePro('PlayerFTPInformation', Encodes.cCONTENTFILECRYPTKEY);
      if (!file.open(strFilename, XfOpen.read, false)) {
        return false;
      }

      if (file.loadEx()) {
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == lpszSignature) {
          // get Player Channel information list
          XmlItem? pXISibling = file.getItem('ChannelItem');
          while (pXISibling != null) {
            ChannelPlayerData pData = ChannelPlayerData();
            // add Player Channel data to list
            _lstChannelPlayer.add(pData);

            // get Player channel Inforamtion data
            pData.getFromXML(pXISibling);

            pXISibling = pXISibling.getSibling();
          }

          return (_lstChannelPlayer.isNotEmpty);
        }
      }
      return false;
    }
  }
}
