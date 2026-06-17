import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/sites.dart' show Site;
import 'package:pure_live/get/get.dart';

/// 站点账号能力。
mixin class SiteAccount {
  /// 是否登录。
  var isLogin = false.obs;

  /// Cookie 内容。
  var userCookie = ''.obs;

  /// 用户 ID。
  var uid = 0;

  /// 用户名。
  var userName = ''.obs;

  /// 获取用户 ID。
  int getUserId() => uid;

  /// 获取用户 Cookie。
  String getUserCookie() => userCookie.value;

  /// 是否支持登录。
  bool isSupportLogin() => false;

  /// 是否支持 Web 登录。
  bool isSupportWebLogin() => true;

  /// 是否支持二维码登录。
  bool isSupportQrLogin() => true;

  /// 是否支持 Cookie 登录。
  bool isSupportCookieLogin() => true;

  /// 退出登录。
  Future<void> logout(Site site) async {
    userCookie.value = '';
    uid = 0;
    userName.value = '';
    isLogin.value = false;

    switch (site.id) {
      case 'bilibili':
        SettingsService.to.cookieManager.bilibiliCookie.v = '';
        SettingsService.to.cookieManager.bilibiliUid.v = 0;
        break;
      case 'huya':
        SettingsService.to.cookieManager.huyaCookie.v = '';
        break;
      case 'douyin':
        SettingsService.to.cookieManager.douyinCookie.v = '';
        break;
      case 'kuaishou':
        SettingsService.to.cookieManager.kuaishouCookie.v = '';
        break;
    }

    await CookieManager.instance().deleteAllCookies();
  }

  /// 加载用户信息。
  Future<bool> loadUserInfo(Site site, String cookie) async {
    userCookie.value = '';
    uid = 0;
    userName.value = '';
    isLogin.value = false;
    return false;
  }

  /// Web 登录请求。
  URLRequest webLoginURLRequest() => URLRequest(
    headers: {},
    url: WebUri(''),
  );

  String? webLoginUserAgent() {
    return null;
  }

  /// Web 登录处理，判断是否成功。
  bool webLoginHandle(WebUri? uri) => false;

  /// 加载二维码。
  Future<QRBean> loadQRCode() async {
    return QRBean();
  }

  /// 获取二维码扫描状态。
  Future<QRBean> pollQRStatus(Site site, QRBean qrBean) async {
    return qrBean;
  }
}

/// 二维码状态。
enum QRStatus {
  /// 加载中。
  loading,

  /// 未扫描。
  unscanned,

  /// 已扫描。
  scanned,

  /// 已过期。
  expired,

  /// 失败。
  failed,

  /// 成功。
  success,
}

/// 二维码实体。
class QRBean {
  /// 二维码状态。
  QRStatus qrStatus = QRStatus.loading;

  /// 二维码链接。
  var qrcodeUrl = '';

  /// 二维码验证密钥。
  var qrcodeKey = '';
}

mixin class SiteVideoHeaders {
  /// 获取视频播放 HTTP Header。
  Map<String, String> getVideoHeaders() => {};
}

mixin class SiteOpen {
  /// 跳转 App URL。
  String getJumpToNativeUrl(LiveRoom liveRoom) => '';

  /// 跳转 Web URL。
  String getJumpToWebUrl(LiveRoom liveRoom) => '';
}

/// 站点解析。
final emptySiteParseBean = SiteParseBean(roomId: '', platform: '');
final urlRegExp = RegExp(
  r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
);

mixin class SiteParse {
  /// 站点解析 URL。
  Future<SiteParseBean> parse(String url) async {
    return emptySiteParseBean;
  }

  String getHttpUrl(String text) {
    final urlMatches = urlRegExp.allMatches(text).map((m) => m.group(0)).whereType<String>().toList();
    if (urlMatches.isEmpty) return '';
    return urlMatches.first;
  }

  /// 解析跳转 URL。
  Future<SiteParseBean> parseJumpUrl(List<RegExp> regExpJumpList, String realUrl) async {
    for (var i = 0; i < regExpJumpList.length; i++) {
      final regExp = regExpJumpList[i];
      final url = regExp.firstMatch(realUrl)?.group(0) ?? '';
      if (url != '') {
        final location = await getHttpResponseLocation(url);
        return parse(location);
      }
    }
    return emptySiteParseBean;
  }

  /// 解析 URL。
  Future<SiteParseBean> parseUrl(List<RegExp> regExpList, String realUrl, String platform) async {
    for (var i = 0; i < regExpList.length; i++) {
      final regExp = regExpList[i];
      final id = regExp.firstMatch(realUrl)?.group(1) ?? '';
      if (id != '') {
        return SiteParseBean(roomId: id, platform: platform);
      }
    }
    return emptySiteParseBean;
  }

  /// 获取 HTTP response Location。
  Future<String> getHttpResponseLocation(String url) async {
    try {
      if (url.isEmpty) return '';
      await dio.Dio().get(
        url,
        options: dio.Options(
          followRedirects: false,
        ),
      );
    } on dio.DioException catch (e) {
      CoreLog.error(e);
      if (e.response?.statusCode == 302) {
        final redirectUrl = e.response?.headers.value('Location');
        if (redirectUrl != null) {
          return redirectUrl;
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return '';
  }
}

class SiteParseBean {
  String roomId;
  String platform;

  SiteParseBean({
    required this.roomId,
    required this.platform,
  });
}

class RegExpBean {
  late RegExp regExp;
  late String siteType;

  RegExpBean({
    required this.regExp,
    required this.siteType,
  });
}

/// 其他跳转。
mixin class SiteOtherJump {
  List<OtherJumpItem> jumpItems(LiveRoom liveRoom) {
    return [];
  }
}

/// 跳转选项。
class OtherJumpItem {
  late IconData? iconData;
  late void Function() onTap;
  late String text;

  OtherJumpItem({
    required this.text,
    this.iconData,
    required this.onTap,
  });
}

/// 站点基础信息和批量更新能力。
mixin class SiteInfo {
  String get id => '';

  String get name => '';

  /// 是否支持批量更新房间。
  bool isSupportBatchUpdateLiveStatus() {
    return false;
  }

  /// 批量更新房间。
  Future<List<LiveRoom>> getLiveRoomDetailList({required List<LiveRoom> list}) {
    return Future.value(list);
  }

  /// 设置离线状态。
  LiveRoom getLiveRoomWithError(LiveRoom liveRoom) {
    liveRoom.liveStatus = LiveStatus.offline;
    liveRoom.status = false;
    liveRoom.isRecord = false;
    return liveRoom;
  }
}

/// 混合所有站点扩展能力。
class SiteMixin with SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse, SiteOtherJump, SiteInfo {}
