import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/player/clip_service.dart';

void main() {
  test('decodes playable previews and safe external references', () {
    final preview = StageClip.fromJson({
      'id': 'apple-1',
      'title': 'Signal',
      'artist': 'Artist',
      'url': 'https://video.example/preview.m4v',
      'playback': 'direct',
      'kind': 'preview',
      'source': 'Apple Music · 30 сек',
      'sourceUrl': 'https://music.apple.com/music-video/1',
      'offsetMs': 0,
    });
    final external = StageClip.fromJson({
      'id': 'youtube-1',
      'title': 'Signal',
      'artist': 'Artist',
      'playback': 'external',
      'kind': 'musicVideo',
      'source': 'YouTube',
      'sourceUrl': 'https://www.youtube.com/watch?v=1',
      'offsetMs': 0,
    });

    expect(preview.playable, isTrue);
    expect(preview.preview, isTrue);
    expect(preview.url, isNotNull);
    expect(external.playable, isFalse);
    expect(external.url, isNull);
  });

  test('rejects insecure media and external URLs', () {
    expect(
      () => StageClip.fromJson({
        'id': 'bad',
        'title': 'Signal',
        'playback': 'direct',
        'kind': 'preview',
        'source': 'Bad',
        'url': 'http://example.com/video.mp4',
        'sourceUrl': 'https://example.com',
      }),
      throwsFormatException,
    );
  });
  test('parses YouTube embeds and rejects malformed ids', () {
    Map<String, dynamic> embed(String id) => {
      'id': 'musicbrainz-1',
      'title': 'Signal',
      'artist': 'Artist',
      'playback': 'embed',
      'embed': {'provider': 'youtube', 'id': id},
      'kind': 'musicVideo',
      'source': 'MusicBrainz · YouTube',
      'sourceUrl': 'https://www.youtube.com/watch?v=$id',
      'offsetMs': 1500,
    };
    final clip = StageClip.fromJson(embed('dQw4w9WgXcQ'));
    expect(clip.playable, isTrue);
    expect(clip.embedded, isTrue);
    expect(clip.key, 'youtube:dQw4w9WgXcQ');
    expect(clip.offset, const Duration(milliseconds: 1500));
    expect(clip.withOffset(Duration.zero).key, clip.key);
    expect(() => StageClip.fromJson(embed('../x')), throwsFormatException);
  });
}
