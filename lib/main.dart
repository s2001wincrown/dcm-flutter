import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/keymap_helper.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/platform_utils.dart';
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

final localhostServer = InAppLocalhostServer(documentRoot: 'assets');
WebViewEnvironment? webViewEnvironment;
void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  WakelockPlus.enable();

  await App().init();
  //await DcmBackgroundService.instance.init();
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
    final windowSize = primaryDisplay!.size;
    logD('main - windowSize: $windowSize');
    WindowOptions windowOptions = WindowOptions(
      size: windowSize,
      center: false,
      minimumSize: const Size(700, 500),
      backgroundColor: Colors.black,
      titleBarStyle: TitleBarStyle.hidden,
      fullScreen: true,
      skipTaskbar: true,
      alwaysOnTop: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      /*await windowManager.setBounds(
        Rect.fromLTWH(0, 0, windowSize.width, windowSize.height),
      );*/
      await windowManager.setFullScreen(true);
      //await windowManager.setAlwaysOnTop(true);
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
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerScreenProvider()),
      ],
      child: const DigitalSignageApp(),
    ),
  );
}
