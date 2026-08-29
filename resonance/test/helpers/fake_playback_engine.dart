import 'dart:async';

import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';

final class FakePlaybackEngine implements PlaybackEngine {
  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _volume = StreamController<double>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _audioOutput = StreamController<AudioOutputDevice>.broadcast();
  final _audioOutputs = StreamController<List<AudioOutputDevice>>.broadcast();

  final openedSources = <ResolvedAudioSource>[];
  final openedPositions = <Duration>[];
  var currentPosition = Duration.zero;
  var currentVolume = 70.0;
  var isPlaying = false;
  var shuffle = false;
  var repeatMode = PlaybackRepeatMode.off;
  var selectedAudioOutput = AudioOutputDevice.automatic;
  var outputDevices = const [
    AudioOutputDevice.automatic,
    AudioOutputDevice(id: 'speakers', label: 'Колонки'),
    AudioOutputDevice(id: 'headphones', label: 'Наушники'),
  ];

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<bool> get buffering => _buffering.stream;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<double> get volume => _volume.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<AudioOutputDevice> get audioOutput => _audioOutput.stream;

  @override
  Stream<List<AudioOutputDevice>> get audioOutputs => _audioOutputs.stream;

  @override
  AudioOutputDevice get currentAudioOutput => selectedAudioOutput;

  @override
  List<AudioOutputDevice> get availableAudioOutputs => outputDevices;

  @override
  Future<void> open(
    ResolvedAudioSource source, {
    bool play = true,
    Duration start = Duration.zero,
  }) async {
    openedSources.add(source);
    openedPositions.add(start);
    currentPosition = start;
    isPlaying = play;
    _position.add(start);
    _playing.add(play);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
    _position.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume;
    _volume.add(volume);
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    shuffle = enabled;
  }

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) async {
    repeatMode = mode;
  }

  @override
  Future<void> setAudioOutput(AudioOutputDevice device) async {
    selectedAudioOutput = device;
    _audioOutput.add(device);
  }

  void emitDuration(Duration value) => _duration.add(value);

  void emitCompleted() => _completed.add(true);

  void emitError(String value) => _errors.add(value);

  @override
  Future<void> dispose() async {
    await Future.wait([
      _playing.close(),
      _buffering.close(),
      _completed.close(),
      _position.close(),
      _duration.close(),
      _volume.close(),
      _errors.close(),
      _audioOutput.close(),
      _audioOutputs.close(),
    ]);
  }
}
