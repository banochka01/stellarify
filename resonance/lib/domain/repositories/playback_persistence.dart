import 'package:resonance/domain/entities/playback_session.dart';

abstract interface class PlaybackPersistence {
  Future<PlaybackSession> load();

  Future<void> save(PlaybackSession session);
}
