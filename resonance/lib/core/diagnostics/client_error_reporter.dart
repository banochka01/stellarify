import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';

enum ClientReportKind { crash, playback, network }

/// Sends crash and playback errors to our own server (`/api/v1/client-reports`).
///
/// No third-party SDK: reports are small JSON documents without tokens,
/// stream URLs or personal data. Sending is throttled on the client as well,
/// the server rate-limits independently.
final class ClientErrorReporter {
  ClientErrorReporter({
    Dio? dio,
    Uri? Function()? endpoint,
    DateTime Function()? now,
    this.maxPerSession = 20,
    this.duplicateWindow = const Duration(minutes: 5),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
             ),
           ),
       _endpoint = endpoint ?? _defaultEndpoint,
       _now = now ?? DateTime.now;

  static final instance = ClientErrorReporter();

  final Dio _dio;
  final Uri? Function() _endpoint;
  final DateTime Function() _now;
  final int maxPerSession;
  final Duration duplicateWindow;
  final _recent = <String, DateTime>{};
  int _sent = 0;
  String? _version;

  static Uri? _defaultEndpoint() {
    try {
      return BackendEndpoint.requireCurrent().resolve('/api/v1/client-reports');
    } on Object {
      return null;
    }
  }

  /// Installs global Flutter and platform error hooks. Existing handlers keep working.
  void installGlobalHandlers() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutter?.call(details);
      unawaited(
        report(
          ClientReportKind.crash,
          details.exceptionAsString(),
          stack: details.stack,
        ),
      );
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(ClientReportKind.crash, error.toString(), stack: stack));
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  /// Returns true when the report was sent.
  Future<bool> report(
    ClientReportKind kind,
    String message, {
    StackTrace? stack,
    String? provider,
    Map<String, Object> context = const {},
  }) async {
    final trimmed = sanitize(message, 500);
    if (trimmed.isEmpty || _sent >= maxPerSession) return false;
    final key = '${kind.name}:$trimmed';
    final now = _now();
    final last = _recent[key];
    if (last != null && now.difference(last) < duplicateWindow) return false;
    final endpoint = _endpoint();
    if (endpoint == null) return false;
    _recent[key] = now;
    _sent += 1;
    try {
      _version ??= await PackageInfo.fromPlatform().then(
        (info) => info.version,
        onError: (_) => 'unknown',
      );
      await _dio.postUri<void>(
        endpoint,
        data: {
          'kind': kind.name,
          'message': trimmed,
          if (stack != null) 'stack': sanitize(stack.toString(), 4000),
          'appVersion': _version,
          'platform': _platformName(),
          'provider': ?provider,
          if (context.isNotEmpty)
            'context': {
              for (final entry in context.entries.take(20))
                entry.key: entry.value is num || entry.value is bool
                    ? entry.value
                    : sanitize('${entry.value}', 200),
            },
        },
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Strips URLs (they may carry stream tokens) and caps the length.
  static String sanitize(String value, int max) {
    final cleaned = value.replaceAll(RegExp(r'https?://\S+'), '<url>').trim();
    return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }
}
