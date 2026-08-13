import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/player.dart';
import 'package:dcm/backend/net/player_log_file.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// --- Error Codes ---

class RegErrorCodes {
  static const String cSUCCESS = "Successful";
  static const String cE001 = "E001"; // Incorrect Bus Number
  static const String cE002 = "E002";
  static const String cE003 = "E003";
  static const String cE004 = "E004";
  static const String cE005 = "E005"; // Time Out
  static const String cE006 = "E006"; // Network Disconnected
  static const String cE007 = "E007"; // Max registration process
  static const String cE008 = "E008";
  static const String cE009 = "E009";
  static const String cE999 = "E999"; // Unknown
}

// --- Main Implementation ---

class PlayerRegisterImpl {
  static const String lpszSignature =
      "DCM FTP Manager Version 1.00- StoreObject";
  static const String _dcmsitesFileName = 'dcmsites.dat';
  static const String serverConfigFileName =
      'Server.txt'; // Simulating INI with JSON or simple Map for Flutter

  String? _lastErrorCode;
  int? _lastErrorId;

  String? get lastErrorCode => _lastErrorCode;
  int? get lastErrorId => _lastErrorId;

  /// Reset local registration data
  static Future<void> reset() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_dcmsitesFileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Serialize/Deserialize Player data to/from encrypted XML file
  static ({bool status, XmlFile? playerFile}) serialize(
      Player player, String strFile, bool bStoring) {
    XmlFile? playerFile;
    if (bStoring) {
      XmlFilePro playerReg = XmlFilePro('PlayerRegisterInformation');
      if (playerReg.newNode('Player', null)) {
        XmlItem? xi = playerReg.getItem('Player');
        if (xi != null) {
          player.writeToXML(xi);
        }
      }

      var xiPlayer = playerReg.getItem('Player');
      if (xiPlayer != null) {
        playerFile = XmlFile('Player');
        var pPlayerItem = playerFile.root();
        pPlayerItem.copy(xiPlayer, true);
      }

      playerReg.setSignature(lpszSignature);
      //playerReg.Export(strOutputXML);

      // encrypt prior to setting checkout status and file info (so these are visible without decryption)
      // this simply fails if password is empty
      playerReg.encrypt(Encodes.cCONTENTFILECRYPTKEY);

      return (status: playerReg.save(strFile), playerFile: playerFile);
    } else {
      XmlFilePro file =
          XmlFilePro('PlayerRegisterInformation', Encodes.cCONTENTFILECRYPTKEY);
      if (!file.open(strFile, XfOpen.read)) {
        return (status: false, playerFile: null);
      }

      if (file.loadEx()) {
        var xiPlayer = file.getItem('Player');
        if (xiPlayer != null) {
          playerFile = XmlFile('Player');
          var pPlayerItem = playerFile.root();
          pPlayerItem.copy(xiPlayer, true);
        }

        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == lpszSignature) {
          // get site data
          var xi = file.getItem('Player');
          if (xi != null) {
            player.getFromXML(xi);
          }

          return (status: true, playerFile: playerFile);
        }
      }
      return (status: false, playerFile: null);
    }
  }

  /********************************************************************/
  /*																	*/
  /* Function name : Serialize										*/
  /* Description   : Call this function to store/load the site data	*/
  /*																	*/
  /// *****************************************************************
  static bool serializePlayer(Player player, String strFile, bool bStoring) {
    if (bStoring) {
      XmlFilePro playerReg = XmlFilePro('PlayerRegisterInformation');
      if (playerReg.newNode('Player', null)) {
        var xi = playerReg.getItem('Player');
        if (xi != null) {
          player.writeToXML(xi);
        }
      }

      playerReg.setSignature(lpszSignature);

      // encrypt prior to setting checkout status and file info (so these are visible without decryption)
      // this simply fails if password is empty
      playerReg.encrypt(Encodes.cCONTENTFILECRYPTKEY);

      return playerReg.save(strFile);
    } else {
      XmlFilePro file =
          XmlFilePro('PlayerRegisterInformation', Encodes.cCONTENTFILECRYPTKEY);
      if (!file.open(strFile, XfOpen.read)) {
        return false;
      }

      if (file.loadEx()) {
        //file.export();
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == lpszSignature) {
          // get site data
          var xi = file.getItem('Player');
          if (xi != null) {
            player.getFromXML(xi);
          }

          return true;
        }
      }
      return false;
    }
  }

  /// Generate Bus Number File (Simulated)
  static Future<void> genBusNumberFile(
      String dataPath, String busNumber) async {
    // In Flutter, we might just store this in SharedPreferences or a specific file
    final file = File(path.join(dataPath, 'id.txt'));
    await file.writeAsString(busNumber);
  }

  static Future<
      ({
        String channel,
        String pHttpLink,
        String pLocation,
        String pOrganization,
        String pPlayerName,
        int pSettingsGroup
      })> getPlayerInformation(String strPath) async {
    final serverFile = IniFile();
    await serverFile.loadFile(path.join(strPath, serverConfigFileName));
    final pPlayerName =
        serverFile.readString('PlayerInformation', 'PlayerName', '');
    final pLocation =
        serverFile.readString('PlayerInformation', 'Location', '');
    final pOrganization =
        serverFile.readString('PlayerInformation', 'Organization', '');
    final channel = serverFile.readString('PlayerInformation', 'Channel', '');
    final pSettingsGroup =
        serverFile.readInt('PlayerInformation', 'SettingsGroup', 1);
    final pHttpLink = serverFile.readString('Server', 'HTTPRootLink', '');

    return (
      pPlayerName: pPlayerName,
      pLocation: pLocation,
      pOrganization: pOrganization,
      channel: channel,
      pSettingsGroup: pSettingsGroup,
      pHttpLink: pHttpLink
    );
  }

  static Future<void> genPlayerInformation(String strPath) async {
    final serverFile = IniFile(path.join(strPath, serverConfigFileName));
    serverFile.writeString('PlayerInformation', 'PlayerName',
        'Player-${DateTime.now().microsecondsSinceEpoch}');
    serverFile.writeString('PlayerInformation', 'Location', 'Player Location');
    serverFile.writeString('PlayerInformation', 'Organization', 'DEMO');
    serverFile.writeString('PlayerInformation', 'Channel', 'default');
    serverFile.writeInt('PlayerInformation', 'SettingsGroup', 3);
    serverFile.writeString(
        'Server', 'HTTPRootLink', 'http://121.40.137.228:8080/demo');
    await serverFile.save();
  }

  /// Get Network Info (IP/MAC)
  static Future<void> updateNetworkInfo(Player player) async {
    final info = NetworkInfo();
    String? wifiIP = await info.getWifiIP();
    String? wifiMAC; //await info.getWifiMac();

    // Fallback for MAC if wifiMAC is null (common in newer Android/iOS versions due to privacy)
    if (wifiMAC == null || wifiMAC.isEmpty) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        wifiMAC = androidInfo.id; // Use Android ID as fallback identifier
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        wifiMAC = iosInfo.identifierForVendor;
      } else {
        wifiMAC = 'Unknown-MAC';
      }
    }

    if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '0.0.0.0') {
      player.strLocalAddress = wifiIP;
      player.strMACAddress = wifiMAC ?? '';
    }

    if (player.nLocalPort < 1024) {
      player.nLocalPort = 10025;
    }
  }

  static Future<String> getDeviceIDUrlEscape() async {
    // Get Device ID
    String? deviceId = await Utils.getUniqueKey();
    if (deviceId == null || deviceId.isEmpty) {
      logE('Failed to get device ID. Please try again.');
      return '';
    }

    return Utils.urlEscape(deviceId);
  }

  /// Auto Register Logic
  static Future<bool> autoRegister(bool commit) async {
    final strDCMSites = path.join(App().dataPath, _dcmsitesFileName);

    Player player = Player();

    // Load existing site data
    serializePlayer(player, strDCMSites, false);

    // Get Device ID
    String? deviceId = await Utils.getUniqueKey();
    if (deviceId == null || deviceId.isEmpty) {
      logE('Failed to get device ID. Please try again.');
      return false;
    }

    player.strUniqueName = deviceId;
    // Disk Serial simulation
    player.strDiskSerial = deviceId;

    if (player.strDiskSerial.isEmpty) {
      player.strDiskSerial = player.strUniqueName;
    }

    //await loadPlayerInformation(player, App().dataPath);
    var playerInformation = await getPlayerInformation(App().dataPath);
    player.setPlayerName(playerInformation.pPlayerName);
    player.setLocation(playerInformation.pPlayerName);
    player.strOrganization = playerInformation.pOrganization;
    player.strChannel = playerInformation.channel;
    await updateNetworkInfo(player);

    if (player.nLocalPort < 1024) {
      player.nLocalPort = 10025;
    }
    player.nRetryCount = 2;
    addMultiMonitor(player);

    return await register(player, playerInformation.pHttpLink, strDCMSites);
  }

  /// Register Logic
  static Future<bool> register(
      Player player, String httpLink, String? szFile) async {
    String strDCMSites = szFile ?? path.join(App().dataPath, _dcmsitesFileName);

    // Save local copy
    var result = serialize(player, strDCMSites, true);
    if (result.status && result.playerFile != null) {
      await genBusNumberFile(App().dataPath, player.strUniqueName);

      if (AppGlobal.ftpSettingPath.isNotEmpty) {
        String strLocalFile =
            path.join(AppGlobal.ftpSettingPath, _dcmsitesFileName);
        await File(strDCMSites).copy(strLocalFile); // Copy to settings path
      }

      String strResult = '';
      var strXML = result.playerFile!.export();
      strResult = await registerCMS(strXML, httpLink);

      // Parse Result
      String strGUID = '';
      if (strResult.contains('\n')) {
        final parts = strResult.split('\n');
        String errCode = parts.isNotEmpty ? parts[0] : '';
        strGUID = parts.length > 1 ? parts[1] : '';
        strResult = errCode;
      }

      if (isRegSuccess(strResult)) {
        if (loadFromResult(player, strResult)) {
          player.guidReg = '';
          changeComputerName(player, true);
        }
      } else if (strResult == RegErrorCodes.cE007) {
        player.guidReg = strGUID;
        player.strUniqueName = '';
      } else {
        player.strUniqueName = '';
      }
    }

    // Update local file with latest status
    serializePlayer(player, strDCMSites, true);

    return true;
  }

  /// Register via CMS (HTTP POST)
  static Future<String> registerCMS(String strXML, String strCMSLink) async {
    strCMSLink = fADDSLASH(strCMSLink);
    strCMSLink += cmsPLAYERREGISTERURL;
    strCMSLink = Utils.addCMSParam(strCMSLink);
    var result = await PlayerLogFile.httpPostAction(
        strCMSLink, strXML, 'application/xml; charset=utf-8');

    return result.result ?? '';
  }

  /// Check if Registration is Successful
  static bool isRegSuccess(String strResult) {
    if (strResult.length > 26 &&
        strResult.contains('<PlayerRegisterInformation')) {
      return true;
    }
    // Also check for simple success code if server returns just "Successful"
    if (strResult == RegErrorCodes.cSUCCESS) {
      return true;
    }
    return false;
  }

  /// Load Player details from Server Response XML
  static bool loadFromResult(Player player, String strResult) {
    if (strResult.length > 26 &&
        strResult.contains('<PlayerRegisterInformation')) {
      XmlFile playerReg = XmlFile('PlayerRegisterInformation');
      if (playerReg.loadXml(strResult)) {
        XmlItem? pItem = playerReg.getItem('Player');
        if (pItem != null) {
          player.getFromXML(pItem);

          return true;
        } else {
          logE('''Player Register; Invalid XML result: '$strResult'.''');
        }
      } else {
        logE('''Player Register; Parse XML result failure: '$strResult'.''');
      }
    }

    return false;
  }

  /// Change Computer Name (Simulated for Flutter)
  static void changeComputerName(Player player, bool bRegOK) {
    // In Flutter/Web/Mobile, changing the actual OS hostname is often restricted or impossible.
    // We just update the internal state.
    if (player.bChangePlayerCmpName) {
      String newName = player.strUniqueName;
      if (!bRegOK) {
        newName = 'P_${player.strUniqueName}_1';
      }
      debugPrint("Simulated Computer Name Change to: $newName");
      // In a real desktop app, you might use platform channels to invoke OS commands.
    }
  }

  static Player addMultiMonitor(Player player) {
    player.freeOutputs();
    final displayManager = DisplayManager.instance;
    final allDisplays = displayManager.getAll();
    if (allDisplays.length > 1) {
      player.initOutputs(allDisplays.length);

      int nIndex = 1;
      for (int nMonitor = 0; nMonitor < allDisplays.length; nMonitor++) {
        String strMonName = allDisplays[nMonitor].id;
        if (strMonName.isEmpty) {
          strMonName = allDisplays[nMonitor].name;
        }
        if (!allDisplays[nMonitor].isPrimary) {
          if (strMonName.isEmpty) {
            strMonName = 'Monitor${nMonitor + 1}';
          }
          player.addOutput(nIndex, nMonitor,
              szName: strMonName, szLocation: strMonName);
        } else {
          if (strMonName.isEmpty) {
            strMonName = 'Monitor1';
          }
          player.addOutput(0, nMonitor,
              szName: strMonName, szLocation: strMonName);
        }
      }
    }
    return player;
  }
}
