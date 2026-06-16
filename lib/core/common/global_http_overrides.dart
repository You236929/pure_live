import 'dart:io';

import 'package:pure_live/common/services/settings_service.dart';

/// 全局 HttpOverrides：用于让所有基于 `dart:io HttpClient` 的网络请求
/// （包括 `package:http`、裸 `HttpClient`、未自定义 adapter 的 `Dio` 实例、
/// `Image.network` / `cached_network_image` 等）统一遵循
/// 设置中的"去除 SSL 验证"开关。
class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    bool disableSslVerify = true; // 默认开启（与 ProxySettingsController 默认值保持一致）
    try {
      // 启动早期 SettingsService 可能还没注册，此时退回到默认值
      disableSslVerify = SettingsService.to.proxy.disableSslVerify.v;
    } catch (_) {}

    if (disableSslVerify) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }

    return client;
  }
}
