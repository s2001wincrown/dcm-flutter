import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MarqueeDirection { left, right, up, down }

enum MarqueeBehavior { static, infinite, slide, pingPong, seamless }

class HandwrittenMarquee extends StatefulWidget {
  const HandwrittenMarquee({
    super.key,
    required this.child,
    this.direction = MarqueeDirection.left,
    this.behavior = MarqueeBehavior.infinite,
    this.speed = 60,
    this.alignment = Alignment.center,
    this.opacity = 1,
    this.contentSize,
  });

  final Widget child;
  final MarqueeDirection direction;
  final MarqueeBehavior behavior;
  final double speed;
  final Alignment alignment;
  final double opacity;
  final Size? contentSize;

  @override
  State<HandwrittenMarquee> createState() => _HandwrittenMarqueeState();
}

class _HandwrittenMarqueeState extends State<HandwrittenMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final GlobalKey _contentKey = GlobalKey();
  Size _contentSize = Size.zero;
  Size _viewportSize = Size.zero;
  double _distance = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(HandwrittenMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction ||
        widget.behavior != oldWidget.behavior ||
        widget.speed != oldWidget.speed ||
        widget.alignment != oldWidget.alignment ||
        widget.opacity != oldWidget.opacity ||
        widget.contentSize != oldWidget.contentSize) {
      _configureAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChildSizeChanged(Size size) {
    if (widget.contentSize != null || size == _contentSize) {
      return;
    }
    _contentSize = size;
    _configureAnimation();
  }

  void _scheduleContentMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final size = _contentKey.currentContext?.size ?? Size.zero;
      if (size != Size.zero && size != _contentSize) {
        _onChildSizeChanged(size);
      }
    });
  }

  void _configureAnimation() {
    if (!mounted || _viewportSize == Size.zero) {
      return;
    }

    final contentSize = widget.contentSize ?? _contentSize;
    if (contentSize == Size.zero ||
        widget.behavior == MarqueeBehavior.static ||
        widget.speed <= 0) {
      _controller.stop();
      _controller.value = 0;
      return;
    }

    final isHorizontal = widget.direction == MarqueeDirection.left ||
        widget.direction == MarqueeDirection.right;
    final viewportExtent =
        isHorizontal ? _viewportSize.width : _viewportSize.height;
    final contentExtent = isHorizontal ? contentSize.width : contentSize.height;
    _distance = widget.behavior == MarqueeBehavior.seamless
        ? contentExtent
        : viewportExtent + contentExtent;
    final duration = Duration(
      milliseconds: math.max(1, (_distance / widget.speed * 1000).round()),
    );
    _controller
      ..stop()
      ..duration = duration
      ..value = 0;

    switch (widget.behavior) {
      case MarqueeBehavior.infinite:
      case MarqueeBehavior.seamless:
        _controller.repeat();
      case MarqueeBehavior.pingPong:
        _controller.repeat(reverse: true);
      case MarqueeBehavior.slide:
        _controller.forward();
      case MarqueeBehavior.static:
        break;
    }
    if (mounted) {
      setState(() {});
    }
  }

  double _offset(double progress) {
    final contentSize = widget.contentSize ?? _contentSize;
    final isHorizontal = widget.direction == MarqueeDirection.left ||
        widget.direction == MarqueeDirection.right;
    final viewportExtent =
        isHorizontal ? _viewportSize.width : _viewportSize.height;
    final contentExtent = isHorizontal ? contentSize.width : contentSize.height;
    final travel = widget.behavior == MarqueeBehavior.seamless
        ? contentExtent
        : widget.behavior == MarqueeBehavior.pingPong
            ? (viewportExtent - contentExtent).abs()
            : _distance;
    final startsFromEnd = widget.direction == MarqueeDirection.left ||
        widget.direction == MarqueeDirection.up;
    final start = widget.behavior == MarqueeBehavior.seamless
        ? (startsFromEnd ? 0 : -contentExtent)
        : widget.behavior == MarqueeBehavior.pingPong
            ? (startsFromEnd
                ? math.max(0, viewportExtent - contentExtent)
                : math.min(0, viewportExtent - contentExtent))
            : (startsFromEnd ? viewportExtent : -contentExtent);
    final delta = travel * progress;
    return start + (startsFromEnd ? -delta : delta);
  }

  Widget _buildContent() {
    final child = SizeChangedLayoutNotifier(
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _onChildSizeChanged(
                  _contentKey.currentContext?.size ?? Size.zero);
            }
          });
          return false;
        },
        child: KeyedSubtree(key: _contentKey, child: widget.child),
      ),
    );
    if (widget.behavior == MarqueeBehavior.seamless) {
      final isHorizontal = widget.direction == MarqueeDirection.left ||
          widget.direction == MarqueeDirection.right;
      return Flex(
        direction: isHorizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          SizeChangedLayoutNotifier(child: widget.child),
        ],
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (nextSize != _viewportSize) {
          _viewportSize = nextSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _configureAnimation();
          });
        }
        _scheduleContentMeasurement();

        final isHorizontal = widget.direction == MarqueeDirection.left ||
            widget.direction == MarqueeDirection.right;
        final content = widget.behavior == MarqueeBehavior.static
            ? Align(alignment: widget.alignment, child: _buildContent())
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final offset = _offset(_controller.value);
                  return Transform.translate(
                    offset:
                        isHorizontal ? Offset(offset, 0) : Offset(0, offset),
                    child: child,
                  );
                },
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth:
                      isHorizontal ? double.infinity : constraints.maxWidth,
                  maxHeight:
                      isHorizontal ? constraints.maxHeight : double.infinity,
                  child: UnconstrainedBox(
                    alignment: Alignment.topLeft,
                    constrainedAxis:
                        isHorizontal ? Axis.vertical : Axis.horizontal,
                    child: _buildContent(),
                  ),
                ),
              );

        return Opacity(
          opacity: widget.opacity.clamp(0.0, 1.0),
          child: ClipRect(child: content),
        );
      },
    );
  }
}
