import 'dart:io';

import 'package:dcm/backend/models/file_info_data.dart';
import 'package:path/path.dart' as path;

class FileInfoUtils {
  static FileInfoData? loadFileInfo(String strFilePath, int contentType) {
    File file = File(strFilePath);
    if (file.existsSync()) {
      FileStat stat = file.statSync();

      FileInfoData pFileInfo = FileInfoData(
        nContentType: contentType,
        strFilePath: file.absolute.path,
        strFileTitle: path.basename(strFilePath),
        strShortPath:
            getSourcePath(path.basename(strFilePath), null, contentType),
        strDestFile: path.basename(strFilePath),
        dwFileSize: BigInt.from(stat.size),
        tmFileCreate: stat.changed,
        tmFileModify: stat.modified,
      );

      return pFileInfo;
    }

    return null;
  }

  static Future<List<FileInfoData>> publishFilePath(
      String dirPath, int contentType) async {
    Directory dir = Directory(dirPath);
    List<FileInfoData> fileInfos = [];

    if (await dir.exists()) {
      await for (FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File &&
            !path.extension(entity.path).toLowerCase().endsWith('.md5')) {
          FileInfoData? fileInfo = await loadFileInfo(entity.path, contentType);
          if (fileInfo != null) {
            fileInfos.add(fileInfo);
          }
        }
      }
    }

    return fileInfos;
  }

  static String getDestPath(String fileTitle, int contentType) {
    String strDestFile = "$fileTitle.xml";
    switch (contentType) {
      case 1: // Assuming DCM_DCMFILE_TYPE
        strDestFile = "$fileTitle.DCM";
        break;
      case 2: // Assuming other types
        break;
      default:
        print("Invalid content type for getDestPath: $contentType");
        break;
    }

    return strDestFile;
  }

  static String getSourcePath(String shortPath, String? id, int contentType) {
    String strShortPath = '';
    switch (contentType) {
      case 1: // Assuming DCM_DAY_TYPE
        strShortPath = "api/pl/playlists/xmlcontent/$id";
        break;
      case 2: // Assuming DCM_DCMFILE_TYPE
        strShortPath = "api/pl/catalogues/xmlcontent/$id";
        break;
      case 3: // Assuming DCM_AHMESSAGE_TYPE
        strShortPath = "api/msg/ahMessages/xmlcontent/$id";
        break;
      case 4: // Assuming DCM_AHPLAYLIST_TYPE
        break;
      case 5: // Assuming SITE_PLAYLIST
        break;
      case 6: // Assuming DIRECTPLAY_TYPE
        strShortPath = "api/cm/contentLists/xmlcontent/$id";
        break;
      case 7: // Assuming DDE_TYPE
        break;
      case 8: // Assuming DCM_ROOMEVENT_TYPE
        break;
      case 9: // Assuming TEXT_TYPE
        strShortPath = "api/cm/banners/xmlcontent/$id";
        break;
      case 10: // Assuming IMAGE_TYPE
        strShortPath = "api/cm/slideshows/xmlcontent/$id";
        break;
      default:
        print("Invalid content type for getSourcePath: $contentType");
        break;
    }

    return strShortPath;
  }

  static List<FileInfoData> mergeFileInfos(
      List<FileInfoData> srcFileInfos, List<FileInfoData> destFileInfos) {
    for (var fileInfo in srcFileInfos) {
      bool exists = false;
      for (var destInfo in destFileInfos) {
        if (destInfo.isSameAs(
            strFileInfo: fileInfo.strDestFile,
            nContentType: fileInfo.nContentType)) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        destFileInfos.add(fileInfo);
      }
    }

    return destFileInfos;
  }
}
