import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlprofile.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

const String cHTTPUNIQUEKEY = 'strUniqueName';
const int cTRANSFERSTATUS = -5;
const int cTRANSFERERR = -1;
const int cTRANSFEROTHERERR = -2;
const int cTRANSFEROTHERMSG = -4;
const int cTRANSFERFILECOUNT = -20;
const int cTRANSFERSUCCESS = 0;
const int cTRANSFERRETRYERR = -3;

// use globalPlayer from player_global.dart

// --------------------------------------------------------------------------
// 1. PlayerLogFile 实现
// --------------------------------------------------------------------------

class PlayerLogFile {
  static bool bSyncFail = false;
  static String strJob = '';
  static String strStatus = '';

  // 静态变量模拟
  static DateTime dtDownloadStartTime = DateTime.now();
  static DateTime dtStartSync = DateTime.now();
  static BigInt nTotalBytesDownloaded = BigInt.zero;
  static BigInt nTotalBytesToDownload = BigInt.zero;
  static BigInt nFileDownloaded = BigInt.zero;
  static int nUpdateCookie = 0; // 使用时间戳毫秒
  static int nUpdateInterval = 60000;

  static String strLogPath = '';

  // 重置日志文件
  static void reset() {
    String strTaskFile = path.join(DCMGlobal.settingPath, 'synctask.xml');
    File file = File(strTaskFile);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  // 打开日志文件并初始化
  static Future<bool> openLogFile(PlayerJobItem pJob,
      [bool bClear = false]) async {
    if (pJob.nRetryCount == 0) {
      logI('Starting download!', syncTag);
    }

    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'ftperror.xml');

    // 模拟临界区锁 (Dart 是单线程事件循环，但在异步操作中需注意原子性，此处简化)
    if (bClear && await File(strFileName).exists()) {
      await File(strFileName).delete();
    }

    // 这里应该使用 XML 库，为了演示逻辑，我们构建一个简单的 Map 结构代表 XML 内容
    // 实际项目中推荐使用 package:xml
    bool bOK = true;
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    if (!xmlProfile.loadProfile(szRootItemName: 'FTPError')) {
      bOK = xmlProfile.createProfile('FTPError');
    }

    if (bOK) {
      if (pJob.nRetryCount > 0) {
        //String strSec;
        //strSec.Format('Retry-%d', pJob.nRetryCount);
        //xmlProfile.appendSection(strSec);
        xmlProfile.writeProfileInt(
            'DownloadSetting', 'RetryCount', pJob.nRetryCount);
      } else {
        xmlProfile.setItemValue('strUniqueName', globalPlayer.strUniqueName);
        xmlProfile.setItemValue('strTask', pJob.strJobItem);
        xmlProfile.writeProfileDateTime(
            'DownloadSetting', 'DownloadSpecialTime', dtStartSync);
        dtDownloadStartTime = DateTime.now();
        xmlProfile.writeProfileDateTime(
            'DownloadSetting', 'DownloadStartTime', dtDownloadStartTime);
        xmlProfile.writeProfileDateTime(
            'DownloadSetting', 'DownloadEndTime', DateTime.now());
        xmlProfile.writeProfileString(
            'DownloadSetting', 'DownloadStatus', 'Starting download!');
        xmlProfile.writeProfileInt(
            'DownloadSetting', 'DownloadContent', pJob.dwSyncContent);
        xmlProfile.writeProfileInt(
            'DownloadSetting', 'TotalSize', nTotalBytesToDownload.toInt());
        xmlProfile.writeProfileString(
            'DownloadSetting', 'TaskName', pJob.strJobItem);
        xmlProfile.writeProfileString(
            'DownloadSetting', 'TaskTime', pJob.strJobTime);
        xmlProfile.writeProfileString(
            'DownloadSetting', 'FTPContent', pJob.strSyncContent);
        xmlProfile.writeProfileString(
            'DownloadSetting', 'OtherInfo', pJob.strOtherInfo);

        String strRequest =
            '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$strJob&dtStartTime=${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtDownloadStartTime)}';
        updateSyncStatus(strRequest);
      }

      return xmlProfile.saveProfile('FtpError.xsl');
    }

    return bOK;
  }

  // 写入日志
  static Future<void> writeLogFile(int nType, String str,
      {String fileTitle = '',
      int contentType = -1,
      bool bUpdateStatus = true}) async {
    strStatus = str;

    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'ftperror.xml');
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    bool bOK = true;
    if (!xmlProfile.loadProfile(szRootItemName: 'FTPError')) {
      bOK = xmlProfile.createProfile('FTPError');
    }
    if (bOK) {
      xmlProfile.writeProfileString(
          'DownloadSetting', 'DownloadStatus', 'Downloading!');
      xmlProfile.writeProfileString('DownloadSetting', 'DownloadProgress', str);
      xmlProfile.writeProfileInt(
          'DownloadSetting', 'Downloaded', nTotalBytesDownloaded.toInt());
      xmlProfile.writeProfileInt(
          'DownloadSetting', 'FilesDownloaded', nFileDownloaded.toInt());
      if (nTotalBytesToDownload > BigInt.zero) {
        xmlProfile.writeProfileInt(
            'DownloadSetting', 'TotalSize', nTotalBytesToDownload.toInt());
      }

      XiType nXIType = XiType.attrib;
      if (nType == cTRANSFERERR) {
        bSyncFail = true;
        XmlItem? nSec = xmlProfile.getSection('ErrorItems');
        if (nSec != null) {
          XmlItem? pItem = nSec.addItem('ErrorItem');
          if (pItem != null) {
            pItem.addItem('Error', str, nXIType);
            pItem.addItem('File', fileTitle, nXIType);
            pItem.addItem('ContentType', contentType, nXIType);
          }
        }
      } else if (nType == cTRANSFEROTHERERR) {
        XmlItem? nSec = xmlProfile.getSection('OtherErrorItems');
        if (nSec != null) {
          XmlItem? pItem = nSec.addItem('OtherErrorItem');
          if (pItem != null) {
            pItem.addItem('OtherError', str, nXIType);
          }
        }
        bSyncFail = true;
      } else if (nType == cTRANSFEROTHERMSG) {
        XmlItem? nSec = xmlProfile.getSection('OtherMessageItems');
        if (nSec != null) {
          XmlItem? pItem = nSec.addItem('OtherMessageItem');
          if (pItem != null) {
            pItem.addItem('OtherMessage', str, nXIType);
          }
        }
      } else if (nType == cTRANSFERFILECOUNT) {
        xmlProfile.writeProfileString(
            'DownloadSetting', 'DownloadFileCount', str);
      } else if (nType == cTRANSFERSUCCESS) {
        XmlItem? nSec = xmlProfile.getSection('SuccessItems');
        if (nSec != null) {
          XmlItem? pItem = nSec.addItem('SuccessItem');
          if (pItem != null) {
            pItem.addItem('Success', str, nXIType);
            pItem.addItem('File', fileTitle, nXIType);
            pItem.addItem('ContentType', contentType, nXIType);
          }
        }
      } else if (nType == cTRANSFERRETRYERR) {
        XmlItem? nSec = xmlProfile.getSection('RetriesErrorItems');
        if (nSec != null) {
          XmlItem? pItem = nSec.addItem('RetriesErrorItem');
          if (pItem != null) {
            pItem.addItem('RetriesError', str, nXIType);
          }
        }
      } else if (nType == 99999) {
        xmlProfile.writeProfileString('DownloadSetting', 'OtherInfo', str);
      }

      xmlProfile.saveProfile('FtpError.xsl');
      xmlProfile.close();
    }

    if (nType != cTRANSFEROTHERMSG) {
      //nType != TRANSFEROTHERERR &&
      if (bUpdateStatus) {
        String strRequest =
            '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$strJob&strStatus=$strStatus&nTotalSize=$nTotalBytesToDownload&nDownloaded=$nTotalBytesDownloaded&dtStartTime=${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtDownloadStartTime)}';
        updateSyncStatus(strRequest);
      }
    }
  }

  // 关闭日志文件
  static Future<bool> closeLogFile(String pStatus,
      {bool bFinished = true}) async {
    strStatus = pStatus;
    logI(pStatus);

    String strFileName = path.join(DCMGlobal.ftpSettingPath, 'ftperror.xml');
    XmlProfile xmlProfile = XmlProfile.fromFile(strFileName);
    bool bOK = true;
    if (!xmlProfile.loadProfile(szRootItemName: 'FTPError')) {
      bOK = xmlProfile.createProfile('FTPError');
    }
    if (bOK) {
      xmlProfile.writeProfileString(
          'DownloadSetting', 'DownloadStatus', pStatus);
      xmlProfile.writeProfileDateTime(
          'DownloadSetting', 'DownloadEndTime', DateTime.now());
      String strXmlLog = '';
      if (bFinished || strStatus.contains('Transfer Failure')) {
        strXmlLog = xmlProfile.export();
      }

      xmlProfile.saveProfile('FtpError.xsl');
      xmlProfile.close();

      String strStatusEscape = Utils.urlEscape(strStatus);
      String strRequest;
      if (bFinished) {
        String strLogPath = path.join(DCMGlobal.logPath, 'FTPlog');
        FileUtils.makeSureDirectoryPathExists(strLogPath);
        String strLogFile = path.join(strLogPath,
            '${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.xml');
        await FileUtils.moveFile(File(strFileName), strLogFile);

        strRequest =
            '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$strJob&strStatus=$strStatusEscape&dtEndTime=${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}';
      } else {
        strRequest =
            '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$strJob&strStatus=$strStatusEscape';
      }
      updateSyncStatus(strRequest);

      if (bFinished || strStatus.contains('Transfer Failure')) {
        var strCMSLink = DCMGlobal.cmsUrl;
        strCMSLink = fADDSLASH(strCMSLink);
        strCMSLink += cmsSyncSTATUSURL;
        strCMSLink = Utils.addCMSParam(strCMSLink);
        await PlayerLogFile.httpPostAction(strCMSLink, strXmlLog);
      }

      return true;
    }

    return false;
  }

  // 定时更新状态
  static Future<void> timeForSyncStatusUpdate() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - nUpdateCookie > nUpdateInterval) {
      String strStatusEscape = Utils.urlEscape(strStatus);
      String szRequest =
          '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$strJob&strStatus=$strStatusEscape&nTotalSize=$nTotalBytesToDownload&nDownloaded=$nTotalBytesDownloaded';
      await updateSyncStatus(szRequest);
    }
  }

  static void resetSyncStatus() {
    //TCHAR szRequest[1024];
    String szRequest =
        '$cHTTPUNIQUEKEY=${globalPlayer.strUniqueName}&strTask=$strJob&strStatus=Reset&nTotalSize=0&nDownloaded=0&dtEndTime=${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}';
    //wxString strRequest;
    //strRequest.Format(_T("%s=%s&strTask=%s&strStatus=%s&nTotalSize=%llu&nDownloaded=%llu"), HTTP_UNIQUE_KEY, m_FtpSite.m_strUniqueName, m_strJob, _T("Reset"), 0, 0, COleDateTime::GetCurrentTime().Format(_T("%Y-%m-%d %H:%M:%S")));
    updateSyncStatus(szRequest);
  }

  // 更新 Sync 状态 (HTTP POST)
  static Future<bool> updateSyncStatus(String szRequest) async {
    // 检查是否使用 CMS Backend
    return updateCMSSyncStatus(szRequest);
  }

  static Future<bool> updateCMSSyncStatus(String szRequest) async {
    var contentSyncStatusUpdateUrl = DCMGlobal.cmsUrl;
    contentSyncStatusUpdateUrl = fADDSLASH(contentSyncStatusUpdateUrl);
    contentSyncStatusUpdateUrl += cmsSyncSTATUSURL;

    //update status to CMS
    String strCMSRequest = szRequest;
    strCMSRequest = strCMSRequest.replaceAll(' ', '+');
    String strCMSLink = contentSyncStatusUpdateUrl;
    if (!strCMSRequest.startsWithIgnoreCase('<?xml')) {
      strCMSLink = '$contentSyncStatusUpdateUrl?$strCMSRequest';
      strCMSRequest = '';
    }
    strCMSLink = Utils.addCMSParam(strCMSLink);
    var result = await httpPostAction(strCMSLink, strCMSRequest);
    if (result.status) {
      if (result.result!.equalsIgnoreCase('Successful')) {
        nUpdateCookie = DateTime.now().millisecondsSinceEpoch;

        return true;
      }
    }
    logE('Sync log update failure\n', syncTag);

    return false;
  }

  //content type: "Content-Type: application/xml; charset=utf-8"
  //Content-Type: application/json; charset=utf-8
  //application/x-www-form-urlencoded; charset=UTF-8
  static Future<({bool status, String? result})> httpPostAction(
      String url, String request,
      [String? contentType]) async {
    final client = dcmHttpClientFactory.clientFor(
      baseUrl: _baseUrl(url),
      timeout: const Duration(seconds: 15),
      defaultHeaders: {
        'Content-Type':
            contentType ?? 'application/x-www-form-urlencoded; charset=UTF-8'
      },
    );
    try {
      if (request.isNotEmpty) {
        final response = await client.postString(
          _path(url),
          body: request,
          headers: {
            'Content-Type': contentType ??
                'application/x-www-form-urlencoded; charset=UTF-8'
          },
        );
        logI(
            '''httpPostAction '$url', response: ${response.statusCode} - ${response.body}''',
            syncTag);
        return (
          status: response.statusCode >= 200 && response.statusCode < 300,
          result: response.body
        );
      } else {
        final response = await client.get(
          url,
          headers: {
            'Content-Type': contentType ??
                'application/x-www-form-urlencoded; charset=UTF-8'
          },
        );
        logI(
            '''httpPostAction '$url', response: ${response.statusCode} - ${response.body}''',
            syncTag);
        return (
          status: response.statusCode >= 200 && response.statusCode < 300,
          result: response.body
        );
      }
    } catch (e) {
      logE('''httpPostAction '$url' error: $e''', syncTag);
      return (status: false, result: null);
    }
  }

  static String _baseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '';
    }
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String _path(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '';
    }
    return uri.path.isEmpty ? '/' : uri.path;
  }
}
