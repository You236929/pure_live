import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/live_dlna_dialog.dart';

class LiveUrlTool {
  static Future<List<String>> parseLiveUrl(String url) async {
    if (url.isEmpty) return [];
    for (var site in Sites.supportSites) {
      var liveSite = site.liveSite;
      var parse = await liveSite.parse(url);
      if (parse.roomId.isNotEmpty) {
        return [parse.roomId, parse.platform];
      }
    }
    return [];
  }

  /// 获取直播播放直链
  /// [liveUrl] 直播间链接
  static Future<void> getLivePlayUrl(String liveUrl) async {
    if (liveUrl.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }

    // 1. 解析链接
    List<String> parseResult = await parseLiveUrl(liveUrl);
    if (parseResult.length < 2 || parseResult[0].isEmpty) {
      ToastUtil.show(i18n("toolbox_parse_failed"));
      return;
    }

    String roomId = parseResult[0];
    String platform = parseResult[1];

    try {
      // 2. 获取房间详情
      SmartDialog.showLoading(msg: "");
      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      // 3. 获取清晰度列表
      final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (qualities.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));
        return;
      }

      // 4. 选择清晰度
      final selectedQuality = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualities
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () => Navigator.pop(Get.context!, e),
                ),
              )
              .toList(),
        ),
      );
      if (selectedQuality == null) return;

      // 5. 获取播放线路
      SmartDialog.showLoading(msg: "");
      final playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: selectedQuality);
      SmartDialog.dismiss(status: SmartStatus.loading);

      // 6. 选择线路并复制
      await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${entry.key + 1}"})),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.value));
                    Navigator.pop(Get.context!);
                    ToastUtil.show(i18n("toolbox_copy_success"));
                  },
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      log("获取直链失败: $e", name: "LiveUrlTool");
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  static Future<void> getPlayUrlByRoomId({required String roomId, required String platform}) async {
    if (roomId.isEmpty || platform.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }
    try {
      SmartDialog.showLoading(msg: "");

      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (qualities.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));
        return;
      }

      final selectedQuality = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualities
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () => Navigator.pop(Get.context!, e),
                ),
              )
              .toList(),
        ),
      );
      if (selectedQuality == null) return;

      SmartDialog.showLoading(msg: "");
      final playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: selectedQuality);
      SmartDialog.dismiss(status: SmartStatus.loading);

      await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${entry.key + 1}"})),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.value));
                    Navigator.pop(Get.context!);
                    ToastUtil.show(i18n("toolbox_copy_success"));
                  },
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      log("已知房间号获取直链失败: $e", name: "LiveUrlTool");
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  static Future<void> castPlayUrlByRoomId({required String roomId, required String platform}) async {
    if (roomId.isEmpty || platform.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }

    try {
      SmartDialog.showLoading(msg: "");
      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (qualities.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));
        return;
      }

      final selectedQuality = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualities
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () {
                    Navigator.pop(Get.context!, e);
                  },
                ),
              )
              .toList(),
        ),
      );
      if (selectedQuality == null) return;

      SmartDialog.showLoading(msg: "");
      final playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: selectedQuality);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (playUrls.isEmpty) {
        ToastUtil.show(i18n("toolbox_get_url_failed"));
        return;
      }

      final selectedUrl = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${entry.key + 1}"})),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(Get.context!, entry.value);
                  },
                ),
              )
              .toList(),
        ),
      );

      // 选中url后直接投屏
      if (selectedUrl != null && selectedUrl.isNotEmpty) {
        Get.dialog(LiveDlnaPage(datasource: selectedUrl));
      }
    } catch (e) {
      SmartDialog.dismiss(status: SmartStatus.loading);
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    }
  }
}
