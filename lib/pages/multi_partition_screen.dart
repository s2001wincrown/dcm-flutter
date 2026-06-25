import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/dcm_skin_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/pages/home.dart';
import 'package:dcm/widgets/basic_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  Timer? _timer;
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
    _timer?.cancel();
    _exitHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  logD('Main windows size: $screenWidth x $screenHeight');

                  return SizedBox(
                    width: screenWidth,
                    height: screenHeight,
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
                                    'Render partition ${partition.getZone()} at ($left, $top) with size ($w x $h)');*/

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

// 视频播放分区
class VideoPartition extends StatefulWidget {
  final String? url;
  final File? file;

  const VideoPartition({this.url, this.file});

  @override
  State<VideoPartition> createState() => _VideoPartitionState();
}

class _VideoPartitionState extends State<VideoPartition> {
  late VideoController _controller;
  late Player _player;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    /*if (widget.url != null) {
      _controller = VideoController(
        _player,
      );
    } else if (widget.file != null) {
      _controller = VideoController(
        _player,
      );
    } else {
      throw ArgumentError('Either url or file must be provided');
    }*/

    _initializeController();
  }

  Future<void> _initAndPlay() async {
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

    final source = widget.url != null ? widget.url! : widget.file!.path;
    final video = Media(LibraryHelper.normalizeMediaSource(source));
    _player.open(video, play: App().settings.autoPlay);

    _controller = VideoController(_player);
    _player.setVolume(App().settings.volume);
  }

  void _initializeController() async {
    try {
      /*await _controller.initialize();
      _controller.setLooping(true);
      _controller.play();*/
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

      final source = widget.url != null ? widget.url! : widget.file!.path;
      final video = Media(LibraryHelper.normalizeMediaSource(source));
      _player.open(video, play: App().settings.autoPlay);

      _controller = VideoController(
        _player,
        configuration: const VideoControllerConfiguration(
          width: 800,
          height: 600,
        ),
      );
      _player.setVolume(App().settings.volume);
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BasicVideo(controller: _controller),
    );
  }
}

// 滚动文本分区
class ScrollText extends StatefulWidget {
  final String text;

  const ScrollText({required this.text});

  @override
  State<ScrollText> createState() => _ScrollTextState();
}

class _ScrollTextState extends State<ScrollText> {
  late ScrollController _scrollController;
  double _position = 0.0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startScrolling();
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;

        if (currentScroll >= maxScroll) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _scrollController.jumpTo(currentScroll + 1);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// HTML内容分区 (简化实现)
class HtmlPartition extends StatelessWidget {
  final String html;

  const HtmlPartition({required this.html});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HTML Content',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                html,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 实时信息分区
class LiveInfoPartition extends StatefulWidget {
  final String info;

  const LiveInfoPartition({required this.info});

  @override
  State<LiveInfoPartition> createState() => _LiveInfoPartitionState();
}

class _LiveInfoPartitionState extends State<LiveInfoPartition> {
  String _liveInfo = '';
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _liveInfo = widget.info;
    _startUpdatingInfo();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startUpdatingInfo() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // 这里模拟实时更新数据
      setState(() {
        _liveInfo = '${widget.info} - Updated at ${DateTime.now().toString()}';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Information',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _liveInfo,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 图片幻灯片分区
class SlideshowPartition extends StatefulWidget {
  final List<String> imageUrls;

  const SlideshowPartition({required this.imageUrls});

  @override
  State<SlideshowPartition> createState() => _SlideshowPartitionState();
}

class _SlideshowPartitionState extends State<SlideshowPartition> {
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrls.isNotEmpty) {
      _startSlideshow();
    }
  }

  void _startSlideshow() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.imageUrls.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Text('No images to display'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: FadeInImage.assetNetwork(
        placeholder: 'assets/images/loading.gif', // 需要在pubspec.yaml中添加资源
        image: widget.imageUrls[_currentIndex],
        fit: BoxFit.cover,
        imageErrorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      ),
    );
  }
}
