import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/audio_effects.dart';
import 'package:resonance/core/playback/transition_policy.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_karaoke.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';

UnifiedTrack _track(String title, {String? album, String artist = 'A'}) =>
    UnifiedTrack(
      id: title,
      title: title,
      normalizedTitle: title.toLowerCase(),
      artist: artist,
      normalizedArtist: artist.toLowerCase(),
      album: album,
    );

void main() {
  group('karaoke', () {
    test('parses word timing and translation flag', () {
      final document = LyricsDocument.fromJson({
        'id': 1,
        'synced': true,
        'translatable': true,
        'lines': [
          {
            'startMs': 1000,
            'text': 'Hello world',
            'words': [
              {'startMs': 1000, 'text': 'Hello '},
              {'startMs': 2000, 'text': 'world'},
            ],
          },
        ],
      });
      expect(document.translatable, isTrue);
      expect(document.hasWordTiming, isTrue);
      expect(document.lines.single.words.last.start.inMilliseconds, 2000);
    });

    test('line progress is linear without word timing', () {
      const line = LyricLine(text: 'abcd', start: Duration(seconds: 10));
      const next = Duration(seconds: 14);
      expect(karaokeProgress(line, next, const Duration(seconds: 9)), 0);
      expect(
        karaokeProgress(line, next, const Duration(seconds: 12)),
        closeTo(.5, .001),
      );
      expect(karaokeProgress(line, next, const Duration(seconds: 15)), 1);
    });

    test('word timing fills whole words in order', () {
      const line = LyricLine(
        text: 'aa bb',
        start: Duration(seconds: 1),
        words: [
          LyricWord(text: 'aa ', start: Duration(seconds: 1)),
          LyricWord(text: 'bb', start: Duration(seconds: 3)),
        ],
      );
      // Первое слово целиком спето к середине своего отрезка.
      expect(
        karaokeProgress(
          line,
          const Duration(seconds: 5),
          const Duration(milliseconds: 2900),
        ),
        closeTo(3 / 5, .001),
      );
      expect(nextLyricStart(const [line, LyricLine(text: 'x')], 0), isNull);
    });
  });

  group('audio filter chain', () {
    test('equalizer bands and normalization degrade by support', () {
      final gains = [...EqualizerPreset.bass.gains];
      final full = buildAudioFilterChain(
        support: const AudioFilterSupport(equalizer: true, loudnorm: true),
        equalizerGains: gains,
        normalize: true,
      );
      expect(full, contains('@eq0:equalizer=f=31:t=o:w=1:g=6.0'));
      expect(full, isNot(contains('@eq4')));
      expect(
        full,
        endsWith('@norm:loudnorm=I=-16:TP=-1.5:LRA=11,@normrate:aresample=48000'),
        reason: 'loudnorm upsamples to 192 kHz, which iOS output plays silently',
      );

      final mobile = buildAudioFilterChain(
        support: const AudioFilterSupport(equalizer: true),
        equalizerGains: gains,
        normalize: true,
      );
      expect(mobile, isNot(contains('norm')));
      expect(
        buildAudioFilterChain(
          support: AudioFilterSupport.none,
          normalize: true,
        ),
        isEmpty,
      );
    });

    test('profile json round trip clamps gains', () {
      final profile = EqualizerProfile.fromJson({
        'enabled': true,
        'preset': 'custom',
        'gains': [40, -40],
      });
      expect(profile.gains.first, equalizerMaxGainDb);
      expect(profile.gains[1], -equalizerMaxGainDb);
      expect(profile.gains, hasLength(equalizerBands.length));
    });
  });

  group('smart transitions', () {
    test('keeps album flow and live endings without fade', () {
      expect(
        smartTransitionSkipsFade(
          _track('One', album: 'LP'),
          _track('Two', album: 'lp'),
        ),
        isTrue,
      );
      expect(
        smartTransitionSkipsFade(_track('Song (Live)'), _track('Next')),
        isTrue,
      );
      expect(
        smartTransitionSkipsFade(
          _track('Symphony No. 5: I. Allegro con brio'),
          _track('Pop'),
        ),
        isTrue,
      );
      expect(smartTransitionSkipsFade(_track('Pop'), _track('Rock')), isFalse);
    });
  });
}
