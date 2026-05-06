import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // 재생 모드 관리
  var isPlaylistMode = false.obs;
  var playbackMode = '자동 재생'.obs;
  var isShuffle = false.obs;
  var repeatMode = 0.obs; // 0: None, 1: One, 2: All

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
      // WebView 폴백 모드일 때는 네이티브 플레이어 상태 변경을 무시
      if (useWebViewFallback.value) return;
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

    // 마지막으로 재생한 곡 복원
    _restoreLastPlayed();
  }

  void _restoreLastPlayed() {
    var box = Hive.box('settings');
    var lastPlayed = box.get('last_played');
    if (lastPlayed != null && lastPlayed is Map) {
      try {
        currentVideo.value = _mapToVideo(lastPlayed);
        playbackMode.value = lastPlayed['mode'] ?? '자동 재생';
        isPlaylistMode.value = lastPlayed['isPlaylist'] ?? false;
        repeatMode.value = lastPlayed['repeatMode'] ?? 0;
        isShuffle.value = lastPlayed['isShuffle'] ?? false;

        // 루프 모드 동기화
        if (repeatMode.value == 1) {
          audioPlayer.setLoopMode(LoopMode.one);
        } else {
          audioPlayer.setLoopMode(LoopMode.off);
        }

        // 대기열 복원
        List? savedQueue = lastPlayed['queue'];
        if (savedQueue != null) {
          queue.assignAll(savedQueue.map((e) => _mapToVideo(e)).toList());
        }

        // 히스토리 복원
        List? savedHistory = lastPlayed['history'];
        if (savedHistory != null) {
          historyStack.assignAll(savedHistory.map((e) => _mapToVideo(e)).toList());
        }
      } catch (_) {}
    }
  }

  Video _mapToVideo(Map map) {
    return Video(
      VideoId(map['id']),
      map['title'] ?? '',
      map['author'] ?? '',
      ChannelId('UC0000000000000000000000'),
      DateTime.now(),
      DateTime.now().toString(),
      DateTime.now(),
      '',
      null,
      ThumbnailSet(map['id']),
      const [],
      Engagement(0, 0, 0),
      false,
    );
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
    if (currentVideo.value == null) return;

    // 한곡 반복 모드인 경우: seek(0)만 수행하여 데이터 재로딩 방지
    if (repeatMode.value == 1) {
      if (kDebugMode) print('Repeat One mode: Seeking to zero');
      if (useWebViewFallback.value && ytWebController != null) {
        ytWebController!.seekTo(seconds: 0.0);
        ytWebController!.playVideo();
      } else {
        await audioPlayer.seek(Duration.zero);
        audioPlayer.play();
      }
      return;
    }

    if (currentVideo.value != null) {
      historyStack.add(currentVideo.value!);
    }
    
    if (queue.isNotEmpty) {
      var nextVideo = queue.removeAt(0);
      await playVideo(nextVideo, isFromQueue: true);
      // 재생목록 모드에서는 큐를 자동으로 채우지 않음
      if (!isPlaylistMode.value && queue.length < 3) {
        _fetchRelatedAndFillQueue(nextVideo);
      }
    } else {
      // 재생목록 전체 반복 모드인 경우
      if (isPlaylistMode.value && repeatMode.value == 2) {
        // 히스토리에 쌓인 곡들을 다시 큐로 옮기고 처음부터 재생
        final allSongs = [...historyStack];
        historyStack.clear();
        final firstVideo = allSongs.removeAt(0);
        queue.assignAll(allSongs);
        await playVideo(firstVideo, isFromQueue: true);
        return;
      }

      // 재생목록이 끝났으면 자동 재생 모드로 전환
      if (isPlaylistMode.value) {
        isPlaylistMode.value = false;
        playbackMode.value = '자동 재생';
      }
      
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
    if (kDebugMode) print('playVideo called for ID: ${video.id.value}');
    
    // 1. 즉시 UI 상태 초기화 (로딩 표시)
    _cancelCurrentLoad = false;
    isLoading.value = true;
    _startLoadingProgress();
    isPlaying.value = false;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    currentVideo.value = video;

    // 2. 이전 재생 중지
    try {
      await audioPlayer.stop();
      if (ytWebController != null) ytWebController!.stopVideo();
    } catch (_) {}
    useWebViewFallback.value = false;

    // 3. 일반 모드일 경우 대기열 관리
    if (!isFromQueue) {
      if (currentVideo.value != null && currentVideo.value != video) {
        historyStack.add(currentVideo.value!);
      }
      queue.clear();
      isPlaylistMode.value = false;
      playbackMode.value = '자동 재생';
      _fetchRelatedAndFillQueue(video);
    }
    
    if (kDebugMode) print('Fetching stream URLs for ${video.id.value}...');
    final urls = await _ytService.getAudioStreamUrls(video.id.value);
    if (kDebugMode) print('Found ${urls.length} URLs');
    
    if (_cancelCurrentLoad) {
      isLoading.value = false;
      _stopLoadingProgress();
      return;
    }
    bool success = false;
    
    for (String url in urls) {
      try {
        if (kDebugMode) print('Attempting play with headers: $url');
        await audioPlayer.setAudioSource(AudioSource.uri(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1'},
        ));
        audioPlayer.play();
        _addToRecentlyPlayed(video);
        success = true;
        break; // 성공 시 루프 탈출
      } catch (e) {
        if (kDebugMode) print('Playback error with headers: $e');
        // 시도 2: 헤더 제거 (AVPlayer 자체 처리 유도)
        try {
          await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
          audioPlayer.play();
          _addToRecentlyPlayed(video);
          success = true;
          break; // 성공 시 루프 탈출
        } catch (e2) {
          if (kDebugMode) print('Playback error without headers: $e2');
          // 다음 Fallback URL로 넘어감
        }
      }
    }

    if (!success) {
      if (kDebugMode) {
        print('Native Stream 시도 실패. WebView Fallback으로 전환합니다.');
      }
      // 중요: audioPlayer를 먼저 중지한 후 WebView를 초기화해야 네이티브 리스너가 isPlaying을 덮어쓰지 않음
      await audioPlayer.stop();
      _initWebViewFallback(video.id.value);
      _addToRecentlyPlayed(video);
      isPlaying.value = true;
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

    // 마지막 재생곡 및 대기열 정보 저장 (앱 재시작 시 복원용)
    box.put('last_played', {
      'id': video.id.value,
      'title': video.title,
      'author': video.author,
      'mode': playbackMode.value,
      'isPlaylist': isPlaylistMode.value,
      'repeatMode': repeatMode.value,
      'isShuffle': isShuffle.value,
      'queue': queue.map((v) => _videoToMap(v)).toList(),
      'history': historyStack.map((v) => _videoToMap(v)).toList(),
    });

    // HomeController가 초기화되어 있다면 데이터 갱신
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().loadRecentPlayed();
    }
  }

  Map _videoToMap(Video v) {
    return {
      'id': v.id.value,
      'title': v.title,
      'author': v.author,
    };
  }  

  /// 플레이리스트 모드로 곡 목록을 재생합니다.
  Future<void> playPlaylist(String playlistName, List<Map> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty || initialIndex < 0 || initialIndex >= songs.length) return;

    if (kDebugMode) print('Starting playPlaylist: $playlistName with ${songs.length} songs');

    isPlaylistMode.value = true;
    playbackMode.value = playlistName;
    historyStack.clear();
    queue.clear();

    // 1. 전체 리스트를 history와 queue로 분배
    List<Video> playlistVideos = songs.map((s) => Video(
      VideoId(s['id'].toString()),
      s['title']?.toString() ?? 'Unknown Title',
      s['author']?.toString() ?? 'Unknown Author',
      ChannelId('UC0000000000000000000000'),
      DateTime.now(), // uploadDate
      DateTime.now().toString(), // uploadDateRaw
      DateTime.now(), // publishDate
      '', // description
      null, // duration
      ThumbnailSet(s['id'].toString()), // thumbnails
      const [], // keywords
      Engagement(0, 0, 0), // engagement
      false, // isLive
    )).toList();

    for (int i = 0; i < initialIndex; i++) {
      historyStack.add(playlistVideos[i]);
    }
    for (int i = initialIndex + 1; i < playlistVideos.length; i++) {
      queue.add(playlistVideos[i]);
    }

    // 2. 셔플 모드라면 대기열 셔플
    if (isShuffle.value) {
      queue.shuffle();
    }

    // 3. 선택된 곡 재생
    if (kDebugMode) print('Playing initial song: ${playlistVideos[initialIndex].title}');
    await playVideo(playlistVideos[initialIndex], isFromQueue: true);
  }

  void addVideoToPlaylist(Video video, dynamic playlistKey) {
    var box = Hive.box('playlists');
    var p = Map.from(box.get(playlistKey));
    List songs = List.from(p['songs'] ?? []);
    
    if (songs.length >= 100) {
      Get.snackbar('알림', '재생목록 당 최대 100곡까지만 등록 가능합니다.', snackPosition: SnackPosition.TOP);
      return;
    }
    
    songs.add({
      'id': video.id.value,
      'title': video.title,
      'author': video.author,
    });
    
    p['songs'] = songs;
    box.put(playlistKey, p);
    
    Get.snackbar(
      '추가 완료', 
      '${p['name']} 재생목록에 추가되었습니다.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1DB954).withOpacity(0.8),
      colorText: Colors.white,
    );
  }

  void toggleShuffle() {
    isShuffle.value = !isShuffle.value;
    if (isShuffle.value && queue.isNotEmpty) {
      queue.shuffle();
    }
    _saveCurrentState(); // 상태 저장 강제 호출
    Get.snackbar(
      '셔플', 
      isShuffle.value ? '셔플 모드가 켜졌습니다.' : '셔플 모드가 꺼졌습니다.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1DB954).withOpacity(0.8),
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void toggleRepeat() {
    repeatMode.value = (repeatMode.value + 1) % 3;
    
    // 네이티브 플레이어 루프 모드 설정 (데이터 재로딩 방지)
    if (repeatMode.value == 1) {
      audioPlayer.setLoopMode(LoopMode.one);
    } else {
      audioPlayer.setLoopMode(LoopMode.off);
    }

    _saveCurrentState();
    String msg = '';
    if (repeatMode.value == 0) msg = '반복 재생 안 함';
    if (repeatMode.value == 1) msg = '한 곡 반복 중';
    if (repeatMode.value == 2) msg = '전체 반복 중';

    Get.snackbar(
      '반복 재생', 
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1DB954).withOpacity(0.8),
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void _saveCurrentState() {
    if (currentVideo.value != null) {
      _addToRecentlyPlayed(currentVideo.value!);
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
      // 복원된 곡이라 소스가 없는 경우, playVideo를 통해 소스 로드 후 재생
      if (audioPlayer.audioSource == null && currentVideo.value != null) {
        playVideo(currentVideo.value!, isFromQueue: true);
      } else {
        audioPlayer.play();
      }
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
