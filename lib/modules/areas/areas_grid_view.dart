import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';

class AreaGridView extends StatefulWidget {
  const AreaGridView({Key? key, required this.labels, required this.areas})
      : super(key: key);

  final List<String> labels;
  final List<List<LiveArea>> areas;

  @override
  State<AreaGridView> createState() => _AreaGridViewState();
}

class _AreaGridViewState extends State<AreaGridView>
    with SingleTickerProviderStateMixin {
  late TabController tabController =
      TabController(length: widget.labels.length, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: tabController,
          isScrollable: true,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: widget.labels.map<Widget>((e) => Tab(text: e)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children:
                widget.areas.map<Widget>((e) => buildAreasView(e)).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildAreasView(List<LiveArea> area) {
    return LayoutBuilder(builder: (context, constraint) {
      final width = constraint.maxWidth;
      final crossAxisCount =
          width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
      return widget.areas.isNotEmpty
          ? MasonryGridView.count(
              padding: const EdgeInsets.all(5),
              controller: ScrollController(),
              crossAxisCount: crossAxisCount,
              itemCount: area.length,
              itemBuilder: (context, index) => AreaCard(area: area[index]),
            )
          : EmptyView(
              icon: Icons.area_chart_outlined,
              title: S.of(context).empty_areas_title,
              subtitle: S.of(context).empty_areas_subtitle,
            );
    });
  }
}
