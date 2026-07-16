import 'dart:io';
import 'dart:convert';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'package:crypto/crypto.dart';

import '../xmlfile/xmlfile.dart';

// ============================================================================
// 2. Service Implementation
// ============================================================================

class FileReplaceService {
  final String lpszSignature = 'DCM Player - FTP FileList Log';
  final List<FileInfoData> _lstFileInfo = [];

  // Configuration
  String _settingsPath = '';
  bool _enableChecksum = false;

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

  void init(String settingsPath, bool enableChecksum) {
    _settingsPath = settingsPath;
    _enableChecksum = enableChecksum;
  }

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

        FileStat stat = await entity.stat();

        FileInfoData info = FileInfoData(
          filePath: entity.path,
          fileTitle: fileName,
          shortPath: p.relative(entity.path, from: contentPath),
          destFile: p.relative(entity.path, from: contentPath),
          fileSize: stat.size,
          contentType: contentType,
          fileCreate: stat.changed, // Approximation
          fileModify: stat.modified,
        );

        if (_enableChecksum) {
          await _calculateHash(info);
        }

        mapFiles[key] = info;
        _lstFileInfo.add(info);
      } else if (entity is Directory) {
        String dirName = p.basename(entity.path);
        // Skip folders starting with { and ending with }
        if (dirName.startsWith('{') && dirName.endsWith('}')) continue;

        await findLocalFiles(contentType, entity.path, mapFiles,
            rootPath: contentPath);
      }
    }
  }

  bool _isContentTypeValid(int contentType, String filePath) {
    // Simplified logic. In C++, specific types like Skins/Graphics were exempt from strict checking.
    // Here we assume all files are valid for discovery unless filtered by extension elsewhere.
    return true;
  }

  Future<void> _calculateHash(FileInfoData info) async {
    try {
      File file = File(info.filePath);
      if (await file.exists()) {
        var bytes = await file.readAsBytes();
        info.md5 = md5.convert(bytes).toString();
        info.sha1 = sha1.convert(bytes).toString();
      }
    } catch (e) {
      print("Error calculating hash for ${info.filePath}: $e");
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
    String strFileName = p.join(DCMGlobal.ftpSettingPath, fileListName);

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
            if (IsLocalFileExists(pData)) {
              m_lstFileInfo.push_back(pData);
            } else {
              SAFE_DELETE(pData);
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
  Future<bool> _isLocalFileExists(FileInfoData fileInfo) async {
    // Simulate FTPPathImpl.GetLocalPath
    String basePath = '/data/local'; // Placeholder
    String destPath = p.join(basePath, fileInfo.destFile);

    if (await File(destPath).exists()) {
      fileInfo.status = FileStatus.normal;
      return true;
    } else {
      // Check temp path
      String tempPath = p.join(basePath, 'temp', fileInfo.destFile);
      if (await File(tempPath).exists()) {
        fileInfo.fileStatus = FileItemStatus.temporary;
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
            //m_lstFileInfo.push_back(new CFileInfoData(*pFileInfo));
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Corresponds to IsCanDownload
  Future<bool> isCanDownload(FileInfoData fileInfo) async {
    // Simulate FTPPathImpl.GetLocalPath
    String basePath = '/data/local';
    String destPath = p.join(basePath, fileInfo.destFile);

    File file = File(destPath);
    if (await file.exists()) {
      FileStat stat = await file.stat();
      // Check if hidden or system (Dart doesn't have direct attribute check like Windows,
      // but we can check if name starts with dot for Unix-like systems)
      if (p.basename(destPath).startsWith('.')) {
        return false;
      }
    }
    return true;
  }

  /// Corresponds to IsReplace
  Future<bool> isReplace(FileInfoData newFileInfoData, bool bReplace) async {
    if (isBadFile(p.basename(newFileInfoData.destFile))) return false;

    if (bReplace) {
      // Specific types might always replace or never replace depending on C++ logic
      // C++: if not Layout/Database/Graphics/Skins, return bReplace
      const List<int> specialTypes = [10, 11, 12, 13]; // Placeholder enums
      if (!specialTypes.contains(newFileInfoData.contentType)) {
        return bReplace;
      }
    }

    // Check against existing list
    for (var existing in _lstFileInfo) {
      if (_isSameFile(newFileInfoData, existing)) {
        if (!newFileInfoData.isModified(existing)) {
          newFileInfoData.status = existing.status;

          // Special types logic
          const List<int> noReplaceTypes = [10, 11, 12, 13];
          if (noReplaceTypes.contains(newFileInfoData.contentType)) {
            return false;
          }
          return bReplace;
        }
        break;
      }
    }

    // PreData logic omitted for brevity, similar comparison

    return true;
  }

  bool _isSameFile(FileInfoData f1, FileInfoData f2) {
    return f1.destFile == f2.destFile && f1.contentType == f2.contentType;
  }

  /// Corresponds to ClearFileList
  Future<void> clearFileList() async {
    List<FileInfoData> toRemove = [];
    for (var fileInfo in _lstFileInfo) {
      String basePath = '/data/local';
      String destPath = p.join(basePath, fileInfo.destFile);
      if (!await File(destPath).exists()) {
        toRemove.add(fileInfo);
      }
    }
    _lstFileInfo.removeWhere((item) => toRemove.contains(item));
  }

  /// Corresponds to RemoveFileInfoData
  bool removeFileInfoData(String destFile, int contentType) {
    int index =
        _lstFileInfo.indexWhere((f) => f.isSameAs(destFile, contentType));
    if (index != -1) {
      _lstFileInfo.removeAt(index);
      return true;
    }
    return false;
  }

  /// Corresponds to AddDownloadFile
  void addDownloadFile(FileInfoData fileInfo, {bool isTemp = false}) {
    bool existed = false;
    for (var existing in _lstFileInfo) {
      if (_isSameFile(fileInfo, existing)) {
        existed = true;
        existing.fileCreate = fileInfo.fileCreate;
        existing.fileModify = fileInfo.fileModify;
        existing.fileSize = fileInfo.fileSize;
        existing.md5 = fileInfo.md5;
        existing.sha1 = fileInfo.sha1;
        existing.status = isTemp ? FileStatus.temporary : FileStatus.normal;
        existing.transferType = fileInfo.transferType;
        break;
      }
    }

    if (!existed) {
      FileInfoData newFile = FileInfoData.copyFrom(
          fileInfo); // Need to implement copyFrom in FileInfoData
      newFile.status = isTemp ? FileStatus.temporary : FileStatus.normal;
      _lstFileInfo.add(newFile);
    }
  }

  void addToFileList(List<FileInfoData> sourceList, {bool isTemp = false}) {
    for (var file in sourceList) {
      addDownloadFile(file, isTemp: isTemp);
    }
  }

  List<FileInfoData> get fileList => _lstFileInfo;
}
