import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/danmaku/pandatv_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/site_helper.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/site/pandatv_site_mixin.dart';

class PandaTvSite extends LiveSite with PandaTvSiteMixin {
  @override
  String id = Sites.pandatvSite;

  @override
  String name = 'PandaTV';

  static const String baseUrl = 'https://www.pandalive.co.kr';
  static const String apiUrl = 'https://api.pandalive.co.kr';

  @override
  LiveDanmaku getDanmaku() => PandaTvDanmaku();

  String get _cookie => userCookie.value.isNotEmpty ? userCookie.value : SettingsService.to.cookieManager.getCookie(id);

  Map<String, String> get headers => {
    'Accept': '*/*',
    'Origin': baseUrl,
    'Referer': '$baseUrl/',
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
    return [LiveCategory(id: 'recommend', name: '推荐', children: [])];
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    return getRecommendRooms(page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final offset = (page - 1) * pageSize;
    final result = decodeJson(await HttpClient.instance.postJson(
      '$apiUrl/v1/live',
      formUrlEncoded: true,
      data: {'orderBy': 'user', 'onlyNewBj': 'N', 'limit': pageSize, 'offset': offset},
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['list'] ?? []) {
      items.add(_parseRoom(item));
    }
    return items;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    final detail = LiveRoom(roomId: roomId, platform: platform);
    try {
      final result = decodeJson(await HttpClient.instance.postJson(
        '$apiUrl/v1/live/play',
        formUrlEncoded: true,
        data: {'userId': roomId, 'action': 'watch'},
        header: headers,
      ));
      if (result['result'] != true) return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
      final media = result['media'] ?? {};
      final room = _parseRoom(media);
      room.data = result;
      room.danmakuData = PandaTvDanmakuArgs(
        roomId: roomId,
        userId: media['userIdx']?.toString() ?? '',
        token: result['token']?.toString() ?? '',
      );
      return room;
    } catch (_) {
      return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final data = detail.data is Map ? detail.data as Map : {};
    final media = data['media'] is Map ? data['media'] as Map : {};
    final playList = media['PlayList'] is Map ? media['PlayList'] as Map : {};
    final qualities = <LivePlayQuality>[];

    for (final key in playList.keys) {
      final list = playList[key];
      if (list is! List) continue;
      for (final item in list) {
        final url = item is Map ? item['url']?.toString() : null;
        if (url == null || url.isEmpty) continue;
        try {
          final content = await HttpClient.instance.getText(url, header: headers);
          qualities.addAll(parseM3u8Qualities(content, url, otherInfoPattern: RegExp('VIDEO="([a-zA-Z0-9]+)"')));
        } catch (_) {}
      }
    }
    return _mergeQualities(qualities);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return qualityUrls(quality);
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    return [];
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

  LiveRoom _parseRoom(Map jsonObj) {
    final isLive = jsonObj['isLive'] == true;
    final roomId = jsonObj['userId']?.toString() ?? '';
    return LiveRoom(
      roomId: roomId,
      userId: jsonObj['userIdx']?.toString() ?? '',
      nick: jsonObj['userNick']?.toString() ?? '',
      title: jsonObj['title']?.toString() ?? '',
      watching: jsonObj['playCnt']?.toString() ?? '0',
      cover: appendTimestamp(jsonObj['thumbUrl']?.toString() ?? ''),
      avatar: jsonObj['userImg']?.toString() ?? '',
      area: jsonObj['category']?.toString() ?? '',
      status: isLive,
      liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
      platform: id,
      data: {'media': jsonObj},
    );
  }

  List<LivePlayQuality> _mergeQualities(List<LivePlayQuality> list) {
    final map = <int, LivePlayQuality>{};
    for (final item in list) {
      final urls = qualityUrls(item);
      final existing = map[item.sort];
      if (existing == null) {
        map[item.sort] = LivePlayQuality(quality: item.quality, sort: item.sort, data: urls);
      } else {
        (existing.data as List<String>).addAll(urls);
      }
    }
    final result = map.values.toList()..sort((a, b) => b.sort.compareTo(a.sort));
    return result;
  }
}
