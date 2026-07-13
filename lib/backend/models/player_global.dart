import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player.dart';
import 'package:dcm/backend/net/dcm_http_client.dart';
import 'package:dcm/backend/net/play_log_post.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/net/player_task_file.dart';
import 'package:dcm/backend/services/player_register_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:path/path.dart' as path;

/// Global player instance shared across the app.
final Player globalPlayer = Player();

Future<bool> initGlobalPlayer() async {
  if (await loadSettings()) {
    await getPlayerRegInfo();
    await getPublicIP();
    PlayerRegisterImpl.updateNetworkInfo(globalPlayer);
  } else {
    autoRegister();
  }

  return false;
}

Future<bool> getPlayerRegInfo() async {
  if (DCMGlobal.cmsUrl.isEmpty) {
    return false;
  }

  final strGetRegInfoHttpLink =
      '${fADDSLASH(DCMGlobal.cmsUrl)}$cmsPLAYERSITEURL';
  final guidReg = globalPlayer.guidReg;
  final strUniqueName = globalPlayer.strUniqueName;
  final strRequest =
      guidReg.isEmpty ? '$cHTTPUNIQUEKEY=$strUniqueName' : 'guidReg=$guidReg';
  logI('''Http link: '$strGetRegInfoHttpLink'; Request: '$strRequest'.''');

  String strLink = '$strGetRegInfoHttpLink?$strRequest';
  strLink = Utils.addCMSParam(strLink);

  final result = await httpGet(strLink);
  if (result.status) {
    final strResult = result.result ?? '';
    if (strResult.length > 16 &&
        strResult.toLowerCase() != 'record not found') {
      final playerReg = XmlFile('PlayerRegisterInformation');
      if (playerReg.loadXml(strResult)) {
        final xi = playerReg.getItem('Player');
        if (xi != null) {
          try {
            final strLogPost = xi.getItemValue('dwLogPost');
            final logPostValue = int.tryParse(strLogPost, radix: 16) ?? 0;
            PlayLogPostService.processLogPostFlag(logPostValue);
            final lastSyncTime = xi.getItemValueD('m_dtLastSyncTime');
            if (lastSyncTime != null) {
              PlayerTaskFile.dtSyncTime = lastSyncTime;
            }
          } catch (e) {
            logE('getPlayerRegInfo parse error: $e');
          }

          final previousAddress = globalPlayer.strAddress;
          globalPlayer.getFromXML(xi);
          globalPlayer.guidReg = '';

          if (previousAddress != globalPlayer.strAddress) {
            final strAppPath = App().dataPath;
            final strDCMSites = path.join(strAppPath, 'dcmsites.dat');
            if (PlayerRegisterImpl.serializePlayer(
                globalPlayer, strDCMSites, true)) {
              await PlayerRegisterImpl.genBusNumberFile(
                  strAppPath, globalPlayer.strUniqueName);
              PlayerRegisterImpl.changeComputerName(globalPlayer, true);

              final strLocalFile =
                  path.join(DCMGlobal.ftpSettingPath, 'dcmsites.dat');
              await File(strDCMSites).copy(strLocalFile);
            } else {
              logE('Failed to serialize player settings to dcmsites.dat');
            }
          }
          return true;
        } else {
          logE('Xml parse error, player item not found in response');
        }
      } else {
        logE('Xml parse error.');
      }
    } else if (guidReg.isEmpty) {
      //not register, start to auto register
      return autoRegister();
    }
  } else {
    logE('Http request failed: ${result.result}');
  }

  return false;
}

Future<bool> getPublicIP() async {
  String? strPublicIP = await httpGetPublicIP();
  if (strPublicIP != null && strPublicIP.isNotEmpty) {
    globalPlayer.strPublicIP = strPublicIP;
  } else {
    globalPlayer.strPublicIP = globalPlayer.strLocalAddress;
  }

  return globalPlayer.strPublicIP.isNotEmpty;
}

Future<({bool status, String? result})> httpGet(String url) async {
  final client = DcmHttpClient(
    baseUrl: Utils.apiBaseUrl(url),
    timeout: const Duration(seconds: 15),
    defaultHeaders: {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    },
  );

  try {
    final response = await client.get(
      Utils.apiPath(url),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
    );
    return (
      status: response.statusCode >= 200 && response.statusCode < 300,
      result: response.body,
    );
  } catch (e) {
    logE('''httpGet '$url' error: $e''');
    return (status: false, result: e.toString());
  } finally {
    client.close();
  }
}

Future<String?> httpGetPublicIP() async {
  String strResult = '';
  if (DCMGlobal.cmsUrl.isEmpty) {
    return null;
  }

  String strGetPublicIPHttpLink = DCMGlobal.cmsUrl;
  strGetPublicIPHttpLink = fADDSLASH(strGetPublicIPHttpLink);
  strGetPublicIPHttpLink += cmsPLAYERIPURL;
  strGetPublicIPHttpLink = Utils.addCMSParam(strGetPublicIPHttpLink, true);
  var result = await httpGet(strGetPublicIPHttpLink);
  if (result.status) {
    strResult = result.result ?? '';
    if (strResult.isNotEmpty && Utils.isValidIPAddress(strResult)) {
      return strResult;
    }
  }

  return null;
}

Future<bool> loadSettings() async {
  try {
    final filePath = path.join(App().dataPath, 'dcmsites.dat');
    final file = File(filePath);
    if (await file.exists()) {
      if (await globalPlayer.loadSettings(filePath)) {
        return globalPlayer.strUniqueName.isNotEmpty;
      }
    }
  } catch (_) {
    // ignore
  }

  return false;
}

Future<bool> autoRegister() async {
  logI('try to auto registering player.');
  try {
    if (await PlayerRegisterImpl.autoRegister(false)) {
      await globalPlayer.loadSettings();
      return true;
    }
    logE('Auto Register failure.');
  } catch (e) {
    logE('Auto Register throw exception: $e');
  }
  return false;
}

Map<String, dynamic> snapshotPlayer() {
  return {
    'strUniqueName': globalPlayer.strUniqueName,
    'sServerName': globalPlayer.sServerName,
    'strAddress': globalPlayer.strAddress,
    'strLogin': globalPlayer.strLogin,
    'strPassword': globalPlayer.strPassword,
    'nPort': globalPlayer.nPort,
    'strDeviceID': globalPlayer.strDeviceID,
    'strMACID': globalPlayer.strMACID,
    'strPublicIP': globalPlayer.strPublicIP,
    'strLocalAddress': globalPlayer.strLocalAddress,
    'strLocation': globalPlayer.strLocation,
    'strDescription': globalPlayer.strDescription,
    'strName': globalPlayer.strName,
    'nRetries': globalPlayer.nRetries,
    'nRetryDelay': globalPlayer.nRetryDelay,
    'nSyncPeriod': globalPlayer.nSyncPeriod,
    'nBeforeDay': globalPlayer.nBeforeDay,
    'bBinary': globalPlayer.bBinary,
    'bUsePASVMode': globalPlayer.bUsePASVMode,
  };
}

void applyWorkerPlayer(Map<String, dynamic>? m) {
  if (m == null) return;
  try {
    globalPlayer.strUniqueName =
        m['strUniqueName'] ?? globalPlayer.strUniqueName;
    globalPlayer.sServerName = m['sServerName'] ?? globalPlayer.sServerName;
    globalPlayer.strAddress = m['strAddress'] ?? globalPlayer.strAddress;
    globalPlayer.strLogin = m['strLogin'] ?? globalPlayer.strLogin;
    globalPlayer.strPassword = m['strPassword'] ?? globalPlayer.strPassword;
    globalPlayer.nPort = (m['nPort'] is int) ? m['nPort'] : globalPlayer.nPort;
    globalPlayer.strDeviceID = m['strDeviceID'] ?? globalPlayer.strDeviceID;
    globalPlayer.strMACID = m['strMACID'] ?? globalPlayer.strMACID;
    globalPlayer.strPublicIP = m['strPublicIP'] ?? globalPlayer.strPublicIP;
    globalPlayer.strLocalAddress =
        m['strLocalAddress'] ?? globalPlayer.strLocalAddress;
    globalPlayer.strLocation = m['strLocation'] ?? globalPlayer.strLocation;
    globalPlayer.strDescription =
        m['strDescription'] ?? globalPlayer.strDescription;
    globalPlayer.strName = m['strName'] ?? globalPlayer.strName;
    globalPlayer.nRetries =
        (m['nRetries'] is int) ? m['nRetries'] : globalPlayer.nRetries;
    globalPlayer.nRetryDelay =
        (m['nRetryDelay'] is int) ? m['nRetryDelay'] : globalPlayer.nRetryDelay;
    globalPlayer.nSyncPeriod =
        (m['nSyncPeriod'] is int) ? m['nSyncPeriod'] : globalPlayer.nSyncPeriod;
    globalPlayer.nBeforeDay =
        (m['nBeforeDay'] is int) ? m['nBeforeDay'] : globalPlayer.nBeforeDay;
    globalPlayer.bBinary = m['bBinary'] ?? globalPlayer.bBinary;
    globalPlayer.bUsePASVMode = m['bUsePASVMode'] ?? globalPlayer.bUsePASVMode;
  } catch (_) {
    // ignore malformed data.
  }
}
