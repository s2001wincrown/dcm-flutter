import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/download_file_info_data.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/download_file_list_impl.dart';
import 'package:dcm/backend/net/file_replace_service.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/xml_settings/contenttype_manager.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const String cFLSignature =
    'DCM FTP Manager Version 1.00 - Publish File Information List';
// ============================================================================
// 2. Data Models
// ============================================================================

class TempFileInfo {
  int nContentType;
  String strSourcePath;
  String strDestPath;
  int nPriorityFlag;

  TempFileInfo({
    required this.nContentType,
    required this.strSourcePath,
    required this.strDestPath,
    this.nPriorityFlag = 0,
  });
}

// ============================================================================
// 3. Service Implementation (Corresponds to CFTPPathImpl)
// ============================================================================

class PlayerPathService {
  // Singleton instance
  static final PlayerPathService _instance = PlayerPathService._internal();
  factory PlayerPathService() => _instance;
  PlayerPathService._internal();

  static final List<TempFileInfo> _tempFiles = [];
  static final List<FileInfoData> _lstFileInfo = [];
  bool _isLoaded = false;
  String _strBatch = "";

  bool bCopyTempFile = false;
  int nCopyCount = 0;

  static final ContentTypeManager contentTypeManager = ContentTypeManager();

  // Lock simulation (Dart is single-threaded for logic, but async IO needs care)
  // For complex concurrency, use Compute or Isolates, but for file lists, a simple list is usually fine
  // if accessed carefully in async methods.

  /// Initialize paths and load settings
  void _fixServerPaths() {
    // Replace $(HttpRoot)/ with actual root link
    if (AppGlobal.cmsUrl.isNotEmpty && !AppGlobal.cmsUrl.endsWith('/')) {
      AppGlobal.cmsUrl += '/';
    }
  }

  Future<void> init() async {
    contentTypeManager.loadContentTypes();
    await loadTempPath();
  }

  /********************************************************************/
  /*																	*/
  /* Function name : GetLocalPath 									*/
  /* Description   : Get Local Path for data.                      	*/
  /// Get Local Path for a specific content type
  /// [bIsTemp]: If true, returns a temporary subdirectory path
  /*																	*/
  /// *****************************************************************
  static Future<String> getLocalPath(int nContentType,
      [bool bIsTemp = false]) async {
    String strFilePath = '';
    int nPriorityFlag = 0;
    switch (nContentType) {
      case cDCMSINGLEIMAGETYPE:
        strFilePath = AppGlobal.imagePath;
        nPriorityFlag = 0;
        break;
      case cIMAGETYPE:
        strFilePath = AppGlobal.imageSettingPath;
        nPriorityFlag = 0;
        break;
      case cVIDEOTYPE:
        strFilePath = AppGlobal.vcdPath;
        nPriorityFlag = 0;
        break;
      case cPOWERPOINTTYPE:
        strFilePath = AppGlobal.ppPath;
        nPriorityFlag = 0;
        break;
      case cTEXTTYPE:
        strFilePath = AppGlobal.textPath;
        nPriorityFlag = 0;
        break;
      case cTVCAPTURETYPE:
        //strFilePath = AppGlobal.t;
        nPriorityFlag = 0;
        break;
      case cQUEUETYPE:
      case cWEBPAGETYPE:
        strFilePath = AppGlobal.webPath;
        nPriorityFlag = 0;
        break;
      case cFLASHTYPE:
        strFilePath = AppGlobal.flashPath;
        nPriorityFlag = 0;
        break;
      case cCLOCKTYPE:
        strFilePath = AppGlobal.clockPath;
        nPriorityFlag = 0;
        break;
      case cWEATHERTYPE:
        strFilePath = AppGlobal.weatherPath;
        nPriorityFlag = 0;
        break;
      case cDCMMONTHTYPE:
        strFilePath = AppGlobal.monthPath;
        nPriorityFlag = 3;
        break;
      case cDCMCALENDARTYPE:
        strFilePath = AppGlobal.calendarPath;
        nPriorityFlag = 3;
        break;
      case cDCMDAYTYPE:
      case cDCMAHPLAYLISTTYPE:
        strFilePath = AppGlobal.dayPath;
        nPriorityFlag = 2;
        break;
      /*case DCM_AHPLAYLIST_TYPE:
        strFilePath = strAHPlaylistPathD;
        nPriorityFlag = 2;
        break;*/
      case cDCMFILETYPE:
        strFilePath = AppGlobal.openPath;
        nPriorityFlag = 1;
        break;
      case cDCMSETTINGTYPE:
        strFilePath = AppGlobal.settingPath;
        nPriorityFlag = 4;
        break;
      case cDCMLAYOUTTYPE:
        strFilePath = AppGlobal.layoutImagePath;
        nPriorityFlag = 0;
        break;
      case cDCMGRAPHICSTYPE:
        strFilePath = AppGlobal.graphicsPath;
        nPriorityFlag = 0;
        break;
      case cDCMSKINSTYPE:
        strFilePath = AppGlobal.skinsPath;
        nPriorityFlag = 0;
        break;
      case cDCMAHMESSAGETYPE:
        strFilePath = AppGlobal.messagePath;
        nPriorityFlag = 0;
        break;
      case cDDETYPE:
      case cDCMCONTENTLISTXMLTYPE:
        strFilePath = AppGlobal.ddeXmlPath;
        nPriorityFlag = 0;
        break;
      case cDCMDDEOTHERTYPE:
        strFilePath = AppGlobal.ddeOthersPath;
        nPriorityFlag = 0;
        break;
      case cDIRECTPLAYTYPE:
        strFilePath = AppGlobal.contentListPath;
        nPriorityFlag = 0;
        break;
      case cLINKAGETYPE:
        strFilePath = AppGlobal.linkagePath;
        nPriorityFlag = 0;
        break;
      case cDCMCONTENTLISTDATATYPE:
        strFilePath = AppGlobal.ddeDataPath;
        nPriorityFlag = 0;
        break;
      case cDCMPREDATATYPE:
        strFilePath = AppGlobal.preDataPath;
        nPriorityFlag = 999;
        break;
      //for Event system - room event
      case cDCMROOMTYPE:
        strFilePath = AppGlobal.roomPath;
        nPriorityFlag = 1;
        break;
      case cDCMROOMEVENTTYPE:
        strFilePath = AppGlobal.roomEventPath;
        nPriorityFlag = 1;
        break;
      case cDCMLOBBYTYPE:
        strFilePath = AppGlobal.lobbyPath;
        nPriorityFlag = 1;
        break;
      case cDCMDYNAMICDATATYPE:
        strFilePath = AppGlobal.dynamicDataPath; //DynamicDataDestination;
        nPriorityFlag = 0;
        break;
      case cDCMRLTCONTENTTYPE:
        strFilePath = AppGlobal.rltContentPath;
        nPriorityFlag = 0;
        break;
      case cDCMSITEDATATYPE:
        strFilePath = AppGlobal.siteContentPath;
        break;
      case cSITEPLAYLIST:
        strFilePath = p.join(AppGlobal.siteContentPath, 'SitePlaylist');
        break;

      case cDCMUPDATETYPE:
        strFilePath = p.join(AppGlobal.updateFilePath, 'APUpdate');
        break;
      default:
        strFilePath = p.join(AppGlobal.cscPath, defaultDataPath); //strCSCPath;
        break;
    }

    await FileUtils.validFilePath(strFilePath, '', false);
    if (!bIsTemp || nContentType == cDCMPREDATATYPE) {
      // || nContentType == DCM_AHMESSAGE_TYPE
      return strFilePath;
    }

    String? strTempPath = await getExistedTempPath(nContentType);
    if (strTempPath == null) {
      String strTempPath = const Uuid().toString(); //DCMMisc::GenerateGUID();
      String strDest = strFilePath;
      strFilePath = p.join(strFilePath, strTempPath);
      if (await FileUtils.makeSureDirectoryPathExists(strFilePath)) {
        addTempFile(nContentType, strFilePath, strDest, nPriorityFlag);

        saveTempPath();
      }
    } else {
      strFilePath = strTempPath;
    }

    return strFilePath;
  }

  /// Add a temporary file tracking record
  static void addTempFile(
      int contentType, String source, String dest, int priority) {
    _tempFiles.add(TempFileInfo(
      nContentType: contentType,
      strSourcePath: source,
      strDestPath: dest,
      nPriorityFlag: priority,
    ));
    saveTempPath();
  }

  /// Check if a temp path exists for the content type
  static Future<String?> getExistedTempPath(int contentType) async {
    for (var temp in _tempFiles) {
      if (temp.nContentType == contentType) {
        await FileUtils.makeSureDirectoryPathExists(temp.strSourcePath);

        // Ensure directory exists (async check usually not needed for string logic,
        // but in real usage you might want to verify Directory.exists)
        return temp.strSourcePath;
      }
    }
    return null;
  }

  void clear() {
    //SaveTempPath();
    removeFileList();
    _tempFiles.clear();
  }

  Future<void> reset() async {
    for (int i = _tempFiles.length - 1; i >= 0; i--) {
      FileUtils.deleteDirectory(_tempFiles[i].strSourcePath);
    }
    _tempFiles.clear();

    String strFileName = p.join(AppGlobal.ftpSettingPath, 'ftppathlog.xml');
    var tempFile = File(strFileName);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    strFileName = p.join(AppGlobal.appDataPath, 'ContentTypes.xml');
    tempFile = File(strFileName);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    strFileName = p.join(AppGlobal.appDataPath, 'FTPManager.xml');
    tempFile = File(strFileName);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }

  void removeFileList() {
    _lstFileInfo.clear();
  }

  Future<void> copyFileFinish([bool bSuccess = true]) async {
//((int)_lstFileInfo.length > 0);
    if (bSuccess) {
      DownloadFileListImpl downloadFileList = DownloadFileListImpl();
      if (await downloadFileList.loadDownloadFileList(_strBatch)) {
        //_lstFileInfo.length > 0 &&
        downloadFileList.saveToFileList(_lstFileInfo);
      }
    }
    removeFileList();

    String strFileName =
        p.join(AppGlobal.ftpSettingPath, 'Filelog', '$_strBatch.xml');
    var listFile = File(strFileName);
    if (await listFile.exists()) {
      listFile.delete();
    }
    bCopyTempFile = false;
  }

  int getDownloadFileCount() {
    int nFileCount = 0;
    nFileCount = _lstFileInfo.length;

    return nFileCount;
  }

  bool isPlayListUpdated() {
    return bCopyTempFile;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : CreateLocalDirectory								*/
  /* Description   : Create directory tree.							*/
  /*																	*/
  ///********************************************************************/
  Future<bool> createLocalDirectory(
      List<String> strFileNameArray, int nContentType) async {
    bool bResult = true;
    for (int i = 0; i < strFileNameArray.length; i++) {
      String strLocalPath =
          p.join(await getLocalPath(nContentType), strFileNameArray[i]);
      String strLocalTempPath =
          p.join(await getLocalPath(nContentType, true), strFileNameArray[i]);
      bResult = await FileUtils.makeSureDirectoryPathExists(strLocalPath);
      bResult = await FileUtils.makeSureDirectoryPathExists(strLocalTempPath);
    }

    return bResult;
  }

  Future<bool> tryToCopyTempFile() async {
    logI('''Retry:'$nCopyCount'; Start Copy tempory file to playlist\n''');
    //bCopyTempFile = true;

    await resetModifyTime();

    bool bSuccess1 = (await copyTempFiles(0) && await copyPreData());
    bool bSuccess2 = await copyTempFiles(1);
    bool bSuccess3 = await copyTempFiles(2);
    bool bSuccess4 = await copyTempFiles(3);
    bool bSuccess5 = await copyTempFiles(4);
    bool bSuccess6 = await copyTempFiles(5);
    bool bSuccess7 = await copyTempFiles(6);
    bool bSuccess8 = true;
    String strTempDefaEvent = p.join(AppGlobal.tempPath, 'DefaultEvent.ini');
    if (await File(strTempDefaEvent).exists()) {
      bSuccess8 = await copyTempFile(
          strTempDefaEvent, p.join(AppGlobal.settingPath, 'DefaultEvent.ini'));
    }
    bool bSuccess9 = await removeFiles();

    if (bSuccess1 &&
        bSuccess2 &&
        bSuccess3 &&
        bSuccess4 &&
        bSuccess5 &&
        bSuccess6 &&
        bSuccess7 &&
        bSuccess8 &&
        bSuccess9) {
      logI('Copy tempory file to playlist successfully\n');
      removeFileList();
      nCopyCount = 0;
      //InterlockedExchange(&nCopyCount, 0);
      //InterlockedExchange(&bcopyTempFile, true);
      bCopyTempFile = true;

      return true;
    }
    //InterlockedIncrement(&nCopyCount);
    nCopyCount++;

    return false;
  }

  Future<bool> copyTempFiles(int nPriorityFlag) async {
    bool bAllSuccess = true;
    for (int i = _tempFiles.length - 1; i >= 0; i--) {
      if (_tempFiles[i].nPriorityFlag == nPriorityFlag) {
        if (_tempFiles[i].nContentType == cDCMMONTHTYPE ||
            _tempFiles[i].nContentType == cDCMCALENDARTYPE) {
          if (await copyTempFolder(
              _tempFiles[i].strSourcePath, _tempFiles[i].strDestPath)) {
            logI(
                '''Copy '${_tempFiles[i].strSourcePath}' to '${_tempFiles[i].strDestPath}' successfully''');
            PlayerLogFile.writeLogFile(cTRANSFEROTHERMSG,
                '''Update Schedule to '${_tempFiles[i].strDestPath}' successfully''');
          } else {
            logI(
                '''Copy '${_tempFiles[i].strSourcePath}' to '${_tempFiles[i].strDestPath}' failure''');
            bAllSuccess = false;
          }
        } else {
          for (int i = _lstFileInfo.length - 1; i >= 0; i--) {
            DownloadFileInfoData pData =
                _lstFileInfo[i] as DownloadFileInfoData;
            if (pData.needDelete()) {
              continue;
            }

            if (pData.nContentType == _tempFiles[i].nContentType) {
              if (!await copyTempFile(pData.strTempPath!, pData.strDestPath!)) {
                logI(
                    '''Copy '${pData.strTempPath}' to '${pData.strDestPath}' failure''');
                bAllSuccess = false;
              } else {
                logI(
                    '''Copy '${pData.strTempPath}' to '${pData.strDestPath}' successfully''');
                _lstFileInfo.removeAt(i);
              }
            }
          }
        }
      }
    }

    return bAllSuccess;
  }

  Future<bool> copyTempFile(String strSource, String strDest) async {
    String strLocalDirectory = p.dirname(strDest);
    if (strLocalDirectory.isNotEmpty) {
      FileUtils.makeSureDirectoryPathExists(strLocalDirectory);
    }

    try {
      await FileUtils.moveFile(File(strSource), strDest);
    } catch (e) {
      logE('''Error copy file '$strSource' to '$strDest': $e''');
      return false;
    }

    var md5File = File('$strSource.MD5');
    if (await md5File.exists()) {
      md5File.delete();
    }

    return true;
  }

  Future<bool> copyTempFileOnly(String strSource, String strDest) async {
    String strLocalDirectory = p.dirname(strDest);
    if (strLocalDirectory.isNotEmpty) {
      FileUtils.makeSureDirectoryPathExists(strLocalDirectory);
    }

    try {
      await File(strSource).copy(strDest);
    } catch (e) {
      logE('''Error copy file '$strSource' to '$strDest': $e''');
      return false;
    }

    var md5File = File('$strSource.MD5');
    if (await md5File.exists()) {
      md5File.delete();
    }

    return true;
  }

  Future<bool> removeFiles() async {
    bool bAllSuccess = true;
    for (int i = _lstFileInfo.length - 1; i >= 0; i--) {
      DownloadFileInfoData it = _lstFileInfo[i] as DownloadFileInfoData;
      if (it.needDelete()) {
        try {
          await File(it.strFilePath!).delete();
          _lstFileInfo.remove(it);
          logI('''Delete File '${it.strFilePath}' successfully.''');
        } catch (e) {
          logI('''Delete File '${it.strFilePath}' failure.''');
          bAllSuccess = false;
        }
      }
    }

    return bAllSuccess;
  }

  Future<bool> copyTempFolder(String strSource, String strDest) async {
    bool bSuccess =
        await _copyTempFolderRecursive(Directory(strSource), strDest);
    if (bSuccess) {
      await FileUtils.deleteDirectory(strSource);
    }

    return bSuccess;
  }

  Future<bool> _copyTempFolderRecursive(Directory dir, String strDest) async {
    bool bSuccess = true;
    if (await dir.exists()) {
      await for (FileSystemEntity entity in dir.list(recursive: false)) {
        String newPath = p.join(strDest, p.basename(entity.path));
        if (entity is Directory) {
          await FileUtils.makeSureDirectoryPathExists(newPath);
          await _copyTempFolderRecursive(entity, newPath);
        } else if (entity is File) {
          try {
            await FileUtils.moveFile(entity, newPath);
            logI('''Copy '${entity.path}' to '$newPath' successfully''');
          } catch (e) {
            logE('''copy '${entity.path}' to '$newPath' failure''');
            bSuccess = false;
          }
        }
      }
    }

    return bSuccess;
  }

  /// Validate Hash (MD5/SHA1)
  /// Corresponds to ValidHashData
  static Future<({bool status, String? strMd5})> validHashData(
      String filePath, FileInfoData pFileInfo) async {
    if ((AppGlobal.globalSetting & settingCHECKSUM) > 0) {
      File md5file = File('$filePath.MD5');
      if (await md5file.exists()) {
        try {
          String strMd5 = md5file.readAsStringSync();
          var hashResult = strMd5.split('||');
          if (hashResult.isNotEmpty &&
              hashResult[0].equalsIgnoreCase(pFileInfo.strMD5)) {
            return (status: true, strMd5: hashResult[1]);
          }
        } catch (e) {
          logE('Error reading MD5 file: $e');
        }
      }

      // Calculate MD5
      var bytes = await File(filePath).readAsBytes();
      var digest = md5.convert(bytes);
      String actualMd5 = digest.toString();

      return (
        status: actualMd5.equalsIgnoreCase(pFileInfo.strMD5),
        strMd5: actualMd5
      );
    }

    return (status: true, strMd5: null);
  }

  static Future<({bool status, String? strErrMsg})> validDownloadedFile(
      DownloadFileInfoData pFileInfo,
      [String? strTempFile]) async {
    String? strTempPath = strTempFile;
    if (strTempPath == null || strTempPath.isEmpty) {
      strTempPath = pFileInfo.strTempPath;
    }
    if (strTempPath == null || strTempPath.isEmpty) {
      return (status: false, strErrMsg: 'Invalid temp file path');
    }
    strTempPath =
        strTempPath.replaceAll(p.separator == '/' ? '\\' : '/', p.separator);
    if (isNotBlank(pFileInfo.strMD5)) {
      var hashResult = await validHashData(strTempPath, pFileInfo);
      if (!hashResult.status) {
        String strErrMsg =
            ''''${pFileInfo.strDestFile}' MD5: '${hashResult.strMd5}', Source file MD5: '${pFileInfo.strMD5}'; File integrity checks failure!''';
        logE(strErrMsg);
        if (await FileUtils.deleteFileEx(strTempPath, true)) {
          await File('$strTempPath.md5').delete();
        }

        return (status: false, strErrMsg: strErrMsg); //false;
      }
    } else {
      var dwFileSize = await FileUtils.getFileSize(strTempPath);
      if (dwFileSize <= BigInt.zero) {
        String strErrMsg =
            ''''$strTempPath' size: $dwFileSize, Source file size: ${pFileInfo.dwFileSize}; File integrity checks failure!''';
        logE(strErrMsg);
        if (await FileUtils.deleteFileEx(strTempPath, true)) {
          await File('$strTempPath.md5').delete();
        }

        return (status: false, strErrMsg: strErrMsg);
      } else {
        if (!pFileInfo.ignoreFileSize() && pFileInfo.dwFileSize > BigInt.zero) {
          if (pFileInfo.dwFileSize != dwFileSize) {
            String strErrMsg =
                ''''$strTempPath' size: $dwFileSize, Source file size: ${pFileInfo.dwFileSize}; File integrity checks failure!''';
            logE(strErrMsg);
            if (await FileUtils.deleteFileEx(strTempPath, true)) {
              await File('$strTempPath.md5').delete();
            }

            return (status: false, strErrMsg: strErrMsg);
          }
        }
      }
    }

    return (status: true, strErrMsg: null);
  }

  static bool isSameFile(FileInfoData pFileInfo1, FileInfoData pFileInfo2) {
    return ((pFileInfo1.strDestFile.equalsIgnoreCase(pFileInfo2.strDestFile)) &&
        pFileInfo2.nContentType == pFileInfo1.nContentType);
  }

  static bool isModified(FileInfoData pServer, FileInfoData pLocal) {
    if (isNotBlank(pServer.strMD5) && isNotBlank(pLocal.strMD5)) {
      if (pServer.strMD5!.equalsIgnoreCase(pLocal.strMD5)) {
        return false;
      }
    } else {
      if (pLocal.tmFileModify == pServer.tmFileModify &&
          (pLocal.dwFileSize == pServer.dwFileSize ||
              pServer.ignoreFileSize())) {
        return false;
      }
    }

    return true;
  }

  Future<void> resetModifyTime() async {
    for (var iter in _lstFileInfo) {
      DownloadFileInfoData pData = iter as DownloadFileInfoData;
      var fs = File(pData.strTempPath!);
      if (await fs.exists()) {
        try {
          FileStat stat = await fs.stat();
          if (pData.tmFileModify != null &&
              pData.tmFileModify!.isAfter(fromOleDateTime()) &&
              pData.tmFileModify!.compareTo(stat.modified) != 0) {
            await fs.setLastModified(pData.tmFileModify!);
          }
        } catch (e) {
          logE(
              '''Error reset modify time: $e for file: '${pData.strTempPath}'.''');
        }
      }
    }
  }

  Future<bool> copyPreData() async {
    String strFileName =
        p.join(AppGlobal.ftpSettingPath, 'PreDataFileList.xml');
    bool bSuccess = true;
    if (await File(strFileName).exists()) {
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
      xmlProfile.loadProfile(szRootItemName: 'FileList');
      XmlItem? pItem = xmlProfile.getItem('FileItem');
      while (pItem != null) {
        String strDestFile = xmlProfile.getNodeText(pItem, 'DestFile');
        String strFilePath = xmlProfile.getNodeText(pItem, 'FilePath');
        var preFile = File(strFilePath);
        if (await preFile.exists()) {
          try {
            await FileUtils.moveFile(preFile, strDestFile);
          } catch (e) {
            logE('''copy '$strFilePath' to '$strDestFile' failure''');
            bSuccess = false;
          }
        }

        pItem = pItem.getSibling();
      }

      if (bSuccess) {
        await File(strFileName).delete();
      }
    }

    return bSuccess;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : LoadFtpSetting									*/
  /* Description   : Load Ftp Setting.                    			*/
  /*																	*/
  /// *****************************************************************
  Future<void> loadTempPath() async {
    String strFileName = p.join(AppGlobal.ftpSettingPath, 'ftppathlog.xml');
    XmlFile file = XmlFile('DCMTempPath');
    if (file.load(strFileName, null)) {
      XmlItem? pPathItem = file.root().getItem('TempPath');
      while (pPathItem != null) {
        String strTemp = pPathItem.getItemValue('TempPath');
        await FileUtils.makeSureDirectoryPathExists(strTemp);
        int nContentType = pPathItem.getItemValueI('ContentType');
        String strDest = pPathItem.getItemValue('DestPath');
        int nFlag = pPathItem.getItemValueI('PriorityFlag');
        addTempFile(nContentType, strTemp, strDest, nFlag);

        pPathItem = pPathItem.getSibling();
      }
    }
  }

  /// Save temp path log to XML/JSON
  static void saveTempPath() {
    if (_tempFiles.isNotEmpty) {
      String strFileName = p.join(AppGlobal.ftpSettingPath, 'ftppathlog.xml');

      XmlFilePro file = XmlFilePro('DCMTempPath');
      // Save tempoary path information
      for (int i = 0; i < _tempFiles.length; i++) {
        XmlItem? pPathItem = file.root().addItem('TempPath');
        if (pPathItem != null) {
          pPathItem.addItem('ContentType', _tempFiles[i].nContentType);
          pPathItem.addItem('TempPath', _tempFiles[i].strSourcePath);
          pPathItem.addItem('DestPath', _tempFiles[i].strDestPath);
          pPathItem.addItem('PriorityFlag', _tempFiles[i].nPriorityFlag);
        }
      }

      file.save(strFileName);
    }
  }

  Future<void> removeAllTempFile(String strBatch) async {
    if (AppGlobal.deleteContentIfFTPFail) {
      DownloadFileListImpl downloadFileList = DownloadFileListImpl(strBatch);
      downloadFileList.loadDownloadFileList(strBatch);
      downloadFileList.removeFileList();
    }
    /*else
    {
      CDownloadFileListImpl DownloadFileList;
      DownloadFileList.LoadDownloadFileList(strBatch);
      DownloadFileList.SaveToTempFile();
    }*/

    String strFileName =
        p.join(AppGlobal.ftpSettingPath, 'Filelog', '$strBatch.xml');
    var logFile = File(strFileName);
    if (await logFile.exists()) await logFile.delete();
  }

  Future<bool> saveDownloadFileList() async {
    DownloadFileListImpl downloadFileList = DownloadFileListImpl();
    downloadFileList.copyFrom(_lstFileInfo);
    return await downloadFileList.saveDownloadFileList(_strBatch);
  }

  Future<bool> loadDownloadFileList(String strBatch) async {
    _strBatch = strBatch;

    DownloadFileListImpl downloadFileList = DownloadFileListImpl();
    downloadFileList.loadDownloadFileList(strBatch);
    if (await downloadFileList.validDownloadedFile(_lstFileInfo)) {
      return true;
    }

    return false;
  }

  static Future<void> initLocalFiles() async {
    String strFileName =
        p.join(AppGlobal.ftpSettingPath, 'FileList.xml'); // + '\\FileList.xml';
    if (await File(strFileName).exists()) {
      return;
    }

    FileReplaceService fileImpl = FileReplaceService();
    Map<String, FileInfoData> mapFiles = {};
    /*for (int i = 0; i < contentTypeManager.contentTypeList.length; i++) {
      String strFilePath = await getLocalPath(i);
      if (strFilePath.isNotEmpty) {
        fileImpl.findLocalFiles(i, strFilePath, mapFiles);
      }
    }*/
    for (var contentType in contentTypeManager.contentTypeList) {
      String strFilePath = await getLocalPath(contentType.uiContentType);
      if (strFilePath.isNotEmpty) {
        fileImpl.findLocalFiles(
            contentType.uiContentType, strFilePath, mapFiles);
      }
    }
    fileImpl.saveFileInfo();
    mapFiles.clear();
  }

  static bool availableForACU() {
    if (isBlank(AppGlobal.availableACUStart) &&
        isBlank(AppGlobal.availableACUEnd)) {
      return true;
    }

    DateTime dtStart = DateTime.now();
    if (isNotBlank(AppGlobal.availableACUStart)) {
      dtStart = stringToTime(dtStart, AppGlobal.availableACUStart!, ':');
      if (DateTime.now().isBefore(dtStart)) {
        logI(
            'Auto content update is unavailable, Start time for auto content update: ${AppGlobal.availableACUStart}');

        return false;
      }
    }

    DateTime dtEnd = DateTime.now();
    if (isNotBlank(AppGlobal.availableACUEnd)) {
      dtEnd = stringToTime(dtEnd, AppGlobal.availableACUEnd!, ':');
      if (DateTime.now().isAfter(dtEnd)) {
        logI(
            'Auto content update is unavailable, End time for auto content update: ${AppGlobal.availableACUEnd}',
            syncTag);

        return false;
      }
    }
    logI(
        'It is time for auto content update, Available time: ${AppGlobal.availableACUStart} - ${AppGlobal.availableACUEnd}',
        syncTag);

    return true;
  }

  bool get isLoaded => _isLoaded;
}
