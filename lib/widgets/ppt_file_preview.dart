import 'dart:async';

import 'package:file_preview/file_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PptFilePreview extends StatefulWidget {
  final String filePath;
  final double width;
  final double height;

  const PptFilePreview({
    super.key,
    required this.filePath,
    required this.width,
    required this.height,
  });

  @override
  State<PptFilePreview> createState() => _PptFilePreviewState();
}

class _PptFilePreviewState extends State<PptFilePreview> {
  static const _tbsLicense = String.fromEnvironment('FILE_PREVIEW_TBS_LICENSE');

  bool _isReady = false;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant PptFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      setState(() {
        _isReady = false;
        _initializationError = null;
      });
    }
  }

  Future<void> _initialize() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FilePreview.initTBS(license: _tbsLicense);
      }
      if (!mounted) {
        return;
      }
      setState(() => _isReady = true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _initializationError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return const ColoredBox(color: Colors.transparent);
    }
    if (!_isReady || widget.filePath.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return FilePreviewWidget(
      key: ValueKey(widget.filePath),
      path: widget.filePath,
      width: widget.width,
      height: widget.height,
    );
  }
}
