import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/utils/extensions.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as p;

////////////////////////////////////////////////////////////////////////////
//Event List Manager
class EventListImpl {
  final List<FileInfoData> _lstDCMFile = [];
  final List<FileInfoData> _lstDCMFile1 = [];
  final List<FileInfoData> _lstContentList = [];

  int _nFtpImm = 0;
  bool _bReplaceExistedFile = false;

  String _strDiskSerial = '';

  EventListImpl();

  /********************************************************************/
  /*																	*/
  /* Function name : Serialize										*/
  /* Description   : Call this function to store/load the Player data	*/
  /*																	*/
  /// *****************************************************************
  bool serialize(String strFilename, bool bStoring) {
    if (bStoring) {
      XmlFilePro playerReg = XmlFilePro('PublishFileInformation');

      playerReg.setDataNode(null, 'm_nFtpImm', _nFtpImm);
      playerReg.setDataNode(
          null, 'm_bReplaceExistedFile', _bReplaceExistedFile);
      playerReg.setDataNode(null, 'm_strDiskSerial', _strDiskSerial);

      // Save the File information
      for (var iter in _lstDCMFile) {
        XmlItem? xi = playerReg.addDataNode('FileItem', null);
        if (xi != null) {
          iter.writeToXML(xi, true);
        }
      }

      playerReg.setSignature(cFLSignature);

      // encrypt prior to setting checkout status and file info (so these are visible without decryption)
      // this simply fails if password is empty
      playerReg.encrypt(Encodes.cDCMFILECRYPTKEY);

      return playerReg.save(strFilename);
    } else {
      XmlFilePro file =
          XmlFilePro('PublishFileInformation', Encodes.cDCMFILECRYPTKEY);
      if (!file.open(strFilename, XfOpen.read, false)) {
        return false;
      }

      if (file.loadEx()) {
        // file header info
        String sXmlHeader = file.getSignature();
        if (sXmlHeader == cFLSignature) {
          _nFtpImm = file.getItemValueI('m_nFtpImm');
          _bReplaceExistedFile = file.getItemValueB('m_bReplaceExistedFile');
          _strDiskSerial = file.getItemValue('m_strDiskSerial');

          // get publish file information list
          XmlItem? pXISibling = file.getItem('FileItem');
          while (pXISibling != null) {
            FileInfoData pData = FileInfoData();

            // get File Inforamtion data
            pData.getFromXML(pXISibling);

            // add File Information data to list
            addFileList(pData);

            pXISibling = pXISibling.getSibling();
          }

          return true;
        }
      }
      return false;
    }
  }

  /********************************************************************/
  /*																	*/
  /* Function name : SerializeSkin									*/
  /* Description   : Call this function to store/load the Player data	*/
  /*																	*/
  /// *****************************************************************
  FileInfoData? _serializeSkin(String strFilename) {
    XmlFilePro file =
        XmlFilePro('PublishFileInformation', Encodes.cDCMFILECRYPTKEY);
    if (!file.open(strFilename, XfOpen.read, false)) {
      return null;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == cFLSignature) {
        _bReplaceExistedFile = file.getItemValueB('m_bReplaceExistedFile');
        _strDiskSerial = file.getItemValue('m_strDiskSerial');

        FileInfoData fileData = FileInfoData();
        // get publish file information list
        XmlItem? pXISibling = file.getItem('FileItem');
        while (pXISibling != null) {
          // get File Inforamtion data
          fileData.getFromXML(pXISibling);

          pXISibling = pXISibling.getSibling();
        }
        return fileData;
      }
    }
    return null;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : SerializeSkin									*/
  /* Description   : Call this function to store/load the Player data	*/
  /*																	*/
  /// *****************************************************************
  bool serializeDDE(String strFilename) {
    XmlFilePro file =
        XmlFilePro('PublishFileInformation', Encodes.cDCMFILECRYPTKEY);
    if (!file.open(strFilename, XfOpen.read, false)) {
      return false;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == cFLSignature) {
        _nFtpImm = file.getItemValueI('m_nFtpImm');
        _bReplaceExistedFile = file.getItemValueB('m_bReplaceExistedFile');
        _strDiskSerial = file.getItemValue('m_strDiskSerial');

        // get publish file information list
        XmlItem? pXISibling = file.getItem('FileItem');
        while (pXISibling != null) {
          FileInfoData pData = FileInfoData();

          // get File Inforamtion data
          pData.getFromXML(pXISibling);

          // add File Information data to list
          addContentList(pData);

          pXISibling = pXISibling.getSibling();
        }
        return true;
      }
    }
    return false;
  }

  List<String> getSkinSetting(String strDCMFile, List<String> dcmArray) {
    String strSkinsDirectory =
        p.join(AppGlobal.ftpSettingPath, 'Skins', '$strDCMFile.dat');
    FileInfoData? fileData = _serializeSkin(strSkinsDirectory);
    if (fileData != null && fileData.nContentType == 0) {
      strSkinsDirectory = '${AppGlobal.ftpSettingPath}/Skins/skin.dat';
      IniFile iniFile = IniFile(strSkinsDirectory);
      String strDCMFile = '';
      strDCMFile = iniFile.readString(fileData.strFilePath!, 'Second DCMFile');
      if (strDCMFile.isNotEmpty) {
        for (int i = 0; i < dcmArray.length; i++) {
          if (dcmArray[i] == strDCMFile) {
            break;
          }
        }
        dcmArray.add(strDCMFile);
      }

      String strFileCount = '0';
      strFileCount =
          iniFile.readString(fileData.strFilePath!, 'DCMFile Count', '0');
      int nFileCount = int.parse(strFileCount);
      for (int nCount = 0; nCount < nFileCount; nCount++) {
        String strFileKey = 'DCMFile$nCount';
        strDCMFile = iniFile.readString(fileData.strFilePath!, strFileKey, '');
        if (strDCMFile.isNotEmpty) {
          for (int i = 0; i < dcmArray.length; i++) {
            if (dcmArray[i] == strDCMFile) {
              break;
            }
          }
          dcmArray.add(strDCMFile);
        }
      }
    }

    return dcmArray;
  }

  bool addFileList(FileInfoData pData) {
    if (pData.nContentType == cDCMDAYTYPE ||
        pData.nContentType == cDCMAHPLAYLISTTYPE) {
      _lstDCMFile1.add(pData);
      return false;
    }
    for (var iter in _lstDCMFile) {
      FileInfoData pFileInfo = iter;
      if (pData.strFilePath == pFileInfo.strFilePath &&
          pData.nContentType == pFileInfo.nContentType) {
        _lstDCMFile1.add(pData);
        return false;
      }
    }

    // add File Information data to list
    _lstDCMFile.add(pData);
    return true;
  }

  bool addContentList(FileInfoData pData) {
    for (var iter in _lstContentList) {
      FileInfoData pFileInfo = iter;
      if (pData.strFilePath!.equalsIgnoreCase(pFileInfo.strFilePath) &&
          pData.nContentType == pFileInfo.nContentType) {
        return false;
      }
    }

    // add File Information data to list
    _lstContentList.add(pData);
    return true;
  }
}
