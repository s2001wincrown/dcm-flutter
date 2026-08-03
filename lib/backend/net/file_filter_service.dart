import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/download_file_list_impl.dart';
import 'package:dcm/backend/net/file_replace_service.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_info_utils.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// 对应 CChannelPlayerImpl 和 CEventListImpl 的部分文件管理逻辑
class FileFilterService {
  int _nFtpImm = 0;
  bool bGenSitePlaylist = false;

  int _nFtpPeriod = 7;

  int _nLevel = 0;

  final List<FileInfoData> _lstFileInfo = [];
  final List<FileInfoData> _lstFileInfo1 = [];
  final List<FileInfoData> _lstPreData = [];
  final List<FileInfoData> _lstSitePlaylist = [];
  final FileReplaceService _fileReplaceImpl = FileReplaceService();

  /// 从 XML 字符串加载文件列表 (对应 LoadXml)
  bool loadFromXml(String strXml) {
    XmlFilePro file = XmlFilePro('PublishFileInformation');
    if (file.loadXml(strXml)) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == cFLSignature) {
        _nLevel = file.getItemValueI('m_nLevel');
        _nFtpImm = file.getItemValueI('m_nFtpImm');

        // get publish file information list
        XmlItem? pXISibling = file.getItem('FileItem');
        while (pXISibling != null) {
          FileInfoData pData = FileInfoData();

          // get File Inforamtion data
          pData.getFromXML(pXISibling);

          // add File Information data to list
          addFileList(pData: pData);

          pXISibling = pXISibling.getSibling();
        }

        return true;
      }
    }
    return false;
  }

  ({
    bool status,
    List<String>? arrSitePlaylist,
    List<String>? arrContentList,
    int? nEventDisplay
  }) loadXml(String strXml) {
    XmlFilePro file = XmlFilePro('PublishFileInformation');
    if (file.loadXml(strXml)) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == cFLSignature) {
        _nLevel = file.getItemValueI('m_nLevel');
        _nFtpImm = file.getItemValueI('m_nFtpImm');
        XmlItem? pXIEventDisplay = file.getItem('EventDisplay');
        int? nEventDisplay;
        if (pXIEventDisplay != null) {
          nEventDisplay = pXIEventDisplay.getValueI();
        }
        var arrSitePlaylist = file.root().getItemValueArray('SitePlaylists');
        var arrContentList = file.root().getItemValueArray('ContentLists');

        // get publish file information list
        XmlItem? pXISibling = file.getItem('FileItem');
        while (pXISibling != null) {
          FileInfoData pData = FileInfoData();

          // get File Inforamtion data
          pData.getFromXML(pXISibling);

          // add File Information data to list
          addFileList(pData: pData);

          pXISibling = pXISibling.getSibling();
        }

        return (
          status: true,
          arrSitePlaylist: arrSitePlaylist,
          arrContentList: arrContentList,
          nEventDisplay: nEventDisplay
        ); //true;
      }
    }

    return (
      status: false,
      arrSitePlaylist: null,
      arrContentList: null,
      nEventDisplay: null
    ); //false;
  }

  bool addFileList(
      {FileInfoData? pData,
      String? tempFile,
      int? contentType,
      String? shortPath}) {
    if (pData != null) {
      if (pData.fileStatus == FileItemStatus.skip) {
        _lstFileInfo1.add(pData);
        return false;
      }

      if (pData.dtEffDateFr != null && pData.dtEffDateTo != null) {
        if (pData.dtEffDateTo!.compareTo(DateTime.now()) <= 0) {
          _lstFileInfo1.add(pData);
          return false;
        }
      }
      pData.strDestFile = FileUtils.stripSeparators(pData.strDestFile);
      if (bGenSitePlaylist) {
        if (pData.nContentType == cSITEPLAYLIST &&
            pData.fileStatus != FileItemStatus.temporary &&
            pData.fileStatus != FileItemStatus.remove) {
          for (var iter in _lstSitePlaylist) {
            if (pData.isSameAs(pFileInfo: iter)) {
              _lstFileInfo1.add(pData);
              return false;
            }
          }
          _lstSitePlaylist.add(pData);

          return true;
        }
      }

      for (var iter in _lstSitePlaylist) {
        if (pData.isSameAs(pFileInfo: iter)) {
          _lstFileInfo1.add(pData);
          return false;
        }
      }

      // add File Information data to list
      _lstFileInfo.add(pData);

      return true;
    } else {
      FileInfoData? pFileInfo =
          FileInfoUtils.loadFileInfo(tempFile!, contentType!);
      if (pFileInfo != null) {
        if (shortPath != null) {
          pFileInfo.strDestFile = shortPath;
          pFileInfo.strShortPath = shortPath;
        }

        pFileInfo.fileStatus = FileItemStatus.temporary;
        pFileInfo.strMD5 = '';
        _lstFileInfo.add(pFileInfo);

        return true;
      }

      return false;
    }
  }

  List<String> getAddonText() {
    List<String> arrAddonText = [];
    for (var iter in _lstFileInfo) {
      if (iter.nContentType == cLINKAGETYPE) {
        String strAddonText = iter.strFileTitle;
        if (iter.strFileTitle.endsWithIgnoreCase('.XML')) {
          strAddonText =
              iter.strFileTitle.substring(0, iter.strFileTitle.indexOf('.'));
        }
        arrAddonText.add(strAddonText);
      }
    }

    return arrAddonText;
  }

  bool fileInList(String strDestFile, int nContentType) {
    for (var iter in _lstFileInfo) {
      if (iter.isSameAs(strFileInfo: strDestFile, nContentType: nContentType)) {
        return true;
      }
    }

    return false;
  }

  List<String> getSitePlaylist() {
    List<String> arrSitePlaylist = [];
    for (var iter in _lstSitePlaylist) {
      arrSitePlaylist.add(iter.strFilePath!);
    }

    return arrSitePlaylist;
  }

  /// 过滤已下载的文件 (对应 FilterDownloadedFile)
  /// 注意：在 Flutter 中，检查文件是否存在需要异步 IO
  Future<void> filterDownloadedFile() async {
    for (int i = _lstFileInfo.length - 1; i >= 0; i--) {
      FileInfoData pFileInfo = _lstFileInfo[i];
      String strShortPath = pFileInfo.strDestFile;
      strShortPath = FileUtils.fixPathSeparators(strShortPath);
      String strDest = path.join(
          await PlayerPathService.getLocalPath(pFileInfo.nContentType, true),
          strShortPath); //pData.strShortPath
      if (isBlank(pFileInfo.strMD5)) {
        var nFileSize = await FileUtils.getFileSize(strDest);
        if (!pFileInfo.ignoreFileSize() && pFileInfo.dwFileSize == nFileSize) {
          PlayerLogFile.nTotalBytesDownloaded += nFileSize;
          _lstFileInfo.removeAt(i);
        }
      } else {
        var md5Result =
            await PlayerPathService.validHashData(strDest, pFileInfo);
        if (md5Result.status) {
          PlayerLogFile.nTotalBytesDownloaded += pFileInfo.getFileSize();

          _lstFileInfo.removeAt(i);
        }
      }
    }
  }

  Future<bool> filterReplaceFile(bool bReplaceFile) async {
    _lstFileInfo1.clear();
    await _fileReplaceImpl.loadFileInfo();

    if (_lstFileInfo.isNotEmpty) {
      bool bWriteLog = false;
      String strFileName = path.join(AppGlobal.ftpSettingPath, 'ftperror.xml');
      XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
      if (xmlProfile.loadProfile(szRootItemName: 'FTPError')) {
        bWriteLog = true;
      }

      for (int i = _lstFileInfo.length - 1; i >= 0; i--) {
        FileInfoData pFileInfo = _lstFileInfo[i];
        if (pFileInfo.fileStatus == FileItemStatus.remove) {
          continue;
        }

        if (!_fileReplaceImpl.isReplace(pFileInfo, bReplaceFile)) {
          if (bWriteLog) {
            writeLogFile(xmlProfile, pFileInfo);
          }
          if (pFileInfo.fileStatus == FileItemStatus.normal) {
            _lstFileInfo.removeAt(i);
          }
        } else {
          if (await isPreData(pFileInfo)) {
            if (bWriteLog) {
              writeLogFile(xmlProfile, pFileInfo, false);
            }
            _lstFileInfo.removeAt(i);
            _lstPreData.add(pFileInfo);
          } else if (await _fileReplaceImpl.isCanDownload(pFileInfo)) {
            if (pFileInfo.fileStatus != FileItemStatus.temporary) {
              pFileInfo.fileStatus = FileItemStatus.download;
            }
            if (bWriteLog) {
              writeLogFile(xmlProfile, pFileInfo, false);
            }
          } else {
            _lstFileInfo.removeAt(i);
          }
        }
      }

      if (bWriteLog) {
        xmlProfile.saveProfile('FtpError.xsl');
      }
    }
    //SaveDownloadFileList();
    await savePreDataFileList();

    return true;
  }

  Future<bool> isPreData(FileInfoData pFileInfo) async {
    if (pFileInfo.nContentType == cDCMPREDATATYPE) {
      return false;
    }

    String strPath = await PlayerPathService.getLocalPath(cDCMPREDATATYPE);
    String strShortPath = pFileInfo.strDestFile;
    strShortPath = FileUtils.fixPathSeparators(strShortPath);
    String strFilePath = path.join(strPath,
        strShortPath.substring(strShortPath.lastIndexOf(path.separator) + 1));
    if (await File(strFilePath).exists()) {
      return _fileReplaceImpl.isPreData(strPath, strFilePath, pFileInfo);
    }
    return false;
  }

  void writeLogFile(XmlProfile xmlProfile, FileInfoData pFileInfo,
      [bool bExisted = true]) {
    // Write Lines to Logfile
    XiType nType = XiType.attrib;
    if (bExisted) {
      XmlItem? nSec = xmlProfile.getSection('ExistedItems');
      if (nSec != null) {
        XmlItem? pItem = nSec.addItem('ExistedFile');
        if (pItem != null) {
          String strTime =
              DateFormat('dd/MM/yyyy HH:mm:ss').format(pFileInfo.tmFileModify!);
          pItem.addItem('ModifyDate', strTime, nType);
          pItem.addItem('File', pFileInfo.strFileTitle, nType);
          pItem.addItem('ContentType', pFileInfo.nContentType, nType);
        }
      }
    } else {
      XmlItem? nSec = xmlProfile.getSection('DownloadItems');
      if (nSec != null) {
        XmlItem? pItem = nSec.addItem('DownloadItem');
        if (pItem != null) {
          String strTime =
              DateFormat('dd/MM/yyyy HH:mm:ss').format(pFileInfo.tmFileModify!);
          pItem.addItem('ModifyDate', strTime, nType);
          pItem.addItem('File', pFileInfo.strFileTitle, nType);
          pItem.addItem('ContentType', pFileInfo.nContentType, nType);
        }
      }
    }
  }

  Future<bool> savePreDataFileList() async {
    if (_lstPreData.isEmpty) {
      return true;
    }

    String strFileName =
        path.join(AppGlobal.ftpSettingPath, 'PreDataFileList.xml');
    await File(strFileName).delete();

    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    xmlProfile.loadProfile(szRootItemName: 'FileList');

    for (var iter in _lstPreData) {
      FileInfoData pFileInfo = iter;

      XmlItem? nSec = xmlProfile.appendSection('FileItem');
      if (nSec != null) {
        xmlProfile.createDataNode(nSec, 'FileTitle', pFileInfo.strFileTitle);
        String strShortPath = pFileInfo.strDestFile;
        strShortPath = FileUtils.fixPathSeparators(strShortPath);
        String strFilePath = path.join(
            await PlayerPathService.getLocalPath(cDCMPREDATATYPE),
            strShortPath
                .substring(strShortPath.lastIndexOf(path.separator) + 1));
        xmlProfile.createDataNode(nSec, 'FilePath', strFilePath);
        String strDestFile = path.join(
            await PlayerPathService.getLocalPath(pFileInfo.nContentType),
            strShortPath);
        xmlProfile.createDataNode(nSec, 'DestFile', strDestFile);
        xmlProfile.createDataNode(
            nSec, 'FileType', '${pFileInfo.nContentType}');
        xmlProfile.createDataNode(
            nSec, 'ShortPath', pFileInfo.strFilePath ?? '');
        xmlProfile.createDataNode(nSec, 'FileCreate',
            DateFormat('dd/MM/yyyy HH:mm:ss').format(pFileInfo.tmFileCreate!));
        xmlProfile.createDataNode(nSec, 'FileModify',
            DateFormat('dd/MM/yyyy HH:mm:ss').format(pFileInfo.tmFileModify!));
        xmlProfile.createDataNode(nSec, 'FileSize', '${pFileInfo.dwFileSize}');
      }
    }
    xmlProfile.saveProfile('FileList.xsl');

    return true;
  }

  Future<bool> saveDownloadFileList(String strBatch) async {
    DownloadFileListImpl downloadFileList = DownloadFileListImpl();
    await downloadFileList.copyFromFileList(_lstFileInfo);
    return await downloadFileList.saveDownloadFileList(strBatch);
  }

  void calcTotalBytesToDownload() {
    PlayerLogFile.nTotalBytesToDownload = BigInt.zero;
    for (var iter in _lstFileInfo) {
      PlayerLogFile.nTotalBytesToDownload += iter.getFileSize();
    }
  }

  Future<bool> loadDownloadFileList(String strBatch) async {
    DownloadFileListImpl downloadFileList = DownloadFileListImpl();
    if (await downloadFileList.loadDownloadFileList(strBatch)) {
      downloadFileList.copyToFileList(_lstFileInfo);
      return true;
    }

    return false;
  }

  Future<bool> saveUnFilterFileList(String strBatch) async {
    String strFileName = path.join(AppGlobal.ftpSettingPath, 'Filelog');
    await FileUtils.makeSureDirectoryPathExists(strFileName);
    strFileName = path.join(strFileName, '$strBatch.xml');

    return _serialize(strFileName, true);
  }

  Future<bool> loadUnFilterFileList(String strBatch) async {
    String strFileName = path.join(AppGlobal.ftpSettingPath, 'Filelog');
    await FileUtils.makeSureDirectoryPathExists(strFileName);
    strFileName = path.join(strFileName, '$strBatch.xml');

    return _serialize(strFileName, false);
  }

  /********************************************************************/
/*																	*/
/* Function name : Serialize										*/
/* Description   : Call this function to store/load the Player data	*/
/*																	*/
  /// *****************************************************************
  bool _serialize(String strFilename, bool bStoring) {
    if (bStoring) {
      XmlFilePro playerReg = XmlFilePro('PublishFileInformation');

      playerReg.setDataNode(null, 'm_nLevel', _nLevel);
      playerReg.setDataNode(null, 'm_nFtpImm', _nFtpImm);

      // Save the File information
      for (var iter in _lstFileInfo) {
        XmlItem? xi = playerReg.addDataNode('FileItem', null);
        if (xi != null) {
          iter.writeToXML(xi, true);
        }
      }

      playerReg.setSignature(cFLSignature);

      // encrypt prior to setting checkout status and file info (so these are visible without decryption)
      // this simply fails if password is empty
      playerReg.encrypt(Encodes.cCONTENTFILECRYPTKEY);

      return playerReg.save(strFilename);
    } else {
      XmlFilePro file =
          XmlFilePro('PublishFileInformation', Encodes.cCONTENTFILECRYPTKEY);
      if (!file.open(strFilename, XfOpen.read)) {
        return false;
      }

      if (file.loadEx()) {
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == cFLSignature) {
          _nLevel = file.getItemValueI('m_nLevel');
          _nFtpImm = file.getItemValueI('m_nFtpImm');

          // get publish file information list
          XmlItem? pXISibling = file.getItem('FileItem');
          while (pXISibling != null) {
            FileInfoData pData = FileInfoData();

            // get File Inforamtion data
            pData.getFromXML(pXISibling);

            // add File Information data to list
            addFileList(pData: pData);

            pXISibling = pXISibling.getSibling();
          }

          return true;
        }
      }
      return false;
    }
  }

  Future<bool> saveFileList() async {
    await _fileReplaceImpl.saveFileInfo();
    return true;
  }

  List<FileInfoData> get fileList => _lstFileInfo;
}
