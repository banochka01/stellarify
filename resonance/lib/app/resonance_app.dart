import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/onboarding/onboarding_feature.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/appearance_backdrop.dart';
import 'package:url_launcher/url_launcher.dart';

class ResonanceApp extends ConsumerStatefulWidget {
  const ResonanceApp({super.key});

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

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceControllerProvider);
    ref.watch(accountControllerProvider);
    ref.watch(obsOverlayControllerProvider);
    return MaterialApp.router(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: ResonanceTheme.forPreset(appearance.theme),
      routerConfig: resonanceRouter,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          AppearanceBackdrop(settings: appearance),
          OnboardingGate(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
