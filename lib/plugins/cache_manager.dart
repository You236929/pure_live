import 'dart:async';
import 'dart:io';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 自定义图片缓存管理器
///
/// 缓存策略：
///   - 缓存有效期：1 天（以最近一次访问时间为准）
///   - 缓存最大占用：500MB（超过时按访问时间从最早开始 LRU 清理）
///   - 启动时自动清理过期与超额缓存
class CustomImageCacheManager {
  static const _cacheKey = 'customImageCacheKey';

  /// 单条缓存的存活期（以访问时间为准）
  static const Duration stalePeriod = Duration(days: 1);

  /// 缓存总大小上限（字节）
  static const int maxCacheBytes = 500 * 1024 * 1024; // 500 MB

  static CacheManager? _instance;
  static Directory? _imageCacheDir;

  static CacheManager get instance {
    if (_instance == null) {
      throw StateError("CustomImageCacheManager 尚未初始化，请先在 main 中调用 initialize()");
    }
    return _instance!;
  }

  static Future<void> initialize() async {
    if (_instance != null) return;
    final Directory imageCacheDir = await AppPathManager().getDir(AppPathManager.dirImageCache);
    _imageCacheDir = imageCacheDir;
    final customFileSystem = IOFileSystem(imageCacheDir.path);

    _instance = CacheManager(
      Config(
        _cacheKey,
        stalePeriod: stalePeriod,
        // flutter_cache_manager 自身按"对象数量"做 LRU；这里把上限调到很高，
        // 真正的容量限制由 enforceLimits() 按总字节数 + 访问时间执行。
        maxNrOfCacheObjects: 1 << 30,
        fileSystem: customFileSystem,
        fileService: HttpFileServiceWithRetry(),
      ),
    );

    // 启动时异步触发一次清理，避免阻塞 UI
    unawaited(enforceLimits());
  }

  /// 获取当前图片缓存目录占用的总字节数
  static Future<int> totalCacheBytes() async {
    final dir = _imageCacheDir ?? await AppPathManager().getDir(AppPathManager.dirImageCache);
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          try {
            total += entity.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  /// 清空全部图片缓存
  static Future<void> clearAll() async {
    final dir = _imageCacheDir ?? await AppPathManager().getDir(AppPathManager.dirImageCache);
    try {
      if (dir.existsSync()) {
        for (final entity in dir.listSync(recursive: true)) {
          try {
            if (entity is File) entity.deleteSync();
          } catch (_) {}
        }
      } else {
        dir.createSync(recursive: true);
      }
    } catch (_) {}
    try {
      await _instance?.emptyCache();
    } catch (_) {}
  }

  /// 执行缓存清理：
  ///   1) 删除超过 [stalePeriod] 未访问的文件（以访问时间为准）
  ///   2) 若总大小仍超过 [maxCacheBytes]，按访问时间从最早开始删除直到达标
  static Future<void> enforceLimits() async {
    final dir = _imageCacheDir ?? await AppPathManager().getDir(AppPathManager.dirImageCache);
    if (!dir.existsSync()) return;

    final now = DateTime.now();
    final List<_Entry> alive = [];
    int totalAlive = 0;

    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(recursive: true);
    } catch (_) {
      return;
    }

    for (final entity in entries) {
      if (entity is! File) continue;
      try {
        final stat = entity.statSync();
        // 部分平台/文件系统可能不更新访问时间，回退到修改时间
        final DateTime accessed = stat.accessed.millisecondsSinceEpoch > 0
            ? stat.accessed
            : stat.modified;
        if (now.difference(accessed) > stalePeriod) {
          try {
            entity.deleteSync();
          } catch (_) {}
        } else {
          alive.add(_Entry(entity, accessed, stat.size));
          totalAlive += stat.size;
        }
      } catch (_) {}
    }

    if (totalAlive > maxCacheBytes) {
      alive.sort((a, b) => a.accessed.compareTo(b.accessed));
      for (final e in alive) {
        if (totalAlive <= maxCacheBytes) break;
        try {
          e.file.deleteSync();
          totalAlive -= e.size;
        } catch (_) {}
      }
    }
  }
}

class _Entry {
  final File file;
  final DateTime accessed;
  final int size;
  _Entry(this.file, this.accessed, this.size);
}

class HttpFileServiceWithRetry extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    int retryCount = 0;
    const int maxRetries = 3;

    while (true) {
      try {
        return await super.get(url, headers: headers);
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries || e.toString().contains('404')) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }
}
