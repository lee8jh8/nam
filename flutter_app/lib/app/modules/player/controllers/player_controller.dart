import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt_iframe;
import '../../../data/services/youtube_service.dart';
import '../../home/controllers/home_controller.dart';

class PlayerController extends GetxController with WidgetsBindingObserver {
  final AudioPlayer audioPlayer = AudioPlayer();
  final YouTubeService _ytService = YouTubeService();
  
  yt_iframe.YoutubePlayerController? ytWebController;
  var useWebViewFallback = false.obs;

  var isPlaying = false.obs;
  var currentVideo = Rxn<Video>();
  var duration = Duration.zero.obs;
  var position = Duration.zero.obs;
  var isLoading = false.obs;
  var loadingPercent = 0.obs;

  var queue = <Video>[].obs;
  var historyStack = <Video>[].obs;
  
  bool _cancelCurrentLoad = false;
  bool _isFetchingQueue = false;
  Timer? _loadingTimer;

  void _startLoadingProgress() {
    loadingPercent.value = 0;
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (loadingPercent.value < 90) {
        loadingPercent.value += 3;
      }
    });
  }

  void _stopLoadingProgress() {
    _loadingTimer?.cancel();
    loadingPercent.value = 100;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      var box = Hive.box('settings');
      bool bgPlayEnabled = box.get('bg_play_enabled', defaultValue: true);
      if (!bgPlayEnabled) {
        if (audioPlayer.playing) audioPlayer.pause();
        if (useWebViewFallback.value && ytWebController != null && isPlaying.value) {
          ytWebController!.pauseVideo();
        }
      }
    }
  }

  Future<void> _fetchRelatedAndFillQueue(Video video) async {
    if (_isFetchingQueue) return;
    _isFetchingQueue = true;

    try {
      var related = await _ytService.getRelatedVideos(video);
      related.removeWhere((v) => v.id.value == video.id.value);
      if (related.isNotEmpty) {
        queue.addAll(related);
        _isFetchingQueue = false;
        return;
      }
    } catch (_) {}
    
    try {
      var artist = video.parsedArtist;
      if (artist.isNotEmpty) {
        var searchResults = await _ytService.searchSongs(artist);
        var historyIds = historyStack.map((e) => e.id.value).toSet();
        var queueIds = queue.map((e) => e.id.value).toSet();
        searchResults.removeWhere((v) => 
            v.id.value == video.id.value || 
            historyIds.contains(v.id.value) || 
            queueIds.contains(v.id.value));
            
        if (searchResults.isNotEmpty) {
          searchResults.shuffle();
          queue.addAll(searchResults.take(10));
          _isFetchingQueue = false;
          return;
        }
      }
    } catch (_) {}

    // 최후의 보루: 홈 컨트롤러의 최신 인기곡 중 선택
    try {
      if (Get.isRegistered<HomeController>()) {
        var trending = Get.find<HomeController>().trendingSongs.toList();
        var historyIds = historyStack.map((e) => e.id.value).toSet();
        var queueIds = queue.map((e) => e.id.value).toSet();
        trending.removeWhere((v) => 
            v.id.value == video.id.value || 
            historyIds.contains(v.id.value) || 
            queueIds.contains(v.id.value));
            
        if (trending.isNotEmpty) {
          trending.shuffle();
          queue.addAll(trending.take(5));
        }
      }
    } catch (_) {}

    _isFetchingQueue = false;
  }

  Future<void> playNext() async {
    if (currentVideo.value != null) {
      historyStack.add(currentVideo.value!);
    }
    
    if (queue.isNotEmpty) {
      var nextVideo = queue.removeAt(0);
      await playVideo(nextVideo, isFromQueue: true);
      if (queue.length < 3) {
        _fetchRelatedAndFillQueue(nextVideo);
      }
    } else {
      if (currentVideo.value != null) {
        await _fetchRelatedAndFillQueue(currentVideo.value!);
        if (queue.isNotEmpty) {
          var nextVideo = queue.removeAt(0);
          await playVideo(nextVideo, isFromQueue: true);
        }
      }
    }
  }

  Future<void> playPrevious() async {
    // 3초 이상 재생되었으면 현재 곡의 처음으로 이동 (재로딩/데이터 재요청 없음)
    if (position.value > const Duration(seconds: 3)) {
      if (useWebViewFallback.value && ytWebController != null) {
        ytWebController!.seekTo(seconds: 0.0);
      } else {
        await audioPlayer.seek(Duration.zero);
      }
      return;
    }

    // 3초 미만이면 이전 곡 재생
    if (historyStack.isNotEmpty) {
      var prevVideo = historyStack.removeLast();
      if (currentVideo.value != null) {
        queue.insert(0, currentVideo.value!);
      }
      await playVideo(prevVideo, isFromQueue: true);
    } else {
      // 이전 곡이 없으면 무조건 처음으로 이동
      if (useWebViewFallback.value && ytWebController != null) {
        ytWebController!.seekTo(seconds: 0.0);
      } else {
        await audioPlayer.seek(Duration.zero);
      }
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

  Future<void> playVideo(Video video, {bool isFromQueue = false}) async {
    // 이전 재생 완전히 중지 (중복 재생 방지)
    try {
      if (audioPlayer.playing) await audioPlayer.stop();
      if (ytWebController != null) ytWebController!.stopVideo();
    } catch (_) {}
    useWebViewFallback.value = false;
    isPlaying.value = false;

    if (!isFromQueue && currentVideo.value != null) {
      historyStack.add(currentVideo.value!);
      queue.clear();
      _fetchRelatedAndFillQueue(video);
    } else if (!isFromQueue && currentVideo.value == null) {
      _fetchRelatedAndFillQueue(video);
    }

    _cancelCurrentLoad = false;
    _startLoadingProgress();
    isLoading.value = true;
    currentVideo.value = video;
    
    final urls = await _ytService.getAudioStreamUrls(video.id.value);
    
    if (_cancelCurrentLoad) {
      isLoading.value = false;
      _stopLoadingProgress();
      return;
    }
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
      Get.snackbar(
        '우회 재생', 
        '네이티브 재생 불가 곡입니다. 웹뷰 모드로 우회 재생합니다.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF2B1A4A),
        colorText: Colors.white,
      );
      print('Native Stream 시도 실패. 숨겨진 WebView Player(Fallback)로 전환합니다.');
      _initWebViewFallback(video.id.value);
      _addToRecentlyPlayed(video);
      success = true;
      audioPlayer.stop(); // just_audio 중단
    }
    
    _stopLoadingProgress();
    isLoading.value = false;
  }

  void _addToRecentlyPlayed(Video video) {
    var box = Hive.box('settings');
    List history = box.get('recent_played', defaultValue: []);
    var videoMap = {
      'id': video.id.value,
      'title': video.parsedSongName,
      'author': video.parsedArtist,
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
    if (isLoading.value) {
      _cancelCurrentLoad = true;
      isLoading.value = false;
      _stopLoadingProgress();
      try {
        audioPlayer.stop();
        if (ytWebController != null) ytWebController!.stopVideo();
      } catch (_) {}
      return;
    }

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
    WidgetsBinding.instance.removeObserver(this);
    audioPlayer.dispose();
    _ytService.dispose();
    super.onClose();
  }
}

extension VideoTitleParsing on Video {
  String get parsedTitle {
    String raw = title;
    raw = raw.replaceAll(RegExp(r'(\[.*?\]|\(.*?\)|【.*?】|MV|Official|Video|Audio|Lyrics|가사|Music)', caseSensitive: false), '').trim();
    
    if (raw.isEmpty) return title;
    
    if (raw.contains(RegExp(r'\s-\s'))) {
      return raw;
    } else if (raw.contains('-')) {
      var parts = raw.split('-');
      return '${parts[0].trim()} - ${parts.sublist(1).join('-').trim()}';
    }
    
    String auth = author.replaceAll(RegExp(r'(- Topic|Topic|VEVO|Official)', caseSensitive: false), '').trim();
    if (auth.isEmpty || raw.toLowerCase().contains(auth.toLowerCase())) return raw;
    return '$auth - $raw';
  }

  String get parsedArtist {
    String pt = parsedTitle;
    if (pt == title || pt.isEmpty) return author;
    if (pt.contains('-')) {
      var artist = pt.split('-')[0].trim();
      return artist.isEmpty ? author : artist;
    }
    return author.replaceAll(RegExp(r'(- Topic|Topic|VEVO|Official)', caseSensitive: false), '').trim();
  }

  String get parsedSongName {
    String pt = parsedTitle;
    if (pt == title || pt.isEmpty) return title;
    if (pt.contains('-')) {
      var song = pt.split('-').sublist(1).join('-').trim();
      return song.isEmpty ? title : song;
    }
    return pt;
  }
}
