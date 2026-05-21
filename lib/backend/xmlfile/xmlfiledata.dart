import 'package:dcm/backend/xmlfile/xmlitem.dart';

/// XML文件数据基类
abstract class XmlFileData {
  void writeToXML(XmlItem pXmlItem) {}
  void getFromXML(XmlItem pXmlItem) {}
  XmlFileData? createObject() => null;
}
