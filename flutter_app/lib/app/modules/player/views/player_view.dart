import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
                  // 재생 모드 배지
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: controller.isPlaylistMode.value
                            ? const Color(0xFF1DB954).withOpacity(0.25)
                            : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          controller.playbackMode.value,
                          style: TextStyle(
                            color: controller.isPlaylistMode.value ? const Color(0xFF1DB954) : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 곡 제목 및 아티스트
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(video.parsedSongName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(video.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 18)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.playlist_add, color: Colors.white70, size: 32),
                          onPressed: () => _showAddToPlaylistBottomSheet(context, video),
                        ),
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
                  // 미디어 컨트롤러 (셔플, 이전, 재생/일시정지, 다음, 반복)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Obx(() => IconButton(
                          icon: Icon(Icons.shuffle, color: controller.isShuffle.value ? const Color(0xFF1DB954) : Colors.white54, size: 24),
                          onPressed: controller.toggleShuffle,
                        )),
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
                        Obx(() {
                          IconData icon = Icons.repeat;
                          Color color = Colors.white54;
                          if (controller.repeatMode.value == 1) {
                            icon = Icons.repeat_one;
                            color = const Color(0xFF1DB954);
                          } else if (controller.repeatMode.value == 2) {
                            icon = Icons.repeat;
                            color = const Color(0xFF1DB954);
                          }
                          return IconButton(
                            icon: Icon(icon, color: color, size: 24),
                            onPressed: controller.toggleRepeat,
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 재생 대기열 보기 버튼
                  TextButton.icon(
                    icon: const Icon(Icons.queue_music, color: Colors.white70, size: 20),
                    label: Obx(() => Text(
                      '대기열 (${controller.queue.length}곡)',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    )),
                    onPressed: () => _showQueueBottomSheet(context),
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

  void _showQueueBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
            ),
            // 헤더
            Obx(() => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.queue_music, color: controller.isPlaylistMode.value ? const Color(0xFF1DB954) : Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    controller.playbackMode.value,
                    style: TextStyle(
                      color: controller.isPlaylistMode.value ? const Color(0xFF1DB954) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (controller.isPlaylistMode.value)
                    Text(
                      '총 ${controller.historyStack.length + 1 + controller.queue.length}곡',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  else
                    Text(
                      '${controller.queue.length}곡 대기 중',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            )),
            const Divider(color: Colors.white12, height: 1),
            
            Expanded(
              child: Obx(() {
                // 플레이리스트 모드일 때는 전체 목록(히스토리 + 현재 + 대기열)을 보여줌
                if (controller.isPlaylistMode.value) {
                  final fullList = [...controller.historyStack, if (controller.currentVideo.value != null) controller.currentVideo.value!, ...controller.queue];
                  final currentIndex = controller.historyStack.length;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: fullList.length,
                    itemBuilder: (context, index) {
                      final v = fullList[index];
                      final isCurrent = index == currentIndex;

                      return ListTile(
                        dense: true,
                        leading: isCurrent 
                          ? const Icon(Icons.graphic_eq, color: Color(0xFF1DB954), size: 20)
                          : Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        title: Text(
                          v.parsedSongName, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: TextStyle(
                            color: isCurrent ? const Color(0xFF1DB954) : Colors.white, 
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14
                          )
                        ),
                        subtitle: Text(v.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        onTap: () {
                          if (isCurrent) return;
                          
                          // 선택한 위치로 이동
                          if (index < currentIndex) {
                            // 히스토리에서 선택한 경우: 현재 곡과 그 사이 곡들을 큐의 맨 앞으로 이동
                            final jumpCount = currentIndex - index;
                            for (int i = 0; i < jumpCount; i++) {
                              controller.queue.insert(0, controller.currentVideo.value!);
                              controller.currentVideo.value = controller.historyStack.removeLast();
                            }
                            controller.playVideo(controller.currentVideo.value!, isFromQueue: true);
                          } else {
                            // 대기열에서 선택한 경우: 이전 곡들을 히스토리로 이동
                            final jumpCount = index - currentIndex;
                            for (int i = 0; i < jumpCount; i++) {
                              controller.historyStack.add(controller.currentVideo.value!);
                              controller.currentVideo.value = controller.queue.removeAt(0);
                            }
                            controller.playVideo(controller.currentVideo.value!, isFromQueue: true);
                          }
                          Get.back();
                        },
                      );
                    },
                  );
                }

                // 일반 모드(자동 재생)일 때는 대기열만 보여줌
                if (controller.queue.isEmpty) {
                  return const Center(child: Text('대기열이 비어있습니다.', style: TextStyle(color: Colors.grey)));
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (controller.currentVideo.value != null) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('현재 재생 중', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.graphic_eq, color: Color(0xFF1DB954), size: 24),
                        title: Text(controller.currentVideo.value!.parsedSongName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(controller.currentVideo.value!.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('다음 트랙', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: controller.queue.length,
                        itemBuilder: (context, index) {
                          final v = controller.queue[index];
                          return ListTile(
                            dense: true,
                            leading: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            title: Text(v.parsedSongName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text(v.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            onTap: () {
                              for (int i = 0; i <= index; i++) {
                                controller.historyStack.add(controller.currentVideo.value!);
                                controller.currentVideo.value = controller.queue.removeAt(0);
                              }
                              controller.playVideo(controller.currentVideo.value!, isFromQueue: true);
                              Get.back();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return ValueListenableBuilder(
          valueListenable: Hive.box('playlists').listenable(),
          builder: (context, Box box, _) {
            var keys = box.keys.toList();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('재생목록에 추가', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (keys.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('생성된 재생목록이 없습니다.', style: TextStyle(color: Colors.grey)),
                    ),
                  ...keys.map((key) {
                    var p = box.get(key);
                    return ListTile(
                      leading: const Icon(Icons.queue_music, color: Color(0xFF1DB954)),
                      title: Text(p['name'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${p['songs']?.length ?? 0}곡', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: () {
                        controller.addVideoToPlaylist(video, key);
                        Get.back();
                      },
                    );
                  }).toList(),
                  const Divider(color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.white),
                    title: const Text('새 재생목록 만들기', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Get.back();
                      _showCreatePlaylistDialog(context, video);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, Video video) {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '새 재생목록', 
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '목록 이름을 입력하세요',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              String name = textController.text.trim();
              if (name.isNotEmpty) {
                var box = Hive.box('playlists');
                if (box.length >= 10) {
                  Get.snackbar('알림', '재생목록은 최대 10개까지 가능합니다.', snackPosition: SnackPosition.TOP);
                  return;
                }
                String key = DateTime.now().millisecondsSinceEpoch.toString();
                box.put(key, {'name': name, 'songs': []});
                controller.addVideoToPlaylist(video, key);
                Navigator.pop(context); // 확실히 닫기 위해 Navigator 사용
              }
            },
            child: const Text('만들기', style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
