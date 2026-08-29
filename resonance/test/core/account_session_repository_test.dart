import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/auth/account_session_repository.dart';

void main() {
  test('stores account tokens and user only in the secure store', () async {
    final store = _MemorySecureStore();
    final repository = AccountSessionRepository(store);
    final session = AccountSession(
      user: AccountUser(
        id: 'user-1',
        email: 'listener@example.com',
        createdAt: DateTime.utc(2026, 8, 29),
      ),
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessExpiresAt: DateTime.utc(2026, 8, 29, 1),
      refreshExpiresAt: DateTime.utc(2026, 9, 29),
    );

    await repository.write(session);
    await repository.writeBoundUserId('user-1');
    final restored = await repository.read();

    expect(restored?.user.email, 'listener@example.com');
    expect(restored?.accessToken, 'access-token');
    expect(await repository.readBoundUserId(), 'user-1');

    await repository.clear();
    expect(await repository.read(), isNull);
    expect(await repository.readBoundUserId(), 'user-1');
    await repository.clearBoundUserId();
    expect(await repository.readBoundUserId(), isNull);
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
