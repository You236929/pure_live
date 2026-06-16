import 'dart:async';
import 'dart:convert';

import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class SoopDanmakuArgs {
  final String url;
  final String chatNo;

  SoopDanmakuArgs({required this.url, required this.chatNo});
}

class SoopDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 20 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  final String f = '\x0c';
  final String esc = '\x1b\x09';
  WebScoketUtils? webScoketUtils;
  late SoopDanmakuArgs danmakuArgs;

  @override
  Future start(dynamic args) async {
    if (args is! SoopDanmakuArgs || args.url.isEmpty || args.chatNo.isEmpty) {
      onClose?.call('弹幕参数无效');
      return;
    }
    danmakuArgs = args;
    webScoketUtils = WebScoketUtils(
      url: danmakuArgs.url,
      heartBeatTime: heartbeatTime,
      protocols: ['chat'],
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Origin': 'https://play.sooplive.co.kr',
      },
      onMessage: (e) {
        if (e is List<int>) decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        markConnected();
        joinRoom();
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

  Future<void> joinRoom() async {
    webScoketUtils?.sendMessage('${esc}000100000600${f * 3}16$f');
    await Future.delayed(const Duration(milliseconds: 200));
    final size = (utf8.encode(danmakuArgs.chatNo).length + 6).toString().padLeft(6, '0');
    webScoketUtils?.sendMessage('${esc}0002${size}00$f${danmakuArgs.chatNo}${f * 5}');
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage('${esc}000000000100$f');
  }

  void decodeMessage(List<int> data) {
    try {
      final messages = _split(data, 0x0c).map((part) => utf8.decode(part, allowMalformed: true)).toList();
      if (messages.length > 6 && !['-1', '1'].contains(messages[1]) && !messages[1].contains('|')) {
        onMessage?.call(LiveMessage(
          type: LiveMessageType.chat,
          userName: messages[6],
          message: messages[1],
          color: LiveMessageColor.white,
        ));
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  List<List<int>> _split(List<int> data, int separator) {
    final result = <List<int>>[];
    var start = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i] == separator) {
        result.add(data.sublist(start, i));
        start = i + 1;
      }
    }
    if (start <= data.length) result.add(data.sublist(start));
    return result;
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    markDisconnected();
    webScoketUtils?.close();
  }
}

extension _RepeatString on String {
  String operator *(int times) => List.filled(times, this).join();
}
