import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/time_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// FTP站点接口定义
abstract class IFtpSite {
  String getFTPServer();
  String getUserName();
  String getPassword();
  String getUserAgent();
  String getProxyServer();
  String getDCMVersion();
  DateTime getLastOnline();
  String getDiskSerial();
  String getUniqueName();
  String getLocalAddress();
  String getMACAddress();
  String getMACAddress1();
  String getDeviceID();
  String getMACID();
  String getPublicIP();
  String getIPAddress();
  String getServerAddress();
  String getLocation();
  String getDescription();
  String getPlayerName();
  String getTimeOuts();
  int getRetries();
  int getRetryDelay();
  int getFtpPeriod();
  int getBeforeDay();
  int getLocalPort();
  int getFtpContent();
  DateTime getRegTime();
  int getPort();
  int getConnectionType();
  int getConnectionTimeout();
  int getReadBufferSize();
  int getLimit();
  bool isBinary();
  bool isPasv();
  bool isReplaceFile();
  bool isOnline();
  void setFTPServer(String server);
  void setUserName(String userName);
  void setPassword(String password);
  void setUserAgent(String agent);
  void setProxyServer(String proxy);
  void setDiskSerial(String diskSerial);
  void setUniqueName(String uniqueName);
  void setLocalAddress(String localAddress);
  void setMACAddress(String macAddress);
  void setDeviceID(String deviceID);
  void setMACID(String macID);
  void setPublicIP(String publicIP);
  void setServerAddress(String serverAddress);
  void setLocation(String location);
  void setDescription(String description);
  void setPlayerName(String playerName);
  void setPort(int port);
  void setConnectionType(int type);
  void setConnectionTimeout(int timeout);
  void setReadBufferSize(int buffer);
  void setLimit(int limit);
  void setBinary(bool binary);
  void setPasv(bool pasv);
}

// 输出结构体
class PlayerOutput {
  int uiOutput;
  String szName;
  String szLocation;

  PlayerOutput({
    required this.uiOutput,
    required this.szName,
    required this.szLocation,
  });

  PlayerOutput copy() {
    return PlayerOutput(
      uiOutput: uiOutput,
      szName: szName,
      szLocation: szLocation,
    );
  }
}

// FTP站点类
class FtpSite implements IFtpSite {
  static const String lpszSignature =
      'DCM FTP Manager Version 1.00- StoreObject';
  String strDCMVersion = '';
  bool bOnline = false;

  int nIndex = 0;
  DateTime pRegTime = DateTime.now();
  String strOrganizationId = '';

  String strAddress = '';
  int nRetries = 1;
  String strDescription = '';
  String strLocalPath = '';
  String strLogin = '';
  String strName = '';
  String strUniqueName = '';
  String strPassword = '';
  int nPort = 21;
  int nRetryDelay = 15;
  bool bUseFirewall = false;
  bool bUsePASVMode = false;
  String strChannel = '';
  String strDiskSerial = '';
  String strLocation = '';
  int nFtpPeriod = 7; // 默认值
  int nBeforeDay = 1;
  int dwFtpContent = 0xFFFF; // FTP_ALLCONTENT
  String strFtpTime = '01:00';
  String strReFtpTime = '';
  String strStartFtpTime = '';
  bool bReplaceFile = false;
  bool bToday = true;
  bool bChangePlayerCmpName = false;

  String strMACAddress = '';
  String strMACAddress1 = '';
  String strLocalAddress = '';
  int nLocalPort = 10025;

  bool bImmReplace = true;
  int nImmFtpPeriod = 7;
  String strTimeOuts = '05:00';

  String strCommand = '';
  String strCMDTime = '';

  DateTime dtOnline = DateTime.now();
  DateTime dtStartup = DateTime.now();
  DateTime dtShutdown = DateTime.now();
  DateTime dtLastSyncTime = DateTime.now();

  String strDeviceID = '';
  String strMACID = '';
  String strPublicIP = '';
  String strPhoneNumber = '';
  String strPhoneNumberServer = '';
  String guidReg = '';

  bool bBinary = true; // 默认二进制传输
  double dbLimit = 0.0;
  int dwConnectionTimeout = 30000; // 30秒超时
  String sUserAgent = '';
  String sProxyServer = '';
  String sServerName = '';
  int connectionType = 0;
  int dwReadBufferSize = 1024;

  int nLastErr = 0;
  int nRetryCount = 0;
  int nReason = 0;

  List<PlayerOutput>? pOutputs;
  int dwOutputs = 0;

  FtpSite() {
    initializeDefaults();
  }

  FtpSite.copy(FtpSite ftpSite) {
    nIndex = ftpSite.nIndex;
    strOrganizationId = ftpSite.strOrganizationId;
    strAddress = ftpSite.strAddress;
    nRetries = ftpSite.nRetries;
    strDescription = ftpSite.strDescription;
    strLocalPath = ftpSite.strLocalPath;
    strLogin = ftpSite.strLogin;
    strName = ftpSite.strName;
    strUniqueName = ftpSite.strUniqueName;
    strPassword = ftpSite.strPassword;
    nPort = ftpSite.nPort;
    strDeviceID = ftpSite.strDeviceID;
    strMACID = ftpSite.strMACID;
    strPhoneNumber = ftpSite.strPhoneNumber;
    strPhoneNumberServer = ftpSite.strPhoneNumberServer;
    guidReg = ftpSite.guidReg;
    strPublicIP = ftpSite.strPublicIP;
    nRetryDelay = ftpSite.nRetryDelay;
    bUseFirewall = ftpSite.bUseFirewall;
    bUsePASVMode = ftpSite.bUsePASVMode;
    strDiskSerial = ftpSite.strDiskSerial;
    strChannel = ftpSite.strChannel;
    strLocation = ftpSite.strLocation;
    nFtpPeriod = ftpSite.nFtpPeriod;
    nBeforeDay = ftpSite.nBeforeDay;
    strFtpTime = ftpSite.strFtpTime;
    strReFtpTime = ftpSite.strReFtpTime;
    bReplaceFile = ftpSite.bReplaceFile;
    bToday = ftpSite.bToday;
    bImmReplace = ftpSite.bImmReplace;
    bChangePlayerCmpName = ftpSite.bChangePlayerCmpName;
    nImmFtpPeriod = ftpSite.nImmFtpPeriod;
    strTimeOuts = ftpSite.strTimeOuts;
    dwFtpContent = ftpSite.dwFtpContent;
    strStartFtpTime = ftpSite.strStartFtpTime;

    strMACAddress = ftpSite.strMACAddress;
    strMACAddress1 = ftpSite.strMACAddress1;
    strLocalAddress = ftpSite.strLocalAddress;
    nLocalPort = ftpSite.nLocalPort;

    strCommand = ftpSite.strCommand;
    strCMDTime = ftpSite.strCMDTime;

    strDCMVersion = ftpSite.strDCMVersion;
    bOnline = ftpSite.bOnline;
    dtOnline = ftpSite.dtOnline;
    dtStartup = ftpSite.dtStartup;
    dtShutdown = ftpSite.dtShutdown;
    dtLastSyncTime = ftpSite.dtLastSyncTime;

    pRegTime = ftpSite.pRegTime;

    bBinary = ftpSite.bBinary;
    dbLimit = ftpSite.dbLimit;
    dwConnectionTimeout = ftpSite.dwConnectionTimeout;
    sUserAgent = ftpSite.sUserAgent;
    sProxyServer = ftpSite.sProxyServer;
    sServerName = ftpSite.sServerName;
    connectionType = ftpSite.connectionType;
    dwReadBufferSize = ftpSite.dwReadBufferSize;

    nLastErr = ftpSite.nLastErr;
    nRetryCount = ftpSite.nRetryCount;
    nReason = ftpSite.nReason;

    if (ftpSite.pOutputs != null) {
      pOutputs = ftpSite.pOutputs!.map((output) => output.copy()).toList();
      dwOutputs = ftpSite.dwOutputs;
    }
  }

  FtpSite.fromInstance(FtpSite? pSite) {
    if (pSite != null) {
      nIndex = pSite.nIndex;
      strOrganizationId = pSite.strOrganizationId;
      strAddress = pSite.strAddress;
      nRetries = pSite.nRetries;
      strDescription = pSite.strDescription;
      strLocalPath = pSite.strLocalPath;
      strLogin = pSite.strLogin;
      strName = pSite.strName;
      strUniqueName = pSite.strUniqueName;
      strPassword = pSite.strPassword;
      nPort = pSite.nPort;
      strDeviceID = pSite.strDeviceID;
      strMACID = pSite.strMACID;
      strPhoneNumber = pSite.strPhoneNumber;
      strPhoneNumberServer = pSite.strPhoneNumberServer;
      guidReg = pSite.guidReg;
      strPublicIP = pSite.strPublicIP;
      nRetryDelay = pSite.nRetryDelay;
      bUseFirewall = pSite.bUseFirewall;
      bUsePASVMode = pSite.bUsePASVMode;
      strDiskSerial = pSite.strDiskSerial;
      strChannel = pSite.strChannel;
      strLocation = pSite.strLocation;
      nFtpPeriod = pSite.nFtpPeriod;
      nBeforeDay = pSite.nBeforeDay;
      strFtpTime = pSite.strFtpTime;
      strReFtpTime = pSite.strReFtpTime;
      bReplaceFile = pSite.bReplaceFile;
      bToday = pSite.bToday;
      bImmReplace = pSite.bImmReplace;
      bChangePlayerCmpName = pSite.bChangePlayerCmpName;
      nImmFtpPeriod = pSite.nImmFtpPeriod;
      strTimeOuts = pSite.strTimeOuts;
      dwFtpContent = pSite.dwFtpContent;
      strStartFtpTime = pSite.strStartFtpTime;

      strMACAddress = pSite.strMACAddress;
      strMACAddress1 = pSite.strMACAddress1;
      strLocalAddress = pSite.strLocalAddress;
      nLocalPort = pSite.nLocalPort;

      strCommand = pSite.strCommand;
      strCMDTime = pSite.strCMDTime;

      strDCMVersion = pSite.strDCMVersion;
      bOnline = pSite.bOnline;
      dtOnline = pSite.dtOnline;
      dtStartup = pSite.dtStartup;
      dtShutdown = pSite.dtShutdown;
      dtLastSyncTime = pSite.dtLastSyncTime;

      pRegTime = pSite.pRegTime;

      bBinary = pSite.bBinary;
      dbLimit = pSite.dbLimit;
      dwConnectionTimeout = pSite.dwConnectionTimeout;
      sUserAgent = pSite.sUserAgent;
      sProxyServer = pSite.sProxyServer;
      sServerName = pSite.sServerName;
      connectionType = pSite.connectionType;
      dwReadBufferSize = pSite.dwReadBufferSize;

      nLastErr = pSite.nLastErr;
      nRetryCount = pSite.nRetryCount;
      nReason = pSite.nReason;

      if (pSite.pOutputs != null) {
        pOutputs = pSite.pOutputs!.map((output) => output.copy()).toList();
        dwOutputs = pSite.dwOutputs;
      }
    }
  }

  void initializeDefaults() {
    nRetries = 1;
    nPort = 21;
    nRetryDelay = 15;
    bUseFirewall = false;
    bUsePASVMode = false;
    nFtpPeriod = 7; // 默认值
    nBeforeDay = 1;
    strFtpTime = '01:00';
    strReFtpTime = '';
    strStartFtpTime = '';
    bReplaceFile = false;
    bToday = true;
    dwFtpContent = 0xFFFF; // FTP_ALLCONTENT
    bImmReplace = true;
    nImmFtpPeriod = 7;
    strTimeOuts = '05:00';
    strUniqueName = '';

    strMACAddress = '';
    strMACAddress1 = '';
    strLocalAddress = '';
    nLocalPort = 10025;

    sUserAgent = '';
    sProxyServer = '';
    sServerName = '';

    strCommand = '';
    strCMDTime = '';

    strDeviceID = '';
    strMACID = '';
    strPublicIP = '';
    strPhoneNumber = '';
    strPhoneNumberServer = '';
    guidReg = '';
    strOrganizationId = '';

    strDCMVersion = '';
    bOnline = false;
  }

  Future<bool> loadFTPSetting([String? szSettingFile]) async {
    strAddress = '';
    XmlFilePro file =
        XmlFilePro('PlayerRegisterInformation', Encodes.cDCMFILECRYPTKEY);
    String? strFilename = szSettingFile;
    if (strFilename == null || strFilename.isEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      strFilename = path.join(directory.path, 'dcmsites.dat');
    }
    if (!file.open(strFilename, XfOpen.read)) {
      return false;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        // get site data
        XmlItem? xi = file.getItem('Player');
        if (xi != null) {
          getFromXML(xi);

          return true;
        }
      }
    }

    return false;
  }

  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_nIndex', nIndex);
    pXmlItem.addItem('m_strOrganizationId', strOrganizationId);
    pXmlItem.addItem('m_strAddress', strAddress);
    pXmlItem.addItem('m_nRetries', nRetries);
    pXmlItem.addItem('m_strDescription', strDescription);
    pXmlItem.addItem('m_strLocalPath', strLocalPath);
    pXmlItem.addItem('m_strLogin', strLogin);
    pXmlItem.addItem('m_strName', strName);
    pXmlItem.addItem('m_strUniqueName', strUniqueName);
    pXmlItem.addItem('m_strPassword', strPassword);
    pXmlItem.addItem('m_nPort', nPort);
    pXmlItem.addItem('m_strDeviceID', strDeviceID);
    pXmlItem.addItem('m_strMACID', strMACID);
    pXmlItem.addItem('m_strPhoneNumber', strPhoneNumber);
    pXmlItem.addItem('m_strPhoneNumberServer', strPhoneNumberServer);
    pXmlItem.addItem('m_guidReg', guidReg);
    pXmlItem.addItem('m_strPublicIP', strPublicIP);
    pXmlItem.addItem('m_nRetryDelay', nRetryDelay);
    pXmlItem.addItem('m_bUseFirewall', bUseFirewall ? 1 : 0);
    pXmlItem.addItem('m_bUsePASVMode', bUsePASVMode ? 1 : 0);
    pXmlItem.addItem('m_strDiskSerial', strDiskSerial);
    pXmlItem.addItem('m_strChannel', strChannel);
    pXmlItem.addItem('m_strLocation', strLocation);
    pXmlItem.addItem('m_nFtpPeriod', nFtpPeriod);
    pXmlItem.addItem('m_nBeforeDay', nBeforeDay);
    pXmlItem.addItem('m_strFtpTime', strFtpTime);
    pXmlItem.addItem('m_strReFtpTime', strReFtpTime);
    pXmlItem.addItem('m_bReplaceFile', bReplaceFile ? 1 : 0);
    pXmlItem.addItem('m_bToday', bToday ? 1 : 0);
    pXmlItem.addItem('m_bImmReplace', bImmReplace ? 1 : 0);
    pXmlItem.addItem('m_bChangePlayerCmpName', bChangePlayerCmpName ? 1 : 0);
    pXmlItem.addItem('m_nImmFtpPeriod', nImmFtpPeriod);
    pXmlItem.addItem('m_strTimeOuts', strTimeOuts);
    pXmlItem.addItem('m_dwFtpContent', dwFtpContent);
    pXmlItem.addItem('m_strStartFtpTime', strStartFtpTime);

    pXmlItem.addItem('m_strMACAddress', strMACAddress);
    pXmlItem.addItem('m_strMACAddress1', strMACAddress1);
    pXmlItem.addItem('m_strLocalAddress', strLocalAddress);
    pXmlItem.addItem('m_nLocalPort', nLocalPort);

    pXmlItem.addItem('m_strCommand', strCommand);
    pXmlItem.addItem('m_strCMDTime', strCMDTime);

    pXmlItem.addItem('m_strDCMVersion', strDCMVersion);

    pXmlItem.addItem('m_nLastErr', nLastErr);
    pXmlItem.addItem('m_nRetryCount', nRetryCount);
    pXmlItem.addItem('m_nReason', nReason);

    pXmlItem.addItem('m_pRegTime', pRegTime);
    pXmlItem.addItem('m_dwOutputs', dwOutputs);
    if (pOutputs != null && dwOutputs > 0) {
      XmlItem? xi = pXmlItem.addItem('OutputList');
      if (xi != null) {
        for (var nOutput = 0; nOutput < dwOutputs; nOutput++) {
          if (pOutputs!.elementAtOrNull(nOutput) != null) {
            XmlItem? xiOutputItem = xi.addItem('COutputMonitor');
            if (xiOutputItem != null) {
              xiOutputItem.addItem('m_sName', pOutputs![nOutput].szName);
              xiOutputItem.addItem('m_uiID', pOutputs![nOutput].uiOutput);
              xiOutputItem.addItem(
                  'm_sLocation', pOutputs![nOutput].szLocation);
            }
          }
        }
      }
    }
  }

  void getFromXML(XmlItem pXmlItem) {
    nIndex = pXmlItem.getItemValueI('m_nIndex');
    strOrganizationId = pXmlItem.getItemValue('m_strOrganizationId');
    strAddress = pXmlItem.getItemValue('m_strAddress');
    nRetries = pXmlItem.getItemValueI('m_nRetries');
    strDescription = pXmlItem.getItemValue('m_strDescription');
    strLocalPath = pXmlItem.getItemValue('m_strLocalPath');
    strLogin = pXmlItem.getItemValue('m_strLogin');
    strName = pXmlItem.getItemValue('m_strName');
    strUniqueName = pXmlItem.getItemValue('m_strUniqueName');
    strPassword = pXmlItem.getItemValue('m_strPassword');
    nPort = pXmlItem.getItemValueI('m_nPort');
    strDeviceID = pXmlItem.getItemValue('m_strDeviceID');
    strMACID = pXmlItem.getItemValue('m_strMACID');
    strPhoneNumber = pXmlItem.getItemValue('m_strPhoneNumber');
    strPhoneNumberServer = pXmlItem.getItemValue('m_strPhoneNumberServer');
    guidReg = pXmlItem.getItemValue('m_guidReg');
    strPublicIP = pXmlItem.getItemValue('m_strPublicIP');
    nRetryDelay = pXmlItem.getItemValueI('m_nRetryDelay');
    bUseFirewall = pXmlItem.getItemValueB('m_bUseFirewall');
    bUsePASVMode = pXmlItem.getItemValueB('m_bUsePASVMode');
    strDiskSerial = pXmlItem.getItemValue('m_strDiskSerial');
    strChannel = pXmlItem.getItemValue('m_strChannel');
    strLocation = pXmlItem.getItemValue('m_strLocation');
    nFtpPeriod = pXmlItem.getItemValueI('m_nFtpPeriod');
    nBeforeDay = pXmlItem.getItemValueI('m_nBeforeDay');
    strFtpTime = pXmlItem.getItemValue('m_strFtpTime');
    strReFtpTime = pXmlItem.getItemValue('m_strReFtpTime');
    bReplaceFile = pXmlItem.getItemValueB('m_bReplaceFile');
    bToday = pXmlItem.getItemValueB('m_bToday');
    bImmReplace = pXmlItem.getItemValueB('m_bImmReplace');
    bChangePlayerCmpName = pXmlItem.getItemValueB('m_bChangePlayerCmpName');
    nImmFtpPeriod = pXmlItem.getItemValueI('m_nImmFtpPeriod');
    strTimeOuts = pXmlItem.getItemValue('m_strTimeOuts');
    dwFtpContent = pXmlItem.getItemValueI('m_dwFtpContent');
    strStartFtpTime = pXmlItem.getItemValue('m_strStartFtpTime');
    //strSystemTime = pXmlItem.getItemValue('m_strSystemTime');

    strMACAddress = pXmlItem.getItemValue('m_strMACAddress');
    strMACAddress1 = pXmlItem.getItemValue('m_strMACAddress1');
    strLocalAddress = pXmlItem.getItemValue('m_strLocalAddress');
    nLocalPort = pXmlItem.getItemValueI('m_nLocalPort');

    strCommand = pXmlItem.getItemValue('m_strCommand');
    strCMDTime = pXmlItem.getItemValue('m_strCMDTime');

    strDCMVersion = pXmlItem.getItemValue('m_strDCMVersion');

    nLastErr = pXmlItem.getItemValueI('m_nLastErr');
    nRetryCount = pXmlItem.getItemValueI('m_nRetryCount');
    nReason = pXmlItem.getItemValueI('m_nReason');

    var regTime = pXmlItem.getItemValueD('m_pRegTime');
    if (regTime != null) {
      pRegTime = regTime;
    }
    String strRegTime = pXmlItem.getItemValue('regTime');
    if (strRegTime.isNotEmpty) {
      regTime = fromDateTimeFormat(strRegTime);
      if (regTime != null) {
        pRegTime = regTime;
      }
    }
    dwOutputs = pXmlItem.getItemValueI('dwOutputs');
    initOutputs(dwOutputs);
    if (dwOutputs > 0) {
      XmlItem? pItem = pXmlItem.getItem('OutputList');
      if (pItem != null) {
        int i = 0;
        XmlItem? pXISibling = pItem.getItem('COutputMonitor');
        while (pXISibling != null) {
          if (i < dwOutputs) {
            // get Player output Inforamtion data
            pOutputs![i].uiOutput = pXISibling.getItemValueI('m_uiID');
            pOutputs![i].szName = pXISibling.getItemValue('m_sName');
            pOutputs![i].szLocation = pXISibling.getItemValue('m_sLocation');
          }
          i++;

          pXISibling = pXISibling.getSibling();
        }
      }
    }
  }

  bool addOutput(int dwIndex, int dwOutputID,
      {String? szName, String? szLocation}) {
    if (dwIndex < dwOutputs && pOutputs != null) {
      pOutputs![dwIndex].uiOutput = dwOutputID;
      pOutputs![dwIndex].szName = szName ?? '';
      pOutputs![dwIndex].szLocation = szLocation ?? '';

      return true;
    }

    return false;
  }

  PlayerOutput? getOutput(int dwOutputID, {bool bByIndex = false}) {
    if (bByIndex) {
      if (dwOutputID < dwOutputs && pOutputs != null) {
        return pOutputs![dwOutputID];
      }
    } else {
      if (pOutputs != null) {
        for (int nOutput = 0; nOutput < dwOutputs; nOutput++) {
          if (pOutputs![nOutput].uiOutput == dwOutputID) {
            return pOutputs![nOutput];
          }
        }
      }
    }

    return null;
  }

  List<PlayerOutput>? initOutputs(int dwOutputs) {
    freeOutputs();

    dwOutputs = dwOutputs;
    if (dwOutputs == 0) {
      pOutputs = null;
      return null;
    }

    pOutputs = List.generate(
      dwOutputs,
      (index) => PlayerOutput(
        uiOutput: index,
        szName: '',
        szLocation: '',
      ),
    );

    return pOutputs;
  }

  void freeOutputs() {
    pOutputs = null;
    dwOutputs = 0;
  }

  List<PlayerOutput>? copyFromOutputs(
      List<PlayerOutput>? pOutputs, int dwOutputs) {
    freeOutputs();

    dwOutputs = dwOutputs;
    if (pOutputs != null) {
      pOutputs = pOutputs.map((output) => output.copy()).toList();
    }

    return pOutputs;
  }

  @override
  String getFTPServer() => sServerName;

  @override
  String getUserName() => strLogin;

  @override
  String getPassword() => strPassword;

  @override
  String getUserAgent() => sUserAgent;

  @override
  String getProxyServer() => sProxyServer;

  @override
  String getDCMVersion() => strDCMVersion;

  @override
  DateTime getLastOnline() => dtOnline;

  @override
  String getDiskSerial() => strDiskSerial;

  @override
  String getUniqueName() => strUniqueName;

  @override
  String getLocalAddress() => strLocalAddress;

  @override
  String getMACAddress() => strMACAddress;

  @override
  String getMACAddress1() => strMACAddress1;

  @override
  String getDeviceID() => strDeviceID;

  @override
  String getMACID() => strMACID;

  @override
  String getPublicIP() => strPublicIP;

  @override
  String getIPAddress() {
    if (strPublicIP.isEmpty) {
      return strLocalAddress;
    }
    return strPublicIP;
  }

  @override
  String getServerAddress() => strAddress;

  @override
  String getLocation() => strLocation;

  @override
  String getDescription() => strDescription;

  @override
  String getPlayerName() => strName;

  @override
  String getTimeOuts() => strTimeOuts;

  @override
  int getRetries() => nRetries;

  @override
  int getRetryDelay() => nRetryDelay;

  @override
  int getFtpPeriod() => nFtpPeriod;

  @override
  int getBeforeDay() => nBeforeDay;

  @override
  int getLocalPort() => nLocalPort;

  @override
  int getFtpContent() => dwFtpContent;

  @override
  DateTime getRegTime() => pRegTime;

  @override
  int getPort() => nPort;

  @override
  int getConnectionType() => connectionType;

  @override
  int getConnectionTimeout() => dwConnectionTimeout;

  @override
  int getReadBufferSize() => dwReadBufferSize;

  @override
  int getLimit() => dbLimit.toInt();

  @override
  bool isBinary() => bBinary;

  @override
  bool isPasv() => bUsePASVMode;

  @override
  bool isReplaceFile() => bReplaceFile;

  @override
  bool isOnline() => bOnline;

  @override
  void setFTPServer(String server) {
    sServerName = server;
  }

  @override
  void setUserName(String userName) {
    strLogin = userName;
  }

  @override
  void setPassword(String password) {
    strPassword = password;
  }

  @override
  void setUserAgent(String agent) {
    sUserAgent = agent;
  }

  @override
  void setProxyServer(String proxy) {
    sProxyServer = proxy;
  }

  @override
  void setDiskSerial(String diskSerial) {
    strDiskSerial = diskSerial;
  }

  @override
  void setUniqueName(String uniqueName) {
    strUniqueName = uniqueName;
  }

  @override
  void setLocalAddress(String localAddress) {
    strLocalAddress = localAddress;
  }

  @override
  void setMACAddress(String macAddress) {
    strMACAddress = macAddress;
  }

  @override
  void setDeviceID(String deviceID) {
    strDeviceID = deviceID;
  }

  @override
  void setMACID(String macID) {
    strMACID = macID;
  }

  @override
  void setPublicIP(String publicIP) {
    strPublicIP = publicIP;
  }

  @override
  void setServerAddress(String serverAddress) {
    strAddress = serverAddress;
  }

  @override
  void setLocation(String location) {
    strLocation = location;
  }

  @override
  void setDescription(String description) {
    strDescription = description;
  }

  @override
  void setPlayerName(String playerName) {
    strName = playerName;
  }

  @override
  void setPort(int port) {
    nPort = port;
  }

  @override
  void setConnectionType(int type) {
    connectionType = type;
  }

  @override
  void setConnectionTimeout(int timeout) {
    dwConnectionTimeout = timeout;
  }

  @override
  void setReadBufferSize(int buffer) {
    dwReadBufferSize = buffer;
  }

  @override
  void setLimit(int limit) {
    dbLimit = limit.toDouble();
  }

  @override
  void setBinary(bool binary) {
    bBinary = binary;
  }

  @override
  void setPasv(bool pasv) {
    bUsePASVMode = pasv;
  }

  static String getIP(FtpSite? pSite) {
    if (pSite == null) return '';

    String strPublicIP = pSite.strPublicIP;
    if (strPublicIP.isNotEmpty) {
      // 模拟分割字符串获取第一个IP
      List<String> ips = strPublicIP.split('\n');
      if (ips.isNotEmpty) {
        strPublicIP = ips.first;
      }
    } else {
      strPublicIP = pSite.strLocalAddress;
    }

    return strPublicIP;
  }

  static String getFullName(FtpSite? pSite) {
    if (pSite == null) return '';

    String strName = '${pSite.getPlayerName()} (${getIP(pSite)})';
    return strName;
  }
}
