import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/subscription/subscription_screen.dart';
import 'package:resonance/features/subscription/subscription_service.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('subscription layout and invalid code at ${size.width}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountControllerProvider.overrideWith(_SignedIn.new),
            subscriptionStatusProvider.overrideWith(
              (ref) async => SubscriptionSnapshot(
                tier: 'guest',
                expiresAt: DateTime.now().add(const Duration(hours: 12)),
                rights: const {'playback.soundcloud': true},
                deviceLimit: 1,
              ),
            ),
          ],
          child: MaterialApp(
            theme: ResonanceTheme.forPreset(ResonanceThemePreset.graphite),
            home: const Scaffold(body: SubscriptionScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Гость · 24 часа'), findsOneWidget);
      expect(find.text('Base'), findsOneWidget);
      expect(find.text('Plus'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final promo = find.byKey(const ValueKey('subscription-promo'));
      await tester.ensureVisible(promo);
      await tester.enterText(promo, 'bad');
      final activate = find.byKey(const ValueKey('subscription-redeem'));
      await tester.ensureVisible(activate);
      await tester.tap(activate);
      await tester.pumpAndSettle();
      expect(find.text('Введите полный промокод.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('expiration overrides cached true capability', () {
    final snapshot = SubscriptionSnapshot(
      tier: 'plus',
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      rights: const {'playback.soundcloud': true},
      deviceLimit: 10,
    );
    expect(snapshot.allows('playback.soundcloud'), false);
  });
}

class _SignedIn extends AccountController {
  @override
  Future<AccountUser?> build() async => AccountUser(
    id: 'test-user',
    email: 'listener@example.com',
    createdAt: DateTime.utc(2026),
  );
}
