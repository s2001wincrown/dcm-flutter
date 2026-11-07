import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/xml_settings/contentlist_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('loadContentList accepts an absolute XML path', () async {
    final directory = await Directory.systemTemp.createTemp();
    final previousContentListPath = AppGlobal.contentListPath;
    addTearDown(() async {
      AppGlobal.contentListPath = previousContentListPath;
      await directory.delete(recursive: true);
    });

    AppGlobal.contentListPath = directory.path;
    final contentList = ContentListImpl(cDIRECTPLAYTYPE);
    final messageData = MessageData()..strAHName = 'contentlist1';

    expect(contentList.saveContentList(messageData), isTrue);
    expect(
      contentList.loadContentList(
        path.join(directory.path, 'contentlist1.xml'),
      ),
      isNotNull,
    );
  });
}
