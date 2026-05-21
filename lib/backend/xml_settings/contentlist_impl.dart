import 'dart:io';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zoneext_data.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

// 内容列表管理器实现
class ContentListImpl {
  static const String lpszSignature =
      'dcCatalogue Version 4.00 - Ad hoc Message List';
  List<ProductData> lstProduct = [];
  List<String> arrContentList = [];
  DateTime dtLastModified = DateTime.now();

  String strContentListPath = '';
  int nContentType = 0;

  ContentListImpl(this.nContentType) {
    // 初始化内容列表路径
    if (nContentType == cDDETYPE) {
      strContentListPath = DCMGlobal.ddeXmlPath;
    } else {
      strContentListPath = DCMGlobal.contentListPath;
    }
    dtLastModified = DateTime.now();
  }

  // 保存内容列表
  bool saveContentList(MessageData messageData) {
    String fileName =
        path.join(strContentListPath, '${messageData.strAHName}.xml');
    return serializeTo(fileName, messageData);
  }

  // 加载内容列表
  MessageData? loadContentList(String strContentList) {
    String fileName = path.join(strContentListPath, '$strContentList.xml');
    return serializeFrom(fileName);
  }

  // 加载内容列表文件
  void loadContentListFile(String strContentList) {
    arrContentList.clear();
    lstProduct.clear();

    String filePath = Utils.getFilePath(strContentList, nContentType);
    if (File(filePath).existsSync()) {
      serializeThis(filePath);
    }
  }

  // 加载内容列表（按日期范围）
  void loadContentListByDateRange(DateTime? dtStart, DateTime? dtEnd,
      {String? strContentList}) async {
    arrContentList.clear();
    lstProduct.clear();

    DateTime dtCurr = DateTime.now();
    dtStart ??= dtCurr;
    dtEnd ??= dtCurr;

    DateTime dtDay = dtStart;
    while (dtDay.isBefore(dtEnd) || dtDay.isAtSameMomentAs(dtEnd)) {
      String strDate = DateFormat('yyyyMMdd').format(dtDay);
      String currContentList = path.join(strContentListPath, '$strDate.xml');
      if (strContentList != null && strContentList.isNotEmpty) {
        currContentList =
            path.join(strContentListPath, strContentList, '$strDate.xml');
      }

      if (File(currContentList).existsSync()) {
        serializeThis(currContentList);
      }

      dtDay = dtDay.add(const Duration(days: 1));
    }
  }

  // 加载内容列表（按文件夹或文件）
  void loadContentListGeneral({String strContentList = ''}) {
    lstProduct.clear();
    arrContentList.clear();

    String contentListFile = strContentList;
    String extension = path.extension(contentListFile).toLowerCase();

    if (extension == '.xml') {
      if (!File(contentListFile).existsSync()) {
        String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
        contentListFile = path.join(strContentListPath, '$dateStr.xml');
      }

      if (File(contentListFile).existsSync()) {
        serializeThis(contentListFile);
      }
    } else {
      String strFileName = strContentListPath; //strFolder;
      if (strContentList.isNotEmpty) {
        strFileName = strContentList; //strFolder;
      }

      String searchPattern = path.join(strFileName, '*.xml');
      Directory dir = Directory(path.dirname(searchPattern));

      if (dir.existsSync()) {
        List<FileSystemEntity> entities = dir
            .listSync()
            .where((entity) => entity.path.toLowerCase().endsWith('.xml'))
            .toList();

        for (FileSystemEntity entity in entities) {
          if (entity is File) {
            serializeThis(entity.path);
          }
        }
      }
    }
  }

  // 检查内容列表是否存在
  Future<bool> isExistedContentList(MessageData messageData) async {
    String fileName =
        path.join(strContentListPath, '${messageData.strAHName}.xml');
    return await File(fileName).exists();
  }

  // 检查是否有效播放
  bool isValidForPlay() {
    for (ProductData pData in lstProduct) {
      if (pData.isValidForPlay()) {
        return true;
      }
    }
    return false;
  }

  // 检查是否过期
  bool isOutdated(ProductData pProductData) {
    if (pProductData.lstZone.isNotEmpty) {
      if (pProductData.lstZone[0] is ZoneExtData) {
        return (pProductData.lstZone[0] as ZoneExtData).isOutdated();
      }
    }
    return false;
  }

  // 检查是否在播放时间范围内
  bool isTimeForPlay(ProductData pProductData) {
    if (pProductData.lstZone.isNotEmpty) {
      if (pProductData.lstZone[0] is ZoneExtData) {
        return (pProductData.lstZone[0] as ZoneExtData).isTimeForPlay();
      }
    }
    return false;
  }

  // 获取产品数据
  ProductData? getProductData({int nProduct = 0}) {
    for (ProductData pData in lstProduct) {
      if (pData.uiID == nProduct) {
        return pData;
      }
    }
    return null;
  }

  // 获取文件信息
  List<FileInfoData> getFileInfo(List<FileInfoData> lstFileInfo,
      {String strContentList = ''}) {
    for (String contentFile in arrContentList) {
      File file = File(contentFile);
      if (file.existsSync()) {
        String destFile = Utils.getShortPath(contentFile, nContentType);
        bool bExisted = false;

        for (FileInfoData fileInfo in lstFileInfo) {
          if (fileInfo.strDestFile.toLowerCase() == destFile.toLowerCase() &&
              fileInfo.nContentType == nContentType) {
            bExisted = true;
            break;
          }
        }

        if (bExisted) continue;

        FileInfoData fileData = FileInfoData(
            strFilePath: file.path,
            strShortPath: destFile,
            strDestFile: destFile,
            strFileTitle: path.basename(file.path),
            nContentType: nContentType,
            dwFileSize: BigInt.from(file.lengthSync()));

        FileStat stat = file.statSync();
        fileData.tmFileCreate = stat.changed;
        fileData.tmFileModify = stat.modified;

        lstFileInfo.add(fileData);
      }
    }

    return lstFileInfo;
  }

  // 获取总持续时间
  double getDuration() {
    double dbDuration = 0.00;
    for (ProductData pData in lstProduct) {
      if (isTimeForPlay(pData)) {
        dbDuration += Utils.getMaxDuration(pData);
      }
    }
    return dbDuration;
  }

  bool serializeThis(String strFilename) {
    lstProduct.clear();
    XmlFilePro file = XmlFilePro("AHMessage"); //szPassword
    if (!file.open(strFilename, XfOpen.read)) {
      return false;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        // get publish file information list
        XmlItem? pMessageItem = file.getItem("MessageItem");
        if (pMessageItem != null) {
          XmlItem? pXISibling = pMessageItem.getItem("m_ZoneData");
          while (pXISibling != null) {
            ProductData pProduct = ProductData();
            pProduct.strProductName = pXISibling
                .getItemValue("ContentListID"); //.Format("%d", nCount);
            pProduct.strProductDesc =
                pXISibling.getItemValue("ContentListLayout");
            pProduct.nLanguage =
                pXISibling.getItemValueI("ContentListItemType");
            pProduct.uiID = pXISibling.getItemValueI("ContentListID");
            lstProduct.add(pProduct);
            ZoneExtData pZone = ZoneExtData();
            pZone.getFromXML(pXISibling);
            pProduct.lstZone.add(pZone);

            XmlItem? pZoneSibling = pXISibling.getItem("m_ZoneData");
            while (pZoneSibling != null) {
              ZoneExtData pZone1 = ZoneExtData();
              pZone1.getFromXML(pZoneSibling);
              pProduct.lstZone.add(pZone1);

              pZoneSibling = pZoneSibling.getSibling();
            }

            pXISibling = pXISibling.getSibling();
          }
        }

        if (lstProduct.isNotEmpty) {
          arrContentList.add(strFilename);
        }
      }
      return true;
    }

    return false;
  }

  /****************************************************************************/
  /*																	        */
  /* Function name : Serialize										        */
  /* Description   : Call this function to store/load the ContentList data	*/
  /*																	        */
  ////****************************************************************************/
  bool serializeTo(String strFilename, MessageData messageData) {
    XmlFilePro playerReg = XmlFilePro('AHMessage');

    // Save the User information
    XmlItem? xi = playerReg.addDataNode('MessageItem', null);
    if (xi != null) {
      messageData.writeToXML(xi);
    }
    playerReg.setSignature(lpszSignature);

    // encrypt prior to setting checkout status and file info (so these are visible without decryption)
    // this simply fails if password is empty
    //PlayerReg.Encrypt(szPassword);

    return playerReg.save(strFilename);
  }

  MessageData? serializeFrom(String strFilename) {
    XmlFilePro file = XmlFilePro('AHMessage', null); //szPassword
    if (!file.open(strFilename, XfOpen.read, false)) {
      return null;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == lpszSignature) {
        MessageData messageData = MessageData();
        // get publish file information list
        XmlItem? pXISibling = file.getItem('MessageItem');
        while (pXISibling != null) {
          // get Content list  data
          messageData.getFromXML(pXISibling);

          pXISibling = pXISibling.getSibling();
        }

        return messageData;
      }
    }
    return null;
  }
}
