// Стресс-тесты экранов 4.0: маленький телефон, альбомная ориентация,
// крупный шрифт, длинные русские строки, ошибки и пустые состояния.
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/core/playback/offline_downloads.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/migration/migration_api.dart';
import 'package:resonance/features/migration/migration_screen.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/features/settings/storage_screen.dart';
import 'package:resonance/features/wave/daily_mixes.dart';
import 'package:resonance/features/wave/new_releases.dart';
import 'package:resonance/features/wave/wave_home_sections.dart';
import 'package:resonance/providers/common/provider_registry.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

const _long =
    'Очень длинное название трека с подробностями (расширенная версия '
    'для танцпола, ремастеринг двадцать четвёртого года)';
const _longArtist =
    'Оркестр филармонии имени Константина Константиновского и друзья';

const _sizes = <String, Size>{
  'phone 360x640': Size(360, 640),
  'landscape 640x360': Size(640, 360),
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  List<Override> overrides = const [],
  double textScale = 1.3,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ResonanceTheme.forPreset(ResonanceThemePreset.graphite),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

UnifiedTrack _track(String id, {String title = _long}) => UnifiedTrack(
  id: 'soundcloud:$id',
  title: title,
  normalizedTitle: title.toLowerCase(),
  artist: _longArtist,
  normalizedArtist: _longArtist.toLowerCase(),
);

// ---------------------------------------------------------------- Переезд --

Map<String, dynamic> _job({String status = 'completed'}) => {
  'id': 'job-1',
  'source': 'spotify',
  'target': 'yandex',
  'kind': 'full',
  'status': status,
  'total': status == 'completed' ? 1200 : 0,
  'processed': status == 'completed' ? 1200 : 0,
  'progress': status == 'completed' ? 100 : 0,
  'truncated': true,
  'warning': 'Часть плейлистов недоступна: $_long',
  if (status == 'failed') 'error': 'Токен источника истёк. $_long',
  'lastSyncedAt': '2026-10-10T10:00:00.000Z',
};

Map<String, dynamic> _src(String id) => {
  'id': id,
  'title': _long,
  'artist': _longArtist,
  'durationMs': 301000,
  'externalUrl': 'https://example.com/$id',
};

Map<String, dynamic> _report() => {
  'job': _job(),
  'summary': {
    'total': 1200,
    'migrated': 1100,
    'percent': 91.7,
    'exact': 1000,
    'high': 100,
    'low': 60,
    'none': 40,
    'manual': 3,
    'pending': 0,
  },
  'lowConfidence': [
    {
      'itemId': 3,
      'section': 'playlist',
      'collectionTitle': _long,
      'status': 'matched',
      'confidence': 'low',
      'score': 0.8,
      'source': _src('s3'),
      'match': {..._src('m3'), 'provider': 'yandex'},
    },
  ],
  'unmatched': [
    {
      'itemId': 4,
      'section': 'favorite',
      'status': 'unmatched',
      'confidence': 'none',
      'score': 0.1,
      'source': _src('s4'),
      'match': null,
    },
  ],
  'collections': <Object>[],
  'artists': [
    for (var i = 0; i < 8; i++)
      {'externalId': 'a$i', 'name': '$_longArtist $i'},
  ],
};

final class _SignedIn extends AccountController {
  @override
  Future<AccountUser?> build() async => AccountUser(
    id: 'user-1',
    email: 'listener@example.com',
    createdAt: DateTime.utc(2026),
  );
}

class _NoTokens implements SecureTokenRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<String?>.value();
}

class _Api extends MigrationApi {
  _Api({this.status = 'completed', this.reportFails = false})
    : super(
        Dio(),
        () => Uri.parse('https://example.com'),
        () async => 'token',
        _NoTokens(),
      );

  final String status;
  bool reportFails;
  bool candidatesFail = false;

  @override
  Future<List<MigrationJob>> jobs() async => [
    MigrationJob.fromJson(_job(status: status)),
  ];

  @override
  Future<MigrationReport> report(String id) async {
    if (reportFails) {
      throw const MigrationException('Сервер не отдал отчёт');
    }
    return MigrationReport.fromJson(_report());
  }

  @override
  Future<List<MigrationCandidate>> candidates(
    MigrationJob job,
    int itemId, {
    String? query,
  }) async {
    if (candidatesFail) throw const MigrationException('Поиск недоступен');
    return const [];
  }
}

List<Override> _migrationOverrides(MigrationApi api) => [
  accountControllerProvider.overrideWith(_SignedIn.new),
  migrationApiProvider.overrideWithValue(api),
  migrationLibraryRefreshProvider.overrideWithValue(() async {}),
];

// --------------------------------------------------------------- Хранилище --

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

OfflineDownloads _downloads(Future<Directory> Function() directory) =>
    OfflineDownloads(
      providers: ProviderRegistry(),
      authorizeSource: (_) async {},
      directory: directory,
    );

const _usage = (
  offline: OfflineUsage(
    downloadsBytes: 1536 * 1024 * 1024,
    downloadsCount: 21,
    autoCacheBytes: 300 * 1024 * 1024,
    autoCacheCount: 1,
    lyricsBytes: 4000,
    lyricsCount: 3,
  ),
  covers: 12 * 1024 * 1024,
);

List<Override> _storageOverrides(
  OfflineDownloads downloads, {
  bool usageFails = false,
}) => [
  offlineDownloadsProvider.overrideWith((ref) => downloads),
  storageUsageProvider.overrideWith(
    (ref) async => usageFails ? throw StateError('disk') : _usage,
  ),
  secureKeyValueStoreProvider.overrideWithValue(_MemoryStore()),
  networkKindProvider.overrideWith((ref) => Stream.value(NetworkKind.mobile)),
];
void main() {
  for (final entry in _sizes.entries) {
    group(entry.key, () {
      testWidgets('Переезд: отчёт с длинными строками без переполнений', (
        tester,
      ) async {
        await _pump(
          tester,
          const MigrationScreen(),
          size: entry.value,
          overrides: _migrationOverrides(_Api()),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Медиатека переехала'), findsOneWidget);
        await _reveal(tester, find.text('Найти вручную'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Найти вручную'));
        await tester.pumpAndSettle();
        expect(
          find.text('Ничего не нашлось — попробуйте другой запрос.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Переезд: экран выбора сервисов', (tester) async {
        final api = _Api();
        await _pump(
          tester,
          const MigrationScreen(),
          size: entry.value,
          overrides: _migrationOverrides(api),
        );
        await tester.pumpAndSettle();
        await _reveal(tester, find.text('Новый переезд'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Новый переезд'));
        await tester.pumpAndSettle();
        expect(find.text('Вся музыка — в один переезд'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Главная: «Ваш день» и новые релизы с крупным шрифтом', (
        tester,
      ) async {
        await _pump(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  WaveDaySection(gutter: 18, compact: true),
                  NewReleasesSection(gutter: 18, compact: true),
                ],
              ),
            ),
          ),
          size: entry.value,
          overrides: [
            secureKeyValueStoreProvider.overrideWithValue(_MemoryStore()),
            dailyMixesProvider.overrideWith(
              (ref) async => DailyMixes(
                mixes: [
                  DailyMix(
                    id: 'm',
                    kind: 'morning',
                    title: 'Утро',
                    subtitle: '$_longArtist, $_longArtist',
                    tracks: [_track('1')],
                  ),
                ],
              ),
            ),
            newReleasesProvider.overrideWith(
              (ref) async => [
                NewRelease(
                  id: 'r',
                  title: _long,
                  artist: _longArtist,
                  releaseDate: DateTime.now(),
                  kind: 'single',
                  externalUrl: Uri.parse('https://example.com'),
                ),
              ],
            ),
            freshWeekProvider.overrideWith(
              (ref) async =>
                  FreshWeek(weekOf: null, tracks: [_track('1'), _track('2')]),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('Ваш день'), findsOneWidget);
        expect(find.text('2 трека · по пятницам'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Хранилище: данные, очистка и склонения', (tester) async {
        await _pump(
          tester,
          const Scaffold(body: StorageScreen()),
          size: entry.value,
          overrides: _storageOverrides(
            _downloads(() async => throw const FileSystemException('busy')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('21 трек ·'), findsOneWidget);
        expect(find.textContaining('1 трек ·'), findsWidgets);
        await tester.tap(find.text('Очистить').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Очистить'));
        await tester.pumpAndSettle();
        expect(
          find.text('Не удалось очистить. Попробуйте ещё раз.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Переезд: отчёт не загрузился — есть выход и повтор', (
    tester,
  ) async {
    final api = _Api(reportFails: true);
    await _pump(
      tester,
      const MigrationScreen(),
      size: const Size(360, 640),
      overrides: _migrationOverrides(api),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сервер не отдал отчёт'), findsOneWidget);
    expect(find.text('Перенос завершён'), findsOneWidget);
    expect(find.text('Показать отчёт'), findsOneWidget);
    expect(find.text('Новый переезд'), findsOneWidget);

    api.reportFails = false;
    await tester.tap(find.text('Показать отчёт'));
    await tester.pumpAndSettle();
    expect(find.text('Медиатека переехала'), findsOneWidget);
    expect(find.text('Сервер не отдал отчёт'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Переезд: ошибка ручного поиска не выдаётся за пустой ответ', (
    tester,
  ) async {
    final api = _Api()..candidatesFail = true;
    await _pump(
      tester,
      const MigrationScreen(),
      size: const Size(360, 900),
      overrides: _migrationOverrides(api),
      textScale: 1,
    );
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Найти вручную'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Найти вручную'));
    await tester.pumpAndSettle();
    expect(find.text('Поиск недоступен'), findsOneWidget);
    expect(
      find.text('Ничего не нашлось — попробуйте другой запрос.'),
      findsNothing,
    );
  });

  testWidgets('Переезд: остановившийся перенос можно продолжить', (
    tester,
  ) async {
    await _pump(
      tester,
      const MigrationScreen(),
      size: const Size(360, 640),
      overrides: _migrationOverrides(_Api(status: 'failed')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Перенос остановился'), findsOneWidget);
    await _reveal(tester, find.text('Продолжить'));
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Хранилище: ошибка подсчёта места не висит вечной загрузкой', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: StorageScreen()),
      size: const Size(360, 640),
      overrides: _storageOverrides(
        _downloads(() => Completer<Directory>().future),
        usageFails: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Считаем занятое место…'), findsNothing);
    expect(find.text('Не удалось посчитать занятое место'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Хранилище: закрытие экрана во время очистки не падает', (
    tester,
  ) async {
    final directory = Completer<Directory>();
    await _pump(
      tester,
      const Scaffold(body: StorageScreen()),
      size: const Size(360, 640),
      overrides: _storageOverrides(_downloads(() => directory.future)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Очистить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Очистить'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    directory.completeError(const FileSystemException('gone'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
