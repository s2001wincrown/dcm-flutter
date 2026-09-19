import 'dart:async';
import 'dart:math';

import 'package:dcm/backend/models/banner_data.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/services/rss_feed_service.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/text_impl.dart';
import 'package:dcm/widgets/handwritten_marquee.dart';
import 'package:flutter/material.dart';

// 滚动文本分区
class ScrollText extends StatefulWidget {
  final String textFile;
  final Rect rect;

  const ScrollText({super.key, required this.textFile, required this.rect});

  @override
  State<ScrollText> createState() => _ScrollTextState();
}

class _ScrollTextState extends State<ScrollText> {
  BannerData? _bannerData;
  final RssFeedService _rssService = RssFeedService();
  final Random _random = Random();
  Timer? _rssRefreshTimer;
  Timer? _rssPageTimer;
  List<RssFeedItem> _rssItems = const [];
  int _rssIndex = 0;
  int _rssTransitionSeed = 0;
  bool _rssLoading = false;
  String? _rssError;

  @override
  void initState() {
    super.initState();
    if (widget.textFile.isNotEmpty) {
      _bannerData = TextImpl.loadByFilePath(widget.textFile);
      if (_bannerData?.nTemplate == 9) {
        _startRss();
      }
    }
  }

  @override
  void dispose() {
    _rssRefreshTimer?.cancel();
    _rssPageTimer?.cancel();
    super.dispose();
  }

  void _startRss() {
    final banner = _bannerData!;
    _refreshRss();
    _rssRefreshTimer = Timer.periodic(
      Duration(seconds: max(1, banner.rssRefreshIntervalSeconds)),
      (_) => _refreshRss(),
    );
  }

  Future<void> _refreshRss() async {
    if (!mounted || _rssLoading) {
      return;
    }
    final url = _bannerData!.strText.trim();
    if (url.isEmpty) {
      setState(() => _rssError = 'RSS URL is empty');
      return;
    }
    setState(() {
      _rssLoading = true;
      _rssError = null;
    });
    try {
      final items = await _rssService.fetch(url);
      if (!mounted) {
        return;
      }
      setState(() {
        _rssItems = items;
        if (_rssIndex >= items.length) {
          _rssIndex = 0;
        }
        _rssLoading = false;
        _rssTransitionSeed++;
      });
      _startRssPageTimer();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rssLoading = false;
        _rssError = 'RSS load failed: $error';
      });
    }
  }

  void _startRssPageTimer() {
    _rssPageTimer?.cancel();
    if (_rssItems.length < 2) {
      return;
    }
    _rssPageTimer = Timer.periodic(
      Duration(seconds: max(1, _bannerData!.rssPageDurationSeconds)),
      (_) {
        if (!mounted || _rssItems.isEmpty) {
          return;
        }
        setState(() {
          _rssIndex = (_rssIndex + 1) % _rssItems.length;
          _rssTransitionSeed = _bannerData!.rssRandomTransition
              ? _random.nextInt(3)
              : _rssTransitionSeed + 1;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerData == null) {
      return Container(
        color: Utils.fromRGB(AppGlobal.clrBGColor),
      );
    }

    if (_bannerData!.nTemplate == 9) {
      return _buildRss(context);
    }

    final banner = _bannerData!;
    final direction = _getDirection();
    final text = _getText();
    final textStyle = TextStyle(
      color: Utils.fromRGB(banner.crTextFGColor),
      fontSize: banner.nTextFontSize / 20.0,
      fontFamily: banner.strTextFontName,
      fontWeight: banner.bFontBold ? FontWeight.bold : null,
      fontStyle: banner.bFontItalic ? FontStyle.italic : null,
      decoration: _getDecoration(),
    );
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: direction == MarqueeDirection.left ||
              direction == MarqueeDirection.right
          ? 1
          : null,
    )..layout(
        maxWidth: direction == MarqueeDirection.up ||
                direction == MarqueeDirection.down
            ? widget.rect.width
            : double.infinity,
      );
    return SizedBox(
      width: widget.rect.width,
      height: widget.rect.height,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: ColoredBox(
          color: Utils.fromRGB(banner.crTextBKColor),
          child: HandwrittenMarquee(
            direction: direction,
            behavior: _getBehavior(),
            speed: banner.nSpeed * 3.0,
            alignment: _getAlignment(),
            contentSize: Size(
              textPainter.width + banner.nLeft.toDouble(),
              textPainter.height + banner.nTop.toDouble(),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: banner.nLeft.toDouble(),
                top: banner.nTop.toDouble(),
              ),
              child: Text(
                text,
                softWrap: direction == MarqueeDirection.up ||
                    direction == MarqueeDirection.down,
                style: textStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRss(BuildContext context) {
    final banner = _bannerData!;
    if (_rssLoading && _rssItems.isEmpty) {
      return _buildRssPlaceholder(banner, 'Loading RSS...');
    }
    if (_rssItems.isEmpty) {
      return _buildRssPlaceholder(banner, _rssError ?? 'No RSS items');
    }

    final item = _rssItems[_rssIndex];
    final text = banner.rssShowContent ? item.pageText : item.title;
    final transition = banner.rssRandomTransition ? _rssTransitionSeed % 3 : 0;
    return SizedBox(
      width: widget.rect.width,
      height: widget.rect.height,
      child: ColoredBox(
        color: Utils.fromRGB(banner.crTextBKColor),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            switch (transition) {
              case 1:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              case 2:
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              default:
                return FadeTransition(opacity: animation, child: child);
            }
          },
          child: _buildMarquee(
            text,
            key: ValueKey('${_rssIndex}_$_rssTransitionSeed'),
          ),
        ),
      ),
    );
  }

  Widget _buildRssPlaceholder(BannerData banner, String message) {
    return SizedBox(
      width: widget.rect.width,
      height: widget.rect.height,
      child: ColoredBox(
        color: Utils.fromRGB(banner.crTextBKColor),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Utils.fromRGB(banner.crTextFGColor)),
          ),
        ),
      ),
    );
  }

  Widget _buildMarquee(String text, {Key? key}) {
    final banner = _bannerData!;
    final direction = _getDirection();
    final textStyle = TextStyle(
      color: Utils.fromRGB(banner.crTextFGColor),
      fontSize: banner.nTextFontSize / 20.0,
      fontFamily: banner.strTextFontName,
      fontWeight: banner.bFontBold ? FontWeight.bold : null,
      fontStyle: banner.bFontItalic ? FontStyle.italic : null,
      decoration: _getDecoration(),
    );
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: direction == MarqueeDirection.left ||
              direction == MarqueeDirection.right
          ? 1
          : null,
    )..layout(
        maxWidth: direction == MarqueeDirection.up ||
                direction == MarqueeDirection.down
            ? widget.rect.width
            : double.infinity,
      );
    return HandwrittenMarquee(
      key: key,
      direction: direction,
      behavior: _getBehavior(),
      speed: banner.nSpeed * 3.0,
      alignment: _getAlignment(),
      contentSize: Size(
        textPainter.width + banner.nLeft.toDouble(),
        textPainter.height + banner.nTop.toDouble(),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: banner.nLeft.toDouble(),
          top: banner.nTop.toDouble(),
        ),
        child: Text(
          text,
          softWrap: direction == MarqueeDirection.up ||
              direction == MarqueeDirection.down,
          style: textStyle,
        ),
      ),
    );
  }

  Alignment _getAlignment() {
    if (_bannerData!.nBehavior != 5 && _bannerData!.nBehavior != 0) {
      switch (_bannerData!.nDirection) {
        case 0:
        case 1:
          switch (_bannerData!.nValign) {
            case 0:
              return Alignment.topLeft;
            case 2:
              return Alignment.bottomLeft;
            default:
              return Alignment.centerLeft;
          }
        default:
          if (_bannerData!.strHalign.equalsIgnoreCase('left')) {
            return Alignment.topLeft;
          } else if (_bannerData!.strHalign.equalsIgnoreCase('right')) {
            return Alignment.topRight;
          } else {
            return Alignment.topCenter;
          }
      }
    } else if (_bannerData!.nBehavior == 0) {
      if (_bannerData!.strHalign.equalsIgnoreCase('left')) {
        return Alignment.topLeft;
      } else if (_bannerData!.strHalign.equalsIgnoreCase('right')) {
        return Alignment.topRight;
      } else {
        return Alignment.topCenter;
      }
    }

    return Alignment.topLeft;
  }

  String _getText() {
    String str = _bannerData!.strText;
    if (str.contains('<br>')) {
      str = str.replaceAll('<br>', '\r\n');
    }
    str = str.replaceAll('&nbsp;', ' ');

    return str;
  }

  MarqueeDirection _getDirection() {
    switch (_bannerData!.nDirection) {
      case 1: //right
        return MarqueeDirection.right;
      case 2: //up
        return MarqueeDirection.up;
      case 3: //down
        return MarqueeDirection.down;
      default: //left
        return MarqueeDirection.left;
    }
  }

  MarqueeBehavior _getBehavior() {
    switch (_bannerData!.nBehavior) {
      case 1:
        return MarqueeBehavior.infinite;
      case 2:
        return MarqueeBehavior.pingPong;
      case 0:
        return MarqueeBehavior.static;
      case 4:
        return MarqueeBehavior.seamless;
      default:
        return MarqueeBehavior.slide;
    }
  }

  TextDecoration? _getDecoration() {
    TextDecoration? decoration;
    if (_bannerData!.bFontUnderline) {
      decoration = TextDecoration.underline;
    }
    if (_bannerData!.bStrikethrough) {
      if (decoration == null) {
        decoration = TextDecoration.lineThrough;
      } else {
        decoration =
            TextDecoration.combine([decoration, TextDecoration.lineThrough]);
      }
    }

    return decoration;
  }
}
