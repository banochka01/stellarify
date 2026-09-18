import 'dart:convert';
import 'dart:math';

import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/features/auth/account_api.dart';

/// Stable installation identity plus an optional Resonance account session.
/// It identifies anonymous Wave sessions and room clients; it grants no paid tier.
final class ClientIdentityService {
  ClientIdentityService(this._secure, this._accounts);

  final SecureKeyValueStore _secure;
  final AccountApi _accounts;
  Future<String>? _installation;

  Future<String> deviceId() => _installation ??= _loadInstallation();

  Future<String> _loadInstallation() async {
    const key = 'resonance.access.installation';
    final stored = await _secure.read(key);
    if (stored != null) return stored;
    final random = Random.secure();
    final token = base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    await _secure.write(key, token);
    return token;
  }

  Future<Map<String, String>> headers() async {
    final device = await deviceId();
    final token = await _accounts.accessToken();
    return {
      'X-Device-Id': device,
      'X-Guest-Token': device,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
