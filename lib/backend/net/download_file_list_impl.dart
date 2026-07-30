import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/download_file_info_data.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/file_replace_service.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as p;

// ============================================================================
// 2. Implementation Class
// ============================================================================

class DownloadFileListImpl {
  final List<DownloadFileInfoData> _lstFileInfo = [];
  String _strBatch = '';

  // Signature for XML validation
  static const String _signature = "DCM Player - FTP Downloaded FileList Log";

  DownloadFileListImpl([String? batchId]) {
    _strBatch = batchId ?? '';
  }

  // --------------------------------------------------------------------------
  // Core Logic Methods
  // --------------------------------------------------------------------------

  /// Corresponds to RemoveFileList
  Future<void> removeFileList() async {
    // Delete temp files
    for (var fileInfo in _lstFileInfo) {
      if (fileInfo.strTempPath != null && fileInfo.strTempPath!.isNotEmpty) {
        File tempFile = File(fileInfo.strTempPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    // Delete the log XML file
    var listFile =
        File(p.join(AppGlobal.ftpSettingPath, 'Filelog', '$_strBatch.xml'));
    if (await listFile.exists()) {
      await listFile.delete();
    }
    _lstFileInfo.clear();
  }

  /// Corresponds to SaveToTempFile
  /// Note: In C++, this interacts with FileReplaceService.
  /// Here we assume a simplified local storage or just marking them.
  Future<bool> saveToTempFile() async {
    FileReplaceService fileReplace = FileReplaceService();
    fileReplace.loadFileInfo();
    for (var iter in _lstFileInfo) {
      var bValid = await PlayerPathService.validDownloadedFile(iter);
      if (!bValid.status) {
        fileReplace.addDownloadFile(iter, true);
      }
    }
    return fileReplace.saveFileInfo();
  }

  /// Corresponds to SaveToFileList()

  Future<bool> saveToFileList([List<FileInfoData>? lstFileInfo]) async {
    FileReplaceService fileReplace = FileReplaceService();
    fileReplace.loadFileInfo();
    if (lstFileInfo == null) {
      for (var iter in _lstFileInfo) {
        fileReplace.addDownloadFile(iter);
      }
    } else {
      for (var iter in _lstFileInfo) {
        if (isInDownloadFileList(
            lstFileInfo, iter.strDestFile, iter.nContentType)) {
          fileReplace.addDownloadFile(iter, true);
        } else {
          fileReplace.addDownloadFile(iter);
        }
      }
    }
    return fileReplace.saveFileInfo();
  }

  /// Corresponds to ValidDownloadedFile
  Future<bool> validDownloadedFile(List<FileInfoData> targetList) async {
    bool bValid = true;
    if (AppGlobal.fileIntegrityCheck) {
      for (var iter in _lstFileInfo) {
        if (!iter.needDelete()) {
          var result = await PlayerPathService.validDownloadedFile(iter);
          if (!result.status) {
            PlayerLogFile.writeLogFile(cTRANSFEROTHERERR, result.strErrMsg!,
                contentType: iter.nContentType, fileTitle: iter.strFileTitle);
            bValid = false;
          }
        }
      }
    }

    if (!bValid) {
      saveToTempFile();
    } else {
      for (var iter in _lstFileInfo) {
        if (!isInDownloadFileList(
            targetList, iter.strFilePath!, iter.nContentType)) {
          targetList.add(DownloadFileInfoData.copyFrom(iter));
        }
      }
    }

    return bValid;
  }

  /// Corresponds to IsInDownloadFileList
  bool isInDownloadFileList(
      List<FileInfoData> list, String destFile, int contentType) {
    return list.any(
        (f) => f.isSameAs(strFileInfo: destFile, nContentType: contentType));
  }

  /// Corresponds to CopyToFileList
  void copyToFileList(List<FileInfoData> targetList) {
    for (var fileInfo in _lstFileInfo) {
      targetList.add(DownloadFileInfoData.copyFrom(fileInfo));
    }
  }

  /// Corresponds to CopyFrom
  void copyFrom(List<FileInfoData> sourceList) {
    for (var fileInfo in sourceList) {
      _lstFileInfo
          .add(DownloadFileInfoData.copyFrom(fileInfo as DownloadFileInfoData));
    }
  }

  /// Corresponds to CopyFromFileList
  /// Calculates TempPath and DestPath based on ContentType
  void copyFromFileList(List<FileInfoData> sourceList) async {
    for (var iter in sourceList) {
      DownloadFileInfoData pDownloadFile =
          DownloadFileInfoData.fromFileInfo(iter);
      //pDownloadFile->m_strShortPath = iter.strFilePath;
      //pDownloadFile->m_strFilePath = FTPPathImpl.GetLocalPath(iter.nContentType, iter.dwModuleFlag, true) + wxFILE_SEP_PATH + iter.strDestFile;
      //pDownloadFile->m_strDestFile = FTPPathImpl.GetLocalPath(iter.nContentType, iter.dwModuleFlag) + wxFILE_SEP_PATH + iter.strDestFile;
      String name = iter.strDestFile;
      name = name.replaceAll(p.separator == '/' ? '\\' : '/', p.separator);
      pDownloadFile.strTempPath = p.join(
          await PlayerPathService.getLocalPath(iter.nContentType, true), name);
      pDownloadFile.strDestPath =
          p.join(await PlayerPathService.getLocalPath(iter.nContentType), name);

      _lstFileInfo.add(pDownloadFile);
    }
  }

  // --------------------------------------------------------------------------
  // Serialization (XML)
  // --------------------------------------------------------------------------

  /// Corresponds to Serialize
  Future<bool> _serialize(String batchId, bool isStoring) async {
    String strFileName = p.join(AppGlobal.ftpSettingPath, 'Filelog');
    FileUtils.makeSureDirectoryPathExists(strFileName);
    strFileName = p.join(strFileName, '$_strBatch.xml');

    if (isStoring) {
      XmlFilePro fileList = XmlFilePro('FileList');
      for (var iter in _lstFileInfo) {
        //iter.strShortPath = iter.strFilePath;
        //iter.strFilePath = FTPPathImpl.GetLocalPath(iter.nContentType, iter.dwModuleFlag, true) + wxFILE_SEP_PATH + iter.strDestFile;
        //iter.strDestFile = FTPPathImpl.GetLocalPath(iter.nContentType, iter.dwModuleFlag) + wxFILE_SEP_PATH + iter.strDestFile;
        // Save the Weather information
        XmlItem? xi = fileList.addDataNode('FileItem', null);
        if (xi != null) {
          iter.writeToXML(xi);
        }
      }

      fileList.setSignature(_signature);

      return fileList.save(strFileName);
    } else {
      XmlFilePro file = XmlFilePro('FileList');
      if (!file.open(strFileName, XfOpen.read, false)) {
        return false;
      }

      if (file.loadEx()) {
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == _signature) {
          // get FileList Item
          XmlItem? pXISibling = file.getItem('FileItem');
          while (pXISibling != null) {
            DownloadFileInfoData pData = DownloadFileInfoData();
            // get File List Inforamtion data
            pData.getFromXML(pXISibling);
            _lstFileInfo.add(pData);

            pXISibling = pXISibling.getSibling();
          }

          return true;
        }
      }
      return false;
    }
  }

  /// Corresponds to LoadDownloadFileList
  Future<bool> loadDownloadFileList(String batchId) async {
    _strBatch = batchId;
    return _serialize(batchId, false);
  }

  /// Corresponds to SaveDownloadFileList
  Future<bool> saveDownloadFileList(String batchId) async {
    _strBatch = batchId;
    return _serialize(batchId, true);
  }

  List<DownloadFileInfoData> get fileList => _lstFileInfo;
}
