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

  final FeatureTransport transport;
  final Future<bool> Function() hasSession;
  final Duration debounce;

  Timer? _timer;
  String? _lastReportedId;

  void onTrack(UnifiedTrack? track) {
    if (track == null || track.id == _lastReportedId) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_report(track)));
  }

  Future<void> _report(UnifiedTrack track) async {
    try {
      if (!await hasSession()) return;
      _lastReportedId = track.id;
      final provider =
          track.preferredProvider ?? track.sources.firstOrNull?.provider;
      await transport.request(
        'PUT',
        path,
        body: {
          'title': track.title,
          'artist': track.artist,
          'provider': ?provider?.name,
          'trackId': track.id,
        },
      );
    } on Object {
      // Social presence is best-effort.
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
