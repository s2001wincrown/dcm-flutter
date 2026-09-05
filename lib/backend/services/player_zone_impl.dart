import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/content_list_player_impl.dart';
import 'package:dcm/backend/services/app_skin_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/widgets/content_list_player.dart';
import 'package:dcm/widgets/scrolltext.dart';
import 'package:dcm/widgets/slideshow.dart';
import 'package:dcm/widgets/webview_desktop_player.dart';
import 'package:dcm/widgets/webview_player.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PreloadedContent {
  final int type;
  final VideoController? controller;
  final Player? player;
  final String filePath;
  final String? text;
  final List<String>? images;
  bool _isReadyToPlay = true;

  PreloadedContent({
    required this.type,
    this.controller,
    this.player,
    required this.filePath,
    this.text,
    this.images,
  });

  Future<void> release() async {
    if (player != null) {
      await player!.dispose();
    }
    _isReadyToPlay = false;
  }

  Future<void> stop() async {
    if (player != null) {
      player!.stop();
      player!.open(Media(LibraryHelper.normalizeMediaSource(filePath)),
          play: false);
      _isReadyToPlay = true;
    }
  }

  Future<void> ready() async {
    if (player != null) {
      if (!_isReadyToPlay) {
        await player!.open(Media(LibraryHelper.normalizeMediaSource(filePath)),
            play: false);
        _isReadyToPlay = true;
      }
    }
  }

  double getActualDuration() => player!.state.duration.inMilliseconds / 1000.0;
}

class PlayerZoneImpl {
  //int productId;
  int _zoneId = -1;
  int _contentType = -1;
  int _nStart = 0;
  ProductData? _pProductData;
  ZoneData? _pZoneData;
  bool _bZoneFinish = false;
  bool _bFirstFinished = false;
  bool _bContinuePlaying = false;
  bool _bContentFinished = false;
  bool _bWriteLog = true;

  late DateTime _dwStartTime;
  late DateTime _dtStartPlay;

  bool _bIsRendering = false;
  bool _bIsAHPlaying = false;
  bool _bIsPlaying = false;
  bool _bIsValid = true;
  int _nPType = 0;
  String? _strCompany;
  String _strContentName = "";
  String _strZoneFile = '';

  bool _playCached = false;
  bool _bLoadState = false;
  bool _bShowMessage = false;
  bool _bShowMessageNext = false;
  bool _bNeedReset = false;
  bool _bIsAHPlaylist = false;

  double _rtDuration = 0.00;
  double _rtLine = 0.00;
  double _rtAct = 0.00;
  double _rtPlaying = 0.00;
  double _rtCurrDuration = 0.00;

  Rect? _rect;
  Rect? _rectPlayerOrg;

  PreloadedContent? _preloadedContent;

  ContentListPlayerImpl? _contentListPlayer;
  VideoController? _controller;
  Player? _player;
  int _nVideoStatus = -1;
  bool _bWantStop = false;

  void stopPlay() {
    try {
      if (_player != null) {
        _player!.stop();
      }
      if (_contentListPlayer != null) {
        _contentListPlayer!.stop();
      }
      if (_preloadedContent != null) {
        _preloadedContent!.stop();
      }
    } catch (e, stackTrace) {
      logE('PlayerZoneImpl - stopPlay error: $e', stackTrace);
    }
  }

  void release() {
    try {
      if (_player != null) {
        _player!.dispose();
        _player = null;
      }
      if (_contentListPlayer != null) {
        _contentListPlayer!.release();
        _contentListPlayer = null;
      }
      if (_preloadedContent != null) {
        _preloadedContent!.release();
        _preloadedContent = null;
      }
    } catch (e, stackTrace) {
      logE('PlayerZoneImpl - release error: $e', stackTrace);
    }
  }

  void resetAllPlayer(bool bTypeChanged) {
    if (bTypeChanged) {
      stopPlay();
    } else {
      //stopTimer();
      //stopTimer3();
    }

    _rtDuration = 0;
    _rtAct = 0;
    _rtPlaying = 0;
  }

  //mapPreloadedContents: cached contents
  void initZone([Map<String, PreloadedContent>? mapPreloadedContents]) async {
    if (mapPreloadedContents != null) {
      _playCached = true;
      stopPlay();
    } else {
      _playCached = false;
      if (_bNeedReset) {
        release();
      } else {
        stopPlay();
      }
    }

    _rtCurrDuration = 0.00;
    _bIsAHPlaylist = ScheduleList().isPlayingEpisode();
    _strCompany = ScheduleList().getCurrCompany();

    _bZoneFinish = false;
    _bFirstFinished = false;
    _bContinuePlaying = false;
    _bContentFinished = false;
    //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 1");
    _dtStartPlay = DateTime.now();
    ZoneData? pZoneData = getZoneData();
    if (pZoneData == null) {
      logE('PlayerZoneImpl - no zone data.');
      _bIsValid = false;
      return;
    }

    if (_zoneId < 0) _zoneId = pZoneData.nZoneID;
    if (_rect == null && _zoneId > -1) _rect = playSkin.getZoneRect(_zoneId);
    _rectPlayerOrg = _rect;
    _strContentName = pZoneData.strZoneFile;
    _contentType = pZoneData.nZoneType;

    _bIsRendering = true;
    _strZoneFile = Utils.getFilePath(
        pZoneData.strZoneFile, pZoneData.nZoneType, _nPType, _strCompany);
    logI(
        'Try to init Zone - Zone: $_zoneId, _nPType: $_nPType, _strZoneFile: $_strZoneFile, _bNeedReset: $_bNeedReset, mapPreloadedContents: ${mapPreloadedContents != null ? mapPreloadedContents.length : 0}.');
    try {
      if (await _validZone(_strZoneFile, _contentType)) {
        //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 4");
        _rtDuration = 0;
        switch (_contentType) {
          case cIMAGETYPE:
            break;
          case cVIDEOTYPE:
            if (mapPreloadedContents != null &&
                mapPreloadedContents.containsKey(_strZoneFile)) {
              _preloadedContent = mapPreloadedContents[_strZoneFile];
              _rtAct = _preloadedContent!.getActualDuration();
            } else {
              if (_player != null) {
                _player!.open(
                    Media(LibraryHelper.normalizeMediaSource(_strZoneFile)),
                    play: false);
                _rtAct = _player!.state.duration.inMilliseconds / 1000.0;
              } else {
                _initVideoPlayer(pZoneData, null);
                if (_player != null) {
                  _rtAct = _player!.state.duration.inMilliseconds / 1000.0;
                } else {
                  logE(
                      'PlayerZoneImpl - initVideoPlayer error: _player is null');
                }
              }
            }
            break;

          case cPOWERPOINTTYPE:
            //PlayPPT(strZone1File, rectWin);
            break;

          case cQUEUETYPE:
          //strZone1File = GetQueueLink(strZone1File);
          case cWEBPAGETYPE:
            break;
          case cFLASHTYPE:
            break;
          case cTVCAPTURETYPE:
          case cWEBCAMTYPE:
            break;
          case cTEXTTYPE:
            break;
          case cSTREAMINGTYPE:
            break;
          case cONLINETYPE:
            break;
          case cCLOCKTYPE:
            break;
          case cWEATHERTYPE:
            break;
          case cDDETYPE:
          case cDIRECTPLAYTYPE:
          case cSITEPLAYLIST:
            _initContentList(_contentType, _strZoneFile, _rect!);
            break;
          case cLINKAGETYPE:
            break;
          case cEVENTTYPE:
            break;
          default:
            break;
        }
      } else {
        _bIsValid = false;
      }
    } catch (e, stackTrace) {
      logE(
          'Init Zone failed - Zone: $_zoneId; _nPType: $_nPType; _strZoneFile: $_strZoneFile error: $e',
          stackTrace);
    }

    if (_contentType != cDDETYPE &&
        _contentType != cDIRECTPLAYTYPE &&
        _contentType != cSITEPLAYLIST) {
      _rtDuration = pZoneData.nZoneDuration;
    }

    if (_rtDuration < cEPSILON) {
      _rtDuration = cDEFAULTDURATION;
    }
    if (_rtAct < cEPSILON) {
      _rtAct = _rtDuration;
    }
    _bIsRendering = false;
    _bIsPlaying = false;
    _bNeedReset = true;
    logI(
        'Init Zone finished - Zone: $_zoneId; _nPType: $_nPType; _rtDuration: $_rtDuration; _rtAct: $_rtAct; _strZoneFile: $_strZoneFile; _playCached: $_playCached.');
  }

  void _initVideoPlayer(ZoneData pZoneData, [PreloadedContent? preloaded]) {
    preloaded ??= preloadVideoPlayer(pZoneData,
        filePath: _strZoneFile, size: _rect!.size);
    if (preloaded != null) {
      //preloaded.ready();
      _player = preloaded.player;
      _controller = preloaded.controller;
    }
  }

  void setWindowRect(Rect rcWin) {
    _rect = rcWin;
  }

  Rect getRect() => _rect ?? Rect.zero;

  int getZone() => _zoneId;

  void setZone(int nZone) {
    _zoneId = nZone;
  }

  String getZoneFile() => _strZoneFile;

  void setZoneFile(String zoneFile) {
    _strZoneFile = zoneFile;
  }

  void setCompany(String strCompany) {
    _strCompany = strCompany;
  } // for multi company

  double getPlayingDuration() {
    return _rtPlaying;
  }

  double getPlayerDuration() => _rtDuration;
  double getActualDuration() => _rtAct;

  void setPlayingDuration(double rtPosition) {
    _rtPlaying += rtPosition;
  }

  void setPlayingLine(double rtPosition, [bool bReset = true]) {
    double rtDuration = rtPosition;
    if (rtDuration < cEPSILON) {
      rtDuration = cDEFAULTDURATION;
    }

    if (bReset) {
      _rtLine = rtDuration;
    } else {
      _rtLine += rtDuration;
    }
  }

  double getPlayingLine() => _rtLine;
  bool isShowMessage() => _bShowMessage;
  int getEffect() => 100;

  void setPlayStart(int nStart) {
    _nStart = nStart;
  }

  void setStartTime(DateTime dwStartTime) {
    _dwStartTime = dwStartTime;
  }

  void setStartPlayTime(DateTime dwStartTime) {
    _dwStartTime = dwStartTime;
  }

  DateTime getStartPlayTime() => _dwStartTime;

  void setParentContentType(int ptype) {
    _nPType = ptype;
  }

  int getPType() => _nPType;
  void setWriteLog(bool bWriteLog) {
    _bWriteLog = bWriteLog;
  }

  void setAHPlaying([bool bIsAHPlaying = false]) {
    _bIsAHPlaying = bIsAHPlaying;
  }

  bool isZoneFinish() => _bZoneFinish;

  void setZoneFinish(bool bFinish) {
    _bZoneFinish = bFinish;
  }

  bool isNeedReset() => _bNeedReset;

  void setNeedReset(bool bNeedReset) {
    _bNeedReset = bNeedReset;
  }

  bool isFirstFinished() => _bFirstFinished;
  void setFirstFinished([bool bFirst = true]) {
    _bFirstFinished = bFirst;
  }

  bool isContentFinished() => _bContentFinished;
  void setContentFinished([bool bContentFinished = true]) {
    _bContentFinished = bContentFinished;
  }

  void setContentStarting([bool isLoading = true]) {
    if (_contentListPlayer != null) {
      return _contentListPlayer!.setIsLoading(isLoading);
    }
  }

  void setContentType(int nContentType) {
    _contentType = nContentType;
  }

  bool hasContent(int nContentType) {
    if (_contentListPlayer != null) {
      return _contentListPlayer!.hasContent(nContentType);
    } else {
      return (_contentType == nContentType);
    }
  }

  int getPlayStart() {
    if (_contentListPlayer != null) {
      return _contentListPlayer!.getCurrPlaying();
    }
    return 0;
  }

  bool isRendering() {
    if (!_bIsValid) {
      return true;
    }

    return (_bIsRendering == true);
  }

  bool isPlaying() {
    if (!_bIsValid) {
      return true;
    }

    return (_bIsPlaying == true);
  }

  void calcDuration() {
    if (_rtDuration < cEPSILON) {
      _rtDuration = cDEFAULTDURATION;
    }
    if (_rtAct < cEPSILON) {
      _rtAct = _rtDuration;
    }
  }

  void wantStop(bool bWantStop) {
    _bWantStop = bWantStop;
  }

  bool isWantStop() => _bWantStop;

  void setProductData(ProductData? pProductData) {
    _pProductData = pProductData;
  }

  void setZoneData(ZoneData? pZoneData) {
    _pZoneData = pZoneData;
  }

  ZoneData? getZoneData() {
    ZoneData? pZoneData = _pZoneData;
    if (_zoneId > -1 && _pProductData != null) {
      pZoneData = _pProductData!.getZoneData(_zoneId);
    }

    return pZoneData;
  }

  ContentListPlayerImpl? getContentListPlayer() => _contentListPlayer;

  bool initResetFlag(int nZoneType, String strContent, Rect rect) {
    if (nZoneType < 0) {
      _contentType = -1;
      _strContentName = '';
    }
    /*if (_nZone == 0 && _contentType == THUMBVIEW)
    {
      _bNeedReset = false;
    }
    else
    {
      if (_rectPlayerOrg == rect && _contentType == nZoneType && _strContentName == strContent)
        _bNeedReset = false;
    }*/
    _bNeedReset = true;
    if (_rectPlayerOrg != null &&
        _rectPlayerOrg == rect &&
        _contentType == nZoneType &&
        _strContentName == strContent) {
      _bNeedReset = false;
    }

    return _bNeedReset;
  }

  Future<bool> _validZone(String strPath, int nZoneType) async {
    if (strPath.isEmpty) return false;

    if (nZoneType == cDIRECTPLAYTYPE ||
        nZoneType == cDDETYPE ||
        nZoneType == cSITEPLAYLIST) {
      return true;
    }

    if (nZoneType == cTVCAPTURETYPE ||
        nZoneType == cTEXTTYPE ||
        nZoneType == cWEBCAMTYPE ||
        nZoneType == cSTREAMINGTYPE ||
        nZoneType == cONLINETYPE ||
        nZoneType == cCLOCKTYPE ||
        nZoneType == cWEATHERTYPE ||
        nZoneType == cEXPLORERTYPE ||
        nZoneType == cLINKAGETYPE ||
        nZoneType == cEVENTTYPE ||
        nZoneType == cPLUGINTYPE ||
        nZoneType == cLIGHTBOXTYPE ||
        nZoneType == 27) {
      return true;
    }

    if (nZoneType != cWEBPAGETYPE) {
      // Is this a valid directory and file name?
      if (await File(strPath).exists()) {
        return true;
      }
    } else {
      return true;
    }

    return false;
  }

  int play([int nStart = 0]) {
    _bIsPlaying = true;
    /*if (nStart == 2) {
      if (m_pThumbCtrl != NULL) {
        int nProduct = (int)lParam;
        m_pThumbCtrl->SelectProductButton(nProduct == 0 ? PlayList.GetPlayProduct() : nProduct);
      }

      return 0;
    }

    _bLoadState = (nStart == 1);
    
    logI('CPlayerZoneDlg::OnStartPlay Zone id '%d', m_bZoneReseting: '%d', m_bIsRendering: '%d' Thread ID %d!!!', m_nZone, m_bZoneReseting, m_bIsRendering ? 1 : 0, GetCurrentThreadId());
    if (_bZoneReseting || _bIsRendering) {
      StartTimer2(2, 100);
      return 0;
    }

    try {
      RenderZone();
      if (nStart == 3 && m_pThumbCtrl != NULL && HIBYTE(PlayList.GetCatalogue().GetBtnAlign()) > 0) {
        m_pThumbCtrl->SelectProductButton(PlayList.GetPlayProduct());
      }
    } catch(e) {
      logI('Render zone %d error, Thread ID %d!!!', m_nZone, GetCurrentThreadId());
    }*/

    return 0;
  }

  void rePlay() {
    rePlayZone();
  }

  Widget renderZone([bool cached = false]) {
    Widget? widget;
    if (_bIsValid) {
      try {
        ZoneData? pZoneData = getZoneData();
        switch (pZoneData!.nZoneType) {
          case cIMAGETYPE:
            if (_bNeedReset) {
              widget = Slideshow(
                  key: Key(_strZoneFile),
                  imageFile: _strZoneFile,
                  rect: _rect!,
                  cached: cached);
            }
            /*logD(
                '''renderZone: $_zoneId, image file: "$_strZoneFile", _bNeedReset: $_bNeedReset, widget: "$widget".''');*/
            break;
          case cVIDEOTYPE:
            if (_preloadedContent != null) {
              _preloadedContent!.player!.play();
              widget = ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Video(
                    key: Key(_strZoneFile),
                    controller: _preloadedContent!.controller!,
                    fit: pZoneData.bZoneRatio ? BoxFit.contain : BoxFit.fill,
                    controls: null),
              );
            } else {
              if (_player != null) {
                _player!.play();
              }
              if (_controller != null) {
                widget = ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Video(
                      key: Key(_strZoneFile),
                      controller: _controller!,
                      fit: pZoneData.bZoneRatio ? BoxFit.contain : BoxFit.fill,
                      controls: null),
                );
              }
            }
            break;
          case cPOWERPOINTTYPE:
            //PlayPPT(strZone1File, rectWin);
            break;

          case cQUEUETYPE:
          case cWEBPAGETYPE:
            widget = PlatformUtils.isDesktop
                ? WebviewDesktopPlayer(url: _strZoneFile)
                : WebviewPlayer(url: _strZoneFile);
            break;
          case cFLASHTYPE:
            break;
          case cTVCAPTURETYPE:
          case cWEBCAMTYPE:
            break;
          case cTEXTTYPE:
            if (_bNeedReset) {
              widget = ScrollText(
                  key: Key(_strZoneFile), textFile: _strZoneFile, rect: _rect!);
            }
            //if (_bNeedReset) PlayTextType(pZoneData, strZone1File, rectWin);
            break;

          case cSTREAMINGTYPE:
            break;
          case cONLINETYPE:
            break;
          case cCLOCKTYPE:
            break;
          case cWEATHERTYPE:
            break;
          case cDDETYPE:
          case cDIRECTPLAYTYPE:
          case cSITEPLAYLIST:
            //playContentList(pZoneData.nZoneType, _strZoneFile, _rect!);
            widget = ContentListPlayer(
              key: Key(_strZoneFile),
              contentList: _strZoneFile,
              contentType: pZoneData.nZoneType,
              zone: _zoneId,
              rect: _rect!,
            );
            break;
          case cLINKAGETYPE:
            break;
          case cEVENTTYPE:
            break;
          case cPDFTYPE:
            bool bShowPDFScrollBar = (hasFlag(AppGlobal.pdfViewMode, 0x0002));
            var strContent = (bShowPDFScrollBar
                ? '$_strZoneFile#toolbar=0&navpanes=0&scrollbar=0&view=FitH'
                : '$_strZoneFile#toolbar=0&navpanes=0&scrollbar=0&view=Fit');
            widget = PlatformUtils.isDesktop
                ? WebviewDesktopPlayer(url: strContent)
                : WebviewPlayer(url: strContent);
            break;
          case cPLUGINTYPE:
            break;
          case cLIGHTBOXTYPE:
            break;
          case cAMELEMENTTYPE: //27
            widget = PlatformUtils.isDesktop
                ? WebviewDesktopPlayer(url: _strZoneFile)
                : WebviewPlayer(url: _strZoneFile);
            break;
          default:
            break;
        }
      } catch (e, stackTrace) {
        logE(
            'RenderZone failed - Zone: $_zoneId; _nPType: $_nPType; _strZoneFile: $_strZoneFile error: $e',
            stackTrace);
      }
    }

    _bIsPlaying = true;
    _bNeedReset = true;
    _bIsRendering = false;
    //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 6 _rtDuration: " + _rtDuration + " _rtAct " + _rtAct);
    logI(
        'RenderZone finished - Zone: $_zoneId; _nPType: $_nPType; _rtDuration: $_rtDuration; _rtAct $_rtAct; _strZoneFile: $_strZoneFile; _bIsValid: $_bIsValid.');

    return widget ?? Container(color: Utils.fromRGB(AppGlobal.clrBGColor));
  }

  void _initContentList(int nType, String strZoneFile, Rect rectWin) {
    bool initialize = true;
    if (_contentListPlayer == null) {
      //logD('''Zone $_zoneId play '$strZoneFile' step 21, TID $pid.''');
      _contentListPlayer = ContentListPlayerImpl(nType, _zoneId);
    } else {
      //logD('''Zone $_zoneId play '$strZoneFile' step 22, TID $pid.''');
      _contentListPlayer!.resetFirstFinished();
      _contentListPlayer!.setTimeForStop(true);
      initialize = false;
    }

    if (_contentListPlayer != null) {
      //logD('''Zone $_zoneId play '$strZoneFile' step 23, TID $pid.''');
      _contentListPlayer!.loadContentList(contentList: strZoneFile);
      if (_contentListPlayer!.isValidForPlay()) {
        //logD('''Zone $_zoneId play '$strZoneFile' step 24, TID $pid.''');
        _rtDuration = _nStart > 0
            ? (_contentListPlayer!.getDuration() -
                _contentListPlayer!.getDuration(_nStart))
            : _contentListPlayer!.getDuration();
        _contentListPlayer!.setPlayerRect(_rect!);
        //logD('''Zone $_zoneId play '$strZoneFile' step 25, TID $pid.''');
        _contentListPlayer!.setAHPlaying(_bIsAHPlaylist);
        _contentListPlayer!.setParentContentType(_nPType);
        //CString strCompany = PlayList.GetCurrCompany();
        _contentListPlayer!.setCompany(_strCompany);
        //_contentListPlayer!.initZone(context); //
        _contentListPlayer!
            .matchZoneImpl(_contentListPlayer!.getProductZones(_nStart));
      }
      _contentListPlayer!.setTimeForStop(false);
      if (!initialize) {
        playContentList(nType, strZoneFile, rectWin);
      }
    }
  }

  Future<void> preloadContentList(BuildContext context) async {
    if (_contentListPlayer != null) {
      _contentListPlayer!.initZone(context); //
    }
  }

  void playContentList(int nType, String strZoneFile, Rect rectWin) {
    if (_contentListPlayer != null && _contentListPlayer!.isValidForPlay()) {
      _contentListPlayer!.setStartTime(_dwStartTime);
      _contentListPlayer!.play(_nStart); //
      _bShowMessage = _contentListPlayer!.isShowMessage();
      _bShowMessageNext = _contentListPlayer!.isShowMessageNext();
      _nStart = 0;
    }
  }

  void playNextContentListItem(PlayFinish nFinish) {
    try {
      if (_contentListPlayer != null) {
        _contentListPlayer!.stopCurrProduct();
        _contentListPlayer!.playNextProduct();

        _bShowMessage = _contentListPlayer!.isShowMessage();
        _bShowMessageNext = _contentListPlayer!.isShowMessageNext();
      }
    } catch (e) {
      logE('PlayerZoneImpl - playNextContentListItem error: $e');
    }
  }

  void rePlayContentList() {
    if (_contentListPlayer != null) {
      _contentListPlayer!.rePlayProduct();
    }
  }

  void videoVolumeControl(bool bMute) {
    if (_player != null) {
      _player!.setVolume(bMute ? cVOLUMESILENCE : cVOLUMEFULL);
    }
  }

  void videoStatusControl(int nVideoStatus) {
    _nVideoStatus = nVideoStatus;
    if (_player != null) _player!.playOrPause();
    if (_contentListPlayer != null) {
      _contentListPlayer!.videoStatusControl(nVideoStatus);
    }
  }

  ({bool status, double? rtPosition}) getCurrentPosition() {
    if (_bIsRendering) {
      return (status: false, rtPosition: null);
    }

    bool bRet = false;
    double? rtPosition;
    if (_player != null) {
      rtPosition = _player!.state.position.inMilliseconds / 1000.0;
      bRet = true;
    }

    if (bRet) {
      /*logD(
          'CPlayerZoneDlg::getCurrentPosition - Zone: $_zoneId, rtPosition=$rtPosition, _rtCurrDuration=$_rtCurrDuration.');*/
      if (_nVideoStatus != 1 && rtPosition! - _rtCurrDuration < cEPSILON) {
        bRet = false;
      } else {
        _rtCurrDuration = rtPosition!;
      }
    }

    return (status: bRet, rtPosition: rtPosition);
  }

  ({bool status, PlayFinish? nFinish}) isPlayerFinish(
      double rtCurrPos, PlayFinish nFinish) {
    if (_bWantStop) {
      double rtDuration = _rtDuration;
      double rtAct = _rtAct;
      while (rtDuration - rtAct > cPLAYINGINTERVAL) {
        rtDuration -= rtAct;
      }

      if (_rtDuration > 0) {
        if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
          logD(
              'Zone $_zoneId Play start ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');
          if (!_bShowMessageNext) {
            _bShowMessage = _bShowMessageNext;
          }

          return (status: true, nFinish: nFinish);
        }
      }

      return (status: false, nFinish: nFinish);
    }

    ZoneData? pZoneData = getZoneData();
    bool bIsAH = _bIsAHPlaylist;
    if (pZoneData == null || _rtDuration < cEPSILON || _rtAct < cEPSILON) {
      return (status: true, nFinish: nFinish);
    }

    /*logD(
        '''PlayerZoneImpl - Zone: '$_zoneId' isPlayerFinish; _dtStartPlay: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}; _nPType: $_nPType; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'; _rtPlaying:'$_rtPlaying'.''');*/
    if (pZoneData.isMixedContent() && _contentListPlayer != null) {
      //return _contentListPlayer!.IsPlayFinish();
      var result = _contentListPlayer!.isPlayFinish(nFinish);
      if (result.status) {
        if (!_bShowMessageNext) {
          _bShowMessage = _bShowMessageNext;
        }
        //WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType, pZoneData.strZoneFile, pZoneData.nZoneDuration, bIsAH);
      }
      if (result.nFinish == PlayFinish.eCONTENTFINISH) {
        if (!_bShowMessageNext) {
          _bShowMessage = _bShowMessageNext;
        }
      }

      return result;
    }

    double rtAct = _rtAct;
    if (!_bIsRendering && pZoneData.nZoneType == cVIDEOTYPE) {
      //logD('Zone ${_zoneId}; _rtDuration:'%.8f'; _rtAct:'%.8f'; rtCurrPos:'%.8f'; _rtLine:'%.8f'!!!', _nZone, _rtDuration, _rtAct, rtCurrPos, _rtLine);
      if (_player != null || _preloadedContent != null) {
        // && _pZonePlayer->State() == MLS_LOADED
        if (_rtDuration - rtAct < cPLAYINGINTERVAL * 10) {
          if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
            logD(
                '''PlayerZoneImpl - Zone: '$_zoneId' isPlayerFinish; _dtStartPlay: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}; _nPType: $_nPType; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'; _rtPlaying:'$_rtPlaying'.''');
            /*logD(
                'Zone $_zoneId Create filter for video file ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');*/
            if (!_bShowMessageNext) {
              _bShowMessage = _bShowMessageNext;
            }
            //WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType, pZoneData.strZoneFile, pZoneData.nZoneDuration, bIsAH);
            return (status: true, nFinish: nFinish);
          }
          return (status: false, nFinish: nFinish);
        } else {
          if (_rtDuration - (_rtPlaying + rtCurrPos) > cPLAYINGINTERVAL) {
            if (rtAct - rtCurrPos < cPLAYINGINTERVAL) {
              /*logD(
                  'Zone $_zoneId Create filter for video file ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');*/
              logD(
                  '''PlayerZoneImpl - Zone: '$_zoneId' isPlayerFinish; _dtStartPlay: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}; _nPType: $_nPType; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'; _rtPlaying:'$_rtPlaying'.''');
              if (!_bShowMessageNext) {
                _bShowMessage = _bShowMessageNext;
              }
              //WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType, pZoneData.strZoneFile, pZoneData.nZoneDuration, bIsAH);
              return (status: true, nFinish: nFinish);
            }
            return (status: false, nFinish: nFinish);
          } else {
            if (!_bShowMessageNext) {
              _bShowMessage = _bShowMessageNext;
            }
            //WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType, pZoneData.strZoneFile, pZoneData.nZoneDuration, bIsAH);
            return (status: true, nFinish: nFinish);
          }
        }
      } else {
        if (_rtDuration > 0) {
          if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
            /*logD(
                'Zone $_zoneId Create filter for video file ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');*/
            logD(
                '''PlayerZoneImpl - Zone: '$_zoneId' isPlayerFinish; _dtStartPlay: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}; _nPType: $_nPType; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'; _rtPlaying:'$_rtPlaying'.''');
            if (!_bShowMessageNext) {
              _bShowMessage = _bShowMessageNext;
            }
            //WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType, pZoneData.strZoneFile, pZoneData.nZoneDuration, bIsAH);
            return (status: true, nFinish: nFinish);
          }
        }
      }
    } else {
      if (_rtDuration > 0) {
        if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
          /*logD(
              'Zone $_zoneId Play start ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');*/
          logD(
              '''PlayerZoneImpl - Zone: '$_zoneId' isPlayerFinish; _dtStartPlay: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}; _nPType: $_nPType; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'; _rtPlaying:'$_rtPlaying'.''');
          if (!_bShowMessageNext) {
            _bShowMessage = _bShowMessageNext;
          }
          //WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType, pZoneData.strZoneFile, pZoneData.nZoneDuration, bIsAH);
          return (status: true, nFinish: nFinish);
        }
      }
    }

    return (status: false, nFinish: nFinish);
  }

  int isPlayerFinished(double rtCurrPos) {
    ZoneData? pZoneData = getZoneData();
    if (pZoneData == null || _rtDuration < cEPSILON || _rtAct < cEPSILON) {
      return 0;
    }

    if (pZoneData.isMixedContent()) {
      PlayFinish nFinish = PlayFinish.eNOTFINISH;
      _contentListPlayer!.isPlayFinish(nFinish); //return
    }

    double rtAct = _rtAct;
    if (!_bIsRendering && pZoneData.nZoneType == cVIDEOTYPE) {
      if (_player != null || _preloadedContent != null) {
        if (_rtDuration - rtAct < cPLAYINGINTERVAL) {
          if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
            logI(
                '''PlayerZoneImpl - Zone '$_zoneId' isPlayerFinished;  _nPType: '$_nPType'; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'.''');
            /*if (_bWriteLog)
              WritePlayLoger(
                  GetPlayLogStart(),
                  _nZone,
                  pZoneData.nZoneType,
                  pZoneData.strZoneFile,
                  pZoneData.nZoneDuration,
                  _bIsAHPlaying);*/

            return 1;
          }
        } else {
          if (_rtDuration - (_rtPlaying + rtCurrPos) > cPLAYINGINTERVAL) {
            if (rtAct - rtCurrPos < cPLAYINGINTERVAL) {
              logI(
                  '''PlayerZoneImpl - Zone '$_zoneId' isPlayerFinished;  _nPType: '$_nPType'; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'.''');
              /*if (_bWriteLog)
                WritePlayLoger(
                    GetPlayLogStart(),
                    _nZone,
                    pZoneData.nZoneType,
                    pZoneData.strZoneFile,
                    pZoneData.nZoneDuration,
                    _bIsAHPlaying);*/

              return 2;
            }
          } else {
            /*if (_bWriteLog)
              WritePlayLoger(
                  GetPlayLogStart(),
                  _nZone,
                  pZoneData.nZoneType,
                  pZoneData.strZoneFile,
                  pZoneData.nZoneDuration,
                  _bIsAHPlaying);*/

            return 1;
          }
        }
      } else {
        if (_rtDuration > 0) {
          if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
            logI(
                '''PlayerZoneImpl - Zone '$_zoneId' isPlayerFinished;  _nPType: '$_nPType'; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'.''');
            /*if (_bWriteLog)
              WritePlayLoger(
                  GetPlayLogStart(),
                  _nZone,
                  pZoneData.nZoneType,
                  pZoneData.strZoneFile,
                  pZoneData.nZoneDuration,
                  _bIsAHPlaying);*/

            return 1;
          }
        }
      }
    } else {
      if (_rtDuration > 0) {
        if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
          logI(
              '''PlayerZoneImpl - Zone '$_zoneId' isPlayerFinished;  _nPType: '$_nPType'; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'.''');
          /*if (_bWriteLog)
            WritePlayLoger(GetPlayLogStart(), _nZone, pZoneData.nZoneType,
                pZoneData.strZoneFile, pZoneData.nZoneDuration, _bIsAHPlaying);*/

          return 1;
        }
      }
    }

    return 0;
  }

  void rePlayZone() {
    _rtCurrDuration = 0.00;
    ZoneData? pZoneData = getZoneData();
    if (pZoneData == null) {
      return;
    }

    _dtStartPlay = DateTime.now();
    int nCurSel = pZoneData.nZoneType;
    switch (nCurSel) {
      case cIMAGETYPE:
      case cTEXTTYPE:
        break;

      case cVIDEOTYPE:
        rePlayVideo();
        break;
      case cPOWERPOINTTYPE:
      case cQUEUETYPE:
        break;

      case cWEBPAGETYPE:
        break;
      case cFLASHTYPE:
        break;

      case cDDETYPE:
      case cDIRECTPLAYTYPE:
      case cSITEPLAYLIST:
        if (_contentListPlayer != null) {
          _rtDuration = _contentListPlayer!.getDuration();
          _contentListPlayer!.rePlay();
        }
        break;
      default:
        //RePlayDCMContent();
        break;
    }
    if (nCurSel != cSITEPLAYLIST &&
        nCurSel != cDDETYPE &&
        nCurSel != cDIRECTPLAYTYPE) {
      _rtDuration = pZoneData.nZoneDuration;
    }
    calcDuration();
  }

  bool rePlayVideo() {
    /*if (!_playCached || _player == null) {
      if (_player != null) {
        _player!.dispose();
      }
      _initVideoPlayer(getZoneData()!);
    }
    if (_player != null) {
      _player!.play();
    }*/
    if (_preloadedContent != null) {
      _preloadedContent!.stop();
      _rtAct = _preloadedContent!.getActualDuration();
      return true;
    } else {
      if (_player != null) {
        //_player!.seek(Duration.zero);
        _player!.stop();
        _player!.open(Media(LibraryHelper.normalizeMediaSource(_strZoneFile)),
            play: true);
        _rtAct = _player!.state.duration.inMilliseconds / 1000.0;

        return true;
      }
    }
    return false;
  }

  void showZoneWnd(bool bool) {}

  static Future<double> getVideoDuration(String videoFile) async {
    var player = Player(
      configuration: const PlayerConfiguration(
        title: 'dcm',
        osc: false,
        muted: false,
        async: true,
        libass: false,
        logLevel: MPVLogLevel.error,
      ),
    );

    final video = Media(LibraryHelper.normalizeMediaSource(videoFile));
    await player.open(video, play: false);
    player.setVolume(cVOLUMESILENCE);

    return player.state.duration.inMilliseconds / 1000.0;
  }

  static Future<PreloadedContent?> preloadContent(
      ZoneData pZoneData, BuildContext context,
      {String? filePath, String? company, Size? size, int ptype = -1}) async {
    filePath ??= Utils.getFilePath(
        pZoneData.strZoneFile, pZoneData.nZoneType, ptype, company);
    PreloadedContent? preloaded;
    switch (pZoneData.nZoneType) {
      case cVIDEOTYPE:
        preloaded =
            preloadVideoPlayer(pZoneData, filePath: filePath, size: size);
        break;
      case cIMAGETYPE:
        if (filePath.startsWith('http')) {
          await precacheImage(NetworkImage(filePath), context);
        } else {
          await precacheImage(FileImage(File(filePath)), context);
        }
        preloaded = PreloadedContent(type: cIMAGETYPE, filePath: filePath);
        break;
      default:
        break;
    }

    return preloaded;
  }

  static PreloadedContent? preloadVideoPlayer(ZoneData pZoneData,
      {String? filePath, String? company, Size? size, int ptype = -1}) {
    filePath ??= Utils.getFilePath(
        pZoneData.strZoneFile, pZoneData.nZoneType, ptype, company);
    try {
      var player = Player(
        configuration: const PlayerConfiguration(
          title: 'dcm',
          osc: false,
          muted: false,
          async: true,
          libass: false,
          logLevel: MPVLogLevel.error,
        ),
      );

      final video = Media(LibraryHelper.normalizeMediaSource(filePath));
      player.open(video, play: false);

      var controller = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          width: size?.width.toInt() ?? 800,
          height: size?.height.toInt() ?? 600,
        ),
      );
      player.setVolume(
          AppGlobal.videoVolume(pZoneData.bZoneMute, pZoneData.dVolume));

      return PreloadedContent(
          type: cVIDEOTYPE,
          filePath: filePath,
          controller: controller,
          player: player);
    } catch (e, stackTrace) {
      logE('PlayerZoneImpl - preloadVideoPlayer error: $e', stackTrace);
    }

    return null;
  }
}
