import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/preferences/onboarding_preferences.dart';

final class AudioOutputState {
  const AudioOutputState({
    this.devices = const [AudioOutputDevice.automatic],
    this.selected = AudioOutputDevice.automatic,
    this.preferredId = 'auto',
    this.changing = false,
    this.error,
  });

  final List<AudioOutputDevice> devices;
  final AudioOutputDevice selected;
  final String preferredId;
  final bool changing;
  final String? error;

  AudioOutputState copyWith({
    List<AudioOutputDevice>? devices,
    AudioOutputDevice? selected,
    String? preferredId,
    bool? changing,
    String? error,
    bool clearError = false,
  }) => AudioOutputState(
    devices: devices ?? this.devices,
    selected: selected ?? this.selected,
    preferredId: preferredId ?? this.preferredId,
    changing: changing ?? this.changing,
    error: clearError ? null : error ?? this.error,
  );
}

final class AudioOutputController extends StateNotifier<AudioOutputState> {
  AudioOutputController(this._engine, this._preferences)
    : super(
        AudioOutputState(
          devices: _normalize(_engine.availableAudioOutputs),
          selected: _engine.currentAudioOutput,
        ),
      ) {
    _devicesSubscription = _engine.audioOutputs.listen(_handleDevices);
    _selectedSubscription = _engine.audioOutput.listen((device) {
      state = state.copyWith(selected: device, changing: false);
    });
    unawaited(_restorePreference());
  }

  final PlaybackEngine _engine;
  final OnboardingPreferences _preferences;
  late final StreamSubscription<List<AudioOutputDevice>> _devicesSubscription;
  late final StreamSubscription<AudioOutputDevice> _selectedSubscription;

  Future<void> select(AudioOutputDevice device) async {
    final previousPreferredId = state.preferredId;
    state = state.copyWith(
      preferredId: device.id,
      changing: true,
      clearError: true,
    );
    try {
      await _engine.setAudioOutput(device);
      await _preferences.setAudioOutputId(device.id);
      state = state.copyWith(selected: device, changing: false);
    } on Object {
      state = state.copyWith(
        preferredId: previousPreferredId,
        changing: false,
        error: 'Не удалось переключить аудиовыход',
      );
    }
  }

  Future<void> _restorePreference() async {
    var preferred = 'auto';
    try {
      preferred = await _preferences.readAudioOutputId() ?? 'auto';
    } on Object {
      // Automatic routing remains available if platform storage is unavailable.
    }
    state = state.copyWith(preferredId: preferred);
    await _applyPreferredIfAvailable();
  }

  void _handleDevices(List<AudioOutputDevice> devices) {
    state = state.copyWith(devices: _normalize(devices));
    unawaited(_applyPreferredIfAvailable());
  }

  Future<void> _applyPreferredIfAvailable() async {
    final preferred = state.devices
        .where((device) => device.id == state.preferredId)
        .firstOrNull;
    if (preferred == null || preferred.id == state.selected.id) return;
    await select(preferred);
  }

  static List<AudioOutputDevice> _normalize(List<AudioOutputDevice> devices) =>
      {
        AudioOutputDevice.automatic.id: AudioOutputDevice.automatic,
        for (final device in devices) device.id: device,
      }.values.toList(growable: false);

  @override
  void dispose() {
    unawaited(_devicesSubscription.cancel());
    unawaited(_selectedSubscription.cancel());
    super.dispose();
  }
}
