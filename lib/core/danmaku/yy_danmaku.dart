import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class YyDanmakuArgs {
  final int topSid;
  final int subSid;

  YyDanmakuArgs({required this.topSid, required this.subSid});
}

class YyDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 5 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void markConnected() {
    _connected = true;
  }

  @override
  void markDisconnected() {
    _connected = false;
  }

  WebScoketUtils? webScoketUtils;
  late YyDanmakuArgs danmakuArgs;
  final appId = 'yymwebh5';
  final appVersion = '3.2.10';
  late final String uuid = _uuid();

  @override
  Future start(dynamic args) async {
    if (args is! YyDanmakuArgs || args.topSid <= 0 || args.subSid <= 0) {
      onClose?.call('弹幕参数无效');
      return;
    }
    danmakuArgs = args;
    webScoketUtils = WebScoketUtils(
      url: 'wss://h5-sinchl.yy.com/websocket?appid=$appId&version=$appVersion&uuid=$uuid',
      heartBeatTime: heartbeatTime,
      headers: {
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'origin': 'https://www.yy.com',
      },
      onMessage: (e) {
        if (e is Uint8List) decodeMessage(e);
        if (e is List<int>) decodeMessage(Uint8List.fromList(e));
      },
      onReady: () {
        onReady?.call();
        markConnected();
        final packet = _buildJoinChannelPacket();
        if (packet != null) webScoketUtils?.sendMessage(packet);
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

  @override
  void heartbeat() {
    final buffer = Uint8List(14);
    final data = ByteData.view(buffer.buffer);
    final values = [0x0e00, 0x0000, 0x041e, 0x0c00, 0xc800, 0x0000, 0x0000];
    for (var i = 0; i < values.length; i++) {
      data.setUint16(i * 2, values[i], Endian.little);
    }
    webScoketUtils?.sendMessage(buffer);
  }

  Uint8List? _buildJoinChannelPacket() {
    try {
      final buffer = Uint8List(256);
      final byteData = ByteData.view(buffer.buffer);
      var offset = 0;
      byteData.setUint32(offset, 0x10000001, Endian.little);
      offset += 4;
      byteData.setUint32(offset, 3104100, Endian.little);
      offset += 4;
      byteData.setUint16(offset, 0, Endian.little);
      offset += 2;
      byteData.setUint32(offset, 0, Endian.little);
      offset += 4;
      byteData.setUint32(offset, danmakuArgs.topSid, Endian.little);
      offset += 4;
      byteData.setUint32(offset, danmakuArgs.subSid, Endian.little);
      offset += 4;
      byteData.setUint32(offset, 10, Endian.little);
      offset += 4;
      offset = _writeUtf8(buffer, byteData, offset, appVersion);
      offset = _writeUtf8(buffer, byteData, offset, uuid);
      byteData.setUint32(offset, 0, Endian.little);
      offset += 4;
      return buffer.sublist(0, offset);
    } catch (e) {
      CoreLog.error(e);
      return null;
    }
  }

  int _writeUtf8(Uint8List buffer, ByteData byteData, int offset, String value) {
    final bytes = utf8.encode(value);
    byteData.setUint16(offset, bytes.length, Endian.little);
    offset += 2;
    buffer.setAll(offset, bytes);
    return offset + bytes.length;
  }

  void decodeMessage(Uint8List data) {
    try {
      final parser = _BufferParser(data);
      parser.getUI32();
      final ruri = parser.getUI32();
      parser.getUI16();
      if (ruri == 3104600) {
        parser.getUI32();
        parser.getUI32();
        parser.getUI32();
        final nick = parser.getUTF8();
        final msg = parser.getUTF8();
        onMessage?.call(LiveMessage(type: LiveMessageType.chat, userName: nick, message: msg, color: LiveMessageColor.white));
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  String _uuid() {
    final r = Random();
    String part(int len) => List.generate(len, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${part(8)}-${part(4)}-${part(4)}-${part(4)}-${part(12)}';
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    markDisconnected();
    webScoketUtils?.close();
  }
}

class _BufferParser {
  final Uint8List buffer;
  int offset = 0;

  _BufferParser(this.buffer);

  int getUI32() {
    final value = ByteData.view(buffer.buffer).getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  int getUI16() {
    final value = ByteData.view(buffer.buffer).getUint16(offset, Endian.little);
    offset += 2;
    return value;
  }

  String getUTF8() {
    final len = getUI16();
    final subBuffer = buffer.sublist(offset, offset + len);
    offset += len;
    return utf8.decode(subBuffer, allowMalformed: true);
  }
}
