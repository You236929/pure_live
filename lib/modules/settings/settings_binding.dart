import 'package:get/get.dart';
import 'package:pure_live/common/services/settings_service.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsService>(
      SettingsService.new,
    );
  }
}
