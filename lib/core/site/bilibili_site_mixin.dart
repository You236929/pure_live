import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/sites.dart' show Site;
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:url_launcher/url_launcher_string.dart';

mixin BilibiliSiteMixin on LiveSite {
  final Map<String, String> loginHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0',
  };

  /// ------------------ 登录
  @override
  bool isSupportLogin() => true;

  @override
  URLRequest webLoginURLRequest() {
    return URLRequest(
      url: WebUri('https://passport.bilibili.com/login'),
      headers: loginHeaders,
    );
  }

  @override
  bool webLoginHandle(WebUri? uri) {
    if (uri == null) {
      return false;
    }
    return uri.host == 'm.bilibili.com' || uri.host == 'www.bilibili.com';
  }

  /// 加载二维码
  @override
  Future<QRBean> loadQRCode() async {
    final qrBean = QRBean();
    try {
      qrBean.qrStatus = QRStatus.loading;

      final result = await HttpClient.instance.getJson(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
      );
      if (result['code'] != 0) {
        throw result['message'];
      }
      qrBean.qrcodeKey = result['data']['qrcode_key'];
      qrBean.qrcodeUrl = result['data']['url'];
      qrBean.qrStatus = QRStatus.unscanned;
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      qrBean.qrStatus = QRStatus.failed;
    }
    return qrBean;
  }

  /// 获取二维码扫描状态
  @override
  Future<QRBean> pollQRStatus(Site site, QRBean qrBean) async {
    try {
      final response = await HttpClient.instance.get(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
        queryParameters: {
          'qrcode_key': qrBean.qrcodeKey,
        },
      );
      if (response.data['code'] != 0) {
        throw response.data['message'];
      }
      final data = response.data['data'];
      final code = data['code'];
      if (code == 0) {
        final cookies = <String>[];
        response.headers['set-cookie']?.forEach((element) {
          final cookie = element.split(';')[0];
          cookies.add(cookie);
        });
        if (cookies.isNotEmpty) {
          final cookieStr = cookies.join(';');
          await loadUserInfo(site, cookieStr);
          qrBean.qrStatus = QRStatus.success;
        }
      } else if (code == 86038) {
        qrBean.qrStatus = QRStatus.expired;
        qrBean.qrcodeKey = '';
      } else if (code == 86090) {
        qrBean.qrStatus = QRStatus.scanned;
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
    }
    return qrBean;
  }

  @override
  Future<bool> loadUserInfo(Site site, String cookie) async {
    try {
      final result = await HttpClient.instance.getJson(
        'https://api.bilibili.com/x/member/web/account',
        header: {
          'Cookie': cookie,
        },
      );
      if (result['code'] == 0) {
        final info = BiliBiliUserInfoModel.fromJson(result['data']);
        userName.value = info.uname ?? '';
        uid = info.mid ?? 0;
        final flag = info.uname != null;
        isLogin.value = flag;
        CoreLog.d('isLogin: $flag');
        userCookie.value = cookie;
        SettingsService.to.cookieManager.setCookie(site.id, cookie);
        SettingsService.to.cookieManager.bilibiliUid.v = uid;
        return flag;
      } else {
        SmartDialog.showToast('${site.name}${i18n("bilibili_login_expired")}');
        logout(site);
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast('${site.name}${i18n("bilibili_user_info_failed")}');
    }
    return false;
  }

  /// 获取视频播放 HTTP Header
  @override
  Map<String, String> getVideoHeaders() {
    return {
      'cookie': userCookie.value,
      'authority': 'api.bilibili.com',
      'accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'accept-language': 'zh-CN,zh;q=0.9',
      'cache-control': 'no-cache',
      'dnt': '1',
      'pragma': 'no-cache',
      'sec-ch-ua': '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"macOS"',
      'sec-fetch-dest': 'document',
      'sec-fetch-mode': 'navigate',
      'sec-fetch-site': 'none',
      'sec-fetch-user': '?1',
      'upgrade-insecure-requests': '1',
      'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'referer': 'https://live.bilibili.com',
    };
  }

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) => 'bilibili://live/${liveRoom.roomId}';

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) => 'https://live.bilibili.com/${liveRoom.roomId}';

  @override
  Future<SiteParseBean> parse(String url) async {
    final realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if (realUrl.isEmpty) return siteParseBean;

    final regExpJumpList = [
      RegExp(r'https?:\/\/b23.tv\/[0-9a-z-A-Z]+'),
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if (siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    final regExpBeanList = [
      RegExp(r'bilibili\.com/([\d|\w]+)$'),
      RegExp(r'bilibili\.com/h5/([\d\w]+)$'),
    ];
    siteParseBean = await parseUrl(regExpBeanList, realUrl, id);
    return siteParseBean;
  }

  @override
  List<OtherJumpItem> jumpItems(LiveRoom liveRoom) {
    final list = <OtherJumpItem>[];

    list.add(
      OtherJumpItem(
        text: '直播录像',
        iconData: Icons.emergency_recording_outlined,
        onTap: () async {
          try {
            await launchUrlString(
              'https://space.bilibili.com/${liveRoom.userId}/lists?type=series',
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            CoreLog.error(e);
          }
        },
      ),
    );

    list.add(
      OtherJumpItem(
        text: '动态',
        iconData: Icons.wind_power_outlined,
        onTap: () async {
          try {
            await launchUrlString(
              'https://space.bilibili.com/${liveRoom.userId}/dynamic',
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            CoreLog.error(e);
          }
        },
      ),
    );

    return list;
  }
}
