import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularGridView extends StatefulWidget {
  final String tag;

  const PopularGridView(this.tag, {Key? key}) : super(key: key);

  @override
  State<PopularGridView> createState() => _PopularGridViewState();
}

class _PopularGridViewState extends State<PopularGridView> {
  PopularGridController get controller =>
      Get.find<PopularGridController>(tag: widget.tag);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount =
            width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                event.scrollDelta.direction >= 0 &&
                event.scrollDelta.direction <= pi) {
              final pos = controller.scrollController.position;
              if (pos.maxScrollExtent - pos.pixels < 40) {
                controller.onLoading();
              }
            }
          },
          child: Obx(() => SmartRefresher(
                enablePullDown: true,
                enablePullUp: true,
                header: const WaterDropHeader(),
                footer: const ClassicFooter(),
                controller: controller.refreshController,
                onRefresh: controller.onRefresh,
                onLoading: controller.onLoading,
                child: controller.list.isNotEmpty
                    ? MasonryGridView.count(
                        padding: const EdgeInsets.all(5),
                        controller: controller.scrollController,
                        crossAxisCount: crossAxisCount,
                        itemCount: controller.list.length,
                        itemBuilder: (context, index) => RoomCard(
                          room: controller.list[index],
                          dense: true,
                        ),
                      )
                    : EmptyView(
                        icon: Icons.live_tv_rounded,
                        title: S.of(context).empty_live_title,
                        subtitle: S.of(context).empty_live_subtitle,
                      ),
              )),
        );
      },
    );
  }
}
