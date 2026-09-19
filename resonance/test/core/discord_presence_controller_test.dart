import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/integrations/discord_presence_controller.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

void main() {
  test('maps active playback to Discord listening activity', () {
    final now = DateTime.utc(2026, 9, 18, 12);
    final activity = DiscordPresenceActivity.fromPlayback(
      ResonancePlaybackState(
        queue: [_track('night-drive', artwork: 'https://img.test/cover.jpg')],
        currentIndex: 0,
        playing: true,
        position: const Duration(seconds: 40),
        duration: const Duration(minutes: 3),
      ),
      now: now,
    );

    expect(activity.title, 'Night Drive');
    expect(activity.artist, 'Resonance');
    expect(activity.artworkUrl, 'https://img.test/cover.jpg');
    expect(activity.startedAt, now.subtract(const Duration(seconds: 40)));
    expect(activity.endsAt, now.add(const Duration(minutes: 2, seconds: 20)));
  });

  test('connects, publishes track changes, and disconnects safely', () async {
    final store = _MemoryStore()
      ..values['resonance.discord_presence.application_id'] =
          '123456789012345678';
    final feed = _FakePlaybackFeed(
      ResonancePlaybackState(
        queue: [_track('night-drive')],
        currentIndex: 0,
        playing: true,
        duration: const Duration(minutes: 3),
      ),
    );
    final gateways = <_FakeGateway>[];
    final controller = DiscordPresenceController(store, Future.value(feed), (
      applicationId,
    ) {
      final gateway = _FakeGateway(applicationId);
      gateways.add(gateway);
      return gateway;
    }, supported: true);
    addTearDown(() async {
      controller.dispose();
      await feed.close();
    });

    await _waitUntil(() => controller.state.configured);
    await controller.setEnabled(true);
    expect(controller.state.connected, isTrue);
    expect(gateways.single.applicationId, '123456789012345678');
    expect(gateways.single.activities.single.title, 'Night Drive');

    feed.emit(
      ResonancePlaybackState(
        queue: [_track('midnight-city')],
        currentIndex: 0,
        playing: true,
        duration: const Duration(minutes: 4),
      ),
    );
    await _waitUntil(() => gateways.single.activities.length == 2);
    expect(gateways.single.activities.last.title, 'Midnight City');

    await controller.setEnabled(false);
    expect(controller.state.connected, isFalse);
    expect(gateways.single.disconnects, 1);
    expect(store.values['resonance.discord_presence.enabled'], 'false');
  });

  test('rejects malformed Discord application IDs', () async {
    final feed = _FakePlaybackFeed(const ResonancePlaybackState());
    final controller = DiscordPresenceController(
      _MemoryStore(),
      Future.value(feed),
      (_) => _FakeGateway('unused'),
      supported: true,
    );
    addTearDown(() async {
      controller.dispose();
      await feed.close();
    });

    expect(
      await controller.setApplicationId('not-an-id'),
      'Application ID должен содержать от 15 до 22 цифр.',
    );
    expect(controller.state.configured, isFalse);
  });
}

UnifiedTrack _track(String id, {String? artwork}) => UnifiedTrack(
  id: id,
  title: id == 'midnight-city' ? 'Midnight City' : 'Night Drive',
  normalizedTitle: id,
  artist: 'Resonance',
  normalizedArtist: 'resonance',
  duration: const Duration(minutes: 3),
  artworkUrl: artwork == null ? null : Uri.parse(artwork),
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: id,
      externalUrl: Uri.parse('https://example.test/$id'),
    ),
  ],
  preferredProvider: MusicProvider.soundcloud,
);

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached in time');
}

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class _FakePlaybackFeed implements DiscordPlaybackFeed {
  _FakePlaybackFeed(this._state);

  final StreamController<ResonancePlaybackState> _states =
      StreamController<ResonancePlaybackState>.broadcast();
  ResonancePlaybackState _state;

  @override
  ResonancePlaybackState get state => _state;

  @override
  Stream<ResonancePlaybackState> get states => _states.stream;

  void emit(ResonancePlaybackState value) {
    _state = value;
    _states.add(value);
  }

  Future<void> close() => _states.close();
}

final class _FakeGateway implements DiscordPresenceGateway {
  _FakeGateway(this.applicationId);

  final String applicationId;
  final activities = <DiscordPresenceActivity>[];
  int disconnects = 0;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<void> update(DiscordPresenceActivity activity) async {
    activities.add(activity);
  }
}
