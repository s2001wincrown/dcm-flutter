import 'dart:async';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// a simple implementaion of `media_kit_video` Video Widget
class BasicVideo extends StatefulWidget {
  const BasicVideo({
    super.key,
    required this.controller,
  });

  final VideoController controller;

  @override
  State<BasicVideo> createState() => _BasicVideoState();
}

class _BasicVideoState extends State<BasicVideo> {
  final _subscriptions = <StreamSubscription>[];
  late int? _width = widget.controller.player.state.width;
  late int? _height = widget.controller.player.state.height;
  late bool _visible = (_width ?? 0) > 0 && (_height ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll(
      [
        widget.controller.player.stream.width.listen(
          (value) {
            _width = value;
            final visible = (_width ?? 0) > 0 && (_height ?? 0) > 0;
            if (_visible != visible) {
              setState(() {
                _visible = visible;
              });
            }
          },
        ),
        widget.controller.player.stream.height.listen(
          (value) {
            _height = value;
            final visible = (_width ?? 0) > 0 && (_height ?? 0) > 0;
            if (_visible != visible) {
              setState(() {
                _visible = visible;
              });
            }
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrain) {
        var factor = MediaQuery.of(context).devicePixelRatio;
        App().voHeight = (constrain.maxHeight * factor).toInt();
        App().voWidth = (constrain.maxWidth * factor).toInt();
        return ValueListenableBuilder<int?>(
          valueListenable: widget.controller.id,
          builder: (context, id, _) {
            return ValueListenableBuilder<Rect?>(
              valueListenable: widget.controller.rect,
              builder: (context, rect, _) {
                if (id != null && rect != null && _visible) {
                  return FittedBox(
                    child: SizedBox(
                      width: rect.width,
                      height: rect.height,
                      child: Texture(textureId: id),
                    ),
                  );
                }
                return Container(
                  color: Color(AppGlobal.clrBGColor),
                );
              },
            );
          },
        );
      },
    );
  }
}
