import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/site_helper.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_play_quality.dart';

class StripChatSite extends LiveSite {
  @override
  String id = Sites.stripchatSite;

  @override
  String name = 'StripChat';

  static const String baseUrl = 'https://www.stripchat.com';
  static const String apiBase = 'https://zh.stripchat.com';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  Map<String, String> get headers => {
    'Accept': '*/*',
    'Origin': baseUrl,
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
  };

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    return [LiveCategory(id: 'girls', name: 'Girls', children: [])];
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    return getRecommendRooms(page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final offset = (page - 1) * pageSize;
    final result = decodeJson(await HttpClient.instance.getJson(
      '$apiBase/api/front/models',
      queryParameters: {
        'removeShows': 'false',
        'recInFeatured': 'false',
        'limit': pageSize,
        'offset': offset,
        'primaryTag': 'girls',
        'filterGroupTags': '[["tagLanguageChinese"]]',
        'sortBy': 'stripRanking',
        'parentTag': 'tagLanguageChinese',
        'nic': 'true',
        'byw': 'false',
        'rcmGrp': 'A',
      },
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['models'] ?? []) {
      items.add(_parseRoom(item));
    }
    return items;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    final detail = LiveRoom(roomId: roomId, platform: platform);
    try {
      final result = decodeJson(await HttpClient.instance.getJson(
        '$apiBase/api/front/v2/models/username/$roomId/cam',
        header: headers,
      ));
      final jsonObj = result['user']?['user'];
      if (jsonObj is! Map) return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
      final room = _parseRoom(jsonObj);
      room.data = result;
      return room;
    } catch (_) {
      return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final userId = detail.userId ?? '';
    if (userId.isEmpty) return [];
    final url = 'https://edge-hls.growcdnssedge.com/hls/$userId/master/${userId}_auto.m3u8';
    try {
      final content = await HttpClient.instance.getText(url, header: headers);
      final qualities = parseM3u8Qualities(content, url, otherInfoPattern: RegExp('NAME="([a-zA-Z0-9]+)"'));
      if (qualities.isNotEmpty) {
        final firstUrls = qualityUrls(qualities.first);
        if (firstUrls.isNotEmpty) {
          final firstUrl = firstUrls.first;
          final replacement = firstUrl.replaceFirst(RegExp(r'_\d+p\.m3u8'), '.m3u8');
          if (replacement != firstUrl) {
            qualities.add(LivePlayQuality(quality: '720P', sort: 4000, data: [replacement]));
          }
        }
      }
      return qualities;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return qualityUrls(quality);
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final offset = (page - 1) * pageSize;
    final result = decodeJson(await HttpClient.instance.getJson(
      '$apiBase/api/front/v5/models/search/group/all',
      queryParameters: {
        'query': keyword,
        'limit': pageSize,
        'offset': offset,
        'primaryTag': 'girls',
        'includeCvSearchResults': 'false',
        'rcmGrp': 'A',
        'oRcmGrp': 'A',
      },
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['groups']?['username']?['models'] ?? []) {
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

  LiveRoom _parseRoom(Map jsonObj) {
    var isLive = jsonObj['isLive'] == true;
    if (isLive) isLive = jsonObj['status'] == 'public';
    final userId = jsonObj['id']?.toString() ?? '';
    final snapshot = jsonObj['snapshotTimestamp'];
    final cover = snapshot == null ? '' : 'https://img.doppiocdn.org/thumbs/$snapshot/$userId';
    return LiveRoom(
      roomId: jsonObj['username']?.toString() ?? '',
      userId: userId,
      nick: jsonObj['username']?.toString() ?? '',
      title: (jsonObj['offlineStatus'] ?? jsonObj['groupShowTopic'] ?? jsonObj['topic'] ?? '').toString(),
      watching: (jsonObj['favoritedCount'] ?? jsonObj['viewersCount'] ?? '0').toString(),
      cover: cover.replaceFirst('https://', 'https://i2.wp.com/'),
      avatar: (jsonObj['previewUrlThumbSmall'] ?? '').toString().replaceFirst('https://', 'https://i2.wp.com/'),
      status: isLive,
      liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
      platform: id,
    );
  }
}
