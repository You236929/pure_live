import 'dart:io';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/core/sites.dart';

/// 批量更新房间工具类
class UpdateRoomUtil {
  /// 判断网络是否连接
  static Future<bool> testNetwork() async {
    var testCount = 2;
    var isOk = false;
    for (var i = 0; i < testCount; i++) {
      try {
        await HttpClient.instance.get("http://suggestion.baidu.com/su?wd=pqn&cb=suggestion");
        isOk = true;
        break;
      } catch (e) {
        CoreLog.w("$e");
        HttpClient.instance.rebuildDio();
        sleep(const Duration(milliseconds: 2000));
      }
    }
    return isOk;
  }

  /// 批量更新房间列表
  static Future<bool> updateRoomList(List<LiveRoom> roomList, FavoriteRoomController favCtrl) async {
    var isTestNetworkOk = await testNetwork();
    if (!isTestNetworkOk) {
      return isTestNetworkOk;
    }
    // 过滤非法数据
    roomList = roomList.where((room) => (room.roomId?.isNotEmpty ?? false) && (room.platform?.isNotEmpty ?? false)).toList();
    // 已经更新的数据
    List<LiveRoom> updatedRoomList = [];
    // 批量更新
    var tmp = Sites.supportSites
        .where((site) => site.liveSite.isSupportBatchUpdateLiveStatus())
        .map((site) => MapEntry(site.liveSite, <LiveRoom>[]))
        .toList();
    var batchUpdateSiteMap = Map.fromEntries(tmp);
    var unBatchUpdateRooms = roomList;
    bool hasError = false;
    if (batchUpdateSiteMap.isNotEmpty) {
      unBatchUpdateRooms = <LiveRoom>[];
      for (final room in roomList) {
        if (room.roomId == "") {
          continue;
        }
        var liveSite = Sites.of(room.platform!).liveSite;
        if (liveSite.isSupportBatchUpdateLiveStatus()) {
          batchUpdateSiteMap[liveSite]!.add(room);
        } else {
          unBatchUpdateRooms.add(room);
        }
      }
      // 批量更新
      List<Future<List<LiveRoom>>> futures = [];
      batchUpdateSiteMap.forEach((liveSite, list) {
        futures.add(liveSite.getLiveRoomDetailList(list: list));
      });
      try {
        for (var i = 0; i < futures.length; i++) {
          final rooms = await futures[i];
          updatedRoomList.addAll(rooms);
        }
      } catch (e) {
        CoreLog.error(e);
        hasError = true;
      }
    }
    List<Future<LiveRoom>> futures = [];
    for (final room in unBatchUpdateRooms) {
      if (room.roomId == "") {
        continue;
      }
      futures.add(Sites.of(room.platform!).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!));
    }
    List<List<Future<LiveRoom>>> groupedList = [];
    // 每次循环处理三个元素
    for (int i = 0; i < futures.length; i += 3) {
      int end = i + 3;
      if (end > futures.length) {
        end = futures.length;
      }
      List<Future<LiveRoom>> subList = futures.sublist(i, end);
      groupedList.add(subList);
    }
    try {
      for (var i = 0; i < groupedList.length; i++) {
        final rooms = await Future.wait(groupedList[i]);
        updatedRoomList.addAll(rooms);
      }
    } catch (e) {
      CoreLog.error(e);
      hasError = true;
    }
    // 统一更新到收藏列表
    for (var updated in updatedRoomList) {
      favCtrl.updateRoom(updated);
    }
    return hasError;
  }
}
