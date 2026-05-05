import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  var yt = YoutubeExplode();
  try {
    var search = await yt.search.search('Kpop Top 100');
    for (var video in search.take(3)) {
      print('${video.title} - ${video.id}');
    }
  } catch (e) {
    print(e);
  }
  yt.close();
}
