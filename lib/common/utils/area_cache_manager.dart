import 'dart:convert';

import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/model/live_category.dart';

class AreaCacheManager {
  static const String _indexKey = 'area_cache_sites';
  static const String _keyPrefix = 'area_cache_';

  static String _siteKey(String siteId) => '$_keyPrefix$siteId';

  static Future<void> saveSiteCategories(String siteId, List<LiveCategory> categories) async {
    final data = {
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'categories': categories.map(_categoryToJson).toList(),
    };
    await HivePrefUtil.setString(_siteKey(siteId), jsonEncode(data));
    final sites = _cachedSiteIds();
    if (!sites.contains(siteId)) {
      sites.add(siteId);
      await HivePrefUtil.setStringList(_indexKey, sites);
    }
  }

  static List<LiveCategory> getSiteCategories(String siteId) {
    final raw = HivePrefUtil.getString(_siteKey(siteId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map<String, dynamic> ? decoded['categories'] : null;
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => _categoryFromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearSite(String siteId) async {
    await HivePrefUtil.remove(_siteKey(siteId));
    final sites = _cachedSiteIds()..remove(siteId);
    await HivePrefUtil.setStringList(_indexKey, sites);
  }

  static Future<void> clearAll() async {
    final sites = _cachedSiteIds();
    for (final siteId in sites) {
      await HivePrefUtil.remove(_siteKey(siteId));
    }
    await HivePrefUtil.setStringList(_indexKey, []);
  }

  static int siteBytes(String siteId) {
    final raw = HivePrefUtil.getString(_siteKey(siteId));
    if (raw == null || raw.isEmpty) return 0;
    return utf8.encode(raw).length;
  }

  static int totalBytes() {
    return _cachedSiteIds().fold<int>(0, (total, siteId) => total + siteBytes(siteId));
  }

  static Map<String, int> siteBytesMap(Iterable<String> siteIds) {
    return {for (final siteId in siteIds) siteId: siteBytes(siteId)};
  }

  static List<String> _cachedSiteIds() {
    return List<String>.from(HivePrefUtil.getStringList(_indexKey) ?? const []);
  }

  static Map<String, dynamic> _categoryToJson(LiveCategory item) {
    return {
      'id': item.id,
      'name': item.name,
      'children': item.children.map((e) => e.toJson()).toList(),
    };
  }

  static LiveCategory _categoryFromJson(Map<String, dynamic> json) {
    final children = json['children'];
    return LiveCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      children: children is List
          ? children.whereType<Map>().map((e) => LiveArea.fromJson(Map<String, dynamic>.from(e))).toList()
          : <LiveArea>[],
    );
  }
}
