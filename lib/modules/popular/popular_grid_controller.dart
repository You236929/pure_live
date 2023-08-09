import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/index.dart';

class PopularGridController extends BaseListController<LiveRoom> {
  final Site site;

  PopularGridController(
    this.site,
  );

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    return await site.liveSite.getRecommend(page: page, size: pageSize);
  }

  void clear() {
    pageEmpty.value = false;
    list.clear();
  }
}
