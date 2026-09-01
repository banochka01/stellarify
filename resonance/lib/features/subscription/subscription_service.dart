import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/auth/account_api.dart';
import 'package:resonance/features/auth/account_session_repository.dart';

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.tier,
    required this.expiresAt,
    required this.rights,
    required this.deviceLimit,
    this.familyOwnerId,
    this.scheduled = const [],
  });
  factory SubscriptionSnapshot.fromJson(Map<String, dynamic> json) =>
      SubscriptionSnapshot(
        tier: json['tier'] as String,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        rights: Map<String, bool>.from(json['capabilities'] as Map),
        deviceLimit: json['deviceLimit'] as int,
        familyOwnerId: json['familyOwnerId'] as String?,
        scheduled: (json['scheduled'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
  final String tier;
  final DateTime? expiresAt;
  final Map<String, bool> rights;
  final int deviceLimit;
  final String? familyOwnerId;
  final List<Map<String, dynamic>> scheduled;
  bool allows(String right) =>
      rights[right] == true &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now().toUtc());
  String get label => switch (tier) {
    'base' => 'Resonance Base',
    'plus' => 'Resonance Plus',
    'family' => 'Resonance Family',
    'guest' => 'Гость · 24 часа',
    _ => 'Нет активной подписки',
  };
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class SubscriptionService {
  SubscriptionService(
    this._dio,
    this._endpoint,
    this._secure,
    this._accounts,
    this._sessions,
  );
  final Dio _dio;
  final Uri Function() _endpoint;
  final SecureKeyValueStore _secure;
  final AccountApi _accounts;
  final AccountSessionRepository _sessions;
  Future<String>? _installation;
  Future<void>? _startingGuest;
  SubscriptionSnapshot? _cached;
  String? _cachedIdentity;
  DateTime? _cachedAt;

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
    // Starting once is durable across retries and account registration; server owns the clock.
    final startedKey = 'resonance.access.started.${_endpoint().origin}';
    if (await _secure.read(startedKey) != 'yes') {
      _startingGuest ??= _startGuest(device, startedKey);
      try {
        await _startingGuest;
      } finally {
        _startingGuest = null;
      }
    }
    return {
      'X-Device-Id': device,
      'X-Guest-Token': device,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _startGuest(String token, String key) async {
    await _dio.postUri<dynamic>(
      _endpoint().resolve('/api/v1/subscription/guest'),
      data: {'token': token},
      options: Options(followRedirects: false),
    );
    await _secure.write(key, 'yes');
  }

  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  Future<SubscriptionSnapshot> status({bool force = false}) async {
    final identity =
        '${_endpoint().origin}:${(await _sessions.read())?.user.id ?? 'guest'}';
    if (!force &&
        _cached != null &&
        _cachedIdentity == identity &&
        DateTime.now().difference(_cachedAt!) < const Duration(seconds: 20)) {
      return _cached!;
    }
    final data = await request('GET', '/status');
    if (identity !=
        '${_endpoint().origin}:${(await _sessions.read())?.user.id ?? 'guest'}') {
      throw const SubscriptionException(
        'Аккаунт изменился. Повторите действие.',
      );
    }
    final result = SubscriptionSnapshot.fromJson(
      Map<String, dynamic>.from(data['subscription'] as Map),
    );
    _cached = result;
    _cachedIdentity = identity;
    _cachedAt = DateTime.now();
    return result;
  }

  Future<void> requireProvider(MusicProvider provider) async {
    final subscription = await status();
    if (!subscription.allows('playback.${provider.name}')) {
      throw const SubscriptionException(
        'Источник недоступен. Откройте раздел «Подписка».',
      );
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Object? data,
  }) async {
    try {
      final expectedUserId = (await _sessions.read())?.user.id;
      final requestHeaders = await headers();
      if ((await _sessions.read())?.user.id != expectedUserId) {
        throw const SubscriptionException(
          'Аккаунт изменился. Повторите действие.',
        );
      }
      final response = await _dio.requestUri<dynamic>(
        _endpoint().resolve('/api/v1/subscription$path'),
        data: data,
        options: Options(
          method: method,
          headers: requestHeaders,
          followRedirects: false,
        ),
      );
      if ((await _sessions.read())?.user.id != expectedUserId) {
        throw const SubscriptionException(
          'Аккаунт изменился. Повторите действие.',
        );
      }
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {};
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map && body['error'] is Map
          ? (body['error'] as Map)['message']
          : null;
      throw SubscriptionException(
        message is String
            ? message
            : 'Не удалось проверить подписку. Проверьте подключение.',
      );
    }
  }

  Future<void> redeem(String code) async {
    await request('POST', '/redeem', data: {'code': code.trim()});
    invalidate();
  }
}
