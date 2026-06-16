import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/plugins/cache_manager.dart';

class CacheController extends GetxController {
  /// 全部缓存（含录制、下载、IPTV、图片）总大小，单位 MB
  final cacheSizeMB = 0.0.obs;

  /// 仅图片缓存大小，单位 MB
  final imageCacheSizeMB = 0.0.obs;

  final refreshTurns = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    getCacheSize();
  }

  Future<double> getCacheSize() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> targetDirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];

    double totalSizeBytes = 0;
    double imageBytes = 0;
    for (final dir in targetDirs) {
      if (!dir.existsSync()) continue;
      try {
        final files = dir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            final len = file.lengthSync();
            totalSizeBytes += len;
            if (dir.path == imageCacheDir.path) {
              imageBytes += len;
            }
          }
        }
      } catch (_) {}
    }
    cacheSizeMB.value = totalSizeBytes / 1024 / 1024;
    imageCacheSizeMB.value = imageBytes / 1024 / 1024;
    return cacheSizeMB.value;
  }

  Future<void> clearCache() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> dirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];

    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      try {
        dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    // 同步重置 cached_network_image 的元数据
    try {
      await CustomImageCacheManager.clearAll();
    } catch (_) {}
    cacheSizeMB.value = 0;
    imageCacheSizeMB.value = 0;
  }

  /// 仅清除图片缓存
  Future<void> clearImageCache() async {
    try {
      await CustomImageCacheManager.clearAll();
    } catch (_) {}
    await getCacheSize();
  }

  Future<void> handleManualRefresh() async {
    refreshTurns.value += 1.0;
    await getCacheSize();
  }
}
