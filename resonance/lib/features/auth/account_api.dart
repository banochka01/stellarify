import 'dart:io';

import 'package:dio/dio.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/auth/account_session_repository.dart';

final class AccountApi {
  AccountApi(this._dio, this._endpoint, this._sessions);

  final Dio _dio;
  final Uri Function() _endpoint;
  final AccountSessionRepository _sessions;
  Future<AccountSession>? _refreshing;

  Future<AccountSession> register(String email, String password) =>
      _credentials('/api/v1/account/register', email, password);

  Future<AccountSession> login(String email, String password) =>
      _credentials('/api/v1/account/login', email, password);

  Future<AccountUser> me() async {
    final response = await _authorized('GET', '/api/v1/account/me');
    return AccountUser.fromJson(
      (response.data as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<RemoteLibrarySnapshot> library() async {
    final response = await _authorized('GET', '/api/v1/account/library');
    return _libraryFromResponse(response);
  }

  Future<RemoteLibrarySnapshot> applyOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    final response = await _authorized(
      'POST',
      '/api/v1/account/library/operations',
      data: {'operations': operations},
    );
    return _libraryFromResponse(response);
  }

  Future<void> logout() async {
    final session = await _sessions.read();
    if (session == null) return;
    try {
      await _dio.postUri(
        _endpoint().resolve('/api/v1/account/logout'),
        data: {'refreshToken': session.refreshToken},
      );
    } on DioException {
      // Local logout must succeed even while offline.
    }
  }

  Future<AccountSession> _credentials(
    String path,
    String email,
    String password,
  ) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _endpoint().resolve(path),
        data: {
          'email': email.trim(),
          'password': password,
          'deviceName': _deviceName,
        },
      );
      return AccountSession.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Response<dynamic>> _authorized(
    String method,
    String path, {
    Object? data,
  }) async {
    var session = await _sessions.read();
    if (session == null) {
      throw const AccountApiException(
        'Войдите в аккаунт',
        code: 'AUTH_REQUIRED',
      );
    }
    if (session.accessExpiresAt.isBefore(
      DateTime.now().toUtc().add(const Duration(seconds: 30)),
    )) {
      session = await _refresh(session);
    }
    try {
      return await _dio.requestUri<dynamic>(
        _endpoint().resolve(path),
        data: data,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        session = await _refresh(session);
        try {
          return await _dio.requestUri<dynamic>(
            _endpoint().resolve(path),
            data: data,
            options: Options(
              method: method,
              headers: {'Authorization': 'Bearer ${session.accessToken}'},
            ),
          );
        } on DioException catch (retryError) {
          throw _mapError(retryError);
        }
      }
      throw _mapError(error);
    }
  }

  Future<AccountSession> _refresh(AccountSession session) {
    return _refreshing ??= _performRefresh(session).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<AccountSession> _performRefresh(AccountSession session) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _endpoint().resolve('/api/v1/account/refresh'),
        data: {'refreshToken': session.refreshToken, 'deviceName': _deviceName},
      );
      final refreshed = AccountSession.fromJson(response.data!);
      await _sessions.write(refreshed);
      return refreshed;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) await _sessions.clear();
      throw _mapError(error);
    }
  }

  RemoteLibrarySnapshot _libraryFromResponse(Response<dynamic> response) {
    final data = response.data as Map<String, dynamic>;
    return RemoteLibrarySnapshot.fromJson(
      data['library'] as Map<String, dynamic>,
    );
  }

  String get _deviceName => 'Resonance ${Platform.operatingSystem}';

  AccountApiException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final body = data['error'];
      if (body is Map<String, dynamic>) {
        return AccountApiException(
          body['message'] as String? ?? 'Ошибка аккаунта',
          code: body['code'] as String?,
        );
      }
    }
    return const AccountApiException(
      'Сервер недоступен. Локальная медиатека продолжит работать',
      code: 'NETWORK_ERROR',
    );
  }
}
