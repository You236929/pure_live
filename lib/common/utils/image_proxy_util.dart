import 'package:pure_live/common/services/settings_service.dart';

class ImageProxyUtil {
  ImageProxyUtil._();

  static String proxyImageUrl(String imageUrl, {String? siteKey, int? width, int? height}) {
    if (imageUrl.isEmpty) return imageUrl;
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme || uri.host == 'gimg0.baidu.com') return imageUrl;
    final site = siteKey?.trim();
    if (site == null || site.isEmpty) return imageUrl;
    if (!SettingsService.to.proxy.imageProxySites.contains(site)) return imageUrl;

    final encodedUrl = Uri.encodeComponent(imageUrl);
    var sizeText = '';
    if (width != null && height != null) {
      sizeText = '&size=w$width';
    }
    return 'https://gimg0.baidu.com/gimg/src=$encodedUrl&app=2001&n=0&g=0n&q=80&fmt=webp$sizeText';
  }
}
