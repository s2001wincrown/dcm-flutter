import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_info_utils.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as p;

import '../xmlfile/xmlfile.dart';

// ============================================================================
// 2. Service Implementation
// ============================================================================

class FileReplaceService {
  final String lpszSignature = 'DCM Player - FTP FileList Log';
  final List<FileInfoData> _lstFileInfo = [];

  // Bad file names list
  static const List<String> _badFileNames = [
    'sthumbs.dat',
    'thumbs.db',
    'dxva_sig.txt',
    'wand.dat',
    'signons.txt',
    'signons2.txt',
    'signons3.txt',
    'signons.sqlite',
    'key3.db',
  ];

  // --------------------------------------------------------------------------
  // File Discovery
  // --------------------------------------------------------------------------

  /// Corresponds to FindLocalFiles
  Future<void> findLocalFiles(
      int contentType, String path, Map<String, FileInfoData> mapFiles,
      {String? rootPath}) async {
    Directory dir = Directory(path);
    if (!await dir.exists()) return;

    String contentPath = rootPath ?? path;

    await for (var entity in dir.list()) {
      if (entity is File) {
        String fileName = p.basename(entity.path);

        if (isBadFile(fileName)) continue;

        // Content Type Check (Simplified: In C++ it used ContentTypeMgr)
        // Assuming we only process if it matches or is generic type
        if (!_isContentTypeValid(contentType, entity.path)) continue;

        String key = entity.path.toLowerCase();
        if (mapFiles.containsKey(key)) continue;

        FileInfoData? info = await FileInfoUtils.loadFile(entity, contentType);
        if (info != null) {
          info.strShortPath = p.relative(entity.path, from: contentPath);
          info.strDestFile = p.relative(entity.path, from: contentPath);
          if ((AppGlobal.globalSetting & settingCHECKSUM) > 0) {
            await _calculateHash(info);
          }

          mapFiles[key] = info;
          _lstFileInfo.add(info);
        }
      } else if (entity is Directory) {
        String dirName = p.basename(entity.path);
        // Skip folders starting with { and ending with }
        if (Utils.isValidUuid(dirName) ||
            (dirName.startsWith('{') && dirName.endsWith('}'))) {
          continue;
        }

        await findLocalFiles(contentType, entity.path, mapFiles,
            rootPath: contentPath);
      }
    }
  }

  bool _isContentTypeValid(int contentType, String filePath) {
    if (cDCMSKINSTYPE != contentType &&
        cDCMGRAPHICSTYPE != contentType &&
        cDCMLAYOUTTYPE != contentType &&
        cIMAGETYPE != contentType) {
      int nCType = contentType;
      if (contentType == cDCMSINGLEIMAGETYPE) {
        nCType = cIMAGETYPE;
      }
      if (!PlayerPathService.contentTypeManager
          .isContentType(filePath, nCType)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _calculateHash(FileInfoData info) async {
    try {
      File file = File(info.strFilePath!);
      if (await file.exists()) {
        var bytes = await file.readAsBytes();
        info.strMD5 = md5.convert(bytes).toString();
        info.strSHA1 = sha1.convert(bytes).toString();
      }
    } catch (e) {
      logE('Error calculating hash for ${info.strFilePath}: $e', syncTag);
    }
  }

  static bool isBadFile(String fileName) {
    if (fileName.isEmpty) return true;
    if (fileName.startsWith('.')) return true;

    String lowerName = fileName.toLowerCase();
    if (_badFileNames.contains(lowerName)) return true;

    // Add extension checks if needed

    return false;
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------

  /// Corresponds to Serialize / LoadFileInfoData / SaveFileInfoData
  Future<bool> serialize(String fileListName, bool bStoring) async {
    String strFileName = p.join(AppGlobal.ftpSettingPath, fileListName);

    if (bStoring) {
      XmlFilePro fileList = XmlFilePro('FileList');

      fileList.setSignature(lpszSignature);

      for (var iter in _lstFileInfo) {
        // Save the File List information
        XmlItem? xi = fileList.addDataNode('FileItem', null);
        if (xi != null) {
          iter.writeToXML(xi, true);
        }
      }

      fileList.setSignature(lpszSignature);

      return fileList.save(strFileName);
    } else {
      XmlFilePro file = XmlFilePro('FileList');
      if (!file.open(strFileName, XfOpen.read, false)) {
        return false;
      }

      if (file.loadEx()) {
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == lpszSignature) {
          // get FileList Item
          XmlItem? pXISibling = file.getItem('FileItem');
          while (pXISibling != null) {
            FileInfoData pData = FileInfoData();
            // get File List Inforamtion data
            pData.getFromXML(pXISibling);
            if (await _isLocalFileExists(pData)) {
              _lstFileInfo.add(pData);
            }

            pXISibling = pXISibling.getSibling();
          }
          file.close();

          return true;
        }
      }
      file.close();

      return false;
    }
  }

  Future<bool> loadFileInfo([String fileListName = 'FileList.xml']) async {
    return serialize(fileListName, false);
  }

  Future<bool> saveFileInfo([String fileListName = 'FileList.xml']) async {
    return serialize(fileListName, true);
  }

  // --------------------------------------------------------------------------
  // Logic Helpers
  // --------------------------------------------------------------------------

  /// Corresponds to IsLocalFileExists
  Future<bool> _isLocalFileExists(FileInfoData pFileInfo) async {
    String strDest = p.join(
        await PlayerPathService.getLocalPath(pFileInfo.nContentType),
        pFileInfo.strDestFile);
    if (await File(strDest).exists()) {
      pFileInfo.fileStatus = FileItemStatus.normal;
      return true;
    } else {
      strDest = p.join(
          await PlayerPathService.getLocalPath(pFileInfo.nContentType, true),
          pFileInfo.strDestFile);
      if (await File(strDest).exists()) {
        pFileInfo.fileStatus = FileItemStatus.temporary;
        return true;
      }
    }
    return false;
  }

  bool isPreData(
      String strPath, String strPreDataFile, FileInfoData pFileInfo) {
    for (var iter in _lstFileInfo) {
      FileInfoData pFileInfo1 = iter;
      if (pFileInfo1.nContentType == cDCMPREDATATYPE) {
        String strFilePath = strPath + pFileInfo1.strDestFile;
        if (strFilePath.equalsIgnoreCase(strPreDataFile)) {
          if (equalsTime(pFileInfo.tmFileModify, pFileInfo1.tmFileModify) &&
              pFileInfo.dwFileSize == pFileInfo1.dwFileSize) {
            //_lstFileInfo.add(new CFileInfoData(*pFileInfo));
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<bool> isCanDownload(FileInfoData pFileInfo) async {
    /*String strDest = p.join(await PlayerPathService.getLocalPath(pFileInfo.nContentType), pFileInfo.strDestFile);
    var file = File(strDest);
    if (await file.exists()) {
      if (file.IsSystem() || file.IsHidden())
      {
        return false;
      }
    }*/

    return true;
  }

  bool isReplace(FileInfoData pFileInfo, bool bReplace) {
    if (isBadFile(p.basename(pFileInfo.strDestFile))) {
      return false;
    }

    if (bReplace) {
      if (pFileInfo.nContentType != cDCMLAYOUTTYPE &&
          pFileInfo.nContentType != cDCMGRAPHICSTYPE &&
          pFileInfo.nContentType != cDCMSKINSTYPE) {
        return bReplace;
      }
    }

    for (var iter in _lstFileInfo) {
      FileInfoData pFileInfo1 = iter;
      if (isSameFile(pFileInfo, pFileInfo1)) {
        if (!isModified(pFileInfo, pFileInfo1)) {
          if (bReplace) {
            logI(
                '''File: '${pFileInfo.strDestFile}'; content Type:'${pFileInfo.nContentType}' need to download''',
                syncTag);
          }

          pFileInfo.fileStatus = pFileInfo1.fileStatus;
          if (pFileInfo.nContentType == cDCMLAYOUTTYPE &&
              pFileInfo.nContentType == cDCMGRAPHICSTYPE &&
              pFileInfo.nContentType == cDCMSKINSTYPE) {
            return false;
          }

          return bReplace;
        }

        break;
      }
    }
    if (pFileInfo.nContentType == cDCMPREDATATYPE) {
      for (var iter in _lstFileInfo) {
        FileInfoData pFileInfo1 = iter;
        String strFileName = pFileInfo.strFilePath!;
        strFileName = FileUtils.fixPathSeparators(strFileName);
        strFileName = p.basename(strFileName);
        String strFileName1 = pFileInfo1.strFilePath!;
        strFileName1 = FileUtils.fixPathSeparators(strFileName1);
        strFileName1 = p.basename(strFileName1);
        if (strFileName.equalsIgnoreCase(strFileName1)) {
          if (pFileInfo.tmFileModify == pFileInfo1.tmFileModify &&
              pFileInfo.dwFileSize == pFileInfo1.dwFileSize) {
            return bReplace;
          }
        }
      }
    }
    logI(
        '''File: '${pFileInfo.strDestFile}'; content Type:'${pFileInfo.nContentType}' need to download''',
        syncTag);

    return true;
  }

  Future<void> clearFileList() async {
    for (int i = _lstFileInfo.length - 1; i >= 0; i--) {
      FileInfoData pFileInfo = _lstFileInfo[i];

      String strDest = p.join(
          await PlayerPathService.getLocalPath(pFileInfo.nContentType),
          pFileInfo.strDestFile);
      if (!await File(strDest).exists()) {
        _lstFileInfo.removeAt(i);
      }
    }
  }

  bool removeFileInfo(String strDestFile, int nContentType) {
    for (int i = _lstFileInfo.length - 1; i >= 0; i--) {
      FileInfoData pFileInfo1 = _lstFileInfo[i];
      if (pFileInfo1.isSameAs(
          strFileInfo: strDestFile, nContentType: nContentType)) {
        _lstFileInfo.removeAt(i);
        return true;
      }
    }
    return false;
  }

  void addDownloadFile(FileInfoData pFileInfo, [bool isTemp = false]) {
    bool bExisted = false;
    for (var iter in _lstFileInfo) {
      FileInfoData pFileInfo1 = iter;

      if (isSameFile(pFileInfo, pFileInfo1)) {
        bExisted = true;
        pFileInfo1.tmFileCreate = pFileInfo.tmFileCreate;
        pFileInfo1.tmFileModify = pFileInfo.tmFileModify;
        pFileInfo1.dwFileSize = pFileInfo.dwFileSize;
        pFileInfo1.strMD5 = pFileInfo.strMD5;
        pFileInfo1.strSHA1 = pFileInfo.strSHA1;
        pFileInfo1.fileStatus =
            isTemp ? FileItemStatus.temporary : FileItemStatus.normal;
        pFileInfo1.nTransferType = pFileInfo.nTransferType;
        break;
      }
    }
    if (!bExisted) {
      FileInfoData pFileInfo1 = FileInfoData.copy(pFileInfo);
      pFileInfo1.fileStatus =
          isTemp ? FileItemStatus.temporary : FileItemStatus.normal;
      _lstFileInfo.add(pFileInfo1);
    }
  }

  void setTempFileFlag(String strDestFile, int nContentType) {
    var it = _lstFileInfo.iterator;
    while (it.moveNext()) {
      FileInfoData pFileInfo1 = it.current;
      if (pFileInfo1.isSameAs(
          strFileInfo: strDestFile, nContentType: nContentType)) {
        pFileInfo1.fileStatus = FileItemStatus.temporary;
        break;
      }
    }
  }

  bool addToFileList(List<FileInfoData> lstFileInfo, [bool bIsTemp = false]) {
    for (var iter in lstFileInfo) {
      addDownloadFile(iter, bIsTemp);
    }

    return true;
  }

  bool isSameFile(FileInfoData pFileInfo1, FileInfoData pFileInfo2) {
    return ((pFileInfo1.strDestFile.equalsIgnoreCase(pFileInfo2.strDestFile)) &&
        pFileInfo2.nContentType == pFileInfo1.nContentType);
  }

  bool isModified(FileInfoData pServer, FileInfoData pLocal) {
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

  List<FileInfoData> get fileList => _lstFileInfo;
}
