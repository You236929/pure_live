import 'package:pure_live/common/models/index.dart';

import '../interface/live_danmaku.dart';

class LiveSite {
  /// 站点唯一ID
  String id = "";

  /// 站点名称
  String name = "";

  /// 站点名称
  LiveDanmaku getDanmaku() => LiveDanmaku();

  /// 获取直播间所有清晰度的url
  /// @param room
  Future<Map<String, List<String>>> getLiveStream(LiveRoom room) {
    return Future(() => {});
  }

  /// 获取单个直播间信息
  /// @param room
  /// @return room
  Future<LiveRoom> getRoomInfo(LiveRoom room) {
    return Future(() => LiveRoom(''));
  }

  /// 根据分页获取推荐直播间
  /// @param page 页数
  /// @param size 每页大小
  /// @return
  Future<List<LiveRoom>> getRecommend({
    int page = 0,
    int size = 20,
  }) {
    return Future(() => []);
  }

  /// 获取bilibili所有分类
  /// @return
  Future<List<List<LiveArea>>> getAreaList() {
    return Future(() => []);
  }

  /// 获取b站分区房间
  /// @param area 分类id
  /// @param page 请求页数
  /// @param size
  /// @return
  Future<List<LiveRoom>> getAreaRooms(
    LiveArea area, {
    int page = 1,
    int size = 20,
  }) {
    return Future(() => []);
  }

  /// 搜索
  /// @param keyWords  搜索关键字
  /// @return
  Future<List<LiveRoom>> search(String keyWords) {
    return Future(() => []);
  }
}
