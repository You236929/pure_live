import 'dart:collection';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/danmaku/yy_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/site_helper.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/site/yy_site_mixin.dart';

class YYSite extends LiveSite with YYSiteMixin {
  @override
  String id = Sites.yySite;

  @override
  String name = 'YY';

  @override
  LiveDanmaku getDanmaku() => YyDanmaku();

  String get _cookie => userCookie.value.isNotEmpty ? userCookie.value : SettingsService.to.cookieManager.getCookie(id);

  Map<String, String> get headers => {
    'Accept': '*/*',
    'Origin': 'https://www.yy.com',
    'Referer': 'https://www.yy.com/',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-site',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    if (_cookie.isNotEmpty) 'Cookie': _cookie,
  };

  @override
  Map<String, String> getVideoHeaders() => headers;

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://www.yy.com/yyweb/module/data/header',
      header: headers,
    ));
    final categories = <LiveCategory>[];
    for (final item in result['categoryTabs'] ?? []) {
      categories.add(LiveCategory(id: item['id']?.toString() ?? '', name: item['title']?.toString() ?? '', children: []));
    }
    if (categories.isEmpty) {
      categories.add(LiveCategory(id: 'recommend', name: '推荐', children: []));
    }
    return categories;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      'biz': 'other',
      'subBiz': 'idx',
      'moduleId': category.areaId?.isNotEmpty == true ? category.areaId : '-1',
    };
    return _roomsFromMorePage(params);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    return _roomsFromMorePage({'page': page, 'pageSize': pageSize, 'biz': 'other', 'subBiz': 'idx', 'moduleId': '-1'});
  }

  Future<List<LiveRoom>> _roomsFromMorePage(Map<String, dynamic> params) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://www.yy.com/more/page.action',
      queryParameters: params,
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['data']?['data'] ?? []) {
      items.add(_parseRoom(item));
    }
    return items;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    final detail = LiveRoom(roomId: roomId, platform: platform);
    try {
      var sid = roomId;
      var uid = '';
      final page = await HttpClient.instance.getText('https://www.yy.com/$roomId', header: headers);
      uid = RegExp(r'sid : "(.*?)",\n\s+ssid', multiLine: true).firstMatch(page)?.group(1) ?? '';
      final result = decodeJson(await HttpClient.instance.getJson(
        'https://www.yy.com/api/liveInfoDetail/$sid/$sid/$uid',
        header: headers,
      ));
      if (result['resultCode'] != 0) return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
      return _parseRoom(result['data'] ?? {});
    } catch (_) {
      return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final jsonObj = await _liveStreamObj(detail: detail, qn: '1');
    final channelStreamInfo = jsonObj['channel_stream_info'] as Map<String, dynamic>?;
    final streams = channelStreamInfo?['streams'];
    final qualityMap = HashMap<String, LivePlayQuality>();
    if (streams is List) {
      for (final stream in streams) {
        final jsonStr = stream['json']?.toString() ?? '';
        if (jsonStr.isEmpty) continue;
        final info = decodeJson(jsonStr);
        final gearInfo = info['gear_info'];
        if (gearInfo is! Map) continue;
        final desc = gearInfo['name']?.toString() ?? '';
        final qn = gearInfo['gear']?.toString() ?? '';
        final rate = info['rate'] is int ? info['rate'] as int : 0;
        if (desc.isNotEmpty && qn.isNotEmpty) {
          qualityMap.putIfAbsent(desc, () => LivePlayQuality(quality: desc, sort: rate, data: qn));
        }
      }
    }
    final qualities = qualityMap.values.toList()..sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final qn = quality.data?.toString() ?? '1';
    final liveData = await _liveStreamObj(detail: detail, qn: qn);
    final streamLineAddr = liveData['avp_info_res']?['stream_line_addr'];
    if (streamLineAddr is! Map || streamLineAddr.isEmpty) return [];
    final first = streamLineAddr.values.first;
    final url = first['cdn_info']?['url']?.toString() ?? '';
    return url.isEmpty ? [] : [url];
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://www.yy.com/apiSearch/doSearch.json',
      queryParameters: {'q': keyword, 't': '120', 'n': page},
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['data']?['searchResult']?['response']?['120']?['docs'] ?? []) {
      items.add(_parseRoom(item));
    }
    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async => [];

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final detail = await getRoomDetail(roomId: roomId, platform: platform);
    return detail.liveStatus == LiveStatus.live;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async => [];

  Future<dynamic> _liveStreamObj({required LiveRoom detail, required String qn}) async {
    return decodeJson(await HttpClient.instance.postJson(
      'https://stream-manager.yy.com/v3/channel/streams',
      queryParameters: {'uid': '0', 'cid': detail.roomId, 'sid': detail.roomId, 'appid': '0', 'sequence': '1755858374681', 'encode': 'json'},
      data: {
        'head': {
          'seq': 1755858374681,
          'appidstr': '0',
          'bidstr': '123',
          'cidstr': detail.roomId,
          'sidstr': detail.roomId,
          'uid64': 0,
          'client_type': 108,
          'client_ver': '5.19.4',
          'stream_sys_ver': 1,
          'app': 'yylive_web',
          'playersdk_ver': '5.19.4',
          'thundersdk_ver': '0',
          'streamsdk_ver': '5.19.4',
        },
        'client_attribute': {
          'client': 'web',
          'model': 'web0',
          'cpu': '',
          'graphics_card': '',
          'os': 'chrome',
          'osversion': '128.0.0.0',
          'vsdk_version': '',
          'app_identify': '',
          'app_version': '',
          'business': '',
          'width': '1366',
          'height': '768',
          'scale': '',
          'client_type': 8,
          'h265': 0,
        },
        'avp_parameter': {
          'version': 1,
          'client_type': 8,
          'service_type': 0,
          'imsi': 0,
          'send_time': 1755858374,
          'line_seq': -1,
          'gear': int.tryParse(qn) ?? 1,
          'ssl': 1,
          'stream_format': 0,
        },
      },
      header: headers,
    ));
  }

  LiveRoom _parseRoom(dynamic item) {
    return LiveRoom(
      roomId: item['sid']?.toString() ?? '',
      title: (item['desc'] ?? item['channelName'] ?? '').toString(),
      cover: validImageUrl(item['thumb2'] ?? item['posterurl'] ?? ''),
      nick: item['name']?.toString() ?? '',
      userId: item['uid']?.toString() ?? '',
      watching: item['users']?.toString() ?? '0',
      avatar: validImageUrl(item['avatar'] ?? item['headurl'] ?? ''),
      area: item['biz']?.toString() ?? '',
      liveStatus: LiveStatus.live,
      status: true,
      platform: id,
      danmakuData: YyDanmakuArgs(
        topSid: int.tryParse(item['sid']?.toString() ?? '') ?? 0,
        subSid: int.tryParse(item['ssid']?.toString() ?? '') ?? 0,
      ),
    );
  }
}
