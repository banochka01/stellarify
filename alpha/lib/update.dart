import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:url_launcher/url_launcher.dart';

const alphaVersion = '0.2.0';
const alphaBuild = 2;

/// What the server says is the newest α (`/downloads/alpha/latest.json`).
final class AlphaRelease {
  const AlphaRelease({
    required this.version,
    required this.build,
    required this.notes,
    required this.download,
  });

  final String version;
  final int build;
  final String notes;
  final Uri download;

  bool get isNewer => build > alphaBuild;

  static AlphaRelease? parse(Object? json, Uri base) {
    if (json is! Map) return null;
    final version = json['version'];
    final build = json['build'];
    final link = json[Platform.isIOS ? 'ios' : 'windows'];
    if (version is! String || build is! int || link is! String) return null;
    final notes = json['notes'];
    return AlphaRelease(
      version: version,
      build: build,
      notes: notes is String ? notes : '',
      download: base.resolve(link),
    );
  }
}

/// Checked on start and every six hours, so testers do not stay on an old
/// build without noticing.
final alphaUpdateProvider = FutureProvider<AlphaRelease?>((ref) async {
  final timer = Timer(const Duration(hours: 6), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final Uri base;
  try {
    base = BackendEndpoint.requireCurrent();
  } on Object {
    return null;
  }
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
    ),
  );
  final response = await dio.getUri<Object?>(
    base.resolve('/downloads/alpha/latest.json'),
  );
  return AlphaRelease.parse(response.data, base);
});

const _dismissedKey = 'alpha.update.dismissed_build';

/// The build the user said "later" to; its banner stays hidden.
final dismissedUpdateProvider =
    StateNotifierProvider<DismissedUpdate, int>((ref) {
      return DismissedUpdate(ref);
    });

final class DismissedUpdate extends StateNotifier<int> {
  DismissedUpdate(this._ref) : super(0) {
    unawaited(_load());
  }

  final Ref _ref;

  Future<void> _load() async {
    final raw = await _ref.read(secureKeyValueStoreProvider).read(_dismissedKey);
    if (mounted) state = int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> dismiss(int build) async {
    state = build;
    await _ref.read(secureKeyValueStoreProvider).write(_dismissedKey, '$build');
  }
}

Future<void> openUpdate(AlphaRelease release) async {
  final opened = await launchUrl(
    release.download,
    mode: LaunchMode.externalApplication,
  );
  if (!opened) throw StateError('Не получилось открыть ссылку');
}
