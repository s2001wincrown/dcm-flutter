import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

class DownloadFileInfoData extends FileInfoData {
  String? strTempPath;
  String? strDestPath;

  DownloadFileInfoData()
      : super.create(
            strFilePath: '',
            strShortPath: '',
            strDestFile: '',
            strFileTitle: '',
            dwFileSize: BigInt.zero);

  DownloadFileInfoData.full({
    super.uiID,
    required super.strFileTitle,
    super.strFilePath,
    required super.strShortPath,
    required super.strDestFile,
    super.uuid,
    super.strMD5,
    super.strSHA1,
    super.tmFileModify,
    super.tmFileCreate,
    DateTime? effDateFr,
    DateTime? effDateTo,
    required super.dwFileSize,
    super.nContentType = -1,
    super.nTransferType = 1,
    super.fileStatus = FileItemStatus.normal,
    this.strDestPath,
    this.strTempPath,
  }) : super.create(dtEffDateFr: effDateFr, dtEffDateTo: effDateTo);

  DownloadFileInfoData.copyFrom(DownloadFileInfoData other)
      : super.copy(other) {
    strTempPath = other.strTempPath;
    strDestPath = other.strDestPath;
  }

  DownloadFileInfoData.fromFileInfo(super.other) : super.copy();

  @override
  void writeToXML(XmlItem pXmlItem, [bool bChecksum = true]) {
    super.writeToXML(pXmlItem, bChecksum);
    pXmlItem.addItem('m_strTempPath', strTempPath);
    pXmlItem.addItem('m_strDestPath', strDestPath);
  }

  @override
  void getFromXML(XmlItem pXmlItem) {
    super.getFromXML(pXmlItem);
    strTempPath = pXmlItem.getItemValue('m_strTempPath');
    strDestPath = pXmlItem.getItemValue('m_strDestPath');
  }
}
