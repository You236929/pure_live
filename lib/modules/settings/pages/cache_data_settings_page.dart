import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class CacheDataSettingsPage extends StatelessWidget {
  const CacheDataSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("cache_and_data"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("cache_and_data")),
          context.buildModernCard([
            Obx(() {
              final size = SettingsService.to.cache.cacheSizeMB.value;
              final turns = SettingsService.to.cache.refreshTurns.value;
              return context.buildTile(
                icon: Remix.database_2_line,
                title: i18n("current_cache_size"),
                subtitle: "",
                onTap: () => SettingsService.to.cache.handleManualRefresh(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${size.toStringAsFixed(2)} MB",
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: turns,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      child: Icon(Remix.refresh_line, size: 16, color: theme.hintColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              );
            }),
            // 图片缓存：单独显示大小并提供清除入口
            Obx(() {
              final imgSize = SettingsService.to.cache.imageCacheSizeMB.value;
              return context.buildTile(
                icon: Remix.image_2_line,
                title: i18n("clear_image_cache"),
                subtitle: i18n("clear_image_cache_desc"),
                trailing: Text(
                  "${imgSize.toStringAsFixed(2)} MB",
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final ok = await Get.dialog<bool>(
                    AlertDialog(
                      title: Text(i18n("confirm_clear_image_cache")),
                      content: Text(i18n("confirm_clear_image_cache_desc")),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(Get.context!, false),
                          child: Text(i18n("cancel")),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(Get.context!, true),
                          child: Text(i18n("clear"), style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await SettingsService.to.cache.clearImageCache();
                    Get.snackbar(i18n("done"), i18n("image_cache_cleared"), snackPosition: SnackPosition.bottom);
                  }
                },
              );
            }),
            context.buildTile(
              icon: Remix.delete_bin_6_line,
              title: i18n("clear_all_cache"),
              subtitle: i18n("clear_all_cache_meida_desc"),
              onTap: () async {
                final ok = await Get.dialog<bool>(
                  AlertDialog(
                    title: Text(i18n("confirm_clear_cache")),
                    content: Text(i18n("confirm_clear_meida_desc")),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(Get.context!, false), child: Text(i18n("cancel"))),
                      TextButton(
                        onPressed: () => Navigator.pop(Get.context!, true),
                        child: Text(i18n("clear"), style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await SettingsService.to.cache.clearCache();
                  Get.snackbar(i18n("done"), i18n("cache_cleared"), snackPosition: SnackPosition.bottom);
                }
              },
            ),
          ]),
          const SizedBox(height: 16),
          context.buildGroupTitle(i18n("area_cache_clean")),
          context.buildModernCard([
            Obx(() {
              final areaSize = SettingsService.to.cache.areaCacheSizeMB.value;
              return context.buildTile(
                icon: Remix.apps_2_line,
                title: i18n("area_cache_size"),
                subtitle: i18n("area_cache_desc"),
                trailing: Text(
                  "${areaSize.toStringAsFixed(2)} MB",
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () => SettingsService.to.cache.handleManualRefresh(),
              );
            }),
            context.buildTile(
              icon: Remix.delete_bin_2_line,
              title: i18n("clear_all_area_cache"),
              subtitle: i18n("clear_all_area_cache_desc"),
              onTap: () async {
                final ok = await Get.dialog<bool>(
                  AlertDialog(
                    title: Text(i18n("confirm_clear_area_cache")),
                    content: Text(i18n("confirm_clear_area_cache_desc")),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(Get.context!, false), child: Text(i18n("cancel"))),
                      TextButton(
                        onPressed: () => Navigator.pop(Get.context!, true),
                        child: Text(i18n("clear"), style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await SettingsService.to.cache.clearAreaCache();
                  Get.snackbar(i18n("done"), i18n("area_cache_cleared"), snackPosition: SnackPosition.bottom);
                }
              },
            ),
            ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.only(bottom: 4),
              leading: Icon(Remix.folder_2_line, color: theme.colorScheme.primary, size: 22),
              title: Text(i18n("site_area_cache"), style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  i18n("area_cache_desc"),
                  style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.75)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              children: Sites.supportSites
                  .map(
                    (site) => Obx(() {
                      final size = SettingsService.to.cache.areaCacheSiteSizeMB[site.id] ?? 0;
                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 24, right: 16, top: 2, bottom: 2),
                        leading: _buildSiteLogo(site.logo),
                        title: Text(site.name, style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${size.toStringAsFixed(2)} MB",
                              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Icon(Remix.delete_bin_2_line, color: theme.hintColor.withValues(alpha: 0.45), size: 18),
                          ],
                        ),
                        onTap: size <= 0
                            ? null
                            : () async {
                                final ok = await Get.dialog<bool>(
                                  AlertDialog(
                                    title: Text(i18n("confirm_clear_site_area_cache", args: {"site": site.name})),
                                    content: Text(i18n("confirm_clear_site_area_cache_desc")),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(Get.context!, false),
                                        child: Text(i18n("cancel")),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(Get.context!, true),
                                        child: Text(i18n("clear"), style: TextStyle(color: theme.colorScheme.error)),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await SettingsService.to.cache.clearAreaCacheBySite(site.id);
                                  Get.snackbar(i18n("done"), i18n("site_area_cache_cleared"), snackPosition: SnackPosition.bottom);
                                }
                              },
                      );
                    }),
                  )
                  .toList(),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSiteLogo(String logo) {
    return Image.asset(
      logo,
      width: 24,
      height: 24,
      errorBuilder: (_, _, _) => const Icon(Remix.live_line, size: 22),
    );
  }
}
