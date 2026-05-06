import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../controllers/search_controller_custom.dart';
import '../../player/controllers/player_controller.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});

  final SearchControllerCustom controller = Get.put(SearchControllerCustom());
  final PlayerController playerController = Get.find<PlayerController>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'search'.tr,
            hintStyle: const TextStyle(color: Colors.grey),
            border: InputBorder.none,
          ),
          onSubmitted: (val) {
            controller.searchSongs(val);
          },
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
        }

        if (controller.searchResults.isEmpty && controller.recentSearches.isNotEmpty) {
          return ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: controller.recentSearches.length,
            itemBuilder: (context, index) {
              final term = controller.recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(term, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  controller.searchSongs(term);
                  FocusScope.of(context).unfocus();
                },
              );
            },
          );
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: controller.searchResults.length,
          itemBuilder: (context, index) {
            final video = controller.searchResults[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(video.thumbnails.lowResUrl, width: 50, height: 50, fit: BoxFit.cover),
              ),
              title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
              subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
              onTap: () {
                playerController.playVideo(video);
                FocusScope.of(context).unfocus();
                Get.toNamed('/player');
              },
              onLongPress: () {
                _showAddToPlaylistDialog(context, video);
              },
            );
          },
        );
      }),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D0D0D),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) Get.back(); // 홈으로 돌아가기
          // index 1은 현재 화면 (Search)
          if (index == 2) Get.toNamed('/library');
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'home'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: 'search'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.library_music), label: 'library'.tr),
        ],
      ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, dynamic video) {
    final box = Hive.box('playlists');
    var keys = box.keys.toList();

    if (keys.isEmpty) {
      Get.snackbar('알림', '먼저 보관함에서 재생목록을 만들어 주세요.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF2B1A4A),
        colorText: Colors.white,
      );
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('재생목록에 추가', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...keys.map((key) {
              Map p = box.get(key);
              List songs = p['songs'] ?? [];
              bool isFull = songs.length >= 100;
              bool alreadyAdded = songs.any((s) => s['id'] == video.id.value);
              return ListTile(
                leading: Icon(
                  Icons.queue_music,
                  color: alreadyAdded ? Colors.grey : const Color(0xFF1DB954),
                ),
                title: Text(
                  p['name'],
                  style: TextStyle(color: alreadyAdded ? Colors.grey : Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  alreadyAdded ? '이미 추가됨' : (isFull ? '가득 참 (100곡)' : '${songs.length}/100곡'),
                  style: TextStyle(color: alreadyAdded || isFull ? Colors.redAccent : Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  if (alreadyAdded || isFull) return;
                  songs.add({
                    'id': video.id.value,
                    'title': video.title,
                    'author': video.author,
                  });
                  p['songs'] = songs;
                  box.put(key, p);
                  Get.back();
                  Get.snackbar('완료', '"${p['name']}"에 추가되었습니다.',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: const Color(0xFF1DB954),
                    colorText: Colors.white,
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
