import 'dart:convert';
import 'dart:math';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/site_helper.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_play_quality.dart';

class TwitchSite implements LiveSite {
  @override
  String id = Sites.twitchSite;

  @override
  String name = 'Twitch';

  static const String gqlApiUrl = 'https://gql.twitch.tv/gql';
  static const String defaultUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';

  final Map<String, String> _cursorMap = {};

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  Map<String, String> get headers => {
    'user-agent': defaultUa,
    'accept': 'application/vnd.twitchtv.v5+json',
    'client-id': 'kimne78kx3ncx6brgo4mv6wki5h1ko',
    'device-id': (1000000000000000 + Random().nextInt(1 << 32)).toString(),
  };

  String _persisted(String operationName, String sha256Hash, Map<String, dynamic> variables) {
    return jsonEncode({
      'operationName': operationName,
      'extensions': {
        'persistedQuery': {'version': 1, 'sha256Hash': sha256Hash},
      },
      'variables': variables,
    });
  }

  Future<dynamic> _gql(dynamic payload) async {
    return decodeJson(await HttpClient.instance.postJson(gqlApiUrl, header: headers, data: payload is String ? payload : jsonEncode(payload)));
  }

  String _cursorKey(String type, String id, int page) => '${type}_${id}_$page';
  String _cursor(String type, String id, int page) => _cursorMap[_cursorKey(type, id, page)] ?? '';
  void _saveCursor(String type, String id, int page, String value) => _cursorMap[_cursorKey(type, id, page + 1)] = value;

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    try {
      final response = await _gql(_persisted(
        'SearchCategoryTags',
        'b4cb189d8d17aadf29c61e9d7c7e7dcfc932e93b77b3209af5661bffb484195f',
        {'userQuery': '', 'limit': pageSize},
      ));
      final categories = <LiveCategory>[];
      for (final item in response['data']?['searchCategoryTags'] ?? []) {
        categories.add(LiveCategory(
          id: item['id']?.toString() ?? '',
          name: item['tagName']?.toString() ?? '',
          children: [LiveArea(platform: id, areaType: item['id']?.toString() ?? '', areaName: item['tagName']?.toString() ?? '', shortName: item['id']?.toString() ?? '')],
        ));
      }
      return categories;
    } catch (_) {
      return [LiveCategory(id: 'just-chatting', name: 'Just Chatting', children: [LiveArea(platform: id, areaName: 'Just Chatting', shortName: 'just-chatting')])];
    }
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final cursorType = 'getCategoryRooms';
    final slug = category.shortName?.isNotEmpty == true ? category.shortName! : (category.areaName ?? 'just-chatting').toLowerCase().replaceAll(' ', '-');
    final cursor = _cursor(cursorType, slug, page);
    if (cursor.isEmpty && page > 1) return [];

    final payload = [
      {
        'operationName': 'DirectoryPage_Game',
        'variables': {
          'imageWidth': 50,
          'slug': slug,
          'options': {
            'sort': 'VIEWER_COUNT',
            'recommendationsContext': {'platform': 'web'},
            'requestID': 'JIRA-VXP-2397',
            'freeformTags': null,
            'tags': [],
            'broadcasterLanguages': ['ZH', 'KO'],
            'systemFilters': [],
          },
          'sortTypeIsRecency': false,
          'limit': pageSize,
          'includeCostreaming': true,
          if (cursor.isNotEmpty) 'cursor': cursor,
        },
        'extensions': {
          'persistedQuery': {'version': 1, 'sha256Hash': '76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f'},
        },
      }
    ];
    final response = await _gql(payload);
    final streams = response[0]?['data']?['game']?['streams'] ?? {};
    final edges = streams['edges'] ?? [];
    final hasNext = streams['pageInfo']?['hasNextPage'] == true;
    final nextCursor = edges is List && edges.isNotEmpty && hasNext ? edges.last['cursor']?.toString() ?? '' : '';
    _saveCursor(cursorType, slug, page, nextCursor);
    final rooms = <LiveRoom>[];
    for (final item in edges) {
      rooms.add(_parseStream(item['node']));
    }
    return rooms;
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    return getCategoryRooms(LiveArea(platform: id, shortName: 'just-chatting', areaName: 'Just Chatting'), page: page, pageSize: pageSize);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    final detail = LiveRoom(roomId: roomId, platform: platform);
    try {
      final payload = [
        jsonDecode(_persisted('ChannelShell', 'fea4573a7bf2644f5b3f2cbbdcbee0d17312e48d2e55f080589d053aad353f11', {'login': roomId})),
        jsonDecode(_persisted('StreamMetadata', 'b57f9b910f8cd1a4659d894fe7550ccc81ec9052c01e438b290fd66a040b9b93', {'channelLogin': roomId, 'includeIsDJ': true})),
        jsonDecode(_persisted('VideoPreviewOverlay', '9515480dee68a77e667cb19de634739d33f243572b007e98e67184b1a5d8369f', {'login': roomId})),
        jsonDecode(_playbackAccessTokenRequest(roomId)),
      ];
      final response = await _gql(payload) as List;
      final userOrError = response[0]['data']?['userOrError'];
      final user = response[1]['data']?['user'];
      final previewUser = response[2]['data']?['user'];
      if (userOrError == null || user == null) return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
      final stream = user['stream'];
      final online = stream != null && stream['streamType'] == 'live';
      final preview = previewUser?['stream']?['previewImageURL'] ?? userOrError['bannerImageURL'] ?? '';
      final room = LiveRoom(
        roomId: userOrError['login']?.toString() ?? roomId,
        title: user['lastBroadcast']?['title']?.toString() ?? '',
        cover: appendTimestamp(preview.toString().replaceFirst('https://', 'https://i2.wp.com/')),
        nick: userOrError['displayName']?.toString() ?? roomId,
        avatar: (user['profileImageURL'] ?? '').toString().replaceFirst('https://', 'https://i2.wp.com/'),
        watching: (userOrError['stream']?['viewersCount'] ?? stream?['viewersCount'] ?? 0).toString(),
        status: online,
        danmakuData: roomId,
        platform: id,
        liveStatus: online ? LiveStatus.live : LiveStatus.offline,
        area: stream?['game']?['displayName']?.toString() ?? stream?['game']?['name']?.toString() ?? '',
        data: [response[3]],
      );
      return room;
    } catch (_) {
      return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final data = detail.data;
    if (data is! List || data.isEmpty || detail.status != true) return [];
    final token = data[0]['data']?['streamPlaybackAccessToken']?['value'];
    final sign = data[0]['data']?['streamPlaybackAccessToken']?['signature'];
    if (token == null || sign == null) return [];
    final playSessionIds = ['bdd22331a986c7f1073628f2fc5b19da', '064bc3ff1722b6f53b0b5b8c01e46ca5'];
    final params = {
      'allow_source': 'true',
      'p': DateTime.timestamp().second.toString(),
      'platform': 'web',
      'play_session_id': playSessionIds[Random().nextInt(playSessionIds.length)],
      'player_backend': 'mediaplayer',
      'player_version': '1.28.0-rc.1',
      'playlist_include_framerate': 'true',
      'sig': sign,
      'token': token,
      'transcode_mode': 'cbr_v1',
    };
    final m3u8Url = 'https://usher.ttvnw.net/api/channel/hls/${detail.roomId}.m3u8';
    final content = await HttpClient.instance.getText(m3u8Url, queryParameters: params, header: headers);
    return parseM3u8Qualities(content, m3u8Url, otherInfoPattern: RegExp('VIDEO="([a-zA-Z0-9]+)"'));
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return qualityUrls(quality);
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final cursorType = 'searchRooms';
    final cursor = _cursor(cursorType, keyword, page);
    if (cursor.isEmpty && page > 1) return [];
    final response = await _gql(_persisted(
      'SearchResultsPage_SearchResults',
      '7f3580f6ac6cd8aa1424cff7c974a07143827d6fa36bba1b54318fe7f0b68dc5',
      {
        'platform': 'web',
        'query': keyword,
        'options': {'targets': null, 'shouldSkipDiscoveryControl': false},
        'requestID': '808c9f2e-f52e-431c-8dc7-d2e3c1831d77',
        'includeIsDJ': true,
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    ));
    final channels = response['data']?['searchFor']?['channels'] ?? {};
    _saveCursor(cursorType, keyword, page, channels['cursor']?.toString() ?? '');
    final rooms = <LiveRoom>[];
    for (final item in channels['edges'] ?? []) {
      final node = item['item'];
      final stream = node['stream'];
      rooms.add(LiveRoom(
        roomId: node['login']?.toString() ?? '',
        title: node['broadcastSettings']?['title']?.toString() ?? '',
        cover: appendTimestamp((stream?['previewImageURL'] ?? '').toString().replaceFirst('https://', 'https://i2.wp.com/')),
        nick: node['displayName']?.toString() ?? '',
        avatar: (node['profileImageURL'] ?? '').toString().replaceFirst('https://', 'https://i2.wp.com/'),
        watching: (stream?['viewersCount'] ?? 0).toString(),
        status: stream != null,
        platform: id,
        liveStatus: stream != null ? LiveStatus.live : LiveStatus.offline,
        area: stream?['game']?['displayName']?.toString() ?? '',
      ));
    }
    return rooms;
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

  String _playbackAccessTokenRequest(String roomId) {
    return _persisted('PlaybackAccessToken', 'ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9', {
      'isLive': true,
      'login': roomId,
      'isVod': false,
      'vodID': '',
      'playerType': 'site',
      'isClip': false,
      'clipID': '',
      'platform': 'site',
    });
  }

  LiveRoom _parseStream(dynamic node) {
    return LiveRoom(
      roomId: node['broadcaster']?['login']?.toString() ?? '',
      title: node['title']?.toString() ?? '',
      cover: appendTimestamp((node['previewImageURL'] ?? '').toString().replaceFirst('https://', 'https://i2.wp.com/')),
      nick: node['broadcaster']?['displayName']?.toString() ?? '',
      avatar: (node['broadcaster']?['profileImageURL'] ?? '').toString().replaceFirst('https://', 'https://i2.wp.com/'),
      watching: (node['viewersCount'] ?? 0).toString(),
      status: true,
      platform: id,
      liveStatus: LiveStatus.live,
      area: node['game']?['displayName']?.toString() ?? '',
    );
  }
}
