import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:uuid/uuid.dart';

class CCDanmakuArgs {
  final int channelId;
  final int gameType;
  final int roomId;

  CCDanmakuArgs({required this.channelId, required this.roomId, required this.gameType});
}

class CCDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 45 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  WebScoketUtils? webScoketUtils;
  final Uuid _uuid = Uuid();

  @override
  Future start(dynamic args) async {
    if (args is! CCDanmakuArgs || args.channelId <= 0 || args.roomId <= 0) {
      onClose?.call('弹幕参数无效');
      return;
    }
    webScoketUtils = WebScoketUtils(
      url: 'wss://weblink.cc.163.com',
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        if (e is Uint8List) decodeMessage(e);
        if (e is List<int>) decodeMessage(Uint8List.fromList(e));
      },
      onReady: () {
        onReady?.call();
        markConnected();
        joinRoom(args);
      },
      onHeartBeat: heartbeat,
      onReconnect: () {
        markDisconnected();
        onClose?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (e) {
        markDisconnected();
        onClose?.call('服务器连接失败$e');
      },
    );
    webScoketUtils?.connect();
  }

  Future<void> joinRoom(CCDanmakuArgs args) async {
    final deviceToken = '${_uuid.v1()}@web.cc.163.com';
    webScoketUtils?.sendMessage(_packet(6144, 2, _registerPayload(deviceToken)));
    await Future.delayed(const Duration(seconds: 1));
    heartbeat();
    webScoketUtils?.sendMessage(_packet(512, 1, {
      'roomId': args.roomId,
      'cid': args.channelId,
      'gametype': args.gameType,
      'hall_version': 1,
      'motive': '',
      'account_id': deviceToken,
      'recom_token': '',
      'client_type': 4000,
      'client_source': '',
    }));
  }

  Map<String, dynamic> _registerPayload(String deviceToken) {
    return {
      'web-cc': DateTime.now().microsecondsSinceEpoch,
      'macAdd': deviceToken,
      'device_token': deviceToken,
      'page_uuid': _uuid.v1(),
      'update_req_info': {
        '22': 640,
        '23': 360,
        '24': 'web',
        '25': 'Linux',
        '29': '163_cc',
        '30': '',
        '31':
            'Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Mobile Safari/537.36',
      },
      'memory': 1,
      'version': 1,
      'system': 'win',
      'client_type': 4253,
      'webccType': 4253,
      'account_id': deviceToken,
    };
  }

  Uint8List _packet(int sid, int cid, Map<String, dynamic> payload) {
    final writer = _BinaryWriter(128);
    writer.writeUint16LE(sid);
    writer.writeUint16LE(cid);
    writer.writeUint32LE(0);
    writer.writeBytes(_MsgPackEncoder.encode(payload));
    return writer.toBytes();
  }

  Uint8List _heartbeatPacket() => _packet(6144, 5, {});

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(_heartbeatPacket());
  }

  void decodeMessage(Uint8List data) {
    try {
      if (data.length <= 8) return;
      var body = data.sublist(8);
      if (body.isNotEmpty && body[0] == 0x78) {
        body = Uint8List.fromList(zlib.decode(body));
      }
      final message = _MsgPackDecoder(body).decode();
      if (message is Map) handleMsg(message);
    } catch (e) {
      CoreLog.error(e);
    }
  }

  void handleMsg(Map message) {
    if (message.containsKey('usercount')) {
      onMessage?.call(LiveMessage(
        type: LiveMessageType.online,
        data: message['usercount'] ?? 0,
        color: LiveMessageColor.white,
        userName: '',
        message: '',
      ));
      return;
    }

    final data = message['data'];
    if (data is Map) {
      final msgList = data['msg_list'];
      if (msgList is List) {
        for (final msg in msgList) {
          _emitStructuredMsg(msg);
        }
      }
      return;
    }

    final msg = message['msg'];
    if (msg is List) {
      for (final item in msg) {
        _emitRegexMsg(item);
      }
    } else if (msg is Map) {
      for (final item in msg.keys) {
        _emitRegexMsg(item);
      }
    }
  }

  void _emitStructuredMsg(dynamic msg) {
    if (msg is! Map) return;
    final userName = (msg['name'] ?? '').toString();
    final text = (msg['text'] ?? msg[4] ?? '').toString();
    if (userName.isEmpty || text.isEmpty) return;
    onMessage?.call(LiveMessage(
      type: LiveMessageType.chat,
      userName: userName,
      userLevel: (msg['userlevel'] ?? '').toString(),
      message: text,
      color: LiveMessageColor.white,
    ));
  }

  void _emitRegexMsg(dynamic value) {
    final s = value.toString();
    final nickname = RegExp(r', 197: (.+?), ').firstMatch(s)?.group(1) ?? '';
    final message = RegExp(r', 4: (.+?), 5: ').firstMatch(s)?.group(1) ?? '';
    final userLevel = RegExp(r'"level": (\d+),').firstMatch(s)?.group(1) ?? '';
    final fansLevel = RegExp(r', 28: (\d+),').firstMatch(s)?.group(1) ?? '';
    if (nickname.isEmpty || message.isEmpty) return;
    onMessage?.call(LiveMessage(
      type: LiveMessageType.chat,
      userName: nickname,
      message: message,
      userLevel: userLevel,
      fansLevel: fansLevel,
      color: LiveMessageColor.white,
    ));
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    markDisconnected();
    webScoketUtils?.close();
  }
}

class _BinaryWriter {
  ByteData _buffer;
  int _offset = 0;

  _BinaryWriter(int initialSize) : _buffer = ByteData(initialSize);

  void _ensureCapacity(int length) {
    if (_offset + length <= _buffer.lengthInBytes) return;
    final old = _buffer.buffer.asUint8List();
    _buffer = ByteData((_offset + length) * 2);
    _buffer.buffer.asUint8List().setRange(0, _offset, old);
  }

  void writeUint8(int value) {
    _ensureCapacity(1);
    _buffer.setUint8(_offset, value);
    _offset += 1;
  }

  void writeUint16LE(int value) {
    _ensureCapacity(2);
    _buffer.setUint16(_offset, value, Endian.little);
    _offset += 2;
  }

  void writeUint32LE(int value) {
    _ensureCapacity(4);
    _buffer.setUint32(_offset, value, Endian.little);
    _offset += 4;
  }

  void writeBytes(List<int> bytes) {
    _ensureCapacity(bytes.length);
    _buffer.buffer.asUint8List().setAll(_offset, bytes);
    _offset += bytes.length;
  }

  Uint8List toBytes() => _buffer.buffer.asUint8List(0, _offset);
}

class _MsgPackEncoder {
  static Uint8List encode(dynamic value) {
    final writer = _BinaryWriter(1024);
    _encodeValue(writer, value);
    return writer.toBytes();
  }

  static void _encodeValue(_BinaryWriter writer, dynamic value) {
    if (value == null) {
      writer.writeUint8(0xc0);
    } else if (value is bool) {
      writer.writeUint8(value ? 0xc3 : 0xc2);
    } else if (value is String) {
      _encodeString(writer, value);
    } else if (value is int) {
      _encodeInt(writer, value);
    } else if (value is double) {
      writer.writeUint8(0xcb);
      final data = ByteData(8)..setFloat64(0, value, Endian.big);
      writer.writeBytes(data.buffer.asUint8List());
    } else if (value is Map) {
      _encodeMap(writer, value);
    } else {
      _encodeString(writer, value.toString());
    }
  }

  static void _encodeString(_BinaryWriter writer, String value) {
    final bytes = utf8.encode(value);
    if (bytes.length < 32) {
      writer.writeUint8(0xa0 + bytes.length);
    } else if (bytes.length <= 255) {
      writer.writeUint8(0xd9);
      writer.writeUint8(bytes.length);
    } else if (bytes.length <= 65535) {
      writer.writeUint8(0xda);
      writer.writeUint16LE(bytes.length);
    } else {
      writer.writeUint8(0xdb);
      writer.writeUint32LE(bytes.length);
    }
    writer.writeBytes(bytes);
  }

  static void _encodeInt(_BinaryWriter writer, int value) {
    if (value >= 0 && value <= 127) {
      writer.writeUint8(value);
    } else if (value >= 0 && value <= 255) {
      writer.writeUint8(0xcc);
      writer.writeUint8(value);
    } else if (value >= 0 && value <= 65535) {
      writer.writeUint8(0xcd);
      writer.writeUint16LE(value);
    } else {
      writer.writeUint8(0xce);
      writer.writeUint32LE(value);
    }
  }

  static void _encodeMap(_BinaryWriter writer, Map value) {
    if (value.length < 16) {
      writer.writeUint8(0x80 | value.length);
    } else {
      writer.writeUint8(0xde);
      writer.writeUint16LE(value.length);
    }
    for (final entry in value.entries) {
      _encodeString(writer, entry.key.toString());
      _encodeValue(writer, entry.value);
    }
  }
}

class _MsgPackDecoder {
  final Uint8List data;
  int offset = 0;

  _MsgPackDecoder(this.data);

  dynamic decode() => _readValue();

  int _readUint8() => data[offset++];

  int _readUint16() {
    final value = ByteData.sublistView(data, offset, offset + 2).getUint16(0, Endian.big);
    offset += 2;
    return value;
  }

  int _readUint32() {
    final value = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    return value;
  }

  int _readUint64() {
    final value = ByteData.sublistView(data, offset, offset + 8).getUint64(0, Endian.big);
    offset += 8;
    return value;
  }

  int _readInt8() {
    final value = ByteData.sublistView(data, offset, offset + 1).getInt8(0);
    offset += 1;
    return value;
  }

  int _readInt16() {
    final value = ByteData.sublistView(data, offset, offset + 2).getInt16(0, Endian.big);
    offset += 2;
    return value;
  }

  int _readInt32() {
    final value = ByteData.sublistView(data, offset, offset + 4).getInt32(0, Endian.big);
    offset += 4;
    return value;
  }

  int _readInt64() {
    final value = ByteData.sublistView(data, offset, offset + 8).getInt64(0, Endian.big);
    offset += 8;
    return value;
  }

  double _readFloat32() {
    final value = ByteData.sublistView(data, offset, offset + 4).getFloat32(0, Endian.big);
    offset += 4;
    return value;
  }

  double _readFloat64() {
    final value = ByteData.sublistView(data, offset, offset + 8).getFloat64(0, Endian.big);
    offset += 8;
    return value;
  }

  String _readString(int length) {
    final value = utf8.decode(data.sublist(offset, offset + length), allowMalformed: true);
    offset += length;
    return value;
  }

  List<dynamic> _readList(int length) {
    return List.generate(length, (_) => _readValue());
  }

  Map<dynamic, dynamic> _readMap(int length) {
    final map = <dynamic, dynamic>{};
    for (var i = 0; i < length; i++) {
      final key = _readValue();
      final value = _readValue();
      map[key] = value;
    }
    return map;
  }

  dynamic _readValue() {
    final tag = _readUint8();
    if (tag <= 0x7f) return tag;
    if (tag >= 0xe0) return tag - 256;
    if (tag >= 0xa0 && tag <= 0xbf) return _readString(tag & 0x1f);
    if (tag >= 0x90 && tag <= 0x9f) return _readList(tag & 0x0f);
    if (tag >= 0x80 && tag <= 0x8f) return _readMap(tag & 0x0f);

    switch (tag) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xcc:
        return _readUint8();
      case 0xcd:
        return _readUint16();
      case 0xce:
        return _readUint32();
      case 0xcf:
        return _readUint64();
      case 0xd0:
        return _readInt8();
      case 0xd1:
        return _readInt16();
      case 0xd2:
        return _readInt32();
      case 0xd3:
        return _readInt64();
      case 0xd9:
        return _readString(_readUint8());
      case 0xda:
        return _readString(_readUint16());
      case 0xdb:
        return _readString(_readUint32());
      case 0xdc:
        return _readList(_readUint16());
      case 0xdd:
        return _readList(_readUint32());
      case 0xde:
        return _readMap(_readUint16());
      case 0xdf:
        return _readMap(_readUint32());
      case 0xca:
        return _readFloat32();
      case 0xcb:
        return _readFloat64();
      default:
        throw FormatException('Unknown msgpack tag: 0x${tag.toRadixString(16)}');
    }
  }
}
