import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/net/player_path_service.dart';
import 'package:dcm/backend/utils/encoder_utils.dart';
import 'package:dcm/backend/xmlfile/xmlfile.dart';
import 'package:dcm/backend/xmlfile/xmlfilepro.dart';
import 'package:dcm/backend/xmlfile/xmlitem.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

////////////////////////////////////////////////////////////////////////////
//Event List Manager
class EventListImpl {
  final List<FileInfoData>      _lstDCMFile = [];
	final List<FileInfoData>      _lstDCMFile1 = [];
	final List<FileInfoData>      _lstContentList = [];

	int  _nFtpImm;
	bool _bReplaceExistedFile;

	String _strDiskSerial;
	String _strChannel;
	String _strChannelPath;
	String _strPublishPath;

	int _nFtpPeriod;

  EventListImpl() {
    _strChannel.Empty();
    _strDiskSerial.Empty();
    _strPublishPath.Empty();
    _nFtpPeriod = 7;
    _bReplaceExistedFile = false;
  }

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
      playerReg.setDataNode(null, 'm_bReplaceExistedFile', _bReplaceExistedFile);
      playerReg.setDataNode(null, 'm_strDiskSerial', _strDiskSerial);

      // Save the File information
      for(var iter in _lstDCMFile) {
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
    } else  {
      XmlFilePro file = XmlFilePro('PublishFileInformation', Encodes.cDCMFILECRYPTKEY);
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
          while(pXISibling != null) {
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
  bool serializeSkin(String strFilename, FileInfoData fileData) {
    XmlFilePro file = XmlFilePro('PublishFileInformation', szPassword);
    if (!file.open(strFilename, XfOpen.read, false)) {
      return false;
    }

    if (file.loadEx()) {
      // file header info
      String sXmlHeader = file.getSignature();
      if (sXmlHeader == cFLSignature) {
        _bReplaceExistedFile = file.getItemValueI('m_bReplaceExistedFile');
        _strDiskSerial = file.getItemValue('m_strDiskSerial');

        // get publish file information list
        XmlItem? pXISibling = file.getItem('FileItem');
        while(pXISibling != null) {
          // get File Inforamtion data
          fileData.getFromXML(pXISibling);

          pXISibling = pXISibling.getSibling();
        }
        return true;
      }
    }
    return false;
  }

  /********************************************************************/
  /*																	*/
  /* Function name : SerializeSkin									*/
  /* Description   : Call this function to store/load the Player data	*/
  /*																	*/
  /// *****************************************************************
  bool serializeDDE(String strFilename) {
    XmlFilePro file = XmlFilePro('PublishFileInformation', Encodes.cDCMFILECRYPTKEY);
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
        while(pXISibling != null) {
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

  void getSkinSetting(String &strDCMFile, wxArrayString &DCMArray) {
    String strSkinsDirectory = Settings.m_strFtpSettingPath;
    ADDBACKSLASH(strSkinsDirectory);
    strSkinsDirectory += 'Skins';
    ADDBACKSLASH(strSkinsDirectory);
    strSkinsDirectory += strDCMFile;
    strSkinsDirectory += '.dat';
    FileInfoData fileData;
    SerializeSkin(strSkinsDirectory, fileData);
    if (fileData.m_nContentType == 0)
    {
      strSkinsDirectory = Settings.m_strFtpSettingPath + '/Skins/skin.dat';
      CIniFile iniFile(strSkinsDirectory);
      String strDCMFile = '';
      iniFile.ReadString(fileData.m_strFilePath, 'Second DCMFile', strDCMFile, '');
      if (!strDCMFile.IsEmpty())
      {
        for(int i = 0; i < (int)DCMArray.length; i++)
        {
          if (DCMArray[i] == strDCMFile)
          {
            break;
          }
        }
        DCMArray.Add(strDCMFile);
      }

      String strFileCount = '0';
      iniFile.ReadString(fileData.m_strFilePath, 'DCMFile Count', strFileCount, '0');
      int nFileCount = DCMMisc::ConvLong(strFileCount);
      for(int nCount=0; nCount<nFileCount; nCount++)
      {
        String strFileKey = String::Format('DCMFile%d', nCount);
        iniFile.ReadString(fileData.m_strFilePath, strFileKey, strDCMFile, '');
        if (!strDCMFile.IsEmpty())
        {
          for(int i = 0; i < (int)DCMArray.length; i++)
          {
            if (DCMArray[i] == strDCMFile)
            {
              break;
            }
          }
          DCMArray.Add(strDCMFile);
        }
      }
    }
  }

  bool addFileList(FileInfoData pData) {
    if (pData.nContentType == DCM_DAY_TYPE || pData.nContentType == DCM_AHPLAYLIST_TYPE)
    {
      m_lstDCMFile1.push_back(pData);
      return false;
    }
    for(FileInfoIT iter = m_lstDCMFile.begin(); iter != m_lstDCMFile.end(); iter++)
    {
      FileInfoData pFileInfo = (*iter);

      if (pData.strFilePath == pFileInfo.strFilePath && pData.nContentType == pFileInfo.nContentType)
      {
        m_lstDCMFile1.push_back(pData);
        return false;
      }
    }

    // add File Information data to list
    m_lstDCMFile.push_back(pData);
    return true;
  }

  bool AddContentList(FileInfoData pData)
  {
    for(FileInfoIT iter = m_lstContentList.begin(); iter != m_lstContentList.end(); iter++)
    {
      FileInfoData pFileInfo = (*iter);

      if (pData.strFilePath.CmpNoCase(pFileInfo.strFilePath) == 0 && pData.nContentType == pFileInfo.nContentType)
      {
        return false;
      }
    }

    // add File Information data to list
    m_lstContentList.push_back(pData);
    return true;
  }

  bool DownloadDDE(CTransferFileAction &tfAction, bool bDownload)
  {
    String strDDEDirectory = Settings.m_strFtpSettingPath;
    ADDBACKSLASH(strDDEDirectory);
    strDDEDirectory += 'DDE';
    DCMMisc::MakeSureDirectoryPathExists(strDDEDirectory);
    ADDBACKSLASH(strDDEDirectory);
    //Download Skin Setting for Touch Screen(DCM File for touch screen)
    for(FileInfoIT iter = m_lstDCMFile.begin(); iter != m_lstDCMFile.end(); iter++)
    {
      FileInfoData pFileInfo = (*iter);

      String strFile = pFileInfo.strFileTitle + '.dat';
      String strLocalFile = strDDEDirectory + strFile;
      if (bDownload)
      {
        String strRemoteFile = FTPPathImpl.getServerPath(DCM_PUBLISH_TYPE) +  '/DDE/' + strFile;
        if (tfAction.FindFile(strRemoteFile))
        {
          tfAction.TransferAction(strLocalFile, strRemoteFile);
        }
      }
      SerializeDDE(strLocalFile);
    }
    return true;
  }

  bool DownloadDCMFile(CTransferFileAction &tfAction, bool bDownload)
  {
    if (bDownload)
    {
      String strSkinsDirectory = Settings.m_strFtpSettingPath;
      ADDBACKSLASH(strSkinsDirectory);
      strSkinsDirectory += 'Skins';
      DCMMisc::MakeSureDirectoryPathExists(strSkinsDirectory);
      ADDBACKSLASH(strSkinsDirectory);
      //Download Skin Setting for Touch Screen(DCM File for touch screen)
      for(FileInfoIT iter = m_lstDCMFile.begin(); iter != m_lstDCMFile.end(); iter++)
      {
        FileInfoData pFileInfo = (*iter);

        String strFile = pFileInfo.strFileTitle + '.dat';
        String strLocalFile = strSkinsDirectory + strFile;

        String strRemoteFile = FTPPathImpl.getServerPath(DCM_PUBLISH_TYPE) + '/Skins/' + strFile;
        tfAction.TransferAction(strLocalFile, strRemoteFile);
      }
    }
    return true;
  }

  bool GetContentList(CTransferFileAction &tfAction, wxArrayString &ContentList, bool bDownload)
  {
    ContentList.Clear();

    for(FileInfoIT iter = m_lstContentList.begin(); iter != m_lstContentList.end(); iter++)
    {
      ContentList.Add((*iter).strFilePath);
    }

    if (bDownload)
    {
      String strContentListDirectory = Settings.m_strFtpSettingPath;
      ADDBACKSLASH(strContentListDirectory);
      strContentListDirectory += 'ContentList';
      DCMMisc::MakeSureDirectoryPathExists(strContentListDirectory);
      ADDBACKSLASH(strContentListDirectory);
      for(int i = 0; i < (int)ContentList.length; i++)
      {
        String strFile = ContentList[i] + '.dat';
        String strLocalFile = strContentListDirectory + strFile;

        String strRemoteFile = FTPPathImpl.getServerPath(DCM_PUBLISH_TYPE) +  '/ContentList/' + strFile;
        if (!tfAction.TransferAction(strLocalFile, strRemoteFile))
        {
  #ifdef FTP_DEBUG
          CFTPLogFile::Message(MSG_INFO, CFormat('Download Contentlist File list:'%s' failure\n') % strRemoteFile);
  #endif
          return false;
        }
      }
    }

    return true;
  }

  bool GetDCMArray(CTransferFileAction &tfAction, wxArrayString &DCMArray, bool bDownload)
  {
    DCMArray.Clear();
    for(FileInfoIT iter = m_lstDCMFile.begin(); iter != m_lstDCMFile.end(); iter++)
    {
      FileInfoData pFileInfo = (*iter);

      DCMArray.Add(pFileInfo.strFileTitle);

      GetSkinSetting(pFileInfo.strFileTitle, DCMArray);
    }

    if (bDownload)
    {
      String strDCMFileDirectory = Settings.m_strFtpSettingPath;
      ADDBACKSLASH(strDCMFileDirectory);
      strDCMFileDirectory += 'DCMFile';
      DCMMisc::MakeSureDirectoryPathExists(strDCMFileDirectory);
      ADDBACKSLASH(strDCMFileDirectory);
      for(int i = 0; i < (int)DCMArray.length; i++)
      {
        String strFile = DCMArray[i] + '.dat';
        String strLocalFile = strDCMFileDirectory + strFile;
        String strRemoteFile = FTPPathImpl.getServerPath(DCM_PUBLISH_TYPE) +  '/dcmfile/' + strFile;
        if (!tfAction.TransferAction(strLocalFile, strRemoteFile))
        {
  #ifdef FTP_DEBUG
          CFTPLogFile::Message(MSG_INFO, CFormat('Download DCM File list:'%s' failure\n') % strRemoteFile);
  #endif
          return false;
        }
      }
    }
    return true;
  }
}
