import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcm/backend/net/netdef.dart';

// 包类实现
class Packet {
  int size = 0;
  int opcode = 0;
  int protocol = 0;
  bool isSplitted = false;
  bool isLastSplitted = false;
  bool isPacked = false;
  bool isFromPF = false;
  Uint8List head = Uint8List(6);
  Uint8List? tempBuffer;
  Uint8List? completeBuffer;
  Uint8List? pBuffer;

  // 构造函数1: 基础协议构造
  Packet({this.protocol = 2}) {
    // 默认协议QC
    size = 0;
    opcode = 0;
    isSplitted = false;
    isLastSplitted = false;
    isPacked = false;
    isFromPF = false;
    head.fillRange(0, 6, 0);
    tempBuffer = null;
    completeBuffer = null;
    pBuffer = null;
  }

  // 构造函数2: 从原始头部和缓冲区构建（用于接收数据包）
  Packet.fromRawHeader(Uint8List rawHeader, Uint8List buf) {
    head.fillRange(0, 6, 0);
    final header = HeaderStruct.fromBytes(rawHeader);
    size = _ntohl(header.packetLength) - 1;
    opcode = header.command;
    protocol = header.eDCMID;
    isSplitted = false;
    isLastSplitted = false;
    isPacked = false;
    isFromPF = false;
    tempBuffer = null;
    completeBuffer = null;

    final payloadBuffer = Uint8List(size);
    final copyLength = buf.length < size ? buf.length : size;
    payloadBuffer.setRange(0, copyLength, buf.sublist(0, copyLength));
    pBuffer = payloadBuffer;
  }

  // 构造函数3: 从字符串构建
  Packet.fromString(String str, {this.protocol = 2, this.opcode = 0}) {
    isSplitted = false;
    isPacked = false;
    isLastSplitted = false;
    isFromPF = false;
    size = str.length;
    completeBuffer = Uint8List(size + 6);
    pBuffer = Uint8List.view(
      completeBuffer!.buffer,
      completeBuffer!.offsetInBytes + 6,
      size,
    );
    final strBytes = utf8.encode(str);
    pBuffer!.setRange(0, strBytes.length, strBytes);
    tempBuffer = null;
  }

  // 析构（Dart自动垃圾回收，但这里保留概念）
  void dispose() {
    if (tempBuffer != null) {
      tempBuffer = null;
    }
  }

  // 从头部获取数据包大小
  static int getPacketSizeFromHeader(Uint8List rawHeader) {
    final header = HeaderStruct.fromBytes(rawHeader);
    int size = _ntohl(header.packetLength);
    if (size < 1 || size >= 0x7ffffff0) {
      return 0;
    }
    return size - 1;
  }

  // 复制数据到缓冲区
  void copyToDataBuffer(int offset, Uint8List data, int length) {
    if (offset + length > size + 1) {
      throw Exception('Offset + length exceeds buffer size');
    }
    pBuffer!.setRange(offset, offset + length, data.sublist(0, length));
  }

  // 获取数据包
  Uint8List getPacket() {
    if (completeBuffer != null) {
      if (!isSplitted) {
        final headerBytes = getHeader();
        completeBuffer!.setRange(0, headerBytes.length, headerBytes);
      }
      return completeBuffer!;
    } else {
      if (tempBuffer != null) {
        tempBuffer = null;
      }
      tempBuffer = Uint8List(size + 6);
      final headerBytes = getHeader();
      tempBuffer!.setRange(0, headerBytes.length, headerBytes);
      tempBuffer!.setRange(6, 6 + size, pBuffer!);
      return tempBuffer!;
    }
  }

  // 分离数据包
  Uint8List detachPacket() {
    if (completeBuffer != null) {
      if (!isSplitted) {
        final headerBytes = getHeader();
        completeBuffer!.setRange(0, headerBytes.length, headerBytes);
      }
      final result = completeBuffer!;
      completeBuffer = null;
      pBuffer = null;
      return result;
    } else {
      if (tempBuffer != null) {
        tempBuffer = null;
      }
      tempBuffer = Uint8List(size + 6);
      final headerBytes = getHeader();
      tempBuffer!.setRange(0, headerBytes.length, headerBytes);
      tempBuffer!.setRange(6, 6 + size, pBuffer!);
      final result = tempBuffer!;
      tempBuffer = null;
      return result;
    }
  }

  // 获取头部
  Uint8List getHeader() {
    if (isSplitted) {
      throw Exception('Cannot get header for split packet');
    }

    final header = HeaderStruct();
    header.command = opcode;
    header.eDCMID = protocol;
    header.packetLength = _htonl(size + 1);

    return header.toBytes();
  }

  // 获取UDP头部
  Uint8List getUDPHeader() {
    if (isSplitted) {
      throw Exception('Cannot get UDP header for split packet');
    }

    head.fillRange(0, 6, 0);
    final udpHeader = UdpHeaderStruct();
    udpHeader.eDCMID = protocol;
    udpHeader.command = opcode;

    return udpHeader.toBytes();
  }

  // 将32位整数写入数据缓冲区
  void copyUInt32ToDataBuffer(int data, {int offset = 0}) {
    if (offset > size - 4) {
      throw Exception('Bad offset in copyUInt32ToDataBuffer');
    }
    final dataBytes = _int32ToBytes(data);
    pBuffer!.setRange(offset, offset + 4, dataBytes);
  }

  // 获取操作码
  int getOpCode() => opcode;

  // 设置操作码
  void setOpCode(int opCode) {
    opcode = opCode;
  }

  // 获取数据包大小
  int getPacketSize() => size;

  // 获取协议
  int getProtocol() => protocol;

  // 设置协议
  void setProtocol(int p) {
    protocol = p;
  }

  // 获取数据缓冲区
  Uint8List? getDataBuffer() => pBuffer;

  // 是否是分片数据包
  bool isSplittedPacket() => isSplitted;

  // 是否是最后一个分片
  bool isLastSplittedPacket() => isLastSplitted;

  // 是否来自部分文件
  bool isFromPartFile() => isFromPF;

  // 实现网络字节序转换函数
  static int _htonl(int value) {
    return value & 0xFFFFFFFF;
  }

  static int _ntohl(int value) {
    return value & 0xFFFFFFFF;
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

class PacketTcpServer {
  PacketTcpServer({
    this.port = kFTPMANAGERPORT,
    this.address,
    this.onPacket,
    this.onError,
  });

  final int port;
  final InternetAddress? address;
  final void Function(Packet packet)? onPacket;
  final void Function(Object error, StackTrace stackTrace)? onError;

  ServerSocket? _serverSocket;
  final PacketStreamParser _parser = PacketStreamParser();

  Future<void> start() async {
    final bindAddress = address ?? InternetAddress.anyIPv4;
    _serverSocket = await ServerSocket.bind(bindAddress, port);
    _serverSocket!.listen((socket) {
      socket.listen(
        (data) {
          final packets = _parser.feedAll(data);
          for (final packet in packets) {
            onPacket?.call(packet);
          }
        },
        onError: (error, StackTrace stackTrace) {
          onError?.call(error, stackTrace);
        },
        onDone: () {
          socket.destroy();
        },
      );
    });
  }

  Future<void> stop() async {
    final serverSocket = _serverSocket;
    _serverSocket = null;
    await serverSocket?.close();
  }

  static Packet? parsePacket(Uint8List bytes) {
    return PacketStreamParser().feed(bytes);
  }

  static PacketStreamParser createParser() {
    return PacketStreamParser();
  }
}

class PacketStreamParser {
  final List<int> _buffer = <int>[];

  Packet? feed(Uint8List chunk) {
    final packets = feedAll(chunk);
    return packets.isEmpty ? null : packets.first;
  }

  List<Packet> feedAll(Uint8List chunk) {
    _buffer.addAll(chunk);
    final packets = <Packet>[];

    while (true) {
      if (_buffer.length < 6) {
        return packets;
      }

      final headerBytes = Uint8List.fromList(_buffer.sublist(0, 6));
      final packetSize = Packet.getPacketSizeFromHeader(headerBytes);
      if (packetSize <= 0) {
        _buffer.clear();
        return packets;
      }

      final totalPacketLength = 6 + packetSize;
      if (_buffer.length < totalPacketLength) {
        return packets;
      }

      final packetBytes =
          Uint8List.fromList(_buffer.sublist(0, totalPacketLength));
      _buffer.removeRange(0, totalPacketLength);
      packets.add(
        Packet.fromRawHeader(packetBytes.sublist(0, 6), packetBytes.sublist(6)),
      );
    }
  }
}

// 示例用法
void main() {
  print('Socket Communication Packet Implementation in Flutter/Dart');

  // 创建一个简单的数据包
  final packet = Packet(protocol: ProtocolId.qc.value);
  packet.setOpCode(NetCommand.registerUpdate.value);

  print('Created packet with opcode: ${packet.getOpCode()}');
  print('Packet protocol: ${packet.getProtocol()}');

  // 创建一个包含字符串的数据包
  final stringPacket = Packet.fromString('Hello, DCM!',
      protocol: ProtocolId.ah.value, opcode: NetCommand.ahMessage.value);
  print('String packet size: ${stringPacket.getPacketSize()}');
  print('String packet opcode: ${stringPacket.getOpCode()}');

  // 创建一个DCM内容对象
  final content = DcmContent(filePath: '/home/user/file.txt', pid: 12345)
    ..allContent = true
    ..includeToday = true
    ..imm = false
    ..ftpTime = '2023-06-01 10:30:00'
    ..timeout = '30s'
    ..startFtpTime = '2023-06-01 09:00:00'
    ..ftpContent = 100
    ..period = 3600;

  print('DCM Content:');
  print('  Path: ${content.filePath}');
  print('  PID: ${content.pid}');
  print('  All Content: ${content.allContent}');
  print('  Include Today: ${content.includeToday}');

  // 序列化和反序列化示例
  final contentBytes = content.toBytes();
  print('Serialized DCM Content length: ${contentBytes.length}');

  try {
    final deserializedContent = DcmContent.fromBytes(contentBytes);
    print('Deserialized DCM Content path: ${deserializedContent.filePath}');
    print('Deserialized PID: ${deserializedContent.pid}');
  } catch (e) {
    print('Error during deserialization: $e');
  }
}
