import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/translations/app_translations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'app/bindings/global_binding.dart';
import 'app/data/services/audio_handler.dart';

late MyAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('playlists');
  
  // 백그라운드 오디오 재생을 위한 AudioSession 설정
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  
  // 오디오 포커스 중단 시 대응 (전화, 타 앱 재생 등)
  session.interruptionEventStream.listen((event) {
    if (event.begin) {
       if (kDebugMode) print('[Main] Audio interruption began');
       audioHandler.pause();
    } else {
       if (kDebugMode) print('[Main] Audio interruption ended');
       if (event.type == AudioInterruptionType.pause) {
         audioHandler.play();
       }
    }
  });

  // AudioService 초기화
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.nam.music.music_app.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      artDownscaleWidth: 300,
      artDownscaleHeight: 300,
    ),
  );

  // 앱 실행 시 오디오 세션 즉시 활성화 (시스템에 우리 앱이 메인임을 알림)
  await session.setActive(true);
  
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Sonic Flow',
      initialBinding: GlobalBinding(),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF1DB954),
        cardColor: const Color(0xFF1A1A1A),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFB3B3B3)),
        ),
      ),
      translations: AppTranslations(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en', 'US'),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}
