import 'dart:io';

import 'package:flutter/material.dart';

const IconData appIcon = Icons.play_circle_outline;
const String appName = 'DCMPlayer';
const String version = 'Beta 2026.4';
const String flutterVersion = '3.29.0';

const String cDCMFILEROOT = 'DCMDocument';
const String cEVENTROOT = 'EventDocument';
const String cLTCONTENTROOT = 'LTContentDocument';
const String cPLOGROOT = 'PlayLogList';

const String cDCMLASTMODIFIED = 'LASTMODIFIED';
const String cDCMPROJECTNAME = 'DCMPlayer';
const String cDCMSIGNATURE = 'Signature';
const String cDCMLASTSORTBY = 'LASTSORTBY';
const String cDCMLASTSORTDIR = 'LASTSORTDIR';
const String cDCMNEXTUNIQUEID = 'NEXTUNIQUEID';
const String cDCMARCHIVE = 'ARCHIVE';
const String cDCMFILENAME = 'FILENAME';
const String cDCMFILEFORMAT = 'FILEFORMAT';
const String cDCMFILEVERSION = 'FILEVERSION';
const String cDCMCHECKEDOUTTO = 'CHECKEDOUTTO';
const String cDCMCOMPANY = 'COMPANY';
const String cDCMREPORTTITLE = 'REPORTTITLE';
const String cDCMREPORTDATE = 'REPORTDATE';
const String cDCMREPORTDATEOLE = 'REPORTDATEOLD';
const String cDCMARRAYITEM = 'ArrayItem';
const String cDCMITEMVALUE = 'ItemValue';

int fMAKEWORD(int low, int high) => (low & 0xFF) | ((high & 0xFF) << 8);
int fMAKEDWORD(int low, int high) => (low & 0xFFFF) | ((high & 0xFFFF) << 16);
int fLOWORD(int dw) => (dw & 0xffff);
int fHIWORD(int dw) => (dw >> 16) & 0xffff;
int fLOBYTE(int w) => (w & 0xff);
int fHIBYTE(int w) => ((w >> 8) & 0xff);
bool hasFlag(int dwFlags, int dwFlag) => ((dwFlags & dwFlag) == dwFlag);

String fADDSLASH(String s) {
  if (!s.endsWith('/')) {
    s = '$s/';
  }
  return s;
}

String fREMOVESLASH(String s) {
  if (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

String fLADDSLASH(String s) {
  if (!s.startsWith('/')) {
    s = '/$s';
  }
  return s;
}

String fLREMOVESLASH(String s) {
  if (s.startsWith('/')) {
    s = s.substring(1);
  }
  return s;
}

const String configFILENAME = 'dcm.dat';
final String defaultBTNIMAGEPATH = 'Graphics${Platform.pathSeparator}btnImage';
final String defaultBTNIMAGEFILE =
    'Graphics${Platform.pathSeparator}btnImage${Platform.pathSeparator}BTN1.BMP';

const String layoutTemplatePath = 'Layout';
const String defaultSkinsPath = 'Skins';
const String defaultGraphicsPath = 'Graphics';

const String defaultSAVEPATH = 'dcmfile';
const String defaultOPENPATH = 'dcmfile';
const String defaultDataPath = 'data';
final String defaultSCHEDULEDAYPATH = 'schedule${Platform.pathSeparator}day';
final String defaultAHPLAYLISTPATH =
    'schedule${Platform.pathSeparator}AHPlaylist';
final String defaultSCHEDULEMONTHPATH =
    'schedule${Platform.pathSeparator}month';
final String defaultCALENDARPATH = 'schedule${Platform.pathSeparator}calendar';
final String defaultSCHEDULESETTINGPATH =
    'schedule${Platform.pathSeparator}setting';
final String defaultSCHEDULEPUBLISHPATH =
    'schedule${Platform.pathSeparator}publish';
final String defaultAHMESSAGEPATH =
    'schedule${Platform.pathSeparator}AHMessage';
final String defaultROOMEVENTPATH =
    'schedule${Platform.pathSeparator}RoomEvent';
final String defaultROOMPATH = 'schedule${Platform.pathSeparator}Room';
final String defaultLOBBYPATH = 'schedule${Platform.pathSeparator}Lobby';
const String defaultREPORTPATH = 'reports';

final String defaultBGFILE =
    '$defaultGraphicsPath${Platform.pathSeparator}view.jpg';

final String defaultTextPath = 'Data${Platform.pathSeparator}Text';
final String defaultImageSettingPath = 'Data${Platform.pathSeparator}image';
final String defaultClockPath = 'Data${Platform.pathSeparator}clock';
final String defaultWeatherPath = 'Data${Platform.pathSeparator}Weather';

final String defaultLogPath = 'Schedule${Platform.pathSeparator}log';
final String defaultContentListPath =
    'Data${Platform.pathSeparator}ContentList';
final String defaultDDEXMLPath = 'Data${Platform.pathSeparator}DDEList';
final String defaultLinkagePath = 'Data${Platform.pathSeparator}LTContent';
final String defaultTempPath = 'Schedule${Platform.pathSeparator}Temp';
final String defaultAHPlaylistPath =
    'Schedule${Platform.pathSeparator}AHPlaylist';
const String defaultFtpSettingPath = 'ftpsetting';

const double cDEFAULTDURATION = 10.0;
const int cDCMMAXDURATION = 8640000;
const int cDCMMAXCONTENT = 1024;
const int cDCMMAXTEXTLEN = 1000;
const int cDCMMAXZONE = 1024;
const int cDCMTEXTZONE = cDCMMAXZONE + 1;
const int cDCMRSSZONE = cDCMMAXZONE + 2;
const int cDCMCLOCKZONE = cDCMMAXZONE + 3;
const int cDCMWEATHERZONE = cDCMMAXZONE + 4;
const double cEPSILON = 0.00001;
const int cBYTEMAX = 255;

const int cINTMIN = -2147483648; /* minimum (signed) int value */
const int cINTMAX = 2147483647; /* maximum (signed) int value */

const int cWORDMAX = 0xffff;

const int cPLAYINGDURATION = 200;
const double cPLAYINGINTERVAL = 0.05; //interval

//Content type define
const int cIMAGETYPE = 0;
const int cVIDEOTYPE = 1;
//const int	VCD_TYPE = 1;
const int cDVDTYPE = 2;
const int cPOWERPOINTTYPE = 3;
const int cWEBPAGETYPE = 4;
const int cFLASHTYPE = 5;
const int cTVCAPTURETYPE = 6;
const int cTEXTTYPE = 7;
const int cSTREAMINGTYPE = 8;
const int cONLINETYPE = 9;
const int cCLOCKTYPE = 10;
const int cWEBCAMTYPE = 11;
const int cDDETYPE = 12;
const int cWEATHERTYPE = 13;
const int cDIRECTPLAYTYPE = 14;
const int cEXPLORERTYPE = 15;
const int cLINKAGETYPE = 16;
const int cEVENTTYPE = 17;
const int cPLUGINTYPE = 18;
const int cCAROUSELTYPE = 19;
const int cQUEUETYPE = 20;
const int cSITEPLAYLIST = 21;
const int cLIGHTBOXTYPE = 22;
const int cWMEDIATYPE = 23;
const int cQUICKTIMETYPE = 24;
const int cAUDIOTYPE = 25;
const int cPDFTYPE = 26;
const int cAMELEMENTTYPE = 27;
const int cAMCONTENTTYPE = 28;
const int cRSSTYPE = 29;
const int cNETWORKVIDEOTYPE = 30;
const int cTHUMBVIEWTYPE = 31;

const int cDCMMONTHTYPE = 100;
const int cDCMDAYTYPE = 101;
const int cDCMFILETYPE = 102;
const int cDCMSETTINGTYPE = 103;
const int cDCMLAYOUTTYPE = 104;
const int cDCMGRAPHICSTYPE = 106;
const int cDCMSKINSTYPE = 107;
const int cDCMAHMESSAGETYPE = 108;
const int cDCMCONTENTLISTDATATYPE = 109;
const int cDCMCONTENTLISTXMLTYPE = 110;
const int cDCMSINGLEIMAGETYPE = 111;
const int cDCMDDEOTHERTYPE = 112;
const int cDCMPREDATATYPE = 113;
const int cDCMPUBLISHTYPE = 114;
const int cDCMPLAYERTYPE = 115;
const int cDCMCALENDARTYPE = 117;
const int cDCMAHPLAYLISTTYPE = 118;
const int cDCMROOMTYPE = 119;
const int cDCMROOMEVENTTYPE = 120;
const int cDCMLOBBYTYPE = 121;
const int cDCMSITEDATATYPE = 122;
const int cDCMJSONTYPE = 123;

const int cDCMPRODUCTTYPE = 300;
const int cDCMDYNAMICDATATYPE = 301;
const int cDCMOTHERTYPE = 302;
const int cDCMRLTCONTENTTYPE = 303;
const int cDCMUPDATETYPE = 304;

const int cTRANSPARENTZONETYPE = 1200;
const int cPOPUPWINDOWTYPE = 1110;

//Global Setting define
const int settingHIDECURSOR = 0x00000001;
const int settingLANGBTN = 0x00000002;
const int settingVALIDCLONLYTIME = 0x00000004;
const int settingMULTICAPTURE = 0x00000008;
const int settingCHECKSUM = 0x00000010;
const int settingWOW64 = 0x00000020;
const int settingPLAYLISTLOG = 0x00000040;
const int settingUSBLOG = 0x00000080;
const int settingMSGLOG = 0x00000100;
const int settingAHPLAYLOG = 0x00000200;
const int settingMUTEALL = 0x00000400;
const int settingQC = 0x00000800;

//Content Clean
const int settingCONTENTCLEAN = 0x00010000;
const int settingWEBREFRESHINTERVAL = 0x00020000;
const int settingASPLAYLIST = 0x00040000;
const int settingSIMPLEFILELIST = 0x00080000;
const int settingMOCKDBCLICK = 0x00100000;
const int settingWEBVIEW2BUFFER = 0x00200000;

//Log all contents in current playlist
const int settingCONTENTLOG = 0x00400000;

//disable play content in catalogue wizard - content page
const int settingNOTPLAYCONTENT = 0x00800000;

//Capture Device Identifier - Frield Name/Device path
const int settingCDI = 0x01000000;

//Layout page tip window - Catalogue wizard
const int settingLAYOUTTIPWINDOWN = 0x02000000;
//WEB API backend
const int settingAPIBACKEND = 0x04000000;

//Schedule setting define
const int settingRETURNBRKPTS = 0x00000001;
const int settingLATESTPLAYLIST = 0x00010000;

const String cmsPLAYERLOGURL =
    'api/pm/players/log'; //'services/api/players/log';
const String cmsPLAYERLOG2URL = 'api/log/playerLog2s/create';
const String cmsPLAYLISTLOGURL =
    'api/pm/players/playlistlog'; //'services/api/players/playlistlog';
const String cmsEVENTDISPLAYURL =
    'api/book/myCalendars/eventdisplay'; //'services/api/myCalendars/eventdisplay';
const String cmsDAILYLISTURL =
    'api/cm/dailyLists/xmlfilelist'; //services/api/dailyLists/xmlfilelist
const String cmsCONTENTLISTURL =
    'api/cm/contentLists/xmlfilelist'; //services/api/contentLists/xmlfilelist
const String cmsSyncSTATUSURL =
    'api/pm/ftpStatuses/create'; //services/api/ftpStatuses/create
const String cmsPLAYERTASKURL =
    'api/pm/players/tasks'; //services/api/players/tasks
const String cmsPLAYERTASKUPDATEURL = 'api/pm/players/tasks/update';
const String cmsPLAYERREGISTERURL =
    'api/pm/players/register'; //services/api/players/register
const String cmsPLAYERSITEURL = 'api/pm/players/site';
const String cmsPLAYERIPURL = 'api/pm/players/ip';
const String cmsPLAYLOGURL = 'api/log/playLogs/create';
const String cmsGETPLAYLISTURL = 'api/pm/players/playlists';
const String cmsGETFILELISTURL = 'api/pm/players/filelist';
const String cmsGETSETTINGSURL = 'api/pm/settings';
const String cmsCONTENTLOGURL = 'api/log/contentLogs/create';

//volume for MediaKit
const double cVOLUMEFULL = 100.0;
const double cVOLUMESILENCE = 0.0;

//Play mode
const int cPLAYNORMAL = 0x0001; //Normal mode
const int cPLAYPREVIEW = 0x0002; //Preview mode
const int cPLAYTEST = 0x0004; //Test Mode
const int cPLAYOTHER = 0x0008; //Other Mode
const int cPLAYEVENT = 0x0010; //Event Mode

const int cPLAYAPTKM = 0x0100; //accecpt keydown event
const int cPLAYSYNC = 0x0200; //Synchronous playback

//Muti Monitor define
const int cSINGLEMONITOR = 0x0000; //0-single monitor;
const int cMULTIMONITORLD = 0x0001; //1-use multi monitor as one large display;
const int cMULTIMONITORDV = 0x0002; //2-independently multi monitor(Dualview);
const int cMULTIMONITOREP = 0x0010; //16-(editor + player) mode
const int cMULTIMONITORP2P = 0x0020; //32-(editor to player) mode

//builtin Content Type
//Content Type Name
class ContentTypeEntry {
  String strContentTypeName;
  String strFilter;
  int nLangID = 0;
  int nSeq = 0;
  BigInt dwFlag = BigInt.zero;
  BigInt dwFlags = BigInt.zero;
  String strSettingKey;

  ContentTypeEntry(
      {required this.strContentTypeName,
      required this.strFilter,
      required this.nLangID,
      required this.nSeq,
      required this.dwFlag,
      required this.dwFlags,
      required this.strSettingKey});
}

final List<ContentTypeEntry> contentTypeTable = [
  ContentTypeEntry(
      strContentTypeName: 'Image',
      strFilter: '|.JPG|.JPEG|.BMP|.GIF|.PNG|TIFF|.WMF|.EMF|',
      nLangID: 0,
      nSeq: 0,
      dwFlag: BigInt.from(1),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Video file',
      strFilter:
          '|.DAT|.WMV|.WMA|.AVI|.MPG|.MPEG|.VOB|.ASF|.RMVB|.RM|.MOV|.MKV|.HDMOV|.MP4|.DV|.FLV|.FLC|.FLI|.F4V|',
      nLangID: 1,
      nSeq: 1,
      dwFlag: BigInt.from(2),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'DVD',
      strFilter: 'Obsolete',
      nLangID: -1,
      nSeq: -1,
      dwFlag: BigInt.zero,
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'PowerPoint',
      strFilter: '|.PPT|.PPS|.POT|.PPTX|.PPTM|.PPSX|.PPSM|',
      nLangID: 3,
      nSeq: 3,
      dwFlag: BigInt.from(4),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Web Page',
      strFilter: '|.HTM|.HTML|.HTX|.MHT|',
      nLangID: 4,
      nSeq: 4,
      dwFlag: BigInt.from(8),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Flash',
      strFilter: '|.SWF|',
      nLangID: 5,
      nSeq: 5,
      dwFlag: BigInt.from(16),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'TV Capture',
      strFilter: '',
      nLangID: 6,
      nSeq: 6,
      dwFlag: BigInt.from(32),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Text',
      strFilter: '|.XML|',
      nLangID: 7,
      nSeq: 2,
      dwFlag: BigInt.from(64),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Media Streaming',
      strFilter: '',
      nLangID: 8,
      nSeq: 7,
      dwFlag: BigInt.from(128),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Online Information',
      strFilter: '',
      nLangID: 9,
      nSeq: 8,
      dwFlag: BigInt.from(256),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Clock',
      strFilter: '|.XML|',
      nLangID: 10,
      nSeq: 9,
      dwFlag: BigInt.from(512),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Web Camera',
      strFilter: '',
      nLangID: 11,
      nSeq: 10,
      dwFlag: BigInt.from(1024),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'DDE',
      strFilter: '|.XML|',
      nLangID: 12,
      nSeq: 11,
      dwFlag: BigInt.from(2048),
      dwFlags: BigInt.from(31),
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Weather',
      strFilter: '|.XML|',
      nLangID: 13,
      nSeq: 12,
      dwFlag: BigInt.from(4096),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Content List',
      strFilter: '|.XML|',
      nLangID: 14,
      nSeq: 13,
      dwFlag: BigInt.from(8192),
      dwFlags: BigInt.from(31),
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Explorer',
      strFilter: '',
      nLangID: 15,
      nSeq: 14,
      dwFlag: BigInt.from(16384),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Add-on text',
      strFilter: '|.XML|',
      nLangID: 16,
      nSeq: 15,
      dwFlag: BigInt.from(32768),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Event',
      strFilter: '',
      nLangID: 17,
      nSeq: 16,
      dwFlag: BigInt.from(65535),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Plugin',
      strFilter: '',
      nLangID: 18,
      nSeq: 17,
      dwFlag: BigInt.from(131072),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Carousel SlideShow',
      strFilter: '|.XML|',
      nLangID: 19,
      nSeq: 18,
      dwFlag: BigInt.from(262144),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Queue',
      strFilter: '|.XML|',
      nLangID: 20,
      nSeq: 19,
      dwFlag: BigInt.from(524288),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Site Playlist',
      strFilter: '|.XML|',
      nLangID: 21,
      nSeq: 20,
      dwFlag: BigInt.from(1048576),
      dwFlags: BigInt.from(31),
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'LightBox',
      strFilter: '',
      nLangID: 22,
      nSeq: 21,
      dwFlag: BigInt.from(2097152),
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'Windows Media',
      strFilter: '|.AAC|.ASF|.AVI|.M4A|.MP3|.MP4|.WAV|.WMA|.WMV|.3GP|.3G2|',
      nLangID: 23,
      nSeq: -1,
      dwFlag: BigInt.zero,
      dwFlags: BigInt.zero,
      strSettingKey: ''),
  ContentTypeEntry(
      strContentTypeName: 'QuickTime',
      strFilter: '|.MOV|.HDMOV|.MP4|',
      nLangID: 24,
      nSeq: -1,
      dwFlag: BigInt.zero,
      dwFlags: BigInt.zero,
      strSettingKey: ''), //4194304
  ContentTypeEntry(
      strContentTypeName: 'Audio file',
      strFilter: '|.MP3|.WMA|.WAV|.MID|.MPG|.MPEG|.ASF|.RM|.DAT|.WMV|.AVI|',
      nLangID: 25,
      nSeq: -1,
      dwFlag: BigInt.zero,
      dwFlags: BigInt.zero,
      strSettingKey: '') //4194304
];

enum PlayerStatus {
  eWAITINGFORDOWNLOAD,
  eSTARTINGDOWNLOAD,
  eDOWNLOADING,
  eDOWNLOADFINISHED,
  eDOWNLOADFAILURE,
  eDOWNLOADRESETTED,
}

enum PlayerNotice {
  eAHMESSAGENOTICE,
  eAHDIRECTNOTICE,
  eDCMEDITORNOTICE,
  eSyncFINISHEDNOTICE,
  ePLAYLOGERNOTICE,
  ePLAYCLOSENOTICE,
  eUSBIMPFINISHEDNOTICE,
  eCHANGEPLAYLISTNOTICE,
  eFORMATDNOTICE,
  eBLACKSCRNNOTICE,
  eONEKEYNOTICE,
  eREFRESHNOTICE,
}

enum AHMessagePos {
  eAHFULLSCREEN,
  eAHTOP,
  eAHBOTTOM,
  eAHINZONE, //play ah in Specified zone but not stop zone play
  eAHBOTTOMMZ,
  eAHREPLACEZONE, //play ah in Specified zone  and stop current zone play
}

const int cAHMSGOVERLAY = 0x0001; //AH Message overlay in playlist
const int cAHMSGSTOPPLAYLIST =
    0x0002; //stop current playlist when play AH message
const int cAHMSGLAYERED = 0x0004; //Message overlay message

enum SchedulePlayMeth {
  eSEQUENCEPLAYLIST,
  eCROSSPLAYLIST,
  ePEROUTPUTPLAYLIST,
  eAHPLAYLIST,
}

enum PlayFinish {
  eNOTSPECIFIED,
  eNOTFINISH,
  eCONTENTFINISH,
  eZONEFINISH,
  ePRODUCTFINISH,
  eCONTENTSTARTING,
}

enum ButtonPosition { eBOTTOM, eRIGHT, eTOP, eLEFT, eTHUMBVIEW }
