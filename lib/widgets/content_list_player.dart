import 'dart:ui';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/contentlist_impl.dart';

/// A Flutter/Dart replacement for the legacy ContentListPlayer C++ implementation.
class ContentListPlayer {
  final ContentListImpl _contentList;
  int _currPlaying = 0;
  int _videoStatus = -1;
  bool _bTimeForStop = false;
  bool _bIsAHPlaying = false;
  bool _bFirstFinished = false;
  bool _bShowMessage = false;
  bool _bShowMessageNext = false;
  int _nParentContentType = 0;
  String _strCompany = '';
  DateTime? _dtStartTime;
  Rect? _playerRect;
  final List<PlayerZoneImpl> _players = [];
  List<Rect>? _arrZoneRect;

  ProductData? _pProductData;
  bool _bIsPlaying = false;

  late int _nCurrProduct;
  int _nContentType;
  int _nPType = -1;
  int _nZone;
  late int _nPrevTotalZone;

  ContentListPlayer(this._nContentType, this._nZone)
      : _contentList = ContentListImpl(_nContentType);

  List<ProductData> get products => _contentList.lstProduct;
  List<String> get contentLists => _contentList.arrContentList;
  DateTime get lastModified => _contentList.dtLastModified;

  bool get bTimeForStop => _bTimeForStop;

  bool saveContentList(MessageData messageData) {
    return _contentList.saveContentList(messageData);
  }

  MessageData? loadContentList(String contentList) {
    _currPlaying = 0;
    return _contentList.loadContentList(contentList);
  }

  void loadContentListFile(String contentList) {
    _contentList.loadContentListFile(contentList);
    _currPlaying = 0;
  }

  void loadContentListByDateRange(DateTime? start, DateTime? end,
      {String? contentList}) {
    _contentList.loadContentListByDateRange(start, end,
        strContentList: contentList);
    _currPlaying = 0;
  }

  void loadContentListGeneral({String contentList = ''}) {
    _contentList.loadContentListGeneral(strContentList: contentList);
    _currPlaying = 0;
  }

  Future<bool> isExistedContentList(MessageData messageData) {
    return _contentList.isExistedContentList(messageData);
  }

  bool isValidForPlay() {
    return _contentList.isValidForPlay();
  }

  bool isOutdated(ProductData productData) {
    return _contentList.isOutdated(productData);
  }

  bool isTimeForPlay(ProductData productData) {
    return _contentList.isTimeForPlay(productData);
  }

  ProductData? getProductData({int nProduct = 0}) {
    return _contentList.getProductData(nProduct: nProduct);
  }

  double getDuration([int nStart = 0]) {
    if (nStart <= 0) {
      return _contentList.getDuration();
    }

    double dbDuration = 0.0;
    int currentIndex = 0;
    for (final pData in _contentList.lstProduct) {
      if (!isTimeForPlay(pData)) {
        continue;
      }
      if (currentIndex >= nStart) {
        break;
      }
      dbDuration += Utils.getMaxDuration(pData);
      currentIndex++;
    }
    return dbDuration;
  }

  int getCount() {
    return _contentList.lstProduct.where(isTimeForPlay).length;
  }

  bool hasContent(int nContentType) {
    for (final product in _contentList.lstProduct) {
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
    _playerRect = rect;
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
          pZoneImpl.initZone();
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
      pZoneImpl.initZone();

      _players.add(pZoneImpl);
    }
  }

  void deleteZoneImpl(int nZone) {
    while (_players.length > nZone) {
      PlayerZoneImpl pImpl = _players.elementAt(nZone);
      pImpl.stopPlay();
      _players.removeAt(nZone);
    }
  }

  void stop() {
    /*if (m_bIsPlaying)
      return;*/
    deleteZoneImpl(0);
    _nPrevTotalZone = -1;
    //_nPlayAHItem = -1;
    //_dwPlayADItem = 0;
    //g_pPlayerWnd->DetachMZThread(m_nZone);
    _bIsPlaying = false;
  }

  void play(int nStart) {
    if (nStart < 0) {
      _currPlaying = 0;
    } else {
      _currPlaying = nStart;
    }

    final activeCount = _contentList.lstProduct.where(isTimeForPlay).length;
    if (_currPlaying >= activeCount) {
      _currPlaying = activeCount > 0 ? activeCount - 1 : 0;
    }

    _bShowMessage = isShowMessage();
    _bShowMessageNext = isShowMessageNext();
  }

  void stopCurrProduct() {
    _bTimeForStop = true;
  }

  void playNextProduct() {
    final activeProducts =
        _contentList.lstProduct.where(isTimeForPlay).toList();
    if (_currPlaying < activeProducts.length - 1) {
      _currPlaying++;
    } else {
      _currPlaying = activeProducts.length;
    }

    _bShowMessage = isShowMessage();
    _bShowMessageNext = isShowMessageNext();
  }

  void rePlayProduct() {
    if (_currPlaying < 0) {
      _currPlaying = 0;
    }

    _bShowMessage = isShowMessage();
    _bShowMessageNext = isShowMessageNext();
  }

  void rePlay() {
    _nCurrProduct = -1;
  }

  bool isShowMessage() {
    final activeCount = _contentList.lstProduct.where(isTimeForPlay).length;
    return _currPlaying >= 0 && _currPlaying < activeCount;
  }

  bool isShowMessageNext() {
    final activeCount = _contentList.lstProduct.where(isTimeForPlay).length;
    return _currPlaying + 1 >= 0 && _currPlaying + 1 < activeCount;
  }

  void videoStatusControl(int nVideoStatus) {
    _videoStatus = nVideoStatus;
  }

  ({bool status, PlayFinish? nFinish}) isPlayFinish(PlayFinish nFinish) {
    if (_bTimeForStop) return (status: false, nFinish: nFinish);

    DateTime dwSecondTime = DateTime.now();

    double rtPos = 0;
    double rtPlayerDuration = 0;
    for (PlayerZoneImpl pPlayer in _players) {
      double rtCurrPos1 = dwSecondTime
          .difference(pPlayer.getStartPlayTime())
          .inMilliseconds
          .toDouble();
      var result = pPlayer.getCurrentPosition(rtPos);
      if (!result.status) {
        rtPos = rtCurrPos1 / Duration.millisecondsPerSecond;
      } else {
        rtPos = result.rtPosition!;
      }

      var nResult = pPlayer.isPlayerFinished(rtPos);
      /*WriteMessage(MSG_INFO, _T("CContentListPlayer::IsPlayFinish; Zone:'%d'; m_dwSecondTime:'%d'; rtCurrPos1:'%.2f'; rtPos:'%.2f'; nResult: '%d'")
        , i, dwSecondTime, rtCurrPos1, rtPos, nResult);*/
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
    _contentList.lstProduct.clear();
    _contentList.arrContentList.clear();
    _currPlaying = 0;
    _videoStatus = -1;
    _bTimeForStop = false;
    _bShowMessage = false;
    _bShowMessageNext = false;
    _bFirstFinished = false;
    _playerRect = null;
  }
}
