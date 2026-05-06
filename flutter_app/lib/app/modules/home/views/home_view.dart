import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
                ? _buildMiniPlayer() 
                : _buildSkeletonMiniPlayer(),
            )
          ),
          
          // WebView Fallback Player (숨겨짐)
          Obx(() {
            if (playerController.useWebViewFallback.value && playerController.ytWebController != null) {
              return Positioned(
                bottom: -100, right: -100,
                width: 10, height: 10,
                child: Opacity(
                  opacity: 0.01,
                  child: YoutubePlayer(controller: playerController.ytWebController!),
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
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.trendingSongs.length,
          itemBuilder: (context, index) {
            final video = controller.trendingSongs[index];
            final cleanTitle = controller.parseTitle(video.title);
            return GestureDetector(
              onTap: () => playerController.playVideo(video),
              child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(video.thumbnails.highResUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video.parsedSongName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(video.parsedArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
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

  Widget _buildMiniPlayer() {
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
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: playerController.playNext),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
