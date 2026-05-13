import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  // ... (다른 메서드들은 동일)

  // 오디오 스트림 URL 추출 (재시도 로직 포함하여 백그라운드 안정성 강화)
  Future<List<String>> getAudioStreamUrls(String videoId, {int maxRetries = 3}) async {
    int attempt = 0;
    print('[YouTubeService] Attempting to fetch audio streams for: $videoId');
    
    while (attempt < maxRetries) {
      try {
        var manifest = await _yt.videos.streamsClient.getManifest(videoId);
        print('[YouTubeService] getManifest completed successfully for: $videoId');
        List<String> urls = [];
        
        // YouTube의 최근 봇 보호 로직(PO-Token 등)으로 인해 audioOnly 스트림이 403 에러를 자주 발생시킵니다.
        // muxed(비디오+오디오) mp4 스트림은 이러한 검사를 우회할 수 있으므로 최우선으로 사용합니다.
        final muxedStreams = manifest.muxed.where((s) => s.container.name.toLowerCase().contains('mp4')).toList();
        if (muxedStreams.isNotEmpty) {
          // 화질이 낮을수록 오디오 로딩 속도가 빠르므로 용량이 작은 것을 우선
          muxedStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
          for (var stream in muxedStreams) {
            urls.add(stream.url.toString());
          }
        }

        // 그 다음으로 audioOnly 중 mp4/m4a 컨테이너 탐색 (혹시 muxed가 실패할 경우 대비)
        final m4aStreams = manifest.audioOnly.where((s) {
          final mime = s.codec.mimeType.toLowerCase();
          final containerName = s.container.name.toLowerCase();
          return mime.contains('mp4') || containerName.contains('mp4') || containerName.contains('m4a');
        }).toList();

        if (m4aStreams.isNotEmpty) {
          m4aStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
          for (var stream in m4aStreams) {
            urls.add(stream.url.toString());
          }
        } else if (manifest.audioOnly.isNotEmpty) {
          final otherStreams = manifest.audioOnly.toList();
          otherStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
          for (var stream in otherStreams) {
            urls.add(stream.url.toString());
          }
        }

        if (urls.isNotEmpty) {
          return urls;
        }
      } catch (e) {
        attempt++;
        print('[YouTubeService] Error fetching manifest (Attempt $attempt/$maxRetries): $e');
        if (attempt >= maxRetries) {
          // 모든 재시도 실패 시 에러를 던져 Controller가 다음 곡으로 넘어갈 수 있게 함
          throw Exception('STREAM_FETCH_FAILED');
        }
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }
    return [];
  }

  // ... (기존 메서드들)
  Future<VideoSearchList> searchSongs(String query) async {
    return await _yt.search.search(query);
  }

  Future<List<Video>> getTrendingMusic() async {
    try {
      var searchResults = await _yt.search.search('인기 급상승 음악 Kpop Official MV');
      return searchResults.where((v) {
        if (v.duration == null) return false;
        final s = v.duration!.inSeconds;
        return s >= 90 && s < 600; // 1분 30초 이상 10분 미만
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Video> getVideoDetails(String videoId) async {
    return await _yt.videos.get(videoId);
  }

  Future<List<Video>> getRelatedVideos(Video video) async {
    try {
      final videoId = video.id.value;
      if (kDebugMode) print('[YouTubeService] getRelatedVideos requested for ID: $videoId');
      
      List<Video> results = [];
      
      // 1단계: 전달받은 Video 객체로 직접 시도
      var relatedList = await _yt.videos.getRelatedVideos(video);
      
      // 2단계: 결과가 비어있다면, 전체 URL을 사용하여 Video 객체를 새로 가져온 후 재시도
      if (relatedList == null || relatedList.isEmpty) {
        if (kDebugMode) print('[YouTubeService] Related list empty. Fetching full video metadata via URL...');
        final fullVideo = await _yt.videos.get('https://youtube.com/watch?v=$videoId');
        relatedList = await _yt.videos.getRelatedVideos(fullVideo);
      }

      // 3단계: 여전히 비어있다면, 검색을 통한 Fallback 처리
      if (relatedList == null || relatedList.isEmpty) {
        if (kDebugMode) print('[YouTubeService] Falling back to search for similar content...');
        final query = '${video.title} ${video.author} related'.trim();
        final searchResults = await _yt.search.search(query);
        results = searchResults.toList();
      } else {
        results = relatedList.toList();
      }

      if (results.isEmpty) return [];

      if (kDebugMode) print('[YouTubeService] Processing ${results.length} candidates for metadata...');
      
      // 3.x 버전에서는 Video 객체에 duration이 포함되지 않는 경우가 많으므로 병렬로 상세 정보 조회
      // 성능을 위해 상위 25개만 조회
      final List<Future<Video?>> detailFutures = results.take(25).map((v) async {
        try {
          if (v.duration != null) return v;
          return await _yt.videos.get(v.id);
        } catch (_) {
          return null;
        }
      }).toList();

      final List<Video?> detailedVideos = await Future.wait(detailFutures);
      final List<Video> validVideos = detailedVideos.whereType<Video>().toList();

      // 관련 영상 필터링 (1분 30초 ~ 10분)
      final filtered = validVideos.where((v) {
        if (v.duration == null) return false;
        final s = v.duration!.inSeconds;
        return s >= 90 && s < 600;
      }).toList();
      
      return filtered.take(10).toList();
    } catch (e) {
      if (kDebugMode) print('[YouTubeService] getRelatedVideos Error: $e');
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
