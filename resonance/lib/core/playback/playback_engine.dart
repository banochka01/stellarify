import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';

final class AudioOutputDevice {
  const AudioOutputDevice({required this.id, required this.label});

  static const automatic = AudioOutputDevice(
    id: 'auto',
    label: 'Системное устройство',
  );

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

abstract interface class PlaybackEngine {
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<double> get volume;
  Stream<String> get errors;
  Stream<AudioOutputDevice> get audioOutput;
  Stream<List<AudioOutputDevice>> get audioOutputs;
  AudioOutputDevice get currentAudioOutput;
  List<AudioOutputDevice> get availableAudioOutputs;

  Future<void> open(
    ResolvedAudioSource source, {
    bool play = true,
    Duration start = Duration.zero,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setShuffle(bool enabled);
  Future<void> setRepeatMode(PlaybackRepeatMode mode);
  Future<void> setAudioOutput(AudioOutputDevice device);
  Future<void> dispose();
}

final class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine({media_kit.Player? player})
    : player = player ?? media_kit.Player();

  final media_kit.Player player;

  @override
  Stream<bool> get playing => player.stream.playing;

  @override
  Stream<bool> get buffering => player.stream.buffering;

  @override
  Stream<bool> get completed => player.stream.completed;

  @override
  Stream<Duration> get position => player.stream.position;

  @override
  Stream<Duration> get duration => player.stream.duration;

  @override
  Stream<double> get volume => player.stream.volume;

  @override
  Stream<String> get errors => player.stream.error;

  @override
  Stream<AudioOutputDevice> get audioOutput =>
      player.stream.audioDevice.map(_mapDevice);

  @override
  Stream<List<AudioOutputDevice>> get audioOutputs =>
      player.stream.audioDevices.map(_mapDevices);

  @override
  AudioOutputDevice get currentAudioOutput =>
      _mapDevice(player.state.audioDevice);

  @override
  List<AudioOutputDevice> get availableAudioOutputs =>
      _mapDevices(player.state.audioDevices);

  @override
  Future<void> open(
    ResolvedAudioSource source, {
    bool play = true,
    Duration start = Duration.zero,
  }) {
    final media = media_kit.Media(
      source.streamUrl.toString(),
      httpHeaders: source.headers,
      start: start == Duration.zero ? null : start,
    );
    return player.open(media, play: play);
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);

  @override
  Future<void> setShuffle(bool enabled) => player.setShuffle(enabled);

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) {
    final playlistMode = switch (mode) {
      PlaybackRepeatMode.off ||
      PlaybackRepeatMode.all => media_kit.PlaylistMode.none,
      PlaybackRepeatMode.one => media_kit.PlaylistMode.single,
    };
    return player.setPlaylistMode(playlistMode);
  }

  @override
  Future<void> setAudioOutput(AudioOutputDevice device) =>
      player.setAudioDevice(media_kit.AudioDevice(device.id, device.label));

  @override
  Future<void> dispose() => player.dispose();

  static AudioOutputDevice _mapDevice(media_kit.AudioDevice device) =>
      AudioOutputDevice(
        id: device.name,
        label: device.name == 'auto' || device.description.trim().isEmpty
            ? (device.name == 'auto'
                  ? AudioOutputDevice.automatic.label
                  : device.name)
            : device.description.trim(),
      );

  static List<AudioOutputDevice> _mapDevices(
    List<media_kit.AudioDevice> devices,
  ) {
    final mapped = <AudioOutputDevice>[
      AudioOutputDevice.automatic,
      ...devices.where((device) => device.name != 'auto').map(_mapDevice),
    ];
    return {
      for (final device in mapped) device.id: device,
    }.values.toList(growable: false);
  }
}
