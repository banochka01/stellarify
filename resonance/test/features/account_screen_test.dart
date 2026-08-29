import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/auth/account_screen.dart';

void main() {
  testWidgets('account form adapts to mobile and validates registration', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountControllerProvider.overrideWith(_FakeAccountController.new),
        ],
        child: const MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
    await tester.tap(find.text('Создать новый аккаунт'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-password-confirmation')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('account-email')),
      'listener@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'short',
    );
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pump();
    expect(find.textContaining('не меньше 10'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeAccountController extends AccountController {
  @override
  Future<AccountUser?> build() async => null;
}
