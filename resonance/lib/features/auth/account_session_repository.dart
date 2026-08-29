import 'dart:async';
import 'dart:convert';

import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/features/auth/account_models.dart';

final class AccountSessionRepository {
  AccountSessionRepository(this._store);

  final SecureKeyValueStore _store;
  final StreamController<void> _invalidations = StreamController.broadcast();

  static const _accessKey = 'resonance.account.access';
  static const _refreshKey = 'resonance.account.refresh';
  static const _userKey = 'resonance.account.user';
  static const _accessExpiryKey = 'resonance.account.access_expires';
  static const _refreshExpiryKey = 'resonance.account.refresh_expires';
  static const _boundUserKey = 'resonance.account.bound_library_user';

  Future<AccountSession?> read() async {
    final values = await Future.wait([
      _store.read(_accessKey),
      _store.read(_refreshKey),
      _store.read(_userKey),
      _store.read(_accessExpiryKey),
      _store.read(_refreshExpiryKey),
    ]);
    if (values.any((value) => value == null || value.isEmpty)) return null;
    try {
      return AccountSession(
        accessToken: values[0]!,
        refreshToken: values[1]!,
        user: AccountUser.fromJson(
          jsonDecode(values[2]!) as Map<String, dynamic>,
        ),
        accessExpiresAt: DateTime.parse(values[3]!).toUtc(),
        refreshExpiresAt: DateTime.parse(values[4]!).toUtc(),
      );
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write(AccountSession session) => Future.wait([
    _store.write(_accessKey, session.accessToken),
    _store.write(_refreshKey, session.refreshToken),
    _store.write(_userKey, jsonEncode(session.user.toJson())),
    _store.write(_accessExpiryKey, session.accessExpiresAt.toIso8601String()),
    _store.write(_refreshExpiryKey, session.refreshExpiresAt.toIso8601String()),
  ]);

  Future<void> clear() => Future.wait([
    _store.delete(_accessKey),
    _store.delete(_refreshKey),
    _store.delete(_userKey),
    _store.delete(_accessExpiryKey),
    _store.delete(_refreshExpiryKey),
  ]);

  Stream<void> get invalidations => _invalidations.stream;

  Future<void> invalidate() async {
    await clear();
    _invalidations.add(null);
  }

  Future<void> dispose() => _invalidations.close();

  Future<String?> readBoundUserId() => _store.read(_boundUserKey);

  Future<void> writeBoundUserId(String userId) =>
      _store.write(_boundUserKey, userId);

  Future<void> clearBoundUserId() => _store.delete(_boundUserKey);
}
