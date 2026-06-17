import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/plugins/utils.dart';

class SiteAccountController extends GetxController {
  final cookie = SettingsService.to.cookieManager;
  late final List<Site> sites = Sites.supportSites.where((site) => site.id != Sites.iptvSite && site.id != Sites.allSite).toList();

  @override
  void onInit() {
    super.onInit();
    initAllSiteCookie();
  }

  /// 初始化所有站点 Cookie。
  Future<void> initAllSiteCookie() async {
    for (final site in sites) {
      final cookieValue = cookie.getCookie(site.id);
      if (cookieValue.isNotEmpty) {
        await site.liveSite.loadUserInfo(site, cookieValue);
      }
    }
  }

  /// 点击站点账号项。
  Future<void> onTap(Site site) async {
    if (site.liveSite.isLogin.value) {
      final result = await Utils.showAlertDialog(
        i18n('site_logout_confirm', args: {'site': site.name}),
        title: i18n('logout'),
      );
      if (result) {
        await site.liveSite.logout(site);
      }
    } else {
      showSiteLoginOptions(site);
    }
  }

  /// 显示站点登录方式。
  void showSiteLoginOptions(Site site) {
    Get.bottomSheet(
      SafeArea(
        child: Material(
          color: Get.theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Get.theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  title: Text(
                    i18n('site_login_title', args: {'site': site.name}),
                    style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (site.liveSite.isSupportWebLogin())
                  ListTile(
                    leading: const Icon(Icons.account_circle_outlined),
                    title: Text(i18n('web_login')),
                    subtitle: Text(i18n('web_login_subtitle')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Get.back();
                      Get.toNamed(RoutePath.kSiteWebLogin, parameters: {'site': site.id});
                    },
                  ),
                if (site.liveSite.isSupportQrLogin())
                  ListTile(
                    leading: const Icon(Icons.qr_code_rounded),
                    title: Text(i18n('qr_login')),
                    subtitle: Text(i18n('site_qr_login_subtitle', args: {'site': site.name})),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Get.back();
                      Get.toNamed(RoutePath.kSiteQRLogin, parameters: {'site': site.id});
                    },
                  ),
                if (site.liveSite.isSupportCookieLogin())
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(i18n('cookie_login')),
                    subtitle: Text(i18n('cookie_login_subtitle')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Get.back();
                      doCookieLogin(site);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Cookie 登录。
  Future<void> doCookieLogin(Site site) async {
    final cookieValue = await Utils.showEditTextDialog(
      cookie.getCookie(site.id),
      title: i18n('input_cookie'),
      hintText: i18n('input_cookie'),
    );
    if (cookieValue == null || cookieValue.trim().isEmpty) {
      return;
    }

    final flag = await site.liveSite.loadUserInfo(site, cookieValue.trim());
    if (!flag) {
      await Utils.showAlertDialog(i18n('cookie_check_failed'), title: i18n('error'));
    }
  }
}
