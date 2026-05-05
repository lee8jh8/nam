import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/search_controller_custom.dart';
import '../../player/controllers/player_controller.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});

  final SearchControllerCustom controller = Get.put(SearchControllerCustom());
  final PlayerController playerController = Get.find<PlayerController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          itemCount: controller.searchResults.length,
          itemBuilder: (context, index) {
            final video = controller.searchResults[index];
            return ListTile(
              leading: Image.network(video.thumbnails.lowResUrl, width: 50, height: 50, fit: BoxFit.cover),
              title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
              subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
              onTap: () {
                playerController.playVideo(video);
                // 검색된 곡을 탭하면 플레이를 시작하고 키보드를 닫습니다.
                FocusScope.of(context).unfocus();
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
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'home'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: 'search'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.library_music), label: 'library'.tr),
        ],
      ),
    );
  }
}
