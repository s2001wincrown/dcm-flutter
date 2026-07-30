// Global settings for Content management Flutter app

import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

class AppGlobal {
  // File Paths
  static String configFile = '';
  static String cscPath = '';
  static String appDataPath = '';
  static String ddServerPath = '';
  static String openPath = '';
  static String bgFile = '';
  static String loginFile = '';
  static String imagePath = '';
  static String vcdPath = '';
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
  static String appConnectString = '';
  static int playMode = 0;
  static int globalSetting = 0;
  static int autoReloadDuration = 0;
  static int playStartPoint = 0;
  static int playListCut = 0;
  static int multiMonitor = 0;
  static int appRuntimeType = 1;
  static int ieSetting = 0x0001;
  static int videoSetting = 0x0001;
  static int videoRender = 3;
  static double maxContentDuration = 0;
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

  static int pdfViewMode = 0;
  static int pdfPlayMode = 0;

  static int messagePlayMode = 4;
  static int processAHConflict = 0;
  static int eventTimeout = 0;
  static int maxZoneThread = 2;

  static int clrBGColor = 0;
  static String bgImageFile = '';
  static String? startupWallpaper;

  // DataCenter
  static String sPassword = '';

  static late String cmsUrl; //CMS url
  static late String cmsToken; //CMS Token
  static late String organization;
  static bool enableTaskCheck = true;
  static bool autoContentUpdate = true;
  static int fileTransferRetries = 3;
  static int taskTransferRetries = 3;
  static int tempFileCopyRetries = 100; //times
  static int retryInterval = 60; //seconds
  static int logUploadInterval = 10; //seconds
  static int logUploadPeriod = 7; //days
  static bool fileIntegrityCheck = true;
  static bool deleteContentIfFTPFail = true;
  static bool autoSyncTime = false;
  static bool getEventDisplay = false;

  static String?
      availableACUStart; //available start time for auto content update
  static String? availableACUEnd; //available end time for auto content update

  static int httpRetryTimes = 10; //HTTP Post Retry Times

  static int statusCheckInterval = 60; //seconds

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
    'File Path.App_Setting_Path': (v) => settingPath = v,
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
    'DataBase Setting.DataBaseConnectString': (v) => appConnectString = v,
    'Global Setting.CombSettings': (v) => globalSetting = int.parse(v),
    'Global Setting.Auto Reload Idle Duration': (v) =>
        autoReloadDuration = int.parse(v),
    'Global Setting.PlayStartPoint': (v) => playStartPoint = int.parse(v),
    'Global Setting.PlayListCut': (v) => playListCut = int.parse(v),
    'Global Setting.MultiMonitor': (v) => multiMonitor = int.parse(v),
    'Global Setting.Client': (v) => appRuntimeType = int.parse(v),
    'Global Setting.Hide IE Scrollbar': (v) => ieSetting = int.parse(v),
    'Global Setting.VideoSetting': (v) => videoSetting = int.parse(v),
    'Global Setting.Video_Render': (v) => videoRender = int.parse(v),
    'Global Setting.MaxContentDuration': (v) =>
        maxContentDuration = double.parse(v),
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
    // CMS backend
    'Global Setting.CMSUrl': (v) => cmsUrl = v,
    'Global Setting.CMSToken': (v) => cmsToken = v,
    'Global Setting.Organization': (v) => organization = v,
    // Other
    'Global Setting.PrivateTypes': (v) => privateTypes = v,
    'Global Setting.MessagePlayMode': (v) => messagePlayMode = int.parse(v),
    'Global Setting.ProcessAHConflict': (v) => processAHConflict = int.parse(v),
    'Global Setting.PlayMode': (v) => playMode = int.parse(v),
    'Global Setting.EventTimeout': (v) => eventTimeout = int.parse(v),
    'Global Setting.ZoneThread': (v) => maxZoneThread = int.parse(v),
    'Global Setting.Background Color': (v) => clrBGColor = int.parse(v),
    'Global Setting.BackgroundImage': (v) => bgImageFile = v,
    'Global Setting.StartupWallpaper': (v) => startupWallpaper = v,
    'Global Setting.nPDFViewMode': (v) => pdfViewMode = int.parse(v),
    'Global Setting.nPDFPlayMode': (v) => pdfPlayMode = int.parse(v),

    'ContentSync.StatusCheckInterval': (v) =>
        statusCheckInterval = int.parse(v),
    'ContentSync.EnableTaskCheck': (v) => enableTaskCheck = bool.parse(v),
    'ContentSync.AutoContentUpdate': (v) => autoContentUpdate = bool.parse(v),
    'ContentSync.FileTransferRetries': (v) =>
        fileTransferRetries = int.parse(v),
    'ContentSync.TaskTransferRetries': (v) =>
        taskTransferRetries = int.parse(v),
    'ContentSync.TempFileCopyRetries': (v) =>
        tempFileCopyRetries = int.parse(v),
    'ContentSync.LogUploadInterval': (v) => logUploadInterval = int.parse(v),
    'ContentSync.LogUploadPeriod': (v) => logUploadPeriod = int.parse(v),
    'ContentSync.HTTPRetryTimes': (v) => httpRetryTimes = int.parse(v),
    'ContentSync.FileIntegrityCheck': (v) => fileIntegrityCheck = bool.parse(v),
    'ContentSync.DeleteContentIfFTPFail': (v) =>
        deleteContentIfFTPFail = bool.parse(v),
    'ContentSync.AvailableACUStart': (v) => availableACUStart = v,
    'ContentSync.AvailableACUEnd': (v) => availableACUEnd = v,
    //retryInterval
    'ContentSync.TaskRetryInterval': (v) => retryInterval = int.parse(v),
    'ContentSync.AutoSyncTime': (v) => autoSyncTime = bool.parse(v),
    'ContentSync.GetEventDisplay': (v) => getEventDisplay = bool.parse(v),
  };

  static final Map<String, String Function()> _getters = {
    // File Paths
    'File Path.ContentAndSettingCenter': () => cscPath,
    'File Path.DynamicDataPath': () => ddServerPath,
    'File Path.Open Path': () => openPath,
    'File Path.Background Image': () => bgFile,
    'File Path.Login Image': () => loginFile,
    'File Path.Image Data': () => imagePath,
    'File Path.VCD Data': () => vcdPath,
    'File Path.Powerpoint Data': () => ppPath,
    'File Path.Flash Data': () => flashPath,
    'File Path.WebPage Data': () => webPath,
    'File Path.Text Setting Path': () => textPath,
    'File Path.Image Setting Path': () => imageSettingPath,
    'File Path.Clock Setting Path': () => clockPath,
    'File Path.Weather Setting Path': () => weatherPath,
    'File Path.Site_Content_Path': () => siteContentPath,
    'File Path.LayoutImagePath': () => layoutImagePath,
    'File Path.SkinsPath': () => skinsPath,
    'File Path.RLTContentDestination': () => rltContentPath,
    'File Path.DynamicDataDestination': () => dynamicDataPath,
    'File Path.Skin Setting': () => skinFile,
    'File Path.GraphicsPath': () => graphicsPath,
    'File Path.Schedule Day Path': () => dayPath,
    'File Path.Schedule_AHPlaylist_Path': () => ahPlaylistPath,
    'File Path.Schedule Month Path': () => monthPath,
    'File Path.Schedule_Calendar_Path': () => calendarPath,
    'File Path.App_Setting_Path': () => settingPath,
    'File Path.DOWNLOAD_Setting_Path': () => ftpSettingPath,
    'File Path.Reports Path': () => reportPath,
    'File Path.TempFile_Path': () => tempPath,
    'File Path.Logfile Path': () => logPath,
    'File Path.ContentList Path': () => contentListPath,
    'File Path.Linkage_Path': () => linkagePath,
    'File Path.DDE_Others_Path': () => ddeOthersPath,
    'File Path.DDE_Data_Path': () => ddeDataPath,
    'File Path.DDE_XML_Path': () => ddeXmlPath,
    'File Path.AHMessage Path': () => messagePath,
    'File Path.RoomEvent Path': () => roomEventPath,
    'File Path.Room_Path': () => roomPath,
    'File Path.Lobby_Path': () => lobbyPath,
    'File Path.Player Register Path': () => playerPath,
    'File Path.PreData_Path': () => preDataPath,
    'File Path.UpdateFile_Path': () => updateFilePath,
    // Global Settings
    'Global Setting.RLTContentFile': () => rltContentFile,
    'Global Setting.KeyMappingFile': () => keyMappingFile,
    'DataBase Setting.DataBaseConnectString': () => appConnectString,
    'Global Setting.CombSettings': () => globalSetting.toString(),
    'Global Setting.Auto Reload Idle Duration': () =>
        autoReloadDuration.toString(),
    'Global Setting.PlayStartPoint': () => playStartPoint.toString(),
    'Global Setting.PlayListCut': () => playListCut.toString(),
    'Global Setting.MultiMonitor': () => multiMonitor.toString(),
    'Global Setting.Client': () => appRuntimeType.toString(),
    'Global Setting.Hide IE Scrollbar': () => ieSetting.toString(),
    'Global Setting.VideoSetting': () => videoSetting.toString(),
    'Global Setting.Video_Render': () => videoRender.toString(),
    'Global Setting.MaxContentDuration': () => maxContentDuration.toString(),
    'Global Setting.MaxDefaultEvent': () => maxDefaultEvent.toString(),
    'Global Setting.LogFileRecordNum': () => logFileRecordNum.toString(),
    'Global Setting.LogFileKeepDay': () => logFileKeepDay.toString(),
    'Global Setting.CopyFileBuffer': () => copyFileBuffer.toString(),
    'Global Setting.CopyFileRetries': () => copyFileRetries.toString(),
    'Global Setting.EventMultiGroup': () => multiGroup.toString(),
    'Global Setting.ContentExportType': () => exportType.toString(),
    'Global Setting.PlaybackSettings': () => loopMethod.toString(),
    'Global Setting.PowerPoint Version': () => powerPoint.toString(),
    'Global Setting.PPView Path': () => ppViewPath,
    'Global Setting.EventContentPath': () => eventContentPath,
    'TVCard.Installed': () => tvInstalled.toString(),
    // DataCenter
    'DataCenter.sPassword': () => sPassword,
    // CMS backend
    'Global Setting.CMSUrl': () => cmsUrl,
    'Global Setting.CMSToken': () => cmsToken,
    'Global Setting.Organization': () => organization,
    // Other
    'Global Setting.PrivateTypes': () => privateTypes,
    'Global Setting.MessagePlayMode': () => messagePlayMode.toString(),
    'Global Setting.ProcessAHConflict': () => processAHConflict.toString(),
    'Global Setting.PlayMode': () => playMode.toString(),
    'Global Setting.EventTimeout': () => eventTimeout.toString(),
    'Global Setting.ZoneThread': () => maxZoneThread.toString(),
    'Global Setting.Background Color': () => clrBGColor.toString(),
    'Global Setting.BackgroundImage': () => bgImageFile,
    'Global Setting.StartupWallpaper': () => startupWallpaper ?? '',
    'Global Setting.nPDFViewMode': () => pdfViewMode.toString(),
    'Global Setting.nPDFPlayMode': () => pdfPlayMode.toString(),

    'ContentSync.StatusCheckInterval': () => statusCheckInterval.toString(),
    'ContentSync.EnableTaskCheck': () => enableTaskCheck.toString(),
    'ContentSync.AutoContentUpdate': () => autoContentUpdate.toString(),
    'ContentSync.FileTransferRetries': () => fileTransferRetries.toString(),
    'ContentSync.TaskTransferRetries': () => taskTransferRetries.toString(),
    'ContentSync.TempFileCopyRetries': () => tempFileCopyRetries.toString(),
    'ContentSync.LogUploadInterval': () => logUploadInterval.toString(),
    'ContentSync.LogUploadPeriod': () => logUploadPeriod.toString(),
    'ContentSync.HTTPRetryTimes': () => httpRetryTimes.toString(),
    'ContentSync.FileIntegrityCheck': () => fileIntegrityCheck.toString(),
    'ContentSync.DeleteContentIfFTPFail': () =>
        deleteContentIfFTPFail.toString(),
    'ContentSync.AvailableACUStart': () => availableACUStart ?? '',
    'ContentSync.AvailableACUEnd': () => availableACUEnd ?? '',
    //retryInterval
    'ContentSync.TaskRetryInterval': () => retryInterval.toString(),
    'ContentSync.AutoSyncTime': () => autoSyncTime.toString(),
    'ContentSync.GetEventDisplay': () => getEventDisplay.toString(),
  };

  static Map<String, dynamic> snapshot() {
    return {
      'cscPath': _readStringValue(() => cscPath),
      'appDataPath': _readStringValue(() => appDataPath),
      'ddServerPath': _readStringValue(() => ddServerPath),
      'openPath': _readStringValue(() => openPath),
      'imagePath': _readStringValue(() => imagePath),
      'vcdPath': _readStringValue(() => vcdPath),
      'ppPath': _readStringValue(() => ppPath),
      'flashPath': _readStringValue(() => flashPath),
      'webPath': _readStringValue(() => webPath),
      'textPath': _readStringValue(() => textPath),
      'imageSettingPath': _readStringValue(() => imageSettingPath),
      'clockPath': _readStringValue(() => clockPath),
      'weatherPath': _readStringValue(() => weatherPath),
      'siteContentPath': _readStringValue(() => siteContentPath),
      'layoutImagePath': _readStringValue(() => layoutImagePath),
      'skinsPath': _readStringValue(() => skinsPath),
      'rltContentPath': _readStringValue(() => rltContentPath),
      'dynamicDataPath': _readStringValue(() => dynamicDataPath),
      'skinFile': _readStringValue(() => skinFile),
      'graphicsPath': _readStringValue(() => graphicsPath),
      'dayPath': _readStringValue(() => dayPath),
      'ahPlaylistPath': _readStringValue(() => ahPlaylistPath),
      'monthPath': _readStringValue(() => monthPath),
      'calendarPath': _readStringValue(() => calendarPath),
      'settingPath': _readStringValue(() => settingPath),
      'ftpSettingPath': _readStringValue(() => ftpSettingPath),
      'tempPath': _readStringValue(() => tempPath),
      'logPath': _readStringValue(() => logPath),
      'contentListPath': _readStringValue(() => contentListPath),
      'linkagePath': _readStringValue(() => linkagePath),
      'ddeOthersPath': _readStringValue(() => ddeOthersPath),
      'ddeDataPath': _readStringValue(() => ddeDataPath),
      'ddeXmlPath': _readStringValue(() => ddeXmlPath),
      'messagePath': _readStringValue(() => messagePath),
      'roomEventPath': _readStringValue(() => roomEventPath),
      'roomPath': _readStringValue(() => roomPath),
      'lobbyPath': _readStringValue(() => lobbyPath),
      'preDataPath': _readStringValue(() => preDataPath),
      'updateFilePath': _readStringValue(() => updateFilePath),
      'availableACUStart': availableACUStart == null
          ? ''
          : _readStringValue(() => availableACUStart!),
      'availableACUEnd': availableACUEnd == null
          ? ''
          : _readStringValue(() => availableACUEnd!),
      'cmsUrl': _readStringValue(() => cmsUrl),
      'cmsToken': _readStringValue(() => cmsToken),
      'organization': _readStringValue(() => organization),
      'enableTaskCheck': enableTaskCheck,
      'autoContentUpdate': autoContentUpdate,
      'fileTransferRetries': fileTransferRetries,
      'taskTransferRetries': taskTransferRetries,
      'tempFileCopyRetries': tempFileCopyRetries,
      'logUploadInterval': logUploadInterval,
      'logUploadPeriod': logUploadPeriod,
      'statusCheckInterval': statusCheckInterval,
      'httpRetryTimes': httpRetryTimes,
      'fileIntegrityCheck': fileIntegrityCheck,
      'deleteContentIfFTPFail': deleteContentIfFTPFail,
      'retryInterval': retryInterval,
      'autoSyncTime': autoSyncTime,
      'getEventDisplay': getEventDisplay,
    };
  }

  static String _readStringValue(String Function() getter) {
    try {
      return getter();
    } catch (_) {
      return '';
    }
  }

  static void applyWorkerConfig({
    String? cscPath,
    String? appDataPath,
    String? ddServerPath,
    String? openPath,
    String? imagePath,
    String? vcdPath,
    String? ppPath,
    String? flashPath,
    String? webPath,
    String? textPath,
    String? imageSettingPath,
    String? clockPath,
    String? weatherPath,
    String? siteContentPath,
    String? layoutImagePath,
    String? skinsPath,
    String? rltContentPath,
    String? dynamicDataPath,
    String? skinFile,
    String? graphicsPath,
    String? dayPath,
    String? ahPlaylistPath,
    String? monthPath,
    String? calendarPath,
    String? settingPath,
    String? ftpSettingPath,
    String? tempPath,
    String? logPath,
    String? contentListPath,
    String? linkagePath,
    String? ddeOthersPath,
    String? ddeDataPath,
    String? ddeXmlPath,
    String? messagePath,
    String? roomEventPath,
    String? roomPath,
    String? lobbyPath,
    String? preDataPath,
    String? updateFilePath,
    String? availableACUStart,
    String? availableACUEnd,
    String? cmsUrl,
    String? cmsToken,
    String? organization,
    bool? enableTaskCheck,
    bool? autoContentUpdate,
    int? fileTransferRetries,
    int? taskTransferRetries,
    int? tempFileCopyRetries,
    int? logUploadInterval,
    int? logUploadPeriod,
    int? statusCheckInterval,
    int? httpRetryTimes,
    bool? fileIntegrityCheck,
    bool? deleteContentIfFTPFail,
    int? retryInterval,
    bool? autoSyncTime,
    bool? getEventDisplay,
  }) {
    if (cscPath != null) {
      AppGlobal.cscPath = cscPath;
    }
    if (appDataPath != null) {
      AppGlobal.appDataPath = appDataPath;
    }
    if (ddServerPath != null) {
      AppGlobal.ddServerPath = ddServerPath;
    }
    if (openPath != null) {
      AppGlobal.openPath = openPath;
    }
    if (imagePath != null) {
      AppGlobal.imagePath = imagePath;
    }
    if (vcdPath != null) {
      AppGlobal.vcdPath = vcdPath;
    }
    if (ppPath != null) {
      AppGlobal.ppPath = ppPath;
    }
    if (flashPath != null) {
      AppGlobal.flashPath = flashPath;
    }
    if (webPath != null) {
      AppGlobal.webPath = webPath;
    }
    if (textPath != null) {
      AppGlobal.textPath = textPath;
    }
    if (imageSettingPath != null) {
      AppGlobal.imageSettingPath = imageSettingPath;
    }
    if (clockPath != null) {
      AppGlobal.clockPath = clockPath;
    }
    if (weatherPath != null) {
      AppGlobal.weatherPath = weatherPath;
    }
    if (siteContentPath != null) {
      AppGlobal.siteContentPath = siteContentPath;
    }
    if (layoutImagePath != null) {
      AppGlobal.layoutImagePath = layoutImagePath;
    }
    if (skinsPath != null) {
      AppGlobal.skinsPath = skinsPath;
    }
    if (rltContentPath != null) {
      AppGlobal.rltContentPath = rltContentPath;
    }
    if (dynamicDataPath != null) {
      AppGlobal.dynamicDataPath = dynamicDataPath;
    }
    if (skinFile != null) {
      AppGlobal.skinFile = skinFile;
    }
    if (graphicsPath != null) {
      AppGlobal.graphicsPath = graphicsPath;
    }
    if (dayPath != null) {
      AppGlobal.dayPath = dayPath;
    }
    if (ahPlaylistPath != null) {
      AppGlobal.ahPlaylistPath = ahPlaylistPath;
    }
    if (monthPath != null) {
      AppGlobal.monthPath = monthPath;
    }
    if (calendarPath != null) {
      AppGlobal.calendarPath = calendarPath;
    }
    if (settingPath != null) {
      AppGlobal.settingPath = settingPath;
    }
    if (ftpSettingPath != null) {
      AppGlobal.ftpSettingPath = ftpSettingPath;
    }
    if (tempPath != null) {
      AppGlobal.tempPath = tempPath;
    }
    if (logPath != null) {
      AppGlobal.logPath = logPath;
    }
    if (contentListPath != null) {
      AppGlobal.contentListPath = contentListPath;
    }
    if (linkagePath != null) {
      AppGlobal.linkagePath = linkagePath;
    }
    if (ddeOthersPath != null) {
      AppGlobal.ddeOthersPath = ddeOthersPath;
    }
    if (ddeDataPath != null) {
      AppGlobal.ddeDataPath = ddeDataPath;
    }
    if (ddeXmlPath != null) {
      AppGlobal.ddeXmlPath = ddeXmlPath;
    }
    if (messagePath != null) {
      AppGlobal.messagePath = messagePath;
    }
    if (roomEventPath != null) {
      AppGlobal.roomEventPath = roomEventPath;
    }
    if (roomPath != null) {
      AppGlobal.roomPath = roomPath;
    }
    if (lobbyPath != null) {
      AppGlobal.lobbyPath = lobbyPath;
    }
    if (preDataPath != null) {
      AppGlobal.preDataPath = preDataPath;
    }
    if (updateFilePath != null) {
      AppGlobal.updateFilePath = updateFilePath;
    }
    if (availableACUStart != null) {
      AppGlobal.availableACUStart = availableACUStart;
    }
    if (availableACUEnd != null) {
      AppGlobal.availableACUEnd = availableACUEnd;
    }
    if (cmsUrl != null) {
      AppGlobal.cmsUrl = cmsUrl;
    }
    if (cmsToken != null) {
      AppGlobal.cmsToken = cmsToken;
    }
    if (organization != null) {
      AppGlobal.organization = organization;
    }
    if (enableTaskCheck != null) {
      AppGlobal.enableTaskCheck = enableTaskCheck;
    }
    if (autoContentUpdate != null) {
      AppGlobal.autoContentUpdate = autoContentUpdate;
    }
    if (fileTransferRetries != null) {
      AppGlobal.fileTransferRetries = fileTransferRetries;
    }
    if (taskTransferRetries != null) {
      AppGlobal.taskTransferRetries = taskTransferRetries;
    }
    if (tempFileCopyRetries != null) {
      AppGlobal.tempFileCopyRetries = tempFileCopyRetries;
    }
    if (logUploadInterval != null) {
      AppGlobal.logUploadInterval = logUploadInterval;
    }
    if (logUploadPeriod != null) {
      AppGlobal.logUploadPeriod = logUploadPeriod;
    }
    if (statusCheckInterval != null) {
      AppGlobal.statusCheckInterval = statusCheckInterval;
    }
    if (httpRetryTimes != null) {
      AppGlobal.httpRetryTimes = httpRetryTimes;
    }
    if (getEventDisplay != null) {
      AppGlobal.getEventDisplay = getEventDisplay;
    }
  }

  static Future<bool> loadFromIni() async {
    appDataPath = FileUtils.removeBackslash(App().dataPath);
    try {
      if (configFile.isEmpty) {
        configFile = path.join(appDataPath, configFILENAME);
      }

      final file = File(configFile);
      if (!await file.exists()) {
        return false;
      }

      var iniFile = IniFile(configFile);
      if (iniFile.sections.isEmpty) {
        return false;
      }

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

    return validGlobalSetting(appDataPath);
  }

  static Future<void> genConfigFile() async {
    var iniFile = IniFile(path.join(appDataPath, configFILENAME));
    for (var entry in _getters.entries) {
      if ('Global Setting.CombSettings' == entry.key) {
        writeCombSettings(iniFile);
      } else if ('Global Setting.PlaybackSettings' == entry.key) {
        writePlaybackSettings(iniFile);
      } else {
        iniFile.setValue(entry.key.split('.').first, entry.key.split('.').last,
            entry.value.call());
      }
    }
    await iniFile.save();
  }

  static String loadPlaybackSettings(IniFile iniFile) {
    int settingValue =
        iniFile.readInt('Global Setting', 'Schedule Loop Method', 0);
    if (iniFile.readInt('Global Setting', 'PlayLatestPlaylist', 0) > 0) {
      settingValue |= settingLATESTPLAYLIST;
    }
    return settingValue.toString();
  }

  static void writePlaybackSettings(IniFile iniFile) {
    iniFile.setValue('Global Setting', 'PlayLatestPlaylist',
        (loopMethod & settingLATESTPLAYLIST) > 0);
    iniFile.setValue(
        'Global Setting',
        'Schedule Loop Method',
        (loopMethod & settingLATESTPLAYLIST) > 0
            ? loopMethod - settingLATESTPLAYLIST
            : loopMethod);
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

  static void writeCombSettings(IniFile iniFile) {
    iniFile.setValue('Global Setting', 'Hide Cursor',
        (globalSetting & settingHIDECURSOR) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'Language Button',
        (globalSetting & settingLANGBTN) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'MuteAll',
        (globalSetting & settingMUTEALL) > 0 ? 1 : 0); // Mute all
    iniFile.setValue('Global Setting', 'EnableQueueControl',
        (globalSetting & settingQC) > 0 ? 1 : 0); //Enable Queue Control
    iniFile.setValue('Global Setting', 'ContentListTime',
        (globalSetting & settingVALIDCLONLYTIME) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'ContentListAsPlaylist',
        (globalSetting & settingASPLAYLIST) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'EnableContentClean',
        (globalSetting & settingCONTENTCLEAN) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'EnableContentLog',
        (globalSetting & settingCONTENTLOG) > 0 ? 1 : 0);
    iniFile.setValue('TVCard', 'MultiSupport',
        (globalSetting & settingMULTICAPTURE) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'WebPageRefreshInterval',
        (globalSetting & settingWEBREFRESHINTERVAL) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'SimpleFileList',
        (globalSetting & settingSIMPLEFILELIST) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'MockDBClickForCapture',
        (globalSetting & settingMOCKDBCLICK) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'WebView2Buffer',
        (globalSetting & settingWEBVIEW2BUFFER) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'DisablePlayInCatalogueWizard',
        (globalSetting & settingNOTPLAYCONTENT) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'DisableLayoutPopup',
        (globalSetting & settingLAYOUTTIPWINDOWN) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'CaptureDeviceIdentifier',
        (globalSetting & settingCDI) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'EnableContentChecksum',
        (globalSetting & settingCHECKSUM) > 0 ? 1 : 0);
    iniFile.setValue('Global Setting', 'EnableAPIBackend',
        (globalSetting & settingAPIBACKEND) > 0 ? 1 : 0);
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
    appRuntimeType = 1;

    messagePlayMode = 4;
    processAHConflict = 0;
  }

  static Future<bool> validGlobalSetting(String szAppDataPath) async {
    if (cscPath.isEmpty) {
      cscPath = szAppDataPath;
    } else {
      cscPath = cscPath.replaceAll('\$(AppPath)', szAppDataPath);
    }
    cscPath = FileUtils.removeBackslash(cscPath);

    if (!await Directory(cscPath).exists()) {
      cscPath = '';
      return false;
    }

    String strOpenPath = path.join(cscPath, defaultOPENPATH);
    //String strHtml = szAppPath;
    String strImagePath = path.join(cscPath, defaultDataPath);
    String strImageSettingPath = path.join(cscPath, 'data', 'image');
    String strVCDPath = path.join(cscPath, defaultDataPath);
    String strPPPath = path.join(cscPath, defaultDataPath);
    String strFlashPath = path.join(cscPath, defaultDataPath);
    String strWebPath = path.join(cscPath, defaultDataPath);
    String strTextPath = path.join(cscPath, 'data', 'text');
    String strClockPath = path.join(cscPath, 'data', 'clock');
    String strWeatherPath = path.join(cscPath, 'data', 'weather');
    String strLayoutImagePath = path.join(cscPath, layoutTemplatePath);
    String strSkinsPath = path.join(cscPath, 'Skins');
    String strGraphicsPath = path.join(cscPath, 'Graphics');
    String strSiteContentPath = path.join(cscPath, 'data');

    openPath = await FileUtils.validFilePath(openPath, strOpenPath, false);
    if (!Directory(openPath).existsSync()) {
      FileUtils.makeSureDirectoryPathExists(openPath);
    }

    imagePath = await FileUtils.validFilePath(imagePath, strImagePath, false);
    vcdPath = await FileUtils.validFilePath(vcdPath, strVCDPath, false);
    ppPath = await FileUtils.validFilePath(ppPath, strPPPath, false);
    flashPath = await FileUtils.validFilePath(flashPath, strFlashPath, false);
    webPath = await FileUtils.validFilePath(webPath, strWebPath, false);
    textPath = await FileUtils.validFilePath(textPath, strTextPath, false);
    imageSettingPath = await FileUtils.validFilePath(
        imageSettingPath, strImageSettingPath, false);
    clockPath = await FileUtils.validFilePath(clockPath, strClockPath, false);
    weatherPath =
        await FileUtils.validFilePath(weatherPath, strWeatherPath, false);
    siteContentPath = await FileUtils.validFilePath(
        siteContentPath, strSiteContentPath, false);
    String strSitePlaylistPath = path.join(siteContentPath, 'SitePlaylist');
    FileUtils.makeSureDirectoryPathExists(strSitePlaylistPath);

    layoutImagePath = await FileUtils.validFilePath(
        layoutImagePath, strLayoutImagePath, false);
    skinsPath = await FileUtils.validFilePath(skinsPath, strSkinsPath, false);
    if (rltContentPath.isNotEmpty) {
      String strRLTContentPath = path.join(cscPath, 'RLTContent');
      rltContentPath = await FileUtils.validFilePath(
          rltContentPath, strRLTContentPath, false);
    }

    if (rltContentFile.isNotEmpty) {
      rltContentFile = await FileUtils.validFilePath(rltContentFile, '', true);
    }

    if (keyMappingFile.isNotEmpty) {
      keyMappingFile = await FileUtils.validFilePath(keyMappingFile, '', true);
    }

    skinFile = path.join(skinsPath, 'skin.dat');
    if (!await File(skinFile).exists()) {
      skinFile = await FileUtils.validFilePath(skinFile, configFile, true);
    }

    graphicsPath =
        await FileUtils.validFilePath(graphicsPath, strGraphicsPath, false);

    copyFileQueueSize = 4 * copyFileBuffer * 1024 * 1024;
    ppViewPath =
        FileUtils.replaceAppWildcard(ppViewPath, appPath: szAppDataPath);

    String strDayPath = path.join(cscPath, defaultSCHEDULEDAYPATH);
    String strMonthPath = path.join(cscPath, defaultSCHEDULEMONTHPATH);
    String strSettingPath = path.join(cscPath, defaultSCHEDULESETTINGPATH);
    String strReportPath = path.join(cscPath, defaultREPORTPATH);
    String strChannelPath = path.join(cscPath, defaultSCHEDULESETTINGPATH);
    String strLogPath = path.join(cscPath, 'schedule', 'log');
    String strContentListPath = path.join(cscPath, 'data', 'contentlist');
    String strDDEOthersPath = path.join(cscPath, 'Data');
    String strDDEDataPath = path.join(cscPath, defaultDataPath);
    String strDDEXMLPath = path.join(cscPath, 'data', 'ddelist');
    String strLinkagePath = path.join(cscPath, 'data', 'LTContent');
    String strCalendarPath = path.join(cscPath, defaultCALENDARPATH);
    String strTempPath = path.join(cscPath, 'Schedule', 'Temp');
    String strFtpSettingPath = path.join(cscPath, 'ftpsetting');
    String strAHPlaylistPath = path.join(cscPath, 'schedule', 'ahplaylist');

    dayPath = await FileUtils.validFilePath(dayPath, strDayPath, false);
    ahPlaylistPath =
        await FileUtils.validFilePath(ahPlaylistPath, strAHPlaylistPath, false);
    monthPath = await FileUtils.validFilePath(monthPath, strMonthPath, false);
    calendarPath =
        await FileUtils.validFilePath(calendarPath, strCalendarPath, false);
    settingPath =
        await FileUtils.validFilePath(settingPath, strSettingPath, false);
    ftpSettingPath =
        await FileUtils.validFilePath(ftpSettingPath, strFtpSettingPath, false);
    reportPath =
        await FileUtils.validFilePath(reportPath, strReportPath, false);
    tempPath = await FileUtils.validFilePath(tempPath, strTempPath, false);
    logPath = await FileUtils.validFilePath(logPath, strLogPath, false);
    contentListPath = await FileUtils.validFilePath(
        contentListPath, strContentListPath, false);
    linkagePath =
        await FileUtils.validFilePath(linkagePath, strLinkagePath, false);
    ddeDataPath =
        await FileUtils.validFilePath(ddeDataPath, strDDEDataPath, false);
    ddeXmlPath =
        await FileUtils.validFilePath(ddeXmlPath, strDDEXMLPath, false);

    String strMessagePath = path.join(cscPath, defaultAHMESSAGEPATH);
    messagePath =
        await FileUtils.validFilePath(messagePath, strMessagePath, false);

    String strRoomEventPath = path.join(cscPath, defaultROOMEVENTPATH);
    roomEventPath =
        await FileUtils.validFilePath(roomEventPath, strRoomEventPath, false);

    String strRoomPath = path.join(cscPath, defaultROOMPATH);
    roomPath = await FileUtils.validFilePath(roomPath, strRoomPath, false);

    String strLobbyPath = path.join(cscPath, defaultLOBBYPATH);
    lobbyPath = await FileUtils.validFilePath(lobbyPath, strLobbyPath, false);

    String strPlayerPath = path.join(cscPath, 'Schedule', 'Player');
    playerPath =
        await FileUtils.validFilePath(playerPath, strPlayerPath, false);

    String strPreDataPath = path.join(cscPath, 'Data', 'PreData');
    preDataPath =
        await FileUtils.validFilePath(preDataPath, strPreDataPath, false);

    String strUpdateFilePath = path.join(cscPath, 'Schedule', 'Temp');
    updateFilePath =
        await FileUtils.validFilePath(updateFilePath, strUpdateFilePath, false);

    return true;
  }

  static void clear() {
    // Clear all settings if needed
  }

  static String getAppPath() {
    return appDataPath;
  }

  static String getString(String pszPath, [String? defaultValue]) {
    return defaultValue ?? '';
  }

  static int getInt(String pszPath, [int? nDefault]) {
    return nDefault ?? 0;
  }

  static double getDouble(String pszPath) {
    return 0.00;
  }

  static bool getBool(String pszPath) {
    return false;
  }

  static double videoVolume(bool bMute, double nVolume) {
    return (((AppGlobal.globalSetting & settingMUTEALL) > 0)
        ? cVOLUMESILENCE
        : (bMute ? cVOLUMESILENCE : nVolume));
  }

  static bool loadGlobalSetting(XmlFile pXmlFile) {
    bool bLoaded = false;
    if (configFile.isEmpty) {
      configFile = path.join(App().dataPath, configFILENAME);
    }
    IniFile settingsFile = IniFile(configFile);

    XmlItem? pGroup = pXmlFile.getItem('SettingsGroup');
    while (pGroup != null) {
      String strGroup = pGroup.getItemValue('Name');
      XmlItem? pItem = pGroup.getItem('Item');
      while (pItem != null) {
        String strName = pItem.getItemValue('Name');
        String strValue = pItem.getItemValue('Value');
        if (strValue.isNotEmpty) {
          bLoaded = true;
          int nType = pItem.getItemValueI('Type');
          if (nType == 4) {
            settingsFile.writeString(
                strGroup, strName, Encodes.encryptText(strValue));
          } else {
            settingsFile.writeString(strGroup, strName, strValue);
          }
        }
        pItem = pItem.getSibling();
      }
      pGroup = pGroup.getSibling();
    }

    return bLoaded;
  }
}
