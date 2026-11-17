import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/recap/listening_recap.dart';
import 'package:resonance_alpha/screens/artist_screen.dart';
import 'package:resonance_alpha/screens/recap_screen.dart';
import 'package:resonance_alpha/shell/hotkeys.dart';
import 'package:resonance_alpha/state.dart';

UnifiedTrack _track({List<TrackSource> sources = const []}) => UnifiedTrack(
  id: 't',
  title: 'Песня',
  normalizedTitle: 'песня',
  artist: 'Артист',
  normalizedArtist: 'артист',
  sources: sources,
);

ListeningRecap _recap({int plays = 0, int minutes = 0}) => ListeningRecap(
  period: RecapPeriod.week,
  plays: plays,
  listened: Duration(minutes: minutes),
  uniqueTracks: plays,
  uniqueArtists: plays == 0 ? 0 : 1,
  topTracks: const [],
  topArtists: const [],
  activeDays: plays == 0 ? 0 : 2,
  longestStreak: plays == 0 ? 0 : 2,
  topProvider: null,
  peakHour: plays == 0 ? null : 21,
  daily: List.filled(7, plays == 0 ? 0 : 10),
);

Widget _recapApp(ListeningRecap recap) => ProviderScope(
  overrides: [
    listeningRecapProvider.overrideWith((ref, period) async => recap),
  ],
  child: const MaterialApp(home: RecapScreen()),
);

void main() {
  test('share text names the track and carries a link when known', () {
    expect(shareText(_track()), 'Артист — Песня');
    final linked = _track(
      sources: [
        TrackSource(
          provider: MusicProvider.soundcloud,
          externalId: '1',
          externalUrl: Uri.parse('https://soundcloud.com/a/b'),
        ),
      ],
    );
    expect(shareText(linked), 'Артист — Песня\nhttps://soundcloud.com/a/b');
  });

  test('artist strings split into separate names', () {
    expect(artistNames('Земфира feat. Ренат'), ['Земфира', 'Ренат']);
    expect(artistNames('A, B & C'), ['A', 'B', 'C']);
  });

  testWidgets('plain hotkeys stay quiet while typing', (tester) async {
    var plays = 0;
    final field = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.space): unlessTyping(
                () => plays++,
              ),
            },
            child: Focus(
              autofocus: true,
              child: Column(children: [TextField(focusNode: field)]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(plays, 1);

    field.requestFocus();
    await tester.pump();
    expect(isTyping(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(plays, 1);
    field.dispose();
  });

  testWidgets('recap without history explains where numbers come from', (
    tester,
  ) async {
    await tester.pumpWidget(_recapApp(_recap()));
    await tester.pumpAndSettle();
    expect(find.text('Пока нечего считать'), findsOneWidget);
  });

  testWidgets('recap shows minutes, persona and facts', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_recapApp(_recap(plays: 3, minutes: 125)));
    await tester.pumpAndSettle();
    expect(find.text('125'), findsOneWidget);
    expect(find.text('минут музыки'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('дней подряд'), findsOneWidget);
  });
}
