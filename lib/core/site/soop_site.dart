import 'dart:collection';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/danmaku/soop_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/site_helper.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/site/soop_site_mixin.dart';

class SoopSite extends LiveSite with SoopSiteMixin {
  @override
  String id = Sites.soopSite;

  @override
  String name = 'SOOP直播';

  @override
  LiveDanmaku getDanmaku() => SoopDanmaku();

  String get _cookie => userCookie.value.isNotEmpty ? userCookie.value : SettingsService.to.cookieManager.getCookie(id);

  Map<String, String> get headers => {
    'Accept': '*/*',
    'Origin': 'https://www.sooplive.co.kr',
    'Referer': 'https://www.sooplive.co.kr/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    if (_cookie.isNotEmpty) 'Cookie': _cookie,
  };

  @override
  Map<String, String> getVideoHeaders() => headers;

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final category = LiveCategory(id: '1', name: '热门', children: []);
    category.children.addAll(await _getSubCategories(category, 1, 120));
    return [category];
  }

  Future<List<LiveArea>> _getSubCategories(LiveCategory liveCategory, int page, int pageSize) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://sch.sooplive.co.kr/api.php',
      queryParameters: {
        'm': 'categoryList',
        'szKeyword': '',
        'szOrder': 'view_cnt',
        'nPageNo': page,
        'nListCnt': pageSize,
        'nOffset': '0',
        'szPlatform': 'pc',
      },
      header: headers,
    ));
    final subs = <LiveArea>[];
    for (final item in result['data']?['list'] ?? []) {
      subs.add(LiveArea(
        areaId: item['category_no']?.toString() ?? '',
        areaName: item['category_name']?.toString() ?? '',
        areaType: liveCategory.id,
        platform: id,
        areaPic: item['cate_img']?.toString() ?? '',
        typeName: liveCategory.name,
      ));
    }
    return subs;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://sch.sooplive.co.kr/api.php',
      queryParameters: {
        'm': 'categoryContentsList',
        'szType': 'live',
        'nPageNo': page,
        'nListCnt': pageSize,
        'szPlatform': 'pc',
        'szOrder': 'view_cnt_desc',
        'szCateNo': category.areaId,
      },
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['data']?['list'] ?? []) {
      items.add(_parseListRoom(item, area: category.areaName));
    }
    return items;
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://live.sooplive.co.kr/api/main_broad_list_api.php',
      queryParameters: {'selectType': 'action', 'selectValue': 'all', 'orderType': 'view_cnt', 'pageNo': page, 'lang': 'ko_KR'},
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['broad'] ?? []) {
      final roomId = item['user_id']?.toString() ?? '';
      items.add(LiveRoom(
        roomId: roomId,
        title: item['broad_title']?.toString() ?? '',
        cover: validImageUrl(item['broad_thumb']),
        nick: item['user_nick']?.toString() ?? '',
        watching: item['current_view_cnt']?.toString() ?? '0',
        avatar: _avatarUrl(roomId),
        area: item['category_name']?.toString() ?? '',
        liveStatus: LiveStatus.live,
        status: true,
        platform: id,
      ));
    }
    return items;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    final detail = LiveRoom(roomId: roomId, platform: platform);
    try {
      final danmakuArgsFuture = _getDanmakuArgs(roomId);
      final result = decodeJson(await HttpClient.instance.postJson(
        'http://api.m.sooplive.co.kr/broad/a/watch',
        formUrlEncoded: true,
        data: {
          'bj_id': roomId,
          'bid': roomId,
          'broad_no': '',
          'agent': 'web',
          'confirm_adult': 'true',
          'player_type': 'webm',
          'mode': 'live',
        },
        header: headers,
      ));
      if (result['result'] != 1) return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
      final jsonObj = result['data'] ?? {};
      final bno = jsonObj['broad_no']?.toString() ?? '';
      final categories = jsonObj['category_tags'];
      final area = categories is List && categories.isNotEmpty ? categories.first.toString() : '';
      final isLiving = jsonObj['viewpreset'] != null;
      return LiveRoom(
        cover: appendTimestamp(validImageUrl(jsonObj['thumbnail'])),
        watching: jsonObj['view_cnt']?.toString() ?? '0',
        roomId: jsonObj['bj_id']?.toString() ?? roomId,
        userId: bno,
        area: area,
        title: jsonObj['broad_title']?.toString() ?? '',
        nick: jsonObj['user_nick']?.toString() ?? '',
        avatar: validImageUrl(jsonObj['profile_thumbnail']),
        status: isLiving,
        liveStatus: isLiving ? LiveStatus.live : LiveStatus.offline,
        platform: id,
        link: jsonObj['share']?['url']?.toString() ?? '',
        data: {'viewpreset': jsonObj['viewpreset'] ?? []},
        danmakuData: await danmakuArgsFuture,
      );
    } catch (_) {
      return detail.copyWith(status: false, liveStatus: LiveStatus.offline);
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final data = detail.data is Map ? detail.data as Map : {};
    final qualityMap = HashMap<String, LivePlayQuality>();
    for (final item in data['viewpreset'] ?? []) {
      final key = item['name']?.toString() ?? '';
      if (key.isEmpty || key == 'auto') continue;
      qualityMap.putIfAbsent(key, () => LivePlayQuality(quality: key, sort: item['bps'] ?? 0, data: key));
    }
    final qualities = qualityMap.values.toList()..sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final cdnUrl = await _getCdnUrl(bno: detail.userId ?? '', quality: quality.quality);
    final aid = await _getStreamAid(roomId: detail.roomId ?? '', bno: detail.userId ?? '', quality: quality.quality);
    if (cdnUrl.isEmpty) return [];
    return ['${cdnUrl}${cdnUrl.contains('?') ? '&' : '?'}aid=$aid'];
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'https://sch.sooplive.co.kr/api.php',
      queryParameters: {
        'l': 'DF',
        'm': 'liveSearch',
        'c': 'UTF-8',
        'w': 'webk',
        'isMobile': '0',
        'onlyParent': '1',
        'szType': 'json',
        'szOrder': 'score',
        'szKeyword': keyword,
        'nPageNo': page,
        'nListCnt': pageSize,
        'tab': 'live',
        'location': 'total_search',
      },
      header: headers,
    ));
    final items = <LiveRoom>[];
    for (final item in result['REAL_BROAD'] ?? []) {
      items.add(_parseListRoom(item, area: item['standard_broad_cate_name']?.toString() ?? ''));
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

  LiveRoom _parseListRoom(dynamic item, {String? area}) {
    final roomId = item['user_id']?.toString() ?? '';
    return LiveRoom(
      roomId: roomId,
      title: (item['broad_title'] ?? '').toString(),
      cover: validImageUrl(item['thumbnail'] ?? item['broad_img'] ?? ''),
      nick: item['user_nick']?.toString() ?? '',
      watching: (item['view_cnt'] ?? item['current_view_cnt'] ?? '0').toString(),
      avatar: validImageUrl(item['user_profile_img'] ?? _avatarUrl(roomId)),
      area: area,
      liveStatus: LiveStatus.live,
      status: true,
      platform: id,
    );
  }

  Future<String> _getCdnUrl({required String bno, required String quality}) async {
    final result = decodeJson(await HttpClient.instance.getJson(
      'http://livestream-manager.sooplive.co.kr/broad_stream_assign.html',
      queryParameters: {
        'return_type': 'gcp_cdn',
        'use_cors': 'false',
        'cors_origin_url': 'play.sooplive.co.kr',
        'broad_key': '$bno-common-$quality-hls',
        'time': '8361.086329376785',
      },
      header: headers,
    ));
    return result['view_url']?.toString() ?? '';
  }

  Future<String> _getStreamAid({required String roomId, required String bno, required String quality}) async {
    final result = decodeJson(await HttpClient.instance.postJson(
      'https://live.sooplive.co.kr/afreeca/player_live_api.php',
      formUrlEncoded: true,
      queryParameters: {'bjid': roomId},
      data: {
        'bid': roomId,
        'bno': bno,
        'type': 'aid',
        'pwd': '',
        'player_type': 'html5',
        'stream_type': 'common',
        'quality': quality,
        'mode': 'landing',
        'from_api': '0',
        'is_revive': 'false',
      },
      header: headers,
    ));
    return result['CHANNEL']?['AID']?.toString() ?? '';
  }

  Future<SoopDanmakuArgs?> _getDanmakuArgs(String roomId) async {
    try {
      final result = decodeJson(await HttpClient.instance.postJson(
        'https://live.sooplive.co.kr/afreeca/player_live_api.php',
        formUrlEncoded: true,
        queryParameters: {'bjid': roomId},
        data: {
          'bid': roomId,
          'bno': '',
          'type': 'live',
          'pwd': '',
          'player_type': 'html5',
          'stream_type': 'common',
          'quality': 'HD',
          'mode': 'landing',
          'from_api': '0',
          'is_revive': 'false',
        },
        header: headers,
      ));
      final channel = result['CHANNEL'] ?? {};
      final chatNo = channel['CHATNO']?.toString() ?? '';
      final chatDomain = channel['CHDOMAIN']?.toString() ?? '';
      if (chatNo.isEmpty || chatDomain.isEmpty) return null;
      return SoopDanmakuArgs(url: 'wss://$chatDomain:9001/Websocket/$roomId', chatNo: chatNo);
    } catch (_) {
      return null;
    }
  }

  String _avatarUrl(String roomId) {
    if (roomId.length < 2) return '';
    final part = roomId.substring(0, 2);
    return 'https://stimg.sooplive.co.kr/LOGO/$part/$roomId/m/$roomId.webp';
  }
}
