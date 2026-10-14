import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/recap/recap_screen.dart';

void main() {
  testWidgets('year tab teaser promises December', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: WrappedTeaser())),
      ),
    );
    expect(find.text('Итоги ${DateTime.now().year}'), findsOneWidget);
    expect(find.text('Ждём вас в декабре :)'), findsOneWidget);
  });
}
