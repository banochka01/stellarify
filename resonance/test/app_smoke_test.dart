import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/core/database/app_database.dart';

import 'helpers/fake_playback_engine.dart';

void main() {
  testWidgets('renders adaptive Resonance shell', (tester) async {
    final engine = FakePlaybackEngine();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          playbackEngineProvider.overrideWithValue(engine),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Midnight Signal'), findsWidgets);
    expect(find.text('Главная'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
  });

  testWidgets('mobile navigation labels open the matching routes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    resonanceRouter.go('/search');
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

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();

    expect(find.text('Midnight Signal'), findsWidgets);
    expect(find.text('Какую музыку включить?'), findsOneWidget);
    resonanceRouter.go('/');
  });
}
