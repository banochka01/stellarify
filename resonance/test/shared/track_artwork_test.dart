import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

void main() {
  test('upgrades provider artwork URLs without changing unrelated hosts', () {
    expect(
      highQualityArtworkUrl(
        Uri.parse('https://i1.sndcdn.com/artworks-demo-large.jpg'),
      ),
      'https://i1.sndcdn.com/artworks-demo-t500x500.jpg',
    );
    expect(
      highQualityArtworkUrl(
        Uri.parse('https://avatars.yandex.net/get-music-content/a/400x400'),
      ),
      'https://avatars.yandex.net/get-music-content/a/1000x1000',
    );
    expect(
      highQualityArtworkUrl(Uri.parse('https://example.com/cover.jpg')),
      'https://example.com/cover.jpg',
    );
  });
}
