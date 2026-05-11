import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import '../../modules/player/controllers/player_controller.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // PlayerController와의 통신을 위한 스트림
  final _nextRequestController = StreamController<void>.broadcast();
  final _prevRequestController = StreamController<void>.broadcast();
  
  Stream<void> get nextRequests => _nextRequestController.stream;
  Stream<void> get prevRequests => _prevRequestController.stream;

  MyAudioHandler() {
    // 1. 플레이어 상태를 시스템에 통지 (Position, BufferedPosition, Duration 포함)
    _player.playbackEventStream.map(_transformEvent).listen(playbackState.add);
    
    // 2. 재생 위치(Position)를 정기적으로 업데이트 (슬라이더 동기화 핵심)
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_player.playing) {
        playbackState.add(playbackState.value.copyWith(
          updatePosition: _player.position,
        ));
      }
    });

    // 3. 곡 완료 시 다음 곡 요청 스트림에 이벤트 전송
    _player.processingStateStream.listen((state) {
      if (kDebugMode) print('Native Player State: $state');
      if (state == ProcessingState.completed) {
        if (kDebugMode) print('Track completed naturally. Requesting next track.');
        _nextRequestController.add(null);
      }
    });

    // 4. 인덱스 변경 시 시스템 알림(Lockscreen) 업데이트
    _player.currentIndexStream.listen((index) {
      if (index != null && _player.audioSource is ConcatenatingAudioSource) {
        final playlist = _player.audioSource as ConcatenatingAudioSource;
        if (index < playlist.length) {
          final source = playlist.children[index];
          if (source is UriAudioSource && source.tag is MediaItem) {
            mediaItem.add(source.tag as MediaItem);
          }
        }
      }
    });
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) print('[AudioHandler] pause() requested from system');
    // [중요] 시스템에서 중지 신호가 오면 Controller에도 중지 의사 전달
    try {
       Get.find<PlayerController>().pauseByUser();
    } catch (_) {}
    await _player.pause();
  }

  @override
  Future<void> play() async {
    if (kDebugMode) print('[AudioHandler] play() requested from system');
    try {
       Get.find<PlayerController>().resumeByUser();
    } catch (_) {}
    await _player.play();
  }

  @override
  Future<void> stop() async {
    if (kDebugMode) print('[AudioHandler] stop() requested from system');
    try {
       Get.find<PlayerController>().pauseByUser();
    } catch (_) {}
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    if (kDebugMode) print('[AudioHandler] seek($position) requested from system');
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) print('[AudioHandler] skipToNext() requested from system');
    _nextRequestController.add(null);
  }

  @override
  Future<void> skipToPrevious() async {
    if (kDebugMode) print('[AudioHandler] skipToPrevious() requested from system');
    _prevRequestController.add(null);
  }

  @override
  Future<void> fastForward() => _player.seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => _player.seek(_player.position - const Duration(seconds: 10));

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.setRating,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  AudioPlayer get player => _player;

  Future<void> updateCurrentMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }
}
