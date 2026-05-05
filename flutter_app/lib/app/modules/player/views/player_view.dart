import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/player_controller.dart';
import 'dart:ui';

class PlayerView extends GetView<PlayerController> {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
            Get.back();
          }
        },
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 15) {
            Get.back();
          }
        },
        child: Obx(() {
          final video = controller.currentVideo.value;
        if (video == null) return const Center(child: Text('No media'));
        
        return Stack(
          children: [
            // Background blur (앨범 아트 기반 글래스모피즘 효과)
            Positioned.fill(
              child: Image.network(video.thumbnails.highResUrl, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // 상단 앱바
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32), onPressed: () => Get.back()),
                    title: const Text('Now Playing', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                    centerTitle: true,
                  ),
                  const Spacer(),
                  // 중앙 앨범 썸네일
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(video.thumbnails.highResUrl, width: double.infinity, height: 320, fit: BoxFit.cover),
                          if (controller.isLoading.value)
                            Container(
                              width: double.infinity,
                              height: 320,
                              color: Colors.black54,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: Colors.white),
                                  const SizedBox(height: 16),
                                  Text('${controller.loadingPercent.value}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // 곡 제목 및 아티스트
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.parsedSongName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(video.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 재생 진행바 (Progress Slider)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.3),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: controller.position.value.inSeconds.toDouble().clamp(0.0, controller.duration.value.inSeconds.toDouble() > 0 ? controller.duration.value.inSeconds.toDouble() : 1.0),
                            max: controller.duration.value.inSeconds.toDouble() > 0 ? controller.duration.value.inSeconds.toDouble() : 1.0,
                            onChanged: (val) {
                              if (controller.useWebViewFallback.value && controller.ytWebController != null) {
                                controller.ytWebController!.seekTo(seconds: val, allowSeekAhead: true);
                              } else {
                                controller.audioPlayer.seek(Duration(seconds: val.toInt()));
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(controller.position.value), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              Text(_formatDuration(controller.duration.value), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 미디어 컨트롤러 (이전, 재생/일시정지, 다음)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40), onPressed: controller.playPrevious),
                      IconButton(
                        iconSize: 80,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          controller.isLoading.value 
                            ? Icons.pause_circle_filled 
                            : (controller.isPlaying.value ? Icons.pause_circle_filled : Icons.play_circle_fill), 
                          color: Colors.white,
                          size: 80,
                        ),
                        onPressed: controller.togglePlay,
                      ),
                      IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 40), onPressed: controller.playNext),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        );
      }),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
