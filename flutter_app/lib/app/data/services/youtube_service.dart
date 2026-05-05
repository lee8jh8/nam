import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  // 노래 검색 (유튜브 영상 검색)
  Future<List<Video>> searchSongs(String query) async {
    final searchResults = await _yt.search.search(query);
    return searchResults.toList();
  }

  // 비디오 상세 정보 가져오기
  Future<Video> getVideoDetails(String videoId) async {
    return await _yt.videos.get(videoId);
  }

  // 연관 동영상 가져오기 (다음 곡 재생용)
  Future<List<Video>> getRelatedVideos(Video video) async {
    try {
      var related = await _yt.videos.getRelatedVideos(video);
      return related?.toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  // 오디오 스트림 URL 여러 개(Fallback 용) 추출
  Future<List<String>> getAudioStreamUrls(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      List<String> urls = [];
      
      // 1순위: iOS AVPlayer 네이티브 호환성이 가장 높은 Progressive 방식(Muxed) 스트림
      var muxedStreams = manifest.muxed.where((stream) => stream.container.name == 'mp4').toList();
      if (muxedStreams.isNotEmpty) {
        urls.add(muxedStreams.first.url.toString()); // 통상 360p
        if (muxedStreams.length > 1) {
          urls.add(muxedStreams.last.url.toString()); // 다른 해상도의 Muxed
        }
      }
      
      // 2순위: mp4 컨테이너의 오디오 전용 스트림
      var audioMp4 = manifest.audioOnly.where((stream) => stream.container.name == 'mp4').toList();
      if (audioMp4.isNotEmpty) {
        urls.add(audioMp4.withHighestBitrate().url.toString());
      }
      
      // 3순위: 그 외 전체 오디오 (webm 포함)
      if (manifest.audioOnly.isNotEmpty) {
        urls.add(manifest.audioOnly.withHighestBitrate().url.toString());
      }

      return urls;
    } catch (e) {
      print('Error getting audio stream urls: $e');
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
