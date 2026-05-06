import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/services/youtube_service.dart';

class HomeController extends GetxController {
  final YouTubeService _ytService = YouTubeService();
  var trendingSongs = <Video>[].obs;
  var recentPlayed = <Map>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadRecentPlayed();
    fetchTrending();
  }

  void loadRecentPlayed() {
    var box = Hive.box('settings');
    List history = box.get('recent_played', defaultValue: []);
    recentPlayed.assignAll(history.cast<Map>());
  }

  void fetchTrending() async {
    if (trendingSongs.isNotEmpty) return;
    isLoading.value = true;
    try {
      // 실제 유튜브의 최신 인기 음악을 검색해서 가져옴 (모음집 제외 필터링 적용됨)
      var results = await _ytService.getTrendingMusic();
      
      // 제목 정제(Parsing) 로직: [MV], (Official Video) 등 제거
      var cleanedResults = results.toList();
      trendingSongs.assignAll(cleanedResults.take(10));
    } catch (e) {
      print(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<Video?> fetchVideoDetail(String videoId) async {
    try {
      return await _ytService.getVideoDetails(videoId);
    } catch (e) {
      return null;
    }
  }

  String parseTitle(String rawTitle) {
    // 불필요한 태그 제거 정규식
    final regex = RegExp(r'(\[.*?\]|\(.*?\)|official|music video|mv|audio|lyric)', caseSensitive: false);
    return rawTitle.replaceAll(regex, '').trim();
  }
}
