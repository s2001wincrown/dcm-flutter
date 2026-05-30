import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/pages/home.dart';
import 'package:dcm/widgets/basic_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dcm/backend/library_helper.dart';

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
  // 示例播放列表 - 实际项目中可以从配置文件加载
  List<PlaylistItem> playlist = [
    PlaylistItem(
      name: 'Sample Show 1',
      duration: 30,
      layout: [
        PartitionConfig(
          id: 1,
          type: ContentType.video,
          content:
              // 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
              'D:/dc-data/data/P1920-1.mp4',
          x: 0,
          y: 0,
          width: 1280,
          height: 720,
        ),
        PartitionConfig(
          id: 2,
          type: ContentType.image,
          content:
              'https://workspace-zb-cdn.quark.cn/a4f3a529b8864f648dbd66882dd7c0f3%2Fo%2F1773978786572.png?auth_key=1805515380-0-0-5a17cd1b8a1c94658c52a06ea2a9f98a',
          x: 1280,
          y: 0,
          width: 640,
          height: 360,
        ),
        PartitionConfig(
          id: 3,
          type: ContentType.text,
          content: 'Welcome to Digital Signage!',
          x: 1280,
          y: 360,
          width: 640,
          height: 360,
        ),
      ],
    ),
    PlaylistItem(
      name: 'Sample Show 2',
      duration: 20,
      layout: [
        PartitionConfig(
          id: 1,
          type: ContentType.html,
          content: '<h1>Live News Feed</h1><p>Latest updates here...</p>',
          x: 0,
          y: 0,
          width: 1920,
          height: 540,
        ),
        PartitionConfig(
          id: 2,
          type: ContentType.scrollText,
          content:
              'This is a scrolling text message that demonstrates the scroll text functionality in the digital signage system.',
          x: 0,
          y: 540,
          width: 1920,
          height: 540,
        ),
      ],
    ),
    PlaylistItem(
      name: 'Sample Show 3',
      duration: 25,
      layout: [
        PartitionConfig(
          id: 1,
          type: ContentType.slideshow,
          content:
              'https://picsum.photos/800/600,https://picsum.photos/800/601,https://picsum.photos/800/602',
          x: 0,
          y: 0,
          width: 1920,
          height: 720,
        ),
        PartitionConfig(
          id: 2,
          type: ContentType.liveInfo,
          content: 'Current Time',
          x: 0,
          y: 720,
          width: 1920,
          height: 360,
        ),
      ],
    ),
  ];

  int currentShowIndex = 0;
  int nextShowIndex = 0;
  Timer? _timer;
  Timer? _exitHintTimer;
  DateTime? _lastTap;
  bool _exitHintShown = false;
  bool _showExitHint = false;
  bool _isLoadingNext = false;
  final Map<int, List<PreloadedContent>> _preloadedContents = {};

  String? _strDCMFile;
  bool _bValidForPlay = false;
  bool _bScreenLayoutChanged = false;
  bool _bDisplayChanged = false;
  bool _bIsTouchScreen = false;
  bool _bIsSameSkin = false;

  @override
  void initState() {
    super.initState();
    _hideSystemUI();
    // Preload uses `context` (e.g. `precacheImage`), so run it after
    // the first frame to avoid accessing InheritedWidgets during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAllContents();
    });
    _startPlaylist();
  }

  // 隐藏系统UI元素
  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  // 预加载所有内容
  void _preloadAllContents() async {
    for (int i = 0; i < playlist.length; i++) {
      await _preloadContentForShow(i);
    }
  }

  // 预加载特定节目的内容
  Future<void> _preloadContentForShow(int showIndex) async {
    final show = playlist[showIndex];
    List<PreloadedContent> preloaded = [];

    for (final partition in show.layout) {
      switch (partition.type) {
        case ContentType.video:
          final player = Player(
            configuration: const PlayerConfiguration(
              title: 'dcm',
              osc: false,
              muted: false,
              async: true,
              libass: false,
              logLevel: MPVLogLevel.error,
            ),
          );

          final video =
              Media(LibraryHelper.normalizeMediaSource(partition.content));
          player.open(video, play: App().settings.autoPlay);

          final controller = VideoController(
            player,
            configuration: const VideoControllerConfiguration(
              width: 800,
              height: 600,
            ),
          );
          player.setVolume(App().settings.volume);
          preloaded.add(PreloadedContent(
              type: ContentType.video, controller: controller));
          /*if (partition.content.startsWith('http')) {
            final controller = BasicVideoController.networkUrl(
              Uri.parse(
                'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
              ),
            )..initialize().then((_) {
                // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
                setState(() {});
              });
            preloaded.add(PreloadedContent(
                type: ContentType.video, controller: controller));
          } else {
            final controller =
                BasicVideoController.file(File(partition.content));
            await controller.initialize();
            preloaded.add(PreloadedContent(
                type: ContentType.video, controller: controller));
          }*/
          break;
        case ContentType.image:
          if (partition.content.startsWith('http')) {
            await precacheImage(NetworkImage(partition.content), context);
          } else {
            await precacheImage(FileImage(File(partition.content)), context);
          }
          preloaded.add(PreloadedContent(
              type: ContentType.image, imagePath: partition.content));
          break;
        case ContentType.text:
        case ContentType.scrollText:
        case ContentType.html:
        case ContentType.liveInfo:
          // 文本类内容不需要预加载
          preloaded.add(
              PreloadedContent(type: partition.type, text: partition.content));
          break;
        case ContentType.slideshow:
          final images = partition.content.split(',');
          for (final imageUrl in images) {
            if (imageUrl.trim().startsWith('http')) {
              await precacheImage(NetworkImage(imageUrl.trim()), context);
            } else {
              await precacheImage(FileImage(File(imageUrl.trim())), context);
            }
          }
          preloaded.add(PreloadedContent(
              type: ContentType.slideshow,
              images: images.map((e) => e.trim()).toList()));
          break;
        default:
          preloaded.add(PreloadedContent(type: partition.type));
      }
    }

    _preloadedContents[showIndex] = preloaded;
  }

  // 预先加载下一个节目的内容
  void _preloadNextShow() async {
    if (_isLoadingNext) return;

    _isLoadingNext = true;
    nextShowIndex = (currentShowIndex + 1) % playlist.length;

    // 预加载下一个节目的内容
    if (!_preloadedContents.containsKey(nextShowIndex)) {
      await _preloadContentForShow(nextShowIndex);
    }

    _isLoadingNext = false;
  }

  void _startPlaylist() {
    if (playlist.isNotEmpty) {
      _playCurrentShow();
      _preloadNextShow(); // 预加载下一个节目
    }
  }

  void _playCurrentShow() {
    setState(() {}); // 更新UI

    // 设置定时器切换到下一个节目
    _timer?.cancel();
    _timer = Timer(Duration(seconds: playlist[currentShowIndex].duration), () {
      currentShowIndex = (currentShowIndex + 1) % playlist.length;
      _playCurrentShow();
      _preloadNextShow(); // 预加载新的下一个节目
    });
  }

  void readyForPlay() {
    bool bCanPlay = loadPlayerState();
    if (!bCanPlay) {
      StringBuffer strDCMFile = StringBuffer();
      if (ScheduleList().playFileList(strDCMFile)) {
        _strDCMFile = strDCMFile.toString();
        if (loadCatalogue(_strDCMFile!, true)) {
          bCanPlay = ScheduleList().isCatalogueCanPlay();
        }

        if (!bCanPlay) {
          if (ScheduleList().count>1) {
            while (true) {
               if (ScheduleList().playNextFile(strDCMFile)){
                //if (ScheduleList().LoadCatalogue(strDCMFile))
                if (loadCatalogue(strDCMFile.toString(), true)) {
                  if (ScheduleList().isCatalogueCanPlay()) {
                    bCanPlay = true;
                    _strDCMFile = strDCMFile.toString();
                    break;
                  }
                }
              }

              if (!bCanPlay) {
                sleep(const Duration(seconds: 1));
              }
            }
          }
        }
        ScheduleList().setPlayTimes();
      }
    }
    _bValidForPlay = bCanPlay;
  }

  bool loadPlayerState() {
    if (DCMGlobal.playStartPoint != 0) {
      if (ScheduleList().loadState()) {
        StringBuffer strDCMFile = StringBuffer();
        if (ScheduleList().playCurrFile(strDCMFile)) {
          _strDCMFile = strDCMFile.toString();
          if (loadCatalogue(_strDCMFile!)) {
            if (ScheduleList().isCatalogueCanPlay()) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  bool loadCatalogue(String strDCMFile, [bool bStart = false]) {
    String strOldLayout = '';
    String strCurrSkin = '';
    int nOldScreen = 0;
    int nTotalZone1 = 0;
    if (!bStart) {
      strCurrSkin = ScheduleList().getCatalogue().strSkinCode;
      strOldLayout = ScheduleList().getCatalogue().strLayoutName;
      nOldScreen = ScheduleList().getCatalogue().nScreenType;
      nTotalZone1 = ScheduleList().getTotalZones();
    }

    if (ScheduleList().loadCatalogue(strDCMFile)) {
      int nTotalZone = ScheduleList().getTotalZones();
      if (nTotalZone <= 0 || nTotalZone > 10000) {
        return false;
      }

      if (ScheduleList().hasContentType()) {
        sendSerialMSG('2!\r\n');
      }
      _bIsSameSkin = (strCurrSkin == ScheduleList().getCatalogue().strSkinCode && !_bDisplayChanged);
      String strOldTouch = PlaySkin._strDCMFile;
      if (!_bIsSameSkin)
        PlaySkin.LoadSkins(&ScheduleList().getCatalogue());
      
      //WriteMessage(MSG_INFO, 'CPlayerScreenDlg::LoadCatalogue Step: %d, DCMFile:'%s'; last Zone Number:'%d'; Now Zone Number:'%d'; Current TID: %d!!!', 
      //	0, strDCMFile, nTotalZone1, nTotalZone, GetCurrentThreadId());
      bool bIsTwoWindows = PlaySkin.m_bIsTwoWindows;
      bool bIsAutoHide = PlaySkin.m_bIsAutoHidePopWindow;
      if (!bIsTwoWindows || !bIsAutoHide
        || (bIsTwoWindows && bIsAutoHide && strOldTouch.CompareNoCase(PlaySkin._strDCMFile) != 0))
      {
        DeleteTouchScreen();
      }
      
      if (_bIsTouchScreen) {
        CRect rect(0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
        PlaySkin.SetTouchScreen(true);
        PlaySkin.SetTouchScreenRect(rect);
      }
      if (!_bIsSameSkin) {
        LoadSkinSetting();
        //UpdateFrame();
        ReCalcPlayerRect();
      }
      String strCompany = ScheduleList().getCurrCompany();
      PlayMusic(strCompany);
      ResetZoneRect(nTotalZone);

      _bScreenLayoutChanged = (_bDisplayChanged || ScheduleList().getCatalogue().strLayoutName != strOldLayout 
        || ScheduleList().getCatalogue().nScreenType != nOldScreen);
      _bDisplayChanged = false;
      //WriteMessage(MSG_INFO, 'CPlayerScreenDlg::LoadCatalogue Step: %d, Current TID: %d!!!', 3, GetCurrentThreadId());
      ScheduleList().setPlayTimes();
      _strDCMFile = strDCMFile;
      //WriteMessage(MSG_INFO, 'CPlayerScreenDlg::LoadCatalogue Step: %d, Current TID: %d!!!', 4, GetCurrentThreadId());
      return true;
    }

    return false;
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
    // 释放所有预加载的内容
    for (final entry in _preloadedContents.entries) {
      for (final content in entry.value) {
        if (content.player != null) {
          content.player!.dispose();
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double designWidth = 1920.0;
    const double designHeight = 1080.0;

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
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final mq = MediaQuery.of(context);
              final double screenWidth = mq.size.width;
              final double screenHeight = mq.size.height;

              return SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: Stack(
                  children: <Widget>[
                    Builder(
                      builder: (context) {
                        if (playlist.isEmpty ||
                            playlist[currentShowIndex].layout.isEmpty) {
                          return const Center(
                            child: Text(
                              'No Content to Display',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 24),
                            ),
                          );
                        }

                        final currentLayout = playlist[currentShowIndex].layout;

                        final double scaleX = screenWidth / designWidth;
                        final double scaleY = screenHeight / designHeight;
                        final double scale = math.min(scaleX, scaleY);

                        final double offsetX =
                            (screenWidth - designWidth * scale) / 2.0;
                        final double offsetY =
                            (screenHeight - designHeight * scale) / 2.0;

                        return Stack(
                          children: currentLayout.map((partition) {
                            final left = offsetX + partition.x * scale;
                            final top = offsetY + partition.y * scale;
                            final w = partition.width * scale;
                            final h = partition.height * scale;

                            return Positioned(
                              left: left,
                              top: top,
                              width: w,
                              height: h,
                              child: Container(
                                margin: const EdgeInsets.all(0.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  border:
                                      Border.all(color: Colors.grey, width: 0),
                                  borderRadius: BorderRadius.circular(0.0),
                                ),
                                child: _buildPartitionContent(partition),
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
                                  Icon(Icons.touch_app, color: Colors.black87),
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
          ),
        ),
      ),
    );
  }

  Widget _buildPartitionContent(PartitionConfig config) {
    // 尝试从预加载内容中获取对应的控制器或资源
    final preloadedList = _preloadedContents[currentShowIndex];
    if (preloadedList != null) {
      final preloaded = preloadedList.firstWhere(
        (element) => element.type == config.type,
        orElse: () => PreloadedContent(type: ContentType.empty),
      );

      if (preloaded.controller != null && preloaded.player != null) {
        // 视频内容使用预加载的控制器
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BasicVideo(controller: preloaded.controller!),
        );
      }
    }

    // 如果没有预加载，则按需创建
    switch (config.type) {
      case ContentType.video:
        if (config.content.startsWith('http')) {
          return VideoPartition(url: config.content);
        } else {
          return VideoPartition(file: File(config.content));
        }
      case ContentType.image:
        if (config.content.startsWith('http')) {
          return Image.network(config.content, fit: BoxFit.cover);
        } else {
          return Image.file(File(config.content), fit: BoxFit.cover);
        }
      case ContentType.text:
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: Text(
            config.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
      case ContentType.scrollText:
        return ScrollText(text: config.content);
      case ContentType.html:
        return HtmlPartition(html: config.content);
      case ContentType.liveInfo:
        return LiveInfoPartition(info: config.content);
      case ContentType.slideshow:
        return SlideshowPartition(
            imageUrls: config.content.split(',')); // 假设图片URL用逗号分隔
      default:
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.error, color: Colors.red),
          ),
        );
    }
  }
}

// 预加载内容类
class PreloadedContent {
  final ContentType type;
  final VideoController? controller;
  final Player? player;
  final String? imagePath;
  final String? text;
  final List<String>? images;

  PreloadedContent({
    required this.type,
    this.controller,
    this.player,
    this.imagePath,
    this.text,
    this.images,
  });
}

// 分区配置类，使用像素定义位置与大小
class PartitionConfig {
  final int id;
  final ContentType type;
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
    //_player.dispose();
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
