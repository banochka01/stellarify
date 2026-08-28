import 'package:resonance/domain/entities/music_enums.dart';

abstract interface class ProviderAuthService {
  MusicProvider get provider;

  Future<bool> isAuthenticated();

  Future<void> authenticate();

  Future<void> logout();
}
