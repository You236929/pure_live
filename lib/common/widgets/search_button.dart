import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

import '../../routes/app_pages.dart';

class SearchButton extends StatelessWidget {
  const SearchButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Get.toNamed(AppPages.search),
      icon: const Icon(CustomIcons.search),
    );
  }
}
