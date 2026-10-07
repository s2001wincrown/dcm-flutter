import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/clock_data.dart' show ClockData;
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/weather_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/content_list_player_impl.dart';
import 'package:dcm/backend/services/app_skin_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/xml_weather_setting.dart';
import 'package:dcm/backend/xml_settings/xml_clock_setting.dart';
import 'package:dcm/widgets/content_list_player.dart';
import 'package:dcm/widgets/clock_panel.dart';
import 'package:dcm/widgets/scrolltext.dart';
import 'package:dcm/widgets/slideshow.dart';
import 'package:dcm/widgets/pdf_player.dart';
import 'package:dcm/widgets/ppt_file_preview.dart';
import 'package:dcm/widgets/ppt_viewer_widget.dart';
import 'package:dcm/widgets/weather_panel.dart';
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
      await player!.stop();
      await player!.open(Media(LibraryHelper.normalizeMediaSource(filePath)),
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

Future<void> _observePlayerOperation(
  String operation,
  String filePath,
  Future<void> future,
) async {
  logD('PlayerZoneImpl - $operation requested for "$filePath".');
  try {
    await future;
    logD('PlayerZoneImpl - $operation completed for "$filePath".');
  } catch (error, stackTrace) {
    logE('PlayerZoneImpl - $operation failed for "$filePath": $error',
        stackTrace);
  }
}

class _ZoneVideo extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String filePath;
  final BoxFit fit;
  final bool shouldPlay;

  const _ZoneVideo({
    super.key,
    required this.player,
    required this.controller,
    required this.filePath,
    required this.fit,
    required this.shouldPlay,
  });

  @override
  State<_ZoneVideo> createState() => _ZoneVideoState();
}

class _ZoneVideoState extends State<_ZoneVideo> {
  @override
  void initState() {
    super.initState();
    _schedulePlayback();
  }

  @override
  void didUpdateWidget(covariant _ZoneVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player ||
        oldWidget.controller != widget.controller ||
        oldWidget.shouldPlay != widget.shouldPlay) {
      _schedulePlayback();
    }
  }

  void _schedulePlayback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.shouldPlay) {
        unawaited(_observePlayerOperation(
            'play', widget.filePath, widget.player.play()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Video(
        controller: widget.controller,
        wakelock: false,
        fit: widget.fit,
        controls: null,
      ),
    );
  }
}

class PlayerZoneImpl {
  //int productId;
  int _zoneId = -1;
  int _contentType = -1;
  int _nStart = 0;
  ProductData? _pProductData;
  ZoneData? _pZoneData;
  WeatherData? _weatherData;
  ClockData? _clockData;
  bool _bZoneFinish = false;
  bool _bFirstFinished = false;
  bool _bContinuePlaying = false;
  bool _bContentFinished = false;
  bool _bWriteLog = true;

  late DateTime _dwStartTime;
  late DateTime _dtStartPlay;

  bool _bIsRendering = false;
  int _initGeneration = 0;
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
  Future<void>? _stopFuture;
  int _nVideoStatus = -1;
  bool _bWantStop = false;

  void stopPlay() {
    _initGeneration++;
    final stopFuture = _stopPlayers();
    _stopFuture = stopFuture;
    unawaited(stopFuture.whenComplete(() {
      if (identical(_stopFuture, stopFuture)) {
        _stopFuture = null;
      }
    }));
  }

  Future<void> _stopPlayers() async {
    try {
      await _player?.stop();
      _contentListPlayer?.stop();
      await _preloadedContent?.stop();
    } catch (e, stackTrace) {
      logE('PlayerZoneImpl - stopPlay error: $e', stackTrace);
    }
  }

  Future<void> _disposePlayers() async {
    final player = _player;
    final contentListPlayer = _contentListPlayer;
    _player = null;
    _controller = null;
    _preloadedContent = null;
    _contentListPlayer = null;
    _bIsPlaying = false;

    try {
      await player?.dispose();
    } catch (e, stackTrace) {
      logE('PlayerZoneImpl - player dispose error: $e', stackTrace);
    }
    try {
      await contentListPlayer?.release();
    } catch (e, stackTrace) {
      logE('PlayerZoneImpl - content list dispose error: $e', stackTrace);
    }
  }

  Future<void> release() async {
    _initGeneration++;
    _bIsValid = false;
    _bIsRendering = false;
    await _stopFuture;
    await _disposePlayers();
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
  Future<void> initZone(
      [Map<String, PreloadedContent>? mapPreloadedContents]) async {
    final generation = ++_initGeneration;
    _bIsValid = false;
    _bIsRendering = true;
    _bIsPlaying = false;
    await _stopFuture;
    if (generation != _initGeneration) return;
    //Preloaded Content not need release
    if (_playCached) {
      await _stopPlayers();
    } else {
      //not preload content and need reset
      if (_bNeedReset) {
        await _disposePlayers();
      } else {
        await _stopPlayers();
      }
    }
    if (generation != _initGeneration) return;

    _rtCurrDuration = 0.00;
    _rtAct = 0;
    _rtPlaying = 0;
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
      _bIsRendering = false;
      return;
    }

    if (_zoneId < 0) _zoneId = pZoneData.nZoneID;
    if (_rect == null && _zoneId > -1) _rect = playSkin.getZoneRect(_zoneId);
    _rectPlayerOrg = _rect;
    _strContentName = pZoneData.strZoneFile;
    _contentType = pZoneData.nZoneType;

    _bIsRendering = true;
    _bIsValid = false;
    _strZoneFile = Utils.getFilePath(
        pZoneData.strZoneFile, pZoneData.nZoneType, _nPType, _strCompany);
    _clockData = null;
    logI(
        'Try to init Zone - Zone: $_zoneId, _nPType: $_nPType, _strZoneFile: $_strZoneFile, _bNeedReset: $_bNeedReset, mapPreloadedContents: ${mapPreloadedContents != null ? mapPreloadedContents.length : 0}.');

    _playCached = false;
    try {
      if (await _validZone(_strZoneFile, _contentType)) {
        if (generation != _initGeneration) return;
        _bIsValid = true;
        //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 4");
        _rtDuration = 0;
        switch (_contentType) {
          case cIMAGETYPE:
            break;
          case cVIDEOTYPE:
            if (mapPreloadedContents != null &&
                mapPreloadedContents.containsKey(_strZoneFile)) {
              _playCached = true;
              _preloadedContent = mapPreloadedContents[_strZoneFile];
              _rtAct = _preloadedContent!.getActualDuration();
            } else {
              if (_player != null) {
                unawaited(_player!.open(
                    Media(LibraryHelper.normalizeMediaSource(_strZoneFile)),
                    play: false));
                _rtAct = _player!.state.duration.inMilliseconds / 1000.0;
              } else {
                await _initVideoPlayer(pZoneData, null);
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
            break;

          case cQUEUETYPE:
          //strZone1File = GetQueueLink(strZone1File);
          case cWEBPAGETYPE:
            break;
          case cFLASHTYPE:
            break;
          case cTVCAPTURETYPE:
          case cWEBCAMTYPE:
          case cSTREAMINGTYPE:
            if (_player != null) {
              unawaited(_player!.open(
                  Media(LibraryHelper.normalizeMediaSource(_strZoneFile)),
                  play: false));
              _rtAct = _player!.state.duration.inMilliseconds / 1000.0;
            } else {
              await _initVideoPlayer(pZoneData, null);
              if (_player != null) {
                _rtAct = _player!.state.duration.inMilliseconds / 1000.0;
              } else {
                logE(
                    'PlayerZoneImpl - init media source error: _player is null');
              }
            }
            break;
          case cTEXTTYPE:
            break;
          case cONLINETYPE:
            break;
          case cCLOCKTYPE:
            final clockData = ClockData();
            if (XmlClockSetting.loadClockSetting(
                pZoneData.strZoneFile, clockData, _strCompany)) {
              _clockData = clockData;
            } else {
              _bIsValid = false;
              logE(
                  'PlayerZoneImpl - failed to load clock setting "${pZoneData.strZoneFile}".');
            }
            break;
          case cWEATHERTYPE:
            _weatherData = XmlWeatherSetting.loadFromFile(
                pZoneData.strZoneFile, _strCompany ?? '');
            break;
          case cDDETYPE:
          case cDIRECTPLAYTYPE:
          case cSITEPLAYLIST:
            await _initContentList(_contentType, _strZoneFile, _rect!);
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
      _bIsValid = false;
      logE(
          'Init Zone failed - Zone: $_zoneId; _nPType: $_nPType; _strZoneFile: $_strZoneFile error: $e',
          stackTrace);
    } finally {
      if (generation == _initGeneration) {
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
    }
  }

  Future<void> _initVideoPlayer(ZoneData pZoneData,
      [PreloadedContent? preloaded]) async {
    preloaded ??= await preloadVideoPlayer(pZoneData,
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

  Future<void> rePlay() async {
    await rePlayZone();
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
              widget = _ZoneVideo(
                key: Key(_strZoneFile),
                player: _preloadedContent!.player!,
                controller: _preloadedContent!.controller!,
                filePath: _strZoneFile,
                fit: pZoneData.bZoneRatio ? BoxFit.contain : BoxFit.fill,
                shouldPlay: _nVideoStatus != 1,
              );
            } else {
              if (_player != null && _controller != null) {
                widget = _ZoneVideo(
                  key: Key(_strZoneFile),
                  player: _player!,
                  controller: _controller!,
                  filePath: _strZoneFile,
                  fit: pZoneData.bZoneRatio ? BoxFit.contain : BoxFit.fill,
                  shouldPlay: _nVideoStatus != 1,
                );
              }
            }
            break;
          case cPOWERPOINTTYPE:
            final zoneSize = _rect?.size ?? Size.zero;
            widget = PlatformUtils.isAndroid || PlatformUtils.isIOS
                ? PptFilePreview(
                    filePath: _strZoneFile,
                    width: zoneSize.width,
                    height: zoneSize.height,
                  )
                : PlatformUtils.isWindows
                    ? PptViewerWidget(
                        filePath: _strZoneFile,
                        zoneRect: _rect ?? Rect.zero,
                      )
                    : SizedBox.fromSize(
                        size: zoneSize,
                        child: ColoredBox(
                          color: Utils.fromRGB(AppGlobal.clrBGColor),
                        ),
                      );
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
          case cSTREAMINGTYPE:
            if (_player != null && _controller != null) {
              widget = _ZoneVideo(
                key: Key(_strZoneFile),
                player: _player!,
                controller: _controller!,
                filePath: _strZoneFile,
                fit: pZoneData.bZoneRatio ? BoxFit.contain : BoxFit.fill,
                shouldPlay: _nVideoStatus != 1,
              );
            }
            break;
          case cTEXTTYPE:
            if (_bNeedReset) {
              widget = ScrollText(
                  key: Key(_strZoneFile), textFile: _strZoneFile, rect: _rect!);
            }
            //if (_bNeedReset) PlayTextType(pZoneData, strZone1File, rectWin);
            break;
          case cONLINETYPE:
            break;
          case cCLOCKTYPE:
            if (_clockData != null) {
              widget = ClockPanel(
                key: Key(_strZoneFile),
                data: _clockData!,
              );
            }
            break;
          case cWEATHERTYPE:
            widget = WeatherPanel(
              key: Key(_strZoneFile),
              data: _weatherData,
            );
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
            widget = PdfPlayer(source: _strZoneFile);
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

    final pZoneData = getZoneData();
    final needsVideoController = pZoneData != null &&
        (pZoneData.nZoneType == cVIDEOTYPE ||
            pZoneData.nZoneType == cSTREAMINGTYPE ||
            pZoneData.nZoneType == cTVCAPTURETYPE ||
            pZoneData.nZoneType == cWEBCAMTYPE);
    _bIsPlaying = !needsVideoController || widget != null;
    _bNeedReset = true;
    //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 6 _rtDuration: " + _rtDuration + " _rtAct " + _rtAct);
    logI(
        'RenderZone finished - Zone: $_zoneId; _nPType: $_nPType; _rtDuration: $_rtDuration; _rtAct $_rtAct; _strZoneFile: $_strZoneFile; _bIsValid: $_bIsValid.');

    return widget ?? Container(color: Utils.fromRGB(AppGlobal.clrBGColor));
  }

  Future<void> _initContentList(
      int nType, String strZoneFile, Rect rectWin) async {
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
        _contentListPlayer!.setIsLoading(true);
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
        await playContentList(nType, strZoneFile, rectWin);
      }
    }
  }

  Future<void> preloadContentList(
    BuildContext context, {
    VoidCallback? onFirstContentPreloaded,
  }) async {
    final contentListPlayer = _contentListPlayer;
    if (contentListPlayer == null) {
      throw StateError(
          'Content list player is not initialized for zone $_zoneId.');
    }
    if (!await contentListPlayer.initZone(
      context,
      firstProductIndex: _nStart,
      onFirstContentPreloaded: onFirstContentPreloaded,
    )) {
      throw StateError('Content list preload failed for zone $_zoneId.');
    }
  }

  void cancelContentListPreload() {
    _contentListPlayer?.setIsLoading(false);
  }

  Future<void> playContentList(
      int nType, String strZoneFile, Rect rectWin) async {
    if (_contentListPlayer != null && _contentListPlayer!.isValidForPlay()) {
      _contentListPlayer!.setStartTime(_dwStartTime);
      await _contentListPlayer!.play(_nStart);
      _bShowMessage = _contentListPlayer!.isShowMessage();
      _bShowMessageNext = _contentListPlayer!.isShowMessageNext();
      _nStart = 0;
    }
  }

  Future<void> playNextContentListItem(PlayFinish nFinish) async {
    try {
      if (_contentListPlayer != null) {
        _contentListPlayer!.stopCurrProduct();
        await _contentListPlayer!.playNextProduct().catchError(
          (Object error, StackTrace stackTrace) {
            logE(
              'PlayerZoneImpl - next content-list item failed: $error',
              error,
              stackTrace,
            );
          },
        );

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
    final player = _preloadedContent?.player ?? _player;
    player?.setVolume(bMute ? cVOLUMESILENCE : cVOLUMEFULL);
  }

  void videoStatusControl(int nVideoStatus) {
    if (_nVideoStatus != nVideoStatus) {
      _nVideoStatus = nVideoStatus;
      final player = _preloadedContent?.player ?? _player;
      if (nVideoStatus == 1) {
        if (player != null) {
          unawaited(player.pause());
        }
      } else if (nVideoStatus == 2) {
        if (player != null) {
          unawaited(player.play());
        }
      }
    }
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
    final player = _preloadedContent?.player ?? _player;
    if (player != null) {
      rtPosition = player.state.position.inMilliseconds / 1000.0;
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

  Future<void> rePlayZone() async {
    await _rePlayZone();
  }

  Future<void> _rePlayZone() async {
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
      case cSTREAMINGTYPE:
      case cTVCAPTURETYPE:
      case cWEBCAMTYPE:
        await rePlayVideo();
        break;
      case cPOWERPOINTTYPE:
        break;
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

  Future<bool> rePlayVideo() async {
    final generation = _initGeneration;
    final player = _preloadedContent?.player ?? _player;
    if (player == null) return false;

    try {
      await player.stop();
      if (generation != _initGeneration) return false;
      final source = _preloadedContent?.filePath ?? _strZoneFile;
      await player.open(
        Media(LibraryHelper.normalizeMediaSource(source)),
        play: _nVideoStatus != 1,
      );
      if (generation != _initGeneration) return false;
      _rtAct = player.state.duration.inMilliseconds / 1000.0;
      return true;
    } catch (error, stackTrace) {
      logE('PlayerZoneImpl - video replay failed: $error', stackTrace);
      return false;
    }
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
    await player.setVolume(cVOLUMESILENCE);

    var duration = player.state.duration.inMilliseconds / 1000.0;
    await player.dispose();

    return duration;
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
            await preloadVideoPlayer(pZoneData, filePath: filePath, size: size);
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

  static Future<PreloadedContent?> preloadVideoPlayer(ZoneData pZoneData,
      {String? filePath, String? company, Size? size, int ptype = -1}) async {
    filePath ??= Utils.getFilePath(
        pZoneData.strZoneFile, pZoneData.nZoneType, ptype, company);
    Player? player;
    try {
      player = Player(
        configuration: const PlayerConfiguration(
          title: 'dcm',
          osc: false,
          muted: false,
          async: true,
          libass: false,
          logLevel: MPVLogLevel.error,
        ),
      );

      player.stream.error.listen(
        (error) => logE(
            'PlayerZoneImpl - MediaKit stream error for "$filePath": $error'),
      );
      player.stream.videoParams.listen(
        (params) =>
            logI('PlayerZoneImpl - video parameters for "$filePath": $params.'),
      );
      player.stream.width.listen(
        (width) =>
            logD('PlayerZoneImpl - video width for "$filePath": $width.'),
      );
      player.stream.height.listen(
        (height) =>
            logD('PlayerZoneImpl - video height for "$filePath": $height.'),
      );

      final controller = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          width: size?.width.toInt() ?? 800,
          height: size?.height.toInt() ?? 600,
        ),
      );

      final video = Media(LibraryHelper.normalizeMediaSource(filePath));
      logD('PlayerZoneImpl - open requested for "$filePath".');
      await player.open(video, play: false);
      logD('PlayerZoneImpl - open completed for "$filePath".');
      logD('PlayerZoneImpl - setVolume requested for "$filePath".');
      await player.setVolume(
          AppGlobal.videoVolume(pZoneData.bZoneMute, pZoneData.dVolume));
      logD('PlayerZoneImpl - setVolume completed for "$filePath".');

      unawaited(controller.platform.future.then((_) {
        logI(
            'PlayerZoneImpl - video controller ready for "$filePath"; texture: ${controller.id.value}; rect: ${controller.rect.value}.');
        void logTextureUpdate() {
          final textureId = controller.id.value;
          final rect = controller.rect.value;
          logI(
              'PlayerZoneImpl - video texture update for "$filePath"; texture: $textureId; rect: $rect.');
          if (textureId != null && rect != null) {
            controller.id.removeListener(logTextureUpdate);
            controller.rect.removeListener(logTextureUpdate);
          }
        }

        controller.id.addListener(logTextureUpdate);
        controller.rect.addListener(logTextureUpdate);
      }).catchError((Object error, StackTrace stackTrace) {
        logE('PlayerZoneImpl - video controller failed for "$filePath": $error',
            stackTrace);
      }));
      return PreloadedContent(
          type: cVIDEOTYPE,
          filePath: filePath,
          controller: controller,
          player: player);
    } catch (e, stackTrace) {
      await player?.dispose();
      logE('PlayerZoneImpl - preloadVideoPlayer error: $e', stackTrace);
    }

    return null;
  }
}
