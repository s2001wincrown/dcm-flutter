import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/services/dcm_skin_impl.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/widgets/basic_video.dart';
import 'package:dcm/widgets/content_list_player.dart';
import 'package:dcm/widgets/slideshow.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  late String _strZoneFile;

  bool _bDDERefresh = false;
  bool _bLoadState = false;
  bool _bShowMessage = false;
  bool _bShowMessageNext = false;
  bool _bNeedReset = false;
  bool _bIsAHPlaylist = false;

  late double _rtDuration;
  late double _rtLine;
  late double _rtAct;
  late double _rtPlaying;
  late double _rtCurrDuration;

  Rect? rect;
  Rect? _rectPlayerOrg;

  ContentListPlayer? _contentListPlayer;
  VideoController? _controller;
  Player? _player;
  int _nVideoStatus = -1;
  bool _bWantStop = false;

  void stopPlay() {
    if (_player != null) {
      _player!.dispose();
      _player = null;
    }
    if (_contentListPlayer != null) {
      _contentListPlayer!.stop();
      _contentListPlayer = null;
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

  void initZone() async {
    stopPlay();

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
      _bIsValid = false;
      return;
    }

    if (_zoneId < 0) _zoneId = pZoneData.nZoneID;
    if (rect == null && _zoneId > -1) rect = playSkin.getZoneRect(_zoneId);

    _bIsRendering = true;
    int nCurSel = pZoneData.nZoneType;
    _strZoneFile = Utils.getFilePath(
        pZoneData.strZoneFile, pZoneData.nZoneType, _nPType, _strCompany);
    if (await _validZone(_strZoneFile, nCurSel)) {
      //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 4");
      _rtDuration = 0;
      switch (nCurSel) {
        case cIMAGETYPE:
          break;
        case cVIDEOTYPE:
          _player = Player(
            configuration: const PlayerConfiguration(
              title: 'dcm',
              osc: false,
              muted: false,
              async: true,
              libass: false,
              logLevel: MPVLogLevel.error,
            ),
          );

          final video = Media(LibraryHelper.normalizeMediaSource(_strZoneFile));
          _player!.open(video, play: false);

          _controller = VideoController(
            _player!,
            configuration: VideoControllerConfiguration(
              width: rect!.width.toInt(),
              height: rect!.height.toInt(),
            ),
          );
          _player!.setVolume(
              DCMGlobal.videoVolume(pZoneData.bZoneMute, pZoneData.dVolume));
          _rtAct = _player!.state.duration.inMilliseconds / 1000.0;
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

    if (nCurSel != cDDETYPE &&
        nCurSel != cDIRECTPLAYTYPE &&
        nCurSel != cSITEPLAYLIST) {
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
  }

  void setWindowRect(Rect rcWin) {
    rect = rcWin;
  }

  int getZone() => _zoneId;

  void setZone(int nZone) {
    _zoneId = nZone;
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

  bool isFirstFinished() => _bFirstFinished;
  void setFirstFinished([bool bFirst = true]) {
    _bFirstFinished = bFirst;
  }

  bool isContentFinished() => _bContentFinished;
  void setContentFinished([bool bContentFinished = true]) {
    _bContentFinished = bContentFinished;
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

  Widget renderZone() {
    if (_bIsValid) {
      ZoneData? pZoneData = getZoneData();
      switch (pZoneData!.nZoneType) {
        case cIMAGETYPE:
          if (_bNeedReset) {
            return Slideshow(imageFile: _strZoneFile);
          }
          break;
        case cVIDEOTYPE:
          if (_player != null) {
            _player!.play();
          }
          return ClipRRect(
            borderRadius: BorderRadius.zero,
            child: BasicVideo(controller: _controller!),
          );

        case cPOWERPOINTTYPE:
          //PlayPPT(strZone1File, rectWin);
          break;

        case cQUEUETYPE:
        case cWEBPAGETYPE:
          break;
        case cFLASHTYPE:
          break;
        case cTVCAPTURETYPE:
        case cWEBCAMTYPE:
          break;
        case cTEXTTYPE:
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
          break;
        case cLINKAGETYPE:
          break;
        case cEVENTTYPE:
          break;
        default:
          break;
      }
    }

    _bIsPlaying = false;
    _bNeedReset = true;
    //Log.i(PlayerMainActivity.LOG_TAG, "RenderZone step 6 _rtDuration: " + _rtDuration + " _rtAct " + _rtAct);
    logI(
        'RenderZone finished - Zone: $_zoneId; _rtDuration: $_rtDuration; _rtAct $_rtAct; _pZoneData: $_pZoneData; _pProductData: $_pProductData;');

    return Container(color: Color(DCMGlobal.clrBGColor));
  }

  void playContentList(int nType, String strZoneFile, Rect rectWin) {
    if (_contentListPlayer == null) {
      logD('''Zone $_zoneId play '$strZoneFile' step 21, TID $pid.''');
      _contentListPlayer = ContentListPlayer(nType, _zoneId);
    } else {
      logD('''Zone $_zoneId play '$strZoneFile' step 22, TID $pid.''');
      _contentListPlayer!.resetFirstFinished();
      _contentListPlayer!.setTimeForStop(true);
      //_contentListPlayer!.stop();
    }

    if (_contentListPlayer != null) {
      logD('''Zone $_zoneId play '$strZoneFile' step 23, TID $pid.''');
      _contentListPlayer!.loadContentList(strZoneFile);
      if (_contentListPlayer!.isValidForPlay()) {
        logD('''Zone $_zoneId play '$strZoneFile' step 24, TID $pid.''');
        _rtDuration = _contentListPlayer!.getDuration() -
            _contentListPlayer!.getDuration(_nStart);
        _contentListPlayer!.setPlayerRect(rect!);
        logD('''Zone $_zoneId play '$strZoneFile' step 25, TID $pid.''');
        _contentListPlayer!.setAHPlaying(_bIsAHPlaylist);
        _contentListPlayer!.setParentContentType(_nPType);
        //CString strCompany = PlayList.GetCurrCompany();
        _contentListPlayer!.setCompany(_strCompany);
        _contentListPlayer!.setStartTime(_dwStartTime);
        _contentListPlayer!.play(_nStart); //
        _bShowMessage = _contentListPlayer!.isShowMessage();
        _bShowMessageNext = _contentListPlayer!.isShowMessageNext();
        _nStart = 0;
      }
      _contentListPlayer!.setTimeForStop(false);
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
      logD('playNextContentListItem error: $e');
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

  ({bool status, double? rtPosition}) getCurrentPosition(double rtPosition) {
    if (_bIsRendering) {
      return (status: false, rtPosition: null);
    }

    bool bRet = false;
    if (_player != null) {
      rtPosition = _player!.state.position.inMilliseconds / 1000.0;
      bRet = true;
    }

    if (bRet) {
      if (_nVideoStatus != 1 && rtPosition - _rtCurrDuration < cEPSILON) {
        bRet = false;
      } else {
        _rtCurrDuration = rtPosition;
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
    logD(
        'Zone $_zoneId CPlayerZoneDlg::IsPlayerFinish ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');

    logD(
        '''CPlayerZoneDlg::IsPlayerFinish; Zone $_zoneId; _rtDuration:'$_rtDuration'; _rtAct:'$_rtAct'; rtCurrPos:'$rtCurrPos'; _rtLine:'$_rtLine'; _rtPlaying:'$_rtPlaying'.''');
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
      if (_player != null) {
        // && _pZonePlayer->State() == MLS_LOADED
        if (_rtDuration - rtAct < cPLAYINGINTERVAL) {
          if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
            logD(
                'Zone $_zoneId Create filter for video file ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');
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
              logD(
                  'Zone $_zoneId Create filter for video file ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');
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
            logD(
                'Zone $_zoneId Create filter for video file ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');
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
          logD(
              'Zone $_zoneId Play start ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_dtStartPlay)}.');
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
    //logI('CPlayerZoneImpl::IsPlayerFinish; Zone %d; _rtDuration:'%.8f'; _rtAct:'%.8f'; rtCurrPos:'%.8f'; _rtLine:'%.8f'!!!', _nZone, _rtDuration, _rtAct, rtCurrPos, _rtLine);
    if (!_bIsRendering && pZoneData.nZoneType == cVIDEOTYPE) {
      if (_player != null) {
        if (_rtDuration - rtAct < cPLAYINGINTERVAL) {
          if (_rtDuration - rtCurrPos < cPLAYINGINTERVAL) {
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
        //RePlayVideo();
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
    _rtDuration = pZoneData.nZoneDuration;
    calcDuration();
  }

  void showZoneWnd(bool bool) {}

  static double getVideoDuration(String videoFile) {
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
    player.open(video, play: false);
    player.setVolume(cVOLUMESILENCE);

    return player.state.duration.inMilliseconds / 1000.0;
  }
}
