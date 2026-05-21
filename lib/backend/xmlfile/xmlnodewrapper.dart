import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart' as xml;

/// XML节点包装器类
class XmlNodeWrapper {
  final xml.XmlNode? _node;

  XmlNodeWrapper(this._node);

  /// 获取节点值（属性值）
  String getValue(String valueName) {
    if (!isValid()) return '';

    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      return element.getAttribute(valueName) ?? '';
    }

    return '';
  }

  /// 检查节点是否有效
  bool isValid() {
    return _node != null;
  }

  /// 获取前一个兄弟节点
  XmlNodeWrapper? getPrevSibling() {
    if (!isValid()) return null;

    final siblings =
        _node!.parent?.children.where((child) => child != _node).toList();
    if (siblings != null) {
      final index = siblings.indexOf(_node!);
      if (index > 0) {
        return XmlNodeWrapper(siblings[index - 1]);
      }
    }
    return null;
  }

  /// 获取下一个兄弟节点
  XmlNodeWrapper? getNextSibling() {
    if (!isValid()) return null;

    final siblings =
        _node!.parent?.children.where((child) => child != _node).toList();
    if (siblings != null) {
      final index = siblings.indexOf(_node!);
      if (index >= 0 && index < siblings.length - 1) {
        return XmlNodeWrapper(siblings[index + 1]);
      }
    }
    return null;
  }

  /// 根据节点名获取子节点
  XmlNodeWrapper? getNode(String nodeName) {
    if (!isValid()) return null;

    if (_node!.children.isNotEmpty) {
      for (final child in _node!.children) {
        if (child.nodeType == xml.XmlNodeType.ELEMENT &&
            (child as xml.XmlElement).name.local == nodeName) {
          return XmlNodeWrapper(child);
        }
      }
    }

    return null;
  }

  /// 根据索引获取子节点
  XmlNodeWrapper? getNodeByIndex(int nodeIndex) {
    if (!isValid()) return null;

    if (_node!.children.isNotEmpty) {
      final children = _node!.children.whereType<xml.XmlElement>().toList();
      if (children.length > nodeIndex) {
        return XmlNodeWrapper(children[nodeIndex]);
      }
    }

    return null;
  }

  /// 查找节点（同getNode）
  XmlNodeWrapper? findNode(String searchString) {
    return getNode(searchString);
  }

  /// 脱离节点
  xml.XmlNode? detach() {
    return isValid() ? _node : null;
  }

  /// 获取子节点数量
  int numNodes() {
    if (isValid()) {
      return _node!.children.length;
    } else {
      return 0;
    }
  }

  /// 设置属性值
  void setValue(String valueName, dynamic value) {
    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      element.setAttribute(valueName, value.toString());
    }
  }

  /// 添加子节点
  xml.XmlNode? appendChild(xml.XmlNode pNode) {
    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      element.children.add(pNode);
      return pNode;
    }
    return null;
  }

  /// 插入节点
  xml.XmlNode? insertNode(int index, String nodeName) {
    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      final newElement = xml.XmlElement(xml.XmlName(nodeName));

      if (index < element.children.length) {
        element.children.insert(index, newElement);
      } else {
        element.children.add(newElement);
      }

      return newElement;
    }
    return null;
  }

  /// 获取XML字符串
  String getXML() {
    if (isValid()) {
      return _node.toString();
    }
    return '';
  }

  /// 移除节点
  bool removeNode(xml.XmlNode pNode) {
    if (!isValid()) return false;

    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      return element.children.remove(pNode);
    }
    return false;
  }

  /// 获取父文档
  XmlDocumentWrapper? parentDocument() {
    if (isValid()) {
      var parent = _node;
      while (parent != null && parent.parent != null) {
        parent = parent.parent;
      }
      if (parent is xml.XmlDocument) {
        return XmlDocumentWrapper.fromXmlDocument(parent);
      }
    }
    return null;
  }

  xml.XmlNode? createCDATASection(String data) {
    if (isValid()) {
      var parent = _node;
      while (parent != null && parent.parent != null) {
        parent = parent.parent;
      }
      if (parent is xml.XmlDocument) {
        var xmlCDATA = xml.XmlCDATA(data);
        parent.children.add(xmlCDATA);

        return xmlCDATA;
      }
    }
    return null;
  }

  /// 获取接口节点
  xml.XmlNode? interface() {
    if (isValid()) return _node;
    return null;
  }

  /// 检查是否包含CDATA
  bool isCDATA() {
    if (isValid()) {
      for (final child in _node!.children) {
        if (child.nodeType == xml.XmlNodeType.CDATA) {
          return true;
        }
      }
    }
    return false;
  }

  /// 插入节点到指定参考节点之前
  xml.XmlNode? insertBefore(xml.XmlNode refNode, String nodeName) {
    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      final newElement = xml.XmlElement(xml.XmlName(nodeName));

      final index = element.children.indexOf(refNode);
      if (index >= 0) {
        element.children.insert(index, newElement);
      } else {
        element.children.add(newElement);
      }

      return newElement;
    }
    return null;
  }

  /// 插入节点到指定参考节点之后
  xml.XmlNode? insertAfter(xml.XmlNode refNode, String nodeName) {
    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      final newElement = xml.XmlElement(xml.XmlName(nodeName));

      final index = element.children.indexOf(refNode);
      if (index >= 0) {
        element.children.insert(index + 1, newElement);
      } else {
        element.children.add(newElement);
      }

      return newElement;
    }
    return null;
  }

  /// 移除指定名称的所有节点
  void removeNodes(String searchStr) {
    if (!isValid()) return;

    if (_node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      element.children.removeWhere((child) =>
          child.nodeType == xml.XmlNodeType.ELEMENT &&
          (child as xml.XmlElement).name.local == searchStr);
    }
  }

  /// 获取父节点
  XmlNodeWrapper? parent() {
    if (isValid() && _node!.parent != null) {
      return XmlNodeWrapper(_node!.parent!);
    }
    return null;
  }

  /// 获取节点名称
  String name() {
    if (isValid() && _node is xml.XmlElement) {
      return (_node as xml.XmlElement).name.local;
    }
    return '';
  }

  /// 设置文本内容
  void setText(String text) {
    if (isValid()) {
      if (_node is xml.XmlElement) {
        final element = _node as xml.XmlElement;
        // 清除现有内容
        element.children.clear();
        // 添加新文本节点
        element.children.add(xml.XmlText(text));
      }
    }
  }

  /// 获取文本内容
  String getText() {
    if (isValid()) {
      if (isCDATA()) {
        for (final child in _node!.children) {
          if (child.nodeType == xml.XmlNodeType.CDATA) {
            return child.toXmlString();
          }
        }
      } else {
        if (_node is xml.XmlElement) {
          final element = _node as xml.XmlElement;
          if (element.children.isNotEmpty) {
            final firstChild = element.children.first;
            if (firstChild is xml.XmlText) {
              return firstChild.value;
            }
          }
        } else {
          return _node.toString();
        }
      }
    }
    return '';
  }

  /// 替换节点
  void replaceNode(xml.XmlNode oldNode, xml.XmlNode newNode) {
    if (isValid() && _node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      final index = element.children.indexOf(oldNode);
      if (index >= 0) {
        element.children[index] = newNode;
      }
    }
  }

  /// 获取属性数量
  int numAttributes() {
    if (isValid() && _node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      return element.attributes.length;
    }
    return 0;
  }

  /// 获取指定索引的属性名
  String getAttribName(int index) {
    if (isValid() && _node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      if (index >= 0 && index < element.attributes.length) {
        return element.attributes.elementAt(index).name.local;
      }
    }
    return '';
  }

  /// 获取指定索引的属性值
  String getAttribVal(int index) {
    if (isValid() && _node is xml.XmlElement) {
      final element = _node as xml.XmlElement;
      if (index >= 0 && index < element.attributes.length) {
        return element.attributes.elementAt(index).value;
      }
    }
    return '';
  }

  /// 获取节点类型值
  int nodeTypeVal() {
    if (isValid()) {
      return _node!.nodeType.index;
    }
    return -1;
  }
}

/// XML文档包装器类
class XmlDocumentWrapper {
  xml.XmlDocument? _xmldoc;

  static const String defaultHeader = 'version="1.0" encoding="UTF-8"';
  static const String defaultVersion = '1.0';
  static const String defaultEncoding = 'utf-8';
  static const String defaultStandalone = 'yes';

  XmlDocumentWrapper() {
    _xmldoc = null;
  }

  XmlDocumentWrapper.fromString(String header, String szRootItem) {
    try {
      final builder = xml.XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="utf-8"');
      if (szRootItem.isNotEmpty) {
        builder.element(szRootItem, nest: () {});
      }
      _xmldoc = builder.buildDocument();
    } catch (e) {
      debugPrint('Error creating XML document: $e');
    }
  }

  XmlDocumentWrapper.fromXmlDocument(this._xmldoc);

  bool isValid() {
    return _xmldoc != null;
  }

  String getHeader(bool bAsXml) {
    String sHeader = '';
    if (isValid()) {
      String version =
          _xmldoc!.rootElement.getAttribute('version') ?? defaultVersion;
      String encoding =
          _xmldoc!.rootElement.getAttribute('encoding') ?? defaultEncoding;

      if (version.isNotEmpty && encoding.isNotEmpty) {
        String sVersion = '';
        String sEncoding = '';

        if (version.isNotEmpty) sVersion = "version='$version'";
        if (encoding.isNotEmpty) sEncoding = " encoding='$encoding'";

        sHeader = "$sVersion$sEncoding";
      }

      if (sHeader.isEmpty) {
        sHeader = defaultHeader;
      }

      if (bAsXml) {
        sHeader = "<?xml $sHeader?>";
      }
    }

    return sHeader;
  }

  void setHeader(String version, String encoding, bool standalone) {
    if (isValid()) {
      // 在Flutter/Dart中，XML库不直接支持设置这些头部属性
      // 我们可以创建一个新的文档来实现
      final builder = xml.XmlBuilder();
      builder.processing('xml',
          'version="$version" encoding="$encoding" standalone="${standalone ? "yes" : "no"}"');
      // 添加现有的根元素
      builder.element(_xmldoc!.rootElement.name.local,
          namespace: _xmldoc!.rootElement.name.namespaceUri, nest: () {
        _xmldoc!.rootElement.children.toList().forEach((child) {
          if (child is xml.XmlElement) {
            builder.element(child.name.local, nest: () {
              child.attributes.toList().forEach((attr) {
                builder.attribute(attr.name.local, attr.value);
              });
              if (child.innerText.isNotEmpty) {
                builder.text(child.innerText);
              }
            });
          } else if (child is xml.XmlText) {
            builder.text(child.value);
          }
        });
      });
      _xmldoc = builder.buildDocument();
    }
  }

  xml.XmlDocument? detach() {
    if (!isValid()) return null;
    return _xmldoc;
  }

  XmlDocumentWrapper? clone() {
    if (!isValid()) return null;

    final cloned = XmlDocumentWrapper();
    cloned._xmldoc = _xmldoc!.copy();
    return cloned;
  }

  bool load(String path, bool bPreserveWhiteSpace) {
    try {
      final file = File(path);
      final contents = file.readAsStringSync();
      _xmldoc = xml.XmlDocument.parse(contents);
    } catch (e) {
      debugPrint('Error loading XML file: $e');
      return false;
    }

    return isValid();
  }

  bool loadXML(String xmlString) {
    try {
      _xmldoc = xml.XmlDocument.parse(xmlString);
    } catch (e) {
      debugPrint('Error parsing XML string: $e');
      return false;
    }

    return isValid();
  }

  bool save(String path, bool bPreserveWhiteSpace) {
    if (!isValid()) return false;

    try {
      final file = File(path);
      file.writeAsStringSync(_xmldoc!.toXmlString(pretty: true));
      return true;
    } catch (e) {
      debugPrint('Error saving XML file: $e');
      return false;
    }
  }

  xml.XmlNode? asNode() {
    if (!isValid()) return null;
    return _xmldoc!.rootElement;
  }

  String getXML([String stylesheet = '', bool bPreserveWhiteSpace = false]) {
    if (!isValid()) return '';

    String xmlStr = _xmldoc!.toXmlString(pretty: true);

    // 添加样式表如果提供了
    if (stylesheet.isNotEmpty) {
      final headerEnd = xmlStr.indexOf('?>');
      if (headerEnd != -1) {
        final stylesheetStr =
            '<?xml-stylesheet href="$stylesheet" type="text/xsl"?>';
        xmlStr = xmlStr.substring(0, headerEnd + 2) +
            stylesheetStr +
            xmlStr.substring(headerEnd + 2);
      }
    }

    return xmlStr;
  }
}

/// XML节点列表包装器
class XmlNodeListWrapper {
  List<xml.XmlNode> _xmlNodeList = [];

  XmlNodeListWrapper(List<xml.XmlNode> pList) {
    _xmlNodeList = pList;
  }

  int count() {
    return isValid() ? _xmlNodeList.length : 0;
  }

  bool isValid() {
    return _xmlNodeList.isNotEmpty;
  }

  XmlNodeWrapper? next() {
    if (isValid()) {
      return XmlNodeWrapper(_xmlNodeList[0]);
    }
    return null;
  }

  void start() {
    if (isValid()) {
      // 在Flutter中不需要特殊操作
    }
  }

  XmlNodeWrapper? node(int index) {
    if (isValid() && index >= 0 && index < _xmlNodeList.length) {
      return XmlNodeWrapper(_xmlNodeList[index]);
    }
    return null;
  }

  xml.XmlDocument? asDocument() {
    if (isValid()) {
      final builder = xml.XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="utf-8"');
      builder.element('NodeList', nest: () {
        for (final node in _xmlNodeList) {
          if (node is xml.XmlElement) {
            builder.element(node.name.local, nest: () {
              node.attributes.toList().forEach((attr) {
                builder.attribute(attr.name.local, attr.value);
              });
              if (node.innerText.isNotEmpty) {
                builder.text(node.innerText);
              }
            });
          } else if (node is xml.XmlText) {
            builder.text(node.value);
          }
        }
      });
      return builder.buildDocument();
    } else {
      return null;
    }
  }
}

/// 示例使用方法
void main() {
  // 创建一个新的XML文档
  final doc = XmlDocumentWrapper.fromString('', "root");

  if (doc.isValid()) {
    final rootNode = XmlNodeWrapper(doc.asNode()!);

    // 添加一些子节点
    final child1 = rootNode.insertNode(0, "child1");
    if (child1 is xml.XmlElement) {
      child1.setAttribute("id", "1");
      child1.children.add(xml.XmlText("Child 1 content"));
    }

    final child2 = rootNode.insertNode(1, "child2");
    if (child2 is xml.XmlElement) {
      child2.setAttribute("id", "2");
      child2.children.add(xml.XmlText("Child 2 content"));
    }

    // 输出XML
    debugPrint(doc.getXML());

    // 保存到文件
    doc.save("example.xml", false);

    // 加载并解析
    final loadedDoc = XmlDocumentWrapper();
    if (loadedDoc.load("example.xml", false)) {
      debugPrint("Loaded XML:");
      debugPrint(loadedDoc.getXML());
    }
  }
}
