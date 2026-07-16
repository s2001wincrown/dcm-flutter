import 'dart:io';

import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as path;

class AHMessageImpl {
  static const String lpszSignature =
      'dcCatalogue Version 4.00 - Ad hoc Message List';

  List<MessageData> lstMessage = [];
  String messagePath = DCMGlobal.messagePath;

  AHMessageImpl();

  void destroyMessageList() {
    lstMessage.clear();
  }

  void loadMessageList([String? strChannelFile]) {
    destroyMessageList();
    if (messagePath.isEmpty) return;

    final directory = Directory(messagePath);
    if (!directory.existsSync()) return;

    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      final fileName = path.basename(entity.path);
      if (fileName.toLowerCase() == 'ahwait.xml' ||
          fileName.toLowerCase() == 'ahdirect.xml') {
        continue;
      }
      if (strChannelFile != null && strChannelFile.isNotEmpty) {
        if (fileName.toLowerCase() != '${strChannelFile.toLowerCase()}.xml') {
          continue;
        }
      }
      final messageData = MessageData();
      if (serialize(entity.path, messageData, false)) {
        lstMessage.add(messageData);
      }
    }
  }

  void loadMessageListFromFiles(List<FileInfoData> arrFiles) {
    arrFiles.clear();
    if (messagePath.isEmpty) return;

    final directory = Directory(messagePath);
    if (!directory.existsSync()) return;

    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      final fileName = path.basename(entity.path);
      if (fileName.toLowerCase() == 'ahwait.xml' ||
          fileName.toLowerCase() == 'ahdirect.xml') {
        continue;
      }
      final messageData = MessageData();
      if (serialize(entity.path, messageData, false)) {
        final fileInfo = FileInfoData.create(
          uiID: messageData.uiID,
          strFileTitle: messageData.strAHName,
          strShortPath: fileName,
          strDestFile: fileName,
          dwFileSize: BigInt.from(entity.lengthSync()),
        );
        fileInfo.tmFileCreate = entity.statSync().changed;
        fileInfo.tmFileModify = entity.statSync().modified;
        arrFiles.add(fileInfo);
      }
    }
  }

  bool saveMessageData(MessageData messageData) {
    if (messagePath.isEmpty || messageData.strAHName.isEmpty) return false;
    final fileName = path.join(messagePath, '${messageData.strAHName}.xml');
    return serialize(fileName, messageData, true);
  }

  static MessageData? loadMessageData(String strMessageFile) {
    if (strMessageFile.isEmpty) return null;
    final fileName = path.join(DCMGlobal.messagePath, '$strMessageFile.xml');

    return serializeFrom(fileName);
  }

  bool isExistedMessage(MessageData messageData) {
    if (messagePath.isEmpty || messageData.strAHName.isEmpty) return false;
    final fileName = path.join(messagePath, '${messageData.strAHName}.xml');
    return File(fileName).existsSync();
  }

  MessageData? getMessage(String strMessage) {
    if (strMessage.isEmpty) return null;
    for (var item in lstMessage) {
      if (item.strAHName.toLowerCase() == strMessage.toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  static bool isValidMessage(String messageName, int nAction) {
    if (nAction > 0 &&
        (nAction == 2 ||
            nAction == 99 ||
            nAction == 999 ||
            (nAction > 79 && nAction < 86))) {
      return true;
    }
    if (DCMGlobal.messagePath.isEmpty || messageName.isEmpty) {
      return false;
    }
    final fileName = path.join(DCMGlobal.messagePath, '$messageName.xml');
    final file = File(fileName);
    if (!file.existsSync()) return false;
    return file.lengthSync() > lpszSignature.length;
  }

  bool serialize(String strFilename, MessageData messageData, bool bStoring) {
    if (bStoring) {
      XmlFilePro playerReg = XmlFilePro('AHMessage');
      XmlItem? xi = playerReg.addDataNode('MessageItem', null);
      if (xi != null) {
        messageData.writeToXML(xi);
      }
      playerReg.setSignature(lpszSignature);
      return playerReg.save(strFilename);
    }

    XmlFilePro file = XmlFilePro('AHMessage');
    if (!file.open(strFilename, XfOpen.read)) {
      return false;
    }
    if (!file.loadEx()) {
      return false;
    }
    if (file.getSignature() != lpszSignature) {
      return false;
    }

    XmlItem? pXISibling = file.getItem('MessageItem');
    while (pXISibling != null) {
      messageData.getFromXML(pXISibling);
      pXISibling = pXISibling.getSibling();
    }
    return true;
  }

  static MessageData? serializeFrom(String strFilename) {
    XmlFilePro file = XmlFilePro('AHMessage');
    if (!file.open(strFilename, XfOpen.read)) {
      return null;
    }
    if (!file.loadEx()) {
      return null;
    }
    if (file.getSignature() != lpszSignature) {
      return null;
    }

    MessageData messageData = MessageData();
    XmlItem? pXISibling = file.getItem('MessageItem');
    while (pXISibling != null) {
      messageData.getFromXML(pXISibling);
      pXISibling = pXISibling.getSibling();
    }

    return messageData;
  }
}
