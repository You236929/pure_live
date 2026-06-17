import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/sites.dart';

class SiteWebLoginController extends BaseController {
  final Site site;
  final CookieManager cookieManager = CookieManager.instance();
  InAppWebViewController? webViewController;

  SiteWebLoginController({required this.site});

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(urlRequest: site.liveSite.webLoginURLRequest());
  }

  String? initUserAgent() {
    return site.liveSite.webLoginUserAgent();
  }

  Future<void> toQRLogin() async {
    await Get.offAndToNamed(RoutePath.kSiteQRLogin, parameters: {'site': site.id});
  }

  Future<void> onLoadStop(InAppWebViewController controller, WebUri? uri) async {
    CoreLog.d('onLoadStop ..... $uri');
    if (uri == null) {
      return;
    }
    if (site.liveSite.webLoginHandle(uri)) {
      final cookies = await cookieManager.getCookies(url: uri);
      final cookieStr = cookies.map((e) => '${e.name}=${e.value}').join(';');
      CoreLog.d('cookieStr: $cookieStr');
      final flag = await site.liveSite.loadUserInfo(site, cookieStr);
      if (flag) {
        Navigator.of(Get.context!).pop(true);
      }
    }
  }
}
