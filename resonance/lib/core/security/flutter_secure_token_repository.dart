import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class FlutterSecureTokenRepository implements SecureTokenRepository {
  FlutterSecureTokenRepository(this._store);

  final SecureKeyValueStore _store;

  String _key(MusicProvider provider) => 'resonance.token.${provider.name}';

  @override
  Future<String?> read(MusicProvider provider) => _store.read(_key(provider));

  @override
  Future<void> write(MusicProvider provider, String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token cannot be empty.');
    }
    await _store.write(_key(provider), normalized);
  }

  @override
  Future<void> delete(MusicProvider provider) => _store.delete(_key(provider));
}
