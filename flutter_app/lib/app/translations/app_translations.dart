import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'ko_KR': {
          'app_name': 'SONIC FLOW',
          'trending_now': '최신 인기곡',
          'search': '검색',
          'library': '재생목록',
          'home': '홈',
        },
        'en_US': {
          'app_name': 'SONIC FLOW',
          'trending_now': 'Trending Now',
          'search': 'Search',
          'library': 'Playlist',
          'home': 'Home',
        }
      };
}
