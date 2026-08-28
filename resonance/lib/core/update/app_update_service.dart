import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

final class AppUpdate {
  const AppUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.notes,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri downloadUrl;
  final String notes;
}

final class AppUpdateService {
  const AppUpdateService(this._dio, this._baseUrl);

  final Dio _dio;
  final Uri Function() _baseUrl;

  Future<AppUpdate?> check() async {
    final package = await PackageInfo.fromPlatform();
    final response = await _dio.getUri<Map<String, dynamic>>(
      _baseUrl().resolve('/api/client-version'),
      options: Options(receiveTimeout: const Duration(seconds: 6)),
    );
    final data = response.data;
    final latest = data?['version'] as String?;
    final downloads = data?['downloads'] as Map<String, dynamic>?;
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'windows';
    final download = Uri.tryParse(downloads?[platform] as String? ?? '');
    if (latest == null ||
        download == null ||
        !(download.isScheme('https') || download.isScheme('http')) ||
        download.host.isEmpty ||
        compareVersions(latest, package.version) <= 0) {
      return null;
    }
    return AppUpdate(
      currentVersion: package.version,
      latestVersion: latest,
      downloadUrl: download,
      notes: data?['notes'] as String? ?? 'Доступна новая версия Resonance.',
    );
  }
}

int compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList(growable: false);
  final a = parts(left);
  final b = parts(right);
  for (
    var index = 0;
    index < (a.length > b.length ? a.length : b.length);
    index++
  ) {
    final difference =
        (index < a.length ? a[index] : 0) - (index < b.length ? b[index] : 0);
    if (difference != 0) return difference.sign;
  }
  return 0;
}
