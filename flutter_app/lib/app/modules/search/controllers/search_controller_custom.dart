import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/services/youtube_service.dart';

class SearchControllerCustom extends GetxController {
  final YouTubeService _ytService = YouTubeService();
  var searchResults = <Video>[].obs;
  var recentSearches = <String>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    var box = Hive.box('settings');
    List searches = box.get('recent_searches', defaultValue: []);
    recentSearches.assignAll(searches.cast<String>());
  }

  void _addSearchTerm(String term) {
    if (term.trim().isEmpty) return;
    recentSearches.remove(term);
    recentSearches.insert(0, term);
    if (recentSearches.length > 20) {
      recentSearches.assignAll(recentSearches.sublist(0, 20));
    }
    Hive.box('settings').put('recent_searches', recentSearches.toList());
  }

  void searchSongs(String query) async {
    if (query.trim().isEmpty) {
      searchResults.clear();
      return;
    }
    
    isLoading.value = true;
    _addSearchTerm(query);
    try {
      var results = await _ytService.searchSongs(query);
      searchResults.assignAll(results);
    } catch (e) {
      print(e);
    } finally {
      isLoading.value = false;
    }
  }
}
