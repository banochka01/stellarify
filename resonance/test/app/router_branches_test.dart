import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/router.dart';

void main() {
  test('each tab branch opens its own root screen first', () {
    final shell = resonanceRouter.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    final firstPaths = [
      for (final branch in shell.branches)
        (branch.routes.first as GoRoute).path,
    ];
    // Регрессия 5.0.1: /changelog стоял первым в ветке настроек, и вкладка
    // «Настройки» открывала «Что нового».
    expect(firstPaths.last, '/settings');
    expect(firstPaths, isNot(contains('/changelog')));
    expect(firstPaths, isNot(contains('/social')));
    expect(firstPaths, isNot(contains('/collab')));
  });
}
