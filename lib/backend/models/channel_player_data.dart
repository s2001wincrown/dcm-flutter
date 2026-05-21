import 'package:dcm/backend/xmlfile/xmlitem.dart';

class ChannelPlayerData {
  String channelName = '';
  String playerName = '';
  String diskSerial = '';
  String uniqueName = '';
  DateTime? startDate;
  DateTime? endDate;
  int output = 0;
  int channelID = -1;
  int playerID = -1;
  int id = -1;
  String userCode = '';
  String groupCode = '';
  DateTime? modified;
  DateTime? created;

  ChannelPlayerData();

  ChannelPlayerData.copy(ChannelPlayerData other) {
    channelName = other.channelName;
    playerName = other.playerName;
    diskSerial = other.diskSerial;
    uniqueName = other.uniqueName;
    startDate = other.startDate;
    endDate = other.endDate;
    output = other.output;
    channelID = other.channelID;
    playerID = other.playerID;
    id = other.id;
    userCode = other.userCode;
    groupCode = other.groupCode;
    modified = other.modified;
    created = other.created;
  }

  void writeToXML(XmlItem pXmlItem) {
    pXmlItem.addItem('m_strChannelName', channelName);
    pXmlItem.addItem('m_strPlayerName', playerName);
    pXmlItem.addItem('m_strDiskSerial', diskSerial);
    pXmlItem.addItem('m_strUniqueName', uniqueName);
    pXmlItem.addItem('m_dtStartDate', startDate);
    pXmlItem.addItem('m_dtEndDate', endDate);
    pXmlItem.addItem('m_uiOutput', output);
    pXmlItem.addItem('m_uiChannelID', channelID);
    pXmlItem.addItem('m_uiPlayerID', playerID);
    pXmlItem.addItem('m_uiID', id);
    pXmlItem.addItem('m_strUserCode', userCode);
    pXmlItem.addItem('m_strGroupCode', groupCode);
    pXmlItem.addItem('m_dtmodified', modified);
    pXmlItem.addItem('m_dtCreated', created);
  }

  void getFromXML(XmlItem pXmlItem) {
    channelName = pXmlItem.getItemValue('m_strChannelName');
    playerName = pXmlItem.getItemValue('m_strPlayerName');
    diskSerial = pXmlItem.getItemValue('m_strDiskSerial');
    uniqueName = pXmlItem.getItemValue('m_strUniqueName');
    startDate = pXmlItem.getItemValueD('m_dtStartDate');
    endDate = pXmlItem.getItemValueD('m_dtEndDate');
    output = pXmlItem.getItemValueI('m_uiOutput');
    channelID = pXmlItem.getItemValueI('m_uiChannelID');
    playerID = pXmlItem.getItemValueI('m_uiPlayerID');
    id = pXmlItem.getItemValueI('m_uiID');
    userCode = pXmlItem.getItemValue('m_strUserCode');
    groupCode = pXmlItem.getItemValue('m_strGroupCode');
    modified = pXmlItem.getItemValueD('m_dtmodified');
    created = pXmlItem.getItemValueD('m_dtCreated');
  }

  bool isPlayer(int uiPlayerID, String diskSerial, [String? uniqueName]) {
    if (uiPlayerID >= 0 && uiPlayerID != playerID) return false;
    if (uniqueName == null || uniqueName.isEmpty) {
      return diskSerial.toLowerCase() == this.diskSerial.toLowerCase();
    }
    return uniqueName.toLowerCase() == this.uniqueName.toLowerCase();
  }

  bool isChannel(int uiChannelID, [String channelName = '']) {
    if (uiChannelID >= 0 && uiChannelID != channelID) return false;
    if (channelName.isEmpty) return true;
    return this.channelName.toLowerCase() == channelName.toLowerCase();
  }

  bool isEffective(DateTime dtFrom) {
    if (startDate == null) return false;
    if (dtFrom.isBefore(startDate!)) return false;
    if (endDate == null) return true;
    return !dtFrom.isAfter(endDate!);
  }
}
