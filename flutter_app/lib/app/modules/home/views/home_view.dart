import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../controllers/home_controller.dart';
import '../../player/controllers/player_controller.dart';
import 'dart:ui';

class HomeView extends StatelessWidget {
  HomeView({super.key});

  final HomeController controller = Get.find<HomeController>();
  final PlayerController playerController = Get.find<PlayerController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient effect (Glassmorphism base)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2B1A4A), Color(0xFF0D0D0D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  title: Text('app_name'.tr, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                      onPressed: () => Get.toNamed('/settings'),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() {
                          if (controller.recentPlayed.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('최근 재생한 곡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 12),
                              _buildRecentPlayedList(),
                              const SizedBox(height: 24),
                            ],
                          );
                        }),
                        Text('trending_now'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        _buildTrendingCarousel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mini Player
          Obx(() => Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: playerController.currentVideo.value != null 
                ? _buildMiniPlayer(context) 
                : _buildSkeletonMiniPlayer(),
            )
          ),
          
          // WebView Fallback Player (숨겨짐)
          Obx(() {
            if (playerController.useWebViewFallback.value && playerController.ytWebController != null) {
              return Positioned(
                top: 0, left: 0,
                width: 1, height: 1,
                child: Opacity(
                  opacity: 0.01,
                  child: IgnorePointer(
                    child: YoutubePlayer(controller: playerController.ytWebController!),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D0D0D),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Get.toNamed('/search');
          } else if (index == 2) {
            Get.toNamed('/library');
          }
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'home'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: 'search'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.library_music), label: 'library'.tr),
        ],
      ),
    );
  }

  Widget _buildRecentPlayedList() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.recentPlayed.length,
        itemBuilder: (context, index) {
          final item = controller.recentPlayed[index];
          final cleanTitle = controller.parseTitle(item['title']);
          return GestureDetector(
            onTap: () async {
              // Video 객체를 만들어서 재생 (임시 처리)
              final video = await Get.find<HomeController>().fetchVideoDetail(item['id']);
              if (video != null) playerController.playVideo(video);
            },
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(item['thumbnail'], width: 110, height: 90, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 6),
                  Text(cleanTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(item['author'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingCarousel() {
    return SizedBox(
      height: 220,
      child: Obx(() {
        if (controller.isLoading.value && controller.trendingSongs.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
        }
        
        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            // 끝에 도달하기 전에 미리 로드 (80% 지점)
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8) {
              controller.fetchMoreTrending();
            }
            return true;
          },
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: controller.trendingSongs.length + (controller.isMoreLoading.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.trendingSongs.length) {
                return const SizedBox(
                  width: 100,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
                );
              }

              final track = controller.trendingSongs[index];
              return GestureDetector(
                onTap: () async {
                  Get.dialog(
                    const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
                    barrierDismissible: false,
                  );
                  
                  final video = await controller.searchAndGetVideo(track);
                  Get.back();
                  
                  if (video != null) {
                    playerController.playVideo(video);
                  } else {
                    Get.rawSnackbar(message: '영상을 찾을 수 없습니다.');
                  }
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail Image
                        if (track.imageUrl != null && 
                            track.imageUrl!.isNotEmpty && 
                            !track.imageUrl!.contains('2a96cbd8b46e442fc41c2b86b821562f'))
                          Image.network(
                            track.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          )
                        else
                          _buildPlaceholder(),
                        
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                            ),
                          ),
                        ),
                        
                        // Text Info
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name, 
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis, 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.artist, 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis, 
                                style: const TextStyle(color: Colors.grey, fontSize: 12)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[800]!, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white24, size: 48),
      ),
    );
  }

  Widget _buildSkeletonMiniPlayer() {
    return GestureDetector(
      onTap: () {
        Get.toNamed('/search');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 14, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 6),
                      Container(width: 80, height: 10, color: Colors.white.withOpacity(0.05)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.play_arrow, color: Colors.white54), onPressed: () {
                  Get.toNamed('/search');
                }),
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white54), onPressed: () {
                  Get.toNamed('/search');
                }),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context) {
    final video = playerController.currentVideo.value!;

    return GestureDetector(
      onTap: () {
        Get.toNamed('/player');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(video.thumbnails.lowResUrl, width: 48, height: 48, fit: BoxFit.cover),
                      Obx(() {
                        if (playerController.isLoading.value) {
                          return Container(
                            width: 48,
                            height: 48,
                            color: Colors.black54,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${playerController.loadingPercent.value}%', 
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(video.parsedSongName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                      Row(
                        children: [
                          Obx(() => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: playerController.isPlaylistMode.value ? const Color(0xFF1DB954).withOpacity(0.3) : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              playerController.playbackMode.value,
                              style: TextStyle(
                                color: playerController.isPlaylistMode.value ? const Color(0xFF1DB954) : Colors.grey,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )),
                          const SizedBox(width: 6),
                          Flexible(child: Text(video.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11))),
                        ],
                      ),
                    ],
                  ),
                ),
                Obx(() => IconButton(
                    icon: Icon(
                      playerController.isLoading.value 
                        ? Icons.pause 
                        : (playerController.isPlaying.value ? Icons.pause : Icons.play_arrow), 
                      color: Colors.white
                    ),
                    onPressed: playerController.togglePlay,
                  )
                ),
                IconButton(
                  icon: const Icon(Icons.queue_music, color: Colors.white70, size: 22),
                  onPressed: () => _showQueueBottomSheet(context),
                ),
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: playerController.playNext),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
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
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
            ),
            // 헤더
            Obx(() => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.queue_music,
                    color: playerController.isPlaylistMode.value ? const Color(0xFF1DB954) : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    playerController.playbackMode.value,
                    style: TextStyle(
                      color: playerController.isPlaylistMode.value ? const Color(0xFF1DB954) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (playerController.isPlaylistMode.value)
                    Text(
                      '총 ${playerController.historyStack.length + 1 + playerController.queue.length}곡',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  else
                    Text(
                      '${playerController.queue.length}곡 대기 중',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            )),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: Obx(() {
                // 플레이리스트 모드: 전체 목록 표시
                if (playerController.isPlaylistMode.value) {
                  final fullList = [
                    ...playerController.historyStack,
                    if (playerController.currentVideo.value != null) playerController.currentVideo.value!,
                    ...playerController.queue,
                  ];
                  final currentIndex = playerController.historyStack.length;

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
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          v.parsedArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        onTap: () {
                          if (isCurrent) return;
                          if (index < currentIndex) {
                            final jumpCount = currentIndex - index;
                            for (int i = 0; i < jumpCount; i++) {
                              playerController.queue.insert(0, playerController.currentVideo.value!);
                              playerController.currentVideo.value = playerController.historyStack.removeLast();
                            }
                          } else {
                            final jumpCount = index - currentIndex;
                            for (int i = 0; i < jumpCount; i++) {
                              playerController.historyStack.add(playerController.currentVideo.value!);
                              playerController.currentVideo.value = playerController.queue.removeAt(0);
                            }
                          }
                          playerController.playVideo(playerController.currentVideo.value!, isFromQueue: true);
                          Get.back();
                        },
                      );
                    },
                  );
                }

                // 일반 모드: 대기열만 표시
                if (playerController.queue.isEmpty) {
                  return const Center(
                    child: Text('대기열이 비어있습니다.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (playerController.currentVideo.value != null) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('현재 재생 중', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.graphic_eq, color: Color(0xFF1DB954), size: 24),
                        title: Text(
                          playerController.currentVideo.value!.parsedSongName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          playerController.currentVideo.value!.parsedArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('다음 트랙', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: playerController.queue.length,
                        itemBuilder: (context, index) {
                          final v = playerController.queue[index];
                          return ListTile(
                            dense: true,
                            leading: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            title: Text(
                              v.parsedSongName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            subtitle: Text(
                              v.parsedArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                            onTap: () {
                              for (int i = 0; i <= index; i++) {
                                playerController.historyStack.add(playerController.currentVideo.value!);
                                playerController.currentVideo.value = playerController.queue.removeAt(0);
                              }
                              playerController.playVideo(playerController.currentVideo.value!, isFromQueue: true);
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
}
