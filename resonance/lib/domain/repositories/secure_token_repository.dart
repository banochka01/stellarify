import 'package:resonance/domain/entities/music_enums.dart';

abstract interface class SecureTokenRepository {
  Future<String?> read(MusicProvider provider);

  Future<void> write(MusicProvider provider, String token);

  Future<void> delete(MusicProvider provider);
}
