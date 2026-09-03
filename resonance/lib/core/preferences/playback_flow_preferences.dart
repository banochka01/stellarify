import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';

final class PlaybackFlowSettings {
  const PlaybackFlowSettings({
    this.enabled = true,
    this.transitionMs = 1600,
    this.normalizeLoudness = true,
    this.visualizer = true,
  });

  final bool enabled;
  final int transitionMs;
  final bool normalizeLoudness;
  final bool visualizer;

  Duration get transitionDuration => Duration(milliseconds: transitionMs);

  PlaybackFlowSettings copyWith({
    bool? enabled,
    int? transitionMs,
    bool? normalizeLoudness,
    bool? visualizer,
  }) => PlaybackFlowSettings(
    enabled: enabled ?? this.enabled,
    transitionMs: transitionMs ?? this.transitionMs,
    normalizeLoudness: normalizeLoudness ?? this.normalizeLoudness,
    visualizer: visualizer ?? this.visualizer,
  );
}

final class PlaybackFlowPreferences {
  PlaybackFlowPreferences(this._store);

  static const _enabledKey = 'resonance.flow.enabled';
  static const _transitionKey = 'resonance.flow.transition_ms';
  static const _normalizeKey = 'resonance.flow.normalize';
  static const _visualizerKey = 'resonance.flow.visualizer';
  static const allowedTransitionMs = [0, 800, 1600, 2500, 4000];
  final SecureKeyValueStore _store;

  Future<PlaybackFlowSettings> read() async {
    final values = await Future.wait([
      _store.read(_enabledKey),
      _store.read(_transitionKey),
      _store.read(_normalizeKey),
      _store.read(_visualizerKey),
    ]);
    final parsedTransition = int.tryParse(values[1] ?? '');
    return PlaybackFlowSettings(
      enabled: values[0] != 'false',
      transitionMs: allowedTransitionMs.contains(parsedTransition)
          ? parsedTransition!
          : 1600,
      normalizeLoudness: values[2] != 'false',
      visualizer: values[3] != 'false',
    );
  }

  Future<void> write(PlaybackFlowSettings value) => Future.wait([
    _store.write(_enabledKey, value.enabled.toString()),
    _store.write(_transitionKey, value.transitionMs.toString()),
    _store.write(_normalizeKey, value.normalizeLoudness.toString()),
    _store.write(_visualizerKey, value.visualizer.toString()),
  ]);
}

final class PlaybackFlowController extends StateNotifier<PlaybackFlowSettings> {
  PlaybackFlowController(this._preferences)
    : super(const PlaybackFlowSettings()) {
    _load();
  }

  final PlaybackFlowPreferences _preferences;

  Future<void> _load() async {
    try {
      state = await _preferences.read();
    } on Object {
      // Playback remains usable with safe defaults when storage is unavailable.
    }
  }

  Future<PlaybackFlowSettings> update(PlaybackFlowSettings next) async {
    state = next;
    await _preferences.write(next);
    return next;
  }
}
