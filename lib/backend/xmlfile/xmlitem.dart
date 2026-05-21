import 'dart:ui';

import 'package:dcm/backend/utils/string_utils.dart';
import 'package:intl/intl.dart';

/// XML类型枚举
enum XiType { element, attrib, cdata }

/// XML排序键类型
enum XiSortKey { string, integer, float }

/// 键值对类
class Key {
  String name = '';
  String value = '';
}

/// XML项目类
class XmlItem {
  String _name = '';
  String _value = '';
  XiType _type = XiType.element;
  XmlItem? _parent;
  XmlItem? _sibling;
  final List<XmlItem> _lstItems = [];

  XmlItem(this._parent, this._name,
      [this._value = '', this._type = XiType.element]);

  XmlItem.fromItem(XmlItem xi, XmlItem? parent) {
    _name = xi._name;
    _value = xi._value;
    _type = xi._type;
    _parent = parent;
    _sibling = null;
    copy(xi, true);
  }

  void copy(XmlItem xi, bool copySiblings) {
    reset();

    // 复制自己的名称和值
    _name = xi.getName();
    _value = xi.getValue();
    _type = xi.getType();

    // 复制兄弟节点
    if (copySiblings) {
      XmlItem? xISibling = xi.getSibling();
      if (xISibling != null) {
        _sibling = XmlItem(xISibling._parent, xISibling._name, xISibling._value,
            xISibling._type);
      }
    }

    // 复制子节点
    var pos = getFirstItemPos();
    while (pos.moveNext()) {
      XmlItem xiChild = getNextItem(pos);
      addItemObj(XmlItem.fromItem(xiChild, this));
    }
  }

  void reset() {
    _lstItems.clear();
    _sibling = null;
    _type = XiType.element;
  }

  XmlItem? newItem(String szItemName, [XiType nType = XiType.attrib]) {
    XmlItem? pItem = getItem(szItemName);
    pItem ??= addItem(szItemName, '', nType);

    return pItem;
  }

  XmlItem? getItem(String szItemName, [String szSubItem = '']) {
    return getItemEx(szItemName, szSubItem);
  }

  bool hasItem(String szItemName, [String szSubItemName = '']) {
    return (getItem(szItemName, szSubItemName) != null);
  }

  XmlItem? getItemEx(String szItemName, String szSubItem) {
    var pos = getFirstItemPos();
    while (pos.moveNext()) {
      XmlItem? pXIChild = getNextItem(pos);
      if (pXIChild.nameMatches(szItemName)) {
        if (szSubItem.isNotEmpty) {
          return pXIChild.getItemEx(szSubItem, '');
        }
        return pXIChild;
      }
    }
    return null;
  }

  XmlItem? findItem(
      String szItemName, dynamic itemValue, bool bSearchChildren) {
    if (itemValue is DateTime) {
      return findItemEx(szItemName,
          DateFormat('dd/MM/yyyy HH:mm:ss').format(itemValue), bSearchChildren);
    } else if (itemValue is bool) {
      return findItemEx(szItemName, itemValue ? '1' : '0', bSearchChildren);
    }
    return findItemEx(szItemName, itemValue.toString(), bSearchChildren);
  }

  String getItemValue(String szItemName, [String szSubItem = '']) {
    XmlItem? pXI = getItem(szItemName, szSubItem);
    if (pXI != null) return pXI.getValue();
    return '';
  }

  BigInt getItemValueI64(String szItemName, [String szSubItemName = '']) {
    try {
      return BigInt.tryParse(getItemValue(szItemName, szSubItemName)) ??
          BigInt.from(0);
    } catch (e) {
      return BigInt.from(0);
    }
  }

  int getItemValueI(String szItemName, [String szSubItemName = '']) {
    try {
      return int.tryParse(getItemValue(szItemName, szSubItemName)) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  double getItemValueF(String szItemName, [String szSubItemName = '']) {
    try {
      return double.tryParse(getItemValue(szItemName, szSubItemName)) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  bool getItemValueB(String szItemName, [String szSubItemName = '']) {
    try {
      return (int.tryParse(getItemValue(szItemName, szSubItemName)) ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  DateTime? getItemValueD(String szItemName, [String szSubItemName = '']) {
    String strValue = getItemValue(szItemName, szSubItemName);
    if (strValue.isEmpty) return null;

    DateTime? dtValue = DateFormat('dd/MM/yyyy HH:mm:ss').tryParse(strValue);
    dtValue ??= DateFormat('dd/MM/yyyy').tryParse(strValue);

    return dtValue;
  }

  Rect? getItemValueRect(String szItemName, [String szSubItemName = '']) {
    String strValue = getItemValue(szItemName, szSubItemName);
    if (strValue.isEmpty) return null;

    List<double> coords =
        strValue.split(',').map((s) => double.tryParse(s) ?? 0.0).toList();
    if (coords.length != 4) return null;

    return Rect.fromLTWH(coords[0], coords[1], coords[2], coords[3]);
  }

  int? getItemValueR(String szItemName, [String szSubItemName = '']) {
    String strValue = getItemValue(szItemName, szSubItemName);
    if (strValue.isEmpty) return null;

    return fromRGBString(strValue);
  }

  List<String>? getItemValueArray(String szItemName,
      [String szSubItemName = '']) {
    XmlItem? xmlItem = getItem(szItemName, szSubItemName);
    if (xmlItem == null) return null;

    List<String> arrValue = [];
    XmlItem? pXISibling = xmlItem.getItem("ArrayItem");
    while (pXISibling != null) {
      arrValue.add(pXISibling.getItemValue("ItemValue"));

      pXISibling = pXISibling.getSibling();
    }

    return arrValue;
  }

  int getItemCount([String szItemName = '']) {
    if (szItemName.isEmpty) {
      return _lstItems.length;
    }
    int nCount = 0;
    XmlItem? pXI = getItem(szItemName);
    while (pXI != null) {
      nCount++;
      pXI = pXI.getSibling();
    }
    return nCount;
  }

  XmlItem? addItem(String szName,
      [dynamic value, XiType nType = XiType.attrib]) {
    if (szName.isEmpty) return null;
    String szValue = '';
    if (value != null) {
      if (value is DateTime) {
        szValue = DateFormat('dd/MM/yyyy HH:mm:ss').format(value);
      } else if (value is bool) {
        szValue = value ? '1' : '0';
      } else if (value is List) {
        XmlItem? pItem = addItem(szName);
        if (pItem != null) {
          for (int arrayIndex = 0; arrayIndex < value.length; arrayIndex++) {
            XmlItem? pSubItem = pItem.addItem('ArrayItem');
            if (pSubItem != null) {
              pSubItem.addItem('ItemValue', value[arrayIndex]);
            }
          }
        }

        return pItem;
      } else {
        szValue = value.toString();
      }
    }

    XmlItem pXI = XmlItem(this, szName, szValue, nType);
    return addItemObj(pXI);
  }

  XmlItem? addItemObj(XmlItem xi) {
    XmlItem? xiParent = xi.getParent();
    if (xiParent != null && xiParent != this) {
      xiParent.removeItem(xi);
    }
    xi._parent = this;

    XmlItem? xpExist = getItem(xi.getName());
    if (xpExist != null) {
      xpExist.addSibling(xi);
    } else {
      _lstItems.add(xi);
    }
    return xi;
  }

  XmlItem? setItemValue(String szName, dynamic value,
      [XiType nType = XiType.attrib]) {
    assert(nType != XiType.cdata);
    String? sValue;
    if (value is DateTime) {
      sValue = DateFormat('dd/MM/yyyy HH:mm:ss').format(value);
    } else if (value is bool) {
      sValue = value ? '1' : '0';
    } else {
      sValue = value.toString();
    }

    XmlItem? pXI = getItem(szName);
    if (pXI == null) return addItem(szName, sValue, nType);
    pXI.setValue(sValue);
    pXI.setType(nType);
    return pXI;
  }

  XmlItem? setItemValueArray(List<String> arrValue, String szItemName,
      [String? szSubItemName, XiType nType = XiType.attrib]) {
    XmlItem? pItem = setItemValue(szItemName, '', XiType.element);
    if (pItem != null) {
      pItem.deleteAllItems();

      String strSubItem = szSubItemName ?? '';
      if (strSubItem.isEmpty) {
        strSubItem = 'ArrayItem';
      }

      for (int i = 0; i < arrValue.length; i++) {
        XmlItem? pXISibling = pItem.addItem(strSubItem);
        if (pXISibling != null) {
          pXISibling.setItemValue('ItemValue', arrValue[i], nType);
        }
      }
    }

    return pItem;
  }

  bool removeItem(XmlItem? pXI) {
    if (pXI == null) return false;

    String szName = pXI.getName();
    XmlItem? pXIMatch = getItem(szName);
    if (pXIMatch == null) return false;

    XmlItem? pXIPrevSibling;
    while (pXIMatch != pXI) {
      pXIPrevSibling = pXIMatch;
      pXIMatch = pXIMatch?.getSibling();
    }

    if (pXIMatch == null) return false;

    XmlItem? pNextSibling = pXI.getSibling();
    if (pXIPrevSibling == null) {
      int pos = _lstItems.indexOf(pXI);
      if (pNextSibling == null) {
        _lstItems.removeAt(pos);
      } else {
        _lstItems[pos] = pNextSibling;
      }
    } else {
      pXIPrevSibling._sibling = pNextSibling;
    }

    pXI._sibling = null;
    pXI._parent = null;

    return true;
  }

  bool deleteItem({XmlItem? pXI, String? szItemName}) {
    if (pXI == null && szItemName == null) return false;

    if (pXI == null && szItemName != null) {
      pXI = getItem(szItemName);
      if (pXI == null) return false;
      pXI.reset();
    }

    if (removeItem(pXI!)) {
      return true;
    }

    return false;
  }

  bool addSibling(XmlItem? pXI) {
    if (pXI == null) return false;
    if (!(_name == pXI.getName() && _parent == pXI.getParent())) return false;

    if (_sibling == null) {
      _sibling = pXI;
    } else {
      _sibling!.addSibling(pXI);
    }
    return true;
  }

  Iterator<XmlItem> getFirstItemPos() {
    return _lstItems.iterator;
  }

  XmlItem getNextItem(Iterator<XmlItem> pos) {
    return pos.current;
  }

  bool nameMatches(String szName) {
    return _name.toLowerCase() == szName.toLowerCase();
  }

  bool nameIs(String szName) {
    return (_name == szName);
  }

  void setName(String szName) {
    _name = szName;
  }

  String getName() {
    return _name;
  }

  String getValue() {
    return _value;
  }

  int getNameLen() {
    return _name.length;
  }

  int getValueLen() {
    return _value.isEmpty ? 0 : _value.length;
  }

  void setValue(dynamic itemValue) {
    if (itemValue is DateTime) {
      _value = DateFormat('dd/MM/yyyy HH:mm:ss').format(itemValue);
    } else if (itemValue is bool) {
      _value = itemValue ? '1' : '0';
    } else if (itemValue is String) {
      _value = validateString(itemValue, ' ');
    } else {
      _value = itemValue.toString();
    }
  }

  XiType getType() {
    return _type;
  }

  bool setType(XiType nType) {
    _type = nType;
    return true;
  }

  XmlItem? getParent() {
    return _parent;
  }

  XmlItem? getSibling() {
    return _sibling;
  }

  bool isCDATA() {
    return _type == XiType.cdata;
  }

  bool isAttribute([int nMaxAttribLen = 8192]) {
    return _type == XiType.attrib &&
        getValue().length <= nMaxAttribLen &&
        _lstItems.isEmpty;
  }

  static String validateString(String sText, String cReplace) {
    if (sText.isEmpty) return sText;
    // 移除XML不喜欢的字符
    String result = '';
    for (int i = 0; i < sText.length; i++) {
      String c = sText[i];
      if (c.codeUnitAt(0) < 0x20 &&
          ![0x09, 0x0A, 0x0D].contains(c.codeUnitAt(0))) {
        result += cReplace;
      } else if (c.codeUnitAt(0) >= 0x20 && c.codeUnitAt(0) < 0x82 ||
          c.codeUnitAt(0) > 0x9F) {
        result += c;
      } else {
        result += cReplace;
      }
    }
    return result;
  }

  int getValueI() {
    try {
      return int.tryParse(_value) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  BigInt getValueI64() {
    try {
      return BigInt.tryParse(_value) ?? BigInt.from(0);
    } catch (e) {
      return BigInt.from(0);
    }
  }

  double getValueF() {
    try {
      return double.tryParse(_value) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  XmlItem? findItemEx(
      String szItemName, String szItemValue, bool bSearchChildren) {
    if (_name.toLowerCase() == szItemName.toLowerCase() &&
        _value == szItemValue) {
      return this;
    }

    XmlItem? pFound;
    if (bSearchChildren) {
      var pos = getFirstItemPos();
      while (pos.moveNext() && pFound == null) {
        XmlItem pXIChild = getNextItem(pos);
        pFound = pXIChild.findItemEx(szItemName, szItemValue, true);
      }
    }

    if (pFound == null) {
      XmlItem? pXISibling = getSibling();
      if (pXISibling != null) {
        pFound = pXISibling.findItemEx(szItemName, szItemValue, true);
      }
    }

    return pFound;
  }

  void sortItems(String szItemName, String szKeyName, bool bAscending) {
    sortItemsWithKey(szItemName, szKeyName, XiSortKey.string, bAscending);
  }

  void sortItemsWithKey(
      String szItemName, String szKeyName, XiSortKey nKey, bool bAscending) {
    if (szItemName.isEmpty || szKeyName.isEmpty) return;

    XmlItem? pXIItem = getItem(szItemName);
    if (pXIItem == null) return;

    if (pXIItem.getItem(szKeyName) == null) return;

    bool bContinue = (pXIItem.getSibling() != null);
    while (bContinue) {
      XmlItem? pXIPrev;
      XmlItem? pXISibling;

      pXIItem = getItem(szItemName);
      int pos = _lstItems.indexOf(pXIItem!);

      bContinue = false;
      pXISibling = pXIItem.getSibling();
      while (pXISibling != null) {
        int nCompare = compareItems(pXIItem!, pXISibling, szKeyName, nKey);
        if (!bAscending) nCompare = -nCompare;

        if (nCompare > 0) {
          if (pXIPrev != null) {
            pXIPrev._sibling = pXISibling;
          } else {
            _lstItems[pos] = pXISibling;
          }

          pXIItem._sibling = pXISibling._sibling;
          pXISibling._sibling = pXIItem;
          pXIPrev = pXISibling;

          bContinue = true;
        } else {
          pXIPrev = pXIItem;
          pXIItem = pXISibling;
        }

        pXISibling = pXIItem.getSibling();
      }
    }

    pXIItem = getItem(szItemName);
    while (pXIItem != null) {
      pXIItem.sortItemsWithKey(szItemName, szKeyName, nKey, bAscending);
      pXIItem = pXIItem.getSibling();
    }
  }

  int compareItems(
      XmlItem pXIItem1, XmlItem pXIItem2, String szKeyName, XiSortKey nKey) {
    String szValue1 = pXIItem1.getItemValue(szKeyName);
    String szValue2 = pXIItem2.getItemValue(szKeyName);

    double dDiff = 0;
    switch (nKey) {
      case XiSortKey.string:
        dDiff =
            szValue1.toLowerCase().compareTo(szValue2.toLowerCase()).toDouble();
        break;
      case XiSortKey.integer:
        dDiff = ((int.tryParse(szValue1) ?? 0) - (int.tryParse(szValue2) ?? 0))
            .toDouble();
        break;
      case XiSortKey.float:
        dDiff = (double.tryParse(szValue1) ?? 0.0) -
            (double.tryParse(szValue2) ?? 0.0);
        break;
    }

    return dDiff < 0 ? -1 : (dDiff > 0 ? 1 : 0);
  }

  void deleteAllItems() {
    reset();
  }
}
