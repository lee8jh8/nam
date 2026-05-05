import 'package:get/get.dart';
import '../modules/home/views/home_view.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/search/views/search_view.dart';
import '../modules/player/views/player_view.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/settings/controllers/settings_controller.dart';

class AppPages {
  static const INITIAL = '/splash';

  static final routes = [
    GetPage(
      name: '/splash',
      page: () => const SplashView(),
    ),
    GetPage(
      name: '/home',
      page: () => HomeView(),
    ),
    GetPage(
      name: '/search',
      page: () => SearchView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: '/player',
      page: () => const PlayerView(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 100),
    ),
    GetPage(
      name: '/settings',
      page: () => const SettingsView(),
      binding: BindingsBuilder(() {
        Get.put(SettingsController());
      }),
      transition: Transition.rightToLeft,
    ),
  ];
}
