import 'dart:collection';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

enum PlayLogPostFlag {
  playLog(0x00000001),
  playlistLog(0x00000002),
  usbLog(0x00000004),
  msgLog(0x00000008),
  ahPlayLog(0x00000010),
  apPlayLog(0x00000020),
  usbDtlLog(0x00000040),
  syncDtlLog(0x00000080),
  playerLog1(0x00000100),
  playerLog2(0x00000200),
  comLog(0x00000400),
  formatLog(0x00000800),
  ddeLog(0x00001000),
  contentLog(0x00002000);

  const PlayLogPostFlag(this.value);
  final int value;
}

// --- Data Models ---

class LogPostSettings {
  DateTime lastPlayLogUpload = DateTime(1970);
  DateTime lastUSBLogPost = DateTime(1970);
  DateTime lastAHPlayLogPost = DateTime(1970);
  DateTime lastAPPlayLogPost = DateTime(1970);
  DateTime lastCOMLogPost = DateTime(1970);
  DateTime lastPlaylistLogPost = DateTime(1970);
  DateTime lastMSGLogPost = DateTime(1970);
  DateTime lastUSBDTLLogPost = DateTime(1970);
  DateTime lastDDELogPost = DateTime(1970);
  DateTime lastPlayerLog2Post = DateTime(1970);

  void resetIfOlderThanToday(DateTime today) {
    final startOfToday = DateTime(today.year, today.month, today.day);
    if (lastPlayLogUpload.isBefore(startOfToday)) {
      lastPlayLogUpload = DateTime(1970);
    }
    if (lastUSBLogPost.isBefore(startOfToday)) lastUSBLogPost = DateTime(1970);
    if (lastAHPlayLogPost.isBefore(startOfToday)) {
      lastAHPlayLogPost = DateTime(1970);
    }
    if (lastAPPlayLogPost.isBefore(startOfToday)) {
      lastAPPlayLogPost = DateTime(1970);
    }
    if (lastCOMLogPost.isBefore(startOfToday)) lastCOMLogPost = DateTime(1970);
    if (lastPlaylistLogPost.isBefore(startOfToday)) {
      lastPlaylistLogPost = DateTime(1970);
    }
    if (lastMSGLogPost.isBefore(startOfToday)) lastMSGLogPost = DateTime(1970);
    if (lastUSBDTLLogPost.isBefore(startOfToday)) {
      lastUSBDTLLogPost = DateTime(1970);
    }
    if (lastDDELogPost.isBefore(startOfToday)) lastDDELogPost = DateTime(1970);
    if (lastPlayerLog2Post.isBefore(startOfToday)) {
      lastPlayerLog2Post = DateTime(1970);
    }
  }
}

class PlayLogPostService {
  PlayLogPostService({
    this.uniqueName = '',
    this.playerName = '',
    this.logUploadInterval = 10,
    this.logUploadPeriod = 7,
    this.httpClientFactory,
  });

  static bool bPlayLogPost = false;
  static bool bAHPlayLogPost = false;
  static bool bUSBLogPost = false;
  static bool bUSBDTLLogPost = false;
  static bool bAPPlayLogPost = false;
  static bool bCOMLogPost = false;
  static bool bMSGLogPost = false;
  static bool bPlaylistLogPost = false;
  static bool bDDELogPost = false;
  static int logPostFlags = 0;

  // Folder paths (simulated indices from C++ m_pFolders)
  static List<String> logFolders = [];

  final String uniqueName;
  final String playerName;
  final int logUploadInterval;
  final int logUploadPeriod;
  final DcmHttpClientFactory? httpClientFactory;

  static final Map<String, int> _mapLogRetries = <String, int>{};
  final Queue<String> _pendingUploads = Queue<String>();
  DateTime? _lastPlayerLog2Post;
  int _playerLog2RetryCount = 0;

  static bool _bStartupTime =
      false; // true: successful to player log post at startup

  static int _nPlayerLogRetryCnt = 0;
  static int _nShutdownLogRetryCnt = 0;
  static int _nPlayerLog2RetryCnt = 0;

  static String strPublicIP = globalPlayer.strPublicIP;
  static String strDeviceID = globalPlayer.strDeviceID;
  static String strMACID = globalPlayer.strMACID;

  static String strVerInfo = '';
  static String strImportVersion = '';
  static String strPlaylistVersion = '';

  static bool isEnabled(PlayLogPostFlag flag) =>
      (logPostFlags & flag.value) > 0;

  static final LogPostSettings logPostSettings = LogPostSettings();

  static bool serialize(bool bStoring) {
    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'ftplog.xml');

    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    xmlProfile.loadProfile(szRootItemName: 'FTPLog');
    if (bStoring) {
      xmlProfile.writeProfileDateTime('FTPLog', 'LastPlayLogUpload',
          logPostSettings.lastPlayLogUpload); //dtStartUpload);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastUSBLogPost', logPostSettings.lastUSBLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastAHPlayLogPost', logPostSettings.lastAHPlayLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastAPPlayLogPost', logPostSettings.lastAPPlayLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastCOMLogPost', logPostSettings.lastCOMLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastPlaylistLogPost', logPostSettings.lastPlaylistLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastMSGLogPost', logPostSettings.lastMSGLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastUSBDTLLogPost', logPostSettings.lastUSBDTLLogPost);
      xmlProfile.writeProfileDateTime(
          'FTPLog', 'LastDDELogPost', logPostSettings.lastDDELogPost);
      return xmlProfile.saveProfile();
    } else {
      DateTime dtDefa = fromOleDateTime(0.00);
      logPostSettings.lastPlayLogUpload =
          xmlProfile.getProfileDateTime('FTPLog', 'LastPlayLogUpload', dtDefa);
      logPostSettings.lastUSBLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastUSBLogPost', dtDefa);
      logPostSettings.lastAHPlayLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastAHPlayLogPost', dtDefa);
      logPostSettings.lastAPPlayLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastAPPlayLogPost', dtDefa);
      logPostSettings.lastCOMLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastCOMLogPost', dtDefa);
      logPostSettings.lastPlaylistLogPost = xmlProfile.getProfileDateTime(
          'FTPLog', 'LastPlaylistLogPost', dtDefa);
      logPostSettings.lastMSGLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastMSGLogPost', dtDefa);
      logPostSettings.lastUSBDTLLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastUSBDTLLogPost', dtDefa);
      logPostSettings.lastDDELogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastDDELogPost', dtDefa);
    }

    return true;
  }

  static void processLogPostFlag(int dwLogPost) {
    logPostFlags = dwLogPost;
    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'ftplog.xml');

    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    xmlProfile.loadProfile(szRootItemName: 'FTPLog');
    {
      DateTime dtDefa = fromOleDateTime(
          0.00); //DateTime::GetCurrentTime() - Duration(1, 0, 0, 0);
      logPostSettings.lastPlayLogUpload =
          xmlProfile.getProfileDateTime('FTPLog', 'LastPlayLogUpload', dtDefa);
      logPostSettings.lastAHPlayLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastAHPlayLogPost', dtDefa);
      logPostSettings.lastAPPlayLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastAPPlayLogPost', dtDefa);
      logPostSettings.lastUSBLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastUSBLogPost', dtDefa);
      logPostSettings.lastCOMLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastCOMLogPost', dtDefa);
      logPostSettings.lastPlaylistLogPost = xmlProfile.getProfileDateTime(
          'FTPLog', 'LastPlaylistLogPost', dtDefa);
      logPostSettings.lastMSGLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastMSGLogPost', dtDefa);
      logPostSettings.lastUSBDTLLogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastUSBDTLLogPost', dtDefa);
      logPostSettings.lastPlayerLog2Post =
          xmlProfile.getProfileDateTime('FTPLog', 'LastPlayerLog2Post', dtDefa);
      logPostSettings.lastDDELogPost =
          xmlProfile.getProfileDateTime('FTPLog', 'LastDDELogPost', dtDefa);

      DateTime dtCurr = DateTime.now();
      DateTime dtPost =
          DateTime(dtCurr.year, dtCurr.month, dtCurr.day, 0, 0, 0);
      if (logPostSettings.lastPlayLogUpload.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.playLog.value) > 0) {
          xmlProfile.writeProfileDateTime(
              'FTPLog', 'LastPlayLogUpload', dtCurr);
          logPostSettings.lastPlayLogUpload = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastPlayLogUpload.year,
            logPostSettings.lastPlayLogUpload.month,
            logPostSettings.lastPlayLogUpload.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.playLog.value) == 0) {
            xmlProfile.writeProfileDateTime(
                'FTPLog', 'LastPlayLogUpload', dtDefa);
            logPostSettings.lastPlayLogUpload = dtDefa;
          }
        }
      }

      if (logPostSettings.lastAHPlayLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.ahPlayLog.value) > 0) {
          xmlProfile.writeProfileDateTime(
              'FTPLog', 'LastAHPlayLogPost', dtCurr);
          logPostSettings.lastAHPlayLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastAHPlayLogPost.year,
            logPostSettings.lastAHPlayLogPost.month,
            logPostSettings.lastAHPlayLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.ahPlayLog.value) == 0) {
            xmlProfile.writeProfileDateTime(
                'FTPLog', 'LastAHPlayLogPost', dtDefa);
            logPostSettings.lastAHPlayLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastAPPlayLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.apPlayLog.value) > 0) {
          xmlProfile.writeProfileDateTime(
              'FTPLog', 'LastAPPlayLogPost', dtCurr);
          logPostSettings.lastAPPlayLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastAPPlayLogPost.year,
            logPostSettings.lastAPPlayLogPost.month,
            logPostSettings.lastAPPlayLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.apPlayLog.value) == 0) {
            xmlProfile.writeProfileDateTime(
                'FTPLog', 'LastAPPlayLogPost', dtDefa);
            logPostSettings.lastAPPlayLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastCOMLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.comLog.value) > 0) {
          xmlProfile.writeProfileDateTime('FTPLog', 'LastCOMLogPost', dtCurr);
          logPostSettings.lastCOMLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastCOMLogPost.year,
            logPostSettings.lastCOMLogPost.month,
            logPostSettings.lastCOMLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.comLog.value) == 0) {
            xmlProfile.writeProfileDateTime('FTPLog', 'LastCOMLogPost', dtDefa);
            logPostSettings.lastCOMLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastPlaylistLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.playlistLog.value) > 0) {
          xmlProfile.writeProfileDateTime(
              'FTPLog', 'LastPlaylistLogPost', dtCurr);
          logPostSettings.lastPlaylistLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastPlaylistLogPost.year,
            logPostSettings.lastPlaylistLogPost.month,
            logPostSettings.lastPlaylistLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.playlistLog.value) == 0) {
            xmlProfile.writeProfileDateTime(
                'FTPLog', 'LastPlaylistLogPost', dtDefa);
            logPostSettings.lastPlaylistLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastUSBLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.usbLog.value) > 0) {
          xmlProfile.writeProfileDateTime('FTPLog', 'LastUSBLogPost', dtCurr);
          logPostSettings.lastUSBLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastUSBLogPost.year,
            logPostSettings.lastUSBLogPost.month,
            logPostSettings.lastUSBLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.usbLog.value) == 0) {
            xmlProfile.writeProfileDateTime('FTPLog', 'LastUSBLogPost', dtDefa);
            logPostSettings.lastUSBLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastMSGLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.msgLog.value) > 0) {
          xmlProfile.writeProfileDateTime('FTPLog', 'LastMSGLogPost', dtCurr);
          logPostSettings.lastMSGLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastMSGLogPost.year,
            logPostSettings.lastMSGLogPost.month,
            logPostSettings.lastMSGLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.msgLog.value) == 0) {
            xmlProfile.writeProfileDateTime('FTPLog', 'LastMSGLogPost', dtDefa);
            logPostSettings.lastMSGLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastUSBDTLLogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.usbDtlLog.value) > 0) {
          xmlProfile.writeProfileDateTime(
              'FTPLog', 'LastUSBDTLLogPost', dtCurr);
          logPostSettings.lastUSBDTLLogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastUSBDTLLogPost.year,
            logPostSettings.lastUSBDTLLogPost.month,
            logPostSettings.lastUSBDTLLogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.usbDtlLog.value) == 0) {
            xmlProfile.writeProfileDateTime(
                'FTPLog', 'LastUSBDTLLogPost', dtDefa);
            logPostSettings.lastUSBDTLLogPost = dtDefa;
          }
        }
      }

      if (logPostSettings.lastDDELogPost.isBefore(dtPost)) {
        if ((dwLogPost & PlayLogPostFlag.ddeLog.value) > 0) {
          xmlProfile.writeProfileDateTime('FTPLog', 'LastDDELogPost', dtCurr);
          logPostSettings.lastDDELogPost = dtPost;
        }
      } else {
        DateTime dtLog = DateTime(
            logPostSettings.lastDDELogPost.year,
            logPostSettings.lastDDELogPost.month,
            logPostSettings.lastDDELogPost.day,
            0,
            0,
            0);
        if (dtLog == dtPost) {
          if ((dwLogPost & PlayLogPostFlag.ddeLog.value) == 0) {
            xmlProfile.writeProfileDateTime('FTPLog', 'LastDDELogPost', dtDefa);
            logPostSettings.lastDDELogPost = dtDefa;
          }
        }
      }

      xmlProfile.saveProfile();
      if (logPostSettings.lastPlaylistLogPost.isAfter(dtDefa)) {
        logI('Request Playlist log');
      }

      if (logPostSettings.lastUSBDTLLogPost.isAfter(dtDefa)) {
        logI('Request USB log in detail');
      }

      if (logPostSettings.lastMSGLogPost.isAfter(dtDefa)) {
        logI('Request Message log');
      }

      if (logPostSettings.lastUSBLogPost.isAfter(dtDefa)) {
        logI('Request USB log');
      }

      if (logPostSettings.lastCOMLogPost.isAfter(dtDefa)) {
        logI('Request COM log');
      }

      if (logPostSettings.lastAPPlayLogPost.isAfter(dtDefa)) {
        logI('Request 3G ad-hoc Playlog');
      }

      if (logPostSettings.lastAHPlayLogPost.isAfter(dtDefa)) {
        logI('Request ad-hoc Playlog');
      }

      if (logPostSettings.lastPlayLogUpload.isAfter(dtDefa)) {
        logI('Request Playlog in detail');
      }

      if (logPostSettings.lastDDELogPost.isAfter(dtDefa)) {
        logI('Request DDE download log in detail');
      }
    }
  }

  static bool hasLogPost() {
    DateTime dtEnd;
    DateTime dtStart;
    DateTime dtToday = DateTime.now();
    dtStart = dtToday.subtract(const Duration(days: 1));
    dtEnd = dtToday.copyWith(hour: 23, minute: 59, second: 59);
    dtStart = dtStart.copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    bPlayLogPost = ((logPostFlags & PlayLogPostFlag.playLog.value) > 0 &&
        (logPostSettings.lastPlayLogUpload.compareTo(dtStart) >= 0 &&
            logPostSettings.lastPlayLogUpload.compareTo(dtEnd) <= 0)); //
    bUSBLogPost = ((logPostFlags & PlayLogPostFlag.usbLog.value) > 0 &&
        (logPostSettings.lastUSBLogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastUSBLogPost.compareTo(dtEnd) <= 0));
    bAHPlayLogPost = ((logPostFlags & PlayLogPostFlag.ahPlayLog.value) > 0 &&
        (logPostSettings.lastAHPlayLogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastAHPlayLogPost.compareTo(dtEnd) <= 0));
    bAPPlayLogPost = ((logPostFlags & PlayLogPostFlag.apPlayLog.value) > 0 &&
        (logPostSettings.lastAPPlayLogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastAPPlayLogPost.compareTo(dtEnd) <= 0));
    bMSGLogPost = ((logPostFlags & PlayLogPostFlag.msgLog.value) > 0 &&
        (logPostSettings.lastMSGLogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastMSGLogPost.compareTo(dtEnd) <= 0));
    bPlaylistLogPost =
        ((logPostFlags & PlayLogPostFlag.playlistLog.value) > 0 &&
            (logPostSettings.lastPlaylistLogPost.compareTo(dtStart) >= 0 &&
                logPostSettings.lastPlaylistLogPost.compareTo(dtEnd) <= 0));
    bCOMLogPost = ((logPostFlags & PlayLogPostFlag.comLog.value) > 0 &&
        (logPostSettings.lastCOMLogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastCOMLogPost.compareTo(dtEnd) <= 0));
    bUSBDTLLogPost = ((logPostFlags & PlayLogPostFlag.usbDtlLog.value) > 0 &&
        (logPostSettings.lastUSBDTLLogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastUSBDTLLogPost.compareTo(dtEnd) <= 0));
    bDDELogPost = ((logPostFlags & PlayLogPostFlag.ddeLog.value) > 0 &&
        (logPostSettings.lastDDELogPost.compareTo(dtStart) >= 0 &&
            logPostSettings.lastDDELogPost.compareTo(dtEnd) <= 0));

    return (bPlayLogPost ||
        bUSBLogPost ||
        bAHPlayLogPost ||
        bCOMLogPost ||
        bAPPlayLogPost ||
        bMSGLogPost ||
        bPlaylistLogPost ||
        bUSBDTLLogPost);
  }

  static bool hasPlayLogPost() {
    if (serialize(false)) {
      DateTime dtEnd;
      DateTime dtStart;
      DateTime dtToday = DateTime.now();
      //dtEnd = dtToday + DateTime(1, 0, 0, 0);
      dtStart = dtToday.subtract(const Duration(days: 1));
      dtEnd = dtToday.copyWith(hour: 23, minute: 59, second: 59);
      dtStart = dtStart.copyWith(
          hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

      //return (dtStartUpload >= dtStart && dtStartUpload <= dtEnd);
      bPlayLogPost = ((logPostFlags & PlayLogPostFlag.playLog.value) > 0 &&
          (logPostSettings.lastPlayLogUpload.compareTo(dtStart) >= 0 &&
              logPostSettings.lastPlayLogUpload.compareTo(dtEnd) <= 0)); //
      bUSBLogPost = ((logPostFlags & PlayLogPostFlag.usbLog.value) > 0 &&
          (logPostSettings.lastUSBLogPost.compareTo(dtStart) >= 0 &&
              logPostSettings.lastUSBLogPost.compareTo(dtEnd) <= 0));
    }

    return bPlayLogPost;
  }

  static Future<bool> hasAHPlayLogPost() async {
    bool bAHPlayLogPost = false;
    if ((logPostFlags & PlayLogPostFlag.ahPlayLog.value) > 0) {
      //DateTime dtStart;
      DateTime dtToday = DateTime.now();
      String strLogPath = logFolders[1];
      String strLogPost = DateFormat('yyyyMMdd000000')
          .format(dtToday); //dtToday.Format('%Y%m%d000000');
      Directory dir = Directory(strLogPath);
      if (await dir.exists()) {
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is File &&
              !path.extension(entity.path).toLowerCase().endsWith('.xml')) {
            if (path
                    .basenameWithoutExtension(entity.path)
                    .compareTo(strLogPost) <
                0) {
              bAHPlayLogPost = true;
              break;
            }
          }
        }
      }
    }

    return bAHPlayLogPost;
  }

  static String buildPlayerLogRequest(
    String baseRequest,
    String syncTimeValue,
    PlayLogPostFlag logFlag,
    String strUniqueName,
    String strPlayer,
  ) {
    final buffer = StringBuffer(baseRequest);
    if (!buffer.toString().contains('strUniqueName=')) {
      buffer.write('&strUniqueName=$strUniqueName');
    }
    if (!buffer.toString().contains('strPlayer=')) {
      buffer.write('&strPlayer=$strPlayer');
    }
    if (!buffer.toString().contains('dtLastSyncTime=')) {
      buffer.write('&dtLastSyncTime=$syncTimeValue');
    }
    if (logFlag == PlayLogPostFlag.playerLog2) {
      buffer.write('&logFlag=PLAYERLOG2_POST');
    }
    return buffer.toString();
  }

  static Future<bool> updatePlayerLog({required String request}) async {
    if (!isEnabled(PlayLogPostFlag.playerLog1)) {
      return true;
    }

    final cmsUrl = DCMGlobal.cmsUrl;
    if (cmsUrl.isEmpty) {
      return false;
    }
    String link = cmsUrl;
    link = fADDSLASH(link);
    link += cmsPLAYERLOGURL;
    link = Utils.addCMSParam(link);

    final client = dcmHttpClientFactory.clientFor(
      baseUrl: Utils.apiBaseUrl(link),
      timeout: const Duration(seconds: 15),
      defaultHeaders: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
      },
    );

    try {
      final response = await client.postString(
        Utils.apiPath(link),
        body: Utils.urlEscape(request),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
        },
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      logE('PlayLogPostService.updatePlayerLog error: $e');
      return false;
    }
  }

  static Future<bool> updatePlayerLog2Retry({
    required String request,
  }) async {
    _nPlayerLog2RetryCnt++;
    String strResult = '';
    String strRequest1 = Utils.urlEscape(request);

    String strCMSLink = DCMGlobal.cmsUrl;
    strCMSLink = fADDSLASH(strCMSLink);
    strCMSLink += cmsPLAYERLOG2URL;
    strCMSLink += ('?$strRequest1');
    strCMSLink = Utils.addCMSParam(strCMSLink);

    var result = await PlayerLogFile.httpPostAction(strCMSLink, '');
    if (result.status) {
      strResult = result.result ?? '';
      if (strResult.equalsIgnoreCase('Successful')) {
        DateTime dtCurr = DateTime.now();
        logPostSettings.lastPlayerLog2Post = dtCurr.copyWith(
            hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

        String strFileName = path.join(DCMGlobal.ftpSettingPath, 'ftplog.xml');
        XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
        if (xmlProfile.loadProfile(szRootItemName: 'FTPLog')) {
          xmlProfile.writeProfileDateTime('FTPLog', 'LastPlayerLog2Post',
              logPostSettings.lastPlayerLog2Post);
          xmlProfile.saveProfile();
        }

        return true;
      }
    }
    return false;
  }

  bool isSyncTimePost({int maxRetries = 3}) {
    if (_lastPlayerLog2Post == null) {
      return true;
    }

    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastPostDay = DateTime(
      _lastPlayerLog2Post!.year,
      _lastPlayerLog2Post!.month,
      _lastPlayerLog2Post!.day,
    );
    if (lastPostDay.isBefore(today) && _playerLog2RetryCount < maxRetries) {
      return false;
    }
    return true;
  }

  static bool isPlayerLog2Post({int maxRetries = 3}) {
    if ((logPostFlags & PlayLogPostFlag.playerLog2.value) == 0) {
      return false;
    }

    DateTime dtCurr = DateTime.now();
    DateTime dtPost = dtCurr.copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    if (logPostSettings.lastPlayerLog2Post.isBefore(dtPost) &&
        _nPlayerLog2RetryCnt < DCMGlobal.httpRetryTimes) {
      return true;
    }

    return false;
  }

  Future<bool> uploadPendingLogs() async {
    if (_pendingUploads.isEmpty) {
      return true;
    }

    var success = true;
    while (_pendingUploads.isNotEmpty) {
      final item = _pendingUploads.removeFirst();
      final ok = await updatePlayerLog(request: item);
      success &= ok;
    }
    return success;
  }

  void enqueueUpload(String url) {
    _pendingUploads.addLast(url);
  }

  String _resolveUrl(String url, String request) {
    if (request.isEmpty) {
      return url;
    }
    if (url.contains('?')) {
      return '$url&$request';
    }
    return '$url?$request';
  }

  static void updateShutdown() async {
    if (!isEnabled(PlayLogPostFlag.playerLog1)) {
      return;
    }
    if (_nShutdownLogRetryCnt > DCMGlobal.httpRetryTimes) {
      return;
    }
    _nShutdownLogRetryCnt++;

    String strLogPath =
        path.join(DCMGlobal.logPath, 'PlayerLog'); //Settings.m_strLogPath;
    Directory dir = Directory(strLogPath);
    if (await dir.exists()) {
      await for (FileSystemEntity entity in dir.list(recursive: false)) {
        if (entity is File &&
            !path.extension(entity.path).toLowerCase().endsWith('.txt')) {
          logI('''Find Player log file: '${entity.path}'.''');
          try {
            var logFile = File(entity.path);
            String strRequest = await logFile.readAsString();
            logI(
                '''Load Player log file: '${entity.path}' successful; Content: $strRequest''');
            if (strRequest.isNotEmpty &&
                strRequest
                    .substring(0, cHTTPUNIQUEKEY.length)
                    .equalsIgnoreCase(cHTTPUNIQUEKEY)) {
              if (await updatePlayerLog(request: strRequest)) {
                logI('''Upate Player log file: '${entity.path}' successful.''');
                FileUtils.deleteFile(logFile, false);
              } else {
                logI('''Upate Player log file: '${entity.path}' failure.''');
              }
            } else {
              FileUtils.deleteFile(logFile, false);
            }
          } catch (e) {
            logE('Failed to read Player log file: ${entity.path}. Error: $e');
          }
        }
      }
    }
  }

  static void updateContentLog(String strUniqueName, String strPlayer) async {
    if (!isEnabled(PlayLogPostFlag.contentLog)) {
      return;
    }

    String strLogPath =
        path.join(DCMGlobal.logPath, 'ContentLog'); //Settings.m_strLogPath;
    Directory dir = Directory(strLogPath);
    if (await dir.exists()) {
      await for (FileSystemEntity entity in dir.list(recursive: false)) {
        if (entity is File &&
            !path.extension(entity.path).toLowerCase().endsWith('.xml')) {
          await httpPostContentLog(
              entity.path,
              path.basenameWithoutExtension(entity.path),
              strUniqueName,
              strPlayer);
        }
      }
    }
  }

  static Future<int> httpPostContentLog(String strFilePath, String strFileName,
      String strUniqueName, String strPlayer) async {
    String? strContentLog;
    try {
      strContentLog = await File(strFilePath).readAsString();
    } catch (e) {
      logE('Failed to read Content log file: $strFilePath. Error: $e');
    }

    if (strContentLog == null || !strContentLog.contains('<FileList')) {
      await File(strFilePath).delete();
      return 1;
    }
    if (_mapLogRetries.containsKey(strFilePath) &&
        _mapLogRetries[strFilePath]! >= DCMGlobal.httpRetryTimes) {
      _mapLogRetries.remove(strFilePath);

      await File(strFilePath).delete();
      return 1;
    }

    String strContentLogApi = DCMGlobal.cmsUrl;
    strContentLogApi = fADDSLASH(strContentLogApi);
    strContentLogApi += cmsCONTENTLOGURL;
    String strContentLogLink =
        '$strContentLogApi?$cHTTPUNIQUEKEY=$strUniqueName'; // % strContentLogApi % HTTP_UNIQUE_KEY % strUniqueName;
    strContentLogLink = Utils.addCMSParam(strContentLogLink);

    int nRes = 0;
    String strResult = 'HTTP Post failure';
    var result =
        await PlayerLogFile.httpPostAction(strContentLogLink, strContentLog);
    if (result.status) {
      strResult = result.result!;
      if (strResult.equalsIgnoreCase('Successful')) {
        if (_mapLogRetries.containsKey(strFilePath)) {
          _mapLogRetries.remove(strFilePath);
        }

        await File(strFilePath).delete();
        nRes = 1;
      } else {
        if (_mapLogRetries.containsKey(strFilePath)) {
          _mapLogRetries[strFilePath] = _mapLogRetries[strFilePath]! + 1;
        } else {
          _mapLogRetries[strFilePath] = 1;
        }
      }
    } else {
      if (_mapLogRetries.containsKey(strFilePath)) {
        _mapLogRetries.remove(strFilePath);
      }

      await File(strFilePath).delete();
    }
    logI('''Upate Content log file: '$strFilePath' $strResult.''');

    return nRes;
  }

  static void updateDCMUpdateLog(String strUniqueName, String strPlayer) async {
    String strLogPath =
        path.join(DCMGlobal.logPath, 'DCMUpdateLog'); //Settings.m_strLogPath;

    try {
      Directory dir = Directory(strLogPath);
      if (await dir.exists()) {
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is File &&
              !path.extension(entity.path).toLowerCase().endsWith('.xml')) {
            await httpPostPatchUpdateLog(
                entity.path,
                path.basenameWithoutExtension(entity.path),
                strUniqueName,
                strPlayer);
          }
        }
      }
    } catch (e) {
      logE('Failed to process DCMUpdateLog files in $strLogPath. Error: $e');
    }
  }

  static Future<int> httpPostPatchUpdateLog(String strFilePath,
      String strFileName, String strUniqueName, String strPlayer) async {
    XmlFile playerReg = XmlFile('PlayLogList');
    if (!playerReg.load(strFilePath)) {
      await File(strFilePath).delete();
      return -1;
    }

    XmlItem? pLogItem = playerReg.getItem('PlayLog');
    if (pLogItem == null) {
      playerReg.close();

      await File(strFilePath).delete();
      return -1;
    }

    DateTime dtUpdateDate =
        fromDateTimeFormat(strFileName, 1) ?? DateTime.now();
    String strMessage =
        '''$cDCMXMLHEADEREX<PlayLog $cHTTPUNIQUEKEY="$strUniqueName" strPlayer="$strPlayer" organization="${DCMGlobal.organization}" 
    strBatch="${pLogItem.getItemValue('strBatch')}" strResult="${pLogItem.getItemValue('strResult')}" dtUpdateDate="${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtUpdateDate)}"/>''';
    playerReg.close();

    String patchUpdateLogHTTP = DCMGlobal.cmsUrl;
    patchUpdateLogHTTP = fADDSLASH(patchUpdateLogHTTP);
    patchUpdateLogHTTP += cmsCONTENTLOGURL;
    String strContentLogLink =
        '$patchUpdateLogHTTP?$cHTTPUNIQUEKEY=$strUniqueName'; // % strContentLogApi % HTTP_UNIQUE_KEY % strUniqueName;
    strContentLogLink = Utils.addCMSParam(strContentLogLink);

    int nRes = 0;
    String strResult = 'HTTP Post failure';
    var result =
        await PlayerLogFile.httpPostAction(strContentLogLink, strMessage);
    if (result.status) {
      strResult = result.result!;
      if (strResult.equalsIgnoreCase('Successful')) {
        await File(strFilePath).delete();
        nRes = 1;
      }
    } else {
      await File(strFilePath).delete();
    }
    logI('''Upate Patch update log file: '$strFilePath' $strResult''');

    return nRes;
  }

  static Future<bool> updateAPUpdateLog(String strUniqueName, String strPlayer,
      String strBatch, String strTask, String strAPResult, int nStatus) async {
    DateTime dtUpdateDate = DateTime.now();
    String strMessage =
        '''$cDCMXMLHEADEREX<PlayLogList><PlayLog $cHTTPUNIQUEKEY="$strUniqueName" strPlayerName="$strPlayer" organization="${DCMGlobal.organization}" 
    strBatch="$strBatch" strTask="$strTask" strResult="$strAPResult" nStatus="$nStatus" dtUpdateDate="${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtUpdateDate)}"/></PlayLogList>''';

    String strRootHttpLink = DCMGlobal.cmsUrl;
    strRootHttpLink = fADDSLASH(strRootHttpLink);
    strRootHttpLink += cmsCONTENTLOGURL;
    String strContentLogLink =
        '$strRootHttpLink?$cHTTPUNIQUEKEY=$strUniqueName'; // % strContentLogApi % HTTP_UNIQUE_KEY % strUniqueName;
    strContentLogLink = Utils.addCMSParam(strContentLogLink);

    int nRes = 0;
    String strResult = 'HTTP Post failure';
    var result =
        await PlayerLogFile.httpPostAction(strRootHttpLink, strMessage);
    if (result.status) {
      strResult = result.result!;
      if (strResult.equalsIgnoreCase('Successful')) {
        nRes = 1;
      }
    }

    return nRes > 0;
  }

  static void updatePlayerLogRetry() async {
    if (!_bStartupTime && _nPlayerLogRetryCnt < DCMGlobal.httpRetryTimes) {
      String strRequest =
          '''$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&dtStartup=${DateFormat('yyyy-MM-dd HH:mm:ss').format(App().dtStartup)}
        &strPublicIP=$strPublicIP&strDCMVersion=$strVerInfo&strUSBPlugin=$strImportVersion&strPlaylistVersion=$strPlaylistVersion''';
      _bStartupTime = await updatePlayerLog(request: strRequest);
      _nPlayerLogRetryCnt++;
    }
  }

  static void updatePlayerLog2() async {
    if (isPlayerLog2Post()) {
      var diskUsage = await FileUtils.getDiskUsage();
      String strRequest =
          '''$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&dtLastSyncTime=${DateFormat('yyyy-MM-dd HH:mm:ss').format(PlayerTaskFile.dtSyncTime)}
      &strMACID=$strMACID&strDeviceID=$strDeviceID&strMACAddress=${globalPlayer.strMACAddress}&strMACAddress1=${globalPlayer.strMACAddress1}&nUsedSpace=%.2f''';

      await updatePlayerLog2Retry(request: strRequest);
    }
  }
}
