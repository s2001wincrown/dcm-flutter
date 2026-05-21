import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const DigitalSignageApp());
}

class DigitalSignageApp extends StatelessWidget {
  const DigitalSignageApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          row: 0,
          col: 0,
          rowSpan: 2,
          colSpan: 2,
        ),
        PartitionConfig(
          id: 2,
          type: ContentType.image,
          content:
              'https://workspace-zb-cdn.quark.cn/a4f3a529b8864f648dbd66882dd7c0f3%2Fo%2F1773978786572.png?auth_key=1805515380-0-0-5a17cd1b8a1c94658c52a06ea2a9f98a',
          row: 0,
          col: 2,
          rowSpan: 1,
          colSpan: 2,
        ),
        PartitionConfig(
          id: 3,
          type: ContentType.text,
          content: 'Welcome to Digital Signage!',
          row: 1,
          col: 2,
          rowSpan: 1,
          colSpan: 2,
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
          row: 0,
          col: 0,
          rowSpan: 1,
          colSpan: 4,
        ),
        PartitionConfig(
          id: 2,
          type: ContentType.scrollText,
          content:
              'This is a scrolling text message that demonstrates the scroll text functionality in the digital signage system.',
          row: 1,
          col: 0,
          rowSpan: 1,
          colSpan: 4,
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
          row: 0,
          col: 0,
          rowSpan: 1,
          colSpan: 4,
        ),
        PartitionConfig(
          id: 2,
          type: ContentType.liveInfo,
          content: 'Current Time',
          row: 1,
          col: 0,
          rowSpan: 1,
          colSpan: 4,
        ),
      ],
    ),
  ];

  int currentShowIndex = 0;
  int nextShowIndex = 0;
  Timer? _timer;
  DateTime? _lastTap; // 用于双击检测
  bool _isLoadingNext = false;
  Map<int, List<PreloadedContent>> _preloadedContents = {};

  @override
  void initState() {
    super.initState();
    _hideSystemUI();
    _preloadAllContents();
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
          if (partition.content.startsWith('http')) {
            final controller = VideoPlayerController.network(partition.content);
            await controller.initialize();
            preloaded.add(PreloadedContent(
                type: ContentType.video, controller: controller));
          } else {
            final controller =
                VideoPlayerController.file(File(partition.content));
            await controller.initialize();
            preloaded.add(PreloadedContent(
                type: ContentType.video, controller: controller));
          }
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

  // 双击退出功能
  Future<bool> _onWillPop() async {
    DateTime now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _lastTap = now;
      // 显示提示信息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('双击屏幕退出应用'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return false; // 不退出应用
    }
    // 双击确认退出
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 释放所有预加载的内容
    for (final entry in _preloadedContents.entries) {
      for (final content in entry.value) {
        if (content.controller != null) {
          content.controller!.dispose();
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: GestureDetector(
        onTap: () {
          // 单击重置系统UI隐藏计时器
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onDoubleTap: () {
          // 双击退出应用
          _onWillPop().then((shouldExit) {
            if (shouldExit) {
              SystemNavigator.pop(); // 退出应用
            }
          });
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (playlist.isEmpty ||
                      playlist[currentShowIndex].layout.isEmpty) {
                    return const Center(
                      child: Text(
                        'No Content to Display',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    );
                  }

                  final currentLayout = playlist[currentShowIndex].layout;

                  // 计算网格行数和列数
                  int maxRow = 0;
                  int maxCol = 0;
                  for (var partition in currentLayout) {
                    maxRow = (partition.row + partition.rowSpan) > maxRow
                        ? partition.row + partition.rowSpan
                        : maxRow;
                    maxCol = (partition.col + partition.colSpan) > maxCol
                        ? partition.col + partition.colSpan
                        : maxCol;
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: maxCol,
                      childAspectRatio: constraints.maxWidth /
                          (constraints.maxHeight * maxRow / maxCol),
                    ),
                    itemCount: maxRow * maxCol,
                    itemBuilder: (context, index) {
                      int row = index ~/ maxCol;
                      int col = index % maxCol;

                      // 查找对应位置的分区
                      PartitionConfig? partition = currentLayout.firstWhere(
                        (element) =>
                            row >= element.row &&
                            row < element.row + element.rowSpan &&
                            col >= element.col &&
                            col < element.col + element.colSpan,
                        orElse: () => PartitionConfig(
                            id: -1,
                            type: ContentType.empty,
                            content: '',
                            row: -1,
                            col: -1,
                            rowSpan: 1,
                            colSpan: 1),
                      );

                      // 检查这个位置是否已经被占用
                      bool isOccupied = currentLayout.any((element) =>
                          index >= element.row * maxCol + element.col &&
                          index <
                              (element.row + element.rowSpan) * maxCol +
                                  element.col &&
                          !(element.row == row && element.col == col));

                      if (isOccupied) {
                        return Container(); // 已被占用的位置返回空容器
                      }

                      if (partition.id == -1) {
                        return Container(color: Colors.grey[900]); // 空分区
                      }

                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          border: Border.all(color: Colors.grey, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _buildPartitionContent(partition),
                      );
                    },
                  );
                },
              ),
            ),
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

      if (preloaded.controller != null) {
        // 视频内容使用预加载的控制器
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: VideoPlayer(preloaded.controller!),
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
  final VideoPlayerController? controller;
  final String? imagePath;
  final String? text;
  final List<String>? images;

  PreloadedContent({
    required this.type,
    this.controller,
    this.imagePath,
    this.text,
    this.images,
  });
}

// 分区配置类
class PartitionConfig {
  final int id;
  final ContentType type;
  final String content; // URL、文件路径或文本内容
  final int row;
  final int col;
  final int rowSpan;
  final int colSpan;

  PartitionConfig({
    required this.id,
    required this.type,
    required this.content,
    required this.row,
    required this.col,
    required this.rowSpan,
    required this.colSpan,
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
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.url != null) {
      _controller = VideoPlayerController.network(widget.url!);
    } else if (widget.file != null) {
      _controller = VideoPlayerController.file(widget.file!);
    } else {
      throw ArgumentError('Either url or file must be provided');
    }

    _initializeController();
  }

  void _initializeController() async {
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.play();
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
    _controller.dispose();
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
      child: VideoPlayer(_controller),
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

  @override
  void initState() {
    super.initState();
    _liveInfo = widget.info;
    _startUpdatingInfo();
  }

  void _startUpdatingInfo() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
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
