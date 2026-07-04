import 'package:dcm/backend/models/banner_data.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/text_impl.dart';
import 'package:flutter/material.dart';
import 'package:marqueer/marqueer.dart';

// 滚动文本分区
class ScrollText extends StatefulWidget {
  final String textFile;
  final Rect rect;

  const ScrollText({super.key, required this.textFile, required this.rect});

  @override
  State<ScrollText> createState() => _ScrollTextState();
}

class _ScrollTextState extends State<ScrollText> {
  final controller = MarqueerController();
  BannerData? _bannerData;

  @override
  void initState() {
    super.initState();
    if (widget.textFile.isNotEmpty) {
      _bannerData = TextImpl.loadByFilePath(widget.textFile);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerData == null) {
      return Container(
        color: Utils.fromRGB(DCMGlobal.clrBGColor),
      );
    }

    return SizedBox(
      width: widget.rect.width,
      height: widget.rect.height,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: ColoredBox(
          color: Utils.fromRGB(_bannerData!.crTextBKColor),
          child: Marqueer(
            pps: _bannerData!.nSpeed * 3.0,
            controller: controller,
            direction: _getDirection(),
            infinity: _bannerData!.nBehavior == 4,
            //autoStartAfter: const Duration(seconds: 3),
            autoStart: true,
            child: Padding(
              padding: EdgeInsetsGeometry.only(
                  left: _bannerData!.nLeft.toDouble(),
                  top: _bannerData!.nTop.toDouble(),
                  right: 0.00,
                  bottom: 0.00),
              child: Align(
                alignment: _getAlignment(),
                child: Text(
                  _getText(),
                  style: TextStyle(
                    color: Utils.fromRGB(_bannerData!.crTextFGColor),
                    fontSize: (_bannerData!.nTextFontSize / 20.0),
                    fontFamily: _bannerData!.strTextFontName,
                    fontWeight: _bannerData!.bFontBold ? FontWeight.bold : null,
                    fontStyle:
                        _bannerData!.bFontItalic ? FontStyle.italic : null,
                    decoration: _getDecoration(),
                  ),
                ),
              ),
            ),
          ),
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

  MarqueerDirection _getDirection() {
    switch (_bannerData!.nDirection) {
      case 1: //right
        return MarqueerDirection.ltr;
      case 2: //up
        return MarqueerDirection.btt;
      case 3: //down
        return MarqueerDirection.ttb;
      default: //left
        return MarqueerDirection.rtl;
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
