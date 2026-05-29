import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:xml/xml.dart' as xml;

// --- 主要的 XmlFileEx 类 ---
class XmlFileEx extends XmlFile {
  // ignore: constant_identifier_names
  static const String ENCODEDDATA = 'ENCODEDDATA';
  // ignore: constant_identifier_names
  static const String ENCODEDDATALEN = 'DATALEN';
  String? strPassword;
  bool needDecrypt = false;

  XmlFileEx([super.szRootItemName, String? password]) {
    strPassword = password ?? '';
    needDecrypt = password != null;
  }

  // --- 加密方法 ---
  bool encrypt([String? szPassword]) {
    if (szPassword == null || szPassword.isEmpty) {
      szPassword = strPassword;
    }
    if (szPassword == null || szPassword.isEmpty) {
      return false;
    }

    // 1. 导出根节点下的所有内容到字符串
    String sXml = '';
    var pos = root()!.getFirstItemPos();
    while (pos.moveNext()) {
      // 这里需要一个内部导出方法，只导出子节点，不包括根节点本身
      var builder = xml.XmlBuilder();
      _exportItem(pos.current, builder); // Use helper method
      var doc = builder.buildDocument();
      sXml += doc.toXmlString(); // Concatenate without XML declaration
    }

    // 2. 加密字符串
    Uint8List szXmlA = utf8.encode(sXml);
    if (szXmlA.isEmpty) return false;

    int nLength = szXmlA.length + 3;
    var sXmlA = Uint8List(nLength);
    sXmlA[0] = 0xEF;
    sXmlA[1] = 0xBB;
    sXmlA[2] = 0xBF; // BOM
    sXmlA.setRange(3, nLength, szXmlA);

    var results = Encodes.encrypt(sXmlA, szPassword);
    if (results.isNotEmpty) {
      // 3. 用单个CDATA项替换文件内容
      root()!.deleteAllItems();
      root()!.addItem(ENCODEDDATA, results, XiType.cdata);
      root()!.addItem(ENCODEDDATALEN, results.length.toString(), XiType.attrib);
      root()!.addItem('m_strDocVersion', getDocVersion(), XiType.attrib);
      return true;
    }
    return false;
  }

  // --- 内部导出项目辅助方法 (供加密使用) ---
  void _exportItem(XmlItem pItem, xml.XmlBuilder builder) {
    builder.element(pItem.getName(), nest: () {
      if (pItem.getValue().isNotEmpty && pItem.isAttribute()) {
        builder.attribute(pItem.getName(), pItem.getValue());
      } else if (pItem.getValue().isNotEmpty && pItem.isCDATA()) {
        builder.cdata(pItem.getValue());
      } else {
        // Attributes
        var pos = pItem.getFirstItemPos();
        while (pos.moveNext()) {
          if (pos.current.isAttribute()) {
            builder.attribute(pos.current.getName(), pos.current.getValue());
          }
        }
        // Child elements
        pos = pItem.getFirstItemPos();
        while (pos.moveNext()) {
          if (!pos.current.isAttribute()) {
            _exportItem(pos.current, builder);
          }
        }
      }
    });
  }

  // --- 检查是否已加密 ---
  bool _isEncrypted() => getItemValueI(ENCODEDDATALEN) > 0;

  // --- 解密方法 ---
  bool decrypt([String? szPassword]) {
    if (!_isEncrypted()) return true; // nothing to do

    szPassword = szPassword ?? strPassword;

    XmlItem? pXI = _getEncryptedBlock();
    if (pXI != null && pXI.getSibling() == null) {
      String? sFile = _decrypt(pXI.getValue(), szPassword!);
      if (sFile != null && sFile.isNotEmpty) {
        strPassword = szPassword;
        sFile = sFile.trim();
        sFile = '<ROOT>$sFile</ROOT>';

        // 删除CDATA项
        root()!.deleteItem(pXI: pXI);

        try {
          xml.XmlDocument doc = xml.XmlDocument.parse(sFile);
          xml.XmlNode node = doc.rootElement;
          return parseItem(root()!, node);
        } catch (ex) {
          debugPrint('Parse XML failed: $ex');
          setError(XflError.badMsxml);
        }
        return false;
      } else {
        setError(XflError.unknownEncryption);
        return false;
      }
    }

    setError(XflError.unknownEncryption);
    return false;
  }

  // --- 获取加密块 ---
  XmlItem? _getEncryptedBlock() {
    XmlItem? pXI;
    int nDataLen = getItemValueI(ENCODEDDATALEN);
    if (nDataLen > 0) {
      pXI = getItem(ENCODEDDATA);
      if (pXI == null) {
        // 向后兼容
        pXI = getItem('CDATA');
        if (pXI != null) {
          // 缺少标签
          pXI = root();
        }
      }
    }
    return pXI;
  }

  // --- 加载方法 ---
  @override
  bool load(String szFilePath, [String? szRootItemName, bool bDecrypt = true]) {
    needDecrypt = bDecrypt;
    return super.load(szFilePath, szRootItemName);
  }

  // --- 打开方法 ---
  @override
  bool open(String szFilePath, XfOpen nOpenFlag, [bool bDecrypt = true]) {
    needDecrypt = bDecrypt;
    return super.open(szFilePath, nOpenFlag);
  }

  // --- 加载扩展方法 ---
  @override
  bool loadEx([String? szRootItemName]) {
    if (!super.loadEx(szRootItemName)) return false;
    if (needDecrypt) return decrypt(null);
    return true;
  }

  // --- 加载XML方法 ---
  @override
  bool loadXml(String szXML, [String? szRootItemName]) {
    String strRootItemName = szRootItemName ?? '';
    if (strRootItemName.isEmpty && root()!.getName().isNotEmpty) {
      strRootItemName = root()!.getName();
    }
    needDecrypt = strPassword!.isNotEmpty;

    try {
      xml.XmlDocument doc = xml.XmlDocument.parse(szXML);
      bool bRes = parseRootItem(strRootItemName, doc);
      if (!bRes) return false;
      if (needDecrypt) return decrypt(null);
    } catch (e) {
      debugPrint('LoadXML failed: $e');
      return false;
    }
    return true;
  }

  // --- 内部解密方法 ---
  String? _decrypt(String szInput, String szPassword) {
    try {
      return Encodes.dcmDecrypt(szInput, szPassword);
    } catch (e) {
      debugPrint('XML file decrypt failed: $e');
      // e.printStackTrace(); // Dart doesn't have stack trace printing like Java
    }
    return null;
  }
}
