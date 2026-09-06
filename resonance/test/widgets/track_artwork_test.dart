import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

UnifiedTrack _track({Uri? artworkUrl}) => UnifiedTrack(
      id: 't1',
      title: 'nuts',
      normalizedTitle: 'nuts',
      artist: 'Lil Peep, rainy bear',
      normalizedArtist: 'lil peep rainy bear',
      artworkUrl: artworkUrl,
      sources: [
        TrackSource(
          provider: MusicProvider.soundcloud,
          externalId: 't1',
          externalUrl: Uri.parse('https://snd.test/t'),
        ),
      ],
    );

void main() {
  test('highQualityArtworkUrl upgrades SoundCloud artwork to t500x500', () {
    final url = Uri.parse('https://i1.sndcdn.com/artworks-999-large.jpg');
    expect(
      highQualityArtworkUrl(url),
      'https://i1.sndcdn.com/artworks-999-t500x500.jpg',
    );
  });

  test('highQualityArtworkUrl keeps other hosts untouched', () {
    final url = Uri.parse('https://example.com/cover.jpg');
    expect(highQualityArtworkUrl(url), 'https://example.com/cover.jpg');
  });

  testWidgets('TrackArtwork renders gradient fallback with initials when artwork is missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: TrackArtwork(track: _track(), size: 120)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('LP'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
  });

  testWidgets('TrackArtwork fallback gradient is deterministic per track', (tester) async {
    final first = ArtworkFallback.gradientFor(_track());
    final second = ArtworkFallback.gradientFor(_track());
    expect(first, second);
    final other = ArtworkFallback.gradientFor(
      _track(artworkUrl: Uri.parse('https://example.com/a.jpg')).copyWith(title: 'different'),
    );
    expect(listEquals(first, other), isFalse);
  });
}
