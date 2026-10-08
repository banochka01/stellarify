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

  test('fills the Yandex size template even after Uri encoding', () {
    expect(
      highQualityArtworkUrl(
        Uri.parse('https://avatars.yandex.net/get-music-content/1/abc/%%'),
        targetSize: 160,
      ),
      'https://avatars.yandex.net/get-music-content/1/abc/400x400',
    );
  });

  test('artwork sizes share a few cache buckets', () {
    expect(artworkCacheBucket(52), 160);
    expect(artworkCacheBucket(200), 320);
    expect(artworkCacheBucket(400), 640);
    expect(artworkCacheBucket(900), 1000);
    expect(artworkCacheBucket(2400), 1400);
  });
}
