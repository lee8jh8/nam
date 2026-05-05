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

  // 최고 음질의 오디오 스트림 URL 추출
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // iOS AVPlayer는 DASH(Fragmented MP4/WebM) 오디오 스트림을 기본 지원하지 않아 Cannot Open 에러가 발생합니다.
      // 이를 완벽히 해결하기 위해 네이티브 호환성이 있는 Progressive 방식인 Muxed(비디오+오디오) 스트림을 사용합니다.
      var muxedStreams = manifest.muxed.where((stream) => stream.container.name == 'mp4').toList();
      if (muxedStreams.isEmpty) return null;
      
      // 데이터 절약 및 안정적 버퍼링을 위해 제일 낮은 화질(통상 360p)의 mp4를 선택합니다.
      var streamInfo = muxedStreams.first;
      return streamInfo.url.toString();
    } catch (e) {
      print('Error getting audio stream: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}
