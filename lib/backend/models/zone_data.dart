import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

/// Zone effect types
enum ZoneEffectType {
  noEffect(100),
  contentAlpha(101),
  zoneAlpha(102);

  final int value;
  const ZoneEffectType(this.value);
}

class Channel {
  Channel(this.strChannel, this.strChannelName, this.lFrequency);

  String strChannel;
  String strChannelName;
  int lFrequency;
}

/// Class to hold the data for Zone Data
class ZoneData {
  // Attributes
  int uiID = 0;
  int uiCatalogueID = 0;
  int uiIndex = 0;
  int nProductIndex = 0;
  int uiChannelID = 0;
  int nZoneID = 0;
  int nZoneType = 0; // Zone 1 file type(Image,VCD,DVD,Powerpoint,Flash,WEB)
  String strZoneFile = ''; // Zone 1 File Name
  String strZoneOfflineFile = ''; // Zone Offline file name
  int crZoneBGColor = 0; // Zone 1 backgroup color
  String strZoneBGFile = ''; // zone 1 backgroup image file
  bool bZoneSelectBgPic = false;
  bool bChkZone = false;
  bool bDDERefresh = false;

  // Add for Video control 26/02/2010
  int nZoom = 0; // video zoom
  double dAspect = 0.0; // aspect ratio
  double dVolume = 0.0; // volume level
  double dSpeed = 0.0; // speed

  int bAlpha = 0;

  bool bZoneMute = false; // Zone 1 Mute or not
  bool bZoneRatio = false; // Zone 1 Aspect Ratio or not
  double nZoneDuration = 0.0; // Zone 1 duration
  int nZonePort = 0; // Online information port

  int nZoneEffectType = 0; // zone 1 effect type
  int nZoneOrientation = 0; // zone 1 effect 1
  int nZoneMotion = 0; // zone 1 effect 2
  int nZoneDelay = 0; // zone 1 effect 3
  int nZoneDirection = 0; // zone 1 effect 4

  // Add for Webpage control 26/02/2010
  String strWebCharset = ''; // Code page
  int nWebZoom = 0; // Webpage zoom

  bool bZoneChkMpeg2 = false;
  int nVideoCompressor = 0;
  int nZoneTVSource = 0;
  int nZoneTVStandard = 0;
  int nZoneTVInput = 0;
  int nZoneTVInputType = 0;
  int nZoneTVTuningSpace = 0;
  int nZoneTVCountry = 0;
  int lFrequency = 0;
  String strZoneTVChannel = '';
  String strZoneTVSource = '';
  List<Channel>? arrZoneChannel;

  int nAudioSource = 0;
  int nAudioStandard = 0;
  String strAudioSource = '';
  String strAudioDevice = '';

  /// Check if this is mixed content
  bool isMixedContent() {
    return (nZoneType == cDIRECTPLAYTYPE ||
        nZoneType == cDDETYPE ||
        nZoneType == cSITEPLAYLIST);
  }

  int getAlpha() => bAlpha;
  void setAlpha(int bAlpha) => bAlpha = bAlpha;

  int getZoneEffect() {
    return (nZoneEffectType < ZoneEffectType.contentAlpha.value
        ? ZoneEffectType.noEffect.value
        : nZoneEffectType);
  }

  void setZoneEffect(int nEffect) {
    nZoneEffectType = nEffect;
  }

  int getTVChannel() {
    return int.tryParse(strZoneTVChannel) ?? 0;
  }

  int getChannelCount() {
    if (arrZoneChannel == null) return 0;

    return arrZoneChannel!.length;
  }

  void removeAllChannel() {
    arrZoneChannel = null;
  }

  int getChannel(int nIndex) {
    if (arrZoneChannel == null || nIndex >= arrZoneChannel!.length) return -1;

    return int.tryParse(arrZoneChannel![nIndex].strChannel) ?? 0;
  }

  void setTVChannel(int nChannel) {
    strZoneTVChannel = nChannel.toString();
  }

  String getChannelName(int nIndex) {
    if (arrZoneChannel == null || nIndex >= arrZoneChannel!.length) {
      return '';
    }

    return arrZoneChannel![nIndex].strChannelName;
  }

  String getChannelDesc(int nIndex) {
    if (arrZoneChannel == null || nIndex >= arrZoneChannel!.length) {
      return '';
    }

    return arrZoneChannel![nIndex].strChannel;
  }

  int getChannelFreq(int nIndex) {
    if (arrZoneChannel == null || nIndex >= arrZoneChannel!.length) return -1;

    return arrZoneChannel![nIndex].lFrequency;
  }

  /// Write to XML
  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_uiID', uiID);
    pXmlItem.addItem('m_uiCatalogueID', uiCatalogueID);
    pXmlItem.addItem('m_uiIndex', uiIndex);
    pXmlItem.addItem('m_nProductIndex', nProductIndex);
    pXmlItem.addItem('m_uiChannelID', uiChannelID);
    pXmlItem.addItem('m_nZoneID', nZoneID);
    pXmlItem.addItem('m_nZoneType', nZoneType);
    pXmlItem.addItem('m_strZoneFile', strZoneFile);
    pXmlItem.addItem('m_strZoneOfflineFile', strZoneOfflineFile);
    pXmlItem.addItem('m_crZoneBGColor', crZoneBGColor);
    pXmlItem.addItem('m_strZoneBGFile', strZoneBGFile);
    pXmlItem.addItem('m_bZoneSelectBgPic', bZoneSelectBgPic ? '1' : '0');
    pXmlItem.addItem('m_bChkZone', bChkZone ? '1' : '0');
    pXmlItem.addItem('m_bDDERefresh', bDDERefresh ? '1' : '0');
    pXmlItem.addItem('m_nZoom', nZoom);
    pXmlItem.addItem('m_dAspect', dAspect);
    pXmlItem.addItem('m_dVolume', dVolume);
    pXmlItem.addItem('m_dSpeed', dSpeed);
    pXmlItem.addItem('m_bAlpha', bAlpha);
    pXmlItem.addItem('m_bZoneMute', bZoneMute ? '1' : '0');
    pXmlItem.addItem('m_bZoneRatio', bZoneRatio ? '1' : '0');
    pXmlItem.addItem('m_nZoneDuration', nZoneDuration);
    pXmlItem.addItem('m_nZonePort', nZonePort);
    pXmlItem.addItem('m_nZoneEffectType', nZoneEffectType);
    pXmlItem.addItem('m_nZoneOrientation', nZoneOrientation);
    pXmlItem.addItem('m_nZoneMotion', nZoneMotion);
    pXmlItem.addItem('m_nZoneDelay', nZoneDelay);
    pXmlItem.addItem('m_nZoneDirection', nZoneDirection);
    pXmlItem.addItem('m_strWebCharset', strWebCharset);
    pXmlItem.addItem('m_nWebZoom', nWebZoom);
    pXmlItem.addItem('m_bZoneChkMpeg2', bZoneChkMpeg2 ? '1' : '0');
    pXmlItem.addItem('m_nVideoCompressor', nVideoCompressor);
    pXmlItem.addItem('m_nZoneTVSource', nZoneTVSource);
    pXmlItem.addItem('m_nZoneTVStandard', nZoneTVStandard);
    pXmlItem.addItem('m_nZoneTVInput', nZoneTVInput);
    pXmlItem.addItem('m_nZoneTVInputType', nZoneTVInputType);
    pXmlItem.addItem('m_nZoneTVTuningSpace', nZoneTVTuningSpace);
    pXmlItem.addItem('m_nZoneTVCountry', nZoneTVCountry);
    pXmlItem.addItem('m_lFrequency', lFrequency);
    pXmlItem.addItem('m_strZoneTVChannel', strZoneTVChannel);
    pXmlItem.addItem('m_strZoneTVSource', strZoneTVSource);
    pXmlItem.addItem('m_nAudioSource', nAudioSource);
    pXmlItem.addItem('m_nAudioStandard', nAudioStandard);
    pXmlItem.addItem('m_strAudioSource', strAudioSource);
    pXmlItem.addItem('m_strAudioDevice', strAudioDevice);
  }

  /// Get from XML
  void getFromXML(XmlItem pXmlItem) {
    uiID = pXmlItem.getItemValueI('m_uiID');
    uiCatalogueID = pXmlItem.getItemValueI('m_uiCatalogueID');
    uiIndex = pXmlItem.getItemValueI('m_uiIndex');
    nProductIndex = pXmlItem.getItemValueI('m_nProductIndex');
    uiChannelID = pXmlItem.getItemValueI('m_uiChannelID');
    nZoneID = pXmlItem.getItemValueI('m_nZoneID');
    nZoneType = pXmlItem.getItemValueI('m_nZoneType');
    strZoneFile = pXmlItem.getItemValue('m_strZoneFile');
    strZoneOfflineFile = pXmlItem.getItemValue('m_strZoneOfflineFile');
    crZoneBGColor = pXmlItem.getItemValueI('m_crZoneBGColor');
    strZoneBGFile = pXmlItem.getItemValue('m_strZoneBGFile');
    bZoneSelectBgPic = pXmlItem.getItemValueI('m_bZoneSelectBgPic') == 1;
    bChkZone = pXmlItem.getItemValueI('m_bChkZone') == 1;
    bDDERefresh = pXmlItem.getItemValueI('m_bDDERefresh') == 1;
    nZoom = pXmlItem.getItemValueI('m_nZoom');
    dAspect = pXmlItem.getItemValueF('m_dAspect');
    dVolume = pXmlItem.getItemValueF('m_dVolume');
    dSpeed = pXmlItem.getItemValueF('m_dSpeed');
    bAlpha = pXmlItem.getItemValueI('m_bAlpha');
    bZoneMute = pXmlItem.getItemValueI('m_bZoneMute') == 1;
    bZoneRatio = pXmlItem.getItemValueI('m_bZoneRatio') == 1;
    nZoneDuration = pXmlItem.getItemValueF('m_nZoneDuration');
    nZonePort = pXmlItem.getItemValueI('m_nZonePort');
    nZoneEffectType = pXmlItem.getItemValueI('m_nZoneEffectType');
    nZoneOrientation = pXmlItem.getItemValueI('m_nZoneOrientation');
    nZoneMotion = pXmlItem.getItemValueI('m_nZoneMotion');
    nZoneDelay = pXmlItem.getItemValueI('m_nZoneDelay');
    nZoneDirection = pXmlItem.getItemValueI('m_nZoneDirection');
    strWebCharset = pXmlItem.getItemValue('m_strWebCharset');
    nWebZoom = pXmlItem.getItemValueI('m_nWebZoom');
    bZoneChkMpeg2 = pXmlItem.getItemValueI('m_bZoneChkMpeg2') == 1;
    nVideoCompressor = pXmlItem.getItemValueI('m_nVideoCompressor');
    nZoneTVSource = pXmlItem.getItemValueI('m_nZoneTVSource');
    nZoneTVStandard = pXmlItem.getItemValueI('m_nZoneTVStandard');
    nZoneTVInput = pXmlItem.getItemValueI('m_nZoneTVInput');
    nZoneTVInputType = pXmlItem.getItemValueI('m_nZoneTVInputType');
    nZoneTVTuningSpace = pXmlItem.getItemValueI('m_nZoneTVTuningSpace');
    nZoneTVCountry = pXmlItem.getItemValueI('m_nZoneTVCountry');
    lFrequency = pXmlItem.getItemValueI('m_lFrequency');
    strZoneTVChannel = pXmlItem.getItemValue('m_strZoneTVChannel');
    strZoneTVSource = pXmlItem.getItemValue('m_strZoneTVSource');
    nAudioSource = pXmlItem.getItemValueI('m_nAudioSource');
    nAudioStandard = pXmlItem.getItemValueI('m_nAudioStandard');
    strAudioSource = pXmlItem.getItemValue('m_strAudioSource');
    strAudioDevice = pXmlItem.getItemValue('m_strAudioDevice');
  }

  /// Create a copy of this ZoneData
  ZoneData copy() {
    final copy = ZoneData();
    copy.uiID = uiID;
    copy.uiCatalogueID = uiCatalogueID;
    copy.uiIndex = uiIndex;
    copy.nProductIndex = nProductIndex;
    copy.uiChannelID = uiChannelID;
    copy.nZoneID = nZoneID;
    copy.nZoneType = nZoneType;
    copy.strZoneFile = strZoneFile;
    copy.strZoneOfflineFile = strZoneOfflineFile;
    copy.crZoneBGColor = crZoneBGColor;
    copy.strZoneBGFile = strZoneBGFile;
    copy.bZoneSelectBgPic = bZoneSelectBgPic;
    copy.bChkZone = bChkZone;
    copy.bDDERefresh = bDDERefresh;
    copy.nZoom = nZoom;
    copy.dAspect = dAspect;
    copy.dVolume = dVolume;
    copy.dSpeed = dSpeed;
    copy.bAlpha = bAlpha;
    copy.bZoneMute = bZoneMute;
    copy.bZoneRatio = bZoneRatio;
    copy.nZoneDuration = nZoneDuration;
    copy.nZonePort = nZonePort;
    copy.nZoneEffectType = nZoneEffectType;
    copy.nZoneOrientation = nZoneOrientation;
    copy.nZoneMotion = nZoneMotion;
    copy.nZoneDelay = nZoneDelay;
    copy.nZoneDirection = nZoneDirection;
    copy.strWebCharset = strWebCharset;
    copy.nWebZoom = nWebZoom;
    copy.bZoneChkMpeg2 = bZoneChkMpeg2;
    copy.nVideoCompressor = nVideoCompressor;
    copy.nZoneTVSource = nZoneTVSource;
    copy.nZoneTVStandard = nZoneTVStandard;
    copy.nZoneTVInput = nZoneTVInput;
    copy.nZoneTVInputType = nZoneTVInputType;
    copy.nZoneTVTuningSpace = nZoneTVTuningSpace;
    copy.nZoneTVCountry = nZoneTVCountry;
    copy.lFrequency = lFrequency;
    copy.strZoneTVChannel = strZoneTVChannel;
    copy.strZoneTVSource = strZoneTVSource;
    copy.nAudioSource = nAudioSource;
    copy.nAudioStandard = nAudioStandard;
    copy.strAudioSource = strAudioSource;
    copy.strAudioDevice = strAudioDevice;

    return copy;
  }
}
