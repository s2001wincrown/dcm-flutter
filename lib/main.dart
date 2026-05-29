import 'dart:io';

import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/pages/multi_partition_screen.dart';
import 'package:flutter/material.dart';
import 'package:dcm/backend/keymap_helper.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';

import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/services/dcm_background_service.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
import 'package:dcm/pages/home.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  WakelockPlus.enable();

  await App().init();
  await DcmBackgroundService.instance.init();
  await L10n.init();

  // On desktop, initialize window_manager and force fullscreen on primary display
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final windowSize = primaryDisplay.size;
    WindowOptions windowOptions = WindowOptions(
      size: windowSize,
      center: false,
      minimumSize: const Size(700, 500),
      backgroundColor: Colors.black,
      titleBarStyle: TitleBarStyle.hidden,
      fullScreen: true,
      skipTaskbar: true,
      alwaysOnTop: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setBounds(
        Rect.fromLTWH(0, 0, windowSize.width, windowSize.height),
      );
      await windowManager.setFullScreen(true);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  KeyMapHelper.init();

  if (arguments.isNotEmpty) {
    ScheduleList().loadSchedule();
    /*String mediaToOpen = arguments[0];
    App().openMedia(await LibraryHelper.getItemFromFile(mediaToOpen));
    runApp(const HomePage(playerView: true));*/
  } else {
    ScheduleList().loadSchedule();
    //runApp(const HomePage(playerView: false));
  }
  runApp(const DigitalSignageApp());
}
