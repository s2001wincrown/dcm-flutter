import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfiledata.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';
import 'package:pair/pair.dart';

/// XML配置文件类
class XmlProfile extends XmlFile {
  String strFileName = '';
  String strRootItemName = '';

  XmlProfile({this.strFileName = '', this.strRootItemName = ''});

  XmlProfile.fromFile(String fileName) {
    strFileName = fileName;
    strRootItemName = '';
  }

  XmlProfile.empty() {
    strFileName = '';
    strRootItemName = '';
  }

  XmlItem? appendSection(String lpszSection) {
    return root().addItem(lpszSection, '', XiType.element);
  }

  XmlItem? appendNode(XmlItem pItem, String lpszList, String lpszData) {
    return pItem.addItem(lpszList, lpszData, XiType.element);
  }

  bool appendProfileString(
      String lpszSection, String lpszEntry, String lpszData) {
    XmlItem? pItem = setItemValue(lpszSection, '', XiType.element);
    if (pItem != null) {
      pItem.addItem(lpszEntry, lpszData, XiType.element);
      return true;
    }
    return false;
  }

  List<String> getSections() {
    List<String> sections = [];
    var pos = root().getFirstItemPos();
    while (pos.moveNext()) {
      sections.add(pos.current.getName());
    }

    return sections;
  }

  List<String> getSectionsByName(String lpszSection, bool bVal) {
    XmlItem? pSec = getItem(lpszSection);
    if (pSec == null) return [];

    return getSectionsInternal(pSec, bVal);
  }

  List<String> getSectionsInternal(XmlItem pSec, bool bVal) {
    var pos = pSec.getFirstItemPos();
    List<String> sections = [];
    while (pos.moveNext()) {
      if (!bVal) {
        sections.add(pos.current.getName());
      } else {
        sections.add(pos.current.getValue());
      }
    }
    return sections;
  }

  List<Pair<String, String>> getProfileArray(XmlItem pSec) {
    List<Pair<String, String>> arrKeys = [];
    var pos = pSec.getFirstItemPos();
    while (pos.moveNext()) {
      var data = Pair<String, String>(
          getNodeText(pos.current, 'Name'), getNodeText(pos.current, 'Value'));
      arrKeys.add(data);
    }
    return arrKeys;
  }

  bool writeProfileArray(XmlItem pSec, List<Pair<String, String>> arrKeys) {
    pSec.deleteAllItems();
    for (int i = 0; i < arrKeys.length; i++) {
      XmlItem? xiString = pSec.setItemValue('String', '', XiType.element);
      if (xiString != null) {
        var data = arrKeys[i];
        xiString.setItemValue('Name', data.key, XiType.element);
        xiString.setItemValue('Value', data.value, XiType.element);
      }
    }

    return true;
  }

  bool writeProfileList(String lpszSection, List<dynamic> lstPlay) {
    XmlItem? xi = root().newItem(lpszSection); //
    if (xi != null) {
      for (var pXMLListData in lstPlay) {
        if (pXMLListData is XmlFileData) {
          pXMLListData.writeToXML(xi);
        }
      }

      return true;
    }

    return false;
  }

  List<T> getProfileList<T extends XmlFileData>(String lpszSection, T pObject) {
    List<T> lstPlay = [];

    XmlItem? pXItem = root().getItem(lpszSection);
    if (pXItem != null) {
      var pos = pXItem.getFirstItemPos();
      while (pos.moveNext()) {
        T? data = pObject.createObject() as T?;
        if (data != null) {
          data.getFromXML(pos.current);
          lstPlay.add(data);
        }
      }
    }

    return lstPlay;
  }

  bool writeSections(XmlItem pItem, List<String> secs) {
    deleteChildNode(pItem);
    for (int i = 0; i < secs.length; i++) {
      appendNode(pItem, 'String', secs[i]);
    }
    return true;
  }

  bool deleteChildNode(XmlItem pItem) {
    pItem.deleteAllItems();

    return true;
  }

  bool deleteSection(XmlItem? pItem) {
    if (pItem != null) {
      deleteItem(pItem.getName());
    } else {
      reset();
    }
    return true;
  }

  bool deleteSectionByName(String? lpszSection) {
    if (lpszSection == null) {
      reset();
    } else {
      return deleteItem(lpszSection);
    }
    return true;
  }

  XmlItem? getEntry(String lpszSection, String lpszEntry) {
    return setItemValue(lpszSection, lpszEntry, XiType.element);
  }

  XmlItem? getSection(String lpszSection) {
    return setItemValue(lpszSection, '', XiType.element);
  }

  bool writeProfileInt(String lpszSection, String lpszEntry, int nValue) {
    XmlItem? pSec = root().addItem(lpszSection, '', XiType.element);
    if (pSec != null) {
      pSec.setItemValue(lpszEntry, nValue.toString(), XiType.element);
      return true;
    }

    return false;
  }

  bool writeProfileString(
      String lpszSection, String lpszEntry, String lpszData) {
    XmlItem? pSec = root().addItem(lpszSection, '', XiType.element);
    if (pSec != null) {
      pSec.setItemValue(lpszEntry, lpszData, XiType.element);
      return true;
    }

    return false;
  }

  bool writeProfileDateTime(
      String lpszSection, String lpszEntry, DateTime dtData) {
    XmlItem? pSec = setItemValue(lpszSection, '', XiType.element);
    if (pSec != null) {
      //"%d/%m/%Y %H:%M:%S"
      String attrText = DateFormat('dd/MM/yyyy HH:mm:ss').format(dtData);
      pSec.setItemValue(lpszEntry, attrText, XiType.element);
      return true;
    }
    return false;
  }

  int getProfileInt(String lpszSection, String lpszEntry, int nDefault) {
    XmlItem? pSec = getItem(lpszSection);
    if (pSec != null) {
      XmlItem? pItem = pSec.getItem(lpszEntry);
      if (pItem != null) return pItem.getValueI();
    }
    return nDefault;
  }

  String getProfileString(
      String lpszSection, String lpszEntry, String lpszDefault) {
    String strContent = lpszDefault;
    XmlItem? pSec = getItem(lpszSection);
    if (pSec != null) {
      XmlItem? pItem = pSec.getItem(lpszEntry);
      if (pItem != null) strContent = pItem.getValue();
    }
    return strContent;
  }

  DateTime getProfileDateTime(
      String lpszSection, String lpszEntry, DateTime dtDefault) {
    String strContent = '';
    XmlItem? pSec = getItem(lpszSection);
    if (pSec != null) {
      XmlItem? pItem = pSec.getItem(lpszEntry);
      if (pItem != null) {
        strContent = pItem.getValue();
      }
    }
    if (strContent.isEmpty) {
      return dtDefault;
    }

    return DateFormat('dd/MM/yyyy HH:mm:ss').tryParse(strContent) ?? dtDefault;
  }

  bool saveProfile([String szStylesheet = '']) {
    if (szStylesheet.isNotEmpty) {
      // 设置样式表
    }
    return save(strFileName);
  }

  bool loadProfile({String? lpszFileName, String? szRootItemName}) {
    if (lpszFileName != null && lpszFileName.isNotEmpty) {
      strFileName = lpszFileName;
    }
    if (szRootItemName != null && szRootItemName.isNotEmpty) {
      strRootItemName = szRootItemName;
    }
    if (strRootItemName.isNotEmpty) {
      if (!createProfile(strRootItemName)) return false;
    }

    return load(strFileName, strRootItemName);
  }

  bool createProfile(String szRootItemName) {
    strRootItemName = szRootItemName;
    setRootItemName(szRootItemName);
    return true;
  }

  XmlItem? createDataNode(XmlItem pItem, String nodeName, String nodeText) {
    pItem.setItemValue(nodeName, nodeText, XiType.element);
    return pItem.getItem(nodeName);
  }

  XmlItem? getEntryNode(XmlItem pItem, String lpszList) {
    XmlItem? pSubItem = pItem.getItem(lpszList) ?? pItem.addItem(lpszList);

    return pSubItem;
  }

  String getNodeText(XmlItem? pItem, String nodeName) {
    String nodeText = '';
    pItem ??= root();
    XmlItem? pSubItem = pItem.getItem(nodeName);
    if (pSubItem != null) {
      nodeText = pSubItem.getValue();
    }
    if (nodeText.isEmpty) {
      nodeText = pItem.getItemValue(nodeName);
    }

    return nodeText;
  }
}
