import 'package:dio/dio.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfPlayer extends StatefulWidget {
  const PdfPlayer({super.key, required this.source});

  final String source;

  @override
  State<PdfPlayer> createState() => _PdfPlayerState();
}

class _PdfPlayerState extends State<PdfPlayer> {
  late Future<PdfDocument> _documentFuture;
  PdfControllerPinch? _controller;
  PdfController? _windowsController;
  Size? _firstPageSize;

  @override
  void initState() {
    super.initState();
    _documentFuture = _openDocument(widget.source);
  }

  @override
  void didUpdateWidget(covariant PdfPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _controller?.dispose();
      _controller = null;
      _windowsController?.dispose();
      _windowsController = null;
      _firstPageSize = null;
      _documentFuture = _openDocument(widget.source);
    }
  }

  Future<PdfDocument> _openDocument(String source) async {
    final uri = Uri.tryParse(source);
    final scheme = uri?.scheme.toLowerCase();

    if (scheme == 'http' || scheme == 'https') {
      final url = uri!.removeFragment().toString();
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('The PDF response was empty.');
      }
      final document = await PdfDocument.openData(Uint8List.fromList(data));
      await _loadFirstPageSize(document);
      return document;
    }

    if (scheme == 'file') {
      final document = await PdfDocument.openFile(uri!.toFilePath());
      await _loadFirstPageSize(document);
      return document;
    }

    // A local path has no URI scheme. Keep it as a filesystem path instead of
    // converting it through Uri, which can corrupt Windows drive paths.
    final fragmentIndex = source.indexOf('#');
    final filePath =
        fragmentIndex == -1 ? source : source.substring(0, fragmentIndex);
    final document = await PdfDocument.openFile(filePath);
    await _loadFirstPageSize(document);
    return document;
  }

  Future<void> _loadFirstPageSize(PdfDocument document) async {
    final page = await document.getPage(1);
    _firstPageSize = Size(page.width, page.height);
    await page.close();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyBackground();
        }
        if (!snapshot.hasData) {
          return _emptyBackground();
        }

        if (defaultTargetPlatform == TargetPlatform.windows) {
          _windowsController ??= PdfController(document: _documentFuture);
          return LayoutBuilder(
            builder: (context, constraints) {
              return PdfView(
                controller: _windowsController!,
                builders: PdfViewBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  pageBuilder: (context, pageImage, index, document) =>
                      _buildWindowsPage(
                    context,
                    pageImage,
                    index,
                    document,
                    constraints.biggest,
                  ),
                ),
              );
            },
          );
        }

        _controller ??= PdfControllerPinch(document: _documentFuture);
        return PdfViewPinch(controller: _controller!);
      },
    );
  }

  PhotoViewGalleryPageOptions _buildWindowsPage(
    BuildContext context,
    Future<PdfPageImage> pageImage,
    int index,
    PdfDocument document,
    Size viewportSize,
  ) {
    final pageSize = _firstPageSize;
    if (pageSize == null ||
        pageSize.width <= 0 ||
        pageSize.height <= 0 ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0) {
      return PhotoViewGalleryPageOptions(
        imageProvider: PdfPageImageProvider(pageImage, index, document.id),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained * 3,
      );
    }

    final fitHeight = hasFlag(AppGlobal.pdfViewMode, 0x0002);
    final srcRatio = pageSize.width / pageSize.height;
    final targetRatio = viewportSize.width / viewportSize.height;

    final safeScale = (() {
      if (fitHeight) {
        return viewportSize.height / pageSize.height;
      }

      if (srcRatio > targetRatio) {
        return viewportSize.width / pageSize.width;
      }

      return viewportSize.height / pageSize.height;
    })();

    final scale = safeScale.isFinite && safeScale > 0 ? (safeScale / 2.0) : 1.0;

    return PhotoViewGalleryPageOptions(
      imageProvider: PdfPageImageProvider(pageImage, index, document.id),
      initialScale: scale,
      minScale: scale,
      maxScale: scale,
    );
  }

  Widget _emptyBackground() {
    return Container(
      color: Utils.fromRGB(AppGlobal.clrBGColor),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _windowsController?.dispose();
    super.dispose();
  }
}
