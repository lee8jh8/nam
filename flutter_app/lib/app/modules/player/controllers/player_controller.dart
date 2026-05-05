import 'dart:async';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt_iframe;
import '../../../data/services/youtube_service.dart';
import '../../home/controllers/home_controller.dart';

class PlayerController extends GetxController {
  final AudioPlayer audioPlayer = AudioPlayer();
  final YouTubeService _ytService = YouTubeService();
  
  yt_iframe.YoutubePlayerController? ytWebController;
  var useWebViewFallback = false.obs;

  var isPlaying = false.obs;
  var currentVideo = Rxn<Video>();
  var duration = Duration.zero.obs;
  var position = Duration.zero.obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    audioPlayer.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      // 곡 재생이 끝나면 자동으로 다음 곡 재생
      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
    });
    audioPlayer.positionStream.listen((pos) {
      position.value = pos;
    });
    audioPlayer.durationStream.listen((dur) {
      duration.value = dur ?? Duration.zero;
    });
  }

  Future<void> playNext() async {
    if (currentVideo.value == null) return;
    try {
      var related = await _ytService.getRelatedVideos(currentVideo.value!);
      if (related.isNotEmpty) {
        await playVideo(related.first);
      }
    } catch (e) {
      print('Play next error: $e');
    }
  }

  void _initWebViewFallback(String videoId) {
    useWebViewFallback.value = true;
    if (ytWebController == null) {
      ytWebController = yt_iframe.YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const yt_iframe.YoutubePlayerParams(
          showControls: false,
          mute: false,
          showFullscreenButton: false,
          loop: false,
          playsInline: true,
        ),
      );
      
      ytWebController!.listen((event) {
        if (event.playerState == yt_iframe.PlayerState.playing) {
          isPlaying.value = true;
        } else if (event.playerState == yt_iframe.PlayerState.paused) {
          isPlaying.value = false;
        } else if (event.playerState == yt_iframe.PlayerState.ended) {
          playNext();
        }
        duration.value = event.metaData.duration;
      });
      
      Stream.periodic(const Duration(seconds: 1)).listen((_) async {
        if (useWebViewFallback.value && isPlaying.value && ytWebController != null) {
          final pos = await ytWebController!.currentTime;
          position.value = Duration(seconds: pos.toInt());
        }
      });
    } else {
      ytWebController!.loadVideoById(videoId: videoId);
    }
  }

  Future<void> playVideo(Video video) async {
    isLoading.value = true;
    currentVideo.value = video;
    
    final urls = await _ytService.getAudioStreamUrls(video.id.value);
    bool success = false;
    
    for (String url in urls) {
      try {
        // 시도 1: User-Agent 주입 (차단 우회)
        await audioPlayer.setAudioSource(AudioSource.uri(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1'},
        ));
        audioPlayer.play();
        _addToRecentlyPlayed(video);
        success = true;
        break; // 성공 시 루프 탈출
      } catch (e) {
        print('Playback error with headers: $e');
        // 시도 2: 헤더 제거 (AVPlayer 자체 처리 유도)
        try {
          await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
          audioPlayer.play();
          _addToRecentlyPlayed(video);
          success = true;
          break; // 성공 시 루프 탈출
        } catch (e2) {
          print('Playback error without headers: $e2');
          // 다음 Fallback URL로 넘어감
        }
      }
    }

    if (!success) {
      print('Native Stream 시도 실패. 숨겨진 WebView Player(Fallback)로 전환합니다.');
      _initWebViewFallback(video.id.value);
      _addToRecentlyPlayed(video);
      success = true;
      audioPlayer.stop(); // just_audio 중단
    }
    
    isLoading.value = false;
  }

  void _addToRecentlyPlayed(Video video) {
    var box = Hive.box('settings');
    List history = box.get('recent_played', defaultValue: []);
    var videoMap = {
      'id': video.id.value,
      'title': video.title,
      'author': video.author,
      'thumbnail': video.thumbnails.lowResUrl,
    };
    history.removeWhere((v) => v['id'] == video.id.value);
    history.insert(0, videoMap);
    if (history.length > 10) history = history.sublist(0, 10);
    box.put('recent_played', history);
    
    // HomeController가 초기화되어 있다면 데이터 갱신
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().loadRecentPlayed();
    }
  }

  void togglePlay() {
    if (useWebViewFallback.value && ytWebController != null) {
      if (isPlaying.value) {
        ytWebController!.pauseVideo();
      } else {
        ytWebController!.playVideo();
      }
      return;
    }

    if (audioPlayer.playing) {
      audioPlayer.pause();
    } else {
      audioPlayer.play();
    }
  }

  @override
  void onClose() {
    audioPlayer.dispose();
    _ytService.dispose();
    super.onClose();
  }
}
