import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  // 노래 검색 (VideoSearchList 반환으로 페이지네이션 지원)
  // v2.x에서는 search.getVideos(query)가 VideoSearchList(Iterable<Video>)를 반환함
  Future<VideoSearchList> searchSongs(String query) async {
    return await _yt.search.getVideos(query);
  }

  // 최신 인기곡 가져오기 (10분 이하 공식 오디오/MV만 필터링)
  Future<List<Video>> getTrendingMusic() async {
    try {
      var searchResults = await _yt.search.getVideos('인기 급상승 음악 Kpop Official MV');
      return searchResults.where((v) => v.duration != null && v.duration!.inMinutes < 10).toList();
    } catch (e) {
      return [];
    }
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

  // 오디오 스트림 URL 추출
  Future<List<String>> getAudioStreamUrls(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      List<String> urls = [];
      
      var muxedStreams = manifest.muxed.where((stream) => stream.container.name == 'mp4').toList();
      if (muxedStreams.isNotEmpty) {
        urls.add(muxedStreams.first.url.toString());
        if (muxedStreams.length > 1) {
          urls.add(muxedStreams.last.url.toString());
        }
      }
      
      var audioMp4 = manifest.audioOnly.where((stream) => stream.container.name == 'mp4').toList();
      if (audioMp4.isNotEmpty) {
        urls.add(audioMp4.withHighestBitrate().url.toString());
      }
      
      if (manifest.audioOnly.isNotEmpty) {
        urls.add(manifest.audioOnly.withHighestBitrate().url.toString());
      }

      return urls;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
