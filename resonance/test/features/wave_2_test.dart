import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/wave/daily_mixes.dart';
import 'package:resonance/features/wave/new_releases.dart';
import 'package:resonance/features/wave/wave_blocks.dart';
import 'package:resonance/features/wave/wave_controller.dart';

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

UnifiedTrack _track(String artist, String title) => UnifiedTrack(
  id: 'soundcloud:$title',
  title: title,
  normalizedTitle: title.toLowerCase(),
  artist: artist,
  normalizedArtist: artist.toLowerCase(),
);

void main() {
  test('wave keys match server normalization', () {
    expect(normalizeWaveKey('  Саша—Ш!  feat. X '), 'саша ш feat x');
    expect(
      waveTrackKey(_track('Ёлка', 'Прованс (Live)')),
      'ёлка::прованс live',
    );
  });

  test('blocks merge by last write and tombstones hide entries', () async {
    var clock = DateTime.utc(2026, 10, 1);
    final store = _MemoryStore();
    final controller = WaveBlocksController(store, null, now: () => clock);
    await controller.load();
    await controller.blockArtist('Artist A');
    await controller.blockTrack(_track('B', 'Song'));
    expect(controller.blockedArtists, ['artist a']);
    expect(controller.isBlocked(_track('artist  A', 'Any')), isTrue);
    clock = clock.add(const Duration(minutes: 1));
    await controller.unblock(
      controller.active.firstWhere(
        (block) => block.kind == WaveBlockKind.artist,
      ),
    );
    expect(controller.blockedArtists, isEmpty);
    expect(controller.blockedTracks, ['b::song']);

    final restored = WaveBlocksController(store, null);
    await restored.load();
    expect(restored.blockedTracks, ['b::song']);

    final older = WaveBlock(
      kind: WaveBlockKind.track,
      key: 'b::song',
      label: 'B — Song',
      removed: true,
      updatedAt: DateTime.utc(2020),
    );
    expect(
      mergeWaveBlocks(restored.state, [
        older,
      ]).where((block) => !block.removed).length,
      1,
    );
  });

  test('skip learning: early skip vs full listen', () {
    const duration = Duration(minutes: 3);
    expect(waveFeedbackType(const Duration(seconds: 10), duration), 'skipped');
    expect(waveFeedbackType(const Duration(minutes: 3), duration), 'finished');
    expect(waveContextFields(DateTime(2026, 10, 11, 8)), {
      'localHour': 8,
      'weekday': DateTime.sunday,
    });
  });

  test('daily mixes parse playable tracks only', () {
    final parsed = parseDailyMixes({
      'nextRefreshAt': '2026-10-12T03:00:00.000Z',
      'mixes': [
        {
          'id': 'd:morning',
          'kind': 'morning',
          'title': 'Утро',
          'subtitle': 'x',
          'tracks': [
            {
              'provider': 'soundcloud',
              'id': '1',
              'title': 'T',
              'artist': 'A',
              'externalUrl': 'https://soundcloud.com/a/t',
            },
            {'provider': 'unknown', 'id': '2', 'title': 'T', 'artist': 'A'},
          ],
        },
      ],
    });
    expect(parsed.mixes.single.title, 'Утро');
    expect(parsed.mixes.single.tracks.single.id, 'soundcloud:1');
  });

  test('release badge honours toggle and frequency', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    final releases = [
      NewRelease(
        id: '1',
        title: 'New',
        artist: 'A',
        releaseDate: parseReleaseDate('2026-10-09'),
        kind: 'single',
        externalUrl: Uri.parse('https://open.spotify.com/album/1'),
      ),
      NewRelease(
        id: '2',
        title: 'Old',
        artist: 'A',
        releaseDate: parseReleaseDate('2026-09'),
        kind: 'album',
        externalUrl: Uri.parse('https://open.spotify.com/album/2'),
      ),
    ];
    expect(unseenReleaseCount(releases, const ReleaseAlertSettings(), now), 1);
    expect(
      unseenReleaseCount(
        releases,
        const ReleaseAlertSettings(enabled: false),
        now,
      ),
      0,
    );
    expect(latestFriday(now), DateTime.utc(2026, 10, 9));
    expect(
      unseenReleaseCount(
        releases,
        ReleaseAlertSettings(
          frequency: ReleaseCheckFrequency.weekly,
          lastSeenAt: DateTime.utc(2026, 10, 10),
        ),
        now,
      ),
      0,
    );
  });
}
