import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slideshow 过渡效果，覆盖 jQuery UI 支持的 effect 类型。
enum SlideshowEffect {
  none,
  fade,
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
  blind,
  clip,
  drop,
  fold,
  puff,
  scale,
  size,
  bounce,
  pulsate,
  shake,
  explode,
  highlight,
  transfer,
}

/// 将 XML 中的过渡名称（兼容大小写、空格、连字符和中文别名）解析为效果。
SlideshowEffect slideshowEffectFromString(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]'), '')
      .replaceAll('effect', '');

  final numeric = int.tryParse(normalized);
  if (numeric != null) {
    const numericEffects = [
      SlideshowEffect.none,
      SlideshowEffect.fade,
      SlideshowEffect.slideLeft,
      SlideshowEffect.blind,
      SlideshowEffect.clip,
      SlideshowEffect.drop,
      SlideshowEffect.fold,
      SlideshowEffect.puff,
      SlideshowEffect.scale,
      SlideshowEffect.size,
      SlideshowEffect.bounce,
      SlideshowEffect.pulsate,
      SlideshowEffect.shake,
      SlideshowEffect.explode,
      SlideshowEffect.highlight,
      SlideshowEffect.transfer,
    ];
    if (numeric >= 0 && numeric < numericEffects.length) {
      return numericEffects[numeric];
    }
  }

  switch (normalized) {
    case 'fade':
    case 'fadein':
    case 'fadeout':
    case '淡入':
    case '淡出':
    case '淡入淡出':
    case '渐变':
      return SlideshowEffect.fade;
    case 'slide':
    case 'slideleft':
    case 'left':
    case '滑动':
      return SlideshowEffect.slideLeft;
    case 'slideright':
    case 'right':
      return SlideshowEffect.slideRight;
    case 'slideup':
    case 'up':
      return SlideshowEffect.slideUp;
    case 'slidedown':
    case 'down':
      return SlideshowEffect.slideDown;
    case 'blind':
    case '百叶窗':
      return SlideshowEffect.blind;
    case 'clip':
      return SlideshowEffect.clip;
    case 'drop':
      return SlideshowEffect.drop;
    case 'fold':
      return SlideshowEffect.fold;
    case 'puff':
      return SlideshowEffect.puff;
    case 'scale':
    case '放大':
    case '缩放':
      return SlideshowEffect.scale;
    case 'size':
      return SlideshowEffect.size;
    case 'bounce':
    case '弹跳':
      return SlideshowEffect.bounce;
    case 'pulsate':
      return SlideshowEffect.pulsate;
    case 'shake':
      return SlideshowEffect.shake;
    case 'explode':
      return SlideshowEffect.explode;
    case 'highlight':
      return SlideshowEffect.highlight;
    case 'transfer':
      return SlideshowEffect.transfer;
    case 'none':
      return SlideshowEffect.none;
    default:
      return SlideshowEffect.none;
  }
}

/// 在旧图与新图之间播放过渡动画。
class SlideshowTransition extends StatelessWidget {
  final String oldImagePath;
  final String newImagePath;
  final SlideshowEffect effect;
  final Animation<double> animation;
  final BoxFit fit;

  const SlideshowTransition({
    super.key,
    required this.oldImagePath,
    required this.newImagePath,
    required this.effect,
    required this.animation,
    required this.fit,
  });

  Widget _image(String path) {
    return Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return _buildEffect(animation.value, width, height);
          },
        );
      },
    );
  }

  Widget _buildEffect(double raw, double width, double height) {
    final t = Curves.easeInOut.transform(raw);
    final oldImage = _image(oldImagePath);
    final newImage = _image(newImagePath);

    Widget newBehindOld(Widget oldWidget) {
      return Stack(fit: StackFit.expand, children: [newImage, oldWidget]);
    }

    Widget newAboveOld(Widget newWidget) {
      return Stack(fit: StackFit.expand, children: [oldImage, newWidget]);
    }

    switch (effect) {
      case SlideshowEffect.none:
        return newImage;
      case SlideshowEffect.fade:
        return newAboveOld(Opacity(opacity: t, child: newImage));
      case SlideshowEffect.slideLeft:
        return newAboveOld(Transform.translate(
          offset: Offset((1 - t) * width, 0),
          child: newImage,
        ));
      case SlideshowEffect.slideRight:
        return newAboveOld(Transform.translate(
          offset: Offset(-(1 - t) * width, 0),
          child: newImage,
        ));
      case SlideshowEffect.slideUp:
        return newAboveOld(Transform.translate(
          offset: Offset(0, (1 - t) * height),
          child: newImage,
        ));
      case SlideshowEffect.slideDown:
        return newAboveOld(Transform.translate(
          offset: Offset(0, -(1 - t) * height),
          child: newImage,
        ));
      case SlideshowEffect.blind:
        return newAboveOld(ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: SizedBox(width: width, height: height, child: newImage),
          ),
        ));
      case SlideshowEffect.clip:
        return newAboveOld(ClipRect(
          child: Align(
            alignment: Alignment.center,
            widthFactor: t,
            heightFactor: t,
            child: SizedBox(width: width, height: height, child: newImage),
          ),
        ));
      case SlideshowEffect.drop:
        return newAboveOld(Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -(1 - t) * height * 0.3),
            child: newImage,
          ),
        ));
      case SlideshowEffect.fold:
        return newAboveOld(Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..scaleByDouble(1.0, t <= 0 ? 0.001 : t, 1.0, 1.0),
          child: newImage,
        ));
      case SlideshowEffect.puff:
        return newBehindOld(Transform.scale(
          scale: 1 + 0.5 * t,
          child: Opacity(opacity: 1 - t, child: oldImage),
        ));
      case SlideshowEffect.scale:
        return newBehindOld(Transform.scale(
          scale: 1 - 0.5 * t,
          child: Opacity(opacity: 1 - t, child: oldImage),
        ));
      case SlideshowEffect.size:
        return newAboveOld(Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.5 + 0.5 * t, child: newImage),
        ));
      case SlideshowEffect.bounce:
        final bounce = Curves.elasticOut.transform(raw);
        return newAboveOld(Transform.translate(
          offset: Offset(0, -(1 - bounce) * height * 0.4),
          child: newImage,
        ));
      case SlideshowEffect.pulsate:
        final pulse = 1 + 0.03 * math.sin(raw * math.pi * 4);
        return newAboveOld(Opacity(
          opacity: t,
          child: Transform.scale(scale: pulse, child: newImage),
        ));
      case SlideshowEffect.shake:
        final dx = math.sin(raw * math.pi * 16) * width * 0.02 * (1 - raw);
        return newBehindOld(Opacity(
          opacity: 1 - t,
          child: Transform.translate(offset: Offset(dx, 0), child: oldImage),
        ));
      case SlideshowEffect.explode:
        return Stack(fit: StackFit.expand, children: [
          newImage,
          _explodeTiles(t, width, height),
        ]);
      case SlideshowEffect.highlight:
        return newAboveOld(IgnorePointer(
          child: Container(
            color: Colors.white.withValues(alpha: (1 - t) * 0.6),
          ),
        ));
      case SlideshowEffect.transfer:
        return newAboveOld(Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((1 - t) * width * 0.3, (1 - t) * height * 0.3),
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: newImage),
          ),
        ));
    }
  }

  /// jQuery UI explode：旧图拆成 3x3 块向外飞散并淡出。
  Widget _explodeTiles(double t, double width, double height) {
    const rows = 3;
    const cols = 3;
    final tileWidth = width / cols;
    final tileHeight = height / rows;

    return Stack(children: [
      for (int row = 0; row < rows; row++)
        for (int col = 0; col < cols; col++)
          Positioned(
            left: col * tileWidth,
            top: row * tileHeight,
            width: tileWidth,
            height: tileHeight,
            child: Opacity(
              opacity: 1 - t,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: width,
                  maxWidth: width,
                  minHeight: height,
                  maxHeight: height,
                  child: Transform.translate(
                    offset: Offset(
                      -col * tileWidth + (col - 1) * t * width * 0.4,
                      -row * tileHeight + (row - 1) * t * height * 0.4,
                    ),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _image(oldImagePath),
                    ),
                  ),
                ),
              ),
            ),
          ),
    ]);
  }
}
