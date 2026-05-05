import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsController extends GetxController {
  var backgroundPlayEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    var box = Hive.box('settings');
    backgroundPlayEnabled.value = box.get('bg_play_enabled', defaultValue: true);
  }

  void toggleBackgroundPlay(bool val) {
    backgroundPlayEnabled.value = val;
    Hive.box('settings').put('bg_play_enabled', val);
    Get.snackbar('설정 변경', val ? '백그라운드 재생이 켜졌습니다.' : '백그라운드 재생이 꺼졌습니다.', 
      snackPosition: SnackPosition.TOP, 
      backgroundColor: const Color(0xFF2B1A4A), 
      colorText: Colors.white);
  }

  Future<void> openBuyMeACoffee() async {
    final Uri url = Uri.parse('https://www.buymeacoffee.com/lee8jh8');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      Get.snackbar('오류', '링크를 열 수 없습니다.', snackPosition: SnackPosition.TOP, backgroundColor: const Color(0xFFE57373), colorText: Colors.white);
    }
  }
}
