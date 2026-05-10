import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LastFmTrack {
  final String name;
  final String artist;
  final String? imageUrl;

  LastFmTrack({required this.name, required this.artist, this.imageUrl});

  LastFmTrack copyWith({String? imageUrl}) {
    return LastFmTrack(
      name: name,
      artist: artist,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class LastFmService {
  static const String _apiKey = 'c702be6f5c40de7edebfe9775a077461';
  static const String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';

  /// 현재 곡과 유사한 트랙 목록을 Last.fm에서 가져옴 (track.getSimilar)
  Future<List<LastFmTrack>> getSimilarTracks(String trackName, String artistName, {int limit = 10}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'method': 'track.getSimilar',
        'track': trackName,
        'artist': artistName,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
        'autocorrect': '1',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final tracks = data['similartracks']?['track'] as List?;
      if (tracks == null) return [];

      return tracks.map((t) {
        String? img;
        final images = t['image'] as List?;
        if (images != null && images.isNotEmpty) {
          img = images.last['#text'];
        }
        return LastFmTrack(
          name: t['name'] ?? '',
          artist: t['artist']?['name'] ?? '',
          imageUrl: img,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 특정 국가의 인기 트랙을 가져옴 (geo.getTopTracks) - 페이지네이션 지원
  Future<List<LastFmTrack>> getTopTracksByCountry(String country, {int limit = 20, int page = 1}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'method': 'geo.getTopTracks',
        'country': country,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
        'page': page.toString(),
      });

      if (kDebugMode) print('[LastFM] Fetching top tracks for country: $country (Page: $page)');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final tracks = data['toptracks']?['track'] as List?;
      if (tracks == null) return [];

      return tracks.map((t) {
        String? img;
        final images = t['image'] as List?;
        if (images != null && images.isNotEmpty) {
          img = images.last['#text'];
        }
        return LastFmTrack(
          name: t['name'] ?? '',
          artist: t['artist']?['name'] ?? '',
          imageUrl: (img != null && img.isNotEmpty) ? img : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 글로벌 인기 트랙 차트를 가져옴 (chart.getTopTracks) - 페이지네이션 지원
  Future<List<LastFmTrack>> getTopTracks({int limit = 20, int page = 1}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'method': 'chart.getTopTracks',
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
        'page': page.toString(),
      });

      if (kDebugMode) print('[LastFM] Fetching global top tracks (Page: $page)');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final tracks = data['tracks']?['track'] as List?;
      if (tracks == null) return [];

      return tracks.map((t) {
        String? img;
        final images = t['image'] as List?;
        if (images != null && images.isNotEmpty) {
          img = images.last['#text'];
        }
        return LastFmTrack(
          name: t['name'] ?? '',
          artist: t['artist']?['name'] ?? '',
          imageUrl: (img != null && img.isNotEmpty) ? img : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
