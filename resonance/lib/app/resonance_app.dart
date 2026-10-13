import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/core/desktop/quick_actions.dart';
import 'package:resonance/core/desktop/windows_shell.dart';
import 'package:resonance/core/playback/android_home_widget.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/features/onboarding/onboarding_feature.dart';
import 'package:resonance/features/recap/listening_recorder.dart';
import 'package:resonance/features/social/now_playing_reporter.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/appearance_backdrop.dart';
import 'package:resonance/shared/widgets/compact_player.dart';
import 'package:url_launcher/url_launcher.dart';

class ResonanceApp extends ConsumerStatefulWidget {
  const ResonanceApp({super.key});

  /// Число построений корня приложения: тест держит его на минимуме, чтобы
  /// фоновые сервисы не перестраивали весь MaterialApp при старте.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  ConsumerState<ResonanceApp> createState() => _ResonanceAppState();
}

class _ResonanceAppState extends ConsumerState<ResonanceApp> {
  bool _updateShown = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final update = await ref.read(appUpdateServiceProvider).check();
      if (!mounted || update == null || _updateShown) return;
      _updateShown = true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.system_update_alt_rounded),
          title: Text('Доступно обновление ${update.latestVersion}'),
          content: Text(
            'Установлена версия ${update.currentVersion}.\n\n${update.notes}',
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Позже'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(launchUrl(update.downloadUrl));
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Обновить'),
            ),
          ],
        ),
      );
    } on Object {
      // Update checks never block startup or offline use.
    }
  }

  static void _ignore(Object? _, Object? _) {}

  @override
  Widget build(BuildContext context) {
    assert(() {
      ResonanceApp.debugBuildCount++;
      return true;
    }());
    final appearance = ref.watch(appearanceControllerProvider);
    // Фоновые сервисы только держим живыми: listen не перестраивает
    // MaterialApp при каждом их loading → data и смене сессии.
    ref
      ..listen<Object?>(accountControllerProvider, _ignore)
      ..listen<Object?>(obsOverlayControllerProvider, _ignore)
      ..listen<Object?>(listeningRecorderProvider, _ignore)
      ..listen<Object?>(offlineCoordinatorProvider, _ignore)
      ..listen<Object?>(nowPlayingReporterProvider, _ignore)
      ..listen<Object?>(windowsShellProvider, _ignore)
      ..listen<Object?>(androidHomeWidgetProvider, _ignore);
    final compact = ref.watch(compactModeProvider);
    return MaterialApp.router(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: ResonanceTheme.forPreset(appearance.theme),
      routerConfig: resonanceRouter,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          AppearanceBackdrop(settings: appearance),
          Offstage(
            offstage: compact,
            child: OnboardingGate(child: child ?? const SizedBox.shrink()),
          ),
          if (compact) const CompactPlayer(),
        ],
      ),
    );
  }
}
