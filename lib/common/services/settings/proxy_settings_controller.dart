import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/core/common/http_client.dart';

class ProxySettingsController extends GetxController {
  final RxBool enableProxy = hiveBool('enableProxy', false);
  final RxString proxyHost = hiveString('proxyHost', '');
  final RxInt proxyPort = hiveInt('proxyPort', 7897);

  // app proxy settings
  final RxBool enableAppProxy = hiveBool('enableAppProxy', false);
  final RxString appProxyHost = hiveString('appProxyHost', '');
  final RxInt appProxyPort = hiveInt('appProxyPort', 7897);

  // 去除 SSL 验证（默认开启）
  // When true, the application will skip SSL/TLS certificate verification
  // for both Dio HTTP client and the player kernel (mpv).
  final RxBool disableSslVerify = hiveBool('disableSslVerify', true);

  // 图片代理：按站点平台独立开关，默认全部开启
  final RxList<String> imageProxySites = hiveStringList('imageProxySites', AppConsts.supportSites);

  // 站点 API 访问代理：按站点平台独立开关，默认全部关闭
  final RxList<String> apiProxySites = hiveStringList('apiProxySites', []);

  @override
  void onInit() {
    super.onInit();

    final missingImageProxySites = AppConsts.supportSites.where((site) => !imageProxySites.contains(site)).toList();
    if (missingImageProxySites.isNotEmpty) {
      imageProxySites.v = [...imageProxySites.v, ...missingImageProxySites];
    }

    ever<bool>(enableAppProxy, (_) => _refreshDioConnections());
    ever<String>(appProxyHost, (_) => _refreshDioConnections());
    ever<int>(appProxyPort, (_) => _refreshDioConnections());
    ever<bool>(disableSslVerify, (_) => _refreshDioConnections());
    ever<List<String>>(apiProxySites, (_) => _refreshDioConnections());
  }

  void _refreshDioConnections() {
    try {
      HttpClient.instance.rebuildDio();
    } catch (_) {}
  }

  Map<String, dynamic> toJson() {
    return {
      'enableProxy': enableProxy.v,
      'proxyHost': proxyHost.v,
      'proxyPort': proxyPort.v,
      'enableAppProxy': enableAppProxy.v,
      'appProxyHost': appProxyHost.v,
      'appProxyPort': appProxyPort.v,
      'disableSslVerify': disableSslVerify.v,
      'imageProxySites': List<String>.from(imageProxySites.v),
      'apiProxySites': List<String>.from(apiProxySites.v),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    enableProxy.v = json['enableProxy'] ?? false;
    proxyHost.v = json['proxyHost'] ?? '';
    proxyPort.v = json['proxyPort'] ?? 1080;
    enableAppProxy.v = json['enableAppProxy'] ?? false;
    appProxyHost.v = json['appProxyHost'] ?? '';
    appProxyPort.v = json['appProxyPort'] ?? 1080;
    disableSslVerify.v = json['disableSslVerify'] ?? true;
    imageProxySites.v = List<String>.from(json['imageProxySites'] ?? AppConsts.supportSites);
    apiProxySites.v = List<String>.from(json['apiProxySites'] ?? []);
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final proxy = rootConfig?['proxy'] as Map<String, dynamic>? ?? {};
    return {
      'enableProxy': proxy['enableProxy'] ?? false,
      'proxyHost': proxy['proxyHost'] ?? '',
      'proxyPort': proxy['proxyPort'] ?? 7897,
      'enableAppProxy': proxy['enableAppProxy'] ?? false,
      'appProxyHost': proxy['appProxyHost'] ?? '',
      'appProxyPort': proxy['appProxyPort'] ?? 7897,
      'disableSslVerify': proxy['disableSslVerify'] ?? true,
      'imageProxySites': List<String>.from(proxy['imageProxySites'] ?? AppConsts.supportSites),
      'apiProxySites': List<String>.from(proxy['apiProxySites'] ?? []),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final proxy = Map<String, dynamic>.from(rootConfig['proxy'] ?? {});
    updateFields.forEach((k, v) => proxy[k] = v);
    rootConfig['proxy'] = proxy;
    return rootConfig;
  }
}
