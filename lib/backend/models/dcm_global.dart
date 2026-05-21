// Global settings for DCM Flutter app

import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DCMGlobal {
  // File Paths
  static String cscPath = '';
  static String ddServerPath = '';
  static String openPath = '';
  static String bgFile = '';
  static String loginFile = '';
  static String imagePath = '';
  static String vcdPath = '';
  static String dvdPath = '';
  static String ppPath = '';
  static String flashPath = '';
  static String webPath = '';
  static String textPath = '';
  static String imageSettingPath = '';
  static String clockPath = '';
  static String weatherPath = '';
  static String siteContentPath = '';
  static String layoutImagePath = '';
  static String skinsPath = '';
  static String rltContentPath = '';
  static String dynamicDataPath = '';
  static String skinFile = '';
  static String graphicsPath = '';
  static String dayPath = '';
  static String ahPlaylistPath = '';
  static String monthPath = '';
  static String calendarPath = '';
  static String settingPath = '';
  static String ftpSettingPath = '';
  static String reportPath = '';
  static String tempPath = '';
  static String logPath = '';
  static String contentListPath = '';
  static String linkagePath = '';
  static String ddeOthersPath = '';
  static String ddeDataPath = '';
  static String ddeXmlPath = '';
  static String messagePath = '';
  static String roomEventPath = '';
  static String roomPath = '';
  static String lobbyPath = '';
  static String playerPath = '';
  static String preDataPath = '';
  static String updateFilePath = '';

  // Global Settings
  static String rltContentFile = '';
  static String keyMappingFile = '';
  static String dcmConnectString = '';
  static int globalSetting = 0;
  static int autoReloadDuration = 0;
  static int playStartPoint = 0;
  static int playListCut = 0;
  static int multiMonitor = 0;
  static int dcmRuntimeType = 1;
  static int ieSetting = 0x0001;
  static int videoSetting = 0x0001;
  static int videoRender = 3;
  static double maxDcmDuration = 0;
  static int maxDefaultEvent = 3;
  static int logFileRecordNum = 100;
  static int logFileKeepDay = 1;
  static int copyFileBuffer = 2;
  static int copyFileRetries = 3;
  static int multiGroup = 2;
  static int exportType = 0;
  static int loopMethod = 0;
  static int powerPoint = 0x0010;
  static String ppViewPath =
      r'C:\Program Files\Microsoft Office\PowerPoint Viewer\pptview.exe';
  static String eventContentPath = '';
  static int tvInstalled = 2;

  static int messagePlayMode = 4;
  static int processAHConflict = 0;

  // DataCenter
  static String sPassword = '';

  // Other
  static int copyFileQueueSize = 8 * 1024 * 1024;
  static int maxApprovalLevel = 0;
  static int output = 0;
  static String privateTypes =
      "|jc!|fb!|bc!|!ut|dbx|part|partial|pst|reget|getright|pif|lnk|sd|url|wab|m4p|infodb|racestats|chk|tmp|temp|ldb|inf|log|old|manifest|met|bak|\$\$\$|---|~~~|###|__incomplete___|";

  static final Map<String, void Function(String)> _setters = {
    // File Paths
    'File Path.ContentAndSettingCenter': (v) => cscPath = v,
    'File Path.DynamicDataPath': (v) => ddServerPath = v,
    'File Path.Open Path': (v) => openPath = v,
    'File Path.Background Image': (v) => bgFile = v,
    'File Path.Login Image': (v) => loginFile = v,
    'File Path.Image Data': (v) => imagePath = v,
    'File Path.VCD Data': (v) => vcdPath = v,
    'File Path.DVD Data': (v) => dvdPath = v,
    'File Path.Powerpoint Data': (v) => ppPath = v,
    'File Path.Flash Data': (v) => flashPath = v,
    'File Path.WebPage Data': (v) => webPath = v,
    'File Path.Text Setting Path': (v) => textPath = v,
    'File Path.Image Setting Path': (v) => imageSettingPath = v,
    'File Path.Clock Setting Path': (v) => clockPath = v,
    'File Path.Weather Setting Path': (v) => weatherPath = v,
    'File Path.Site_Content_Path': (v) => siteContentPath = v,
    'File Path.LayoutImagePath': (v) => layoutImagePath = v,
    'File Path.SkinsPath': (v) => skinsPath = v,
    'File Path.RLTContentDestination': (v) => rltContentPath = v,
    'File Path.DynamicDataDestination': (v) => dynamicDataPath = v,
    'File Path.Skin Setting': (v) => skinFile = v,
    'File Path.GraphicsPath': (v) => graphicsPath = v,
    'File Path.Schedule Day Path': (v) => dayPath = v,
    'File Path.Schedule_AHPlaylist_Path': (v) => ahPlaylistPath = v,
    'File Path.Schedule Month Path': (v) => monthPath = v,
    'File Path.Schedule_Calendar_Path': (v) => calendarPath = v,
    'File Path.DCM_Setting_Path': (v) => settingPath = v,
    'File Path.DOWNLOAD_Setting_Path': (v) => ftpSettingPath = v,
    'File Path.Reports Path': (v) => reportPath = v,
    'File Path.TempFile_Path': (v) => tempPath = v,
    'File Path.Logfile Path': (v) => logPath = v,
    'File Path.ContentList Path': (v) => contentListPath = v,
    'File Path.Linkage_Path': (v) => linkagePath = v,
    'File Path.DDE_Others_Path': (v) => ddeOthersPath = v,
    'File Path.DDE_Data_Path': (v) => ddeDataPath = v,
    'File Path.DDE_XML_Path': (v) => ddeXmlPath = v,
    'File Path.AHMessage Path': (v) => messagePath = v,
    'File Path.RoomEvent Path': (v) => roomEventPath = v,
    'File Path.Room_Path': (v) => roomPath = v,
    'File Path.Lobby_Path': (v) => lobbyPath = v,
    'File Path.Player Register Path': (v) => playerPath = v,
    'File Path.PreData_Path': (v) => preDataPath = v,
    'File Path.UpdateFile_Path': (v) => updateFilePath = v,
    // Global Settings
    'Global Setting.RLTContentFile': (v) => rltContentFile = v,
    'Global Setting.KeyMappingFile': (v) => keyMappingFile = v,
    'DataBase Setting.DCMDataBaseConnectString': (v) => dcmConnectString = v,
    'Global Setting.CombSettings': (v) => globalSetting = int.parse(v),
    'Global Setting.Auto Reload Idle Duration': (v) =>
        autoReloadDuration = int.parse(v),
    'Global Setting.PlayStartPoint': (v) => playStartPoint = int.parse(v),
    'Global Setting.PlayListCut': (v) => playListCut = int.parse(v),
    'Global Setting.MultiMonitor': (v) => multiMonitor = int.parse(v),
    'Global Setting.DCM Client': (v) => dcmRuntimeType = int.parse(v),
    'Global Setting.Hide IE Scrollbar': (v) => ieSetting = int.parse(v),
    'Global Setting.VideoSetting': (v) => videoSetting = int.parse(v),
    'Global Setting.Video_Render': (v) => videoRender = int.parse(v),
    'Global Setting.MaxDCMDuration': (v) => maxDcmDuration = double.parse(v),
    'Global Setting.MaxDefaultEvent': (v) => maxDefaultEvent = int.parse(v),
    'Global Setting.LogFileRecordNum': (v) => logFileRecordNum = int.parse(v),
    'Global Setting.LogFileKeepDay': (v) => logFileKeepDay = int.parse(v),
    'Global Setting.CopyFileBuffer': (v) => copyFileBuffer = int.parse(v),
    'Global Setting.CopyFileRetries': (v) => copyFileRetries = int.parse(v),
    'Global Setting.EventMultiGroup': (v) => multiGroup = int.parse(v),
    'Global Setting.ContentExportType': (v) => exportType = int.parse(v),
    'Global Setting.PlaybackSettings': (v) => loopMethod = int.parse(v),
    'Global Setting.PowerPoint Version': (v) => powerPoint = int.parse(v),
    'Global Setting.PPView Path': (v) => ppViewPath = v,
    'Global Setting.EventContentPath': (v) => eventContentPath = v,
    'TVCard.Installed': (v) => tvInstalled = int.parse(v),
    // DataCenter
    'DataCenter.sPassword': (v) => sPassword = v,
    // Other
    'Global Setting.PrivateTypes': (v) => privateTypes = v,
    'Global Setting.MessagePlayMode': (v) => privateTypes = v,
    'Global Setting.ProcessAHConflict': (v) => privateTypes = v,
  };

  static Future<void> loadFromIni() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, configFILENAME);
      final file = File(filePath);
      if (!await file.exists()) {
        return;
      }
      var iniFile = IniFile(filePath);
      for (var entry in _setters.entries) {
        if ('Global Setting.CombSettings' == entry.key) {
          entry.value.call(loadCombSettings(iniFile));
        } else if ('Global Setting.PlaybackSettings' == entry.key) {
          entry.value.call(loadPlaybackSettings(iniFile));
        } else {
          String? value = iniFile.getValue(
              entry.key.split('.').first, entry.key.split('.').last);
          if (value != null) {
            entry.value.call(value);
          }
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  static String loadPlaybackSettings(IniFile iniFile) {
    int settingValue =
        iniFile.readInt('Global Setting', 'Schedule Loop Method', 0);
    if (iniFile.readInt('Global Setting', 'PlayLatestPlaylist', 0) > 0) {
      settingValue |= loopMethod;
    }
    return settingValue.toString();
  }

  static String loadCombSettings(IniFile iniFile) {
    int settingValue = 0;
    if (iniFile.readInt('Global Setting', 'Hide Cursor', 0) > 0) {
      settingValue |= settingHIDECURSOR;
    }
    if (iniFile.readInt('Global Setting', 'Language Button', 0) > 0) {
      settingValue |= settingLANGBTN;
    }
    if (iniFile.readInt('Global Setting', 'MuteAll', 0) > 0) // Mute all
    {
      settingValue |= settingMUTEALL;
    }
    if (iniFile.readInt('Global Setting', 'EnableQueueControl', 0) >
        0) //Enable Queue Control
    {
      settingValue |= settingQC;
    }
    if (iniFile.readInt('Global Setting', 'ContentListTime', 0) > 0) {
      settingValue |= settingVALIDCLONLYTIME;
    }
    if (iniFile.readInt('Global Setting', 'ContentListAsPlaylist', 0) > 0) {
      settingValue |= settingASPLAYLIST;
    }
    if (iniFile.readInt('Global Setting', 'EnableContentClean', 0) > 0) {
      settingValue |= settingCONTENTCLEAN;
    }
    if (iniFile.readInt('Global Setting', 'EnableContentLog', 0) > 0) {
      settingValue |= settingCONTENTLOG;
    }
    if (iniFile.readInt('TVCard', 'MultiSupport', 0) > 0) {
      settingValue |= settingMULTICAPTURE;
    }
    if (iniFile.readInt('Global Setting', 'WebPageRefreshInterval', 1) > 0) {
      settingValue |= settingWEBREFRESHINTERVAL;
    }
    if (iniFile.readInt('Global Setting', 'SimpleFileList', 0) > 0) {
      settingValue |= settingSIMPLEFILELIST;
    }
    if (iniFile.readInt('Global Setting', 'MockDBClickForCapture', 0) > 0) {
      settingValue |= settingMOCKDBCLICK;
    }
    if (iniFile.readInt('Global Setting', 'WebView2Buffer', 1) > 0) {
      settingValue |= settingWEBVIEW2BUFFER;
    }
    if (iniFile.readInt('Global Setting', 'DisablePlayInCatalogueWizard', 0) >
        0) {
      settingValue |= settingNOTPLAYCONTENT;
    }
    if (iniFile.readInt('Global Setting', 'DisableLayoutPopup', 0) > 0) {
      settingValue |= settingLAYOUTTIPWINDOWN;
    }
    if (iniFile.readInt('Global Setting', 'CaptureDeviceIdentifier', 0) > 0) {
      settingValue |= settingCDI;
    }
    if (iniFile.readInt('Global Setting', 'EnableContentChecksum', 0) > 0) {
      settingValue |= settingCHECKSUM;
    }
    if (iniFile.readInt('Global Setting', 'EnableAPIBackend', 0) > 0) {
      settingValue |= settingAPIBACKEND;
    }
    return settingValue.toString();
  }

  static void init() {
    // Initialize defaults
    ieSetting = 0x0001;
    multiMonitor = 0;
    loopMethod = 0;
    globalSetting = 0;
    multiGroup = 2;
    logFileRecordNum = 100;
    logFileKeepDay = 1;
    copyFileBuffer = 2;
    copyFileQueueSize = 8 * 1024 * 1024;
    copyFileRetries = 3;
    autoReloadDuration = 0;
    playStartPoint = 0;
    maxApprovalLevel = 0;
    output = 0;
    videoRender = 1;
    tvInstalled = 2;
    videoSetting = 0x0001;
    powerPoint = 0x0001;
    ppViewPath =
        r'C:\Program Files\Microsoft Office\PowerPoint Viewer\pptview.exe';
    eventContentPath = '';
    rltContentPath = '';
    rltContentFile = '';
    keyMappingFile = '';
    dcmRuntimeType = 1;

    messagePlayMode = 4;
    processAHConflict = 0;
  }

  static void clear() {
    // Clear all settings if needed
  }

  static String getAppPath() {
    return App().dataPath;
  }
}
