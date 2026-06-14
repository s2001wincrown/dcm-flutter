// 视频播放分区
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/widgets/basic_video.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayer extends StatefulWidget {
  final ZoneData pZoneData;
  final String? url;
  final File? file;
  final Rect rectWin;

  const VideoPlayer(
      {super.key,
      required this.pZoneData,
      required this.rectWin,
      this.url,
      this.file});

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
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
    _player.open(video, play: false);

    _controller = VideoController(_player);
    _player.setVolume(_zoneVolume());
  }

  double _zoneVolume() {
    return DCMGlobal.videoVolume(
        widget.pZoneData.bZoneMute, widget.pZoneData.dVolume);
  }

  void _initializeController() async {
    try {
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
        configuration: VideoControllerConfiguration(
          width: widget.rectWin.width.toInt(),
          height: widget.rectWin.height.toInt(),
        ),
      );
      _player.setVolume(_zoneVolume());
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      logE('Error initializing video player: $e');
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
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: BasicVideo(controller: _controller),
    );
  }
}
