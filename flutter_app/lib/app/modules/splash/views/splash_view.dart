import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/splash_controller.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SplashController());
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고 아이콘
            const Icon(
              Icons.graphic_eq,
              size: 80,
              color: Color(0xFF1DB954),
            ).animate()
              .scale(duration: 800.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 800.ms),
            const SizedBox(height: 24),
            // 브랜드 이름
            const Text(
              'SONIC FLOW',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
                color: Colors.white,
              ),
            ).animate()
              .slideY(begin: 0.5, end: 0, duration: 800.ms, curve: Curves.easeOut)
              .fadeIn(duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
