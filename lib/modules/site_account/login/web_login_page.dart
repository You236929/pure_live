import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/site_account/login/web_login_controller.dart';

class SiteWebLoginPage extends GetView<SiteWebLoginController> {
  const SiteWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('site_login_title', args: {'site': controller.site.name})),
        actions: [
          if (controller.site.liveSite.isSupportQrLogin())
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: controller.toQRLogin,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Remix.qr_code_line, size: 16),
                label: Text(i18n('qr_login')),
              ),
            ),
        ],
      ),
      body: InAppWebView(
        onWebViewCreated: controller.onWebViewCreated,
        onLoadStop: controller.onLoadStop,
        onReceivedError: (_, _, error) {
          CoreLog.error(error.description);
        },
        initialSettings: InAppWebViewSettings(
          userAgent: controller.initUserAgent(),
          useShouldOverrideUrlLoading: false,
        ),
        shouldOverrideUrlLoading: (webController, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri == null) {
            return NavigationActionPolicy.ALLOW;
          }
          if (controller.site.liveSite.webLoginHandle(uri)) {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
