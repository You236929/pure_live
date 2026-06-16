import 'dart:io' as io;
import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/core/common/core_error.dart';
import 'package:pure_live/core/common/custom_interceptor.dart';
import 'package:pure_live/common/services/settings_service.dart';

class HttpClient {
  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _receiveTimeout = Duration(seconds: 20);
  static const Duration _sendTimeout = Duration(seconds: 20);

  static const int _downloadSuccessCode1 = 200;
  static const int _downloadSuccessCode2 = 206;

  static const String _errorGet = "发送GET请求失败";
  static const String _errorPost = "发送POST请求失败";
  static const String _errorHead = "发送HEAD请求失败";
  static const String _errorDownload = "下载请求失败";
  static const String _errorDownloadFailed = "下载失败";
  static const String _errorDownloadCancel = "下载已取消";
  static const String _siteApiProxyHost = "proxy.moonchan.xyz";

  HttpClient._();
  static final HttpClient instance = HttpClient._();
  late Dio dio = _createDio();
  Dio _createDio() {
    return Dio(BaseOptions(connectTimeout: _connectTimeout, receiveTimeout: _receiveTimeout, sendTimeout: _sendTimeout))
      ..interceptors.add(CustomLogInterceptor())
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = io.HttpClient();
          client.findProxy = (uri) {
            final proxyCtrl = SettingsService.to.proxy;
            if (proxyCtrl.enableAppProxy.value && proxyCtrl.appProxyHost.value.trim().isNotEmpty) {
              return 'PROXY '
                  '${proxyCtrl.appProxyHost.value.trim()}:'
                  '${proxyCtrl.appProxyPort.value}';
            }
            return 'DIRECT';
          };

          // 去除 SSL 验证（默认开启）：跳过证书校验
          if (SettingsService.to.proxy.disableSslVerify.value) {
            client.badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
          }

          return client;
        },
      );
  }

  void rebuildDio() {
    final oldDio = dio;
    dio = _createDio();
    oldDio.close(force: false);
  }

  Map<String, dynamic> _copyQueryParameters(Map<String, dynamic>? queryParameters) {
    return queryParameters == null ? <String, dynamic>{} : Map<String, dynamic>.from(queryParameters);
  }

  String _findEnabledApiProxySiteKey() {
    try {
      final stack = StackTrace.current.toString();
      final enabledSites = SettingsService.to.proxy.apiProxySites;
      for (final siteKey in enabledSites) {
        final patterns = [
          RegExp('/${RegExp.escape(siteKey)}_site\\.dart'),
          RegExp('/${RegExp.escape(siteKey)}_danmaku\\.dart'),
          RegExp('/${RegExp.escape(siteKey)}_site_mixin\\.dart'),
          RegExp('/utils/${RegExp.escape(siteKey)}/'),
          RegExp('/${RegExp.escape(siteKey)}_utils\\.dart'),
        ];
        if (patterns.any((pattern) => pattern.hasMatch(stack))) {
          return siteKey;
        }
      }
    } catch (_) {}
    return "";
  }

  String _siteApiProxyUrl(String url, Map<String, dynamic> queryParameters) {
    final siteKey = _findEnabledApiProxySiteKey();
    if (siteKey.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || uri.host == _siteApiProxyHost) return url;
    queryParameters["proxy_host"] = uri.host;
    queryParameters["proxy_referer"] = "${uri.scheme.isEmpty ? 'https' : uri.scheme}://${uri.host}/";
    return url.replaceFirst(uri.host, _siteApiProxyHost);
  }

  Future<String> getText(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      final query = _copyQueryParameters(queryParameters);
      final result = await dio.get(
        _siteApiProxyUrl(url, query),
        queryParameters: query,
        options: Options(responseType: ResponseType.plain, headers: header),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      throw _handleError(e, _errorGet);
    }
  }

  Future<dynamic> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      final query = _copyQueryParameters(queryParameters);
      final result = await dio.get(
        _siteApiProxyUrl(url, query),
        queryParameters: query,
        options: Options(responseType: ResponseType.json, headers: header),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      throw _handleError(e, _errorGet);
    }
  }

  Future<Response<dynamic>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      final query = _copyQueryParameters(queryParameters);
      final result = await dio.get(
        _siteApiProxyUrl(url, query),
        queryParameters: query,
        options: Options(responseType: ResponseType.json, headers: header),
        cancelToken: cancel,
      );
      return result;
    } catch (e) {
      throw _handleError(e, _errorGet);
    }
  }

  Future<dynamic> postJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? header,
    bool formUrlEncoded = false,
    CancelToken? cancel,
  }) async {
    try {
      final query = _copyQueryParameters(queryParameters);
      final result = await dio.post(
        _siteApiProxyUrl(url, query),
        queryParameters: query,
        data: data,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
          contentType: formUrlEncoded ? Headers.formUrlEncodedContentType : null,
        ),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      throw _handleError(e, _errorPost);
    }
  }

  Future<Response> head(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      final query = _copyQueryParameters(queryParameters);
      final result = await dio.head(
        _siteApiProxyUrl(url, query),
        queryParameters: query,
        options: Options(headers: header, receiveDataWhenStatusError: true),
        cancelToken: cancel,
      );
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        return e.response!;
      }
      throw HttpError(_errorHead);
    }
  }

  Future<io.File> download(
    String url,
    String savePath, {
    Map<String, dynamic>? header,
    CancelToken? cancel,
    Function(int value, int progress)? onReceiveProgress,
  }) async {
    final query = <String, dynamic>{};
    final tempPath = "$savePath.part";
    final tempFile = io.File(tempPath);

    try {
      if (!await tempFile.exists()) {
        await tempFile.create(recursive: true);
      }
      final response = await dio.download(
        _siteApiProxyUrl(url, query),
        tempPath,
        queryParameters: query,
        cancelToken: cancel,
        onReceiveProgress: onReceiveProgress,
        options: Options(headers: header),
      );

      if (response.statusCode == _downloadSuccessCode1 || response.statusCode == _downloadSuccessCode2) {
        return await tempFile.rename(savePath);
      } else {
        throw HttpError(_errorDownloadFailed, statusCode: response.statusCode ?? 0);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw HttpError(_errorDownloadCancel);
      } else if (e.type == DioExceptionType.badResponse) {
        throw HttpError(e.message ?? "", statusCode: e.response?.statusCode ?? 0);
      } else {
        throw HttpError(_errorDownload);
      }
    }
  }

  HttpError _handleError(dynamic e, String defaultMsg) {
    if (e is DioException && e.type == DioExceptionType.badResponse) {
      return HttpError(e.message ?? defaultMsg, statusCode: e.response?.statusCode ?? 0);
    } else {
      return HttpError(defaultMsg);
    }
  }
}
