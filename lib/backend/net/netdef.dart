import 'dart:typed_data';
import 'dart:convert';

// 定义常量
const int kMAXCOMMANDSIZE = 512;
const int kMAXSTATUSSIZE = 300;
const int kDCMSERVERPORT = 40096;
const int kDCMMONITORPORT = 40069;
const int kDCMSMSSERVERPORT = 10028;
const int kDCM3GSERVERPORT = 10029;
const int kFTPMANAGERPORT = 10079;

// Message definitions
//const long msg_CommandReceived		= 'vod0' + 1;
//const long msg_NewSocketAccepted	= 'vod0' + 2;

// SMS Command Control
//const int kSMSCOMMANDMASK		0xff00;
const int kSMSCOMMANDPLAYLOG = 0x0001;
const int kSMSCOMMANDFTPLOG = 0x0002;
const int kSMSCOMMANDBPSSTATUS = 0x0004;
const int kSMSCOMMANDTIMESYNC = 0x0008;
const int kSMSCOMMANDRESET = 0x0010;
const int kSMSCOMMANDRESTART = 0x0020;
const int kSMSCOMMANDDCMPLAYER = 0x0040;
const int kSMSCOMMANDPLAYLIST = 0x0080;
const int kSMSCOMMANDAHPLAYLOG = 0x0100;
const int kSMSCOMMANDUSBDTLLOG = 0x0200;

// 协议ID枚举
enum ProtocolId {
  any(-1),
  nullProtocol(0),
  ah(1), // for DCMSound, ContentImport, use in HKJC
  qc(2), // Queue Control for Players Data Transfer
  lm(3), // License manager control
  cs(4), // Change Service
  last(9);

  final int value;
  const ProtocolId(this.value);
}

// 网络命令ID
enum NetCommand {
  requestSyncTime(0),
  registerUpdate(1),
  requestDcmContent(2),
  dcmContent(3),
  ahSender(4), // AhSender control
  ahMessage(5),
  eventMessage(6),
  playerStatus(7),
  transferStatus(8),
  register(9),
  resetTasks(10),
  resetSettings(11),
  resetTransfer(12),
  weather(13),
  contentList(14),
  monitor(15),
  resetSelf(16),
  resetHost(17),
  smsControl(18),
  shutdown(19),
  uniqueName(20),
  connection(21),
  lightBox(22),
  refresh(23),
  diskClean(24);

  final int value;
  const NetCommand(this.value);
}

NetCommand? netCommandFrom(int value) {
  for (var element in NetCommand.values) {
    if (element.value == value) {
      return element;
    }
  }

  return null;
}

// 数据包头结构体
class HeaderStruct {
  int eDCMID = 0; // 1字节
  int packetLength = 0; // 4字节
  int command = 0; // 1字节

  HeaderStruct();

  HeaderStruct.fromBytes(Uint8List bytes) {
    if (bytes.length < 6) {
      throw Exception('Insufficient bytes for HeaderStruct');
    }
    eDCMID = bytes[0];
    packetLength = _bytesToInt32(bytes.sublist(1, 5)); // bytes 1-4
    command = bytes[5];
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.addByte(eDCMID);
    buffer.add(_int32ToBytes(packetLength));
    buffer.addByte(command);
    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// UDP数据包头结构体
class UdpHeaderStruct {
  int eDCMID = 0; // 1字节
  int command = 0; // 1字节

  UdpHeaderStruct();

  UdpHeaderStruct.fromBytes(Uint8List bytes) {
    if (bytes.length < 2) {
      throw Exception('Insufficient bytes for UdpHeaderStruct');
    }
    eDCMID = bytes[0];
    command = bytes[1];
  }

  Uint8List toBytes() {
    return Uint8List.fromList([eDCMID, command]);
  }
}

// DCM内容结构
class DcmContent {
  String filePath = '';
  int pid = 0;
  bool allContent = false;
  bool includeToday = false;
  bool imm = false;
  String ftpTime = '';
  String timeout = '';
  String startFtpTime = '';
  int ftpContent = 0;
  int period = 0;

  DcmContent({this.filePath = '', this.pid = 0});

  DcmContent.fromBytes(Uint8List bytes, {bool isOleviaPlayer = false}) {
    int offset = 0;

    // 解析文件路径 (根据平台不同长度不同)
    int pathLength = isOleviaPlayer ? 35 : 100;
    List<int> pathBytes = [];
    for (int i = 0; i < pathLength && offset + i < bytes.length; i++) {
      if (bytes[offset + i] == 0) break;
      pathBytes.add(bytes[offset + i]);
    }
    filePath = utf8.decode(pathBytes);
    offset += pathLength;

    pid = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    allContent = bytes[offset] != 0;
    offset += 1;

    includeToday = bytes[offset] != 0;
    offset += 1;

    imm = bytes[offset] != 0;
    offset += 1;

    // 解析FTP时间
    List<int> ftpTimeBytes = [];
    for (int i = 0; i < 20 && offset + i < bytes.length; i++) {
      if (bytes[offset + i] == 0) break;
      ftpTimeBytes.add(bytes[offset + i]);
    }
    ftpTime = utf8.decode(ftpTimeBytes);
    offset += 20;

    // 解析超时
    List<int> timeoutBytes = [];
    for (int i = 0; i < 5 && offset + i < bytes.length; i++) {
      if (bytes[offset + i] == 0) break;
      timeoutBytes.add(bytes[offset + i]);
    }
    timeout = utf8.decode(timeoutBytes);
    offset += 5;

    // 解析开始FTP时间
    List<int> startFtpTimeBytes = [];
    for (int i = 0; i < 20 && offset + i < bytes.length; i++) {
      if (bytes[offset + i] == 0) break;
      startFtpTimeBytes.add(bytes[offset + i]);
    }
    startFtpTime = utf8.decode(startFtpTimeBytes);
    offset += 20;

    ftpContent = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    period = _bytesToInt32(bytes.sublist(offset, offset + 4));
  }

  Uint8List toBytes({bool isOleviaPlayer = false}) {
    final buffer = BytesBuilder();

    // 添加文件路径
    int pathLength = isOleviaPlayer ? 35 : 100;
    List<int> pathBytes = utf8.encode(filePath);
    if (pathBytes.length > pathLength - 1) {
      pathBytes = pathBytes.sublist(0, pathLength - 1);
    }
    buffer.add(pathBytes);
    for (int i = pathBytes.length; i < pathLength; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(pid));
    buffer.addByte(allContent ? 1 : 0);
    buffer.addByte(includeToday ? 1 : 0);
    buffer.addByte(imm ? 1 : 0);

    // 添加FTP时间
    List<int> ftpTimeBytes = utf8.encode(ftpTime);
    if (ftpTimeBytes.length > 19) {
      ftpTimeBytes = ftpTimeBytes.sublist(0, 19);
    }
    buffer.add(ftpTimeBytes);
    for (int i = ftpTimeBytes.length; i < 20; i++) {
      buffer.addByte(0);
    }

    // 添加超时
    List<int> timeoutBytes = utf8.encode(timeout);
    if (timeoutBytes.length > 4) {
      timeoutBytes = timeoutBytes.sublist(0, 4);
    }
    buffer.add(timeoutBytes);
    for (int i = timeoutBytes.length; i < 5; i++) {
      buffer.addByte(0);
    }

    // 添加开始FTP时间
    List<int> startFtpTimeBytes = utf8.encode(startFtpTime);
    if (startFtpTimeBytes.length > 19) {
      startFtpTimeBytes = startFtpTimeBytes.sublist(0, 19);
    }
    buffer.add(startFtpTimeBytes);
    for (int i = startFtpTimeBytes.length; i < 20; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(ftpContent));
    buffer.add(_int32ToBytes(period));

    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// 扩展DCM内容结构
class DcmContentEx extends DcmContent {
  int cbSize = 0;
  String task = '';
  String validity = '';
  int retries = 0;

  DcmContentEx() : super();

  @override
  DcmContentEx.fromBytes(Uint8List bytes, {bool isOleviaPlayer = false})
      : super.fromBytes(bytes.sublist(0, _getContentBaseSize(isOleviaPlayer)),
            isOleviaPlayer: isOleviaPlayer) {
    int baseSize = _getContentBaseSize(isOleviaPlayer);
    int offset = baseSize;

    cbSize = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    // 解析任务
    List<int> taskBytes = [];
    for (int i = 0; i < 15 && offset + i < bytes.length; i++) {
      if (bytes[offset + i] == 0) break;
      taskBytes.add(bytes[offset + i]);
    }
    task = utf8.decode(taskBytes);
    offset += 15;

    // 解析有效期
    List<int> validityBytes = [];
    for (int i = 0; i < 20 && offset + i < bytes.length; i++) {
      if (bytes[offset + i] == 0) break;
      validityBytes.add(bytes[offset + i]);
    }
    validity = utf8.decode(validityBytes);
    offset += 20;

    retries = _bytesToInt32(bytes.sublist(offset, offset + 4));
  }

  @override
  Uint8List toBytes({bool isOleviaPlayer = false}) {
    final buffer = BytesBuilder();
    buffer.add(super.toBytes(isOleviaPlayer: isOleviaPlayer));

    buffer.add(_int32ToBytes(cbSize));

    // 添加任务
    List<int> taskBytes = utf8.encode(task);
    if (taskBytes.length > 14) {
      taskBytes = taskBytes.sublist(0, 14);
    }
    buffer.add(taskBytes);
    for (int i = taskBytes.length; i < 15; i++) {
      buffer.addByte(0);
    }

    // 添加有效期
    List<int> validityBytes = utf8.encode(validity);
    if (validityBytes.length > 19) {
      validityBytes = validityBytes.sublist(0, 19);
    }
    buffer.add(validityBytes);
    for (int i = validityBytes.length; i < 20; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(retries));

    return buffer.toBytes();
  }

  static int _getContentBaseSize(bool isOleviaPlayer) {
    int pathLength = isOleviaPlayer ? 35 : 100;
    return pathLength + 4 + 1 + 1 + 1 + 20 + 5 + 20 + 4 + 4;
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// 传输状态结构
class TransferStatus {
  int errID = 0;
  String tfStatus = '';

  TransferStatus();

  TransferStatus.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      throw Exception('Insufficient bytes for TransferStatus');
    }

    errID = _bytesToInt32(bytes.sublist(0, 4));

    // 解析传输状态
    List<int> statusBytes = [];
    for (int i = 4; i < bytes.length && i < 4 + 256; i++) {
      if (bytes[i] == 0) break;
      statusBytes.add(bytes[i]);
    }
    tfStatus = utf8.decode(statusBytes);
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.add(_int32ToBytes(errID));

    // 添加传输状态
    List<int> statusBytes = utf8.encode(tfStatus);
    if (statusBytes.length > 255) {
      statusBytes = statusBytes.sublist(0, 255);
    }
    buffer.add(statusBytes);
    for (int i = statusBytes.length; i < 256; i++) {
      buffer.addByte(0);
    }

    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// 播放器状态结构
class PlayerStatus {
  String siteID = '';
  int dwStatus = 0;
  String tfStatus = '';
  int ip = 0;

  PlayerStatus();

  PlayerStatus.fromBytes(Uint8List bytes) {
    // 解析站点ID
    List<int> siteIdBytes = [];
    int maxSiteIdLength = 50;
    for (int i = 0; i < maxSiteIdLength && i < bytes.length; i++) {
      if (bytes[i] == 0) break;
      siteIdBytes.add(bytes[i]);
    }
    siteID = utf8.decode(siteIdBytes);
    int offset = maxSiteIdLength;

    dwStatus = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    // 解析传输状态
    List<int> statusBytes = [];
    int maxStatusLength = kMAXSTATUSSIZE;
    for (int i = offset;
        i < bytes.length && i < offset + maxStatusLength;
        i++) {
      if (bytes[i] == 0) break;
      statusBytes.add(bytes[i]);
    }
    tfStatus = utf8.decode(statusBytes);
    offset += maxStatusLength;

    ip = _bytesToInt32(bytes.sublist(offset, offset + 4));
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();

    // 添加站点ID
    List<int> siteIdBytes = utf8.encode(siteID);
    if (siteIdBytes.length > 49) {
      siteIdBytes = siteIdBytes.sublist(0, 49);
    }
    buffer.add(siteIdBytes);
    for (int i = siteIdBytes.length; i < 50; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(dwStatus));

    // 添加传输状态
    List<int> statusBytes = utf8.encode(tfStatus);
    if (statusBytes.length > kMAXSTATUSSIZE - 1) {
      statusBytes = statusBytes.sublist(0, kMAXSTATUSSIZE - 1);
    }
    buffer.add(statusBytes);
    for (int i = statusBytes.length; i < kMAXSTATUSSIZE; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(ip));

    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// 消息信息结构
class MessageInfo {
  int messageID = 0;
  String messageName = '';
  int status = 0;
  String task = '';

  MessageInfo();

  MessageInfo.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      throw Exception('Insufficient bytes for MessageInfo');
    }

    messageID = _bytesToInt32(bytes.sublist(0, 4));

    // 解析消息名称
    List<int> nameBytes = [];
    for (int i = 4; i < bytes.length && i < 4 + 50; i++) {
      if (bytes[i] == 0) break;
      nameBytes.add(bytes[i]);
    }
    messageName = utf8.decode(nameBytes);
    int offset = 4 + 50;

    status = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    // 解析任务
    List<int> taskBytes = [];
    for (int i = offset; i < bytes.length && i < offset + 15; i++) {
      if (bytes[i] == 0) break;
      taskBytes.add(bytes[i]);
    }
    task = utf8.decode(taskBytes);
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.add(_int32ToBytes(messageID));

    // 添加消息名称
    List<int> nameBytes = utf8.encode(messageName);
    if (nameBytes.length > 49) {
      nameBytes = nameBytes.sublist(0, 49);
    }
    buffer.add(nameBytes);
    for (int i = nameBytes.length; i < 50; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(status));

    // 添加任务
    List<int> taskBytes = utf8.encode(task);
    if (taskBytes.length > 14) {
      taskBytes = taskBytes.sublist(0, 14);
    }
    buffer.add(taskBytes);
    for (int i = taskBytes.length; i < 15; i++) {
      buffer.addByte(0);
    }

    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// DCM事件信息结构
class DcmEventInfo {
  int messageID = 0;
  String messageName = '';
  int ip = 0;
  int port = 0;
  int status = 0;

  DcmEventInfo();

  DcmEventInfo.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      throw Exception('Insufficient bytes for DcmEventInfo');
    }

    messageID = _bytesToInt32(bytes.sublist(0, 4));

    // 解析消息名称
    List<int> nameBytes = [];
    for (int i = 4; i < bytes.length && i < 4 + 50; i++) {
      if (bytes[i] == 0) break;
      nameBytes.add(bytes[i]);
    }
    messageName = utf8.decode(nameBytes);
    int offset = 4 + 50;

    ip = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    port = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    status = _bytesToInt32(bytes.sublist(offset, offset + 4));
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.add(_int32ToBytes(messageID));

    // 添加消息名称
    List<int> nameBytes = utf8.encode(messageName);
    if (nameBytes.length > 49) {
      nameBytes = nameBytes.sublist(0, 49);
    }
    buffer.add(nameBytes);
    for (int i = nameBytes.length; i < 50; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(ip));
    buffer.add(_int32ToBytes(port));
    buffer.add(_int32ToBytes(status));

    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}

// AH发送器结构
class AhSender {
  int messageID = 0;
  String messageName = '';
  String startTime = '';
  String endTime = '';
  String createTime = '';
  int status = 0;
  bool endManual = false;

  AhSender();

  AhSender.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      throw Exception('Insufficient bytes for AhSender');
    }

    messageID = _bytesToInt32(bytes.sublist(0, 4));

    // 解析消息名称
    List<int> nameBytes = [];
    for (int i = 4; i < bytes.length && i < 4 + 50; i++) {
      if (bytes[i] == 0) break;
      nameBytes.add(bytes[i]);
    }
    messageName = utf8.decode(nameBytes);
    int offset = 4 + 50;

    // 解析开始时间
    List<int> startTimeBytes = [];
    for (int i = offset; i < bytes.length && i < offset + 20; i++) {
      if (bytes[i] == 0) break;
      startTimeBytes.add(bytes[i]);
    }
    startTime = utf8.decode(startTimeBytes);
    offset += 20;

    // 解析结束时间
    List<int> endTimeBytes = [];
    for (int i = offset; i < bytes.length && i < offset + 20; i++) {
      if (bytes[i] == 0) break;
      endTimeBytes.add(bytes[i]);
    }
    endTime = utf8.decode(endTimeBytes);
    offset += 20;

    // 解析创建时间
    List<int> createTimeBytes = [];
    for (int i = offset; i < bytes.length && i < offset + 20; i++) {
      if (bytes[i] == 0) break;
      createTimeBytes.add(bytes[i]);
    }
    createTime = utf8.decode(createTimeBytes);
    offset += 20;

    status = _bytesToInt32(bytes.sublist(offset, offset + 4));
    offset += 4;

    endManual = bytes[offset] != 0;
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.add(_int32ToBytes(messageID));

    // 添加消息名称
    List<int> nameBytes = utf8.encode(messageName);
    if (nameBytes.length > 49) {
      nameBytes = nameBytes.sublist(0, 49);
    }
    buffer.add(nameBytes);
    for (int i = nameBytes.length; i < 50; i++) {
      buffer.addByte(0);
    }

    // 添加开始时间
    List<int> startTimeBytes = utf8.encode(startTime);
    if (startTimeBytes.length > 19) {
      startTimeBytes = startTimeBytes.sublist(0, 19);
    }
    buffer.add(startTimeBytes);
    for (int i = startTimeBytes.length; i < 20; i++) {
      buffer.addByte(0);
    }

    // 添加结束时间
    List<int> endTimeBytes = utf8.encode(endTime);
    if (endTimeBytes.length > 19) {
      endTimeBytes = endTimeBytes.sublist(0, 19);
    }
    buffer.add(endTimeBytes);
    for (int i = endTimeBytes.length; i < 20; i++) {
      buffer.addByte(0);
    }

    // 添加创建时间
    List<int> createTimeBytes = utf8.encode(createTime);
    if (createTimeBytes.length > 19) {
      createTimeBytes = createTimeBytes.sublist(0, 19);
    }
    buffer.add(createTimeBytes);
    for (int i = createTimeBytes.length; i < 20; i++) {
      buffer.addByte(0);
    }

    buffer.add(_int32ToBytes(status));
    buffer.addByte(endManual ? 1 : 0);

    return buffer.toBytes();
  }

  static int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Need 4 bytes for int32');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }
}
