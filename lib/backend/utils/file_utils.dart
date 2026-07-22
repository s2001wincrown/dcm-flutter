import 'dart:io';
import 'dart:math';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:intl/intl.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileUtils {
  static String waPath = '/storage/emulated/0/WhatsApp/Media/.Statuses';

  /// Get mime information of a file
  static String getMime(String path) {
    File file = File(path);
    String mimeType = mime(file.path) ?? '';
    return mimeType;
  }

  /// Return all available Storage path
  static Future<List<Directory>> getStorageList() async {
    List<Directory> paths = (await getExternalStorageDirectories())!;
    List<Directory> filteredPaths = <Directory>[];
    for (Directory dir in paths) {
      filteredPaths.add(removeDataDirectory(dir.path));
    }
    return filteredPaths;
  }

  static Directory removeDataDirectory(String path) {
    return Directory(path.split('Android')[0]);
  }

  /// Get all Files and Directories in a Directory
  static Future<List<FileSystemEntity>> getFilesInPath(String path) async {
    Directory dir = Directory(path);
    return dir.listSync();
  }

  /// Get all Files on the Device
  static Future<List<FileSystemEntity>> getAllFiles(
      {bool showHidden = false}) async {
    List<Directory> storages = await getStorageList();
    List<FileSystemEntity> files = <FileSystemEntity>[];
    for (Directory dir in storages) {
      List<FileSystemEntity> allFilesInPath = [];
      // This is important to catch storage errors
      try {
        allFilesInPath =
            await getAllFilesInPath(dir.path, showHidden: showHidden);
      } catch (e) {
        allFilesInPath = [];
        print(e);
      }
      files.addAll(allFilesInPath);
    }
    return files;
  }

  static Future<List<FileSystemEntity>> getRecentFiles(
      {bool showHidden = false}) async {
    List<FileSystemEntity> files = await getAllFiles(showHidden: showHidden);
    files.sort((a, b) => File(a.path)
        .lastAccessedSync()
        .compareTo(File(b.path).lastAccessedSync()));
    return files.reversed.toList();
  }

  static Future<List<FileSystemEntity>> searchFiles(String query,
      {bool showHidden = false}) async {
    List<Directory> storage = await getStorageList();
    List<FileSystemEntity> files = <FileSystemEntity>[];
    for (Directory dir in storage) {
      List fs = await getAllFilesInPath(dir.path, showHidden: showHidden);
      for (FileSystemEntity fs in fs) {
        if (basename(fs.path).toLowerCase().contains(query.toLowerCase())) {
          files.add(fs);
        }
      }
    }
    return files;
  }

  /// Get all files
  static Future<List<FileSystemEntity>> getAllFilesInPath(String path,
      {bool showHidden = false}) async {
    List<FileSystemEntity> files = <FileSystemEntity>[];
    Directory d = Directory(path);
    List<FileSystemEntity> l = d.listSync();
    for (FileSystemEntity file in l) {
      if (FileSystemEntity.isFileSync(file.path)) {
        if (!showHidden) {
          if (!file.isHidden) {
            files.add(file);
          }
        } else {
          files.add(file);
        }
      } else {
        if (!file.path.contains('/storage/emulated/0/Android')) {
//          print(file.path);
          if (!showHidden) {
            if (!file.isHidden) {
              files.addAll(
                  await getAllFilesInPath(file.path, showHidden: showHidden));
            }
          } else {
            files.addAll(
                await getAllFilesInPath(file.path, showHidden: showHidden));
          }
        }
      }
    }
//    print(files);
    return files;
  }

  static String formatTime(String iso) {
    DateTime date = DateTime.parse(iso);
    DateTime now = DateTime.now();
    DateTime yDay = DateTime.now().subtract(const Duration(days: 1));
    DateTime dateFormat = DateTime.parse(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T00:00:00.000Z');
    DateTime today = DateTime.parse(
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T00:00:00.000Z');
    DateTime yesterday = DateTime.parse(
        '${yDay.year}-${yDay.month.toString().padLeft(2, '0')}-${yDay.day.toString().padLeft(2, '0')}T00:00:00.000Z');

    if (dateFormat == today) {
      return 'Today ${DateFormat('HH:mm').format(DateTime.parse(iso))}';
    } else if (dateFormat == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(DateTime.parse(iso))}';
    } else {
      return DateFormat('MMM dd, HH:mm').format(DateTime.parse(iso));
    }
  }

  static List<FileSystemEntity> sortList(
      List<FileSystemEntity> list, int sort) {
    switch (sort) {
      /// Sort by name
      case 0:
        list.sort((f1, f2) => basename(f1.path)
            .toLowerCase()
            .compareTo(basename(f2.path).toLowerCase()));
        break;

      case 1:
        list.sort((f1, f2) => basename(f2.path)
            .toLowerCase()
            .compareTo(basename(f1.path).toLowerCase()));
        break;

      /// Sort by date
      case 2:
        list.sort((FileSystemEntity f1, FileSystemEntity f2) =>
            f1.statSync().modified.compareTo(f2.statSync().modified));
        break;

      case 3:
        list.sort((FileSystemEntity f1, FileSystemEntity f2) =>
            f2.statSync().modified.compareTo(f1.statSync().modified));
        break;

      /// sort by size
      case 4:
        list.sort((FileSystemEntity f1, FileSystemEntity f2) =>
            f2.statSync().size.compareTo(f1.statSync().size));
        break;

      case 5:
        list.sort((FileSystemEntity f1, FileSystemEntity f2) =>
            f1.statSync().size.compareTo(f2.statSync().size));
        break;

      default:
        list.sort();
    }

    return list;
  }

  /// check weather FileSystemEntity is File
  /// return true if FileSystemEntity is File else returns false
  static bool isFile(FileSystemEntity entity) {
    return (entity is File);
  }

// check weather FileSystemEntity is Directory
  /// return true if FileSystemEntity is a Directory else returns Directory
  static bool isDirectory(FileSystemEntity entity) {
    return (entity is Directory);
  }

  /// Get the basename of Directory or File.
  ///
  /// Provide [File], [Directory] or [FileSystemEntity] and returns the name as a [String].
  ///
  /// ie:
  /// ```dart
  /// controller.basename(dir);
  /// ```
  /// to hide the extension of file, showFileExtension = flase
  static String basename(dynamic entity, {bool showFileExtension = true}) {
    if (entity is! FileSystemEntity) return "";

    final pathSegments = entity.path.split('/');
    final filename = pathSegments.last;

    if (showFileExtension) return filename;

    return showFileExtension ? filename.split('.').first : filename;
  }

  /*static const int base = 1024;
  static const List<String> suffix = [
    'Bytes',
    'KB',
    'MB',
    'GB',
    'TB',
    'PB',
    'EB',
    'ZB',
    'YB'
  ];
  static const List<int> powBase = [
    1,
    1024,
    1048576,
    1073741824,
    1099511627776
  ];

  /// Format bytes to human readable string.
  static String formatBytes(int bytes, [int precision = 2]) {
    final base = (bytes == 0) ? 0 : (log(bytes) / log(1024)).floor();
    final size = bytes / powBase[base];
    final formattedSize = size.toStringAsFixed(precision);
    return '$formattedSize ${suffix[base]}';
  }*/

  /// Convert Byte to KB, MB, .......
  static String formatBytes(bytes, [int decimals = 2]) {
    if (bytes == 0) return '0.0 KB';
    var k = 1024,
        dm = decimals <= 0 ? 0 : decimals,
        sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'],
        i = (log(bytes) / log(k)).floor();
    final formattedSize = ((bytes / pow(k, i)).toStringAsFixed(dm));

    return '$formattedSize ${sizes[i]}';
  }

  static String formatBytesToMb(BigInt bytes) {
    double mb = bytes / BigInt.from(1024 * 1024);
    return mb.toStringAsFixed(2); // Keeps 2 decimal places
  }

  //type: 0-leading or 1-trailing
  static String stripSeparators(String path, [int type = 0]) {
    assert((type == 0) || (type == 1));
    const String seps = '/\\';

    int startIndex = 0;
    int endIndex = path.length;

    if (type == 0) {
      // Find the start index
      while (startIndex < endIndex && seps.contains(path[startIndex])) {
        startIndex++;
      }
    }

    if (type == 1) {
      // Find the end index
      while (endIndex > startIndex && seps.contains(path[endIndex - 1])) {
        endIndex--;
      }
    }

    return path.substring(startIndex, endIndex);
  }

  static String fixPathSeparators(String filePath) {
    return filePath.replaceAll(
        path.separator == '/' ? '\\' : '/', path.separator);
  }

  // Append paths without duplicating separator
  static String appendPaths(String p1, String p2, [String? sep]) {
    String filePath = p1;
    if (!p1.endsWith('\\') &&
        !p1.endsWith('/') &&
        !p2.startsWith('\\') &&
        !p2.startsWith('/')) {
      filePath += (sep ?? path.separator);
    }
    filePath += p2;

    return fixPathSeparators(filePath);
  }

  static String appendUrls(String p1, String p2) {
    String filePath = p1;
    if (!p1.endsWith('\\') &&
        !p1.endsWith('/') &&
        !p2.startsWith('\\') &&
        !p2.startsWith('/')) {
      filePath += '/';
    }
    filePath += p2;

    return filePath.replaceAll('\\', '/');
  }

  /// Returns a map of storage root -> { 'total': <bytes>, 'free': <bytes> }
  static Future<Map<String, Map<String, int>>> getDiskUsage() async {
    try {
      // storage_info API differs across platforms and package versions.
      // Return an empty map here; platforms can implement a richer
      // implementation if needed.
      return <String, Map<String, int>>{};
    } catch (e) {
      logE('Error getting disk usage: $e');
      return <String, Map<String, int>>{};
    }
  }

  static Future<BigInt> getFileSize(String? path) async {
    if (path == null || path.isEmpty) return BigInt.zero;

    File file = File(path);
    if (await file.exists()) {
      FileStat stat = await file.stat();
      return BigInt.from(stat.size);
    }

    return BigInt.zero;
  }

  /// Creates the directory if it doesn't exist.
  static Future<bool> fileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return await File(path).exists();
  }

  static bool fileExistsSync(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  /// Creates the directory if it doesn't exist.
  static Future<void> createFolder(String currentPath, String name) async {
    String newPath = path.join(currentPath, name);
    await Directory(newPath).create();
  }

  static Future<File> moveFile(File sourceFile, String newPath) async {
    try {
      // prefer using rename as it is probably faster
      return await sourceFile.rename(newPath);
    } on FileSystemException catch (e) {
      // if rename fails, copy the source file and then delete it
      final newFile = await sourceFile.copy(newPath);
      await sourceFile.delete();
      return newFile;
    }
  }

  static Future<bool> deleteFileEx(String strFileName, bool bRename) async {
    return await deleteFile(File(strFileName), bRename);
  }

  static Future<bool> deleteFile(File sourceFile, bool bRename) async {
    try {
      await sourceFile.delete();
      return true;
    } catch (e) {
      logE('Error delete file: $e');
    }
    if (bRename) {
      String newFileName = path.join(path.dirname(sourceFile.path),
          '${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.obs');

      await moveFile(sourceFile, newFileName);
      return true;
    }

    return false;
  }

  static Future<void> deleteDirectory(String path) async {
    final directory = Directory(path);
    try {
      // 设置 recursive: true 以删除文件夹及其所有内容
      await directory.delete(recursive: true);
      logI('Delete folder successfully: ${directory.path}');
    } catch (e) {
      logE('''delete folder '$path' error: $e''');
    }
  }

  /********************************************************************/
  /*																	*/
  /* Function name : makeSureDirectoryPathExists						*/
  /* Description   : This function creates all the directories in		*/
  /*				   the specified DirPath, beginning with the root.	*/
  /*				   This is a clone a Microsoft function with the	*/
  /*			       same name.										*/
  /*																	*/
  /// *****************************************************************
  static Future<bool> makeSureDirectoryPathExists(String path) async {
    var dir = Directory(path);
    if (await dir.exists()) {
      return true;
    }

    await dir
        .create(recursive: true)
        .then((Directory directory) =>
            print('Directory created: ${directory.path}'))
        .catchError((e) => logE('Error creating directory: $e'));

    return true;
  }

  static bool makeSureDirectoryPathExistsSync(String path) {
    var dir = Directory(path);
    if (dir.existsSync()) {
      return true;
    }

    dir
        .create(recursive: true)
        .then((Directory directory) =>
            print('Directory created: ${directory.path}'))
        .catchError((e) => logE('Error creating directory: $e'));

    return true;
  }

  /// Return file extension as String.
  ///
  /// ie:- `File("/../image.png")` to `"png"`
  static String getFileExtension(FileSystemEntity file) {
    if (file is File) {
      return file.path.split("/").last.split('.').last;
    } else {
      throw "FileSystemEntity is Directory, not a File";
    }
  }

  static String removeBackslash(String p) {
    if (p.endsWith(path.separator)) p = p.substring(0, p.length - 1);
    return p;
  }

  static String replaceDCMWildcard(String str,
      {String? appPath, String? cscPath}) {
    String? szAppPath = appPath;
    if (isBlank(szAppPath)) {
      szAppPath = App().dataPath;
    } else {
      szAppPath = FileUtils.removeBackslash(szAppPath!);
    }
    if (isBlank(cscPath)) {
      cscPath = DCMGlobal.cscPath;
    } else {
      cscPath = FileUtils.removeBackslash(cscPath!);
    }
    if (str.contains('\$(AppPath)')) {
      str = str.replaceAll('\$(AppPath)', szAppPath);
    }
    if (str.contains('\$(CSCPath)')) {
      str = str.replaceAll('\$(CSCPath)', cscPath);
    }
    /*if (str.contains('\$(PFPath)\\')){
      str = str.replaceAll('\$(PFPath)\\', FileMisc::GetPFPath());
    }
    if (str.contains('\$(PFx86Path)\\')){
      str = str.replaceAll('\$(PFx86Path)\\', FileMisc::GetPFx86Path());
    }*/

    /*if (str.contains('\$(PFPath)/')){
      str = str.replaceAll('\$(PFPath)/', FileMisc::GetPFPath());
    }
    if (str.contains('\$(PFx86Path)/')){
      str = str.replaceAll('\$(PFx86Path)/', FileMisc::GetPFx86Path());
    }

    if (str.contains('\$(UserName)')) {
      static String szUserName = '';
      if (szUserName.IsEmpty())
        GetSystemDomainUserName(szUserName);
      str = str.replaceAll('\$(UserName)', szUserName);
    }*/

    return str;
  }

  static Future<String> validFilePath(
      String strFile, String strDefault, bool bFile,
      [String? strAppPath]) async {
    if (strFile.isEmpty) {
      strFile = strDefault;
    }

    strFile = replaceDCMWildcard(strFile, appPath: strAppPath);
    if (bFile) {
      return await File(strFile).exists() ? strFile : strDefault;
    } else {
      if (!await makeSureDirectoryPathExists(strFile)) {
        strFile = strDefault;
        await makeSureDirectoryPathExists(strDefault);
      }
      return strFile;
    }
  }

  static String validFilePathSync(String strFile, String strDefault, bool bFile,
      [String? strAppPath]) {
    if (strFile.isEmpty) {
      strFile = strDefault;
    }

    strFile = replaceDCMWildcard(strFile, appPath: strAppPath);
    if (bFile) {
      return File(strFile).existsSync() ? strFile : strDefault;
    } else {
      if (!makeSureDirectoryPathExistsSync(strFile)) {
        strFile = strDefault;
        makeSureDirectoryPathExistsSync(strDefault);
      }
      return strFile;
    }
  }

  static bool isUNCPath(String szPath) {
    if (szPath.length < 2) {
      return false;
    }

    return (szPath.startsWith('\\\\'));
  }

  static String getShortPath(String strFilePath, String strContentRoot) {
    String strSrc = '';
    if (strContentRoot.isEmpty) {
      strSrc = path.basename(strFilePath);
    } else {
      String strPath = strFilePath;
      String strPreImage = strPath.substring(0, 8);
      if (strPreImage.toLowerCase() == 'file:///') {
        strPath = strPath.substring(8);
      } else {
        strPreImage = strPath.substring(0, 7);
        if (strPreImage.toLowerCase() == 'file://') {
          strPath = strPath.substring(7);
        }
      }
      strPath = strPath.replaceAll(
          path.separator == '/' ? '\\' : '/', path.separator);
      strPath = strPath.replaceAll('%20', ' ');
      if (isUNCPath(strPath)) {
        strPath = strPath.substring(2);
      }
      path.canonicalize(strPath);

      String strContentPath = strContentRoot;
      strContentPath = strContentPath.replaceAll('/', path.separator);
      if (isUNCPath(strContentPath)) {
        strContentPath = strContentPath.substring(2);
      }
      path.canonicalize(strContentPath);
      if (path.isWithin(strContentPath, strPath)) {
        strSrc = path.relative(strPath, from: strContentPath);
      } else {
        strSrc = path.basename(strPath);
      }
    }

    return strSrc;
  }
}
