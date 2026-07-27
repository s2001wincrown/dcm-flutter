import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/app_skin_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:provider/provider.dart';

class DigitalSignageApp extends StatelessWidget {
  const DigitalSignageApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      home: const DigitalSignageScreen(),
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
  Timer? _exitHintTimer;
  DateTime? _lastTap;
  bool _exitHintShown = false;
  bool _showExitHint = false;
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
      //_preloadAllContents();
    });
    /*final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.setPosition(0, 0);
      window.setSize(primaryDisplaySize.width, primaryDisplaySize.height);
    }*/
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

  void _exitApplication() {
    if (!mounted || _isExiting) {
      return;
    }

    _isExiting = true;
    _exitHintTimer?.cancel();

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

  void _handleExitTap() {
    if (!mounted || _isExiting) {
      return;
    }

    final windows = WindowManager.instance.getAll();
    for (var window in windows) {
      logD(
          'WindowManager::getAll, position: ${window.position}, ${window.size}'); //, title: ${window.title}, id: ${window.id}
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
      _exitApplication();
      return;
    }

    if (!_exitHintShown) {
      _exitHintShown = true;
      _showExitHint = true;
      _exitHintTimer?.cancel();
      _exitHintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showExitHint = false;
            _exitHintShown = false;
          });
        }
      });
      if (mounted) {
        setState(() {});
      }
    }
  }

  // 双击退出功能
  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    _exitApplication();
  }

  @override
  void dispose() {
    logI('multi_partition_screen dispose');
    _isExiting = true;
    _exitHintTimer?.cancel();
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
        'multi_partition_screen - MediaQuery size: (${mq.size.width} x ${mq.size.height}), _forceRebuild: $_forceRebuild');
    if (playSkin.monitorRect.isEmpty) {
      screenWidth = mq.size.width;
      screenHeight = mq.size.height;
    } else {
      screenWidth = playSkin.monitorRect.width;
      screenHeight = playSkin.monitorRect.height;
    }
    logD(
        'multi_partition_screen - main screen size: ($screenWidth x $screenHeight), player screen size: (${playSkin.monitorRect.width} x ${playSkin.monitorRect.height})');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleExitTap,
        child: Scaffold(
          backgroundColor: Colors.red, //Color(AppGlobal.clrBGColor),
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

                                /*logD(
                                    'multi_partition_screen - Render partition ${partition.getZone()} at ($left, $top) with size ($w x $h)');*/

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: w,
                                  height: h,
                                  child: Container(
                                    width: w,
                                    height: h,
                                    decoration: const BoxDecoration(
                                      color: Colors
                                          .blue, //Utils.fromRGB(AppGlobal.clrBGColor),
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
                        if (_showExitHint)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 32,
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: _showExitHint ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app,
                                          color: Colors.black87),
                                      SizedBox(width: 10),
                                      Text(
                                        '双击屏幕退出应用',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
