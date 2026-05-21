// This is a part of dc Catalogue System(Visual C++).
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

//File Information Object Data

import 'package:dcm/backend/xmlfile/xmlitem.dart';

enum FileItemStatus {
  skip(-1),
  normal(0),
  temporary(1),
  download(2);

  const FileItemStatus(this.status);

  final int status;

  static FileItemStatus fromInt(int status) {
    switch (status) {
      case -1:
        return skip;
      case 0:
        return normal;
      case 1:
        return temporary;
      case 2:
        return download;
      default:
        return skip;
    }
  }
}

class FileInfoData {
  int? uiID = 0;
  String strFileTitle = '';
  String? strFilePath;
  String strShortPath = '';
  String strDestFile = '';
  String? uuid;
  String? strMD5;
  String? strSHA1;
  DateTime? tmFileModify;
  DateTime? tmFileCreate;
  DateTime? dtEffDateFr;
  DateTime? dtEffDateTo;
  BigInt dwFileSize = BigInt.zero;
  int nContentType = -1;
  int nTransferType = 1;
  FileItemStatus fileStatus = FileItemStatus.normal;

  FileInfoData({
    this.uiID,
    required this.strFileTitle,
    this.strFilePath,
    required this.strShortPath,
    required this.strDestFile,
    this.uuid,
    this.strMD5,
    this.strSHA1,
    this.tmFileModify,
    this.tmFileCreate,
    DateTime? dtEffDateFr,
    DateTime? dtEffDateTo,
    required this.dwFileSize,
    int? nContentType,
    int? nTransferType,
    FileItemStatus? fileStatus,
  }) {
    this.dtEffDateFr = dtEffDateFr ?? DateTime.now();
    this.dtEffDateTo =
        dtEffDateTo ?? DateTime.now().add(const Duration(days: 365 * 10));
    this.nContentType = nContentType ?? -1;
    this.nTransferType = nTransferType ?? 1;
    this.fileStatus = fileStatus ?? FileItemStatus.normal;
  }

  FileInfoData.copy(FileInfoData other) {
    uiID = other.uiID;
    strFilePath = other.strFilePath;
    strFileTitle = other.strFileTitle;
    strShortPath = other.strShortPath;
    strDestFile = other.strDestFile;
    dwFileSize = other.dwFileSize;
    nContentType = other.nContentType;
    tmFileCreate = other.tmFileCreate;
    tmFileModify = other.tmFileModify;
    dtEffDateFr = other.dtEffDateFr;
    dtEffDateTo = other.dtEffDateTo;
    fileStatus = other.fileStatus;
    strMD5 = other.strMD5;
    strSHA1 = other.strSHA1;
    nTransferType = 1;
  }

  FileInfoData.zone(String zoneFile, String destFile, int contentType) {
    uiID = 0;
    strFileTitle = '';
    strFilePath = '';
    strShortPath = '';
    strDestFile = '';
    strMD5 = '';
    strSHA1 = '';
    nContentType = 0;
    dwFileSize = BigInt.zero;
    dtEffDateFr = DateTime.now();
    dtEffDateTo = dtEffDateFr!.add(const Duration(days: 365 * 10));
    fileStatus = FileItemStatus.normal;
    nTransferType = 1;
    strFilePath = zoneFile;
    strDestFile = destFile;
    nContentType = contentType;
  }

  FileInfoData.uuidContent(this.uuid, int contentType) {
    uiID = 0;
    strFileTitle = '';
    strFilePath = '';
    strShortPath = '';
    strDestFile = '';
    strMD5 = '';
    strSHA1 = '';
    nContentType = 0;
    dwFileSize = BigInt.zero;
    dtEffDateFr = DateTime.now();
    dtEffDateTo = dtEffDateFr!.add(const Duration(days: 365 * 10));
    fileStatus = FileItemStatus.normal;
    nTransferType = 1;
    nContentType = contentType;
  }

  FileInfoData.full(
      this.uuid,
      int? uiID,
      String? fileTitle,
      String? shortPath,
      String? destFile,
      int? contentType,
      DateTime? lastModified,
      int? dwFileSize) {
    uiID = 0;
    strFileTitle = '';
    strFilePath = '';
    strShortPath = '';
    strDestFile = '';
    strMD5 = '';
    strSHA1 = '';
    nContentType = 0;
    dwFileSize = 0;
    dtEffDateFr = DateTime.now();
    dtEffDateTo = dtEffDateFr!.add(const Duration(days: 365 * 10));
    fileStatus = FileItemStatus.normal;
    nTransferType = 1;
    uiID = uiID;
    strFileTitle = fileTitle ?? '';
    strShortPath = shortPath ?? '';
    strDestFile = destFile ?? '';
    nContentType = contentType ?? 0;
    tmFileModify = lastModified;
    dwFileSize = dwFileSize;
  }

  FileInfoData.uuidTitle(
      this.uuid, String fileTitle, int contentType, DateTime lastModified) {
    uiID = 0;
    strFileTitle = '';
    strFilePath = '';
    strShortPath = '';
    strDestFile = '';
    strMD5 = '';
    strSHA1 = '';
    nContentType = 0;
    dwFileSize = BigInt.zero;
    dtEffDateFr = DateTime.now();
    dtEffDateTo = dtEffDateFr!.add(const Duration(days: 365 * 10));
    fileStatus = FileItemStatus.normal;
    nTransferType = 1;
    strFileTitle = fileTitle;
    nContentType = contentType;
    tmFileModify = lastModified;
  }

  FileInfoData.uuidTitleDest(this.uuid, String fileTitle, String destFile,
      int contentType, DateTime lastModified) {
    uiID = 0;
    strFileTitle = '';
    strFilePath = '';
    strShortPath = '';
    strDestFile = '';
    strMD5 = '';
    strSHA1 = '';
    nContentType = 0;
    dwFileSize = BigInt.zero;
    dtEffDateFr = DateTime.now();
    dtEffDateTo = dtEffDateFr!.add(const Duration(days: 365 * 10));
    fileStatus = FileItemStatus.normal;
    nTransferType = 1;
    strFileTitle = fileTitle;
    strDestFile = destFile;
    nContentType = contentType;
    tmFileModify = lastModified;
  }

  FileInfoData.idTitleDest(int uiID, String fileTitle, String destFile,
      int contentType, DateTime lastModified) {
    uiID = 0;
    strFileTitle = '';
    strFilePath = '';
    strShortPath = '';
    strDestFile = '';
    strMD5 = '';
    strSHA1 = '';
    nContentType = 0;
    dwFileSize = BigInt.zero;
    dtEffDateFr = DateTime.now();
    dtEffDateTo = dtEffDateFr!.add(const Duration(days: 365 * 10));
    fileStatus = FileItemStatus.normal;
    nTransferType = 1;
    uiID = uiID;
    strFileTitle = fileTitle;
    strDestFile = destFile;
    nContentType = contentType;
    tmFileModify = lastModified;
  }

  void writeToXML(XmlItem pXmlItem, bool bChecksum) {
    pXmlItem.addItem("m_uiID", uiID);
    pXmlItem.addItem("uuid", uuid);
    //pXmlItem.addItem("m_strFilePath", strFilePath);
    pXmlItem.addItem("m_strFileTitle", strFileTitle);
    pXmlItem.addItem("m_strShortPath", strShortPath);
    pXmlItem.addItem("m_strDestFile", strDestFile);
    //pXmlItem.addItem("m_strTempPath", strTempPath);
    pXmlItem.addItem("m_dwFileSize", dwFileSize);
    pXmlItem.addItem("m_nContentType", nContentType);
    pXmlItem.addItem("m_tmFileCreate", tmFileCreate);
    pXmlItem.addItem("m_tmFileModify", tmFileModify);
    //pXmlItem.addItem("m_bSkipFtp", bSkipFtp);
    pXmlItem.addItem("m_dtEffDateFr", dtEffDateFr);
    pXmlItem.addItem("m_dtEffDateTo", dtEffDateTo);

    if (bChecksum) {
      pXmlItem.addItem("m_strMD5", strMD5);
      pXmlItem.addItem("m_strSHA1", strSHA1);
    }

    pXmlItem.addItem("m_Status", fileStatus.status);
    pXmlItem.addItem("m_nTransferType", nTransferType);
  }

  void writeToXMLContentLog(XmlItem pXmlItem) {
    pXmlItem.addItem("m_uiID", uiID);
    pXmlItem.addItem("m_strFileTitle", strFileTitle);
    pXmlItem.addItem("m_strShortPath", strShortPath);
    pXmlItem.addItem("m_strDestFile", strDestFile);
    pXmlItem.addItem("m_dwFileSize", dwFileSize);
    pXmlItem.addItem("m_nContentType", nContentType);
    pXmlItem.addItem("m_tmFileModify", tmFileModify);
    pXmlItem.addItem("m_strMD5", strMD5);
    pXmlItem.addItem("m_Status", fileStatus.status);
  }

  void getFromXML(XmlItem pXmlItem) {
    uiID = pXmlItem.getItemValueI("m_uiID");
    uuid = pXmlItem.getItemValue("uuid");
    //strFilePath = pXmlItem.getItemValue("m_strFilePath");
    strFileTitle = pXmlItem.getItemValue("m_strFileTitle");
    strShortPath = pXmlItem.getItemValue("m_strShortPath");
    strDestFile = pXmlItem.getItemValue("m_strDestFile");
    //strTempPath = pXmlItem.getItemValue("m_strTempPath");
    dwFileSize = pXmlItem.getItemValueI64("m_dwFileSize");
    nContentType = pXmlItem.getItemValueI("m_nContentType");
    tmFileCreate = pXmlItem.getItemValueD("m_tmFileCreate");
    tmFileModify = pXmlItem.getItemValueD("m_tmFileModify");
    dtEffDateFr = pXmlItem.getItemValueD("m_dtEffDateFr");
    dtEffDateTo = pXmlItem.getItemValueD("m_dtEffDateTo");

    fileStatus = FileItemStatus.fromInt(pXmlItem.getItemValueI("m_Status"));
    bool bSkipFtp = pXmlItem.getItemValueI("m_bSkipFtp") > 0;
    if (bSkipFtp) {
      fileStatus = FileItemStatus.skip;
    }
    nTransferType = pXmlItem.getItemValueI("m_nTransferType");

    strMD5 = pXmlItem.getItemValue("m_strMD5");
    strSHA1 = pXmlItem.getItemValue("m_strSHA1");
  }

  bool isSameAs(
      {FileInfoData? pFileInfo,
      String? strFileInfo,
      String? uuid,
      int? nContentType}) {
    if (pFileInfo != null) {
      return (strDestFile.toLowerCase() ==
              pFileInfo.strDestFile.toLowerCase() &&
          nContentType == pFileInfo.nContentType);
    } else if (strFileInfo != null) {
      return (strFileInfo.toLowerCase() == strDestFile.toLowerCase() &&
          nContentType == this.nContentType);
    } else if (uuid != null) {
      return (uuid.toLowerCase() == this.uuid!.toLowerCase() &&
          nContentType == this.nContentType);
    }

    return false;
  }

  bool isChanged(FileInfoData pFileInfo) {
    if (strMD5 != null &&
        strMD5!.isNotEmpty &&
        pFileInfo.strMD5 != null &&
        pFileInfo.strMD5!.isNotEmpty) {
      if (strMD5 == pFileInfo.strMD5) return false;
    } else {
      if (dwFileSize == pFileInfo.dwFileSize &&
          tmFileModify!.isAtSameMomentAs(pFileInfo.tmFileModify!)) {
        return false;
      }
    }
    return true;
  }
}
