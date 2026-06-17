import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/sites.dart' show Site;
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:math';
import 'dart:convert';

mixin DouyuSiteMixin on LiveSite {
  /// ------------------ 登录
  @override
  bool isSupportLogin() => false;

  @override
  URLRequest webLoginURLRequest() {
    // https://passport.douyu.com/member/login?
    return URLRequest(
      url: WebUri("https://passport.douyu.com/h5/loginActivity?"),
    );
  }

  @override
  bool webLoginHandle(WebUri? uri) {
    if (uri == null) {
      return false;
    }
    return uri.host == "m.douyu.com" || uri.host == "www.douyu.com";
  }

  /// 加载二维码
  @override
  Future<QRBean> loadQRCode() async {
    var qrBean = QRBean();
    try {
      qrBean.qrStatus = QRStatus.loading;

      var result = await HttpClient.instance.postJson("https://passport.douyu.com/scan/generateCode", data: {
        "client_id": 1,
        "isMultiAccount": 0
      }, header: {
        "referer": "https://passport.douyu.com/member/login?",
        "origin": "https://passport.douyu.com",
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      });
      CoreLog.d("result: $result");
      if (result["error"] != 0) {
        throw result["msg"];
      }
      qrBean.qrcodeKey = result["data"]["code"];
      qrBean.qrcodeUrl = result["data"]["url"];
      qrBean.qrStatus = QRStatus.unscanned;
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      qrBean.qrStatus = QRStatus.failed;
    }
    return qrBean;
  }

  ///  获取二维码扫描状态
  @override
  Future<QRBean> pollQRStatus(Site site, QRBean qrBean) async {
    try {
      var milliseconds = DateTime.now().millisecondsSinceEpoch;
      var response = await HttpClient.instance.get("https://passport.douyu.com/japi/scan/auth", queryParameters: {
        "time": milliseconds,
        "code": qrBean.qrcodeKey,
      }, header: {
        "referer": "https://www.douyu.com/",
      });
      // if (response.data["error"] != 0) {
      //   throw response.data["msg"];
      // }
      /// error -2 msg "客户端还未扫码"
      /// error -1 msg "code不存在或者是已经过期"
      CoreLog.d("response: $response");
      // var data = response.data["data"];
      var code = response.data["error"];
      if (code == 0) {
        var cookies = <String>[];
        response.headers["set-cookie"]?.forEach((element) {
          var cookie = element.split(";")[0];
          cookies.add(cookie);
        });
        if (cookies.isNotEmpty) {
          var cookieStr = cookies.join(";");
          await loadUserInfo(site, cookieStr);
          qrBean.qrStatus = QRStatus.success;
        }
      } else if (code == -1) {
        qrBean.qrStatus = QRStatus.expired;
        qrBean.qrcodeKey = "";
      } else if (code == 86090) {
        qrBean.qrStatus = QRStatus.scanned;
      } else {
        qrBean.qrStatus = QRStatus.unscanned;
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
      var result = await HttpClient.instance.getJson(
        "https://api.bilibili.com/x/member/web/account",
        header: {
          "Cookie": cookie,
        },
      );
      if (result["code"] == 0) {
        var info = BiliBiliUserInfoModel.fromJson(result["data"]);
        userName.value = info.uname ?? i18n('not_logged_in');
        uid = info.mid ?? 0;
        var flag = info.uname != null;
        isLogin.value = flag;
        CoreLog.d("isLogin: $flag");
        userCookie.value = cookie;
        SettingsService.to.cookieManager.setCookie(site.id, cookie);
        return flag;
      } else {
        SmartDialog.showToast(i18n('site_login_expired', args: {'site': site.name}));
        logout(site);
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(i18n('site_user_info_failed', args: {'site': site.name}));
    }
    return false;
  }

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      // naviteUrl = "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${liveRoomRx.roomId}";
      return "dydeeplink://platformapi/startApp?room_id=${liveRoom.roomId}";
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) {
    try {
      return "https://www.douyu.com/${liveRoom.roomId}";
    } catch (e) {
      return "";
    }
  }

  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if (realUrl.isEmpty) return siteParseBean;
    // 解析跳转
    List<RegExp> regExpJumpList = [
      // 网站 解析跳转
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if (siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    List<RegExp> regExpBeanList = [
      // 斗鱼
      RegExp(r"douyu\.com/([\d|\w]+)[/]?$"),
      RegExp(r"douyu\.com/([\d]+)[/]?\?.*"),
      //RegExp(r"douyu\.com/topic/[\w\d]+\?.*rid=([^&]+).*$"),
      RegExp(r"douyu\.com/.*\?.*rid=([^&]+).*$"),
    ];
    siteParseBean = await parseUrl(regExpBeanList, realUrl, id);
    return siteParseBean;
  }

  @override
  List<OtherJumpItem> jumpItems(LiveRoom liveRoom) {
    List<OtherJumpItem> list = [];

    list.add(OtherJumpItem(
      text: i18n('live_recording'),
      iconData: Icons.emergency_recording_outlined,
      onTap: () async {
        try {
          await launchUrlString("https://v.douyu.com/author/${liveRoom.userId}?type=liveReplay", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));

    list.add(OtherJumpItem(
      text: i18n('douyu_yuba'),
      iconData: Icons.web_outlined,
      onTap: () async {
        try {
          await launchUrlString("http://yuba.douyu.com/api/dy/anchor/anchorTopic?room_id=${liveRoom.roomId}", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));

    return list;
  }

  @override
  bool isSupportBatchUpdateLiveStatus() {
    return true;
  }

  @override
  Future<List<LiveRoom>> getLiveRoomDetailList({required List<LiveRoom> list}) async {
    if (list.isEmpty) {
      return list;
    }

    /// 分页获取，每页 20 个
    var size = 20;
    var futureList = <Future<List<LiveRoom>>>[];
    for (var i = 0; i < list.length; i += size) {
      var end = min(i + size, list.length);
      var subList = list.sublist(i, end);
      var future = _getLiveRoomDetailListPart(list: subList);
      futureList.add(future);
    }
    final rooms = await Future.wait(futureList);
    return rooms.expand((e) => e).toList();
  }

  Future<List<LiveRoom>> _getLiveRoomDetailListPart({required List<LiveRoom> list}) async {
    if (list.isEmpty) {
      return list;
    }
    var idList = list.map((room) => room.roomId!).toList();
    var rids = idList.join(",");

    try {
      var result = await HttpClient.instance.postJson(
        "https://apiv2.douyucdn.cn/Livenc/UserRelation/getFollowRoomListByRid",
        queryParameters: {},
        data: {"rids": rids},
        formUrlEncoded: true,
        header: {
          'referer': 'https://www.douyu.com/',
          'content-type': 'application/x-www-form-urlencoded',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
        },
      );

      List roomList;
      if (result is String) {
        roomList = json.decode(result)["data"]["room_list"];
      } else {
        roomList = result["data"]["room_list"];
      }

      List<LiveRoom> rsList = [];
      for (var roomInfo in roomList) {
        var isLiving = roomInfo["show_status"] == 1;
        var tmp = LiveRoom(
          cover: roomInfo["room_src"].toString(),
          watching: roomInfo["hn"].toString(),
          roomId: roomInfo["room_id"].toString(),
          title: roomInfo["room_name"].toString(),
          nick: roomInfo["nickname"].toString(),
          avatar: roomInfo["avatar"].toString(),
          introduction: roomInfo["close_notice"].toString(),
          area: roomInfo["cate2_name"]?.toString() ?? '',
          notice: roomInfo["close_notice"]?.toString() ?? "",
          liveStatus: isLiving ? LiveStatus.live : LiveStatus.offline,
          status: roomInfo["show_status"] == 1,
          danmakuData: roomInfo["room_id"].toString(),
          platform: Sites.douyuSite,
          link: "https://www.douyu.com/${roomInfo["room_id"].toString()}",
          isRecord: false,
        );
        rsList.add(tmp);
      }
      return rsList;
    } catch (e) {
      CoreLog.error(e);
      for (var liveRoom in list) {
        liveRoom.liveStatus = LiveStatus.offline;
        liveRoom.status = false;
      }
      return list;
    }
  }
}
