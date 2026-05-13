import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt_iframe;
import '../../../../main.dart';
import '../../../data/services/youtube_service.dart';
import '../../../data/services/lastfm_service.dart';
import '../../home/controllers/home_controller.dart';

class PlayerController extends GetxController with WidgetsBindingObserver {
  final AudioPlayer audioPlayer = audioHandler.player;
  final YouTubeService _ytService = YouTubeService();
  final LastFmService _lastFmService = LastFmService();
  
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
  
  bool _isFetchingQueue = false;
  String? _currentFetchId; // 비동기 작업 취소를 위한 현재 작업 ID
  Timer? _loadingTimer;



  bool _userIntendsToPlay = false;

  // [추가] Swift Background Task 연동
  static const MethodChannel _bgTaskChannel = MethodChannel('com.nam.music/background_task');
  bool _isBgTaskRunning = false;

  void startSwiftBackgroundTask() async {
    if (_isBgTaskRunning) return;
    _isBgTaskRunning = true;
    try {
      await _bgTaskChannel.invokeMethod('startBackgroundTask');
      if (kDebugMode) print('[Background] Started Swift Background Task for transition');
    } catch (e) {
      if (kDebugMode) print('[Background] Failed to start background task: $e');
    }
  }

  void stopSwiftBackgroundTask() async {
    if (!_isBgTaskRunning) return;
    _isBgTaskRunning = false;
    try {
      await _bgTaskChannel.invokeMethod('stopBackgroundTask');
      if (kDebugMode) print('[Background] Stopped Swift Background Task');
    } catch (e) {}
  }

  void _startLoadingProgress() {
    loadingPercent.value = 0;
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (loadingPercent.value < 90) loadingPercent.value += 3;
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

    audioHandler.nextRequests.listen((_) => playNext());
    audioHandler.prevRequests.listen((_) => playPrevious());

    audioPlayer.playerStateStream.listen((state) {
      if (useWebViewFallback.value) return;
      isPlaying.value = state.playing;

      // [수정] 백그라운드 재생 안정화 로직 정밀화
      // 사용자가 재생 중인 상태(_userIntendsToPlay)이고, 
      // 플레이어가 '로딩 중'이 아닌데도 'ready' 상태에서 멈춰있을 때만 강제 재생.
      // state.playing이 false가 되는 시점(사용자가 중지 버튼 누름)에는 이 로직이 타지 않아야 함.
      if (state.processingState == ProcessingState.ready && 
          !state.playing && 
          _userIntendsToPlay && 
          isLoading.value == false) {
        if (kDebugMode) print('[PlayerController] Auto-resume triggered. Calling play().');
        audioPlayer.play();
      }

      if (state.processingState == ProcessingState.completed) {
        playNext();
      }

      // 오디오가 실제로 재생을 시작하면 안전하게 백그라운드 태스크 권한을 반납
      if (state.playing && state.processingState == ProcessingState.ready) {
        stopSwiftBackgroundTask();
      }
    });

    audioPlayer.durationStream.listen((dur) {
      if (!useWebViewFallback.value) duration.value = dur ?? Duration.zero;
    });

    audioPlayer.positionStream.listen((pos) {
      if (!useWebViewFallback.value) position.value = pos;
      
      // 곡 전환이 임박했을 때(끝나기 5초 전) Swift Background Task를 시작하여
      // 네이티브에서 다음 곡 로딩(Dart 처리) 시점에 앱이 Suspended 되지 않도록 합니다.
      final dur = duration.value.inSeconds;
      if (dur > 0 && dur - pos.inSeconds <= 5) {
        startSwiftBackgroundTask();
      }
    });

    _restoreLastPlayed();
  }

  Future<AudioSource?> _createAudioSource(Video video, {bool useHeaders = true}) async {
    try {
      final urls = await _ytService.getAudioStreamUrls(video.id.value);
      if (urls.isEmpty) {
        if (kDebugMode) print('[PlayerController] No audio streams found. Video might be restricted.');
        return null;
      }

      final mediaItem = MediaItem(
        id: video.id.value,
        album: video.author,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        artUri: video.thumbnails.highResUrl.isNotEmpty 
            ? Uri.parse(video.thumbnails.highResUrl) 
            : (video.thumbnails.mediumResUrl.isNotEmpty 
                ? Uri.parse(video.thumbnails.mediumResUrl) 
                : null),
        extras: {'video': video},
      );

      if (useHeaders) {
        return AudioSource.uri(
          Uri.parse(urls.first),
          headers: const {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1',
          },
          tag: mediaItem,
        );
      } else {
        return AudioSource.uri(
          Uri.parse(urls.first),
          tag: mediaItem,
        );
      }
    } catch (e) {
      if (kDebugMode) print('[PlayerController] Error creating audio source: $e');
      return null;
    }
  }



  Future<void> _restoreLastPlayed() async {
    if (kDebugMode) print('[PlayerController] Restoring last played track...');
    var box = Hive.box('settings');
    var lastPlayed = box.get('last_played');
    if (lastPlayed != null && lastPlayed is Map) {
      try {
        currentVideo.value = _mapToVideo(lastPlayed);
        playbackMode.value = lastPlayed['mode'] ?? '자동 재생';
        isPlaylistMode.value = lastPlayed['isPlaylist'] ?? false;
        repeatMode.value = lastPlayed['repeatMode'] ?? 0;
        isShuffle.value = lastPlayed['isShuffle'] ?? false;

        audioPlayer.setLoopMode(repeatMode.value == 1 ? LoopMode.one : LoopMode.off);

        List? savedQueue = lastPlayed['queue'];
        if (savedQueue != null) {
          queue.assignAll(savedQueue.map((e) => _mapToVideo(e)).toList());
        }

        List? savedHistory = lastPlayed['history'];
        if (savedHistory != null) {
          historyStack.assignAll(savedHistory.map((e) => _mapToVideo(e)).toList());
        }

        if (currentVideo.value != null) {
          AudioSource? source = await _createAudioSource(currentVideo.value!, useHeaders: true);
          if (source == null) source = await _createAudioSource(currentVideo.value!, useHeaders: false);
          if (source != null) {
            try {
              await audioPlayer.setAudioSource(source, preload: true);
            } catch (_) {
              if (kDebugMode) print('[PlayerController] Restore native source failed');
            }
            audioHandler.updateCurrentMediaItem((source as UriAudioSource).tag as MediaItem);
          }
        }
      } catch (e) {
        if (kDebugMode) print('[PlayerController] Error restoring last played: $e');
      }
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
        if (ytWebController != null && isPlaying.value) ytWebController!.pauseVideo();
      }
    }
  }

  Future<void> _fetchRelatedAndFillQueue(Video video) async {
    final String fetchId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentFetchId = fetchId;
    _isFetchingQueue = true;

    try {
      if (kDebugMode) print('[PlayerController] Starting new fetch task: $fetchId for ${video.title}');

      // 무한히 늘어나는 히스토리 때문에 검색 결과가 모두 걸러지는 현상 방지 (최근 20개만 제외)
      final historyIds = historyStack.length > 20 
          ? historyStack.sublist(historyStack.length - 20).map((e) => e.id.value).toSet() 
          : historyStack.map((e) => e.id.value).toSet();
          
      final queueIds = queue.map((e) => e.id.value).toSet();
      final excludeIds = {...historyIds, ...queueIds, video.id.value};
      
      final queuedSongNames = <String>{video.parsedSongName.toLowerCase()};

      // 1. 1순위: YouTube 연관 동영상 (알고리즘 추천)
      try {
        if (kDebugMode) print('[PlayerController] 1순위 Fetch: YouTube 연관 영상 조회 중...');
        var related = await _ytService.getRelatedVideos(video);
        if (kDebugMode) print('[PlayerController] 1순위 결과: ${related.length}곡 발견됨');

        if (kDebugMode) print('related object: ${related}');
        if (_currentFetchId != fetchId) return;
        
        int addedCount = 0;
        for (var v in related) {
          if (_currentFetchId != fetchId) return;
          if (queue.length >= 10) break;
          
          final vId = v.id.value;
          final sName = v.parsedSongName.toLowerCase();
          
          if (kDebugMode) print('   🔍 검사 중: ${v.title} (Duration: ${v.duration})');

          if (vId == video.id.value || excludeIds.contains(vId)) {
            if (kDebugMode) print('   -> [제외] 이미 히스토리/대기열에 있음: ${v.title}');
            continue;
          }

          // YouTubeService에서 이미 2~10분 필터링 및 상세 조회를 완료했으므로
          // 여기서는 null 체크와 중복 체크만 수행합니다.
          if (v.duration == null) {
            if (kDebugMode) print('   -> [제외] 재생 시간 정보 없음: ${v.title}');
            continue;
          }
          
          bool isDuplicateName = false;
          for (var existing in queuedSongNames) {
            if (existing == sName || (sName.length > 3 && existing.contains(sName)) || (existing.length > 3 && sName.contains(existing))) {
              isDuplicateName = true;
              break;
            }
          }
          
          if (isDuplicateName) {
            if (kDebugMode) print('   -> [제외] 제목 중복 의심: ${v.title}');
            continue;
          }

          queue.add(v);
          excludeIds.add(vId);
          queuedSongNames.add(sName);
          addedCount++;
          if (kDebugMode) print('   + [추가] 대기열에 추가됨: ${v.title}');
        }
        if (kDebugMode) print('[PlayerController] 1순위 작업 완료: $addedCount곡 대기열 추가됨 (총 ${queue.length}곡)');
      } catch (e) {
        if (kDebugMode) print('[PlayerController] 1순위 에러: $e');
      }


      if (_currentFetchId != fetchId) return;

      // 2. 2순위: LastFM API를 통한 음악적 유사 곡 추천
      if (queue.length < 10) {
        print('2순위: LastFM API를 통한 음악적 유사 곡 추천');
        try {
          final trackName = video.parsedSongName;
          final artistName = video.parsedArtist;
          if (trackName.isNotEmpty && artistName.isNotEmpty) {
            var similarTracks = await _lastFmService.getSimilarTracks(trackName, artistName, limit: 10);
            if (_currentFetchId != fetchId) return;
            
            if (similarTracks.isEmpty) {
              final similarArtists = await _lastFmService.getSimilarArtists(artistName, limit: 3);
              if (_currentFetchId != fetchId) return;
              for (var artist in similarArtists) {
                final topTracks = await _lastFmService.getArtistTopTracks(artist, limit: 2);
                similarTracks.addAll(topTracks);
              }
              if (similarTracks.isEmpty) {
                similarTracks = await _lastFmService.getArtistTopTracks(artistName, limit: 10);
              }
              similarTracks.shuffle();
            }

            if (similarTracks.isNotEmpty) {
              for (final track in similarTracks) {
                if (_currentFetchId != fetchId) return;
                if (queue.length >= 10) break;
                
                bool isDuplicate = false;
                final qName = track.name.toLowerCase();
                for (var existing in queuedSongNames) {
                  if (existing.contains(qName) || qName.contains(existing)) {
                    isDuplicate = true;
                    break;
                  }
                }
                if (isDuplicate) continue;

                try {
                  final query = '${track.name} ${track.artist} music';
                  final results = await _ytService.searchSongs(query);
                  if (_currentFetchId != fetchId) return;
                  
                  final filtered = results.where((v) {
                    if (v.duration == null || excludeIds.contains(v.id.value)) return false;
                    final s = v.duration!.inSeconds;
                    // 1분 30초 이상 10분 미만 필터 적용
                    return s >= 90 && s < 600;
                  }).toList();
                  
                  if (filtered.isNotEmpty) {
                    if (_currentFetchId != fetchId) return;
                    queue.add(filtered.first);
                    excludeIds.add(filtered.first.id.value);
                    queuedSongNames.add(qName);
                  }
                } catch (_) {}
              }
              if (kDebugMode) print('[PlayerController] Queue replenished from LastFM: ${queue.length} items');
            }
          }
        } catch (_) {}
      }

      if (_currentFetchId != fetchId) return;

      // 3. 3순위: 영상 파싱 정보(가수, 제목) + 채널명을 조합한 유튜브 검색
      if (queue.length < 10) {
        print('3순위: 영상 파싱 정보(가수, 제목) + 채널명을 조합한 유튜브 검색');
        try {
          String channelName = video.author.replaceAll(RegExp(r'(- Topic|Topic|VEVO|Official)', caseSensitive: false), '').trim();
          final query = '${video.parsedArtist} ${video.parsedSongName} $channelName music'.trim();
          
          if (query.isNotEmpty && query != 'music') {
            var searchResults = await _ytService.searchSongs(query);
            if (_currentFetchId != fetchId) return;
            
            var fallback = searchResults.where((v) {
              if (v.duration == null || excludeIds.contains(v.id.value)) return false;
              final s = v.duration!.inSeconds;
              return s >= 90 && s < 600;
            }).toList();
            
            for (var v in fallback) {
              if (_currentFetchId != fetchId) return;
              if (queue.length >= 10) break;
              
              final sName = v.parsedSongName.toLowerCase();
              bool isDuplicate = false;
              for (var existing in queuedSongNames) {
                if (existing.contains(sName) || sName.contains(existing)) {
                  isDuplicate = true;
                  break;
                }
              }
              if (isDuplicate) continue;

              queue.add(v);
              excludeIds.add(v.id.value);
              queuedSongNames.add(sName);
            }
            if (kDebugMode) print('[PlayerController] Queue replenished from Fallback search: ${queue.length} items');
          }
        } catch (_) {}
      }
      
      
    } finally {
      if (_currentFetchId == fetchId) {
        _isFetchingQueue = false;
      }
    }
  }

  String? _currentPlayId;

  void playNext() {
    if (repeatMode.value == 1) {
      audioPlayer.seek(Duration.zero);
      audioPlayer.play();
      return;
    }

    if (queue.isNotEmpty) {
      var nextVideo = queue.removeAt(0);
      if (currentVideo.value != null) {
        historyStack.add(currentVideo.value!);
      }
      playVideo(nextVideo, isFromQueue: true);
    } else if (currentVideo.value != null) {
      playVideo(currentVideo.value!, isFromQueue: true);
    }
  }

  Future<void> playPrevious() async {
    if (position.value > const Duration(seconds: 3)) {
      await audioPlayer.seek(Duration.zero);
      return;
    }

    if (historyStack.isNotEmpty) {
      var prevVideo = historyStack.removeLast();
      if (currentVideo.value != null) {
        queue.insert(0, currentVideo.value!);
      }
      await playVideo(prevVideo, isFromQueue: true);
    }
  }

  Future<void> playVideo(Video video, {bool isFromQueue = false}) async {
    final playId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentPlayId = playId;

    if (kDebugMode) print('[PlayerController] playVideo requested for: ${video.id.value}');
    
    // 재생 전환 시작 시 혹시 모를 네트워크 지연 방지를 위해 백그라운드 태스크 시작
    startSwiftBackgroundTask();

    if (currentVideo.value?.id.value == video.id.value && audioPlayer.audioSource != null && !isFromQueue) {
      await audioPlayer.seek(Duration.zero);
      audioPlayer.play();
      if (_currentPlayId == playId) stopSwiftBackgroundTask();
      return;
    }

    isLoading.value = true;
    _startLoadingProgress();
    isPlaying.value = false;
    currentVideo.value = video;
    _userIntendsToPlay = true; 

    // [수정] 위젯 깜빡임 최소화: 로딩 전에 MediaItem을 미리 업데이트하여 
    // 안드로이드 알림이 사라졌다가 다시 생기는 현상을 방지합니다.
    final immediateMediaItem = MediaItem(
      id: video.id.value,
      album: video.author,
      title: video.title,
      artist: video.author,
      duration: video.duration,
      artUri: video.thumbnails.highResUrl.isNotEmpty 
          ? Uri.parse(video.thumbnails.highResUrl) 
          : (video.thumbnails.mediumResUrl.isNotEmpty 
              ? Uri.parse(video.thumbnails.mediumResUrl) 
              : null),
    );
    audioHandler.updateCurrentMediaItem(immediateMediaItem);

    final session = await AudioSession.instance;
    await session.setActive(true);

    if (!isFromQueue) {
      if (currentVideo.value != null && currentVideo.value != video) {
        historyStack.add(currentVideo.value!);
      }
      queue.clear();
      _currentFetchId = null;
      isPlaylistMode.value = false;
      playbackMode.value = '자동 재생';
      _fetchRelatedAndFillQueue(video);
    } else {
      // 대기열에서 곡을 선택했더라도, 남은 개수가 적으면 미리 보충
      if (!isPlaylistMode.value && queue.length < 10) {
        _fetchRelatedAndFillQueue(video);
      }
    }

    if (_currentPlayId != playId) return;

    if (ytWebController != null) ytWebController!.stopVideo();
    useWebViewFallback.value = false;

    bool success = false;
    AudioSource? source = await _createAudioSource(video, useHeaders: true);
    if (_currentPlayId != playId) return;

    if (source != null) {
      try {
        if (kDebugMode) print('[PlayerController] Attempting native play with headers...');
        await audioPlayer.setAudioSource(source, initialPosition: Duration.zero, preload: true);
        
        if (_currentPlayId != playId) return;

        _stopLoadingProgress();
        isLoading.value = false;
        
        await session.setActive(true);
        audioPlayer.play();
        
        success = true;
        _addToRecentlyPlayed(video);
      } catch (e) {
        if (e.toString().contains('STREAM_FETCH_FAILED')) {
          if (kDebugMode) print('[PlayerController] Stream fetch failed permanently. Skipping...');
          Get.rawSnackbar(message: '곡 정보를 가져오지 못해 다음 곡으로 넘어갑니다.', duration: const Duration(seconds: 2));
          playNext();
          return;
        }

        if (kDebugMode) print('[PlayerController] Native play attempt failed: $e');
        
        source = await _createAudioSource(video, useHeaders: false);
        if (_currentPlayId != playId) return;

        if (source != null) {
          try {
            if (kDebugMode) print('[PlayerController] Attempting native play without headers...');
            await audioPlayer.setAudioSource(source, initialPosition: Duration.zero, preload: true);
            
            _stopLoadingProgress();
            isLoading.value = false;
            
            audioPlayer.play();
            
            success = true;
            _addToRecentlyPlayed(video);
            await session.setActive(true);
          } catch (e2) {
            if (kDebugMode) print('[PlayerController] Native play attempt failed without headers: $e2');
            await audioPlayer.stop();
          }
        }
      }
    }

    if (!success) {
      if (kDebugMode) print('[PlayerController] Native attempt failed. Switching to WebView.');
      _initWebViewFallback(video.id.value);
      _addToRecentlyPlayed(video);
      isPlaying.value = true;

      final mediaItem = MediaItem(
        id: video.id.value,
        album: video.author,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        artUri: video.thumbnails.highResUrl.isNotEmpty 
            ? Uri.parse(video.thumbnails.highResUrl) 
            : (video.thumbnails.mediumResUrl.isNotEmpty 
                ? Uri.parse(video.thumbnails.mediumResUrl) 
                : null),
      );
      audioHandler.updateCurrentMediaItem(mediaItem);
      
      // 시스템 세션 활성화 확인 (애플 뮤직 덮어쓰기 방지)
      final session = await AudioSession.instance;
      await session.setActive(true);
    }

  }

  void _initWebViewFallback(String videoId) {
    if (kDebugMode) print('[Iframe] Init requested for videoId: $videoId');
    useWebViewFallback.value = true;
    if (ytWebController == null) {
      if (kDebugMode) print('[Iframe] Creating new YoutubePlayerController');
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
        if (kDebugMode) {
          print('[Iframe Event] PlayerState: ${event.playerState}, Error: ${event.error}, Duration: ${event.metaData.duration}, Position: ${position.value}');
        }
        
        if (event.playerState == yt_iframe.PlayerState.playing) {
          isPlaying.value = true;
          // Ad-skip simulation: if it's playing but the duration is suspiciously short or ad-like, we could skip.
          // However, youtube_player_iframe doesn't strictly report ads easily. 
        } else if (event.playerState == yt_iframe.PlayerState.paused) {
          isPlaying.value = false;
        } else if (event.playerState == yt_iframe.PlayerState.ended) {
          playNext();
        }
        
        duration.value = event.metaData.duration;
      });
      Stream.periodic(const Duration(seconds: 1)).listen((_) async {
        if (useWebViewFallback.value && isPlaying.value && ytWebController != null) {
          try {
            final pos = await ytWebController!.currentTime;
            position.value = Duration(seconds: pos.toInt());
          } catch (_) {}
        }
      });
    } else {
      if (kDebugMode) print('[Iframe] Loading video in existing controller: $videoId');
      ytWebController!.loadVideoById(videoId: videoId);
    }
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

    if (Get.isRegistered<HomeController>()) Get.find<HomeController>().loadRecentPlayed();
  }

  Map _videoToMap(Video v) {
    return {'id': v.id.value, 'title': v.title, 'author': v.author};
  }

  Future<void> playPlaylist(String playlistName, List<Map> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty || initialIndex < 0 || initialIndex >= songs.length) return;
    if (kDebugMode) print('[PlayerController] playPlaylist requested: $playlistName');

    isPlaylistMode.value = true;
    playbackMode.value = playlistName;
    historyStack.clear();
    queue.clear();

    List<Video> playlistVideos = songs.map((s) => Video(
      VideoId(s['id'].toString()),
      s['title']?.toString() ?? 'Unknown Title',
      s['author']?.toString() ?? 'Unknown Author',
      ChannelId('UC0000000000000000000000'),
      DateTime.now(),
      DateTime.now().toString(),
      DateTime.now(),
      '',
      null,
      ThumbnailSet(s['id'].toString()),
      const [],
      Engagement(0, 0, 0),
      false,
    )).toList();

    for (int i = 0; i < initialIndex; i++) historyStack.add(playlistVideos[i]);
    for (int i = initialIndex + 1; i < playlistVideos.length; i++) queue.add(playlistVideos[i]);

    if (isShuffle.value) queue.shuffle();
    await playVideo(playlistVideos[initialIndex], isFromQueue: true);
  }

  void addVideoToPlaylist(Video video, dynamic playlistKey) {
    var box = Hive.box('playlists');
    var data = box.get(playlistKey);
    if (data == null) return;
    
    var p = Map<String, dynamic>.from(data);
    var songs = List<Map>.from(p['songs'] ?? []);
    if (songs.any((s) => s['id'] == video.id.value)) {
      Get.rawSnackbar(title: '이미 있음', message: '이미 플레이리스트에 있는 곡입니다.', backgroundColor: Colors.orange);
      return;
    }

    songs.add({'id': video.id.value, 'title': video.title, 'author': video.author});
    p['songs'] = songs;
    box.put(playlistKey, p);
    Get.rawSnackbar(title: '추가 완료', message: '${p['name']} 목록에 추가되었습니다.', backgroundColor: const Color(0xFF1DB954));
  }

  void toggleShuffle() {
    isShuffle.value = !isShuffle.value;
    if (isShuffle.value) {
      queue.shuffle();
    }
    _saveCurrentState();
  }

  void toggleRepeat() {
    repeatMode.value = (repeatMode.value + 1) % 3;
    _saveCurrentState();
  }

  // [추가] 사용자가 명시적으로 중지 버튼을 눌렀을 때 호출
  void pauseByUser() {
    _userIntendsToPlay = false;
    audioPlayer.pause();
    if (ytWebController != null) ytWebController!.pauseVideo();
  }

  // [추가] 사용자가 명시적으로 재생 버튼을 눌렀을 때 호출
  void resumeByUser() {
    _userIntendsToPlay = true;
    audioPlayer.play();
    if (useWebViewFallback.value && ytWebController != null) {
      ytWebController!.playVideo();
    }
  }

  void togglePlay() {
    if (isLoading.value) {
      isLoading.value = false;
      _stopLoadingProgress();
      audioPlayer.stop();
      if (ytWebController != null) ytWebController!.stopVideo();
      _userIntendsToPlay = false; // 로딩 중 취소 시 재생 의도 철회
      return;
    }
    if (useWebViewFallback.value && ytWebController != null) {
      if (isPlaying.value) {
        pauseByUser(); // 전용 메서드 사용
      } else {
        ytWebController!.playVideo();
        _userIntendsToPlay = true;
      }
      return;
    }

    if (audioPlayer.audioSource == null && currentVideo.value != null) {
      playVideo(currentVideo.value!);
      return;
    }

    if (audioPlayer.playing) {
      pauseByUser(); // 전용 메서드 사용
    } else {
      audioPlayer.play();
      _userIntendsToPlay = true; // 재생 버튼 클릭 시 재생 의도 활성화
    }
  }
  void _saveCurrentState() {
    if (currentVideo.value != null) _addToRecentlyPlayed(currentVideo.value!);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingTimer?.cancel();
    super.onClose();
  }
}

extension VideoParsing on Video {
  String get parsedTitle {
    return title.replaceAll(RegExp(r'(\[.*?\]|\(.*?\)|【.*?】|MV|Official|Video|Audio|Lyrics|가사|Music)', caseSensitive: false), '').trim();
  }
  String get parsedArtist {
    String pt = parsedTitle;
    if (pt.contains(' - ')) return pt.split(' - ')[0].trim();
    if (pt.contains('-')) return pt.split('-')[0].trim();
    return author.replaceAll(RegExp(r'(- Topic|Topic|VEVO|Official)', caseSensitive: false), '').trim();
  }
  String get parsedSongName {
    String pt = parsedTitle;
    if (pt == title || pt.isEmpty) return title;
    if (pt.contains('-')) return pt.split('-').sublist(1).join('-').trim();
    return pt;
  }
}
