import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/playitem.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/models/zone_rect_data.dart';
import 'package:dcm/backend/services/ah_playlist_impl.dart';
import 'package:dcm/backend/services/app_skin_impl.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/file_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:intl/intl.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:path/path.dart' as path;

class PlayerScreenProvider extends ChangeNotifier {
  static PlayerScreenProvider? _instance;
  static PlayerScreenProvider? get instance => _instance;

  PlayerScreenProvider() {
    _instance = this;
  }

  int currentShowIndex = 0;
  int nextShowIndex = 0;
  Timer? _timer;
  Timer? _playingTimer;
  final List<PlayerZoneImpl> _playerZones = [];

  String? _strDCMFile;
  bool _bValidForPlay = false;
  bool _bScreenLayoutChanged = false;
  bool _bDisplayChanged = false;
  bool _bIsTouchScreen = false;
  bool _bIsSameSkin = false;
  bool _bIsSound = false;
  //Render rect
  Rect _rectPlayer = const Rect.fromLTWH(0, 0, 1920, 1080);

  int _nSerialControl = 0;

  SerialPort? _pSerialControl;

  int _nPushBtn = 0;
  int _btnEvent = 0;
  bool _bIsPlaying = false;
  bool _bDBClickClose = false;
  bool _bPlayConti = true;
  bool _bIsPause = false;
  bool _bNeedPause = false;
  bool _bNeedRefresh = false;
  int _msgNeedRefresh = cINTMIN;

  String _strTextPath = '';
  String _strBKMusic = '';

  late DateTime _dwSecondTime;
  late DateTime _dwVideoPause;
  DateTime? _dwLatestUDP;

  int _needBackToSchedule = 0;

  bool _bReloadSchedule = false;
  bool _bIsTimeForRefresh = false;
  bool _bIsTimeForStopAH = false;
  bool _bIsTimeForPlayAH = false;
  bool _bIsTimeForNextPlaylist = false;
  bool _bIsTimeForNextGroup = false;
  bool _bNeedPlayNextProduct = false;
  int _isNeedBackToSchedule = 0;
  bool _bIsLoading = false;
  bool _needNotifyListeners = false;

  bool _bIsPushFile = false;

  String _strSerialCommand = '';
  int _nUDPPort = 0;

  int _dwUSBImport = 0;
  int _nResetZoneThread = 0;
  int _nTotalZoneThread = 0;

  late DateTime _dwStartTime;
  late DateTime _dwFirstTime;

  bool _bClosing = false;
  int _nCurrProduct = 0;
  int _lVideoStatus = 0;
  int _lTVChannel = -1;

  List<PlayerZoneImpl> getPlayerZones() => _playerZones;
  List<PlayerZoneImpl> getPlayingZones() =>
      _playerZones.where((element) => element.getZone() > -1).toList();

  PlayerZoneImpl? getPlayerZone(int zone) {
    for (var playerZoneImpl in _playerZones) {
      if (playerZoneImpl.getZone() == zone) {
        return playerZoneImpl;
      }
    }

    return null;
  }

  List<PlayerZoneImpl>? getContentListPlayerZones(int zone) {
    PlayerZoneImpl? playerZoneImpl = getPlayerZone(zone);
    if (playerZoneImpl != null &&
        playerZoneImpl.getContentListPlayer() != null) {
      return playerZoneImpl.getContentListPlayer()!.players;
    }

    return null;
  }

  void playImm() async {
    if (isBlank(_strDCMFile)) {
      _readyForPlay();
    } else {
      if (loadCatalogue(_strDCMFile!)) {
        if (!ScheduleList().isCatalogueCanPlay()) {
          _bValidForPlay = false;
        }
      }
      if (_bValidForPlay) {
        initZoneThread();
        //_PlayerFrame.BringWindowToTop();
      }
    }
    if (!_bValidForPlay) {
      playSkin.loadSkins(0, 'No Frame and No Button', 0);
      Rect rectMonitor = playSkin.monitorRect;
      /*MoveWindow(rectMonitor);
      SetWindowPos(
          null,
          rectMonitor.left,
          rectMonitor.top,
          rectMonitor.Width(),
          rectMonitor.Height(),
          SWP_NOACTIVATE | SWP_NOREPOSITION); //SWP_NOMOVE |*/
      logD('No content to play: $_strDCMFile, TID $pid.');
      startTimer();
    } else {
      ScheduleList().writePlaylistLog();

      String strPlayStart = path.join(App().dataPath, 'playstart.txt');
      if (await File(strPlayStart).exists()) sendSerialFile(strPlayStart);

      //LoadExtendPrograms();

      _dwStartTime = DateTime.now();
      _dwFirstTime = DateTime.now();
      stopTimer();
      startPlayingTimer();
    }
  }

  void startTimer() {
    //_timer
    // Cancel any pending timer event
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 10000), (timer) {
      playImm();
    });
  }

  void stopTimer() {
    // Cancel the timer
    _timer?.cancel();
  }

  void startPlayingTimer() {
    // Cancel any pending timer event
    _playingTimer?.cancel();

    _playingTimer =
        Timer.periodic(const Duration(milliseconds: cPLAYINGDURATION), (timer) {
      _onTimer();
    });
  }

  void stopPlayingTimer() {
    // Cancel the timer
    _playingTimer?.cancel();
  }

  void playAll() {
    resetFirstFinished();
    _bIsPlaying = true;
    _bPlayConti = true;

    playProduct(ScheduleList().getPlayProduct(), true);
  }

  void stopPlay() {
    //_pProductData = null;
    deleteZoneThread(0);
    deleteMessageThreadByOutput(cINTMIN);

    //killPPProcess();
  }

  void _onTimer() {
    _needNotifyListeners = false;
    /*logD(
        'PlayerScreenProvider - OnTimer - _bValidForPlay: $_bValidForPlay; _bIsPlaying: \'$_bIsPlaying\'');*/
    if (!_bValidForPlay) {
      stopPlayingTimer();
      playImm();
      return;
    }

    try {
      if (_lVideoStatus == 1) {
        videoStatusControl(_lVideoStatus);
        _dwVideoPause = DateTime.now();
        return;
      } else if (_lVideoStatus == 2) {
        videoStatusControl(_lVideoStatus);
        _lVideoStatus = 0;
        return;
      }
      if (_lTVChannel > -1) {
        ScheduleList().changeTVChannel(_lTVChannel);
        tvChannelControl(_lTVChannel);
        _lTVChannel = -1;
        return;
      }

      if (_bNeedRefresh) {
        _bNeedRefresh = false;
        _bIsPause = false;
        reloadSchedule();
        AHPlayList.resetDefaultMessage();
        //UDPNotify(0);
        return;
      }
      if (_bIsPause) {
        saveStatusAndPause();
        isTimeForAHMessage(DateTime.now());
        return;
      }

      if (_bNeedPause) {
        _bNeedPause = false;
        _bIsPause = true;
        stopNotQuit();
        return;
      }

      if (App().playTimeForDemo != null) {
        if (DateTime.now().difference(_dwStartTime).inMinutes >
            App().playTimeForDemo!) {
          stopAll();
          /*EndDialog(IDOK);
          String strMessage;
          strMessage.Format(getStringByID(IDS_STOP_MESSAGE) +'\n' + getStringByID(IDS_STOP_MESSAGE2), App().playTimeForDemo / 60);
          MessageBox(strMessage, APP_TITLE, MB_OK);*/
          return;
        }
      }

      //if (playBtnEvent()) return;

      //if (hideTouchScreen()) return;

      if (_isNeedBackToSchedule > 0) {
        backToSchedule();
        return;
      }

      if (_bNeedPlayNextProduct) {
        _bNeedPlayNextProduct = false;
        /*if (_btnEvent > 0) {
          InitHookProc();
          DBClickRoute();
        }*/

        playNextProduct();
        return;
      }
      /*if (!_bIsLoading && _btnEvent > 0) {
        DBClickRoute(false);
      }*/

      int nFlag = -1;
      if (ScheduleList().isDCMFilePlay() && (_btnEvent == 0)) {
        //not Preview mode
        DateTime dtCurr = DateTime.now();
        if (_bIsPlaying && ScheduleList().isTimeForStop(dtCurr)) {
          logD(
              'ScheduleList().IsTimeForStop ${DateFormat('yyyy-MM-dd HH:mm:ss').format(dtCurr)}.');
          if (isNormalCut()) {
            stopNotQuit();
            _bIsPlaying = false;
            return;
          } else {
            _bIsTimeForRefresh = true;
            ScheduleList().setPlaylistLog();
          }
        } else if (_bIsPlaying && ScheduleList().isTimeForPlayNextEvent()) {
          if (isNormalCut()) {
            stopNotQuit();
            resetFirstFinished();
            //_nCurrProduct = 0;
            stopPlayingTimer();
            playNextProduct();
            return;
          } else {
            //_bIsTimeForRefresh = true;
            _bIsTimeForNextPlaylist = true;
          }
        } else if (_bIsPlaying &&
            isTimeToCut() &&
            ScheduleList().isTimeForPlayNextGroup()) {
          //_bIsTimeForRefresh = true;
          //ScheduleList().SetPlaylistLog();
          _bIsTimeForNextGroup = true;
        }

        var result = ScheduleList().isTimeForLoad(dtCurr, nFlag);
        if (result.status || (!_bValidForPlay)) {
          nFlag = result.nFlag!;
          if (!_bIsPlaying || (isNormalCut() && !isDurationCut())) {
            logD(
                'PlayerScreenProvider - OnTimer - ScheduleList().IsTimeForLoad - IsTimeForPlayAH; _bIsPlaying: \'$_bIsPlaying\'');
            stopNotQuit();
            _bValidForPlay = false;
            var playResult = ScheduleList().playFileList();
            if (!playResult.status) {
              return;
            }

            if (!loadCatalogue(playResult.strDCMFile!)) {
              stopNotQuit();
              return;
            }
            _bValidForPlay = true;
          } else if (isTimeToCut()) {
            if (nFlag == 1) {
              _bIsTimeForPlayAH = true;
              logD('PlayerScreenProvider - OnTimer IsTimeForPlayAH');
            } else if (nFlag == 0) {
              _bIsTimeForStopAH = true;
              logD('PlayerScreenProvider - OnTimer IsTimeForStopAH');
            } else {
              _bIsTimeForRefresh = true;
            }
          } else {
            if (nFlag == 0) {
              _bIsTimeForStopAH = true;
            } else {
              logD(
                  'PlayerScreenProvider - OnTimer - ScheduleList().IsTimeForLoad - IsTimeForPlayAH');
              stopNotQuit();
              _bValidForPlay = false;
              var playResult = ScheduleList().playFileList();
              if (!playResult.status) {
                return;
              }

              if (!loadCatalogue(playResult.strDCMFile!)) {
                stopNotQuit();
                return;
              }
              _bValidForPlay = true;
            }
          }
        }

        if (!_bIsPause) {
          if (!_bIsPlaying && _bValidForPlay) {
            if (ScheduleList().isTimeForPlay(dtCurr)) {
              playAll();
            }
            return;
          }
        }
      } else {
        if (!_bIsPlaying && _bValidForPlay) {
          playAll();
          return;
        }
      }

      if (_bIsPlaying) {
        //logD('PlayerScreenProvider - OnTimer Start zoneThreadCheck');
        bool bSaveState = zoneThreadCheck(_nTotalZoneThread);

        DateTime dtCurr = DateTime.now();
        if (bSaveState) {
          // && !_bIsTimeForStopAH) || (bSaveState && _bIsTimeForPlayAH && ScheduleList().IsPlayingEpisode()))
          if (AppGlobal.processAHConflict == 1) {
            _bIsTimeForPlayAH = ScheduleList().isTimeForPlayEpisode(dtCurr);
          }
          //SaveState(true);
          ScheduleList().saveState();
        }

        isTimeForAHMessage(dtCurr);

        changePlaylist();
        if (_needNotifyListeners) {
          _needNotifyListeners = false;
          notifyListeners();
        }
      }
    } catch (e) {
      _bReloadSchedule = false;
      _bIsTimeForRefresh = false;
      _bIsTimeForStopAH = false;
      _bIsTimeForPlayAH = false;
      _bIsTimeForNextPlaylist = false;
      _bIsTimeForNextGroup = false;
      logD('PlayerScreenProvider - OnTimer catch Exception: $e');
    }
  }

  bool zoneThreadCheck(int nTotalZone) {
    double rtPos = 0;
    bool bSaveState = false;

    DateTime dwSecondTime = DateTime.now();
    //for (i=0; i<nTotalZone; i++)
    bool bNeedSelectedProduct = false;
    PlayerZoneImpl? pThread;
    for (var pThread0 in _playerZones) {
      if (pThread0.getZone() > -1) {
        if (pThread0.isPlaying() && pThread0.isWantStop()) {
          //::PostMessage(pThread0.GetPlayerHWnd(), WM_INFORM_STOP, 0, 0);
          logD(
              'PlayerScreenProvider - zoneThreadCheck, Zone: ${pThread0.getZone()} want to stop, Current TID $pid.');
          _needNotifyListeners = true;
          continue;
        } else if (!pThread0.isPlaying() && !pThread0.isWantStop()) {
          bNeedSelectedProduct = true;
          //::PostMessage(pThread0.GetPlayerHWnd(), WM_INFORM_PLAY, 0, 0);
          logD(
              'PlayerScreenProvider - zoneThreadCheck, Zone: ${pThread0.getZone()} try to play, Current TID $pid.');
          _needNotifyListeners = true;
          continue;
        }

        if (pThread0.hasContent(cTHUMBVIEWTYPE)) {
          pThread = pThread0;
        }

        double rtCurrPos1 = dwSecondTime
            .difference(pThread0.getStartPlayTime())
            .inMilliseconds
            .toDouble();
        var result = pThread0.getCurrentPosition();
        if (!result.status) {
          rtPos = rtCurrPos1 / Duration.millisecondsPerSecond;
        } else {
          rtPos = result.rtPosition!;
          if (rtCurrPos1 > 0 && rtPos < cEPSILON) {
            rtPos = rtCurrPos1 / Duration.millisecondsPerSecond;
          }
        }

        PlayFinish nFinish = PlayFinish.eNOTFINISH;
        //pThread0.SetContentFinished(false);
        var pfResult = pThread0.isPlayerFinish(rtPos, nFinish);
        nFinish = pfResult.nFinish ?? nFinish;
        logD(
            'PlayerScreenProvider - zoneThreadCheck, Zone: ${pThread0.getZone()}, rtPos: $rtPos, rtCurrPos1: $rtCurrPos1, pfResult: ${pfResult.status} - ${pfResult.nFinish}.');
        if (pfResult.status) {
          pThread0.setPlayingDuration(rtPos);
          pThread0.setStartPlayTime(DateTime.now());
          //pThread0.SetFirstFinished();
          pThread0.setZoneFinish(true);
          pThread0.setContentFinished(true);
          bSaveState = true;
          if (pThread0.getPlayingLine() - pThread0.getPlayingDuration() <
              cPLAYINGINTERVAL) {
            pThread0.setFirstFinished();
          }
        } else {
          if (nFinish == PlayFinish.eCONTENTSTARTING) {
            _needNotifyListeners = true;
            pThread0.setContentStarting(false);
          }
          if (nFinish == PlayFinish.eCONTENTFINISH) {
            bSaveState = true;
          }

          pThread0.setContentFinished(nFinish == PlayFinish.eCONTENTFINISH);
        }
      }
    }

    if (bNeedSelectedProduct &&
        pThread != null &&
        playSkin.highlightFocusBtn &&
        playSkin.dcmFile.isEmpty) {
      _needNotifyListeners = true;
      //notifyListeners();
      //::PostMessage(pThread.GetPlayerHWnd(), WM_INFORM_PLAY, 2, 0);
    }

    return bSaveState;
  }

  void saveStatusAndPause() {
    if (_bIsPlaying) {
      //HideAllZones();
      ScheduleList().saveState();
      stopNotQuit();
    }
  }

  void isTimeForAHMessage(DateTime dtCurr) {
    if (!App().showAHMessage) {
      return;
    }

    if (_msgNeedRefresh == cINTMAX) {
      _msgNeedRefresh = cINTMIN;
      deleteMessageThreadByOutput(cINTMIN);
      resumePlaylist();
    } else if (_msgNeedRefresh >= cWORDMAX) {
      int nLayer = fHIWORD(_msgNeedRefresh);
      _msgNeedRefresh = cINTMIN;
      deleteMessageThreadByLayer(nLayer);
      resumePlaylist();
    } else if (_msgNeedRefresh != cINTMIN) {
      int nOutput = _msgNeedRefresh;
      _msgNeedRefresh = cINTMIN;
      loadMessageThread(nOutput);
    }

    int nOutput = cINTMIN;
    int nRet = ScheduleList().isTimeForStopMessage(dtCurr, nOutput);
    if (nRet == 0) {
      deleteMessageThreadByOutput(nOutput);
      resumePlaylist();

      return;
    } else if (nRet == 2) {
      loadMessageThread(nOutput);
      tryStopPlaylist(nOutput);
    }

    nOutput = cINTMIN;
    if ((nOutput = ScheduleList().isTimeForMessage(dtCurr)) != cINTMIN) {
      createMessageThread(nOutput);
      tryStopPlaylist(nOutput);
    }

    nOutput = cINTMIN;
    if ((nOutput = ScheduleList().isTimeForLoadMessage(dtCurr)) != cINTMIN) {
      loadMessageThread(nOutput);
      tryStopPlaylist(nOutput);
    }
  }

  void resumePlaylist() {
    if (_bIsPause) {
      _needBackToSchedule = 1;
      _bIsPause = false;
    }
  }

  void tryStopPlaylist([int nOutput = -1]) {
    if (ScheduleList().messageList.isStopPlaylist(nOutput)) {
      _bIsPause = true;
    }
  }

  void adjustPlayRect(ProductData pProductData) {
    //WriteMessage(MSG_INFO, 'PlayerScreenProvider - LoadCatalogue Step: %d, Current TID $pid.', 1, GetCurrentThreadId());
    //MatchZoneThread(nTotalZone);
    matchZoneThreadByProduct(pProductData);
    //WriteMessage(MSG_INFO, 'PlayerScreenProvider - LoadCatalogue Step: %d, Current TID $pid.', 2, GetCurrentThreadId());
    if (_bScreenLayoutChanged) {
      _bScreenLayoutChanged = false;
      //StopPlayer();
      hideAllZones();

      //ChangeMessageRect();
      //ChangeMessageRgn(nOutput);
      //ChangePlayerRgn();
      //changeFrameRgn();
      //DigitalSignageScreen.refresh;
    }
  }

  void resetFirstFinished() {
    for (var pThread0 in _playerZones) {
      if (pThread0.getZone() > -1) {
        pThread0.setZoneFinish(false);
        pThread0.setFirstFinished(false);
        pThread0.setContentFinished(false);
      }
    }
  }

  bool isProductFinished() {
    for (var pThread0 in _playerZones) {
      if (pThread0.getZone() > -1) {
        if (!pThread0.isFirstFinished()) {
          return false;
        }
      }
    }

    return true;
  }

  bool isContentFinished() {
    bool bFinished = true;
    for (var pThread0 in _playerZones) {
      if (pThread0.getZone() > -1) {
        if (!pThread0.isContentFinished()) {
          bFinished = false;
          break;
        }
      }
    }

    return bFinished;
  }

  void changePlaylist() {
    bool bIsPlayingEpisode = ScheduleList().isPlayingEpisode();
    //int nTotalZone = ScheduleList().getTotalZones();
    int nTotalZone = _nTotalZoneThread;
    if (!isProductFinished()) //Product not finish
    {
      /*if (DateTime.now().difference(_dwSecondTime).inMilliseconds > 1800000) {
        _dwSecondTime = DateTime.now();
        int  nMemStatus = 0; 
        WriteMemoryLog(nMemStatus);
      }*/
      if ((_bReloadSchedule ||
              _bIsTimeForRefresh ||
              _bIsTimeForStopAH ||
              _bIsTimeForPlayAH ||
              _bIsTimeForNextPlaylist ||
              _bIsTimeForNextGroup) &&
          isContentFinished()) {
        // Content is finish
        if (_bReloadSchedule) {
          if (!(ScheduleList().isAHPlaylist() && _bIsTimeForNextPlaylist)) {
            bool bIsAH = false;
            if (!_bIsTimeForPlayAH) {
              bIsAH = bIsPlayingEpisode;
            }
            ScheduleList().incrementContentListIndex(bIsAH);
          }

          logD('start ReloadSchedule, Current TID: $pid.');
          reloadSchedule(false);
        } else if (_bIsTimeForNextPlaylist) {
          if (!ScheduleList().isAHPlaylist()) {
            bool bIsAH = false;
            if (!_bIsTimeForPlayAH) {
              bIsAH = bIsPlayingEpisode;
            }
            ScheduleList().incrementContentListIndex(bIsAH);
          }

          logD('start play next playlist, Current TID: $pid.');
          playNextPlaylist();
        } else if (_bIsTimeForStopAH) {
          logD('stop playing Nomal Ad-hoc, Current TID: $pid.');
          _bValidForPlay = false;
          if (ScheduleList().isWaitForPlayAH()) {
            if (AppGlobal.processAHConflict == 0) {
              DateTime dtAH = DateTime.now();
              ScheduleList().adjustAHTime(dtAH);
            }

            var ahResult = ScheduleList().startPlayAHItem();
            if (ahResult.status) {
              if (loadCatalogue(ahResult.strDCMFile!)) {
                _bValidForPlay = true;
                playProduct(0, true);
              }
            }
          } else {
            var playResult = ScheduleList().returnPlayNormalItem();
            if (playResult.status) {
              if (loadCatalogue(playResult.strDCMFile!)) {
                ScheduleList().setLoadedState(true);
                _bValidForPlay = true;
                playProduct(ScheduleList().getPlayProduct(false), true);
              }
            }
          }
        } else if (_bIsTimeForPlayAH && !_bIsTimeForStopAH) {
          logD('Start playing Nomal Ad-hoc, Current TID: $pid.');
          ScheduleList().incrementContentListIndex(false);
          ScheduleList().saveState();

          if (AppGlobal.processAHConflict == 0) {
            DateTime dtAH = DateTime.now();
            ScheduleList().adjustAHTime(dtAH);
          }

          _bValidForPlay = false;
          var ahResult = ScheduleList().startPlayAHItem();
          if (ahResult.status) {
            if (loadCatalogue(ahResult.strDCMFile!)) {
              _bValidForPlay = true;
              playProduct(0, true);
            }
          }
        } else if (_bIsTimeForNextGroup) {
          logD('start playing next group, Current TID: $pid.');
          _bValidForPlay = false;
          var playResult = ScheduleList().playNextGroup();
          if (playResult.status) {
            if (loadCatalogue(playResult.strDCMFile!)) {
              _bValidForPlay = true;
              ScheduleList().setLoadedState(false);
              playProduct(0, true);
            }
          }
        } else if (_bIsTimeForRefresh) {
          logD('start refresh playlist, Current TID: $pid.');
          ScheduleList().incrementContentListIndex(bIsPlayingEpisode);
          ScheduleList().saveState();

          if (AppGlobal.processAHConflict == 0) {
            DateTime dtAH = DateTime.now();
            ScheduleList().adjustAHTime(dtAH);
          }

          _bValidForPlay = false;
          var playResult = ScheduleList().playFileList();
          if (playResult.status) {
            if (loadCatalogue(playResult.strDCMFile!)) {
              _bValidForPlay = true;
              ScheduleList().setLoadedState(true);
              playProduct(ScheduleList().getPlayProduct(), true);
            }
          }
        }
        logD(
            '''PlayerScreenProvider - ChangePlaylist before, Reload Schedule: $_bReloadSchedule; Time for Refresh: $_bIsTimeForRefresh; Time for Stop ad-hoc: $_bIsTimeForStopAH;
                      Time for Play ad-hoc: $_bIsTimeForPlayAH; Time for play next playlist: $_bIsTimeForNextPlaylist; time for play next group: $_bIsTimeForNextGroup; Current TID: $pid.''');
        _bReloadSchedule = false;
        _bIsTimeForRefresh = false;
        _bIsTimeForStopAH = false;
        _bIsTimeForPlayAH = false;
        _bIsTimeForNextPlaylist = false;
        _bIsTimeForNextGroup = false;
        logD(
            '''PlayerScreenProvider - ChangePlaylist After, Reload Schedule: $_bReloadSchedule; Time for Refresh: $_bIsTimeForRefresh; Time for Stop ad-hoc: $_bIsTimeForStopAH;
                      Time for Play ad-hoc: $_bIsTimeForPlayAH; Time for play next playlist: $_bIsTimeForNextPlaylist; time for play next group: $_bIsTimeForNextGroup; Current TID: $pid.''');
      } else {
        // Play next content in contentlist or replay zone content
        playNextContent();
      }
    } else {
      //Product finished
      logD(
          '''Catalogue:'$_strDCMFile'; Procduct '${ScheduleList().getPlayProduct()}' playback finished! Current TID: '$pid'.''');
      resetFirstFinished();
      if (_bPlayConti) {
        // Playlist playback
        logD('start play next product, Current TID: $pid!');
        if (ScheduleList().isDCMFilePlay() || isNormalCut()) {
          //Preview mode for DCMFile
          playNextProduct();
        } else {
          //other mode(Playlist mode)
          if (_bReloadSchedule) {
            if (!((ScheduleList().isAHPlaylist() && _bIsTimeForNextPlaylist) ||
                (!ScheduleList().isAHPlaylist() && _bIsTimeForStopAH))) {
              bool bIsAH = false;
              if (!_bIsTimeForPlayAH) {
                bIsAH = bIsPlayingEpisode;
              }
              ScheduleList().playNextProduct(bIsAH);
            }

            logD('start ReloadSchedule, Current TID: $pid.');
            reloadSchedule();
          } else if (_bIsTimeForNextPlaylist) {
            if (!ScheduleList().isAHPlaylist()) {
              if (!_bIsTimeForStopAH) {
                bool bIsAH = false;
                if (!_bIsTimeForPlayAH) {
                  bIsAH = bIsPlayingEpisode;
                }
                ScheduleList().playNextProduct(bIsAH);
              }
            }

            logD('start playing next playlist, Current TID: $pid.');
            playNextPlaylist();
          } else if (_bIsTimeForStopAH) {
            logD('stop playing Nomal Ad-hoc, Current TID: $pid.');
            _bValidForPlay = false;
            if (ScheduleList().isWaitForPlayAH()) {
              if (AppGlobal.processAHConflict == 0) {
                DateTime dtAH = DateTime.now();
                ScheduleList().adjustAHTime(dtAH);
              }

              var ahResult = ScheduleList().startPlayAHItem();
              if (ahResult.status) {
                if (loadCatalogue(ahResult.strDCMFile!)) {
                  _bValidForPlay = true;
                  playProduct(0, true);
                }
              }
            } else {
              var playResult = ScheduleList().returnPlayNormalItem();
              if (playResult.status) {
                if (loadCatalogue(playResult.strDCMFile!)) {
                  _bValidForPlay = true;
                  ScheduleList().setLoadedState(true);
                  playProduct(ScheduleList().getPlayProduct(false), true);
                }
              }
            }
          } else if (_bIsTimeForPlayAH && !_bIsTimeForStopAH) {
            logD('start playing Nomal Ad-hoc, Current TID: $pid.');
            ScheduleList().playNextProduct(false);
            ScheduleList().saveState(); //add by john 3/3

            if (AppGlobal.processAHConflict == 0) {
              DateTime dtAH = DateTime.now();
              ScheduleList().adjustAHTime(dtAH);
            }

            _bValidForPlay = false;
            var ahResult = ScheduleList().startPlayAHItem();
            if (ahResult.status) {
              if (loadCatalogue(ahResult.strDCMFile!)) {
                _bValidForPlay = true;
                playProduct(0, true);
              }
            }
          } else if (_bIsTimeForNextGroup) {
            logD('start playing next group, Current TID: $pid.');
            _bValidForPlay = false;
            var playResult = ScheduleList().playNextGroup();
            if (playResult.status) {
              if (loadCatalogue(playResult.strDCMFile!)) {
                _bValidForPlay = true;
                ScheduleList().setLoadedState(false);
                playProduct(0, true);
              }
            }
          } else if (_bIsTimeForRefresh) {
            logD('start Refresh playlist, Current TID: $pid.');
            ScheduleList().playNextProduct(bIsPlayingEpisode); //add by john 3/3
            ScheduleList().saveState(); //add by john 3/3

            if (AppGlobal.processAHConflict == 0) {
              DateTime dtAH = DateTime.now();
              ScheduleList().adjustAHTime(dtAH);
            }

            _bValidForPlay = false;
            var playResult = ScheduleList().playFileList();
            if (playResult.status) {
              if (loadCatalogue(playResult.strDCMFile!)) {
                _bValidForPlay = true;
                ScheduleList().setLoadedState(true);
                playProduct(ScheduleList().getPlayProduct(), true);
              }
            }
          } else {
            playNextProduct();
          }
        }

        logD(
            '''PlayerScreenProvider - ChangePlaylist before, Reload Schedule: $_bReloadSchedule; Time for Refresh: $_bIsTimeForRefresh; Time for Stop ad-hoc: $_bIsTimeForStopAH;
                      Time for Play ad-hoc: $_bIsTimeForPlayAH; Time for play next playlist: $_bIsTimeForNextPlaylist;
                      time for play next group: $_bIsTimeForNextGroup; Current TID: $pid.''');

        _bReloadSchedule = false;
        _bIsTimeForRefresh = false;
        _bIsTimeForStopAH = false;
        _bIsTimeForPlayAH = false;
        _bIsTimeForNextPlaylist = false;
        _bIsTimeForNextGroup = false;

        logD(
            '''PlayerScreenProvider - ChangePlaylist after, Reload Schedule: $_bReloadSchedule; Time for Refresh: $_bIsTimeForRefresh; Time for Stop ad-hoc: $_bIsTimeForStopAH;
                      Time for Play ad-hoc: $_bIsTimeForPlayAH; Time for play next playlist: $_bIsTimeForNextPlaylist;
                      time for play next group: $_bIsTimeForNextGroup; Current TID: $pid.''');
      } else {
        //touch screen click - play finish, return to playlist
        logD(
            'PlayerScreenProvider - ChangePlaylist after, _dwLatestUDP: ${_dwLatestUDP != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_dwLatestUDP!) : 'null'}; _nEventTimeout: ${AppGlobal.eventTimeout}.');
        if ((_dwLatestUDP == null && AppGlobal.eventTimeout == 0) ||
            (_dwLatestUDP != null ||
                (DateTime.now().difference(_dwLatestUDP!).inMilliseconds >
                    AppGlobal.eventTimeout * 1000))) {
          _bPlayConti = true;
          backToSchedule();
        } else {
          playNextProduct();
        }
      } //
    } // Product Finished
  }

  void hideAllZones() {
    for (var pThread in _playerZones) {
      pThread.setZoneFinish(false);
      pThread.setFirstFinished(false);
      /*pThread.canBeVisible(false);
      HWND hwnd = ((PlayerZoneImpl )pThread).GetPlayerHWnd();
      if (hwnd != null)
      {
        ::ShowWindow(hwnd, SW_HIDE);
      }*/
    }
  }

  void playProduct(int nIndex, [bool bStart = false]) {
    logD(
        'PlayerScreenProvider - PlayProduct - Play Product: $nIndex; TID $pid.');
    //ContentMgr.Cleanup();
    int nStatus = 0;
    //WriteMemoryLog(nStatus);
    if (nStatus == 1) {
      _nResetZoneThread = (_nResetZoneThread > 1 ? _nResetZoneThread : 1);
    } else if (nStatus == 2) {
      _bIsPause = true;
      return;
    }

    //logD(' PlayerScreenProvider - PlayProduct step 1 Play Product %d, TID $pid.', nIndex, GetCurrentThreadId());
    _nCurrProduct = nIndex;
    ScheduleList().setPlayProduct(nIndex);

    ProductData? pProductData = ScheduleList().getProductData(nIndex);
    ScheduleList().initPlaylistZone(pProductData);
    //logD(' PlayerScreenProvider - PlayProduct step 2 Play Product %d, TID $pid.', nIndex, GetCurrentThreadId());

    //logD('PlayerScreenProvider - PlayProduct Stop Timer Event %d!!!', GetCurrentThreadId());
    int nTotalZones = ScheduleList().getTotalZones();
    if (pProductData == null || nTotalZones < 1 || nTotalZones > 10000) {
      _bNeedPlayNextProduct = true;
      return;
    }

    if (!DCMFileImpl.isProductValidForPlay(
        pProductData, ScheduleList().getCurrCompany())) {
      _bNeedPlayNextProduct = true;
      return;
    }

    adjustPlayRect(pProductData);
    if (_nTotalZoneThread < 1) {
      _bNeedPlayNextProduct = true;
      return;
    }

    _bIsLoading = true;
    stopPlayingTimer();

    //::SetCursorPos(GetSystemMetrics(SM_CXSCREEN)+10000, GetSystemMetrics(SM_CYSCREEN)+10000);
    dcmShowCursor(false);

    int nTransparentZones =
        pProductData.getZoneCount(ZoneEffectType.contentAlpha);
    deleteMessageThread(cTRANSPARENTZONETYPE + nTransparentZones, true);
    //logD(' PlayerScreenProvider - PlayProduct step 3 Play Product %d, TID $pid.', nIndex, GetCurrentThreadId());

    //LockWindowUpdate();
    /*if (::IsWindow(_PlayerFrame.GetSafeHwnd()))
    {
      if (playSkin.getSkinType() != CXMLSkinSetting::HTML)
      {
        _PlayerFrame.SetPlayingProduct(nIndex);
      }
    }*/

    double rtDuration = Utils.getMaxDuration(pProductData);
    logI(
        '''Product Index: '$nIndex'; Start Time '$_dwFirstTime'; duration:'$rtDuration', TID '$pid'.''');
    int nZone = 0;
    bool bShowMessage = false;
    DateTime dwFirstTime0 = DateTime.now();
    _dwSecondTime = dwFirstTime0;
    PlayerZoneImpl? pThumbZoneThread;
    try {
      for (var pZoneThread in _playerZones) {
        nZone = pZoneThread.getZone();
        if (nZone < 0) {
          continue;
        }

        ZoneData? pData = pProductData.getZoneData(nZone);
        if (pData == null) {
          continue;
        }

        if (nZone == 0 &&
            pData.nZoneType != cTHUMBVIEWTYPE &&
            fLOBYTE(ScheduleList().getCatalogue().getBtnAlign()) ==
                ButtonPosition.eTHUMBVIEW.index) {
          pData.strZoneOfflineFile = pData.strZoneFile;
          pData.lFrequency = pData.nZoneType;
          pData.nZoneType = cTHUMBVIEWTYPE;
          pData.strZoneFile = '2';
          //pData.nZoneDuration = 10;
        }
        if (pData.nZoneType == cTHUMBVIEWTYPE) {
          pThumbZoneThread = pZoneThread;
        }
        //pZoneThread.SetParent(this.GetSafeHwnd());
        pZoneThread.setStartTime(_dwFirstTime);
        pZoneThread.setContentType(pData.nZoneType);
        if (pZoneThread.initResetFlag(
            pData.nZoneType, pData.strZoneFile, playSkin.getZoneRect(nZone))) {
          pZoneThread.showZoneWnd(false);
        }

        int nStart = 0;
        if (ScheduleList().getContentListIndex(nZone, nStart)) {
          //
          pZoneThread.setPlayStart(nStart);
        }

        if (bStart) {
          pZoneThread
              .play(); //(!_bDBClickClose && pData.nZoneType == THUMBVIEW_TYPE) ? 3 : 0
        } else {
          if (!pData.bChkZone) {
            pZoneThread
                .play(); //(!_bDBClickClose && pData.nZoneType == THUMBVIEW_TYPE) ? 3 : 0
          } else {
            if (pZoneThread.isPlaying()) {
              if (pZoneThread.isZoneFinish()) {
                pZoneThread.setZoneFinish(false);
                pZoneThread.rePlay();
              }
            } else {
              pZoneThread
                  .play(); //(!_bDBClickClose && pData.nZoneType == THUMBVIEW_TYPE) ? 3 : 0
            }
          }
        }
        //Sleep(100);
        //pZoneThread.SetThreadPriority(THREAD_PRIORITY_NORMAL);
        //pZoneThread.SetPlayingLine(_rtDuration, !pData.bChkZone);
        pZoneThread.setPlayingLine(pData.nZoneDuration, !pData.bChkZone);
        bShowMessage = (bShowMessage || pZoneThread.isShowMessage());
      }
    } catch (e) {
      logD(
          'PlayerScreenProvider - PlayProduct Play product 0 error, TID $pid, error: $e');
    }
    ScheduleList().setShowMessage(bShowMessage);

    //logD('PlayerScreenProvider - PlayProduct WaitWithMessageLoop: '%d', %s; TID: '%d'!', bWaitOK, DCMMisc::GetErrorString(), GetCurrentThreadId());

    _dwFirstTime =
        _dwFirstTime.add(Duration(milliseconds: (rtDuration * 1000).toInt()));
    //UnlockWindowUpdate();

    try {
      changePlayerRgn();
      //matchTransparentThread(pProductData);
      ScheduleList().saveState();
      //deleteMZThread();
    } catch (e) {
      logD(
          'PlayerScreenProvider - PlayProduct Play product 1 error, TID $pid, error: $e');
    }

    //Sleep(200);
    dcmShowCursor();

    for (var pZoneThread in _playerZones) {
      if (pZoneThread.getZone() > -1) {
        pZoneThread.showZoneWnd(true);
        pZoneThread.setStartPlayTime(dwFirstTime0);
      }
    }

    if (pThumbZoneThread != null &&
        playSkin.highlightFocusBtn &&
        playSkin.dcmFile.isEmpty &&
        !_bDBClickClose) {
      //::PostMessage(pThumbZoneThread.GetPlayerHWnd(), WM_INFORM_PLAY, 2, 0);
    }

    //ListWindowInfo();
    _needNotifyListeners = false;
    notifyListeners();

    startPlayingTimer();
    //logD('PlayerScreenProvider - PlayProduct Restart Timer Event $pid.');

    _bIsLoading = false;
    /*gShowHideTaskBar(true);
    if (playSkin._bHideCursor)
      SendMouseEvent(GetSystemMetrics(SM_CXSCREEN)+10000, GetSystemMetrics(SM_CYSCREEN)+10000);*/
  }

  int initZoneThread() {
    int nZone = 0;
    ProductData? pProductData =
        ScheduleList().getProductData(ScheduleList().getPlayProduct());
    if (pProductData != null) {
      nZone = pProductData.lstZone.length;
      for (var pData in pProductData.lstZone) {
        PlayerZoneImpl? pThread = getZoneThread(pData.nZoneID);
        pThread ??= getZoneThread(-1);
        if (pThread != null) {
          pThread.setZoneData(pData);
          pThread.setZone(pData.nZoneID);
          pThread.setContentType(pData.nZoneType);
          pThread.setWindowRect(playSkin.getZoneRect(pData.nZoneID));
        } else {
          pThread = _createZoneThread(pData);
        }
        pThread.initZone();
      }

      /*for(var pThread in _playerZones) {
        if ( pThread.getZone()+ 1 > nZone) {
          if (::IsWindow(hwnd))
          {
            //::SendMessageTimeout(hwnd, WM_INFORM_STOP, 1, 0, SMTO_BLOCK, 10000, 0);
            ::PostMessage(hwnd, WM_INFORM_STOP, 1, 0);
            ::ShowWindow(hwnd, SW_HIDE);
          }
          pThread.setZone(-1);
        } else {
          ::ShowWindow(hwnd, SW_SHOW);
        }
      }*/
    }

    return nZone;
  }

  PlayerZoneImpl? getZoneThread(int nZone, [int nEffect = -1]) {
    PlayerZoneImpl? pThread;
    for (var pThread1 in _playerZones) {
      if (pThread1.getZone() == nZone) {
        pThread = pThread1;
        break;
      }
    }

    if (pThread == null && nEffect > 0) {
      for (var pThread1 in _playerZones) {
        if (pThread1.getZone() < 0 && pThread1.getEffect() == nEffect) {
          pThread = pThread1;
          break;
        }
      }
    }

    return pThread;
  }

  bool isZoneIDInProduct(int nZone) {
    ProductData? pProductData =
        ScheduleList().getProductData(ScheduleList().getPlayProduct());
    if (pProductData != null) {
      for (var pData in pProductData.lstZone) {
        if (pData.nZoneID == nZone) {
          return true;
        }
      }
    }
    return false;
  }

  //#define DCMMATCHZONETHREAD
  void matchZoneThread(int nTotalZone) {
    if (nTotalZone <= 0 || nTotalZone > 10000) {
      return;
    }

    logI('Match Thread Count step 0, TID $pid.');
    resetZoneRect(nTotalZone);
    deleteZoneThread(nTotalZone);

    logI('Match Thread Count step 1, TID $pid.');
    logI('Match Thread Count step 2, TID $pid.');
    initZoneThread();
    logI('Match Thread Count step 3, TID $pid.');
  }

  void matchZoneThreadByProduct(ProductData pProductData) {
    int i = 0;
    while (i < _playerZones.length) {
      PlayerZoneImpl pThread = _playerZones.elementAt(i);

      ZoneData? pData = pProductData.getZoneData(pThread.getZone());
      if (pData != null) {
        if (pThread.getEffect() != pData.getZoneEffect()) {
          pThread.setZone(-1);
        }
      } else {
        pThread.setZone(-1);
      }
      i++;
    }

    for (var pData in pProductData.lstZone) {
      int nEffect = pData.getZoneEffect();
      playSkin.updateZoneEffect(pData.nZoneID, nEffect);
      if (nEffect == ZoneEffectType.noEffect.value) {
        PlayerZoneImpl? pThread = getZoneThread(pData.nZoneID);
        pThread ??= _createZoneThreadByZoneData(pData);
        if (pThread != null) {
          pThread.setZone(pData.nZoneID);
          pThread.setContentType(pData.nZoneType);
          pThread.setWindowRect(playSkin.getZoneRect(pData.nZoneID));
          pThread.setZoneData(pData);
          pThread.initZone();
        }
      }
    }

    _nTotalZoneThread = pProductData.getZoneCount();
    int nZone = _nTotalZoneThread;
    if (nZone < AppGlobal.maxZoneThread) {
      nZone = AppGlobal.maxZoneThread;
    }

    i = 0;
    while (_playerZones.length > nZone) {
      if (i == _playerZones.length) {
        break;
      }

      PlayerZoneImpl pThread = _playerZones.elementAt(i);
      if (pThread.getZone() < 0) {
        _playerZones.removeAt(i);
      } else {
        i++;
      }
    }

    for (var pThread in _playerZones) {
      /*if ( pThread.getZone() < 0) {
        if (::IsWindow(hwnd))
        {
          ::PostMessage(hwnd, WM_INFORM_STOP, 1, 0);
          ::ShowWindow(hwnd, SW_HIDE);
        }
      }
      else
      {
        ::ShowWindow(hwnd, SW_SHOW);
      }*/
    }
  }

  void deleteZoneThread(int nZone) {
    // release all zone thead
    if (nZone == 0) {
      _playerZones.clear();

      return;
    }

    // out of memory
    if (_nResetZoneThread == 1) {
      _nResetZoneThread = 0;
      _playerZones.clear();

      return;
    }

    if (nZone == _playerZones.length) {
      return;
    }

    if (nZone < AppGlobal.maxZoneThread) {
      nZone = AppGlobal.maxZoneThread;
    }

    int i = 0;
    while (_playerZones.length > nZone) {
      if (i == _playerZones.length) {
        break;
      }

      PlayerZoneImpl pThread = _playerZones.elementAt(i);
      if (pThread.getZone() + 1 > nZone) {
        _playerZones.removeAt(i);
      } else {
        i++;
      }
    }
    logI('Zone Thread Count ${_playerZones.length}, TID $pid.');
  }

  PlayerZoneImpl? _createZoneThreadByZoneData(ZoneData pZoneData) {
    if (pZoneData.nZoneEffectType > ZoneEffectType.noEffect.value) {
      if (pZoneData.nZoneEffectType == ZoneEffectType.contentAlpha.value) {
        PlayerZoneImpl pZoneThread = PlayerZoneImpl();
        // Start the interface thread.
        pZoneThread.setZoneData(pZoneData);
        pZoneThread.setZone(pZoneData.nZoneID);
        pZoneThread.setContentType(pZoneData.nZoneType);
        pZoneThread.setWindowRect(playSkin.getZoneRect(pZoneData.nZoneID));
        //pZoneThread.initZone();
        _playerZones.add(pZoneThread);

        logI(
            '_createZoneThreadByZoneData: Create Thread for zone: ${pZoneData.nZoneID}, Zone count ${_playerZones.length}.');
        return pZoneThread;
      }
      return null;
    } else {
      return _createZoneThread(pZoneData);
    }
  }

  PlayerZoneImpl _createZoneThread(ZoneData pZoneData) {
    PlayerZoneImpl pZoneThread = PlayerZoneImpl();
    pZoneThread.setZoneData(pZoneData);
    pZoneThread.setZone(pZoneData.nZoneID);
    pZoneThread.setContentType(pZoneData.nZoneType);
    pZoneThread.setWindowRect(playSkin.getZoneRect(pZoneData.nZoneID));
    //pZoneThread.initZone();

    _playerZones.add(pZoneThread);

    logI(
        '_createZoneThread: Create Thread for zone: ${pZoneData.nZoneID}, Zone count ${_playerZones.length}.');

    return pZoneThread;
  }

  void dcmShowCursor([bool bShow = true]) {
    /*if (_pHookMgr != null && !playSkin._bHideCursor) {
      _pHookMgr.IdleTrackerHideCursor(bShow ? false : true);
    }*/
  }

  bool hasPDFContents() {
    for (var pZoneThread in _playerZones) {
      if (pZoneThread.getZone() > -1) {
        if (pZoneThread.hasContent(cPDFTYPE)) {
          return true;
        }
      }
    }

    /*for (nZone=0; nZone<_arrLineThread.length; nZone++)
    {
      PlayerZone pZoneThread = (PlayerZone )_arrLineThread[nZone];
      if (pZoneThread != null && pZoneThread.GetZone() > -1)
      {
        if (pZoneThread.hasContent(PDF_TYPE))
        {
          return true;
        }
      }
    }*/

    return false;
  }

  void playNextContent() {
    for (var pThread0 in _playerZones) {
      if (pThread0.isZoneFinish()) {
        pThread0.setZoneFinish(false);
        pThread0.setContentFinished(false);
        //::PostMessage(pThread0.GetPlayerHWnd(), WM_INFORM_REPLAY, 0, 0);
        logD(
            'PlayerScreenProvider - playNextContent, Zone: ${pThread0.getZone()} play finished, try to replay, Current TID $pid.');
        pThread0.rePlay();
        //notifyListeners();
      } else {
        if (pThread0.isContentFinished()) {
          pThread0.setContentFinished(false);
          logD(
              '''PlayerScreenProvider - playNextContent, Zone: ${pThread0.getZone()} contentlist's content play finished, try to playNextContentListItem, Current TID $pid.''');
          //::PostMessage(pThread0.GetPlayerHWnd(), WM_PLAYNEXT_CONTENTLIST, (WPARAM)CONTENT_FINISH, 0);
          pThread0.playNextContentListItem(PlayFinish.eCONTENTFINISH);
          //notifyListeners();
          _needNotifyListeners = true;
        }
      }
    }
  }

  void playNextProduct() {
    if (!hasFlag(AppGlobal.playMode, 2) &&
        ScheduleList().count == 0 &&
        !ScheduleList().catalogue.canPlay()) {
      startPlayingTimer();
      return;
    }

    bool bHasPowerPoint =
        ScheduleList().hasPowerPoint(ScheduleList().getPlayProduct());
    logD(
        'PlayerScreenProvider - PlayNextProduct, bHasPowerPoint:$bHasPowerPoint, Current TID $pid.');

    try {
      if (ScheduleList().reachLastProduct()) {
        if (!_bIsPushFile) {
          if (_btnEvent == 0) {
            _nCurrProduct = 0;
            ScheduleList().setProductIndex(0);
          }
        } else {
          _nCurrProduct = _nPushBtn;
          ScheduleList().setProductIndex(_nPushBtn);
          _bIsPushFile = false;
        }
        //logD('PlayerScreenProvider - PlayNextProduct step:%d, Current TID $pid.', 3, GetCurrentThreadId());

        if (!ScheduleList().isDCMFilePlay() && _btnEvent == 0) {
          //not Preview catalogue or event
          if (ScheduleList().hasContentType()) {
            sendSerialMSG('1!\r\n');
          }

          //logD('PlayerScreenProvider - PlayNextProduct step:%d, Current TID $pid.', 4, GetCurrentThreadId());
          if (ScheduleList().count > 1) {
            // multi playlist
            //12/03/2001 John Lee
            //if (ScheduleList().getPlayTimes())// not reach playlist item play times
            {
              var playNextResult = ScheduleList().playNextFile();
              if (playNextResult.status) {
                if (!playNextResult.strDCMFile!.equalsIgnoreCase(_strDCMFile)) {
                  //logD('PlayerScreenProvider - PlayNextProduct step:%d, Current TID $pid.', 51, GetCurrentThreadId());
                  if (!loadCatalogue(playNextResult.strDCMFile!)) {
                    logD(
                        'load DCM file: ${playNextResult.strDCMFile} error; Current TID $pid.');
                    //StopNotQuit();
                    //_bValidForPlay = false;
                    _bNeedPlayNextProduct = true;

                    //StartTimer(PLAYING_TIMER, PLAYING_DURATION);
                    return;
                  }
                } else {
                  _nCurrProduct = 0;
                  ScheduleList().setProductIndex(0);
                }
              }
            }
            //logD('PlayerScreenProvider - PlayNextProduct step:%d, Current Thread ID %d!!!', 52, GetCurrentThreadId());
            /*else
            {
              ScheduleList().SetPlayTimes();
            }*/ //12/03/2001 John lee
            logD('play DCM file: $_strDCMFile; Current TID $pid.');
          } else {
            //Single Playlist play
            String strDCMFile = ScheduleList().getPlayFile();
            if (!strDCMFile.equalsIgnoreCase(_strDCMFile)) {
              //logD('PlayerScreenProvider - PlayNextProduct step:%d, Current TID $pid.', 53, GetCurrentThreadId());
              if (!loadCatalogue(strDCMFile)) {
                logD('load DCM file: $strDCMFile error; Current TID $pid.');
                _bNeedPlayNextProduct = true;
                //StopNotQuit();
                //_bValidForPlay = false;
                //StartTimer(PLAYING_TIMER, PLAYING_DURATION);

                return;
              }
            } else {
              _nCurrProduct = 0;
              ScheduleList().setProductIndex(0);
            }
            //logD('PlayerScreenProvider - PlayNextProduct step:%d, Current TID $pid.', 6, GetCurrentThreadId());
          }
        }
      } else {
        //not reach last product, play next product
        if (_btnEvent == 0) {
          if (!_bIsPushFile) {
            _nCurrProduct++;
            ScheduleList().setProductIndex();
          } else {
            _nCurrProduct = _nPushBtn;
            ScheduleList().setProductIndex(_nPushBtn);
            _bIsPushFile = false;
          }
        }
      }

      /*if (bHasPowerPoint && !Misc::HasFlag(Settings.multiMonitor, MULTI_MONITOR_DV))//((Settings.powerPoint & PP_VIEW_2003) || (Settings.powerPoint & PP_OFFICE)))
      {
        //CSingleLock pLock( &_ZoneThreadLock, true );
        for (int i=0; i<_playerZones.length; i++)
        {
          PlayerZone pThread = (PlayerZone )_playerZones[i];
          if (pThread != null && pThread.GetZone() > -1)
          {
            ::SendMessageTimeout(pThread.GetPlayerHWnd(), WM_INFORM_PAUSE, 0, 0, SMTO_BLOCK, 10000, 0);
          }
        }
      }*/

      //int nCurrProduct = ScheduleList().GetPlayProduct();
      logD(
          '''PlayerScreenProvider - PlayNextProduct finished; Catalogue:'$_strDCMFile'; start Play Product:'$_nCurrProduct' Current TID '$pid'.''');
      playProduct(_nCurrProduct);
    } catch (e) {
      logD(
          'PlayerScreenProvider - PlayNextProduct error: $e; Current TID $pid.');
    }

    //StartTimer(PLAYING_TIMER, PLAYING_DURATION);
  }

  void reloadSchedule([bool bIsProductFinish = true]) {
    if (_btnEvent > 0) {
      //BackToSchedule();
      _isNeedBackToSchedule = 1;
      return;
    }

    logD('Try to reload playlist; Current TID: $pid.');
    stopPlayingTimer();
    try {
      ScheduleList().saveState();

      stopNotQuit();

      _bIsPause = false;
      resetFirstFinished();
      //RecycleInstance.RemoveAllRecycleObj();
      _dwFirstTime = DateTime.now();
      {
        logD('Recieve FTP Download message; Current TID: $pid');
        ScheduleList().resetStartDateTime();
        if (!(_bDisplayChanged &&
            ScheduleList().currEvent.equalsIgnoreCase('StartupWallpaper'))) {
          ScheduleList().currEvent = '';
        }
        ScheduleList().loadSchedule(displayChanged: _bDisplayChanged);
        ScheduleList().integrityCheck(true);

        logD('reload Schedule; Current TID: $pid.');
        //_bIsPlaying = true;
        _readyForPlay();
        if (_bValidForPlay) {
          ScheduleList().writePlaylistLog();
          //PlayProduct(ScheduleList().getPlayProduct(), true);
        }
      }
    } catch (e) {
      logE('reloadSchedule error: $e');
    }
    startPlayingTimer();
    //_bIsPause = false;
  }

  void playNextPlaylist() {
    ScheduleList().saveState();

    //StopNotQuit();
    //stopPlayingTimer();
    resetFirstFinished();

    _bIsPause = false;
    //COleDateTime dtCurr = COleDateTime::getCurrentTime();
    var playResult = ScheduleList().playNextPlaylist();
    if (playResult.status) {
      //if (!ScheduleList().IsAHPlaylist())
      ScheduleList().writePlaylistLog();
      if (loadCatalogue(playResult.strDCMFile!)) {
        _bValidForPlay = true;
        //_nCurrProduct = 0;
        if (ScheduleList().isAHPlaylist()) {
          playProduct(0, true);
        } else {
          ScheduleList().setLoadedState(true);
          playProduct(ScheduleList().getPlayProduct(), true);
        }

        _bIsPlaying = true;
      }
    }
    //startPlayingTimer();
  }

  void backToSchedule() {
    var needBackToSchedule = _needBackToSchedule;
    _needBackToSchedule = 0;
    if (needBackToSchedule == 2) {
      ScheduleList().messageList.stopAll();
      deleteMessageThreadByOutput(cINTMIN);
      //ResumePlaylist();
      if (_strSerialCommand.isNotEmpty) {
        logD('Sending serial control command:\'$_strSerialCommand\'');
        sendSerialMSG('$_strSerialCommand\r\n');
      }
    } else {
      _bDBClickClose = false;
      deleteMessageThread(cPOPUPWINDOWTYPE);

      _bPlayConti = true;
      _btnEvent = 0;
      ScheduleList().loadSchedule();
      //ScheduleList().LoadState();
      _readyForPlay();
      playProduct(ScheduleList().getPlayProduct());
    }
  }

  bool needBackToSchedule() {
    if (_needBackToSchedule > 0) {
      _needBackToSchedule = 0;
      _bDBClickClose = false;
      deleteMessageThread(cPOPUPWINDOWTYPE);
      _bPlayConti = true;
      _btnEvent = 0;
      ScheduleList().loadSchedule();
      ScheduleList().loadState();
      playNextProduct();

      return true;
    }

    return false;
  }

  void changePlayerRgn() {
    /*for (int i=0; i<_playerZones.length; i++)
    {
      PlayerZone pThread = (PlayerZone )_playerZones[i];
      if (pThread != null && pThread.GetZone() > -1)
      {
        ::SendMessageTimeout(pThread.GetPlayerHWnd(), WM_MAKE_HOLE, 0, 0, SMTO_BLOCK, 10000, 0);
        ::InvalidateRect(pThread.GetPlayerHWnd(), null, true);
      }
    }
    for (int i=0; i<_arrLineThread.length; i++)
    {
      if (((PlayerZone )_arrLineThread.GetAt(i))->GetZone() > TRANSPARENTZONE_TYPE - 1)
      {
        PlayerZoneImpl pMessageThread = (PlayerZoneImpl )_arrLineThread.GetAt(i);
        if (pMessageThread != null)
        {
          pMessageThread->MakeHole();
        }
      }
    }*/
  }

  void loadMessageThread([int nOutput = -1]) {
    /*if (nOutput != cINTMIN) {
      CAHThread *pMessageThread = (CAHThread *)GetMessageThread(CAHPlayList::GetMessageId(nOutput));
      LoadMessageThread(pMessageThread);
    }
    else
    {
      for (int i=0; i<_arrLineThread.length; i++)
      {
        if (CAHPlayList::IsAHMessage(((PlayerZone )_arrLineThread.GetAt(i))->GetZone()))
        {
          LoadMessageThread((CAHThread *)_arrLineThread.GetAt(i));
        }
      }
    }*/
  }

  /*void loadMessageThread(CAHThread *pMessageThread)
  {
    if (pMessageThread != null)
    {
      int nOutput = CAHPlayList::GetOutput(pMessageThread->GetZone());
      //logI('PlayerScreenProvider - LoadMessageThread: %d', GetCurrentThreadId());
      int nLayout = ScheduleList()._MessageList.GetMessageLayout(nOutput);
      if (nLayout != AH_BOTTOM_MZ)
      {
        ::SendMessageTimeout(pMessageThread->GetPlayerHWnd(), WM_INFORM_STOP, 1, 0, SMTO_BLOCK, 10000, 0);

        CString strCompany = ScheduleList().GetCurrCompany();
        pMessageThread->SetCompany(strCompany);
        //pMessageThread->SetZoneData(ScheduleList()._MessageList.GetZoneData());
        pMessageThread->SetProductData(ScheduleList()._MessageList.GetProductData(nOutput));
      }
      
      ChangeMessageRect(nOutput);
      ChangeMessageRgn(nOutput);
      ReCalcPlayerRect(nOutput);
      ReCalcZoneRect();
      ChangePlayerRgn();
      ChangeFrameRgn();

      if (nLayout != AH_BOTTOM_MZ)
      {
        ::SendMessageTimeout(pMessageThread->GetPlayerHWnd(), WM_INFORM_PLAY, 0, 0, SMTO_BLOCK, 10000, 0);
      }
    }
  }

  PlayerZone getMessageThread(int nZone)
  {
    for (int i=0; i<_arrLineThread.length; i++)
    {
      if (((PlayerZone )_arrLineThread.GetAt(i))->GetZone() == nZone)
      {
        return (PlayerZone )_arrLineThread.GetAt(i);
      }
    }
    return null;
  }*/

  void createMessageThread(int nOutput) {
    /*int nZone = CAHPlayList::GetMessageId(nOutput);
    DeleteMessageThread(nZone);

    CAHThread *pMessageThread = new CAHThread(this->GetSafeHwnd());
    _arrLineThread.Add(pMessageThread);
    pMessageThread->_bAutoDelete = false;	// Disable auto deletion of thread object upon thread termination.

    pMessageThread->SetPlayType(4);
    pMessageThread->SetZone(nZone);
    pMessageThread->SetOutput(nOutput);
    CString strCompany = ScheduleList().GetCurrCompany();
    pMessageThread->SetCompany(strCompany);
    //_pMessageThread->SetProductData(_pProductData);
    if (CAHPlayList::IsAHMessage(nZone))
    { 
      /*HWND hPrev = null;
      HWND hNext = null;
      GetHWnd(nOutput, hPrev, hNext);*/
      ProductData pProductData = ScheduleList()._MessageList.GetProductData(nOutput);
      if (pProductData != null)
      {
        //pMessageThread->SetZoneData(ScheduleList()._MessageList.GetZoneData());
        pMessageThread->SetProductData(pProductData);
        pMessageThread->SetID(IDC_ZONE_WND + nZone);
        //pMessageThread->SetPrevHwnd(hPrev);
        //pMessageThread->SetNextHwnd(hNext);

        CRect rcAH = ScheduleList()._MessageList.GetMessageRect(nOutput);
        int nLayout = ScheduleList()._MessageList.GetMessageLayout(nOutput);
        int nMessageZone = ScheduleList()._MessageList.GetMessageZone(nOutput);
        PlaySkin.SetAHMessageRect(ScheduleList().GetProductData(ScheduleList().GetPlayProduct()), nLayout, nMessageZone,
          ScheduleList()._MessageList.GetMessageZoneType(nOutput), rcAH, nOutput);
        PlaySkin.SetMessageTransparency(ScheduleList()._MessageList.IsTransparency(nOutput));

        rcAH = PlaySkin.GetAHMessageRect(nOutput);
        pMessageThread->SetWindowRect(rcAH);

        ReCalcPlayerRect(nOutput);
        ReCalcZoneRect();
        ChangePlayerRgn();
        ChangeFrameRgn();

        if (nLayout == AH_REPLACEZONE)
        {
          PlayerZone pZoneThread = GetZoneThread(nZone);
          if (pZoneThread != null)
          {
            pZoneThread.WantStop();
            ::SendMessageTimeout(pZoneThread.GetPlayerHWnd(), WM_INFORM_STOP, 1, 0, SMTO_BLOCK, 10000, 0);
          }
        }

        // Start the interface thread.
        pMessageThread->CreateThread();
        Delay(500);
        //pMessageThread->SetParent(this->GetSafeHwnd());
      }
    }
    else
    {
      pMessageThread->SetWindowRect(PlaySkin.GetZoneRect(nZone));
      // Start the interface thread.
      if (!pMessageThread->CreateThread(CREATE_SUSPENDED))
          {
        delete pMessageThread;
        return;
          }
      Delay(500);
      VERIFY(pMessageThread->SetThreadPriority(THREAD_PRIORITY_NORMAL));
      //pMessageThread->SetParent(this->GetSafeHwnd());
      pMessageThread->ResumeThread();
    }*/
  }

  void deleteMessageThreadByOutput([int nOutput = -1]) {
    /*if (nOutput == cINTMIN) {
      int i=0;
      while (i<_arrLineThread.length)
      {
        if (CAHPlayList::IsAHMessage(((PlayerZone )_arrLineThread.GetAt(i))->GetZone()))
        {
          logI('PlayerScreenProvider - DeleteMessageThreadByOutput - Found Message Thread '%d', TID %d.', ((PlayerZone )_arrLineThread.GetAt(i))->GetZone(), GetCurrentThreadId());
          DeleteMessageThread(((PlayerZone )_arrLineThread.GetAt(i))->GetZone());
        }
        else
        {
          i++;
        }
      }
    }
    else
    {
      logI('PlayerScreenProvider - DeleteMessageThreadByOutput - Found Message Thread '%d', Output: '%d'; TID %d.', CAHPlayList::GetMessageId(nOutput), nOutput, GetCurrentThreadId());
      DeleteMessageThread(CAHPlayList::GetMessageId(nOutput));
    }*/
  }

  void deleteMessageThreadByLayer(int nLayer) {
    /*int i=0;
    while (i<_arrLineThread.length)
    {
      if (CAHPlayList::IsAHMessage(((PlayerZone )_arrLineThread.GetAt(i))->GetZone())
        && nLayer == CAHPlayList::GetLayer(((PlayerZone )_arrLineThread.GetAt(i))->GetZone()))
      {
        logI('PlayerScreenProvider - DeleteMessageThreadByLayer - Found Message Thread '%d', TID %d.', ((PlayerZone )_arrLineThread.GetAt(i))->GetZone(), GetCurrentThreadId());
        DeleteMessageThread(((PlayerZone )_arrLineThread.GetAt(i))->GetZone());
      }
      else
      {
        i++;
      }
    }*/
  }

  void deleteMessageThread(int nZone, [bool bGroup = false]) {
    /*if (nZone < 0) {
      while (_arrLineThread.length > 0)
      {
        PlayerZone pMessageThread = (PlayerZone )_arrLineThread.GetAt(0);
        if (pMessageThread != null)
        {
          pMessageThread->SetThreadPriority(THREAD_PRIORITY_ABOVE_NORMAL);
          if (pMessageThread->IsRunning())
          {
            pMessageThread->Kill();
          }

          if (::WaitForSingleObject(pMessageThread->_hThread, 5000) == WAIT_TIMEOUT)
          {
            ::TerminateThread(pMessageThread->_hThread, 0);
          }

          SAFE_DELETE(pMessageThread);
          _arrLineThread.RemoveAt(0);
        }
      }
      return;
    }

    bool bKilled =false;
    if (!bGroup){
      for (int i=0; i<_arrLineThread.length; i++)
      {
        if (((PlayerZone )_arrLineThread.GetAt(i))->GetZone() == nZone)
        {
          PlayerZone pMessageThread = (PlayerZone )_arrLineThread.GetAt(i);
          _arrLineThread.RemoveAt(i);
          if (pMessageThread != null)
          {
            RecycleThread(1, pMessageThread);
          }
          bKilled =true;
          break;
        }
      }
    } else { 
      int i = 0;
      while(i < _arrLineThread.length)
      {
        PlayerZone pMessageThread = (PlayerZone )_arrLineThread.GetAt(i);
        if (pMessageThread != null && pMessageThread->GetZone() + 1 > nZone)
        {
          _arrLineThread.RemoveAt(i);
          RecycleThread(1, pMessageThread);
          bKilled =true;
        }
        else
        {
          i++;
        }
      }
    }

    if (bKilled && AHScheduleList().isAHMessage(nZone)) {
      int nOutput = AHScheduleList().getOutput(nZone);
      logI('''PlayerScreenProvider - DeleteMessageThread refresh window nOutput '$nOutput'''');
      //PlaySkin.RemoveAHMessageRect(nOutput);
      changeMessageRect(nOutput);
      changeMessageRgn(nOutput);
      reCalcPlayerRect(nOutput);
      reCalcZoneRect();
      changePlayerRgn();
      changeFrameRgn();

      for (int i=0; i<_playerZones.length; i++)
      {
        PlayerZone pThread = (PlayerZone )_playerZones[i];
        if (pThread != null && pThread.GetZone() > -1) {
          ::ShowWindow(pThread.GetPlayerHWnd(), SW_HIDE);
          ::ShowWindow(pThread.GetPlayerHWnd(), SW_SHOW);
        }
      }
    }*/
  }

  void waitForPlay() {
    DateTime dtStartTime = DateTime.now();
    String strPlayerList = 'AHWait';
    if (ScheduleList().messageList.addAHMessage(
            message: strPlayerList,
            startTime: dtStartTime,
            endTime: dtStartTime,
            createTime: dtStartTime,
            level: 0,
            endManual: true) >
        0) {
      /*ChangeMessageRect();
      ChangePlayerRgn();
      ChangeFrameRgn();*/
    }
    _bIsPause = true;
    stopNotQuit();
  }

  void stopAll() {
    if (_bIsPlaying) {
      stopTimer();
      stopPlayingTimer();
      //stopPlay();
      _bIsPlaying = false;
      //_bIsFrame = false;
    }
    /*if (!_bClosing)
      Invalidate();*/
  }

  void stopNotQuit() {
    if (_bIsPlaying) {
      resetMusicPlayer();
      //stopPlayer();
      _bIsPlaying = false;

      ///	_bIsFrame = false;
    }

    /*Invalidate();
    if (::IsWindow(_PlayerFrame.GetSafeHwnd())) {
      _PlayerFrame.ShowWindow(SW_HIDE);
    }*/
  }

  void release() {
    stopTimer();
    stopPlayingTimer();
    resetMusicPlayer();
    deleteZoneThread(0);
    deleteMessageThreadByOutput(cINTMIN);
  }

  void videoStatusControl(int nVideoStatus) {}

  void tvChannelControl(int nNewChannel) {}

  bool isValidForPlay() => _bValidForPlay;

  bool isNormalCut() {
    return (AppGlobal.playListCut == 0 || AppGlobal.playListCut == 2);
  }

  bool isTimeToCut() {
    return (AppGlobal.playListCut == 1);
  }

  bool isDurationCut() {
    return (AppGlobal.playListCut == 2);
  }

  void _readyForPlay() {
    bool bCanPlay = loadPlayerState();
    if (!bCanPlay) {
      var playResult = ScheduleList().playFileList();
      if (playResult.status) {
        _strDCMFile = playResult.strDCMFile;
        if (loadCatalogue(_strDCMFile!, true)) {
          bCanPlay = ScheduleList().isCatalogueCanPlay();
        }

        if (!bCanPlay) {
          if (ScheduleList().count > 1) {
            while (true) {
              var playNextResult = ScheduleList().playNextFile();
              if (playNextResult.status) {
                //if (ScheduleList().LoadCatalogue(strDCMFile))
                if (loadCatalogue(playNextResult.strDCMFile!, true)) {
                  if (ScheduleList().isCatalogueCanPlay()) {
                    bCanPlay = true;
                    _strDCMFile = playNextResult.strDCMFile!;
                    break;
                  }
                }
              }

              if (!bCanPlay) {
                sleep(const Duration(seconds: 1));
              }
            }
          }
        }
        ScheduleList().setPlayTimes();
      }
    }
    _bValidForPlay = bCanPlay;
  }

  bool loadPlayerState() {
    if (AppGlobal.playStartPoint != 0) {
      if (ScheduleList().loadState()) {
        var playResult = ScheduleList().playCurrFile();
        if (playResult.status) {
          _strDCMFile = playResult.strDCMFile;
          if (loadCatalogue(playResult.strDCMFile!)) {
            if (ScheduleList().isCatalogueCanPlay()) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  bool loadCatalogue(String strDCMFile, [bool bStart = false]) {
    String strOldLayout = '';
    String strCurrSkin = '';
    int nOldScreen = 0;
    int nTotalZone1 = 0;
    if (!bStart) {
      strCurrSkin = ScheduleList().getCatalogue().strSkinCode;
      strOldLayout = ScheduleList().getCatalogue().strLayoutName;
      nOldScreen = ScheduleList().getCatalogue().nScreenType;
      nTotalZone1 = ScheduleList().getTotalZones();
    }

    if (ScheduleList().loadCatalogue(strDCMFile)) {
      int nTotalZone = ScheduleList().getTotalZones();
      if (nTotalZone <= 0 || nTotalZone > 10000) {
        return false;
      }

      if (ScheduleList().hasContentType()) {
        sendSerialMSG('2!\r\n');
      }
      _bIsSameSkin =
          (strCurrSkin == ScheduleList().getCatalogue().strSkinCode &&
              !_bDisplayChanged);
      String strOldTouch = playSkin.dcmFile;
      if (!_bIsSameSkin) {
        playSkin.loadFromCatalogue(ScheduleList().getCatalogue());
      }

      //logD('PlayerScreenProvider - LoadCatalogue Step: %d, DCMFile:'%s'; last Zone Number:'%d'; Now Zone Number:'%d'; Current TID $pid.',
      //	0, strDCMFile, nTotalZone1, nTotalZone, getCurrentThreadId());
      /*bool bIsTwoWindows = playSkin.isTwoWindows;
      bool bIsAutoHide = playSkin.isAutoHidePopupWindow;
      if (!bIsTwoWindows || !bIsAutoHide
        || (bIsTwoWindows && bIsAutoHide && !strOldTouch.equalsIgnoreCase(playSkin.dcmFile))) {
        DeleteTouchScreen();
      }
      
      if (_bIsTouchScreen) {
        CRect rect(0, 0, getSystemMetrics(SM_CXSCREEN), getSystemMetrics(SM_CYSCREEN));
        playSkin.setTouchScreen(true);
        playSkin.setTouchScreenRect(rect);
      }*/
      if (!_bIsSameSkin) {
        loadSkinSetting();
        reCalcPlayerRect();
      }
      String strCompany = ScheduleList().getCurrCompany();
      playMusic(strCompany);
      resetZoneRect(nTotalZone);

      _bScreenLayoutChanged = (_bDisplayChanged ||
          ScheduleList().getCatalogue().strLayoutName != strOldLayout ||
          ScheduleList().getCatalogue().nScreenType != nOldScreen);
      _bDisplayChanged = false;
      //logD('PlayerScreenProvider - LoadCatalogue Step: %d, Current TID $pid.', 3, getCurrentThreadId());
      ScheduleList().setPlayTimes();
      _strDCMFile = strDCMFile;
      //logD('PlayerScreenProvider - LoadCatalogue Step: %d, Current TID $pid.', 4, getCurrentThreadId());
      return true;
    }

    return false;
  }

  bool sendSerialMSG(String data) {
    if (data.isEmpty) return false;

    if (_nSerialControl == 1 && _pSerialControl != null) {
      //DbgOutStringToFile('Send Com Port Command!!', 'errcom.txt');
      //MessageBox('Send Com Port Command!!');
      List<int> bytes = [];
      for (int i = 0; i < data.length ~/ 2; i++) {
        String hexPair = data.substring(i * 2, (i + 1) * 2);
        bytes.add(int.parse(hexPair, radix: 16));
      }
      return (_pSerialControl!.write(Uint8List.fromList(bytes)) > 0);
      /*if (_pSerialControl.Write(szMsg) == ERROR_SUCCESS)
      {
        //MessageBox('Send Com Port Command successful!!');
        DbgOutStringToFile('Send Com Port Command successful!!', 'errcom.txt');
      }
      else
      {
        //MessageBox('Send Com Port Command failure!!');
        DbgOutStringToFile('Send Com Port Command failure!!', 'errcom.txt');
      }*/
    }
    return false;
  }

  bool sendSerialFile(String szFile) {
    if (_nSerialControl == 1 && _pSerialControl != null) {
      String strFilePath = szFile;
      if (strFilePath.isEmpty) {
        strFilePath = path.join(App().dataPath, 'serial.txt'); //getAppPath();
      }

      // Open the file
      final file = File(strFilePath);
      String strFileData = file.readAsStringSync();
      if (strFileData.isNotEmpty) {
        List<int> bytes = [];
        for (int i = 0; i < strFileData.length ~/ 2; i++) {
          String hexPair = strFileData.substring(i * 2, (i + 1) * 2);
          bytes.add(int.parse(hexPair, radix: 16));
        }
        _pSerialControl!.write(Uint8List.fromList(bytes));
        logD('COM Port: Data sent: $strFileData');
      } else {
        logD('COM Port: Read serial file '
            '$strFilePath'
            ' error or serial file is empty: $strFilePath');
      }
    }

    return true;
  }

  void loadSkinSetting() {
    //SetWindowRgn(null, true);

    playSkin.loadFromCatalogue(ScheduleList().getCatalogue());

    //ShowScreenFrame(true);
    if (!_bIsSameSkin) {
      _changeWindowSize(playSkin.monitorRect);
    }
    _getClientRect();
  }

  void _changeWindowSize(Rect rectMonitor) {
    if (rectMonitor.isEmpty) return;
    /* MoveWindow(rectMonitor);
      SetWindowPos(
          null,
          rectMonitor.left,
          rectMonitor.top,
          rectMonitor.Width(),
          rectMonitor.Height(),
          SWP_NOACTIVATE | SWP_NOREPOSITION); //SWP_NOMOVE |*/

    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      logD('PlayerScreenProvider - _changeWindowSize: $rectMonitor');
      //window.setPosition(rectMonitor.left, rectMonitor.top);
      //window.setSize(rectMonitor.width, rectMonitor.height);
    }
  }

  void _getClientRect() async {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      _rectPlayer = Rect.fromLTWH(window.position.dx, window.position.dy,
          window.size.width, window.size.height);
      logD('PlayerScreenProvider - GetClientRect: $_rectPlayer');
    }
  }

  void resetMusicPlayer() {
    App().player.stop();
  }

  void playMusic([String? strCompany]) {
    String strImageFile = ScheduleList().getCatalogue().strImageFile;
    if (strImageFile.isNotEmpty) {
      strImageFile = Utils.getFilePath(
          strImageFile, cIMAGETYPE, cDCMSINGLEIMAGETYPE, strCompany);
      /*_pPict = new CPicture();
      if (!_pPict.Load(strImageFile)) {
        SAFE_DELETE(_pPict);
      }*/
    }

    resetMusicPlayer();

    String strText = '';
    if (_bIsSound) {
      String szAppPath = path.join(App().dataPath, configFILENAME);

      IniFile settingFile = IniFile(szAppPath);
      strText = settingFile.readString('Global Setting', 'KeyPadSound', '');
    } else {
      String strMusicFile = ScheduleList().getBGMusicFile();
      if (ScheduleList().hasBGMusic() && strMusicFile.isNotEmpty) {
        strText = Utils.getFilePath(strMusicFile, cVIDEOTYPE, -1, strCompany);
      } else {
        String szAppPath = path.join(App().dataPath, configFILENAME);

        IniFile settingFile = IniFile(szAppPath);
        strText =
            settingFile.readString('Global Setting', 'Background Music', '');
      }
    }
    if (strText.isNotEmpty) {
      strText = FileUtils.validFilePathSync(strText, '', true);
      if (strText.isNotEmpty) {
        App().openMedia(PlayItem(source: strText, title: strText));
      }
    }
  }

  void resetZoneRect(int nTotalZone) {
    playSkin.removeAll();
    for (int nZone = 0; nZone < nTotalZone; nZone++) {
      Rect rect = scaleToVW(nZone);
      ZoneRectData pData = ZoneRectData();
      pData.setZoneRect(rect);
      pData.nZoneID = nZone;
      pData.nLevel = nZone;
      pData.bIsAH = false;
      pData.bIsTS = false;

      playSkin.addZoneRectData(pData);
    }
  }

  void reCalcZoneRect() {
    int nTotalZone = ScheduleList().getTotalZones();
    for (int nZone = 0; nZone < nTotalZone; nZone++) {
      Rect rect = scaleToVW(nZone);
      playSkin.updateZoneRectData(nZone, rect);

      /*CWinThread *pThread = getZoneThread(nZone);
      if (pThread != null)
        ::MoveWindow(((PlayerZone )pThread).getPlayerHWnd(), rect.left, rect.top, rect.Width(), rect.Height(), false);*/
    }
  }

  void reCalcPlayerRect([int nOutput = -1]) {
    Rect rectVW1 = playSkin.getPlayerRect();

    //_PlayerFrame.ScaleMediaWindow(rectVW1);
    Rect rectScreen = playSkin.getScreenRect();
    if (playSkin.getPlayerRect() != rectScreen) {
      rectVW1 = rectVW1.shift(rectScreen.topLeft);
    }

    if (!ScheduleList().messageList.isOverlay(nOutput)) {
      Rect rectAH = playSkin.getAHMessageRect(nOutput);
      if (!rectAH.isEmpty) {
        Utils.subtractRect(rectVW1, rectVW1, rectAH);
      }
    }

    setPlayerRect(rectVW1, true);
  }

  void setPlayerRect(Rect rectPlayer, bool bIsFrame) {
    if (!bIsFrame) {
      _getClientRect();
    } else {
      _rectPlayer = rectPlayer;
    }
  }

  Rect scaleToVW(int nZone) {
    return ScheduleList().scaleToVW(nZone, _rectPlayer);
  }

  @override
  void dispose() {
    logI('PlayerScreenProvider dispose');
    _timer?.cancel();
    _playingTimer?.cancel();

    super.dispose();
  }
}
