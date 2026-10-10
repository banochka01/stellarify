import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/wave/daily_mixes.dart';

final class NewRelease {
  const NewRelease({
    required this.id,
    required this.title,
    required this.artist,
    required this.releaseDate,
    required this.kind,
    required this.externalUrl,
    this.artworkUrl,
  });

  factory NewRelease.fromJson(Map<String, dynamic> json) {
    final artwork = Uri.tryParse(json['artworkUrl'] as String? ?? '');
    return NewRelease(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      releaseDate: parseReleaseDate(json['releaseDate'] as String? ?? ''),
      kind: json['kind'] as String? ?? 'album',
      externalUrl: Uri.parse(json['externalUrl'] as String),
      artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
    );
  }

  final String id;
  final String title;
  final String artist;
  final DateTime releaseDate;
  final String kind;
  final Uri externalUrl;
  final Uri? artworkUrl;

  String get kindLabel => switch (kind) {
    'single' => 'Сингл',
    'compilation' => 'Сборник',
    _ => 'Альбом',
  };
}

DateTime parseReleaseDate(String value) {
  final padded = value.length == 4
      ? '$value-01-01'
      : value.length == 7
      ? '$value-01'
      : value;
  return DateTime.tryParse(padded) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

enum ReleaseCheckFrequency { daily, weekly }

final class ReleaseAlertSettings {
  const ReleaseAlertSettings({
    this.enabled = true,
    this.frequency = ReleaseCheckFrequency.daily,
    this.lastSeenAt,
  });

  final bool enabled;
  final ReleaseCheckFrequency frequency;
  final DateTime? lastSeenAt;

  String get frequencyLabel => frequency == ReleaseCheckFrequency.daily
      ? 'Каждый день'
      : 'Раз в неделю, по пятницам';
}

/// In-app release alerts (badge on Home). No push infrastructure: the app
/// checks the cached server feed on its own schedule.
final releaseAlertsProvider =
    StateNotifierProvider<ReleaseAlertsController, ReleaseAlertSettings>((ref) {
      final controller = ReleaseAlertsController(
        ref.watch(secureKeyValueStoreProvider),
      );
      unawaited(controller.load());
      return controller;
    });

class ReleaseAlertsController extends StateNotifier<ReleaseAlertSettings> {
  ReleaseAlertsController(this._store) : super(const ReleaseAlertSettings());

  static const _enabledKey = 'resonance.releases.alerts';
  static const _frequencyKey = 'resonance.releases.frequency';
  static const _seenKey = 'resonance.releases.seen_at';
  final SecureKeyValueStore _store;

  Future<void> load() async {
    try {
      final values = await Future.wait([
        _store.read(_enabledKey),
        _store.read(_frequencyKey),
        _store.read(_seenKey),
      ]);
      state = ReleaseAlertSettings(
        enabled: values[0] != 'false',
        frequency: values[1] == 'weekly'
            ? ReleaseCheckFrequency.weekly
            : ReleaseCheckFrequency.daily,
        lastSeenAt: DateTime.tryParse(values[2] ?? ''),
      );
    } on Object {
      // Defaults are fine when secure storage is unavailable.
    }
  }

  Future<void> setEnabled(bool value) async {
    state = ReleaseAlertSettings(
      enabled: value,
      frequency: state.frequency,
      lastSeenAt: state.lastSeenAt,
    );
    await _store.write(_enabledKey, '$value');
  }

  Future<void> setFrequency(ReleaseCheckFrequency value) async {
    state = ReleaseAlertSettings(
      enabled: state.enabled,
      frequency: value,
      lastSeenAt: state.lastSeenAt,
    );
    await _store.write(_frequencyKey, value.name);
  }

  Future<void> markSeen([DateTime? at]) async {
    final seen = (at ?? DateTime.now()).toUtc();
    state = ReleaseAlertSettings(
      enabled: state.enabled,
      frequency: state.frequency,
      lastSeenAt: seen,
    );
    await _store.write(_seenKey, seen.toIso8601String());
  }
}

/// Number of releases that should light the badge.
int unseenReleaseCount(
  List<NewRelease> releases,
  ReleaseAlertSettings settings,
  DateTime now,
) {
  if (!settings.enabled) return 0;
  var since = settings.lastSeenAt ?? now.subtract(const Duration(days: 7));
  if (settings.frequency == ReleaseCheckFrequency.weekly) {
    // Weekly digest: only releases up to the latest Friday count.
    final friday = latestFriday(now);
    if (!since.isBefore(friday)) return 0;
    return releases
        .where(
          (release) =>
              release.releaseDate.isAfter(since) &&
              !release.releaseDate.isAfter(friday),
        )
        .length;
  }
  since = since.subtract(const Duration(days: 1));
  return releases.where((release) => release.releaseDate.isAfter(since)).length;
}

/// UTC midnight of the latest Friday (global new-music day).
DateTime latestFriday(DateTime now) {
  final utc = now.toUtc();
  final midnight = DateTime.utc(utc.year, utc.month, utc.day);
  final back = (utc.weekday - DateTime.friday + 7) % 7;
  return midnight.subtract(Duration(days: back));
}

Future<List<String>> _followedArtists(Ref ref) async {
  final library = await ref.watch(libraryControllerProvider.future);
  final counts = <String, int>{};
  for (final track in [...library.favorites, ...library.tracks]) {
    counts.update(track.artist, (value) => value + 1, ifAbsent: () => 1);
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(40).map((entry) => entry.key).toList();
}

/// "Новое от ваших артистов" (last 30 days).
final newReleasesProvider = FutureProvider<List<NewRelease>>((ref) async {
  final artists = await _followedArtists(ref);
  final response = await ref
      .read(resonanceHttpClientProvider)
      .dio
      .postUri<Map<String, dynamic>>(
        BackendEndpoint.requireCurrent().resolve('/api/v1/releases/feed'),
        data: {'artists': artists, 'days': 30},
      );
  final raw = response.data?['releases'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      NewRelease.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
});

final class FreshWeek {
  const FreshWeek({required this.weekOf, required this.tracks});

  final DateTime? weekOf;
  final List<UnifiedTrack> tracks;
}

/// Auto-playlist "Свежее за неделю", rebuilt by the server every Friday.
final freshWeekProvider = FutureProvider<FreshWeek>((ref) async {
  final artists = await _followedArtists(ref);
  final response = await ref
      .read(resonanceHttpClientProvider)
      .dio
      .postUri<Map<String, dynamic>>(
        BackendEndpoint.requireCurrent().resolve('/api/v1/releases/fresh-week'),
        data: {
          'artists': artists,
          'enabledProviders': ['soundcloud', 'yandex'],
        },
        options: await providerTokenOptions(
          ref.read(secureTokenRepositoryProvider),
        ),
      );
  final data = response.data;
  return FreshWeek(
    weekOf: DateTime.tryParse(data?['weekOf'] as String? ?? ''),
    tracks: [
      for (final item in data?['tracks'] as List? ?? const [])
        ?unifiedTrackFromWaveItem(Map<String, dynamic>.from(item as Map)),
    ],
  );
});
