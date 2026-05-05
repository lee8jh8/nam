import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _navigateToHome();
  }

  void _navigateToHome() async {
    // 2초 딜레이 후 인증 없이 바로 홈 화면 이동
    await Future.delayed(const Duration(seconds: 2));
    Get.offAllNamed('/home');
  }
}
