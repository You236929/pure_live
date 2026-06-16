import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class TwitchDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 60 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  WebScoketUtils? webScoketUtils;

  @override
  Future start(dynamic args) async {
    final roomId = args?.toString() ?? '';
    if (roomId.isEmpty) {
      onClose?.call('弹幕参数无效');
      return;
    }
    webScoketUtils = WebScoketUtils(
      url: 'wss://irc-ws.chat.twitch.tv',
      heartBeatTime: heartbeatTime,
      onMessage: (e) => decodeMessage(e is List<int> ? utf8.decode(e) : e.toString()),
      onReady: () {
        onReady?.call();
        markConnected();
        joinRoom(roomId);
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

  void joinRoom(String roomId) {
    final user = 'justinfan${1000 + Random().nextInt(99000)}';
    webScoketUtils
      ?..sendMessage('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership')
      ..sendMessage('PASS SCHMOOPIIE')
      ..sendMessage('NICK $user')
      ..sendMessage('USER $user 8 * :$user')
      ..sendMessage('JOIN #$roomId');
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage('PONG :tmi.twitch.tv');
  }

  void decodeMessage(String data) {
    try {
      if (data.startsWith('PING')) {
        webScoketUtils?.sendMessage(data.replaceFirst('PING', 'PONG'));
      }
      for (final line in data.split('\n')) {
        final content = RegExp(r'PRIVMSG [^:]+:(.+)').firstMatch(line)?.group(1);
        final name = RegExp(r'display-name=([^;]+);').firstMatch(line)?.group(1);
        final colorHex = RegExp(r'color=#([a-zA-Z0-9]{6});').firstMatch(line)?.group(1);
        if (content == null || name == null) continue;
        final color = colorHex == null || colorHex.isEmpty
            ? LiveMessageColor.white
            : LiveMessageColor.numberToColor(int.parse(colorHex, radix: 16));
        onMessage?.call(LiveMessage(type: LiveMessageType.chat, userName: name, message: content, color: color));
      }
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
