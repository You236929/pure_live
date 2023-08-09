import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';

import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BaseController extends GetxController {
  /// 加载中，更新页面
  var pageLoadding = false.obs;

  /// 加载中,不会更新页面
  var loadding = false;

  /// 空白页面
  var pageEmpty = false.obs;

  /// 页面错误
  var pageError = false.obs;

  /// 未登录
  var notLogin = false.obs;

  /// 错误信息
  var errorMsg = "".obs;

  /// 显示错误
  /// * [msg] 错误信息
  /// * [showPageError] 显示页面错误
  /// * 只在第一页加载错误时showPageError=true，后续页加载错误时使用Toast弹出通知
  void handleError(Object exception, {bool showPageError = false}) {
    log(exception.toString(), stackTrace: StackTrace.current);
    var msg = exceptionToString(exception);

    if (showPageError) {
      pageError.value = true;
      errorMsg.value = msg;
    } else {
      Get.rawSnackbar(message: exceptionToString(msg));
    }
  }

  String exceptionToString(Object exception) {
    return exception.toString().replaceAll("Exception:", "");
  }

  void onLogin() {}
  void onLogout() {}
}

class BaseListController<T> extends BaseController {
  final ScrollController scrollController = ScrollController();
  final RefreshController refreshController = RefreshController();
  int currentPage = 1;
  int count = 0;
  int maxPage = 0;
  int pageSize = 24;
  var canLoadMore = false.obs;
  var list = <T>[].obs;

  @override
  void onInit() {
    super.onInit();
    onRefresh();
  }

  Future onRefresh() async {
    currentPage = 1;
    list.value = [];

    try {
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      pageLoadding.value = currentPage == 1;

      var result = await getData(currentPage, pageSize);
      // 是否可以加载更多
      if (result.isNotEmpty) {
        currentPage++;
        canLoadMore.value = true;
        pageEmpty.value = false;
        refreshController.refreshCompleted();
      } else {
        pageEmpty.value = true;
        refreshController.refreshFailed();
      }
      // 赋值数据
      list.value = result;
    } catch (e) {
      handleError(e, showPageError: currentPage == 1);
      refreshController.refreshFailed();
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  Future onLoading() async {
    try {
      if (loadding) return;
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      pageLoadding.value = currentPage == 1;

      var result = await getData(currentPage, pageSize);
      // 是否可以加载更多
      if (result.isNotEmpty) {
        currentPage++;
        canLoadMore.value = true;
        pageEmpty.value = false;
        refreshController.loadComplete();
      } else {
        canLoadMore.value = false;
        pageEmpty.value = currentPage == 1;
        refreshController.loadNoData();
      }
      // 赋值数据
      for (var room in result) {
        list.addIf(!list.contains(room), room);
      }
    } catch (e) {
      handleError(e, showPageError: currentPage == 1);
      refreshController.loadFailed();
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  Future<List<T>> getData(int page, int pageSize) async {
    return [];
  }

  void scrollToTopOrRefresh() {
    if (scrollController.offset > 0) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
    } else {
      refreshController.requestRefresh();
    }
  }
}
