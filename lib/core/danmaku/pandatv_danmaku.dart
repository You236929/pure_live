import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class PandaTvDanmakuArgs {
  final String roomId;
  final String userId;
  final String token;

  PandaTvDanmakuArgs({required this.roomId, required this.userId, required this.token});
}

class PandaTvDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 60 * 1000;

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
  int _sendId = 1;

  static final _msgRegex = RegExp(r'"message":"(.+?)"');
  static final _senderRegex = RegExp(r'"nk":"(.+?)"');

  @override
  Future start(dynamic args) async {
    if (args is! PandaTvDanmakuArgs || args.token.isEmpty || args.userId.isEmpty) {
      onClose?.call('弹幕参数无效');
      return;
    }
    webScoketUtils = WebScoketUtils(
      url: 'wss://chat-ws.neolive.kr/connection/websocket',
      heartBeatTime: heartbeatTime,
      headers: {'Origin': 'https://www.pandalive.co.kr'},
      onMessage: decodeMessage,
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

  Future<void> joinRoom(PandaTvDanmakuArgs args) async {
    webScoketUtils?.sendMessage(jsonEncode({
      'id': _sendId++,
      'params': {'token': args.token, 'name': 'js'},
    }));
    await Future.delayed(const Duration(milliseconds: 100));
    webScoketUtils?.sendMessage(jsonEncode({
      'method': 1,
      'params': {'channel': args.userId},
      'id': _sendId++,
    }));
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(jsonEncode({'method': '7', 'id': '${_sendId++}'}));
  }

  void decodeMessage(dynamic data) {
    try {
      final msg = data is Uint8List ? utf8.decode(data) : data.toString();
      if (!msg.contains('"type":"chatter"') && !msg.contains('"type":"manager"')) return;
      final msgMatch = _msgRegex.firstMatch(msg);
      if (msgMatch == null) return;
      final sender = _senderRegex.firstMatch(msg)?.group(1) ?? '';
      final message = msgMatch.group(1)!.replaceAll(r'\n', '\n');
      onMessage?.call(LiveMessage(type: LiveMessageType.chat, userName: sender, message: message, color: LiveMessageColor.white));
    } catch (e) {
      CoreLog.error(e);
    }
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    markDisconnected();
    webScoketUtils?.close();
  }
}
