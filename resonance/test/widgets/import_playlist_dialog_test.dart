import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/library/library_screen.dart';
import 'package:resonance/features/library/playlist_import_progress_dialog.dart';

void main() {
  testWidgets('ImportPlaylistDialog returns trimmed url and closes cleanly', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const ImportPlaylistDialog(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Перенести плейлист'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '  https://music.yandex.ru/playlist  ',
    );
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();

    expect(result, 'https://music.yandex.ru/playlist');
    expect(find.text('Перенести плейлист'), findsNothing);

    // Extra frames after the dialog route finished must not throw
    // (regression: controller was disposed while the exit animation ran).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ImportPlaylistDialog submit on Enter closes cleanly', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const ImportPlaylistDialog(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://vk.com/audio123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, 'https://vk.com/audio123');
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress dialog closes itself only after import completes', (
    tester,
  ) async {
    final completer = Completer<PlaylistImportOutcome>();
    PlaylistImportOutcome? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<PlaylistImportOutcome>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      PlaylistImportProgressDialog(run: () => completer.future),
                );
              },
              child: const Text('import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('import'));
    await tester.pump();
    expect(find.text('Переносим плейлист'), findsOneWidget);

    completer.complete(
      const PlaylistImportOutcome(name: 'Mix', trackCount: 12),
    );
    await tester.pumpAndSettle();

    expect(result?.name, 'Mix');
    expect(find.text('Переносим плейлист'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress dialog exposes retry after a failed import', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<PlaylistImportOutcome>(
                context: context,
                builder: (_) => PlaylistImportProgressDialog(
                  run: () async {
                    attempts++;
                    throw StateError('network failed');
                  },
                ),
              ),
              child: const Text('import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    expect(find.text('Импорт не завершён'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(attempts, 1);
  });
}
