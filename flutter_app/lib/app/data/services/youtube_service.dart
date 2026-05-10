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
        if (attempt >= maxRetries) return [];
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
        return s >= 120 && s < 540; // 2분 이상 9분 미만
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
      var related = await _yt.videos.getRelatedVideos(video);
      if (related == null) return [];
      return related.where((v) {
        if (v.duration == null) return false;
        final s = v.duration!.inSeconds;
        return s >= 120 && s < 540;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
