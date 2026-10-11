import 'dart:async';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/ah_playlist_impl.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/services/playlist_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:flutter/material.dart';

typedef BackToScheduleCallback = void Function(int wParam, int lParam);

class FloatingPlayerImpl {
  FloatingPlayerImpl();

  int _currPlaying = 0;
  bool _bTimeForStop = false;
  bool _bIsAHPlaying = false;
  String _strCompany = '';
  Rect? _playerRect;
  final List<PlayerZoneImpl> _players = [];
  Map<int, Rect>? _mapZoneRect;

  DCMFileData? _playFileData;
  ProductData? _pProductData;
  bool _bIsPlaying = false;
  bool _bIsLoading = false;
  bool _stopRequested = false;
  String? _strContent;
  double _dbDuration = 86400.00;

  PlayList? _pPlayList;
  int uiPlayType = 0;
  bool bPlayImm = false;
  bool _bIsPlayNextFile = false;
  bool _bNeedPlayNextProduct = false;
  bool _needNotifyListeners = false;

  int _nCurrProduct = 0;
  int nContentType = -1;
  int _nZone = -1;
  bool _bPlayConti = true;
  bool _bIsVisible = false;
  bool _bDisposed = false;
  bool _bDataChanged = false;
  bool _bWriteLog = true;
  Timer? _playingTimer;
  Timer? _timer;
  VoidCallback? _onStateChanged;
  int _nOutput = -1;
  int _bAlpha = -1;

  double _rtDuration = 0.0;
  double _rtCurrPos1 = 0.0;

  bool _pollInProgress = false;

  FloatingPlayerImpl.fromPlaylist(
      PlayList pPlayList, String strContent, this.bPlayImm,
      [this.uiPlayType = 0])
      : _pPlayList = pPlayList,
        _strContent = strContent;

  FloatingPlayerImpl.fromContent(
      String strContent, this.nContentType, this.bPlayImm,
      [this.uiPlayType = 1])
      : _strContent = strContent;

  FloatingPlayerImpl.fromZoneData(ZoneData pZoneData, this.bPlayImm,
      [this.uiPlayType = 2]) {
    _pProductData = ProductData();
    _pProductData!.addZoneData(pZoneData);
  }

  FloatingPlayerImpl.fromProduct(ProductData pProductData, this.bPlayImm,
      [this.uiPlayType = 3])
      : _pProductData = pProductData;

  bool get bIsLoading => _bIsLoading;
  void setIsLoading(bool value) {
    _bIsLoading = value;
  }

  bool get bTimeForStop => _bTimeForStop;
  List<PlayerZoneImpl> get players => _players;
  Rect get playerRect => _playerRect ?? Rect.zero;
  bool get isVisible => _bIsVisible;
  bool get isPlaying => _bIsPlaying;
  int get output => _nOutput;
  int get zone => _nZone;
  int getZone() => _nZone;

  List<PlayerZoneImpl> get playingZones =>
      _players.where((player) => player.getZone() >= 0).toList();

  List<PlayerZoneImpl> get visibleZones =>
      _bIsVisible ? playingZones : const <PlayerZoneImpl>[];

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void setZone(int zone) {
    _nZone = zone;
  }

  void setOutput(int output) {
    _nOutput = output;
  }

  void setDataChanged() {
    _bDataChanged = true;
  }

  void wantStop() {
    _stopRequested = true;
  }

  void setPlayType(int playType) {
    uiPlayType = playType;
  }

  void setProductData(ProductData? productData) {
    _pProductData = productData;
    _nCurrProduct = 0;
  }

  void setMessageMode({
    required int output,
    required ProductData productData,
    required Rect rect,
    LayoutData? layout,
  }) {
    uiPlayType = 4;
    _nOutput = output;
    _nZone = AHPlayList.getMessageId(output);
    _bIsAHPlaying = true;
    _playerRect = rect;
    setProductData(productData);
  }

  void setCurrentProductMode(ProductData productData) {
    uiPlayType = 5;
    setProductData(productData);
  }

  void setZoneData(ZoneData? zoneData) {
    if (zoneData == null) {
      setProductData(null);
      return;
    }
    zoneData.nZoneID = 0;
    final product = ProductData()..addZoneData(zoneData);
    setProductData(product);
  }

  void setContentType(int contentType) {
    nContentType = contentType;
    final content = _strContent;
    if (content != null && content.isNotEmpty) {
      setContent(content, contentType: contentType);
    }
  }

  void setDuration(double duration) {
    _dbDuration = duration;
  }

  void setWriteLog(bool writeLog) {
    _bWriteLog = writeLog;
    for (final player in _players) {
      player.setWriteLog(writeLog);
    }
  }

  void setAHPlaying(bool playing) {
    _bIsAHPlaying = playing;
    for (final player in _players) {
      player.setAHPlaying(playing);
    }
  }

  void setContent(
    String content, {
    int contentType = -1,
    double duration = 86400,
    String module = '',
  }) {
    _strContent = content;
    nContentType = contentType;
    final resolvedType = contentType < 0
        ? App().contentTypeManager.getContentTypeByFileName(content)
        : contentType;
    final zone = ZoneData()
      ..nZoneID = 0
      ..strZoneFile = content
      ..nZoneDuration = duration
      ..nZoneType = resolvedType
      ..strZoneOfflineFile =
          App().contentTypeManager.findByType(resolvedType)?.strContentType ??
              ''
      ..dVolume = 100;
    setProductData(ProductData()..addZoneData(zone));
  }

  bool _playImm() {
    if (uiPlayType == 0 || uiPlayType == 1) {
      String? strPlayFile =
          DCMFileImpl.getDCMPath(_strContent!, '', _strCompany);
      _playFileData = DCMFileImpl.openCatalogue(szEdit: strPlayFile);
      if (_pPlayList != null) {
        bool bCanPlay = _playFileData!.canPlay();
        if (!bCanPlay) {
          if (_pPlayList!.count > 1) {
            while (true) {
              var result = _pPlayList!.playNextFile();
              if (result.status) {
                strPlayFile =
                    DCMFileImpl.getDCMPath(result.strDCMFile!, '', _strCompany);
                if (strPlayFile != null) {
                  _playFileData =
                      DCMFileImpl.openCatalogue(szEdit: strPlayFile);
                  if (_playFileData!.canPlay()) {
                    bCanPlay = true;
                    break;
                  }
                }
              } else {
                //DestroyWindow();
                return false;
              }
            }
          } else {
            //DestroyWindow();
            return false;
          }
        }
        if (!bCanPlay) {
          //DestroyWindow();
          return false;
        }
        _pPlayList!.setPlayTimes();
      } else {
        if (!_playFileData!.canPlay()) {
          //DestroyWindow();
          return false;
        }
      }
      _pProductData = _playFileData!.getProductDataByIndex(0);
    }

    reCalcPlayerRect();
    int nTotalZone = getZoneNumber();
    for (int nZone = 0; nZone < nTotalZone; nZone++) {
      createZoneImpl(nZone);
    }

    //playSkin.makeMessageHole(_nOutput, m_hWnd);
    return true;
  }

  void _startCheckTimer() {
    //_timer
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(milliseconds: 10000), (timer) {
      playImm();
    });
  }

  void _stopCheckTimer() {
    // Cancel the timer
    _timer?.cancel();
  }

  Future<void> start() async {
    if (!playImm()) {
      _startCheckTimer();
    }
  }

  bool playImm() {
    bool bResult = false;
    try {
      bResult = _playImm();
    } catch (error, stackTrace) {
      logE('FloatingPlayerImpl - playImm failed.', error, stackTrace);
    }

    if (bResult) {
      _notifyChanged();
      _stopCheckTimer();
      _startTimer();
    }

    return bResult;
  }

  Future<void> _floatPlayerStatusCheck() async {
    if (_pollInProgress) {
      logW(
          'FloatingPlayerImpl - _floatPlayerStatusCheck - floating zone play status check InProgress');
      return;
    }
    _pollInProgress = true;
    try {
      await _onTimer();
    } finally {
      if (_needNotifyListeners) {
        _needNotifyListeners = false;
        _notifyChanged();
      }
      _pollInProgress = false;
    }
  }

  Future<void> _onTimer() async {
    if (_stopRequested) {
      _playingTimer?.cancel();

      stopPlay();
      _bIsPlaying = false;
      _bNeedPlayNextProduct = false;

      return;
    }
    if (_bNeedPlayNextProduct) {
      _bNeedPlayNextProduct = false;
      playNextProduct();

      return;
    }

    if (_pPlayList != null) {
      DateTime dtCurr = DateTime.now();
      if (_bIsPlaying && _pPlayList!.isTimeForStop(dtCurr)) {
        stopNotQuit();
        _bIsPlaying = false;

        return;
      }

      if (_pPlayList!.isTimeForLoad()) {
        stopNotQuit();
        var result = _pPlayList!.playFileList();
        if (result.status) {
          int nTotalZone1 = _playFileData!.getZoneNumber();
          String? strPlayFile =
              DCMFileImpl.getDCMPath(result.strDCMFile!, '', _strCompany);
          _playFileData = DCMFileImpl.openCatalogue(szEdit: strPlayFile);

          reCalcPlayerRect();
          int nTotalZone = _playFileData!.getZoneNumber();
          if (nTotalZone != nTotalZone1) {
            stopPlay();
            _pProductData = _playFileData!.getProductDataByIndex(0);
            _bIsPlayNextFile = true;
          } else {
            _bIsPlayNextFile = !_bIsPlaying;
          }
          matchZoneImpl(nTotalZone);
          _pPlayList!.setPlayTimes();
        }
      }

      if ((_bIsPlayNextFile && _pPlayList!.isPlayEpisode) ||
          (_bIsPlayNextFile && _pPlayList!.isTimeForPlay(dtCurr))) {
        //&&
        _bIsPlayNextFile = false;
        playProduct(0, true);
        _bIsPlaying = true;

        return;
      }

      if (!_bIsPlaying) {
        if (_pPlayList!.isTimeForPlay(dtCurr)) {
          playAll();
        }

        return;
      }
    } else {
      if (!_bIsPlaying) {
        playAll();

        return;
      }
    }

    if (uiPlayType == 5 || uiPlayType == 6) {
      if (_bDataChanged) {
        _bDataChanged = false;
        playAll();

        return;
      }
    }

    _matchZoneImpl();

    DateTime dwSecondTime = DateTime.now();
    double rtPos = 0;
    for (int i = 0; i < _players.length; i++) {
      PlayerZoneImpl? pImpl0 = getZoneImpl(i);
      if (pImpl0 != null) {
        pImpl0.setWindowRect(_mapZoneRect![pImpl0.getZone()]!);
        _rtCurrPos1 = dwSecondTime
            .difference(pImpl0.getStartPlayTime())
            .inMilliseconds
            .toDouble();
        var result = pImpl0.getCurrentPosition();
        if (!result.status) {
          rtPos = _rtCurrPos1 / Duration.millisecondsPerSecond;
        } else {
          rtPos = result.rtPosition!;
          if (_rtCurrPos1 > 0 && rtPos < cEPSILON) {
            rtPos = _rtCurrPos1 / Duration.millisecondsPerSecond;
          }
        }

        PlayFinish nFinish = PlayFinish.eNOTFINISH;
        var playResult = pImpl0.isPlayerFinish(rtPos, nFinish);
        if (playResult.status) {
          pImpl0.setPlayingDuration(rtPos);
          pImpl0.setStartPlayTime(DateTime.now());
          logI(
              '''CPlayerScreen2Dlg::OnTimer; GetPlayingLine:'${pImpl0.getPlayingLine()}'; Zone:'$i'; GetPlayingDuration:'${pImpl0.getPlayingDuration()}'; _rtCurrPos1:'$_rtCurrPos1'; rtPos:'$rtPos'.''');

          _rtCurrPos1 = 0;
          if (pImpl0.getPlayingLine() - pImpl0.getPlayingDuration() <
              cPLAYINGINTERVAL) {
            if (uiPlayType == 6 || isPlayOneTimeAHMessage()) {
              await stopAll();
              //::PostMessage(_hWndParent, DCMM_BACKTO_SCHEDULE, 0, IsPlayOneTimeAHMessage() ? 1 : 0);
              onBackToSchedule?.call(0, isPlayOneTimeAHMessage() ? 1 : 0);
            } else if (uiPlayType != 5) {
              pImpl0.setZoneFinish(true);
              if (_bPlayConti) {
                playNextProduct();
                _needNotifyListeners = true;
              } else {
                await stopAll();
              }
            }
            break;
          } else {
            pImpl0.rePlayZone();
            _needNotifyListeners = true;
          }
        } else {
          if (nFinish == PlayFinish.eCONTENTFINISH) {
            pImpl0.playNextContentListItem(nFinish);
            _needNotifyListeners = true;
          }
        }

        /*if (!pImpl0.isValid()) {
          pImpl0.renderZone();
        }*/
      }
    }
  }

  BackToScheduleCallback? onBackToSchedule;

  Future<void> playAll() async {
    if (_bIsPlaying) {
      releasePlayers();
    }

    _bPlayConti = true;
    _bIsPlaying = true;
    await playProduct(0, true);
  }

  void _startTimer() {
    _playingTimer?.cancel();
    _playingTimer = Timer.periodic(
        const Duration(milliseconds: cPLAYINGDURATION * 2),
        (_) => unawaited(_floatPlayerStatusCheck()));
  }

  Future<void> pausePlay() async {
    _playingTimer?.cancel();
    for (final player in _players) {
      player.videoStatusControl(1);
    }
  }

  Future<void> resumePlay() async {
    for (final player in _players) {
      player.videoStatusControl(0);
    }
    if (_bIsPlaying) {
      _startTimer();
    } else {
      await playAll();
    }
  }

  Future<void> stopAll() async {
    _playingTimer?.cancel();
    _playingTimer = null;
    release();
    _bIsPlaying = false;
    _bIsVisible = false;
    _stopRequested = false;
    _notifyChanged();
  }

  Future<void> stopNotQuit() async {
    _playingTimer?.cancel();
    _playingTimer = null;
    stopPlay();
    _bIsPlaying = false;
    _notifyChanged();
  }

  Future<void> resize(Rect rect) async {
    if (rect.isEmpty) {
      return;
    }
    setWindowRect(rect);
    if (_bIsPlaying) {
      for (final player in playingZones) {
        player.setWindowRect(scaleToVW(player.getZone()));
      }
    }
    _notifyChanged();
  }

  void _notifyChanged() {
    _onStateChanged?.call();
  }

  int getProductNumber() {
    int nProduct = 1;
    if (uiPlayType == 0 || uiPlayType == 1) {
      nProduct = _playFileData!.getZoneNumber();
    }

    return nProduct;
  }

  int getZoneNumber() {
    int nTotalZone = 1;
    if (uiPlayType == 0 || uiPlayType == 1) {
      nTotalZone = _playFileData!.getZoneNumber();
    } else if (uiPlayType == 2 || uiPlayType == 3 || uiPlayType == 4) {
      if (_pProductData != null) {
        nTotalZone = _pProductData!.lstZone.length;
      }
    }

    return nTotalZone;
  }

  void getProductData(int nProduct) {
    if (uiPlayType == 0 || uiPlayType == 1) {
      _pProductData = _playFileData!.getProductDataByIndex(nProduct);
    }
  }

  int getCurrPlaying() => _currPlaying;

  void setCurrPlaying(int value) {
    if (value < 0) {
      _currPlaying = 0;
      return;
    }
    _currPlaying = value;
  }

  void setWindowRect(Rect rect) {
    _playerRect = rect;
  }

  void resizeWindow() {
    if (_bIsPlaying) {
      reCalcPlayerRect();
      for (var pZoneImpl in _players) {
        pZoneImpl.setWindowRect(_mapZoneRect![pZoneImpl.getZone()]!);
      }
    }
  }

  void setCompany(String? strCompany) {
    _strCompany = strCompany ?? '';
    for (final player in _players) {
      player.setCompany(_strCompany);
    }
  }

  void createZoneImpl(int nZone) {
    if (_players.length > nZone) {
      for (var pZoneImpl in _players) {
        if (pZoneImpl.getZone() == -1) {
          pZoneImpl.setZone(nZone);
          pZoneImpl.setAHPlaying(_bIsAHPlaying);
          pZoneImpl.setWriteLog(_bWriteLog);
          pZoneImpl.setCompany(_strCompany);
          pZoneImpl.setProductData(_pProductData);
          pZoneImpl.setWindowRect(_mapZoneRect![nZone]!);
          pZoneImpl.initZone();
          break;
        }
      }
    } else {
      PlayerZoneImpl pZoneImpl = PlayerZoneImpl();
      pZoneImpl.setZone(nZone);
      pZoneImpl.setAHPlaying(_bIsAHPlaying);
      pZoneImpl.setWriteLog(_bWriteLog);
      pZoneImpl.setCompany(_strCompany);
      pZoneImpl.setProductData(_pProductData);
      pZoneImpl.setWindowRect(_mapZoneRect![nZone]!);
      pZoneImpl.initZone();

      _players.add(pZoneImpl);
    }
  }

  void deleteZoneImpl(int nZone) {
    while (_players.length > nZone) {
      final player = _players.removeAt(nZone);
      unawaited(player.release());
    }
  }

  void stopPlay() {
    _playingTimer?.cancel();
    _playingTimer = null;
    for (var pImpl in _players) {
      pImpl.stopPlay();
    }
  }

  Future<void> release() async {
    _bDisposed = true;
    await releasePlayers();
  }

  Future<void> releasePlayers() async {
    _playingTimer?.cancel();
    _playingTimer = null;
    _bIsPlaying = false;
    _bIsVisible = false;
    final players = List<PlayerZoneImpl>.of(_players);
    _players.clear();
    for (final player in players) {
      await player.release();
    }
  }

  Future<void> play([int nStart = 0]) async {
    await playProduct(nStart, true);
  }

  void changeContent() {
    if (isNotBlank(_strContent)) {
      nContentType = -1;
      final resolvedType = nContentType < 0
          ? App().contentTypeManager.getContentTypeByFileName(_strContent!)
          : nContentType;
      final zone = ZoneData()
        ..nZoneID = 0
        ..strZoneFile = _strContent!
        ..nZoneDuration = _dbDuration
        ..nZoneType = resolvedType
        ..strZoneOfflineFile =
            App().contentTypeManager.findByType(resolvedType)?.strContentType ??
                ''
        ..dVolume = 100;

      setProductData(ProductData()..addZoneData(zone));
    }
  }

  bool isPlayOneTimeAHMessage() {
    if (uiPlayType == 4) {
      return (ScheduleList().messageList.getEndType(_nOutput) ==
          AHPlayList.kAHENDPLAYONETIME);
    }

    return false;
  }

  Future<void> playProduct(int nIndex, [bool bStart = false]) async {
    _bIsLoading = true;
    try {
      _playProduct(nIndex, bStart);
    } finally {
      _bIsLoading = false;
    }
  }

  void _playProduct(int nIndex, bool bStart) {
    _playingTimer?.cancel();

    int nTotalZone = 0;
    bool bMatched = false;
    if (uiPlayType == 4) {
      var result = ScheduleList().messageList.getZoneDataList(_nOutput);
      if (result.nChanged != -1) {
        bMatched = true;
        nTotalZone =
            result.lstZoneData!.length + result.lstZoneDataChanged!.length;
        if (result.nChanged == 1 || (nTotalZone != _players.length)) {
          matchByZoneDataList(result.lstZoneData!, result.lstZoneDataChanged!);
        }
        nTotalZone = getZoneNumber();
      }

      int bAlpha = ScheduleList().messageList.getAlpha(_nOutput);
      if ((_bAlpha < 0 && bAlpha < cBYTEMAX) ||
          (_bAlpha > -1 && _bAlpha != bAlpha)) {
        _bAlpha = bAlpha;
        //CTransparentHelper::MakeWindowTransparent(this.getSafeHwnd(), _bAlpha);
      }
    } else if (uiPlayType == 5) {
      ZoneData? pZoneData =
          ScheduleList().getZoneData(ScheduleList().getPlayProduct(), _nZone);
      if (pZoneData != null) {
        setZoneData(pZoneData);
        int bAlpha = pZoneData.bAlpha;
        if ((_bAlpha < 0 && bAlpha > 0) ||
            (_bAlpha > -1 && _bAlpha != bAlpha)) {
          _bAlpha = pZoneData.bAlpha;
          //CTransparentHelper::MakeWindowTransparent(this.getSafeHwnd(), ((100 - _bAlpha) * 255)/ 100);
        }
      }
    } else if (uiPlayType == 6) {
      changeContent();
    }

    if (!bMatched) {
      _nCurrProduct = nIndex;
      getProductData(nIndex);

      nTotalZone = getZoneNumber();
      if (nTotalZone != _players.length) {
        matchZoneImpl(nTotalZone);
      }
    }

    if (_pProductData == null || nTotalZone <= 0) {
      _bNeedPlayNextProduct = true;
      return;
    }
    if (!_pProductData!.isValidForPlay()) {
      _bNeedPlayNextProduct = true;
      return;
    }

    _rtDuration = Utils.getMaxDuration(_pProductData);
    DateTime dwFirstTime0 = DateTime.now();
    for (var pData in _pProductData!.lstZone) {
      int nZone = pData.nZoneID;
      PlayerZoneImpl? pZoneImpl = getZoneImpl(nZone);
      if (pZoneImpl == null) {
        continue;
      }

      pZoneImpl.setZone(nZone);
      pZoneImpl.setProductData(_pProductData);
      /*CZoneData *pData = _pProductData.getZoneData(nZone);
      if (pData == null)
        continue;*/

      pZoneImpl.setStartPlayTime(dwFirstTime0);
      pZoneImpl.setWindowRect(_mapZoneRect![nZone]!);
      if (bStart) {
        //pZoneImpl.renderZone();
      } else {
        if (!pData.bChkZone) {
          //pZoneImpl.renderZone();
        } else {
          if (pZoneImpl.isZoneFinish()) {
            pZoneImpl.setZoneFinish(false);
            pZoneImpl.rePlayZone();
          }
        }
      }

      if (uiPlayType == 6 || isPlayOneTimeAHMessage()) {
        _rtDuration = pZoneImpl.getActualDuration();
        if (_rtDuration >= 86400) {
          _rtDuration = cDEFAULTDURATION;
        }
        pZoneImpl.setPlayerDuration(_rtDuration);
      }
      pZoneImpl.setPlayingLine(_rtDuration, !pData.bChkZone);

      logI(
          '''CPlayerScreen2Dlg::PlayProduct; ZoneFile: '${pData.strZoneFile}'; Zone size: '${_pProductData!.lstZone.length}'; _players size: '${_players.length}', _rtDuration:'$_rtDuration'.''');
    }
    _needNotifyListeners = true;

    _startTimer();
  }

  void playNextProduct() {
    _bIsPlayNextFile = false;
    if (getProductNumber() <= _nCurrProduct + 1) {
      _nCurrProduct = 0;
      if (_pPlayList != null) {
        int nTotalZone1 = _playFileData!.getZoneNumber();
        if (_pPlayList!.count > 1) {
          if (_pPlayList!.getPlayTimes()) {
            var result = _pPlayList!.playNextFile();
            if (result.status) {
              String? strPlayFile =
                  DCMFileImpl.getDCMPath(result.strDCMFile!, '', _strCompany);
              _playFileData = DCMFileImpl.openCatalogue(szEdit: strPlayFile);

              reCalcPlayerRect();
              int nTotalZone = _playFileData!.getZoneNumber();
              if (nTotalZone != nTotalZone1) {
                _playingTimer?.cancel();
                stopPlay();
                _pProductData = _playFileData!.getProductDataByIndex(0);
                //_bIsPlayNextFile = true;
                _startTimer();
              }
              matchZoneImpl(nTotalZone);
              _bIsPlayNextFile = true;
            }
          }
          _pPlayList!.setPlayTimes();
        } else {
          String? strPlayFile = DCMFileImpl.getDCMPath(
              _pPlayList!.getPlayFile(), '', _strCompany);
          _playFileData = DCMFileImpl.openCatalogue(szEdit: strPlayFile);

          reCalcPlayerRect();
          int nTotalZone = _playFileData!.getZoneNumber();
          if (nTotalZone != nTotalZone1) {
            _playingTimer?.cancel();
            stopPlay();
            _pProductData = _playFileData!.getProductDataByIndex(0);
            matchZoneImpl(nTotalZone);
            _bIsPlayNextFile = true;
            _startTimer();
          }
        }
      }
    } else {
      _nCurrProduct++;
    }

    if (!_bIsPlayNextFile) {
      playProduct(_nCurrProduct);
    }
  }

  void clear() {
    _playingTimer?.cancel();
    _playingTimer = null;
    _currPlaying = 0;
    _bTimeForStop = false;
    _playerRect = null;
    _bIsPlaying = false;
    _bIsVisible = false;
  }

  void reCalcPlayerRect() {
    if (_mapZoneRect == null) {
      _mapZoneRect = {};
    } else {
      _mapZoneRect!.clear();
    }
    if (_pProductData == null) {
      _mapZoneRect![0] = scaleToVW(0);
    } else {
      int nTotalZone = getZoneNumber();
      LayoutData? pLayoutData;
      if (_playFileData == null && uiPlayType == 4) {
        pLayoutData = ScheduleList().messageList.getLayoutData(_nOutput);
      }
      for (int nZone = 0; nZone < nTotalZone; nZone++) {
        _mapZoneRect![nZone] = scaleToVW(nZone, nTotalZone, pLayoutData);
      }
    }
  }

  Rect scaleToVW(int nZone, [int nTotalZone = 1, LayoutData? pLayoutData]) {
    final playerRect = _playerRect;
    if (playerRect == null || playerRect.isEmpty) {
      return Rect.zero;
    }

    Rect rcVW = Rect.fromLTWH(0, 0, playerRect.width, playerRect.height);
    if (_playFileData != null) {
      rcVW = _playFileData!.getZoneRect(nZone, rcVW)!;
    } else if (pLayoutData != null) {
      logI(
          '''CPlayerScreen2Dlg::ScaleToVW LayoutData:'${pLayoutData.iNoOfParition}'; Output: '$_nOutput'.''');
      rcVW = DCMFileImpl.getZoneRect(pLayoutData, nZone, rcVW)!;
    } else {
      rcVW = _defaultZoneRect(nZone, nTotalZone);
    }

    return rcVW;
  }

  Rect _defaultZoneRect(int nZone, int totalZones) {
    final rect = _playerRect;
    if (rect == null || rect.isEmpty || totalZones <= 0) {
      return Rect.zero;
    }
    final top = rect.height - (rect.height * (nZone + 1) / totalZones);
    final bottom = top + rect.height / totalZones;
    return Rect.fromLTRB(0, top, rect.width, bottom);
  }

  PlayerZoneImpl? getZoneImpl(int nZone) {
    for (var zoneImpl in _players) {
      if (zoneImpl.getZone() == nZone) {
        return zoneImpl;
      }
    }
    return null;
  }

  int getZoneImplIndex(int nZone) {
    for (int i = 0; i < _players.length; i++) {
      if (_players[i].getZone() == nZone) {
        return i;
      }
    }

    return -1;
  }

  void _matchZoneImpl() {
    //Modify by john 1/12/2011
    if (uiPlayType == 4) {
      var result = ScheduleList().messageList.getZoneDataList(_nOutput);
      if (result.nChanged != -1) {
        int nTotalZone =
            result.lstZoneData!.length + result.lstZoneDataChanged!.length;
        if (result.nChanged == 1 || (nTotalZone != _players.length)) {
          matchByZoneDataList(result.lstZoneData!, result.lstZoneDataChanged!);
        }

        int bAlpha = ScheduleList().messageList.getAlpha(_nOutput);
        if ((_bAlpha < 0 && bAlpha < cBYTEMAX) ||
            (_bAlpha > -1 && _bAlpha != bAlpha)) {
          _bAlpha = bAlpha;
          //CTransparentHelper::MakeWindowTransparent(this->GetSafeHwnd(), m_bAlpha);
        }
      }
    }
  }

  void matchZoneImpl(int nTotalZone) {
    if (nTotalZone <= 0) {
      return;
    }

    reCalcPlayerRect();
    deleteZoneImpl(nTotalZone);
    for (var pZoneImpl in _players) {
      pZoneImpl.setZone(-1);
    }

    for (int i = 0; i < nTotalZone; i++) {
      createZoneImpl(i);
    }
  }

  void matchByZoneDataList(
      List<ZoneData> lstZoneData, List<ZoneData> lstZoneDataChanged) {
    int nTotalZone = lstZoneData.length + lstZoneDataChanged.length;

    List<PlayerZoneImpl> arrZoneImpl = [];
    for (var it in lstZoneData) {
      int nIndex = getZoneImplIndex(it.nZoneID);
      if (nIndex != -1) {
        arrZoneImpl.add(_players.elementAt(nIndex));
        _players.removeAt(nIndex);
      }
    }

    if (_players.length > lstZoneDataChanged.length) {
      int nZone = lstZoneDataChanged.length;
      for (int i = nZone; i < _players.length; i++) {
        _players.elementAt(i).stopPlay();
      }
      while (_players.length > lstZoneDataChanged.length) {
        _players.removeAt(_players.length - 1);
      }
    }

    int i = 0;
    for (i = 0; i < _players.length; i++) {
      _players.elementAt(i).stopPlay();
      _players.elementAt(i).setZone(-1);
    }
    for (var it in lstZoneData) {
      var pos = _pProductData!.lstZone.indexOf(it);
      if (pos != -1) {
        _pProductData!.lstZone.removeAt(pos);
      }
    }

    _pProductData!.lstZone.clear();
    for (var it in lstZoneData) {
      _pProductData!.lstZone.add(it);
    }

    for (var it in lstZoneDataChanged) {
      _pProductData!.lstZone.add(it);
    }
    reCalcPlayerRect();
    _rtDuration = Utils.getMaxDuration(_pProductData);

    for (var it in lstZoneDataChanged) {
      PlayerZoneImpl? pZoneImpl = getZoneImpl(-1);
      int nZone = it.nZoneID;
      if (pZoneImpl == null) {
        pZoneImpl = PlayerZoneImpl();
        pZoneImpl.setZone(nZone);
        pZoneImpl.setProductData(_pProductData);
        pZoneImpl.setWindowRect(_mapZoneRect![nZone]!);
        pZoneImpl.setAHPlaying(_bIsAHPlaying);
        pZoneImpl.setWriteLog(_bWriteLog);
        pZoneImpl.setCompany(_strCompany);
        pZoneImpl.setZoneData(it);

        _players.add(pZoneImpl);
      } else {
        pZoneImpl.setZone(nZone);
        pZoneImpl.setProductData(_pProductData);
        pZoneImpl.setWindowRect(_mapZoneRect![nZone]!);
        pZoneImpl.setAHPlaying(_bIsAHPlaying);
        pZoneImpl.setWriteLog(_bWriteLog);
        pZoneImpl.setCompany(_strCompany);
        pZoneImpl.setZoneData(it);
      }
      pZoneImpl.setStartPlayTime(DateTime.now());
      pZoneImpl.initZone();

      //pZoneImpl.renderZone();
    }

    for (i = 0; i < arrZoneImpl.length; i++) {
      int nZone = arrZoneImpl[i].getZone();
      arrZoneImpl[i].setWindowRect(_mapZoneRect![nZone]!);
      _players.add(arrZoneImpl[i]);
    }
    for (i = 0; i < _players.length; i++) {
      /*WriteMessage(MSG_INFO, _T("CPlayerScreen2Dlg::MatchZoneImpl; Zone ID: '%d'; Zone Contnet: '%s'; Rect left: '%d'; top: '%d'; width: '%d', height: '%d'"), 
        pImpl.getZone(), pImpl.getZoneData().strZoneFile, pImpl.getPlayerRect().left, pImpl.getPlayerRect().top, pImpl.getPlayerRect().Width(), pImpl.getPlayerRect().Height());*/
      _players[i].setPlayingLine(_rtDuration, true);
    }
  }
}
