import 'dart:io';

import 'package:dcm/pages/multi_partition_screen.dart';
import 'package:flutter/material.dart';
import 'package:dcm/backend/keymap_helper.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';

import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
import 'package:dcm/pages/home.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  WakelockPlus.enable();

  await App().init();
  await L10n.init();

  var _primaryDisplay = await screenRetriever.getPrimaryDisplay();
  var _displayList = await screenRetriever.getAllDisplays();
  var windowSize = _primaryDisplay.size;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      minimumSize: const Size(700, 500),
      size: windowSize,
      alwaysOnTop: true,
      // fullScreen: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  KeyMapHelper.init();

  if (arguments.isNotEmpty) {
    String mediaToOpen = arguments[0];
    App().openMedia(await LibraryHelper.getItemFromFile(mediaToOpen));
    runApp(const HomePage(playerView: true));
  } else {
    runApp(const HomePage(playerView: false));
  }
  //runApp(const DigitalSignageApp());
}
