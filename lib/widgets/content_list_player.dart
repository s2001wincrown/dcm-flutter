import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/player_zone_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContentListPlayer extends StatefulWidget {
  final String contentList;
  final int contentType;
  final int zone;
  final Rect rect;

  const ContentListPlayer(
      {super.key,
      required this.contentList,
      required this.contentType,
      required this.zone,
      required this.rect});

  @override
  State<ContentListPlayer> createState() => _ContentListPlayerState();
}

class _ContentListPlayerState extends State<ContentListPlayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlayerZoneImpl? playerZoneImpl =
          Provider.of<PlayerScreenProvider>(context, listen: false)
              .getPlayerZone(widget.zone);
      if (playerZoneImpl != null) {
        /*playerZoneImpl.initContentList(
            widget.contentType, widget.contentList, widget.rect, context);*/
        playerZoneImpl.preloadContentList(context);
        playerZoneImpl.playContentList(
            widget.contentType, widget.contentList, widget.rect);
      }
    });
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
            color: Utils.fromRGB(DCMGlobal.clrBGColor),
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
                    final currentLayout = playerScreenProvider
                        .getContentListPlayerZones(widget.zone);
                    if (currentLayout == null || currentLayout.isEmpty) {
                      return Container(
                        color: Utils.fromRGB(DCMGlobal.clrBGColor),
                      );
                    }

                    return Stack(
                      children: currentLayout.map((partition) {
                        final left = partition.getRect().left;
                        final top = partition.getRect().top;
                        final w = partition.getRect().width;
                        final h = partition.getRect().bottom;
                        logD(
                            '''Render '${partition.getZoneFile()}' in partition ${partition.getZone()} at ($left, $top) with size ($w x $h)''');

                        return Positioned(
                          left: left,
                          top: top,
                          width: w,
                          height: h,
                          child: Container(
                            color: Utils.fromRGB(DCMGlobal.clrBGColor),
                            /*decoration: BoxDecoration(
                            color: Utils.fromRGB(DCMGlobal.clrBGColor),
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
