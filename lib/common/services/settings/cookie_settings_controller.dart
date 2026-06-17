import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';

class CookieSettingsController extends GetxController {
  static const String bilibiliSiteKey = 'bilibili';
  static const String huyaSiteKey = 'huya';
  static const String douyinSiteKey = 'douyin';
  static const String kuaishouSiteKey = 'kuaishou';

  static const Map<String, String> _legacyCookieStorageKeys = {
    bilibiliSiteKey: 'bilibiliCookie',
    huyaSiteKey: 'huyaCookie',
    douyinSiteKey: 'douyinCookie',
    kuaishouSiteKey: 'kuaishouCookie',
  };

  final RxInt bilibiliUid = hiveInt('bilibiliUid', 0);

  late final Map<String, RxString> _siteCookies = {
    for (final entry in _legacyCookieStorageKeys.entries) entry.key: hiveString(entry.value, ''),
  };

  RxString get bilibiliCookie => getCookieRx(bilibiliSiteKey);

  RxString get huyaCookie => getCookieRx(huyaSiteKey);

  RxString get douyinCookie => getCookieRx(douyinSiteKey);

  RxString get kuaishouCookie => getCookieRx(kuaishouSiteKey);

  RxString getCookieRx(String siteKey) {
    final normalizedSiteKey = _normalizeSiteKey(siteKey);
    return _siteCookies.putIfAbsent(
      normalizedSiteKey,
      () => hiveString(_storageKeyForSite(normalizedSiteKey), ''),
    );
  }

  String getCookie(String siteKey) {
    return getCookieRx(siteKey).v;
  }

  void setCookie(String siteKey, String cookie) {
    getCookieRx(siteKey).v = cookie;
  }

  void clearCookie(String siteKey) {
    setCookie(siteKey, '');
  }

  bool hasCookie(String siteKey) {
    return getCookie(siteKey).isNotEmpty;
  }

  void clearAllCookies() {
    for (final cookie in _siteCookies.values) {
      cookie.v = '';
    }
  }

  Map<String, dynamic> toJson() {
    final siteCookies = {
      for (final entry in _siteCookies.entries) entry.key: entry.value.v,
    };
    return {
      'bilibiliCookie': bilibiliCookie.v,
      'huyaCookie': huyaCookie.v,
      'douyinCookie': douyinCookie.v,
      'kuaishouCookie': kuaishouCookie.v,
      'siteCookies': siteCookies,
      'bilibiliUid': bilibiliUid.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final siteCookies = _asStringMap(json['siteCookies']);

    setCookie(bilibiliSiteKey, json['bilibiliCookie'] ?? siteCookies[bilibiliSiteKey] ?? '');
    setCookie(huyaSiteKey, json['huyaCookie'] ?? siteCookies[huyaSiteKey] ?? '');
    setCookie(douyinSiteKey, json['douyinCookie'] ?? siteCookies[douyinSiteKey] ?? '');
    setCookie(kuaishouSiteKey, json['kuaishouCookie'] ?? siteCookies[kuaishouSiteKey] ?? '');

    for (final entry in siteCookies.entries) {
      if (!_legacyCookieStorageKeys.containsKey(entry.key)) {
        setCookie(entry.key, entry.value);
      }
    }

    bilibiliUid.v = json['bilibiliUid'] ?? 0;
    BiliBiliAccountService.instance.setCookie(bilibiliCookie.v);
    BiliBiliAccountService.instance.loadUserInfo();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final cookie = rootConfig?['cookie'] as Map<String, dynamic>? ?? {};
    final siteCookies = _asStringMap(cookie['siteCookies']);
    return {
      'bilibiliCookie': cookie['bilibiliCookie'] ?? siteCookies[bilibiliSiteKey] ?? '',
      'huyaCookie': cookie['huyaCookie'] ?? siteCookies[huyaSiteKey] ?? '',
      'douyinCookie': cookie['douyinCookie'] ?? siteCookies[douyinSiteKey] ?? '',
      'kuaishouCookie': cookie['kuaishouCookie'] ?? siteCookies[kuaishouSiteKey] ?? '',
      'siteCookies': siteCookies,
      'bilibiliUid': cookie['bilibiliUid'] ?? 0,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final cookie = Map<String, dynamic>.from(rootConfig['cookie'] ?? {});
    updateFields.forEach((k, v) => cookie[k] = v);
    rootConfig['cookie'] = cookie;
    return rootConfig;
  }

  static String _normalizeSiteKey(String siteKey) {
    return siteKey.trim().toLowerCase();
  }

  static String _storageKeyForSite(String siteKey) {
    return _legacyCookieStorageKeys[siteKey] ?? 'siteCookie_${siteKey.replaceAll(RegExp(r'[^a-z0-9_]+'), '_')}';
  }

  static Map<String, String> _asStringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, value) => MapEntry(_normalizeSiteKey(key.toString()), value?.toString() ?? ''));
  }
}
