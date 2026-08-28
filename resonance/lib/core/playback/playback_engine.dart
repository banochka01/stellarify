import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';

abstract interface class PlaybackEngine {
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<double> get volume;
  Stream<String> get errors;

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
  Future<void> dispose() => player.dispose();
}
