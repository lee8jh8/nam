import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppleMusicService {
  /// iTunes Search API를 사용하여 곡의 고화질 썸네일 URL을 가져옴
  Future<String?> getTrackArtwork(String artist, String trackName) async {
    try {
      final term = Uri.encodeComponent('$artist $trackName');
      final url = 'https://itunes.apple.com/search?term=$term&entity=song&limit=1';

      if (kDebugMode) print('[iTunes] Searching artwork for: $artist - $trackName');

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final results = data['results'] as List?;
      
      if (results != null && results.isNotEmpty) {
        final artworkUrl = results.first['artworkUrl100'] as String?;
        if (artworkUrl != null) {
          // 사이즈 부분을 유연하게 600x600으로 변경 (100x100, 60x60 등 대응)
          return artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '600x600');
        }
      }
    } catch (e) {
      if (kDebugMode) print('[iTunes] Artwork search failed: $e');
    }
    return null;
  }
}
