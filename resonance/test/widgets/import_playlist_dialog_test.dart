import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/library/library_screen.dart';

void main() {
  testWidgets('ImportPlaylistDialog returns trimmed url and closes cleanly', (tester) async {
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

    await tester.enterText(find.byType(TextField), '  https://music.yandex.ru/playlist  ');
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

  testWidgets('ImportPlaylistDialog submit on Enter closes cleanly', (tester) async {
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
}
