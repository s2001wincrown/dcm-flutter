import 'dart:io';
import 'dart:ui';

import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:dcm/backend/xmlfile/xmlnodewrapper.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml.dart';

enum XfOpen { read, write, exclread }

enum XflError {
  none,
  cancelled,
  missingRoot,
  badMsxml,
  errorInvalidHandle,
  last,
  notInitEncryption,
  unknownEncryption
}

/// XML文件基础类
class XmlFile {
  String strDocVersion = '7.0.0.1';

  late XmlItem _xiRoot;
  String _sHeader = '';
  String _sStylesheet = '';
  String _sFilePath = '';
  XflError _xflError = XflError.none;

  XmlFile([String? szRootItemName]) {
    _xiRoot = XmlItem(null, szRootItemName ?? '');
  }

  bool load(String szFilePath,
      [String? szRootItemName, bool bDecrypt = false]) {
    if (szFilePath.isEmpty) return false;

    close();

    String strRootItemName = szRootItemName ?? '';
    if (strRootItemName.isEmpty && _xiRoot.getName().isNotEmpty) {
      strRootItemName = _xiRoot.getName();
    }

    if (open(szFilePath, XfOpen.read)) {
      return loadEx(strRootItemName);
    }
    return false;
  }

  bool loadEx([String? szRootItemName]) {
    String szFile = '';
    try {
      File file = File(_sFilePath);
      szFile = file.readAsStringSync();
    } catch (e) {
      logE('Error loading file: $e');
      return false;
    }

    String strRootItemName = szRootItemName ?? '';
    if (strRootItemName.isEmpty && _xiRoot.getName().isNotEmpty) {
      strRootItemName = _xiRoot.getName();
    }

    bool bRes = false;
    try {
      XmlDocumentWrapper doc = XmlDocumentWrapper();
      if (!doc.loadXML(szFile)) {
        String sFile = fixInputString(szFile, strRootItemName);

        // then try again
        if (!doc.loadXML(sFile)) _xflError = XflError.badMsxml;
      }

      // now read it into XmlItem structures
      if (_xflError == XflError.none) {
        if (!parseRootItem(strRootItemName, doc.detach())) {
          logE("Miss root item.");
          _xflError = XflError.missingRoot;
        } else {
          bRes = true;
        }
      }
      return parseRootItem(strRootItemName, doc.detach());
    } catch (e) {
      logE('Error parsing XML: $e');
      _xflError = XflError.badMsxml;
    }

    return bRes;
  }

  bool loadXml(String szXML, [String? szRootItemName]) {
    String strRootItemName = szRootItemName ?? '';
    if (strRootItemName.isEmpty && (_xiRoot.getName().isNotEmpty)) {
      strRootItemName = _xiRoot.getName();
    }

    XmlDocumentWrapper doc = XmlDocumentWrapper();
    bool bRes =
        (doc.loadXML(szXML) && parseRootItem(strRootItemName, doc.detach()));

    return bRes;
  }

  String fixInputString(String sXml, String szRootItem) {
    sXml = XmlItem.validateString(sXml, ' ');

    // check for any other obvious problems
    if (szRootItem.isNotEmpty) {
      String sRoot = szRootItem;
      sRoot = "<$sRoot";

      int nRoot = sXml.indexOf(sRoot);
      int nHeader = sXml.indexOf("<?xml");
      if (nHeader > nRoot) {
        // what should we do?

        /*
				// if there is another instance of szRootItem after the
				// header tag then try deleting everything before the header
				// tag
				if (sXml.Find(sRoot, nHeader) != -1)
				{
					sXml = sXml.Right(nHeader);
				}
				else // try moving the header to the start
				{
					int nHeaderEnd = sXml.Find('>', nHeader) + 1;
					String sHeader = sXml.Mid(nHeader, nHeaderEnd - nHeader);

					sXml = sHeader + sXml.Left(nHeader) + sXml.Right(nHeaderEnd);
				}
	*/
      }
    }

    return sXml;
  }

  bool save(String szFilePath) {
    if (szFilePath.isEmpty) return false;

    close();

    if (open(szFilePath, XfOpen.write)) {
      bool bRes = saveEx();
      close();
      return bRes;
    }
    return false;
  }

  bool saveEx() {
    String sXml = export();
    if (sXml.isNotEmpty) {
      try {
        File file = File(_sFilePath);
        file.writeAsStringSync(sXml);
        return true;
      } catch (e) {
        logE('Error saving file: $e');
        return false;
      }
    }
    return false;
  }

  bool open(String szFilePath, XfOpen nOpenFlag, [bool bDecrypt = false]) {
    if (szFilePath.isEmpty) return false;

    close();
    _sFilePath = szFilePath;
    return true;
  }

  bool parseRootItem(String szRootItemName, xml.XmlDocument? pDoc) {
    if (pDoc == null) {
      return false;
    }

    _xiRoot.reset();

    String sRootItem = szRootItemName.trim();

    xml.XmlElement pNode = pDoc.rootElement;
    if (sRootItem.isNotEmpty) {
      if (pNode.name.local != sRootItem) {
        return false;
      }
    } else {
      _xiRoot.setName(
          pNode.nodeType == xml.XmlNodeType.ELEMENT ? pNode.name.local : '');
    }

    _sHeader = '<?xml version="1.0" encoding="utf-8"?>';

    parseItem(_xiRoot, pNode);

    return true;
  }

  bool parseItem(XmlItem xi, xml.XmlNode pNode) {
    if (pNode.nodeType == xml.XmlNodeType.ELEMENT) {
      xml.XmlElement element = pNode as xml.XmlElement;
      for (var attribute in element.attributes) {
        xi.addItem(attribute.name.local, attribute.value);
      }
    }

    for (var child in pNode.children) {
      if (child.nodeType == xml.XmlNodeType.COMMENT ||
          child.nodeType == xml.XmlNodeType.TEXT) {
        logD('child: ${child.toXmlString()}');
        continue;
      }

      if (child.nodeType == xml.XmlNodeType.ELEMENT) {
        xml.XmlElement element = child as xml.XmlElement;
        XiType nType = XiType.element;
        var cdata = element.children
            .where((e) => e.nodeType == xml.XmlNodeType.CDATA)
            .firstOrNull;
        /*if (element.children.any((e) => e.nodeType == xml.XmlNodeType.CDATA)) {
          nType = XiType.cdata;
        }*/
        if (cdata == null) {
          XmlItem? xiAdd =
              xi.addItem(element.name.local, element.innerText, nType);
          parseItem(xiAdd!, element);
        } else {
          nType = XiType.cdata;
          xi.addItem(element.name.local, cdata.value, nType);
        }
      } else {
        // if (child.nodeType == xml.XmlNodeType.TEXT)
        logD('child attrib: ${child.toXmlString()}');
        xi.setValue(child.toXmlString());
        xi.setType(XiType.attrib);
      }
    }

    return true;
  }

  String export() {
    String sOutput = '';

    var builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element(_xiRoot.getName(), nest: () {
      exportItem(_xiRoot, builder);
    });

    var doc = builder.buildDocument();
    sOutput = doc.toXmlString(pretty: true);

    return sOutput;
  }

  void exportItem(XmlItem pItem, xml.XmlBuilder builder) {
    if (pItem.getValue().isNotEmpty) {
      builder.text(pItem.getValue());
    }

    var pos = pItem.getFirstItemPos();
    while (pos.moveNext()) {
      String sItem = pos.current.getName();
      if (pos.current.isAttribute()) {
        builder.attribute(sItem, pos.current.getValue());
      } else {
        builder.element(sItem, nest: () {
          exportItem(pos.current, builder);
        });
      }
    }
  }

  void reset() {
    _xiRoot.reset();
  }

  XmlItem root() {
    return _xiRoot;
  }

  XmlItem? getItem(String szItemName) {
    return _xiRoot.getItem(szItemName);
  }

  XmlItem? findItem(String szItemName, dynamic itemValue,
      [bool bSearchChildren = true]) {
    return _xiRoot.findItem(szItemName, itemValue, bSearchChildren);
  }

  XmlItem? addItem(String szName,
      [dynamic value, XiType nType = XiType.attrib]) {
    return _xiRoot.addItem(szName, value, nType);
  }

  XmlItem? setItemValue(String szName, dynamic value,
      [XiType nType = XiType.attrib]) {
    return _xiRoot.setItemValue(szName, value, nType);
  }

  bool deleteItem(String szItemName) {
    return _xiRoot.deleteItem(szItemName: szItemName);
  }

  String getItemValue(String szItemName, [String szSubItemName = '']) {
    return _xiRoot.getItemValue(szItemName, szSubItemName);
  }

  int getItemValueI(String szItemName, [String szSubItemName = '']) {
    String value = _xiRoot.getItemValue(szItemName, szSubItemName);
    return int.tryParse(value) ?? 0;
  }

  BigInt getItemValueI64(String szItemName, [String szSubItemName = '']) {
    String value = _xiRoot.getItemValue(szItemName, szSubItemName);
    return BigInt.tryParse(value) ?? BigInt.from(0);
  }

  double getItemValueF(String szItemName, [String szSubItemName = '']) {
    String value = _xiRoot.getItemValue(szItemName, szSubItemName);
    return double.tryParse(value) ?? 0.0;
  }

  bool getItemValueB(String szItemName, [String szSubItemName = '']) {
    String value = _xiRoot.getItemValue(szItemName, szSubItemName);
    return (int.tryParse(value) ?? 0) > 0;
  }

  int? getItemValueR(String szItemName, [String szSubItemName = '']) {
    return _xiRoot.getItemValueR(szItemName, szSubItemName);
  }

  DateTime? getItemValueD(String szItemName, [String szSubItemName = '']) {
    return _xiRoot.getItemValueD(szItemName, szSubItemName);
  }

  Rect? getItemValueRect(String szItemName, [String szSubItemName = '']) {
    return _xiRoot.getItemValueRect(szItemName, szSubItemName);
  }

  List<String>? getItemValueArray(String szItemName,
      [String szSubItemName = '']) {
    return _xiRoot.getItemValueArray(szItemName, szSubItemName);
  }

  void close() {}

  String getFilePath() {
    return _sFilePath;
  }

  String getHeader() {
    return _sHeader;
  }

  void setHeader(String szHeader) {
    _sHeader = szHeader.toLowerCase();
  }

  void setDocVersion(String szDocVersion) {
    strDocVersion = szDocVersion;
  }

  String getDocVersion() {
    return strDocVersion;
  }

  void setRootItemName(String szRootItemName) {
    if (_xiRoot != null) _xiRoot?.setName(szRootItemName);
  }

  String getRootItemName() {
    if (_xiRoot != null) return _xiRoot?.getName() ?? '';

    return '';
  }

  String getStylesheet() {
    return _sStylesheet;
  }

  void setStylesheet(String szStylesheet) {
    _sStylesheet = szStylesheet;
  }

  void setError(XflError xflError) {
    _xflError = xflError;
  }

  void sortItems(String szItemName, String szKeyName,
      [bool bAscending = true]) {
    _xiRoot.sortItems(szItemName, szKeyName, bAscending);
  }

  XmlItem newItem(String szName) {
    return XmlItem(null, szName);
  }
}
