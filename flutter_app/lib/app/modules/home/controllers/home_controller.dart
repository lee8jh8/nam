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
    isLoading.value = true;
    try {
      // 최신 인기곡 목업 검색 (실제 차트 API 연동 전 임시)
      var results = await _ytService.searchSongs("top hits kpop official audio");
      
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
