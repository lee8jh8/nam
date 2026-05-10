import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // PlayerController와의 통신을 위한 스트림
  final _nextRequestController = StreamController<void>.broadcast();
  final _prevRequestController = StreamController<void>.broadcast();
  
  Stream<void> get nextRequests => _nextRequestController.stream;
  Stream<void> get prevRequests => _prevRequestController.stream;

  MyAudioHandler() {
    // 1. 플레이어 상태를 시스템에 통지
    _player.playbackEventStream.map(_transformEvent).listen(playbackState.add);
    
    // 2. 곡 완료 시 다음 곡 요청 스트림에 이벤트 전송
    _player.processingStateStream.listen((state) {
      if (kDebugMode) print('Native Player State: $state');
      if (state == ProcessingState.completed) {
        if (kDebugMode) print('Track completed naturally. Requesting next track.');
        _nextRequestController.add(null);
      }
    });

    // 3. 인덱스 변경 시 시스템 알림(Lockscreen) 업데이트
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    // [중요] fresh URL 보장을 위해 네이티브 playlist seek 대신 Controller를 통한 재로딩 유도
    _nextRequestController.add(null);
  }

  @override
  Future<void> skipToPrevious() async {
    // [중요] fresh URL 보장을 위해 네이티브 playlist seek 대신 Controller를 통한 재로딩 유도
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
