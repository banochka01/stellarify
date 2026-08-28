import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/networking/soundcloud_proxy_preference.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';

void main() {
  test('stores only the SoundCloud proxy toggle on the client', () async {
    final store = _MemoryStore();
    final preference = SecureSoundCloudProxyPreference(store);

    expect(await preference.read(), isFalse);

    await preference.write(true);

    expect(await preference.read(), isTrue);
    expect(store.values, {'resonance.soundcloud.proxy.enabled': 'true'});
  });
}

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
