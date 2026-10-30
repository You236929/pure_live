import 'dart:io';

import 'package:pure_live/core/config/settings_service.dart';

/// 全局 HttpOverrides：用于让所有基于 `dart:io HttpClient` 的网络请求
/// （包括 `package:http`、裸 `HttpClient`、未自定义 adapter 的 `Dio` 实例、
/// `Image.network` / `cached_network_image` 等）统一遵循
/// 设置中的"去除 SSL 验证"开关。
class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    bool disableSslVerify = false;
    try {
      disableSslVerify = SettingsService.to.proxy.disableSslVerify.value;
    } catch (_) {}

    if (disableSslVerify) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }

    return client;
  }
}
