import 'package:flutter/material.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:url_launcher/url_launcher_string.dart';

mixin CCSiteMixin on LiveSite {
  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      return "cc://join-room/${liveRoom.roomId}/${liveRoom.userId}/";
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) => "https://cc.163.com/${liveRoom.roomId}";

  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if (realUrl.isEmpty) return siteParseBean;
    // 解析跳转
    List<RegExp> regExpJumpList = [];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if (siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    List<RegExp> regExpBeanList = [
      // 网易 CC
      RegExp(r"cc\.163\.com/([a-zA-Z0-9]+)$"),
      RegExp(r"cc\.163\.com/cc/([a-zA-Z0-9]+)$"),
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
          // await launchUrlString("https://space.bilibili.com/${liveRoom.userId}/lists/405144?type=series", mode: LaunchMode.externalApplication);
          await launchUrlString("https://cc.163.com/user/${liveRoom.roomId}/?", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));
    return list;
  }
}
