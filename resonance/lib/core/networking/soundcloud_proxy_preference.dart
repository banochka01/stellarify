import 'package:resonance/core/security/flutter_secure_token_repository.dart';

abstract interface class SoundCloudProxyPreference {
  Future<bool> read();

  Future<void> write(bool enabled);
}

final class SecureSoundCloudProxyPreference
    implements SoundCloudProxyPreference {
  SecureSoundCloudProxyPreference(this._store);

  static const _key = 'resonance.soundcloud.proxy.enabled';
  final SecureKeyValueStore _store;

  @override
  Future<bool> read() async => await _store.read(_key) == 'true';

  @override
  Future<void> write(bool enabled) => _store.write(_key, '$enabled');
}
