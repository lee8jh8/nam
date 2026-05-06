import 'package:get/get.dart';
import '../modules/home/controllers/home_controller.dart';
import '../modules/player/controllers/player_controller.dart';
import '../modules/settings/controllers/settings_controller.dart';

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(PlayerController(), permanent: true);
    Get.put(HomeController(), permanent: true);
    Get.lazyPut(() => SettingsController());
  }
}
