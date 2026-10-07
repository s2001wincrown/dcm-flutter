import 'dart:async';

import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/content_list_playback.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FloatingPlayer extends StatefulWidget {
  final String contentList;
  final int contentType;
  final int zone;
  final Rect rect;

  const FloatingPlayer(
      {super.key,
      required this.contentList,
      required this.contentType,
      required this.zone,
      required this.rect});

  @override
  State<FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends State<FloatingPlayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_preloadAndPlayContentList());
    });
  }

  Future<void> _preloadAndPlayContentList() async {
    final playerZoneImpl =
        Provider.of<PlayerScreenProvider>(context, listen: false)
            .getPlayerZone(widget.zone);
    if (playerZoneImpl == null) return;

    try {
      logI('FloatingPlayer - preloadContentList');
      await preloadContentListThenPlay(
        preload: (onFirstContentPreloaded) => playerZoneImpl.preloadContentList(
          context,
          onFirstContentPreloaded: onFirstContentPreloaded,
        ),
        shouldPlay: () => mounted,
        play: () => playerZoneImpl.playContentList(
            widget.contentType, widget.contentList, widget.rect),
        onPlaybackStarted: () {
          if (mounted) setState(() {});
        },
        onPlaybackFinished: () {
          if (mounted) setState(() {});
        },
        onPlaybackSkipped: playerZoneImpl.cancelContentListPreload,
      );
    } catch (error, stackTrace) {
      logE(
          'FloatingPlayer - preload or playback initialization failed: '
          '$error',
          error,
          stackTrace);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerScreenProvider>(
      builder: (BuildContext context, playerScreenProvider, Widget? child) {
        if (!playerScreenProvider.isValidForPlay()) {
          return Container(
            color: Utils.fromRGB(AppGlobal.clrBGColor),
          );
        }

        return LayoutBuilder(builder: (context, constraints) {
          return SizedBox(
            width: widget.rect.width,
            height: widget.rect.height,
            child: Stack(
              children: <Widget>[
                Builder(
                  builder: (context) {
                    final currentLayout =
                        playerScreenProvider.getFloatingPlayerZones();
                    /*logD(
                        '''FloatingPlayer Zone: ${widget.zone}, play: '${widget.contentList}', contentType: ${widget.contentType}, currentLayout: ${currentLayout?.length}.''');*/
                    if (currentLayout == null || currentLayout.isEmpty) {
                      return Container(
                        color: Utils.fromRGB(AppGlobal.clrBGColor),
                      );
                    }

                    return Stack(
                      children: currentLayout.map((partition) {
                        final left = partition.getRect().left;
                        final top = partition.getRect().top;
                        final w = partition.getRect().width;
                        final h = partition.getRect().bottom;
                        /*logD(
                            '''FloatingPlayer: Render '${partition.getZoneFile()}' in partition ${partition.getZone()} at ($left, $top) with size ($w x $h)''');*/

                        return Positioned(
                          left: left,
                          top: top,
                          width: w,
                          height: h,
                          child: Container(
                            color: Utils.fromRGB(AppGlobal.clrBGColor),
                            /*decoration: BoxDecoration(
                            color: Utils.fromRGB(AppGlobal.clrBGColor),
                            border: null,
                            borderRadius: BorderRadius.zero,
                          ),*/
                            child: partition.renderZone(true),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
