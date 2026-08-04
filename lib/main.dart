import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/keymap_helper.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/netdef.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/content_sync_background_service.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/pages/multi_partition_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nativeapi/nativeapi.dart' as display_manager;
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:dcm/backend/services/app_watchdog.dart';

const String kContentSyncPlayerRefreshPortName =
    'content_sync_player_refresh_port';

final localhostServer = InAppLocalhostServer(documentRoot: 'assets');
WebViewEnvironment? webViewEnvironment;
Size primaryDisplaySize = const Size(1920, 1080);
final ReceivePort _contentSyncPlayerRefreshPort = ReceivePort();

void _registerContentSyncPlayerRefreshPort() {
  IsolateNameServer.removePortNameMapping(kContentSyncPlayerRefreshPortName);
  IsolateNameServer.registerPortWithName(
    _contentSyncPlayerRefreshPort.sendPort,
    kContentSyncPlayerRefreshPortName,
  );

  _contentSyncPlayerRefreshPort.listen((message) {
    MessageInfo? messageInfo;
    try {
      messageInfo = MessageInfo.fromJson(jsonDecode(message));
      logI(
          '''ContentSyncPlayerRefreshPort; Command: '${messageInfo.messageID}'; Type: '${messageInfo.status}'; content: '${messageInfo.messageName}'.''');
    } catch (e) {
      logE('''ContentSyncPlayerRefreshPort receive: '$message', error: $e''');
    }
    if (messageInfo != null) {
      if (messageInfo.messageID == PlayerNotice.eSyncFINISHEDNOTICE.index) {
        final playerScreenProvider = PlayerScreenProvider.instance;
        if (playerScreenProvider != null) {
          playerScreenProvider.onMessageAH(messageInfo.messageID,
              messageInfo.status, messageInfo.messageName);
        }
      }
    }
  });
}

void main(List<String> arguments) async {
  if (await AppWatchdog.runParentIfNeeded(arguments)) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  WakelockPlus.enable();

  await App().init();
  _registerContentSyncPlayerRefreshPort();
  workerManager.log = true;
  await workerManager.init(dynamicSpawning: true);
  await ContentSyncBackgroundService.instance.init();
  await L10n.init();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(availableVersion != null,
        'Failed to find an installed WebView2 runtime or non-stable Microsoft Edge installation.');

    webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
            userDataFolder: path.join(App().dataPath, 'webviewsettings')));
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  // On desktop, initialize window_manager and force fullscreen on primary display
  if (PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();
    final displayManager = display_manager.DisplayManager.instance;
    final primaryDisplay = displayManager.getPrimary();
    //final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    if (primaryDisplay != null) {
      primaryDisplaySize = primaryDisplay.size;
    }
    logD(
        'main - uniqueKey: ${App().uniqueKey}, windowSize: ${primaryDisplaySize.width * windowManager.getDevicePixelRatio()}x${primaryDisplaySize.height * windowManager.getDevicePixelRatio()}, DevicePixelRatio: ${windowManager.getDevicePixelRatio()}');
    WindowOptions windowOptions = WindowOptions(
      //size: Size(0, 0),
      center: false,
      //minimumSize: Size(0, 0),
      backgroundColor: Utils.fromRGB(AppGlobal.clrBGColor),
      titleBarStyle: TitleBarStyle.hidden,
      fullScreen: false,
      skipTaskbar: true,
      alwaysOnTop: kDebugMode ? false : true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      //await windowManager.setFullScreen(true);
      //await windowManager.setAlwaysOnTop(true);
      await windowManager.setAsFrameless();
      await windowManager.setBounds(Rect.fromLTWH(
          0, 0, primaryDisplaySize.width, primaryDisplaySize.height));
      await windowManager.show();
      await windowManager.focus();
      DigitalSignageScreen.refresh?.call();
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
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerScreenProvider()),
      ],
      child: const DigitalSignageApp(),
    ),
  );
}
