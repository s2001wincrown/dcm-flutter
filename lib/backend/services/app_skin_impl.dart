import 'dart:io';
import 'dart:math';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_rect_data.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/main.dart';
import 'package:nativeapi/nativeapi.dart';

enum AppSkinType { gdi, html, d2d, html5 }

class AppSkinSetting {
  AppSkinSetting._() {
    _initSetting();
  }

  static final AppSkinSetting instance = AppSkinSetting._();

  AppSkinSetting({
    this.skin = 0,
    this.skinCode = '',
    this.screenType = 0,
    Size? layout,
  }) : layout = layout ?? Size.zero {
    _initSetting();
    if (skin != 0 || skinCode.isNotEmpty || screenType != 0) {
      loadSkinFile();
    }
  }

  // Attributes
  bool highlightFocusBtn = false;
  int btnWidth = 0;
  int btnHeight = 0;
  int btnSpace = 0;
  int btnLayout = 0;
  int quantity = 1;
  List<int> outputs = [];

  int fontColor = 0;
  bool fontUnderline = false;
  bool fontItalic = false;
  bool fontBold = false;
  String fontName = 'Arial';
  int fontSize = 160;
  int btnAlign = 0;
  int btnStyle = 0;
  String btnLang = 'ENG';

  int playingBtnTextColor = 0;
  int btnTextColor = 0;
  int frameColor = 0;
  int playingBtnTextColor2 = 0;
  int btnTextColor2 = 0;
  int frameColor2 = 0;

  int btnMinWidth = 0;
  int btnMinHeight = 0;

  int pageBtnWidth = 0;
  int pageBtnHeight = 0;
  int pageBtnSpace = 0;
  int pageMode = 0;
  int sortMode = 0;
  int loadingDelay = 0;

  int mockBtnMode = 0;
  int screenEffect = 0;
  int timeout = 10;
  int autoReloadDuration = 0;
  int alpha = 255;

  int skin = 0;
  int screenType = 0;
  String skinCode = '';
  String skinFile = '';
  String maskFile = '';
  String skinFile2 = '';
  String maskFile2 = '';
  String htmlFile1 = '';
  String htmlFile2 = '';
  String skinTypeString = '0';
  String dcmFile = '';
  String eventFile = '';
  String fixedSort = '';

  int backBtnTextColor = 0;
  String backBtnImage = '';
  bool backBtn = false;

  bool isTwoWindows = false;
  bool useMask = false;
  bool isAutoHidePopupWindow = false;
  bool hideCursor = true;
  bool isTouchScreen = false;
  bool transparencyMsg = false;

  Size? layout;
  Rect playerRect = Rect.zero;
  Rect playerRect01 = Rect.zero;
  Rect playerRect02 = Rect.zero;
  Rect playerRect1 = Rect.zero;
  Rect playerRect2 = Rect.zero;
  Rect screenRect = Rect.zero;
  Rect imageRect = Rect.zero;
  Rect monitorRect =
      Rect.fromLTWH(0, 0, primaryDisplaySize.width, primaryDisplaySize.height);
  Rect touchScreenRect = Rect.zero;
  Map<int, Rect> ahMessageRects = {};
  List<ZoneRectData> zoneRects = [];

  // Constructors
  void release() {
    // No-op in Dart; retained for compatibility.
  }

  bool get highlightFocus => highlightFocusBtn;

  int getBtnWidth() => btnWidth;
  int getBtnHeight() => btnHeight;
  int getBtnSpace() => btnSpace;
  Rect getPlayWndRect() => playerRect;
  bool getHighlightFocusBtn() => highlightFocusBtn;
  int getBtnTextColor() => btnTextColor;
  int getPlayingBtnTextColor() => playingBtnTextColor;

  void setBtnTextColor(int color) {
    btnTextColor = color;
  }

  void setPlayingBtnTextColor(int color) {
    playingBtnTextColor = color;
  }

  void setBtnFontBold(bool bold) {
    fontBold = bold;
  }

  void setBtnFontItalic(bool italic) {
    fontItalic = italic;
  }

  void setBtnFontUnderline(bool underline) {
    fontUnderline = underline;
  }

  void setBtnFontSize(int size) {
    fontSize = size;
  }

  void addZoneRectData(ZoneRectData zoneRect) {
    final existingIndex =
        zoneRects.indexWhere((z) => z.nZoneID == zoneRect.nZoneID);
    if (existingIndex >= 0) {
      zoneRects[existingIndex] = zoneRect;
    } else {
      zoneRects.add(zoneRect);
    }
  }

  ZoneRectData? getZoneRectData(int zoneId) {
    return zoneRects.firstWhere(
      (rect) => rect.nZoneID == zoneId,
      orElse: () => ZoneRectData(),
    );
  }

  int getZoneLevel(int zoneId) {
    final zone = zoneRects.firstWhere(
      (rect) => rect.nZoneID == zoneId,
      orElse: () => ZoneRectData(),
    );
    return zone.nLevel;
  }

  Rect getZoneRect(int zoneId) {
    final zone = zoneRects.firstWhere(
      (rect) => rect.nZoneID == zoneId,
      orElse: () => ZoneRectData(),
    );
    return zone.getZoneRect();
  }

  Rect getAHMessageRect([int output = -1]) {
    return ahMessageRects[output] ?? Rect.zero;
  }

  void removeAHMessageRect([int? output]) {
    if (output == null) {
      ahMessageRects.clear();
    } else {
      ahMessageRects.remove(output);
    }
  }

  Rect getTouchScreenRect() => touchScreenRect;

  void setAHMessageRect(Rect rect, [int output = -1]) {
    ahMessageRects[output] = rect;
  }

  void setAHMessageRectFromProduct(
      ProductData productData, int layout, int zone, int ahType, Rect rect,
      [int output = -1]) {
    if (layout == 1 || layout == 2) {
      final zoneRect = getZoneRect(zone);
      ahMessageRects[output] = zoneRect;
      if (ahMessageRects[output]!.isEmpty) {
        final messageZone = productData.getZone(ahType);
        ahMessageRects[output] = getZoneRect(messageZone);
      }
    } else {
      ahMessageRects[output] = rect;
    }
  }

  void setTouchScreenRect(Rect rect) {
    touchScreenRect = rect;
  }

  bool isPopTouchScreen() => isTouchScreen;

  void setTouchScreen(bool value) {
    isTouchScreen = value;
  }

  bool isAutoHide() => isAutoHidePopupWindow;
  bool isHideCursor() => hideCursor;
  int getScreenEffect() => screenEffect;
  int getTouchScreenTimeout() => timeout;
  Rect getPlayerRect() => playerRect;
  Rect getScreenRect() => screenRect;
  int getAutoReloadDuration() => autoReloadDuration;

  AppSkinType get skinType {
    switch (skinTypeString) {
      case '0':
        return AppSkinType.gdi;
      case '1':
        return AppSkinType.html;
      case '2':
        return AppSkinType.d2d;
      default:
        return AppSkinType.html5;
    }
  }

  String getSkinCode() => skinCode;
  String getSkinFile() => skinFile;
  String getMaskFile() => maskFile;
  String getSkinFile2() => skinFile2;
  String getMaskFile2() => maskFile2;
  String getHtmlFile1() => htmlFile1;
  String getHtmlFile2() => htmlFile2;
  String getSkinTypeString() => skinTypeString;
  String getDCMFile() => dcmFile;
  String getEventFile() => eventFile;
  String getFixedSort() => fixedSort;
  int getPageMode() => pageMode;
  int getSortMode() => sortMode;
  int getPageBtnHeight() => pageBtnHeight;
  int getPageBtnWidth() => pageBtnWidth;
  int getPageBtnSpace() => pageBtnSpace;
  int getBtnMinHeight() => btnMinHeight;
  int getBtnMinWidth() => btnMinWidth;

  void removeAll() {
    zoneRects.clear();
    ahMessageRects.clear();
  }

  void loadFromCatalogue(DCMFileData fileObj) {
    loadSkins(fileObj.nSkin, fileObj.strSkinCode, fileObj.nScreenType,
        fileObj.getLayoutSize());
    fontName = fileObj.strFontName;
    setBtnFontSize(fileObj.nFontSize);
    setBtnFontBold(fileObj.bFontBold);
    setBtnFontItalic(fileObj.bFontItalic);
    setBtnFontUnderline(fileObj.bFontUnderline);
    btnAlign = fileObj.nBtnAlign;
    fontColor = fileObj.crFontColor;
    btnStyle = fileObj.nBtnStyle;
    quantity = fileObj.nQuantity;
    btnLang = fileObj.strBtnLng;
  }

  void loadSkins(int skin, String skinCode, int screenType, [Size? layout]) {
    this.skin = skin;
    this.skinCode = skinCode;
    this.screenType = screenType;
    final prevAHMessages = Map<int, Rect>.from(ahMessageRects);
    final prevTouchScreen = touchScreenRect;
    _initSetting();
    this.layout = layout;
    loadSkinFile();
    ahMessageRects = prevAHMessages;
    touchScreenRect = prevTouchScreen;
  }

  void loadSkinFile() {
    removeAll();
    final iniFile = IniFile(AppGlobal.skinFile);
    _getMonitorInfo(iniFile, skinCode);
    final cx = monitorRect.width;
    final cy = monitorRect.height;
    screenRect = Rect.fromLTWH(0, 0, cx, cy);

    if (hasFlag(AppGlobal.playMode, 2)) {
      if (layout != null && layout!.width > 0 && layout!.height > 0) {
        final fitted = _fitToSize(layout!, screenRect);
        screenRect = fitted;
      }
    }

    isTwoWindows = iniFile.readInt(skinCode, 'Two Windows', 0) > 0;
    hideCursor = AppGlobal.globalSetting & settingHIDECURSOR > 0;
    if (!hideCursor) {
      hideCursor = iniFile.readInt(skinCode, 'Hide Cursor', 1) > 0;
    }
    dcmFile = iniFile.readString(skinCode, 'Second DCMFile', '');
    eventFile = iniFile.readString(skinCode, 'Second EventFile', '');
    skinTypeString = iniFile.readString(skinCode, 'HTML Skin', '0');
    htmlFile1 = iniFile.readString(skinCode, 'Skin Html', ' ');
    htmlFile2 = iniFile.readString(skinCode, 'Skin Html2', ' ');
    if (htmlFile1.isNotEmpty) htmlFile1 = _normalizePath(htmlFile1);
    if (htmlFile2.isNotEmpty) htmlFile2 = _normalizePath(htmlFile2);
    isAutoHidePopupWindow =
        iniFile.readInt(skinCode, 'Auto Hide Popup Window', 1) > 0;
    highlightFocusBtn =
        iniFile.readBool(skinCode, 'HighlightFocusButton', false);
    timeout = iniFile.readInt(skinCode, 'Delay Second', 5);
    autoReloadDuration =
        iniFile.readInt(skinCode, 'Auto Reload Idle Duration', 0);
    if (autoReloadDuration == 0) {
      autoReloadDuration = AppGlobal.autoReloadDuration;
    }

    btnMinWidth = iniFile.readInt(skinCode, 'ButtonMinWidth', btnMinWidth);
    btnMinHeight = iniFile.readInt(skinCode, 'ButtonMinHeight', btnMinHeight);
    pageBtnWidth = iniFile.readInt(skinCode, 'PageButtonWidth', pageBtnWidth);
    pageBtnHeight =
        iniFile.readInt(skinCode, 'PageButtonHeight', pageBtnHeight);
    pageBtnSpace = iniFile.readInt(skinCode, 'PageButtonSpace', pageBtnSpace);
    pageMode = iniFile.readInt(skinCode, 'PageMode', pageMode);
    sortMode = iniFile.readInt(skinCode, 'SortMode', sortMode);
    loadingDelay =
        iniFile.readInt(skinCode, 'ProductLoadingDelay', loadingDelay);
    fixedSort = iniFile.readString(skinCode, 'FixedSortButtons', '');
    screenEffect = iniFile.readInt(skinCode, 'Screen Effect', screenEffect);
    mockBtnMode = iniFile.readInt(skinCode, 'MockButtonMode', mockBtnMode);
    alpha = iniFile.readInt(skinCode, 'Transparent', alpha);

    if (skinTypeString == '1') {
      _loadHtmlSkins(iniFile);
      return;
    }

    if (skinCode.toLowerCase() != 'no frame and no button') {
      skinFile = iniFile.readString(skinCode, 'Skin Image', '');
      maskFile = iniFile.readString(skinCode, 'Skin Image Mask', '');
      if (_validFilePath(maskFile)) {
        useMask = true;
      }

      final frameRect = iniFile.readString(
          skinCode, 'Frame Rect', skinTypeString == '3' ? '0,0,1600,900' : '');
      final imageRectString =
          iniFile.readString(skinCode, 'Image Rect', '0,0,1600,900');
      imageRect = _stringToRect(imageRectString);
      final frameColorString =
          iniFile.readString(skinCode, 'Frame Background', '0,0,0');
      final textRgb = iniFile.readString(
          skinCode, 'Product Button Text Color', '255,215,0');
      final playingRgb =
          iniFile.readString(skinCode, 'Playing Product Button Text Color', '');
      final btnWidthString =
          iniFile.readString(skinCode, 'Product Button Width', '');
      final btnHeightString =
          iniFile.readString(skinCode, 'Product Button Height', '');
      final btnSpaceString =
          iniFile.readString(skinCode, 'Product Button Space', '');
      btnLayout = iniFile.readInt(skinCode, 'Product Button Layout', btnLayout);

      final backTextRgb =
          iniFile.readString(skinCode, 'Back Button Text Color', '0,0,0');
      backBtnImage = iniFile.readString(skinCode, 'Back Button Image', '');
      backBtn = iniFile.readInt(skinCode, 'Back Button', 0) > 0;
      backBtnTextColor = fromRGBString(backTextRgb);
      if (_validFilePath(backBtnImage)) {
        backBtnImage = backBtnImage;
      }

      btnTextColor2 = fromRGBString(textRgb);
      playingBtnTextColor2 = fromRGBString(playingRgb);
      frameColor2 = fromRGBString(frameColorString);
      btnWidth2 = int.tryParse(btnWidthString) ?? btnWidth2;
      btnHeight2 = int.tryParse(btnHeightString) ?? btnHeight2;
      btnSpace2 = int.tryParse(btnSpaceString) ?? btnSpace2;

      btnTextColor = fromRGBString(textRgb);
      playingBtnTextColor = fromRGBString(playingRgb);
      frameColor = fromRGBString(frameColorString);
      btnWidth = int.tryParse(btnWidthString) ?? btnWidth;
      btnHeight = int.tryParse(btnHeightString) ?? btnHeight;
      btnSpace = int.tryParse(btnSpaceString) ?? btnSpace;

      if (skinTypeString == '3') {
        playerRect = _stringToRect(frameRect);
      } else {
        if (_validFilePath(skinFile)) {
          playerRect = _stringToRect(frameRect);
        }
      }
      if (_validFilePath(skinFile2)) {
        playerRect01 = _stringToRect(frameRect);
        playerRect02 = _stringToRect(frameRect);
      }
    } else {
      skinFile = iniFile.readString('No Frame and No Button', 'Skin Image', '');
      if (_validFilePath(skinFile)) {
        skinFile = skinFile;
      }
      final textRgb = iniFile.readString(
          'No Frame and No Button', 'Product Button Text Color', '255,215,0');
      final playingRgb = iniFile.readString(
          'No Frame and No Button', 'Playing Product Button Text Color', '');
      btnTextColor = fromRGBString(textRgb);
      playingBtnTextColor = fromRGBString(playingRgb);
      btnWidth = iniFile.readInt(
          'No Frame and No Button', 'Product Button Width', btnWidth);
      btnHeight = iniFile.readInt(
          'No Frame and No Button', 'Product Button Height', btnHeight);
      btnSpace = iniFile.readInt(
          'No Frame and No Button', 'Product Button Space', btnSpace);
      btnLayout = iniFile.readInt(
          'No Frame and No Button', 'Product Button Layout', btnLayout);
      mockBtnMode = iniFile.readInt(
          'No Frame and No Button', 'MockButtonMode', mockBtnMode);
      frameColor = fromRGBString(iniFile.readString(
          'No Frame and No Button', 'Frame Background', '0,0,0'));
      frameColor2 = fromRGBString(iniFile.readString(
          'No Frame and No Button', 'Frame Background2', '0,0,0'));
    }

    if (playerRect01.isEmpty) {
      playerRect01 = screenRect;
    }
    if (playerRect02.isEmpty) {
      playerRect02 = screenRect;
    }
    if (playerRect.isEmpty) {
      playerRect = screenRect;
    }
  }

  void _loadHtmlSkins(IniFile iniFile) {
    if (skinCode.toLowerCase() != 'no frame and no button') {
      final frame = iniFile.readString(skinCode, 'Image Rect', '0,0,1600,900');
      final rect = iniFile.readString(skinCode, 'Frame Rect', '0,0,1600,900');
      final rect1 = iniFile.readString(skinCode, 'Frame Rect1', '0,0,1600,900');
      final rect2 = iniFile.readString(skinCode, 'Frame Rect2', '0,0,1600,900');
      final win1 = iniFile.readString(skinCode, 'First Window Position', '');
      final win2 = iniFile.readString(skinCode, 'Second Window Position', '');
      final frameColorString =
          iniFile.readString(skinCode, 'Frame Background', '0,0,0');
      final textRgb = iniFile.readString(
          skinCode, 'Product Button Text Color', '255,215,0');
      final playingRgb =
          iniFile.readString(skinCode, 'Playing Product Button Text Color', '');
      final btnWidthString =
          iniFile.readString(skinCode, 'Product Button Width', '');
      final btnHeightString =
          iniFile.readString(skinCode, 'Product Button Height', '');
      final btnSpaceString =
          iniFile.readString(skinCode, 'Product Button Space', '');

      frameColor = fromRGBString(frameColorString);
      btnTextColor = fromRGBString(textRgb);
      playingBtnTextColor = fromRGBString(playingRgb);
      btnWidth = int.tryParse(btnWidthString) ?? btnWidth;
      btnHeight = int.tryParse(btnHeightString) ?? btnHeight;
      btnSpace = int.tryParse(btnSpaceString) ?? btnSpace;

      imageRect = _stringToRect(frame);
      playerRect = _stringToRect(rect);
      if (playerRect.isEmpty) {
        playerRect = screenRect;
      }
    } else {
      playerRect = screenRect;
    }
  }

  bool isOverlay(Rect rect) {
    if (isTouchScreen &&
        !touchScreenRect.isEmpty &&
        touchScreenRect.overlaps(rect)) {
      return true;
    }
    for (final item in ahMessageRects.values) {
      if (!item.isEmpty && item.overlaps(rect)) {
        return true;
      }
    }
    return false;
  }

  void makeZoneHole(int zoneId, dynamic hwnd) {
    // Not supported in Flutter. Window-region operations are not portable.
  }

  void makeTouchScreenHole(dynamic hwnd) {
    // Not supported in Flutter.
  }

  void makeMessageHole(int output, dynamic hwnd) {
    // Not supported in Flutter.
  }

  void makeFrameHole(dynamic hwnd, dynamic dlgRgn) {
    // Not supported in Flutter.
  }

  void updateZoneRectData(int zoneId, Rect rect, {int alpha = 0}) {
    final zone = zoneRects.firstWhere(
      (item) => item.nZoneID == zoneId,
      orElse: () => ZoneRectData(),
    );
    if (zone.nZoneID != 0 || zoneRects.any((item) => item.nZoneID == zoneId)) {
      zone.setZoneRect(rect);
      zone.bAlpha = alpha;
    }
  }

  void updateZoneTransparency(int zoneId, int alpha) {
    final zone = zoneRects.firstWhere(
      (item) => item.nZoneID == zoneId,
      orElse: () => ZoneRectData(),
    );
    if (zone.nZoneID != 0 || zoneRects.any((item) => item.nZoneID == zoneId)) {
      zone.bAlpha = alpha;
    }
  }

  void updateZoneEffect(int zoneId, int effect) {
    final zone = zoneRects.firstWhere(
      (item) => item.nZoneID == zoneId,
      orElse: () => ZoneRectData(),
    );
    if (zone.nZoneID != 0 || zoneRects.any((item) => item.nZoneID == zoneId)) {
      zone.nLevel = effect;
    }
  }

  List<int> getOutputs() {
    if (outputs.isEmpty) {
      return [0];
    }
    return List.from(outputs);
  }

  Future<Rect> getMonitorRect([int output = -1]) async {
    Rect rect = monitorRect;
    if (output > -1) {
      //final monitors = await screenRetriever.getAllDisplays();
      final displayManager = DisplayManager.instance;
      final monitors = displayManager.getAll();
      if (output < monitors.length) {
        for (int i = 0; i < monitors.length; i++) {
          if (output == i) {
            rect = _displayRect(monitors[i]);
            break;
          }
        }
        rect = _normalizeRect(rect);
      }
    }

    return rect;
  }

  void _initSetting() {
    playingBtnTextColor = 0xFFD700;
    btnTextColor = 0x000000;
    frameColor = 0xFFFFFF;
    btnWidth = 200;
    btnHeight = 120;
    btnSpace = 10;
    playingBtnTextColor2 = 0xFFD700;
    btnTextColor2 = 0x000000;
    frameColor2 = 0xFFFFFF;
    btnWidth2 = 200;
    btnHeight2 = 120;
    btnSpace2 = 10;
    btnMinWidth = 200;
    btnMinHeight = 120;
    pageBtnWidth = 80;
    pageBtnHeight = 80;
    pageBtnSpace = 10;
    pageMode = 0;
    sortMode = 0;
    loadingDelay = 0;
    quantity = 1;
    fontName = 'Arial';
    fontSize = 160;
    fontBold = false;
    fontItalic = false;
    fontUnderline = false;
    fontColor = 0x000000;
    btnLang = 'ENG';
    btnAlign = 0;
    btnStyle = 0;
    timeout = 10;
    autoReloadDuration = 0;
    screenEffect = 0;
    mockBtnMode = 0;
    alpha = 255;
    backBtnTextColor = 0x000000;
    backBtnImage = '';
    backBtn = false;
    isTwoWindows = false;
    useMask = false;
    isAutoHidePopupWindow = false;
    hideCursor = true;
    skinFile = '';
    maskFile = '';
    skinFile2 = '';
    maskFile2 = '';
    htmlFile1 = '';
    htmlFile2 = '';
    skinTypeString = '0';
    dcmFile = '';
    eventFile = '';
    fixedSort = '';
    playerRect = Rect.zero;
    playerRect01 = Rect.zero;
    playerRect02 = Rect.zero;
    playerRect1 = Rect.zero;
    playerRect2 = Rect.zero;
    screenRect = Rect.zero;
    imageRect = Rect.zero;
    monitorRect = Rect.fromLTWH(
        0, 0, primaryDisplaySize.width, primaryDisplaySize.height);
    touchScreenRect = Rect.zero;
    ahMessageRects.clear();
    zoneRects.clear();
  }

  void _getMonitorInfo(IniFile iniFile, String skinCode) async {
    if (hasFlag(AppGlobal.playMode, cPLAYOTHER)) {
      monitorRect = Rect.fromLTRB(0, 0, layout!.width, layout!.height);
      return;
    }

    outputs.clear();
    int nMonitor = 0;
    if (AppGlobal.output < 80) {
      nMonitor = AppGlobal.output;
    }

    final displayManager = DisplayManager.instance;
    final allDisplays = displayManager.getAll();
    //final allDisplays = await screenRetriever.getAllDisplays();
    if (nMonitor == 0 && !hasFlag(AppGlobal.multiMonitor, cMULTIMONITORDV)) {
      String strRect = iniFile.readString(skinCode, 'DisplayMonitor', '');
      var displayMonitors = strRect.split(',');
      monitorRect = Rect.zero;
      if (displayMonitors.length > 1) {
        for (int i = 0; i < allDisplays.length; i++) {
          if (displayMonitors.contains(i.toString())) {
            monitorRect =
                monitorRect.expandToInclude(_displayRect(allDisplays[i]));
            outputs.add(i);
          }
        }

        if (!monitorRect.isEmpty) {
          monitorRect = _normalizeRect(monitorRect);
          return;
        }
      }

      nMonitor = int.tryParse(strRect) ?? 0;
    }

    if (nMonitor == -1) {
      monitorRect = Rect.zero;
      for (int i = 0; i < allDisplays.length; i++) {
        monitorRect = monitorRect.expandToInclude(_displayRect(allDisplays[i]));
        outputs.add(i);
      }
    } else {
      if (nMonitor < allDisplays.length) {
        for (int i = 0; i < allDisplays.length; i++) {
          if (nMonitor == i) {
            monitorRect = _displayRect(allDisplays[i]);
            outputs.add(i);
            break;
          }
        }
      }
    }

    if (monitorRect.isEmpty &&
        allDisplays.isNotEmpty &&
        AppGlobal.multiMonitor != 99) {
      monitorRect = _displayRect(allDisplays[0]);
    }
    monitorRect = _normalizeRect(monitorRect);
    if (outputs.isEmpty) {
      outputs.add(0);
    }
    logD(
        '''GetMonitorInfo Output:'${AppGlobal.output}'; rect:'$monitorRect'; Skin: '$skinCode', allDisplays: '${allDisplays.toString()}'.''');
  }

  Rect _displayRect(Display display) {
    /*double left = 0,
        top = 0,
        width = display.size.width,
        height = display.size.height;
    if (display.visiblePosition != null) {
      left = display.visiblePosition!.dx;
      top = display.visiblePosition!.dy;
    }
    if (display.visibleSize != null) {
      width = display.visibleSize!.width;
      height = display.visibleSize!.height;
    }*/

    return Rect.fromLTWH(display.position.dx, display.position.dy,
        display.size.width, display.size.height);
  }

  Rect _fitToSize(Size source, Rect target, [bool bOffset = false]) {
    if (source.width <= 0 || source.height <= 0) {
      return target;
    }
    final ratio =
        min(target.width / source.width, target.height / source.height);
    final width = source.width * ratio;
    final height = source.height * ratio;
    var left = (target.width - width) / 2;
    var top = (target.height - height) / 2;
    if (bOffset) {
      left += target.left;
      top += target.top;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  Rect _stringToRect(String s) {
    final parts =
        s.split(',').map((item) => int.tryParse(item.trim()) ?? 0).toList();
    if (parts.length < 4) return Rect.zero;
    return _normalizeRect(Rect.fromLTRB(
      parts[0].toDouble(),
      parts[1].toDouble(),
      parts[2].toDouble(),
      parts[3].toDouble(),
    ));
  }

  Rect _normalizeRect(Rect rect) {
    final left = min(rect.left, rect.right);
    final right = max(rect.left, rect.right);
    final top = min(rect.top, rect.bottom);
    final bottom = max(rect.top, rect.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _validFilePath(String path) {
    if (path.isEmpty) return false;
    return File(path).existsSync();
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  // Optional compatibility fields
  int btnWidth2 = 0;
  int btnHeight2 = 0;
  int btnSpace2 = 0;
}

final playSkin = AppSkinSetting.instance;
