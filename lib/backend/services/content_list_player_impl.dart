import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/models/zoneext_data.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// A Flutter/Dart replacement for the legacy ContentListPlayer C++ implementation.
class ContentListPlayerImpl {
  int _currPlaying = 0;
  int _videoStatus = -1;
  bool _bTimeForStop = false;
  bool _bIsAHPlaying = false;
  bool _bFirstFinished = false;
  bool _bShowMessage = false;
  bool _bShowMessageNext = false;
  int _nParentContentType = 0;
  late String _strContentListPath;
  String _strCompany = '';
  String _strLayout = '';
  DateTime? _dtStartTime;
  Rect? _playerRect;
  final List<PlayerZoneImpl> _players = [];
  List<Rect>? _arrZoneRect;
  Map<String, LayoutData>? _mapLayouts;
  List<ProductData>? _lstProduct;
  Map<String, PreloadedContent>? _mapPreloadedContents;

  ProductData? _pProductData;
  bool _bIsPlaying = false;
  bool _bNeedStop = false;

  int _nCurrProduct = 0;
  int _nContentType;
  int _nPType = -1;
  int _nZone;
  int _nPrevTotalZone = 0;

  int _nPlayAHItem = -1;
  int _dwPlayADItem = 0;

  double _rtDuration = 0.0;
  DateTime _dwFirstTime = DateTime.now();
  int _nUpdateInterval = 0;

  ContentListPlayerImpl(this._nContentType, this._nZone) {
    if (_nContentType == cDDETYPE) {
      _strContentListPath = DCMGlobal.ddeXmlPath;
    } else if (_nContentType == cDIRECTPLAYTYPE) {
      _strContentListPath = DCMGlobal.contentListPath;
    } else {
      _strContentListPath = DCMGlobal.siteContentPath;
    }
  }

  bool get bTimeForStop => _bTimeForStop;
  List<PlayerZoneImpl> get players => _players;

  bool saveContentList(String strContentList) {
    return true;
  }

  bool loadContentList(
      {String? contentList,
      MessageData? messageData,
      DateTime? dtStart,
      DateTime? dtEnd}) {
    _lstProduct?.clear();
    _lstProduct ??= [];
    if (messageData != null) {
      messageData.getProductInitFromZoneData(_lstProduct!);
      return (_lstProduct!.isNotEmpty);
    } else if (contentList != null) {
      //<?xml version="1.0" encoding="UTF-8" ?>
      String strXmlHeader = '<?xml version="1.0" encoding="UTF-8"?>';
      if (contentList.length > strXmlHeader.length &&
          strXmlHeader.equalsIgnoreCase(
              contentList.substring(0, strXmlHeader.length))) {
        XmlFilePro fileLocal = XmlFilePro('Contents', null);
        if (fileLocal.loadXml(contentList)) {
          //IXmlItem *pContents = fileLocal.GetItem('Contents');
          XmlItem? pXISibling = fileLocal.root().getItem('Content');
          while (pXISibling != null) {
            ProductData pProduct = ProductData();
            _lstProduct!.add(pProduct);

            pProduct.strProductName = pXISibling.getItemValue('seq');
            pProduct.uiID = pXISibling.getItemValueI('seq');

            ZoneExtData pZone = ZoneExtData();
            pZone.nZoneID = 0;
            pZone.nZoneType = pXISibling.getItemValueI('contentType');
            pZone.strZoneFile = pXISibling.getItemValue('fileName');
            pZone.nZoneDuration = pXISibling.getItemValueF('duration');
            bool bMute = pXISibling.getItemValueI('mute') > 0;
            pZone.dVolume = bMute ? 0 : 100;
            pZone.bZoneMute = bMute;
            pZone.bZoneRatio = pXISibling.getItemValueI('aspectRatio') > 0;
            pZone.dtStartTime = pXISibling.getItemValueD('startTime');
            pZone.dtEndTime = pXISibling.getItemValueD('endTime');

            pProduct.lstZone.add(pZone);

            pXISibling = pXISibling.getSibling();
          }
        }

        return true;
      }

      String strXML = path.extension(contentList);
      String strFileName = _strContentListPath; //strFolder;
      if (strXML.equalsIgnoreCase('.XML')) {
        strFileName = contentList;
        if (!File(contentList).existsSync()) {
          strFileName = path.join(_strContentListPath,
              '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xml');
          //strContentList = strCurrContentList;
        }
        return serialize(strFileName);
      } else {
        if (contentList.isNotEmpty) {
          strFileName = contentList; //strFolder;
        }
        strFileName = '$strFileName\\*.xml';
        final directory = Directory(_strContentListPath);
        for (var entity in directory.listSync(recursive: false)) {
          if (entity is File &&
              !path.extension(entity.path).equalsIgnoreCase('.xml')) {
            serialize(entity.path);
          }
        }

        return true;
      }
    } else {
      dtStart ??= DateTime.now();
      dtEnd ??= DateTime.now();

      DateTime dtDay = dtStart;
      while (dtDay.compareTo(dtEnd) <= 0) {
        String strCurrContentList = path.join(_strContentListPath,
            '${DateFormat('yyyy-MM-dd').format(dtDay)}.xml');
        if (contentList != null && contentList.isNotEmpty) {
          strCurrContentList = path.join(_strContentListPath, contentList,
              '${DateFormat('yyyy-MM-dd').format(dtDay)}.xml');
        }
        serialize(strCurrContentList);

        dtDay = dtDay.add(const Duration(days: 1));
      }
    }

    return false;
  }

  Future<bool> isExistedContentList(MessageData messageData) {
    String strFileName =
        path.join(_strContentListPath, '${messageData.strAHName}.xml');

    return File(strFileName).exists();
  }

  bool isValidForPlay() {
    if (_lstProduct == null) return false;

    for (var pData in _lstProduct!) {
      if (pData.isValidForPlay()) {
        return true;
      }
    }
    return false;
  }

  bool isOutdated(ProductData productData) {
    ZoneData? pData = productData.lstZone.firstOrNull;
    return (pData != null && pData is ZoneExtData) ? pData.isOutdated() : true;
  }

  bool isTimeForPlay(ProductData productData) {
    if (productData.nLanguage > 9999) {
      return false;
    }

    ZoneData? pData = productData.lstZone.firstOrNull;
    return (pData != null && pData is ZoneExtData)
        ? pData.isTimeForPlay()
        : false;
  }

  //return next product data
  ({bool status, ProductData? pNextData}) getProductData({int nProduct = 0}) {
    if (_lstProduct == null) return (status: false, pNextData: null);

    int nIndex = 0;
    ProductData? pFirst;
    ProductData? pNextData;
    bool bExisted = false;
    for (int i = 0; i < _lstProduct!.length; i++) {
      ProductData? pData = getProductDataByID(i);
      if (pData != null && isTimeForPlay(pData)) {
        if (nIndex == 0) {
          pFirst = pData;
        }

        if (nIndex == nProduct) {
          _pProductData = pData;
          _strLayout = pData.strProductDesc;
          bExisted = true;
        } else if (nIndex == nProduct + 1) {
          pNextData = pData;
          break;
        }
        nIndex++;
      }
    }

    pNextData ??= pFirst;

    return (status: bExisted, pNextData: pNextData);
  }

  ProductData? getProductDataByID([int nProductID = 0]) {
    if (_lstProduct == null) return null;

    for (var pData in _lstProduct!) {
      if (pData.uiID == nProductID) {
        return pData;
      }
    }

    return null;
  }

  double getDuration([int nStart = 0]) {
    double dbDuration = 0.00;
    if (_lstProduct == null) return dbDuration;

    if (nStart <= 0) {
      for (var pData in _lstProduct!) {
        if (isTimeForPlay(pData)) {
          dbDuration += Utils.getMaxDuration(pData);
        }
      }
      return dbDuration;
    }

    for (int j = 0; j < nStart; j++) {
      int nIndex = 0;
      for (int i = 0; i < _lstProduct!.length; i++) {
        ProductData? pData = getProductDataByID(i);
        if (pData != null && isTimeForPlay(pData)) {
          if (nIndex == j) {
            dbDuration += Utils.getMaxDuration(pData);
            break;
          }
          nIndex++;
        }
      }
    }

    return dbDuration;
  }

  int getCount() {
    if (_lstProduct == null) return 0;

    int nCount = 0;
    for (var pData in _lstProduct!) {
      if (isTimeForPlay(pData)) {
        nCount++;
      }
    }
    return nCount;
  }

  bool hasContent(int nContentType) {
    if (_lstProduct == null) return false;

    for (final product in _lstProduct!) {
      if (product.hasContentType(nContentType)) {
        return true;
      }
    }
    return false;
  }

  int getCurrPlaying() => _currPlaying;

  void setCurrPlaying(int value) {
    if (value < 0) {
      _currPlaying = 0;
      return;
    }
    _currPlaying = value;
  }

  void setPlayerRect(Rect rect) {
    if (rect.isEmpty) {
      return;
    }

    _playerRect = rect;
    for (var playerZoneImpl in _players) {
      Rect rect = scaleToVW(playerZoneImpl.getZone());
      playerZoneImpl.setWindowRect(rect);
    }
  }

  void setAHPlaying(bool bIsAHPlaying) {
    _bIsAHPlaying = bIsAHPlaying;
  }

  void setParentContentType(int nParentContentType) {
    _nParentContentType = nParentContentType;
  }

  void setCompany(String? strCompany) {
    _strCompany = strCompany ?? '';
  }

  void setStartTime(DateTime? dtStartTime) {
    _dtStartTime = dtStartTime;
  }

  void setTimeForStop(bool timeForStop) {
    _bTimeForStop = timeForStop;
  }

  Future<bool> initZone(BuildContext context) async {
    stop();
    if (_lstProduct == null) return false;

    _mapPreloadedContents ??= {};
    for (var pData in _lstProduct!) {
      if (isTimeForPlay(pData)) {
        for (var pZoneData in pData.lstZone) {
          var proloadContent = await PlayerZoneImpl.preloadContent(
              pZoneData, context,
              company: _strCompany);
          if (proloadContent != null) {
            _mapPreloadedContents?[proloadContent.filePath] = proloadContent;
          }
        }
      }
    }

    return true;
  }

  void createZoneImpl(int nZone) {
    if (_players.length > nZone) {
      for (var pZoneImpl in _players) {
        if (pZoneImpl.getZone() == -1) {
          //pZoneImpl.stopPlay();
          pZoneImpl.setZone(nZone);
          pZoneImpl.setAHPlaying(_bIsAHPlaying);
          pZoneImpl.setWriteLog(true);
          pZoneImpl.setCompany(_strCompany);
          pZoneImpl.setProductData(_pProductData);
          pZoneImpl.setWindowRect(_arrZoneRect![nZone]);
          pZoneImpl.setParentContentType(_nContentType);
          //pZoneImpl.initZone();
          break;
        }
      }
    } else {
      PlayerZoneImpl pZoneImpl = PlayerZoneImpl();
      pZoneImpl.setZone(nZone);
      pZoneImpl.setAHPlaying(_bIsAHPlaying);
      pZoneImpl.setWriteLog(true);
      pZoneImpl.setCompany(_strCompany);
      pZoneImpl.setProductData(_pProductData);
      pZoneImpl.setWindowRect(_arrZoneRect![nZone]);
      pZoneImpl.setParentContentType(_nContentType);
      //pZoneImpl.initZone();

      _players.add(pZoneImpl);
    }
  }

  void deleteZoneImpl(int nZone) {
    while (_players.length > nZone) {
      _players[nZone].stopPlay();
      _players.removeAt(nZone);
    }
  }

  void stop() {
    /*if (_bIsPlaying)
      return;*/
    deleteZoneImpl(0);
    //_mapPreloadedContents?.clear();
    _nPrevTotalZone = -1;
    //_nPlayAHItem = -1;
    //_dwPlayADItem = 0;
    //g_pPlayerWnd->DetachMZThread(_nZone);
    _bIsPlaying = false;
  }

  void release() {
    _bIsPlaying = false;
    _players.clear();
    if (_mapPreloadedContents != null && _mapPreloadedContents!.isNotEmpty) {
      for (var preloadedContent in _mapPreloadedContents!.values) {
        preloadedContent.release();
      }
      _mapPreloadedContents!.clear();
    }

    _nPrevTotalZone = -1;
    //_nPlayAHItem = -1;
    //_dwPlayADItem = 0;
    //g_pPlayerWnd->DetachMZThread(_nZone);
  }

  void play([int nStart = 0]) {
    _dwFirstTime = DateTime.now();
    playProduct(nStart, true);
  }

  void stopCurrProduct() {
    if (_bIsPlaying) return;

    _nUpdateInterval = 0;
    if (!_bNeedStop) {
      return;
    }

    for (var pImpl in _players) {
      pImpl.stopPlay();
    }
    //g_pPlayerWnd->DetachMZThread(m_nZone);
    _bIsPlaying = false;
    logD(
        '''CContentListPlayer::StopCurrProduct; Zone:'$_nZone'; ${PlatformUtils().getMemoryLog()}; TID: '$pid'.''');
  }

  void playNextProduct() {
    //StopCurrProduct();
    //WriteMessage(MSG_INFO, _T("CContentListPlayer::PlayNextProduct; m_nPlayAHItem:%d; m_dwPlayADItem: %d, Thread ID %d!!!"), m_nPlayAHItem, m_dwPlayADItem, GetCurrentThreadId());
    if (_nPlayAHItem == -1 || _dwPlayADItem == 0) {
      if (getCount() <= _nCurrProduct + 1) {
        _nCurrProduct = 0;
      } else {
        _nCurrProduct++;
      }
    }

    playProduct(_nCurrProduct);
  }

  void playCurrProduct(ZoneExtData pZoneData) {
    PlayerZoneImpl? pPlayer = _players.firstOrNull;
    if (pPlayer == null) {
      pPlayer = PlayerZoneImpl();
      //pPlayer.SetContentListFlag(_nContentType == DDE_TYPE);
      pPlayer.setParentContentType(_nContentType);
      pPlayer.setWindowRect(_playerRect!);

      _players.add(pPlayer);
    }

    ProductData pProductData = ProductData();
    pProductData.uiID = 0;
    pProductData.lstZone.add(pZoneData.copy());
    if (!pProductData.isValidForPlay()) {
      return;
    }

    ZoneData? pData = pProductData.lstZone.firstOrNull;
    if (pData == null || (pData is ZoneExtData && !pData.isTimeForPlay())) {
      return;
    }

    _rtDuration = Utils.getMaxDuration(pProductData);
    pPlayer.setProductData(pProductData);
    pPlayer.setZone(pData.nZoneID);

    pPlayer.renderZone();

    pPlayer.setPlayingLine(_rtDuration, !pData.bChkZone);
    pPlayer.setStartPlayTime(DateTime.now());
    pPlayer.setWindowRect(_playerRect!);
  }

  void playProduct(int nIndex, [bool bStart = false]) {
    if (getCount() == 0) {
      logD(
          '''No item to play, Content Type: '$_nContentType'; Content Path: '$_strContentListPath'; TID: '$pid'.''');
      return;
    }

    ProductData? pNextProduct;
    ProductData? pCurrProduct = _pProductData;
    _nCurrProduct = nIndex;
    var result = getProductData(nProduct: nIndex);
    if (!result.status) {
      playNextProduct();
      return;
    }

    pNextProduct = result.pNextData;
    if (_nPType != cEVENTTYPE && _nPlayAHItem == -1 && _dwPlayADItem == 0) {
      ScheduleList().setContentListIndex(_nZone, nIndex, _lstProduct!.length);
    }

    if (_pProductData == null) {
      playNextProduct();
      return;
    }

    if (!_pProductData!.isValidForPlay()) {
      playNextProduct();
      return;
    }

    if (_nPType == cEVENTTYPE &&
        getCount() == 1 &&
        pCurrProduct == _pProductData &&
        _pProductData!.lstZone.length == 1 &&
        _pProductData!.hasContentType(cWEBPAGETYPE)) {
      //logD('No need to play, Content Type: '%d'; Content Path: '%s'; TID: '%d'.', _nContentType, _strContentListPath);
      return;
    }

    _bIsPlaying = true;

    //g_pPlayerWnd->StopMZThread(_nZone);
    int nTotalZone = _pProductData!.lstZone.length;
    if (nTotalZone != _nPrevTotalZone) {
      _nPrevTotalZone = nTotalZone;
      matchZoneImpl(nTotalZone);
    }

    _rtDuration = Utils.getMaxDuration(_pProductData);
    _dwFirstTime =
        _dwFirstTime.add(Duration(milliseconds: (_rtDuration * 1000).toInt()));
    int nMaxZone = nTotalZone;
    logD(
        '''ContentListPlayerImpl - playProduct, Zone:'$_nZone', Content list item: '$nIndex'; Max Zone '$nMaxZone'; duration:'${_rtDuration * 1000}', TID: '$pid'.''');

    int nZone = 0;
    for (nZone = 0; nZone < nMaxZone; nZone++) {
      Rect rect = scaleToVW(nZone);
      if (nZone > 0) {
        if (_players.length > nZone) {
          getZoneImpl(nZone)?.setWindowRect(rect);
        }
      }
      logD(
          '''ContentListPlayerImpl - playProduct, Zone:'$_nZone', Content list item: '$nIndex'; SetPlayerRect: '$rect', _mapPreloadedContents: '${_mapPreloadedContents?.length}'.''');
    }

    for (nZone = 0; nZone < nMaxZone; nZone++) {
      PlayerZoneImpl? pZoneImpl = getZoneImpl(nZone);
      ZoneData? pData = _pProductData!.getZoneData(nZone);
      if (pData == null) {
        continue;
      }

      if (pData.nZoneType == cPDFTYPE) {
        _nUpdateInterval = pData.nZoneDelay;
      }

      ZoneData? pNextData;
      if (pNextProduct != null) {
        pNextData =
            pNextProduct.getZoneData(nZone); //GetNextZone(nIndex + 1, nZone);
      }

      _bNeedStop = true;
      if (notNeedStop(pData, pNextData)) {
        _bNeedStop = false;
      }

      pZoneImpl!.setZone(nZone);
      pZoneImpl.setProductData(_pProductData);
      pZoneImpl.setAHPlaying(_bIsAHPlaying);
      pZoneImpl.initZone(_mapPreloadedContents);
      if (bStart) {
        /*if (!pZoneImpl.renderZone(pNextData)) {
            playNextProduct();
            _bIsPlaying = false;

            return;
          }*/
      } else {
        if (!pData.bChkZone) {
          /*if (!pZoneImpl.renderZone(pNextData)) {
              playNextProduct();
              _bIsPlaying = false;

              return;
            }*/
        } else {
          if (pZoneImpl.isZoneFinish()) {
            pZoneImpl.setZoneFinish(false);
            pZoneImpl.rePlayZone();
          }
        }
      }
      pZoneImpl.setPlayingLine(_rtDuration, !pData.bChkZone);
    }

    //logD('ContentList Index: '%d'; Start Time '%d'; duration:'%d', Thread ID '%d'!!!', nIndex, _dwFirstTime, (DWORD)(_rtDuration * 1000), GetCurrentThreadId());
    DateTime dwFirstTime0 = DateTime.now();
    for (var zoneImpl in _players) {
      zoneImpl.setStartPlayTime(dwFirstTime0);
    }
    logD(
        '''ContentListPlayerImpl - playProduct, Zone:'$_nZone'; Content list Item:'$nIndex'; Current time '$dwFirstTime0'; Play Dur.:'$_dwFirstTime', TID:'$pid'.''');
    _bIsPlaying = false;
  }

  bool notNeedStop(ZoneData pCurr, ZoneData? pNext) {
    /*if (pCurr.nZoneType == cVIDEOTYPE) {
      if (pNext != null) {
        if (pNext.nZoneType == cVIDEOTYPE) {
          return true;
        } else {
          pNext = null;
        }
      }

      return false;
    }

    if (pCurr.nZoneType == cIMAGETYPE ||
        pCurr.nZoneType == cFLASHTYPE ||
        pCurr.nZoneType == cWEBPAGETYPE) {
      if (pNext != null) {
        int nNextContentType = pNext.nZoneType;
        pNext = null;
        if ((pCurr.nZoneType == cIMAGETYPE && nNextContentType == cIMAGETYPE) ||
            (pCurr.nZoneType == cFLASHTYPE && nNextContentType == cFLASHTYPE) ||
            (pCurr.nZoneType == cWEBPAGETYPE &&
                nNextContentType == cWEBPAGETYPE)) {
          return true;
        }
      }
    }*/

    return false;
  }

  void rePlayProduct() {
    for (var zoneImpl in _players) {
      zoneImpl.rePlayZone();
    }
  }

  void rePlay() {
    _nCurrProduct = -1;
  }

  bool isShowMessage() => _bShowMessage;

  bool isShowMessageNext() => _bShowMessageNext;

  void videoStatusControl(int nVideoStatus) {
    _videoStatus = nVideoStatus;
  }

  ({bool status, PlayFinish? nFinish}) isPlayFinish(PlayFinish nFinish) {
    if (_bTimeForStop) return (status: false, nFinish: nFinish);

    DateTime dwSecondTime = DateTime.now();

    double rtPos = 0;
    for (PlayerZoneImpl pPlayer in _players) {
      double rtCurrPos1 = dwSecondTime
          .difference(pPlayer.getStartPlayTime())
          .inMilliseconds
          .toDouble();
      var result = pPlayer.getCurrentPosition();
      if (!result.status) {
        rtPos = rtCurrPos1 / Duration.millisecondsPerSecond;
      } else {
        rtPos = result.rtPosition!;
      }

      var nResult = pPlayer.isPlayerFinished(rtPos);
      logD(
          '''CContentListPlayer::IsPlayFinish; Zone:'${pPlayer.getZone()}'; _dwSecondTime:'${DateFormat('yyyy-MM-dd HH:mm:ss').format(dwSecondTime)}'; rtCurrPos1:'$rtCurrPos1'; rtPos:'$rtPos'; nResult: '$nResult'.''');
      if (nResult == 1) {
        pPlayer.setPlayingDuration(rtPos);
        pPlayer.setStartPlayTime(dwSecondTime);
        pPlayer.setZoneFinish(true);
        pPlayer.setFirstFinished();
      } else if (nResult == 2) {
        pPlayer.setPlayingDuration(rtPos);
        pPlayer.setStartPlayTime(dwSecondTime);
        pPlayer.setZoneFinish(true);
      }
    }

    if (!isProductFinished()) {
      for (var pPlayer in _players) {
        if (pPlayer.isZoneFinish()) {
          pPlayer.setZoneFinish(false);
          pPlayer.rePlayZone();
        }
      }
    } else {
      //WriteThreadLog(); //Write playlog for contentlist item
      if (getCount() <= _nCurrProduct + 1) {
        return (status: true, nFinish: nFinish);
      } else {
        nFinish = PlayFinish.eCONTENTFINISH;
        resetFirstFinished();
      }
    }

    return (status: false, nFinish: nFinish);
  }

  void resetFirstFinished() {
    for (var pPlayer in _players) {
      pPlayer.setZoneFinish(false);
      pPlayer.setFirstFinished(false);
    }
  }

  bool isProductFinished() {
    for (var pPlayer in _players) {
      if (!pPlayer.isFirstFinished()) {
        return false;
      }
    }

    return true;
  }

  void clear() {
    _lstProduct?.clear();
    _currPlaying = 0;
    _videoStatus = -1;
    _bTimeForStop = false;
    _bShowMessage = false;
    _bShowMessageNext = false;
    _bFirstFinished = false;
    _playerRect = null;
  }

  void reCalcPlayerRect(int nTotalZone) {
    for (int nZone = 0; nZone < nTotalZone; nZone++) {
      Rect rect = scaleToVW(nZone);
      addZoneRect(nZone, rect);
    }
  }

  Rect scaleToVW(int nZone) {
    Rect rcVW = Rect.fromLTWH(0, 0, _playerRect!.width, _playerRect!.height);

    String strLayout = _strLayout;
    if (strLayout.isNotEmpty) {
      if (_mapLayouts != null) {
        LayoutData? pLayout = _mapLayouts![strLayout];
        if (pLayout != null) {
          if (nZone + 1 > pLayout.iNoOfParition) {
            rcVW = Rect.zero;
          } else {
            rcVW = DCMFileImpl.getZoneRect(pLayout, nZone, rcVW, rcVW) ??
                Rect.fromLTWH(0, 0, _playerRect!.width, _playerRect!.height);
          }
        }
      }
    }

    return rcVW;
  }

  PlayerZoneImpl? getZoneImpl(int nZone) {
    for (var zoneImpl in _players) {
      if (zoneImpl.getZone() == nZone) {
        return zoneImpl;
      }
    }
    return null;
  }

  void matchZoneImpl(int nTotalZone) {
    if (nTotalZone <= 0) {
      return;
    }

    _arrZoneRect ??= [];
    if (nTotalZone > 1) {
      //logD('Content List Multi zone!');
      _arrZoneRect!.clear();
      for (int nZone = 0; nZone < nTotalZone; nZone++) {
        Rect rect = scaleToVW(nZone);
        addZoneRect(nZone, rect);
      }

      int nTotalZoneImpl = 1;
      int nTotalZoneThrd = nTotalZone - 1;
      deleteZoneImpl(nTotalZoneImpl);
      int i = 0;
      for (var pZoneImpl in _players) {
        pZoneImpl.setZone(-1);
      }

      //MatchMessageThread(MAXCONTENTLISTZONE);
      for (i = 0; i < nTotalZone; i++) {
        createZoneImpl(i);
      }
    } else {
      _arrZoneRect?.clear();
      Rect rect = Rect.fromLTWH(0, 0, _playerRect!.width, _playerRect!.height);
      addZoneRect(0, rect);

      int nTotalZoneImpl = 1;
      deleteZoneImpl(nTotalZoneImpl);
      for (var pZoneImpl in _players) {
        pZoneImpl.setZone(-1);
      }

      createZoneImpl(0);
    }
  }

  void addZoneRect(int nZone, Rect rcVW) {
    _arrZoneRect ??= [];
    if (_arrZoneRect!.length > nZone) {
      _arrZoneRect![nZone] = rcVW;
    } else {
      _arrZoneRect!.add(rcVW);
    }
  }

  /********************************************************************/
/*																	*/
/* Function name : Serialize										*/
/* Description   : Call this function to store/load the site data	*/
/*																	*/
  /// *****************************************************************
  bool serialize(String strFilename) {
    const String lpszSignature =
        'dcCatalogue Version 4.00 - Ad hoc Message List';
    _lstProduct?.clear();
    _mapLayouts?.clear();

    XmlFilePro file = XmlFilePro('AHMessage', null); //szPassword
    if (!file.open(strFilename, XfOpen.read, false)) {
      return false;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        _lstProduct ??= [];
        _mapLayouts ??= {};
        XmlItem? pMessageItem = file.getItem('MessageItem');
        if (pMessageItem != null) {
          //Layout Data
          XmlItem? pXILayout = pMessageItem.getItem('ContentListLayout');
          if (pXILayout != null) {
            XmlItem? pLayoutSibling = pXILayout.getItem('LayoutData');
            while (pLayoutSibling != null) {
              LayoutData pLayoutData =
                  DCMFileImpl.serializeLayoutFrom(pLayoutSibling);
              _mapLayouts![pLayoutData.strLayoutName] = pLayoutData;

              pLayoutSibling = pLayoutSibling.getSibling();
            }
          }

          int nCount = 0;
          int nLayoutCount = _mapLayouts!.length;
          XmlItem? pXISibling = pMessageItem.getItem('m_ZoneData');
          while (pXISibling != null) {
            ProductData pProduct = ProductData();
            _lstProduct!.add(pProduct);

            String strLayout = pXISibling.getItemValue('ContentListLayout');
            pProduct.strProductDesc =
                strLayout; //pXISibling.getItemValue('ContentListLayout');
            XmlItem? pXIID = pXISibling.getItem('ContentListID');
            if (pXIID == null) {
              pProduct.strProductName = '$nCount';
              pProduct.uiID = nCount;
            } else {
              pProduct.strProductName = pXISibling
                  .getItemValue('ContentListID'); //.Format('%d', nCount);
              //pProduct.strProductDesc = pXISibling.getItemValue('ContentListLayout');
              pProduct.uiID = pXISibling.getItemValueI('ContentListID') - 1;
            }
            pProduct.nLanguage =
                pXISibling.getItemValueI('ContentListItemType');
            String strTimeRange =
                pXISibling.getItemValue('ContentListTimeRange');

            ZoneExtData pZone = ZoneExtData();
            pZone.getFromXML(pXISibling);
            pProduct.lstZone.add(pZone);

            XmlItem? pZoneSibling = pXISibling.getItem('m_ZoneData');
            while (pZoneSibling != null) {
              pZone = ZoneExtData();
              pZone.getFromXML(pZoneSibling);
              pProduct.lstZone.add(pZone);

              pZoneSibling = pZoneSibling.getSibling();
            }

            pXISibling = pXISibling.getSibling();
            nCount++;
          }
        }
        return true;
      }
    }

    return false;
  }
}
