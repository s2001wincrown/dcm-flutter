import 'dart:collection';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
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
  ddeLog(0x00001000);

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
  }) {
    _flags = <PlayLogPostFlag, bool>{};
    for (final flag in PlayLogPostFlag.values) {
      _flags![flag] = false;
    }
  }

  final String uniqueName;
  final String playerName;
  final int logUploadInterval;
  final int logUploadPeriod;
  final DcmHttpClientFactory? httpClientFactory;

  Map<PlayLogPostFlag, bool>? _flags;
  final Map<String, int> _retryCounts = <String, int>{};
  final Queue<String> _pendingUploads = Queue<String>();
  DateTime? _lastPlayerLog2Post;
  int _playerLog2RetryCount = 0;

  bool isEnabled(PlayLogPostFlag flag) => _flags?[flag] ?? false;

  static final LogPostSettings logPostSettings = LogPostSettings();

  static void processLogPostFlag(int dwLogPost) {
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

  String buildPlayerLogRequest(
    String baseRequest,
    String syncTimeValue,
    PlayLogPostFlag logFlag,
  ) {
    final buffer = StringBuffer(baseRequest);
    if (!buffer.toString().contains('strUniqueName=')) {
      buffer.write('&strUniqueName=$uniqueName');
    }
    if (!buffer.toString().contains('strPlayer=')) {
      buffer.write('&strPlayer=$playerName');
    }
    if (!buffer.toString().contains('dtLastSyncTime=')) {
      buffer.write('&dtLastSyncTime=$syncTimeValue');
    }
    if (logFlag == PlayLogPostFlag.playerLog2) {
      buffer.write('&logFlag=PLAYERLOG2_POST');
    }
    return buffer.toString();
  }

  Future<bool> updatePlayerLog({
    required String url,
    required String request,
    PlayLogPostFlag flag = PlayLogPostFlag.playerLog1,
  }) async {
    if (!isEnabled(flag)) {
      return true;
    }

    final encodedRequest = Utils.urlEscape(request);
    final resolvedUrl = _resolveUrl(url, encodedRequest);

    try {
      final client = (httpClientFactory ?? dcmHttpClientFactory).clientFor(
        baseUrl: Utils.apiBaseUrl(resolvedUrl),
        timeout: const Duration(seconds: 15),
        defaultHeaders: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
        },
      );
      final response = await client.postString(
        Utils.apiPath(resolvedUrl),
        body: '',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
        },
      );
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (ok) {
        _retryCounts.remove(flag.name);
      } else {
        _retryCounts[flag.name] = (_retryCounts[flag.name] ?? 0) + 1;
      }
      return ok;
    } catch (e) {
      logE('PlayLogPostService.updatePlayerLog error: $e');
      _retryCounts[flag.name] = (_retryCounts[flag.name] ?? 0) + 1;
      return false;
    }
  }

  Future<bool> updatePlayerLogCms({required String request}) async {
    final cmsUrl = DCMGlobal.cmsUrl;
    if (cmsUrl.isEmpty) {
      return false;
    }
    String link = cmsUrl;
    link = fADDSLASH(link);
    link += cmsPLAYERLOGURL;
    link = Utils.addCMSParam(link);

    final client = (httpClientFactory ?? dcmHttpClientFactory).clientFor(
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
      logE('PlayLogPostService.updatePlayerLogCms error: $e');
      return false;
    }
  }

  Future<bool> updatePlayerLog2({
    required String url,
    required String request,
  }) async {
    _playerLog2RetryCount++;
    final encodedRequest = Utils.urlEscape(request);
    final resolvedUrl = _resolveUrl(url, encodedRequest);

    try {
      final client = (httpClientFactory ?? dcmHttpClientFactory).clientFor(
        baseUrl: Utils.apiBaseUrl(resolvedUrl),
        timeout: const Duration(seconds: 15),
        defaultHeaders: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
        },
      );
      final response = await client.postString(
        Utils.apiPath(resolvedUrl),
        body: '',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastPlayerLog2Post = DateTime.now();
        return true;
      }
      return false;
    } catch (e) {
      logE('PlayLogPostService.updatePlayerLog2 error: $e');
      return false;
    }
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

  bool isPlayerLog2Post({int maxRetries = 3}) {
    if (_lastPlayerLog2Post == null) {
      return false;
    }

    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastPostDay = DateTime(
      _lastPlayerLog2Post!.year,
      _lastPlayerLog2Post!.month,
      _lastPlayerLog2Post!.day,
    );
    if (lastPostDay.isBefore(today) && _playerLog2RetryCount < maxRetries) {
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
      final ok = await updatePlayerLog(
        url: item,
        request: item,
        flag: PlayLogPostFlag.playerLog1,
      );
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
}
