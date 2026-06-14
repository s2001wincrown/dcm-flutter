import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/slideshow_data.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/xml_multi_image_setting.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:transparent_image/transparent_image.dart';

class Slideshow extends StatefulWidget {
  final String imageFile;

  const Slideshow({super.key, required this.imageFile});

  @override
  State<Slideshow> createState() => _SlideshowState();
}

class _SlideshowState extends State<Slideshow> {
  int _currentIndex = 0;
  late Timer _timer;
  SlideShowData? _slideShowData;
  final List<String> imageUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.imageFile.isNotEmpty) {
      _startSlideshow();
    }
  }

  void _startSlideshow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      parser(widget.imageFile);
    });
    if (imageUrls.isEmpty) return;

    _timer = Timer.periodic(
        Duration(
            seconds: _slideShowData == null ? 8 : _slideShowData!.nPerSecond),
        (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % imageUrls.length;
      });
    });
  }

  void parser(String filePath) async {
    //Log.i(PlayerMainActivity.LOG_TAG, "slideshow parse step 1");
    if (path.extension(filePath).equalsIgnoreCase(".xml")) {
      //Log.i(PlayerMainActivity.LOG_TAG, "slideshow parse step 2");
      try {
        _slideShowData = XmlMultiImageSetting.loadByFilePath(filePath);
        //Log.i(PlayerMainActivity.LOG_TAG, "slideshow parse step 3");
        if (_slideShowData != null && _slideShowData!.arrImageFile != null) {
          //Log.i(PlayerMainActivity.LOG_TAG, "slideshow parse step 4");
          //WriteMessage(MSG_INFO, "Zone %d play Image %s step 2, Thread ID %d!!!", m_nZone, pZoneData.m_strZoneFile, 0);
          for (int i = 0; i < _slideShowData!.arrImageFile!.length; i++) {
            //Log.i(PlayerMainActivity.LOG_TAG, "slideshow parse step 5 " + i);
            String imageFilePath = Utils.getFilePath(
                _slideShowData!.arrImageFile!.elementAt(i),
                cIMAGETYPE,
                -1,
                null); //GetFilePath(pZoneData.m_arrImageFile.get(i), IMAGE_TYPE, DCMConstant.DCM_SINGLEIMAGE_TYPE);
            var imageFile = File(imageFilePath);
            if (await imageFile.exists()) {
              if (context.mounted) {
                await precacheImage(FileImage(imageFile), context);
              }
              imageUrls.add(imageFilePath);
            } else {
              logE('''Slideshow - image file: "$imageFilePath" not found.''');
            }
          }
          //WriteMessage(MSG_INFO, "Zone %d play Image %s step 3, Thread ID %d!!!", m_nZone, pZoneData.m_strZoneFile, 0);
        } else {
          logE('Slideshow - invalid slideshow format: "$filePath".');
        }
      } catch (e) {
        logE('Slideshow - image file: "$filePath" throw exception; Error: $e.');
      }
    } else {
      var imageFile = File(filePath);
      if (await imageFile.exists()) {
        if (context.mounted) {
          await precacheImage(FileImage(imageFile), context);
        }
        imageUrls.add(filePath);
      } else {
        logE('''Slideshow - image file: "$filePath" not found.''');
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      if (_slideShowData != null && _slideShowData!.strBGFile.isNotEmpty) {
        String bgImageFilePath =
            Utils.getFilePath(_slideShowData!.strBGFile, cIMAGETYPE, -1, null);
        return Image.file(
          File(bgImageFilePath),
          width: double.maxFinite,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: _slideShowData != null
                  ? Color(_slideShowData!.crBGColor)
                  : Colors.black,
            );
          },
        );
      } else {
        return Container(
          color: _slideShowData != null
              ? Color(_slideShowData!.crBGColor)
              : Colors.black,
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: FadeInImage.memoryNetwork(
        placeholder: kTransparentImage,
        image: imageUrls[_currentIndex],
        fit: BoxFit.cover,
        imageErrorBuilder: (context, error, stackTrace) {
          return Container(
            color: _slideShowData != null
                ? Color(_slideShowData!.crBGColor)
                : Colors.black,
          );
        },
      ),
    );
  }
}
