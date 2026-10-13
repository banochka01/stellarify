import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_flags.dart';

/// Reports the current track to `PUT /api/v1/social/now-playing` so friends
/// see it in their feed (the server keeps it for 10 minutes and applies the
/// user's `shareListening` privacy). Only with a Resonance account session;
/// debounced, failures are ignored.
final class NowPlayingReporter {
  NowPlayingReporter({
    required this.transport,
    required this.hasSession,
    this.debounce = const Duration(seconds: 4),
  });

  static const path = '/api/v1/social/now-playing';
  static const maxFieldLength = 200;

  final FeatureTransport transport;
  final Future<bool> Function() hasSession;
  final Duration debounce;

  Timer? _timer;
  String? _lastReportedId;

  void onTrack(UnifiedTrack? track) {
    _timer?.cancel();
    if (track == null || track.id == _lastReportedId) return;
    _timer = Timer(debounce, () => unawaited(report(track)));
  }

  static String _clip(String value) => value.length <= maxFieldLength
      ? value
      : value.substring(0, maxFieldLength);

  Future<void> report(UnifiedTrack track) async {
    try {
      if (!await hasSession()) return;
      final provider =
          track.preferredProvider ?? track.sources.firstOrNull?.provider;
      await transport.request(
        'PUT',
        path,
        body: {
          'title': _clip(track.title),
          'artist': _clip(track.artist),
          'provider': ?provider?.name,
          'trackId': _clip(track.id),
        },
      );
      _lastReportedId = track.id;
    } on Object {
      // Social presence is best-effort; the next track change retries.
    }
  }

  /// Clears the status (sign-out). Must run while the session is still valid.
  Future<void> clear() async {
    _timer?.cancel();
    _lastReportedId = null;
    try {
      await transport
          .request('DELETE', path)
          .timeout(const Duration(seconds: 3));
    } on Object {
      // Expires on the server after 10 minutes anyway.
    }
  }

  void dispose() => _timer?.cancel();
}

final nowPlayingReporterProvider = Provider<NowPlayingReporter?>((ref) {
  if (!ref.watch(featureEnabledProvider(FeatureFlag.social))) return null;
  final reporter = NowPlayingReporter(
    transport: ref.watch(featureTransportProvider),
    hasSession: () async =>
        await ref.read(accountSessionRepositoryProvider).read() != null,
  );
  ref
    ..onDispose(reporter.dispose)
    ..listen(
      playbackStateProvider.select((state) => state.valueOrNull?.currentTrack),
      (_, track) => reporter.onTrack(track),
    );
  return reporter;
});

/// Called by the account controller right before logout.
Future<void> clearNowPlayingBeforeLogout(Ref ref) async {
  final reporter = ref.read(nowPlayingReporterProvider);
  if (reporter != null) {
    await reporter.clear();
    return;
  }
  try {
    await ref
        .read(featureTransportProvider)
        .request('DELETE', NowPlayingReporter.path)
        .timeout(const Duration(seconds: 3));
  } on Object {
    // Best-effort.
  }
}
