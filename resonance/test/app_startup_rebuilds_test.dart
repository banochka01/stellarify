import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/features/recap/listening_recorder.dart';
import 'package:resonance/features/social/now_playing_reporter.dart';

import 'helpers/fake_playback_engine.dart';

void main() {
  testWidgets('background services do not rebuild the app root on startup', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    ResonanceApp.debugBuildCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Пересоздание фоновых сервисов (новая сессия, перезапуск плеера)
    // проходит через loading → data и раньше перестраивало корень.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ResonanceApp)),
    );
    container
      ..invalidate(accountControllerProvider)
      ..invalidate(listeningRecorderProvider)
      ..invalidate(offlineCoordinatorProvider)
      ..invalidate(nowPlayingReporterProvider);
    await tester.pumpAndSettle();
    // Вход в аккаунт меняет состояние сессии, но не тему и не роутер.
    container.read(accountControllerProvider.notifier).state = AsyncData(
      AccountUser(
        id: 'user-1',
        email: 'listener@example.invalid',
        createdAt: DateTime.utc(2026),
      ),
    );
    await tester.pumpAndSettle();

    // Сессия аккаунта, рекордер, офлайн-координатор и репортёр «сейчас
    // играет» поднимаются асинхронно и не должны перестраивать MaterialApp.
    expect(
      ResonanceApp.debugBuildCount,
      1,
      reason: 'ResonanceApp built ${ResonanceApp.debugBuildCount} times',
    );
  });
}
