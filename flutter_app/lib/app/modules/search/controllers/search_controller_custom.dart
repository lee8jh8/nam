import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/services/youtube_service.dart';

class SearchControllerCustom extends GetxController {
  final YouTubeService _ytService = YouTubeService();
  
  var searchResults = <Video>[].obs;
  var recentSearches = <String>[].obs;
  
  var isLoading = false.obs;
  var isMoreLoading = false.obs;
  
  VideoSearchList? _currentSearchList;
  String currentQuery = '';

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

  /// 새로운 검색 수행
  void searchSongs(String query) async {
    if (query.trim().isEmpty) {
      searchResults.clear();
      _currentSearchList = null;
      return;
    }
    
    currentQuery = query;
    isLoading.value = true;
    _addSearchTerm(query);
    
    try {
      _currentSearchList = await _ytService.searchSongs(query);
      if (_currentSearchList != null) {
        searchResults.assignAll(_currentSearchList!);
      }
    } catch (e) {
      print('[Search] Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 다음 페이지 검색 결과 로드
  Future<void> searchMore() async {
    if (isMoreLoading.value || _currentSearchList == null) return;
    
    isMoreLoading.value = true;
    try {
      final nextResults = await _currentSearchList!.nextPage();
      if (nextResults != null) {
        _currentSearchList = nextResults;
        searchResults.addAll(nextResults);
      }
    } catch (e) {
      print('[Search] Load More Error: $e');
    } finally {
      isMoreLoading.value = false;
    }
  }
}
