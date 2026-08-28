import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';

void main() {
  test('stores token under provider-scoped secure key', () async {
    final store = _MemorySecureStore();
    final repository = FlutterSecureTokenRepository(store);

    await repository.write(MusicProvider.yandex, '  secret-token  ');

    expect(store.values['resonance.token.yandex'], 'secret-token');
    expect(await repository.read(MusicProvider.yandex), 'secret-token');
    await repository.delete(MusicProvider.yandex);
    expect(await repository.read(MusicProvider.yandex), isNull);
  });

  test('keeps Yandex and SoundCloud tokens isolated', () async {
    final store = _MemorySecureStore();
    final repository = FlutterSecureTokenRepository(store);

    await repository.write(MusicProvider.yandex, 'yandex-token');
    await repository.write(MusicProvider.soundcloud, 'soundcloud-token');

    expect(await repository.read(MusicProvider.yandex), 'yandex-token');
    expect(await repository.read(MusicProvider.soundcloud), 'soundcloud-token');
    expect(
      store.values.keys,
      containsAll(['resonance.token.yandex', 'resonance.token.soundcloud']),
    );
  });

  test('rejects empty tokens', () async {
    final repository = FlutterSecureTokenRepository(_MemorySecureStore());

    expect(
      () => repository.write(MusicProvider.yandex, '   '),
      throwsArgumentError,
    );
  });
}

final class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
