import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('설정', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const Text('재생 옵션', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Obx(() => SwitchListTile(
            title: const Text('백그라운드 음악 재생', style: TextStyle(color: Colors.white)),
            subtitle: const Text('앱을 화면에서 내려도 음악을 계속 재생합니다.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: controller.backgroundPlayEnabled.value,
            onChanged: (val) => controller.toggleBackgroundPlay(val),
            activeColor: Colors.deepPurpleAccent,
            activeTrackColor: Colors.white,
            contentPadding: EdgeInsets.zero,
          )),
          const Divider(color: Colors.white24, height: 40),
          const Text('개발자 후원', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.coffee, color: Colors.orangeAccent, size: 32),
            title: const Text('개발자에게 커피 사주기', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Buy me a coffee', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 20),
            onTap: () => controller.openBuyMeACoffee(),
          ),
        ],
      ),
    );
  }
}
