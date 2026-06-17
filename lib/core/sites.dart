import 'site/huya_site.dart';
import 'site/douyu_site.dart';
import 'site/douyin_site.dart';
import 'interface/live_site.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/cc_site.dart';
import 'package:pure_live/core/site/iptv_site.dart';
import 'package:pure_live/core/site/yy_site.dart';
import 'package:pure_live/core/site/soop_site.dart';
import 'package:pure_live/core/site/twitch_site.dart';
import 'package:pure_live/core/site/pandatv_site.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:pure_live/core/site/kuaishou_site.dart';
import 'package:pure_live/core/site/stripchat_site.dart';

class Sites {
  static const String allSite = "all";
  static const String bilibiliSite = "bilibili";
  static const String douyuSite = "douyu";
  static const String huyaSite = "huya";
  static const String douyinSite = "douyin";
  static const String kuaishouSite = "kuaishou";
  static const String ccSite = "cc";
  static const String iptvSite = "iptv";
  static const String pandatvSite = "pandatv";
  static const String soopSite = "soop";
  static const String stripchatSite = "stripchat";
  static const String twitchSite = "twitch";
  static const String yySite = "yy";
  static final Map<String, LiveSite> _liveSites = {
    bilibiliSite: BiliBiliSite(),
    douyuSite: DouyuSite(),
    huyaSite: HuyaSite(),
    douyinSite: DouyinSite(),
    kuaishouSite: KuaishowSite(),
    ccSite: CCSite(),
    pandatvSite: PandaTvSite(),
    soopSite: SoopSite(),
    stripchatSite: StripChatSite(),
    twitchSite: TwitchSite(),
    yySite: YYSite(),
    iptvSite: IptvSite(),
  };

  static List<Site> get supportSites => [
    Site(id: bilibiliSite, name: i18n("site_bilibili"), logo: "assets/images/bilibili_2.png", liveSite: _liveSites[bilibiliSite]!),
    Site(id: douyuSite, name: i18n("site_douyu"), logo: "assets/images/douyu.png", liveSite: _liveSites[douyuSite]!),
    Site(id: huyaSite, name: i18n("site_huya"), logo: "assets/images/huya.png", liveSite: _liveSites[huyaSite]!),
    Site(id: douyinSite, name: i18n("site_douyin"), logo: "assets/images/douyin.png", liveSite: _liveSites[douyinSite]!),
    Site(id: kuaishouSite, name: i18n("site_kuaishou"), logo: "assets/images/kuaishou.png", liveSite: _liveSites[kuaishouSite]!),
    Site(id: ccSite, name: i18n("site_cc"), logo: "assets/images/cc.png", liveSite: _liveSites[ccSite]!),
    Site(id: pandatvSite, name: i18n("site_pandatv"), logo: "assets/images/pandatv.png", liveSite: _liveSites[pandatvSite]!),
    Site(id: soopSite, name: i18n("site_soop"), logo: "assets/images/soop.png", liveSite: _liveSites[soopSite]!),
    Site(id: stripchatSite, name: i18n("site_stripchat"), logo: "assets/images/stripchat.png", liveSite: _liveSites[stripchatSite]!),
    Site(id: twitchSite, name: i18n("site_twitch"), logo: "assets/images/twitch.png", liveSite: _liveSites[twitchSite]!),
    Site(id: yySite, name: i18n("site_yy"), logo: "assets/images/yy.png", liveSite: _liveSites[yySite]!),
    Site(id: iptvSite, name: i18n("site_iptv"), logo: "assets/images/logo.png", liveSite: _liveSites[iptvSite]!),
  ];

  static Site of(String id) {
    return supportSites.firstWhere((e) => id == e.id);
  }

  List<Site> availableSites({bool containsAll = false}) {
    final List<String> savedIds = SettingsService.to.fav.hotAreasList.v;

    List<Site> result = [];
    for (String id in savedIds) {
      final match = supportSites.firstWhereOrNull((element) => element.id == id);
      if (match != null) {
        result.add(match);
      }
    }
    if (containsAll) {
      result.insert(0, Site(id: "all", name: i18n("site_all"), logo: "assets/images/all.png", liveSite: LiveSite()));
    }
    return result;
  }
}

class Site {
  final String id;
  final String name;
  final String logo;
  final LiveSite liveSite;
  Site({required this.id, required this.liveSite, required this.logo, required this.name});
}
