import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

void main() {
  testWidgets('entrance motion is disabled for motion-sensitive users', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ResonanceEntrance(child: Text('Wave')),
        ),
      ),
    );

    expect(find.text('Wave'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResonanceEntrance),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('entrance motion uses the shared fade and slide transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ResonanceEntrance(child: Text('Wave'))),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ResonanceEntrance),
        matching: find.byType(FadeTransition),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ResonanceEntrance),
        matching: find.byType(SlideTransition),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}
