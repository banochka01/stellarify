import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/recap/listening_recap.dart';
import 'package:resonance/features/recap/listening_recorder.dart';

UnifiedTrack _track(String title, String artist) => UnifiedTrack(
  id: '$artist-$title',
  title: title,
  normalizedTitle: title.toLowerCase(),
  artist: artist,
  normalizedArtist: artist.toLowerCase(),
);

ListeningRecord _listen(UnifiedTrack track, DateTime at, int minutes) =>
    ListeningRecord(
      track: track,
      playedAt: at,
      listened: Duration(minutes: minutes),
    );

void main() {
  final now = DateTime(2026, 10, 9, 22);
  final alpha = _track('Alpha House', 'Knucks, Venna');
  final night = _track('Night Drive', 'Resonance');

  test('recap counts minutes, tops, streak and drops older listens', () {
    final recap = buildListeningRecap(
      [
        _listen(alpha, now, 3),
        _listen(alpha, now.subtract(const Duration(days: 1)), 3),
        _listen(night, now.subtract(const Duration(days: 2)), 4),
        _listen(night, now.subtract(const Duration(days: 20)), 30),
      ],
      RecapPeriod.week,
      now: now,
    );

    expect(recap.plays, 3);
    expect(recap.minutes, 10);
    expect(recap.topTracks.first.track.title, 'Alpha House');
    expect(recap.topTracks.first.plays, 2);
    expect(recap.uniqueArtists, 3);
    expect(recap.topArtists.first.name, isIn(['Knucks', 'Venna']));
    expect(recap.longestStreak, 3);
    expect(recap.activeDays, 3);
    expect(recap.daily.length, 7);
    expect(recap.daily.last, 3);
    expect(recap.peakHour, 22);
  });

  test('an empty history gives an empty recap', () {
    final recap = buildListeningRecap(const [], RecapPeriod.month, now: now);
    expect(recap.empty, isTrue);
    expect(recap.daily.length, 30);
    expect(recap.persona, isNotEmpty);
  });

  test('recorder counts only smooth playback and records once', () async {
    final store = _MemoryStore();
    final recorder = ListeningRecorder(store);
    ResonancePlaybackState at(int seconds, {bool playing = true}) =>
        ResonancePlaybackState(
          queue: [demoTrack],
          currentIndex: 0,
          playing: playing,
          position: Duration(seconds: seconds),
          duration: const Duration(minutes: 3),
        );

    recorder.onPlayback(at(0));
    // Перемотка вперёд не засчитывается.
    recorder.onPlayback(at(90));
    expect(store.records, isEmpty);
    for (var second = 91; second <= 125; second++) {
      recorder.onPlayback(at(second));
    }
    await Future<void>.delayed(Duration.zero);
    expect(store.records, hasLength(1));
    expect(store.records.single.inSeconds, 30);

    recorder.onPlayback(at(126, playing: false));
    recorder.onPlayback(
      ResonancePlaybackState(
        queue: [demoTrack.copyWith(id: 'next')],
        currentIndex: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.records, hasLength(1));
    expect(store.updates.single.inSeconds, 35);
  });
}

final class _MemoryStore implements ListeningStore {
  final records = <Duration>[];
  final updates = <Duration>[];

  @override
  Future<int> recordListen(UnifiedTrack track, Duration listened) async {
    records.add(listened);
    return records.length;
  }

  @override
  Future<void> updateListen(int id, Duration listened) async {
    updates.add(listened);
  }
}
