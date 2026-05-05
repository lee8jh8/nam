import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../data/services/youtube_service.dart';
import '../../home/controllers/home_controller.dart';

class PlayerController extends GetxController {
  final AudioPlayer audioPlayer = AudioPlayer();
  final YouTubeService _ytService = YouTubeService();
  
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

  Future<void> playVideo(Video video) async {
    isLoading.value = true;
    currentVideo.value = video;
    
    final url = await _ytService.getAudioStreamUrl(video.id.value);
    if (url != null) {
      try {
        await audioPlayer.setAudioSource(AudioSource.uri(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1'},
        ));
        audioPlayer.play();
        _addToRecentlyPlayed(video);
      } catch (e) {
        print('Playback error: $e');
      }
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
