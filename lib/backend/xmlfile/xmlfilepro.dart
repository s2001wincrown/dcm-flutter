// XMLFilePro.cpp: implementation of the CXMLFilePro class.
//
// Date  : 03/03/2004

// Construction/Destruction
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfileex.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:intl/intl.dart';

//////////////////////////////////////////////////////////////////////
class XmlFilePro extends XmlFileEx {
  static const String xfDCMLASTMODIFIED = "LASTMODIFIED";
  static const String xfDCMPROJECTNAME = "DCMPlayer";
  static const String xfDCMSIGNATURE = "Signature";
  static const String xfDCMLASTSORTBY = "LASTSORTBY";
  static const String xfDCMLASTSORTDIR = "LASTSORTDIR";
  static const String xfDCMNEXTUNIQUEID = "NEXTUNIQUEID";
  static const String xfDCMARCHIVE = "ARCHIVE";
  static const String xfDCMFILENAME = "FILENAME";
  static const String xfDCMFILEFORMAT = "FILEFORMAT";
  static const String xfDCMFILEVERSION = "FILEVERSION";
  static const String xfDCMCHECKEDOUTTO = "CHECKEDOUTTO";
  static const String xfDCMCOMPANY = "COMPANY";
  static const String xfDCMREPORTTITLE = "REPORTTITLE";
  static const String xfDCMREPORTDATE = "REPORTDATE";
  static const String xfDCMREPORTDATEOLE = "REPORTDATEOLD";
  static const String xfDCMARRAYITEM = "ArrayItem";
  static const String xfDCMITEMVALUE = "ItemValue";

  XmlFilePro(super.szRootItemName, [super.password]);

  ///////////////////////////////////////////////////////////////////////

  bool newNode(String szTitle, XmlItem? pParent) {
    XmlItem? pXIParent = pParent ?? root();
    if (pXIParent == null) return false;

    pXIParent.addItemObj(newItem(szTitle));

    return true;
  }

  XmlItem? addDataNode(String szTitle, XmlItem? pParent) {
    XmlItem? pXIParent = pParent ?? root();
    if (pXIParent == null) return null;

    XmlItem pXINew = newItem(szTitle);
    pXIParent.addItemObj(pXINew);

    return pXINew;
  }

  ////////////////////////////////////////////////////////////////////

  bool setDataNode(XmlItem? pXINode, String nodeName, dynamic nodeValue,
      [bool bIncTime = true]) {
    XmlItem? pXITask = pXINode ?? root();
    String? sValue;
    if (nodeValue is DateTime) {
      sValue = DateFormat(bIncTime ? 'dd/MM/yyyy HH:mm:ss' : 'dd/MM/yyyy')
          .format(nodeValue);
    } else if (nodeValue is bool) {
      sValue = nodeValue ? '1' : '0';
    } else {
      sValue = nodeValue.toString();
    }

    XmlItem? pXItem = pXITask?.getItem(nodeName);
    if (pXItem != null) {
      pXItem.setValue(sValue);
      return true;
    }

    // else
    pXItem = newItem(nodeName);
    pXITask?.addItemObj(pXItem);
    pXItem.setValue(sValue);

    return true;
  }

  bool setDataNodeR(XmlItem? pXINode, String colorNode, int crVal) {
    XmlItem? pXITask = pXINode ?? root();
    XmlItem? pXItem = pXITask?.getItem(colorNode);

    String attrText = toRGBString(crVal);
    if (pXItem != null) {
      pXItem.setValue(attrText);
      return true;
    }

    // else
    pXItem = newItem(colorNode);
    pXITask?.addItemObj(pXItem);
    pXItem.setValue(attrText);

    return true;
  }

  String getProjectName() {
    return getItemValue(xfDCMPROJECTNAME);
  }

  String getSignature() {
    return getItemValue(xfDCMSIGNATURE);
  }

  int getFileFormat() {
    return getItemValueI(xfDCMFILEFORMAT);
  }

  int getFileVersion() {
    return getItemValueI(xfDCMFILEVERSION);
  }

  BigInt getLastModified() {
    return getItemValueI64(xfDCMLASTMODIFIED);
  }

  bool setProjectName(String szName) {
    XmlItem? pXItem = getItem(xfDCMPROJECTNAME);
    if (pXItem != null) {
      pXItem.setValue(szName);
      return true;
    }

    // else
    return (null != addItem(xfDCMPROJECTNAME, szName));
  }

  bool setSignature(String szSignature) {
    XmlItem? pXItem = getItem(xfDCMSIGNATURE);
    if (pXItem != null) {
      pXItem.setValue(szSignature);
      return true;
    }

    // else
    return (null != addItem(xfDCMSIGNATURE, szSignature));
  }

  bool setFileVersion(int nVersion) {
    XmlItem? pXItem = getItem(xfDCMFILEVERSION);
    if (pXItem != null) {
      pXItem.setValue(nVersion);
      return true;
    }

    // else
    return (null != addItem(xfDCMFILEVERSION, nVersion));
  }

  bool setFileFormat(int lFormat) {
    XmlItem? pXItem = getItem(xfDCMFILEFORMAT);
    if (pXItem != null) {
      pXItem.setValue(lFormat);
      return true;
    }

    // else
    return (null != addItem(xfDCMFILEFORMAT, lFormat));
  }

  bool setLastModified(String sLastMod) {
    XmlItem? pXItem = getItem(xfDCMLASTMODIFIED);
    if (pXItem != null) {
      pXItem.setValue(sLastMod);
      return true;
    }

    // else
    return (null != addItem(xfDCMLASTMODIFIED, sLastMod));
  }
}
