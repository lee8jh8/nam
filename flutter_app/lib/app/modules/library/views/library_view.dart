import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../player/controllers/player_controller.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('재생목록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          ValueListenableBuilder(
            valueListenable: Hive.box('playlists').listenable(),
            builder: (context, Box box, _) {
              if (box.keys.length >= 10) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF1DB954)),
                onPressed: () => _showCreatePlaylistDialog(context),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('playlists').listenable(),
        builder: (context, Box box, _) {
          var keys = box.keys.toList();
          if (keys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_music, color: Colors.white24, size: 80),
                  const SizedBox(height: 16),
                  const Text('저장된 재생목록이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('재생목록 만들기'),
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              var key = keys[index];
              Map p = box.get(key);
              List songs = p['songs'] ?? [];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.queue_music, color: Color(0xFF1DB954), size: 32),
                ),
                title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('${songs.length}곡 · 최대 100곡', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  color: const Color(0xFF1A1A1A),
                  onSelected: (value) {
                    if (value == 'delete') {
                      Get.defaultDialog(
                        title: '삭제',
                        titleStyle: const TextStyle(color: Colors.white),
                        backgroundColor: const Color(0xFF1A1A1A),
                        middleText: '"${p['name']}" 재생목록을 삭제하시겠습니까?',
                        middleTextStyle: const TextStyle(color: Colors.white70),
                        confirm: TextButton(
                          onPressed: () { box.delete(key); Get.back(); },
                          child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
                        ),
                        cancel: TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('취소', style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    } else if (value == 'rename') {
                      _showRenamePlaylistDialog(context, key, p['name']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('이름 변경', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
                onTap: () {
                  Get.to(() => PlaylistDetailView(playlistKey: key));
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D0D0D),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Get.offAllNamed('/home');
          if (index == 1) Get.toNamed('/search');
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'home'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: 'search'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.library_music), label: 'library'.tr),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final box = Hive.box('playlists');
    if (box.keys.length >= 10) {
      Get.snackbar('알림', '재생목록은 최대 10개까지 만들 수 있습니다.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF2B1A4A),
        colorText: Colors.white,
      );
      return;
    }

    final textController = TextEditingController();
    Get.defaultDialog(
      title: '새 재생목록',
      titleStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1A1A),
      content: TextField(
        controller: textController,
        autofocus: true,
        maxLength: 20,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '재생목록 이름',
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1DB954))),
        ),
      ),
      confirm: TextButton(
        onPressed: () {
          final name = textController.text.trim();
          if (name.isEmpty) return;
          box.add({'name': name, 'songs': []});
          Get.back();
          Get.snackbar('완료', '"$name" 재생목록이 생성되었습니다.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF1DB954),
            colorText: Colors.white,
          );
        },
        child: const Text('만들기', style: TextStyle(color: Color(0xFF1DB954))),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('취소', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, dynamic key, String currentName) {
    final textController = TextEditingController(text: currentName);
    Get.defaultDialog(
      title: '이름 변경',
      titleStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1A1A),
      content: TextField(
        controller: textController,
        autofocus: true,
        maxLength: 20,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '새 이름',
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1DB954))),
        ),
      ),
      confirm: TextButton(
        onPressed: () {
          final name = textController.text.trim();
          if (name.isEmpty) return;
          var box = Hive.box('playlists');
          Map current = box.get(key);
          current['name'] = name;
          box.put(key, current);
          Get.back();
        },
        child: const Text('변경', style: TextStyle(color: Color(0xFF1DB954))),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('취소', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}


/// 재생목록 상세 화면 (곡 목록 표시 및 관리)
class PlaylistDetailView extends StatelessWidget {
  final dynamic playlistKey;
  const PlaylistDetailView({super.key, required this.playlistKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('playlists').listenable(),
        builder: (context, Box box, _) {
          Map? playlist = box.get(playlistKey);
          if (playlist == null) {
            return const Center(child: Text('재생목록을 찾을 수 없습니다.', style: TextStyle(color: Colors.grey)));
          }
          List songs = List.from(playlist['songs'] ?? []);
          return Column(
            children: [
              // 재생목록 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.queue_music, color: Color(0xFF1DB954), size: 48),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                          const SizedBox(height: 4),
                          Text('${songs.length}/100곡', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 전체 재생 버튼
              if (songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('전체 재생', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            var playerController = Get.find<PlayerController>();
                            playerController.playPlaylist(playlist['name'], songs.cast<Map>(), initialIndex: 0);
                            Get.toNamed('/player');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shuffle, size: 20),
                          label: const Text('셔플', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () {
                            var playerController = Get.find<PlayerController>();
                            playerController.isShuffle.value = true;
                            playerController.playPlaylist(playlist['name'], songs.cast<Map>(), initialIndex: 0);
                            Get.toNamed('/player');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 곡 리스트
              Expanded(
                child: songs.isEmpty
                  ? const Center(child: Text('곡을 추가해 주세요.\n검색 화면에서 곡을 길게 누르면 추가할 수 있습니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: songs.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final item = songs.removeAt(oldIndex);
                        songs.insert(newIndex, item);
                        playlist['songs'] = songs;
                        box.put(playlistKey, playlist);
                      },
                      itemBuilder: (context, index) {
                        var song = songs[index];
                        return ListTile(
                          key: ValueKey('${song['id']}_$index'),
                          leading: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                          title: Text(song['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(song['author'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () {
                              songs.removeAt(index);
                              playlist['songs'] = songs;
                              box.put(playlistKey, playlist);
                            },
                          ),
                          onTap: () {
                            // 해당 곡부터 재생 (전체 리스트 전달하되 시작 인덱스 지정)
                            var playerController = Get.find<PlayerController>();
                            playerController.playPlaylist(playlist['name'], songs.cast<Map>(), initialIndex: index);
                            Get.toNamed('/player');
                          },
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
