import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/services/youtube_service.dart';
import '../../../data/services/lastfm_service.dart';
import '../../../data/services/apple_music_service.dart';

class HomeController extends GetxController {
  final YouTubeService _ytService = YouTubeService();
  final LastFmService _lastFmService = LastFmService();
  final AppleMusicService _appleService = AppleMusicService();

  // Last.fm에서 받은 트랙 목록
  var trendingSongs = <LastFmTrack>[].obs;
  var recentPlayed = <Map>[].obs;
  
  var isLoading = true.obs;
  var isMoreLoading = false.obs;
  var currentPage = 1;
  bool _hasMore = true;

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

  /// 최초 인기곡 가져오기
  Future<void> fetchTrending() async {
    if (trendingSongs.isNotEmpty) return;
    isLoading.value = true;
    currentPage = 1;
    _hasMore = true;

    try {
      String countryCode = Get.deviceLocale?.countryCode ?? 'KR';
      String countryName = _getCountryName(countryCode);
      
      var tracks = await _lastFmService.getTopTracksByCountry(countryName, limit: 20, page: currentPage);
      
      if (tracks.isEmpty) {
        tracks = await _lastFmService.getTopTracks(limit: 20, page: currentPage);
      }

      if (tracks.isNotEmpty) {
        trendingSongs.assignAll(tracks);
        isLoading.value = false; 
        _updateArtworks(tracks, startIndex: 0);
      }
    } catch (e) {
      if (kDebugMode) print('[Home] fetchTrending failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 추가 데이터 로드 (무한 스크롤)
  Future<void> fetchMoreTrending() async {
    if (isMoreLoading.value || !_hasMore) return;
    isMoreLoading.value = true;
    currentPage++;

    try {
      String countryCode = Get.deviceLocale?.countryCode ?? 'KR';
      String countryName = _getCountryName(countryCode);
      
      var newTracks = await _lastFmService.getTopTracksByCountry(countryName, limit: 20, page: currentPage);
      
      if (newTracks.isEmpty) {
        newTracks = await _lastFmService.getTopTracks(limit: 20, page: currentPage);
      }

      if (newTracks.isNotEmpty) {
        final int startIndex = trendingSongs.length;
        trendingSongs.addAll(newTracks);
        _updateArtworks(newTracks, startIndex: startIndex);
      } else {
        _hasMore = false;
      }
    } catch (e) {
      if (kDebugMode) print('[Home] fetchMoreTrending failed: $e');
      currentPage--;
    } finally {
      isMoreLoading.value = false;
    }
  }

  /// iTunes Search API를 통해 각 트랙의 썸네일 업데이트 (병렬 처리)
  Future<void> _updateArtworks(List<LastFmTrack> tracks, {required int startIndex}) async {
    final List<Future> tasks = [];
    
    for (int i = 0; i < tracks.length; i++) {
      tasks.add(() async {
        try {
          final track = tracks[i];
          final artworkUrl = await _appleService.getTrackArtwork(track.artist, track.name);
          
          if (artworkUrl != null) {
            final targetIndex = startIndex + i;
            if (targetIndex < trendingSongs.length) {
              trendingSongs[targetIndex] = track.copyWith(imageUrl: artworkUrl);
            }
          }
        } catch (_) {}
      }());
    }
    await Future.wait(tasks);
  }

  String _getCountryName(String code) {
    final Map<String, String> countryMap = {
      'KR': 'South Korea', 'US': 'United States', 'JP': 'Japan', 'GB': 'United Kingdom',
      'FR': 'France', 'DE': 'Germany', 'ES': 'Spain', 'IT': 'Italy', 'CA': 'Canada',
      'AU': 'Australia', 'BR': 'Brazil', 'RU': 'Russia', 'IN': 'India', 'MX': 'Mexico',
      'ID': 'Indonesia', 'VN': 'Vietnam', 'TH': 'Thailand',
    };
    return countryMap[code.toUpperCase()] ?? 'South Korea';
  }

  Future<Video?> searchAndGetVideo(LastFmTrack track) async {
    try {
      final query = '${track.name} ${track.artist}';
      final results = await _ytService.searchSongs(query);
      final filtered = results.where((v) => v.duration != null && v.duration!.inMinutes < 10).toList();
      return filtered.isNotEmpty ? filtered.first : results.firstOrNull;
    } catch (e) {
      return null;
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
    final regex = RegExp(r'(\[.*?\]|\(.*?\)|official|music video|mv|audio|lyric)', caseSensitive: false);
    return rawTitle.replaceAll(regex, '').trim();
  }
}
