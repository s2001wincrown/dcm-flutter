import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

class DownloadFileInfoData extends FileInfoData {
  String tempPath = '';
  String destPath = '';

  DownloadFileInfoData()
      : super(
            strFilePath: '',
            strShortPath: '',
            strDestFile: '',
            strFileTitle: '',
            nContentType: -1,
            dwFileSize: BigInt.zero);

  DownloadFileInfoData.copy(DownloadFileInfoData other) : super.copy(other) {
    tempPath = other.tempPath;
    destPath = other.destPath;
  }

  @override
  void writeToXML(XmlItem pXmlItem, bool bChecksum) {
    super.writeToXML(pXmlItem, bChecksum);
    pXmlItem.addItem('m_strTempPath', tempPath);
    pXmlItem.addItem('m_strDestPath', destPath);
  }

  @override
  void getFromXML(XmlItem pXmlItem) {
    super.getFromXML(pXmlItem);
    tempPath = pXmlItem.getItemValue('m_strTempPath');
    destPath = pXmlItem.getItemValue('m_strDestPath');
  }
}
