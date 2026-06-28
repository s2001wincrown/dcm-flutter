import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/dcm_skin_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
}

class _DigitalSignageScreenState extends State<DigitalSignageScreen> {
  int currentShowIndex = 0;
  int nextShowIndex = 0;
  Timer? _exitHintTimer;
  DateTime? _lastTap;
  bool _exitHintShown = false;
  bool _showExitHint = false;

  @override
  void initState() {
    super.initState();
    _hideSystemUI();
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
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  void _handleExitTapDown() {
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _lastTap = now;
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
  }

  // 双击退出功能
  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    _exitApplication();
  }

  @override
  void dispose() {
    logI('multi_partition_screen dispose');
    _exitHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth;
    double screenHeight;
    if (playSkin.monitorRect.isEmpty) {
      final mq = MediaQuery.of(context);
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
        onTap: () {
          // 单击重置系统UI隐藏计时器
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onTapDown: (_) => _handleExitTapDown(),
        onDoubleTap: _exitApplication,
        child: Scaffold(
          backgroundColor: Color(DCMGlobal.clrBGColor),
          body: Consumer<PlayerScreenProvider>(
            builder:
                (BuildContext context, playerScreenProvider, Widget? child) {
              if (!playerScreenProvider.isValidForPlay()) {
                return Container(
                  color: Color(DCMGlobal.clrBGColor),
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
                                playerScreenProvider.getPlayerZones();

                            return Stack(
                              children: currentLayout.map((partition) {
                                final left = partition.rect!.left;
                                final top = partition.rect!.top;
                                final w = partition.rect!.width;
                                final h = partition.rect!.bottom;
                                /*logD(
                                    'multi_partition_screen - Render partition ${partition.getZone()} at ($left, $top) with size ($w x $h)');*/

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: w,
                                  height: h,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(DCMGlobal.clrBGColor),
                                      border: null,
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: partition.renderZone(),
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
