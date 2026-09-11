import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/net/netdef.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/app_skin_impl.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/pages/home.dart';
import 'package:dcm/pages/initial_setup_page.dart';
import 'package:dcm/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:worker_manager/worker_manager.dart';

const String kContentSyncCommandPortName = 'content_sync_command_port';
void _notifyContentSyncIsolateCommand(int nCmd, int ntype, [String? content]) {
  final SendPort? sendPort =
      IsolateNameServer.lookupPortByName(kContentSyncCommandPortName);
  logI(
      'multi_partition_screen _notifyContentSyncIsolateCommand: sendPort ${sendPort != null}, nCmd: $nCmd, ntype: $ntype, content: $content');
  var messageInfo = MessageInfo();
  messageInfo.messageID = nCmd;
  messageInfo.status = ntype;
  messageInfo.messageName = content ?? '';
  String msgInfo = jsonEncode(messageInfo.toJson());
  sendPort?.send(msgInfo);
}

class DigitalSignageApp extends StatelessWidget {
  const DigitalSignageApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return MaterialApp(
      shortcuts: {
        // override the default behavior of arrow and space key
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const NoOpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const NoOpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const NoOpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const NoOpIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const NoOpIntent(),
      },
      actions: {
        // bind Intent to NoOpAction
        NoOpIntent: NoOpAction(),
      },
      title: 'Digital Signage Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: App().needsInitialSetup
          ? InitialSetupPage(
              onCompleted: (context) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const DigitalSignageScreen(),
                  ),
                );
              },
            )
          : const DigitalSignageScreen(),
    );
  }
}

class DigitalSignageScreen extends StatefulWidget {
  const DigitalSignageScreen({Key? key}) : super(key: key);

  @override
  State<DigitalSignageScreen> createState() => _DigitalSignageScreenState();

  static void Function()? refresh;
}

bool shouldTriggerDoubleTapExit({
  required DateTime now,
  required DateTime? lastTap,
  required Duration window,
  required bool mounted,
  required bool isExiting,
}) {
  if (!mounted || isExiting || lastTap == null) {
    return false;
  }
  return now.difference(lastTap) <= window;
}

class _DigitalSignageScreenState extends State<DigitalSignageScreen> {
  int currentShowIndex = 0;
  int nextShowIndex = 0;
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  static const Duration _menuTimeout = Duration(seconds: 5);
  final _focusNode = FocusNode();
  Timer? _menuTimer;
  DateTime? _lastTap;
  bool _showMenu = false;
  bool _isExiting = false;
  bool _forceRebuild = false;

  @override
  void initState() {
    super.initState();
    _hideSystemUI();
    DigitalSignageScreen.refresh = () => setState(() => _forceRebuild = true);
    // Preload uses `context` (e.g. `precacheImage`), so run it after
    // the first frame to avoid accessing InheritedWidgets during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlayerScreenProvider>(context, listen: false).playImm();
      _focusNode.requestFocus();
      //_preloadAllContents();
    });

    //_startPlaylist();
  }

  // 隐藏系统UI元素
  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  Future<void> _exitApplication() async {
    logI('multi_partition_screen _exitApplication: _isExiting $_isExiting');
    if (!mounted || _isExiting) {
      return;
    }

    _isExiting = true;
    _menuTimer?.cancel();
    PlayerScreenProvider.instance?.release();
    _notifyContentSyncIsolateCommand(PlayerNotice.ePLAYCLOSENOTICE.index, 0);
    //sleep(const Duration(seconds: 1));
    await Future.delayed(const Duration(seconds: 1)); // Non-blocking delay

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        SystemNavigator.pop();
      } catch (_) {
        exit(0);
      }
    } else {
      exit(0);
    }
  }

  void _showFloatingMenu() {
    if (!mounted || _isExiting) return;
    _menuTimer?.cancel();
    setState(() => _showMenu = true);
    _menuTimer = Timer(_menuTimeout, _hideFloatingMenu);
  }

  void _hideFloatingMenu() {
    _menuTimer?.cancel();
    if (mounted) {
      setState(() => _showMenu = false);
    }
  }

  Future<void> _openSettings() async {
    _hideFloatingMenu();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _reinitialize() async {
    _hideFloatingMenu();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InitialSetupPage(
          reloadSettings: true,
          onCompleted: (context) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const DigitalSignageScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleScreenTap() async {
    if (!mounted || _isExiting) {
      return;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final now = DateTime.now();
    final lastTap = _lastTap;
    _lastTap = now;

    if (shouldTriggerDoubleTapExit(
      now: now,
      lastTap: lastTap,
      window: _doubleTapWindow,
      mounted: mounted,
      isExiting: _isExiting,
    )) {
      _showFloatingMenu();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _exitApplication();
    }
  }

  // Handle the platform back action separately from the on-screen menu.
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    await _exitApplication();
  }

  @override
  void dispose() {
    logI('multi_partition_screen dispose');
    _isExiting = true;
    _menuTimer?.cancel();
    _focusNode.dispose();
    workerManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_forceRebuild) {
      _forceRebuild = false;
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    }

    double screenWidth;
    double screenHeight;
    final mq = MediaQuery.of(context);
    logD(
        'multi_partition_screen - MediaQuery size: (${mq.size.width} x ${mq.size.height}), devicePixelRatio: ${mq.devicePixelRatio}, _forceRebuild: $_forceRebuild');
    if (playSkin.monitorRect.isEmpty) {
      playSkin.setMonitorRect(mq.size);
      screenWidth = mq.size.width;
      screenHeight = mq.size.height;
    } else {
      screenWidth = playSkin.monitorRect.width;
      screenHeight = playSkin.monitorRect.height;
    }
    logD(
        'multi_partition_screen - main screen size: ($screenWidth x $screenHeight), player screen size: (${playSkin.monitorRect.width} x ${playSkin.monitorRect.height})');

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: _onPopInvokedWithResult,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleScreenTap,
          child: Scaffold(
            backgroundColor: Utils.fromRGB(AppGlobal.clrBGColor),
            body: Consumer<PlayerScreenProvider>(
              builder:
                  (BuildContext context, playerScreenProvider, Widget? child) {
                if (!playerScreenProvider.isValidForPlay()) {
                  return Container(
                    color: Utils.fromRGB(AppGlobal.clrBGColor),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Stack(
                        children: <Widget>[
                          Builder(
                            builder: (context) {
                              final currentLayout =
                                  playerScreenProvider.getPlayingZones();

                              return Stack(
                                children: currentLayout.map((partition) {
                                  final left = partition.getRect().left;
                                  final top = partition.getRect().top;
                                  final w = partition.getRect().width;
                                  final h = partition.getRect().height;
                                  /*var left = 0.00;
                                var top = 0.00;
                                var w = mq.size.width / 2;
                                var h = mq.size.height;
                                if (partition.getZone() > 0) {
                                  left = mq.size.width / 2;
                                  top = 0;
                                  w = mq.size.width / 2;
                                  h = mq.size.height;
                                }*/

                                  logD(
                                      'multi_partition_screen - Render partition ${partition.getZone()} at ($left, $top) with size ($w x $h)');

                                  return Positioned(
                                    left: left,
                                    top: top,
                                    width: w,
                                    height: h,
                                    child: Container(
                                      width: w,
                                      height: h,
                                      decoration: BoxDecoration(
                                        color:
                                            Utils.fromRGB(AppGlobal.clrBGColor),
                                        border: null,
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      child: SizedBox(
                                        width: w,
                                        height: h,
                                        child: partition.renderZone(),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          if (_showMenu)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 32,
                              child: Center(
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _menuButton(Icons.settings_outlined,
                                            '设置'.l10n, _openSettings),
                                        _menuButton(Icons.refresh, '重新初始化'.l10n,
                                            _reinitialize),
                                        _menuButton(Icons.exit_to_app,
                                            '退出'.l10n, _exitApplication),
                                        _menuButton(Icons.arrow_back, '返回'.l10n,
                                            _hideFloatingMenu),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton(IconData icon, String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

// 分区配置类，使用像素定义位置与大小
class PartitionConfig {
  final int id;
  final int type;
  final String content; // URL、文件路径或文本内容
  final int x;
  final int y;
  final int width;
  final int height;

  PartitionConfig({
    required this.id,
    required this.type,
    required this.content,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

// 内容类型枚举
enum ContentType {
  video,
  image,
  text,
  scrollText,
  html,
  liveInfo,
  slideshow,
  empty, // 空分区
}

// 播放列表项
class PlaylistItem {
  final String name;
  final int duration; // 播放持续时间（秒）
  final List<PartitionConfig> layout;

  PlaylistItem({
    required this.name,
    required this.duration,
    required this.layout,
  });
}
