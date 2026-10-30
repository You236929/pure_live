import 'dart:convert';

import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

class StripChatSite extends LiveSite implements LiveSiteExternalRoomResolver {
  @override
  String id = PlatformIds.stripchat;

  @override
  String name = 'StripChat';

  static const String baseUrl = 'https://www.stripchat.com';
  static const String apiBase = 'https://zh.stripchat.com';

  Map<String, String> get _headers => {
        'Accept': '*/*',
        'Origin': baseUrl,
        'Referer': '$baseUrl/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        if (CookieSettingsController.to.stripchatCookie.value.isNotEmpty)
          'Cookie': CookieSettingsController.to.stripchatCookie.value,
      };

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    return RoomExternalTarget(web: 'https://zh.stripchat.com/$id');
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    return [
      LiveCategory(
        id: id,
        name: name,
        children: [],
      ),
    ];
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    return getRecommendRooms(page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final offset = (page - 1) * pageSize;
    try {
      final result = await HttpClient.instance.getJson(
        '$apiBase/api/front/models',
        queryParameters: {
          'removeShows': 'false',
          'recInFeatured': 'false',
          'limit': pageSize.toString(),
          'offset': offset.toString(),
          'primaryTag': 'girls',
          'filterGroupTags': '[["tagLanguageChinese"]]',
          'sortBy': 'stripRanking',
          'parentTag': 'tagLanguageChinese',
          'nic': 'true',
          'byw': 'false',
          'rcmGrp': 'A',
          'rbCnGr': 'true',
          'iem': 'true',
          'mvPrm': 'false',
          'decMb': 'false',
          'ctryTop': 'false',
        },
        header: _headers,
      );
      final items = <LiveRoom>[];
      for (final item in (result['models'] as List?) ?? []) {
        items.add(_parseRoom(item as Map));
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    final roomId = liveroom.roomId;
    if (roomId == null || roomId.isEmpty) return liveroom;
    try {
      final result = await HttpClient.instance.getJson(
        '$apiBase/api/front/v2/models/username/$roomId/cam',
        header: _headers,
      );
      final jsonObj = result['user']?['user'];
      if (jsonObj is! Map) return liveroom.copyWith(status: false, liveStatus: LiveStatus.offline);
      final room = _parseRoom(jsonObj);
      room.data = result;
      return room;
    } catch (_) {
      return liveroom.copyWith(status: false, liveStatus: LiveStatus.offline);
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    final userId = liveroom.userId ?? '';
    if (userId.isEmpty) return [];
    final url = 'https://edge-hls.growcdnssedge.com/hls/$userId/master/${userId}_auto.m3u8';
    try {
      final content = await HttpClient.instance.getText(url, header: _headers);
      final qualities = _parseM3u8Qualities(content, url);
      if (qualities.isNotEmpty) {
        final firstUrls = _qualityUrls(qualities.first);
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
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    return _qualityUrls(quality);
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final offset = (page - 1) * pageSize;
    try {
      final result = await HttpClient.instance.getJson(
        '$apiBase/api/front/v5/models/search/group/all',
        queryParameters: {
          'query': keyword,
          'limit': pageSize.toString(),
          'offset': offset.toString(),
          'primaryTag': 'girls',
          'includeCvSearchResults': 'false',
          'rcmGrp': 'A',
          'oRcmGrp': 'A',
        },
        header: _headers,
      );
      final items = <LiveRoom>[];
      final groups = result['groups'] as Map?;
      final usernames = groups?['username'] as Map?;
      for (final item in (usernames?['models'] as List?) ?? []) {
        items.add(_parseRoom(item as Map));
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async => [];

  LiveRoom _parseRoom(Map<String, dynamic> jsonObj) {
    var isLive = jsonObj['isLive'] == true;
    if (isLive) isLive = jsonObj['status'] == 'public';
    final userId = jsonObj['id']?.toString() ?? '';
    final snapshot = jsonObj['snapshotTimestamp'];
    final cover = snapshot == null
        ? ''
        : 'https://img.doppiocdn.org/thumbs/$snapshot/$userId';
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

  List<LivePlayQuality> _parseM3u8Qualities(String content, String baseUrl) {
    final lines = const LineSplitter().convert(content);
    final qualities = <LivePlayQuality>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

      String? urlLine;
      for (var j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (next.isEmpty) continue;
        if (!next.startsWith('#')) {
          urlLine = next;
          break;
        }
      }
      if (urlLine == null) continue;

      final resolutionMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
      final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
      final resolution = int.tryParse(resolutionMatch?.group(1) ?? '') ?? 0;
      final bandwidth = int.tryParse(bandwidthMatch?.group(1) ?? '') ?? 0;
      final bitRate = resolution > 0 ? _resolutionToBitrate(resolution) : (bandwidth / 1000).round();
      final qualityName = resolution > 0 ? _resolutionToQualityName(resolution) : '${bitRate}K';
      final playUrl = Uri.parse(baseUrl).resolve(urlLine).toString();

      final existing = qualities.firstWhere(
        (item) => item.sort == bitRate,
        orElse: () => LivePlayQuality(quality: qualityName, sort: bitRate, data: <String>[]),
      );
      if (!(existing.data as List<String>).contains(playUrl)) {
        (existing.data as List<String>).add(playUrl);
      }
    }

    if (qualities.isEmpty && content.contains('#EXTM3U')) {
      qualities.add(LivePlayQuality(quality: '原画', sort: 99999, data: [baseUrl]));
    }

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  List<String> _qualityUrls(LivePlayQuality quality) {
    final data = quality.data;
    if (data is List) {
      return data.map((e) => e.toString().split('#').first).where((e) => e.isNotEmpty).toList();
    }
    final value = data?.toString() ?? '';
    return value.isEmpty ? <String>[] : <String>[value];
  }

  int _resolutionToBitrate(int resolution) {
    if (resolution >= 2160) return 20000;
    if (resolution >= 1440) return 10000;
    if (resolution >= 1080) return 8000;
    if (resolution >= 720) return 4000;
    if (resolution >= 480) return 1000;
    if (resolution >= 360) return 250;
    return 250;
  }

  String _resolutionToQualityName(int resolution) {
    if (resolution >= 2160) return '4K';
    if (resolution >= 1440) return '2K';
    if (resolution >= 1080) return '1080P';
    if (resolution >= 720) return '720P';
    if (resolution >= 480) return '480P';
    if (resolution >= 360) return '360P';
    return '流畅';
  }
}
