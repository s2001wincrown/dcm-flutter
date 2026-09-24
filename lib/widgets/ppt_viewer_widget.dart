import 'dart:async';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/services/ppt_viewer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PptViewerWidget extends StatefulWidget {
  final String filePath;
  final Rect zoneRect;

  const PptViewerWidget({
    super.key,
    required this.filePath,
    required this.zoneRect,
  });

  @override
  State<PptViewerWidget> createState() => _PptViewerWidgetState();
}

class _PptViewerWidgetState extends State<PptViewerWidget> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant PptViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      unawaited(_restart());
    } else if (oldWidget.zoneRect != widget.zoneRect) {
      unawaited(_resize());
    }
  }

  Future<void> _start() async {
    try {
      _started = await PptViewerService.start(
        viewerPath: AppGlobal.ppViewPath,
        filePath: widget.filePath,
      );
    } on MissingPluginException {
      _started = false;
    }
    if (_started) {
      await _resize();
    }
  }

  Future<void> _restart() async {
    await PptViewerService.stop();
    _started = false;
    await _start();
  }

  Future<void> _resize() {
    final rect = widget.zoneRect;
    return PptViewerService.resize(
      left: rect.left.round(),
      top: rect.top.round(),
      width: rect.width.round(),
      height: rect.height.round(),
    );
  }

  @override
  void dispose() {
    if (_started) {
      unawaited(PptViewerService.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
