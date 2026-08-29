import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/library/library_controller.dart';

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, AccountUser?>(
      AccountController.new,
    );

class AccountController extends AsyncNotifier<AccountUser?> {
  @override
  Future<AccountUser?> build() async {
    final sessions = ref.read(accountSessionRepositoryProvider);
    final subscription = sessions.invalidations.listen((_) {
      unawaited(_completeLocalSignOut());
    });
    ref.onDispose(subscription.cancel);
    final session = await sessions.read();
    if (session == null) return null;
    try {
      final user = await ref.read(accountApiProvider).me();
      try {
        await ref.read(librarySyncServiceProvider).connect(user.id);
      } on AccountApiException {
        // A valid session remains usable while synchronization is offline.
      }
      ref.invalidate(libraryControllerProvider);
      return user;
    } on AccountApiException catch (error) {
      if (error.code == 'INVALID_SESSION' || error.code == 'AUTH_REQUIRED') {
        await ref.read(accountSessionRepositoryProvider).invalidate();
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) =>
      _authenticate(() => ref.read(accountApiProvider).login(email, password));

  Future<void> register(String email, String password) => _authenticate(
    () => ref.read(accountApiProvider).register(email, password),
  );

  Future<void> _authenticate(Future<AccountSession> Function() request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await request();
      await ref.read(accountSessionRepositoryProvider).write(session);
      try {
        await ref.read(librarySyncServiceProvider).connect(session.user.id);
      } on AccountApiException {
        // Keep the successful login; queued changes retry when connectivity returns.
      }
      ref.invalidate(libraryControllerProvider);
      return session.user;
    });
  }

  Future<void> synchronize() async {
    final user = state.valueOrNull;
    if (user == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(librarySyncServiceProvider).sync();
      ref.invalidate(libraryControllerProvider);
      return user;
    });
  }

  Future<void> logout() async {
    final user = state.valueOrNull;
    state = const AsyncLoading();
    await ref.read(accountApiProvider).logout();
    await ref.read(accountSessionRepositoryProvider).clear();
    await _completeLocalSignOut();
    if (user != null) ref.invalidate(libraryControllerProvider);
  }

  Future<void> _completeLocalSignOut() async {
    await ref.read(accountSessionRepositoryProvider).clearBoundUserId();
    await ref
        .read(appDatabaseProvider)
        .replaceLocalLibrary(
          const LocalLibrarySnapshot(favorites: [], playlists: []),
        );
    state = const AsyncData(null);
    ref.invalidate(libraryControllerProvider);
  }
}
