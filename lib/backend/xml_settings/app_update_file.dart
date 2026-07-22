import 'dart:math';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';

/// 对应 C++ 中的 CAppUpdateFile
class AppUpdateFile extends XmlFile {
  static const String nextUniqueIdTag = 'NextUniqueID';
  static const String cAPPUPDATEROOT = 'DCMUpdateList';
  static const String cAPPUPDATEGROUP = 'UpdateGroup';
  static const String cAPPUPDATEGROUPNAME = 'strBatch';
  static const String cAPPUPDATEGROUPPATH = 'Path';
  static const String cAPPUPDATEDATE = 'GroupDate';
  static const String cAPPUPDATESENDDATE = 'dtPublish';
  static const String cAPPUPDATEVALIDITY = 'dtValidity';
  static const String cAPPUPDATEDESC = 'GroupDesc';
  static const String cAPPUPDATESTATUS = 'GroupStatus';
  static const String cAPPUPDATEITEM = 'UpdateItem';
  static const String cAPPUPDATESOURCE = 'strSource';
  static const String cAPPUPDATEDEST = 'strDest';
  static const String cAPPUPDATEACTION = 'nAction';
  static const String cAPPUPDATEMD5 = 'strMD5';
  static const String cAPPUPDATESHA1 = 'strSHA1';
  static const String cAPPUPDATEFILESIZE = 'nFileSize';
  static const String cAPPUPDATELASTMOD = 'dtLastModified';
  static const String cAPPUPDATEVERSION = 'strVersion';
  static const String cAPPUPDATEISCHECKSUM = 'bChecksum';
  static const String cAPPUPDATEISCHECKVER = 'bCheckVersion';
  static const String cAPPUPDATEISREGSERVER = 'bRegServer';
  static const String cAPPUPDATECREATION = 'CreationDate';

  int _dwNextUniqueID = 1;

  AppUpdateFile() : super(cAPPUPDATEROOT) {
    _dwNextUniqueID = 1;
  }

  /// 从 XML 字符串加载
  bool saveSetting(String szFileName) {
    setNextUniqueID(_dwNextUniqueID);

    return save(szFileName);
  }

  bool loadSetting(String szFileName, [XfOpen nMode = XfOpen.read]) {
    if (!open(szFileName, nMode)) {
      return false;
    }

    return loadEx();
  }

  bool loadFile(String szFilePath, bool bDecrypt) {
    bool bRes = load(szFilePath, cAPPUPDATEROOT, bDecrypt);
    if (bRes) {
      _dwNextUniqueID = getItemValueI(cDCMNEXTUNIQUEID);
      if (_dwNextUniqueID <= 0) {
        _dwNextUniqueID = 1; // always > 0
      }
    }

    return bRes;
  }

  @override
  bool loadEx([String? szRootItemName]) {
    bool bResult = super.loadEx(cAPPUPDATEROOT);
    if (bResult) {
      // fix corrupted loglist where the root item has an ID
      XmlItem? pXI = getItem(cDCMID);
      while (pXI != null) {
        deleteItem(pXI: pXI);
        pXI = getItem(cDCMID);
      }

      _dwNextUniqueID = getItemValueI(cDCMNEXTUNIQUEID);
      if (_dwNextUniqueID <= 0) {
        _dwNextUniqueID = 1; // always > 0
      }
    }

    return bResult;
  }

  bool loadXML(String szXML) {
    bool bResult = super.loadXml(szXML, cAPPUPDATEROOT);
    if (bResult) {
      // fix corrupted loglist where the root item has an ID
      XmlItem? pXI = getItem(cDCMID);
      while (pXI != null) {
        deleteItem(pXI: pXI);
        pXI = getItem(cDCMID);
      }

      _dwNextUniqueID = getItemValueI(cDCMNEXTUNIQUEID);
      if (_dwNextUniqueID <= 0) {
        _dwNextUniqueID = 1; // always > 0
      }
    }

    return bResult;
  }

  bool setNextUniqueID(int dwNextID) {
    assert(dwNextID >= _dwNextUniqueID);

    bool bResult = false;
    XmlItem? pXItem = getItem(cDCMNEXTUNIQUEID);
    if (pXItem != null) {
      pXItem.setValue(dwNextID);
      bResult = true;
    } else {
      bResult = (null != addItem(cDCMNEXTUNIQUEID, dwNextID));
    }

    if (bResult) {
      _dwNextUniqueID = dwNextID;
    }

    return bResult;
  }

  int getNextUniqueID() {
    return _dwNextUniqueID;
  }

  ////////////////////////////////////////////////
  // utility functions

  int getUpdateItemULong(XmlItem hAppUpdateItem, String szULongItem) {
    return hAppUpdateItem.getItemValueI(szULongItem);
  }

  int getUpdateItemInt(XmlItem hAppUpdateItem, String szIntItem) {
    return hAppUpdateItem.getItemValueI(szIntItem);
  }

  String getUpdateItemCChar(XmlItem hAppUpdateItem, String szCCharItem) {
    return hAppUpdateItem.getItemValue(szCCharItem);
  }

  double getUpdateItemDouble(XmlItem hAppUpdateItem, String szDoubleItem) {
    return hAppUpdateItem.getItemValueF(szDoubleItem);
  }

  DateTime? getUpdateItemDate(
      XmlItem hAppUpdateItem, String szDateItem, bool bIncTime) {
    return hAppUpdateItem.getItemValueD(szDateItem);
  }

  bool setUpdateItemULong(
      XmlItem hAppUpdateItem, String szULongItem, int lVal) {
    return (hAppUpdateItem.setItemValue(szULongItem, lVal) != null);
  }

  bool setUpdateItemInt(XmlItem hAppUpdateItem, String szIntItem, int iVal) {
    return (hAppUpdateItem.setItemValue(szIntItem, iVal) != null);
  }

  bool setUpdateItemCChar(
      XmlItem hAppUpdateItem, String szCCharItem, String szVal,
      [bool bCData = false]) {
    return (hAppUpdateItem.setItemValue(
            szCCharItem, szVal, bCData ? XiType.cdata : XiType.attrib) !=
        null);
  }

  bool setUpdateItemDouble(
      XmlItem hAppUpdateItem, String szDoubleItem, double dVal) {
    return (hAppUpdateItem.setItemValue(szDoubleItem, dVal) != null);
  }

  bool setUpdateItemDate(
      XmlItem hAppUpdateItem, String szDateItem, DateTime tVal) {
    return (hAppUpdateItem.setItemValue(szDateItem, tVal) != null);
  }

  String? getUpdateItemArrayItem(XmlItem hAppUpdateItem, String szNumItemTag,
      String szItemTag, int nIndex) {
    if (nIndex == 0) {
      return getUpdateItemCChar(hAppUpdateItem, szItemTag); // first item
    }

    // else
    int nCount = hAppUpdateItem.getItemValueI(szNumItemTag);

    if (nCount == 0 || nIndex < 1 || nIndex > nCount - 1) return null;

    String sItem = '$szItemTag$nIndex';

    return getUpdateItemCChar(hAppUpdateItem, sItem);
  }

  bool addUpdateItemArrayItem(XmlItem hAppUpdateItem, String szNumItemTag,
      String szItemTag, String szItem) {
    int nCount = hAppUpdateItem.getItemValueI(szNumItemTag);

    // see if it already exists
    if (nCount > 0 || hAppUpdateItem.getItem(szItemTag) != null) {
      String sValue = hAppUpdateItem.getItemValue(szItemTag);

      if (sValue.equalsIgnoreCase(szItem)) {
        return false; // already exists
      }

      // the rest have numbers after their names
      for (int nItem = 1; nItem < nCount; nItem++) {
        String sItem = '$szItemTag$nItem';

        String sValue = hAppUpdateItem.getItemValue(sItem);

        if (sValue.equalsIgnoreCase(szItem)) {
          return false; // already exists
        }
      }
    }

    // does the task have an existing item?
    if (hAppUpdateItem.getItem(szItemTag) == null) {
      hAppUpdateItem.addItem(szNumItemTag, 1); // num
      hAppUpdateItem.addItem(szItemTag, szItem); // first item
    } else {
      // append
      // increment item count
      hAppUpdateItem.setItemValue(szNumItemTag, nCount + 1);
      String sItem = '$szItemTag$nCount';
      hAppUpdateItem.addItem(sItem, szItem);
    }

    return true;
  }

  int getUpdateItemArray(XmlItem hAppUpdateItem, String szNumItemTag,
      String szItemTag, List<String> aItems) {
    aItems.clear();

    // first item
    String sItem = getUpdateItemCChar(hAppUpdateItem, szItemTag);

    if (sItem.isNotEmpty) {
      aItems.add(sItem);

      // rest
      int nCount = hAppUpdateItem.getItemValueI(szNumItemTag);
      for (int nItem = 1; nItem < nCount; nItem++) {
        var itemValue = getUpdateItemArrayItem(
            hAppUpdateItem, szNumItemTag, szItemTag, nItem);
        if (isNotBlank(itemValue)) {
          aItems.add(itemValue!);
        }
      }
    }

    return aItems.length;
  }

  bool setUpdateItemArray(XmlItem hAppUpdateItem, String szNumItemTag,
      String szItemTag, List<String> aItems) {
    // delete any existing items
    hAppUpdateItem.deleteItem(szItemName: szItemTag);
    hAppUpdateItem.deleteItem(szItemName: szNumItemTag);

    // then add these
    int nCount = aItems.length;
    for (int nItem = 0; nItem < nCount; nItem++) {
      addUpdateItemArrayItem(
          hAppUpdateItem, szNumItemTag, szItemTag, aItems[nItem]);
    }

    return true;
  }

  int getArray(String szItemTag, List<String> aItems) {
    aItems.clear();

    XmlItem? pXI = getItem(szItemTag);
    if (pXI != null) {
      int nCount = pXI.getItemCount();
      for (int nItem = 0; nItem < nCount; nItem++) {
        String sItem = '$szItemTag$nItem';

        aItems.add(pXI.getItemValue(sItem));
      }
    }

    return aItems.length;
  }

  bool setArray(String szItemTag, List<String> aItems) {
    // and start again
    if (aItems.isNotEmpty) {
      XmlItem? pXI = addItem(szItemTag);

      if (pXI != null) {
        int nCount = aItems.length;

        for (int nItem = 0; nItem < nCount; nItem++) {
          String sItem = '$szItemTag$nItem';

          pXI.addItem(sItem, aItems[nItem]);
        }

        return true;
      }
    }

    return false;
  }

  ///////////////////////////////////////////////////////////////////////

  XmlItem newUpdateItem(String szSource, XmlItem? hParent, int dwID) {
    XmlItem? pXIParent = hParent ?? root();

    XmlItem pXINew = newItem(cAPPUPDATEITEM);

    pXIParent.addItemObj(pXINew);

    // set ID and name
    setUpdateItemSource(pXINew, szSource);

    if (dwID <= 0) {
      dwID = _dwNextUniqueID++;
    } else {
      _dwNextUniqueID = max(_dwNextUniqueID, dwID + 1);
    }

    setUpdateItemID(pXINew, dwID);

    return pXINew;
  }

  XmlItem newUpdateGroup(String szSource, [XmlItem? hParent, int dwID = 0]) {
    XmlItem pXIParent = hParent ?? root();

    XmlItem? pXINew = newItem(cAPPUPDATEGROUP);
    pXIParent.addItemObj(pXINew);

    // set ID and name
    setUpdateGroupName(pXINew, szSource);

    if (dwID <= 0) {
      dwID = _dwNextUniqueID++;
    } else {
      _dwNextUniqueID = max(_dwNextUniqueID, dwID + 1);
    }

    setUpdateItemID(pXINew, dwID);

    return pXINew;
  }

  XmlItem? getUpdateGroupItem(String szGroup, [bool bNew = false]) {
    if (szGroup.isEmpty) {
      return getFirstUpdateItem();
    }

    XmlItem? pXI = findItem(cAPPUPDATEGROUPNAME, szGroup);
    if (pXI == null && bNew) {
      return newUpdateGroup(szGroup);
    }

    return pXI != null ? (pXI.getParent()) : null;
  }

  XmlItem? getUpdateItem(String szUpdate, XmlItem hGroup /* = null*/) {
    XmlItem? hItem = getFirstUpdateItem(hGroup);
    if (hItem != null) {
      XmlItem? pXI = hItem.findItem(cAPPUPDATESOURCE, szUpdate);

      return pXI != null ? (pXI.getParent()) : null;
    }

    return null;
  }

  bool deleteUpdateItem(XmlItem hAppUpdateItem) {
    XmlItem? pXIParent = hAppUpdateItem.getParent();
    assert(pXIParent != null);
    if (pXIParent != null) {
      return pXIParent.deleteItem(pXI: hAppUpdateItem);
    }

    return false;
  }

  bool deleteChildItem(XmlItem hGroupItem) {
    var pos = hGroupItem.getFirstItemPos();
    while (pos.moveNext()) {
      XmlItem? pXIChild = hGroupItem.getNextItem(pos);
      if (pXIChild.nameMatches(cAPPUPDATEITEM)) {
        hGroupItem.deleteItem(pXI: pXIChild);
      }
    }

    return true;
  }

  bool deleteUpdateItemAttributes(XmlItem hAppUpdateItem) {
    var pos = hAppUpdateItem.getFirstItemPos();
    while (pos.moveNext()) {
      XmlItem? pXIChild = hAppUpdateItem.getNextItem(pos);
      if (!pXIChild.nameMatches(cAPPUPDATEITEM)) {
        hAppUpdateItem.deleteItem(pXI: pXIChild);
      }
    }

    return true;
  }

  XmlItem? getFirstUpdateItem([XmlItem? hParent]) {
    XmlItem pXIParent = hParent ?? root();

    XmlItem? hItem;
    if (hParent == null) {
      hItem = pXIParent.getItem(cAPPUPDATEGROUP);
    } else {
      hItem = pXIParent.getItem(cAPPUPDATEITEM);
    }

    return hItem;
  }

  XmlItem? getNextUpdateItem(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getSibling();
  }

  // get methods
  String getUpdateItemSource(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATESOURCE);
  }

  String getUpdateItemMD5(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATEMD5);
  }

  String getUpdateGroupName(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATEGROUPNAME);
  }

  String getUpdateGroupPath(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATEGROUPPATH);
  }

  int getUpdateGroupStatus(XmlItem hAppUpdateItem) {
    return getUpdateItemULong(hAppUpdateItem, cAPPUPDATESTATUS);
  }

  String getUpdateItemVersion(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATEVERSION);
  }

  String getUpdateGroupDesc(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATEDESC);
  }

  String getUpdateItemSHA1(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATESHA1);
  }

  String getUpdateItemDest(XmlItem hAppUpdateItem) {
    return getUpdateItemCChar(hAppUpdateItem, cAPPUPDATEDEST);
  }

  int getUpdateItemID(XmlItem hAppUpdateItem) {
    return getUpdateItemULong(hAppUpdateItem, cDCMID);
  }

  BigInt getUpdateItemFileSize(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueI64(cAPPUPDATEFILESIZE);
  }

  int getUpdateItemAction(XmlItem hAppUpdateItem) {
    return getUpdateItemULong(hAppUpdateItem, cAPPUPDATEACTION);
  }

  bool isChecksum(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueB(cAPPUPDATEISCHECKSUM);
  }

  bool isCheckVer(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueB(cAPPUPDATEISCHECKVER);
  }

  bool isRegServer(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueB(cAPPUPDATEISREGSERVER);
  }

  XmlItem? getUpdateItemParent(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getParent();
  }

  // set methods
  bool setUpdateItemSource(XmlItem hAppUpdateItem, String szSource) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATESOURCE, szSource);
  }

  bool setUpdateItemMD5(XmlItem hAppUpdateItem, String szMD5) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATEMD5, szMD5);
  }

  bool setUpdateGroupName(XmlItem hAppUpdateItem, String szGroup) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATEGROUPNAME, szGroup);
  }

  bool setUpdateGroupPath(XmlItem hAppUpdateItem, String szPath) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATEGROUPPATH, szPath);
  }

  bool setUpdateGroupStatus(XmlItem hAppUpdateItem, int nStatus) {
    return setUpdateItemULong(hAppUpdateItem, cAPPUPDATESTATUS, nStatus);
  }

  bool setUpdateItemVersion(XmlItem hAppUpdateItem, String szVersion) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATEVERSION, szVersion);
  }

  bool setUpdateGroupDesc(XmlItem hAppUpdateItem, String szDesc) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATEDESC, szDesc);
  }

  bool setUpdateItemSHA1(XmlItem hAppUpdateItem, String szSHA1) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATESHA1, szSHA1);
  }

  bool setUpdateItemDest(XmlItem hAppUpdateItem, String szDest) {
    return setUpdateItemCChar(hAppUpdateItem, cAPPUPDATEDEST, szDest);
  }

  bool setUpdateItemFileSize(XmlItem hAppUpdateItem, int nFileSize) {
    return setUpdateItemULong(hAppUpdateItem, cAPPUPDATEFILESIZE, nFileSize);
  }

  bool setUpdateItemAction(XmlItem hAppUpdateItem, int nAction) {
    return setUpdateItemULong(hAppUpdateItem, cAPPUPDATEACTION, nAction);
  }

  bool setUpdateItemID(XmlItem hAppUpdateItem, int nID,
      [bool bVisible = true]) {
    if (setUpdateItemULong(hAppUpdateItem, cDCMID, nID)) {
      // update _dwNextUniqueID
      _dwNextUniqueID = max(_dwNextUniqueID, nID + 1);

      return true;
    }

    return false;
  }

  bool setUpdateItemChecksum(XmlItem hAppUpdateItem, bool bChecksum) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATEISCHECKSUM, bChecksum) !=
        null);
  }

  bool setUpdateItemRegServer(XmlItem hAppUpdateItem, bool bRegServer) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATEISREGSERVER, bRegServer) !=
        null);
  }

  bool setUpdateItemCheckVer(XmlItem hAppUpdateItem, bool bCheckVer) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATEISCHECKVER, bCheckVer) !=
        null);
  }

  bool setUpdateLastModified(XmlItem hAppUpdateItem, DateTime tLastMod) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATELASTMOD, tLastMod) != null);
  }

  bool setUpdateCreationDate(XmlItem hAppUpdateItem, DateTime date) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATECREATION, date) != null);
  }

  bool setUpdateGroupDate(XmlItem hAppUpdateItem, DateTime date) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATEDATE, date) != null);
  }

  bool setUpdateGroupSendDate(XmlItem hAppUpdateItem, DateTime date) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATESENDDATE, date) != null);
  }

  bool setUpdateGroupValidity(XmlItem hAppUpdateItem, DateTime date) {
    return (hAppUpdateItem.setItemValue(cAPPUPDATEVALIDITY, date) != null);
  }

  DateTime? getUpdateLastModified(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueD(cAPPUPDATELASTMOD);
  }

  DateTime? getUpdateCreationDate(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueD(cAPPUPDATECREATION);
  }

  DateTime? getUpdateGroupDate(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueD(cAPPUPDATEDATE);
  }

  DateTime? getUpdateGroupValidity(XmlItem hAppUpdateItem) {
    return hAppUpdateItem.getItemValueD(cAPPUPDATEVALIDITY);
  }
}
