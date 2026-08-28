import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';

class AppearanceBackdrop extends StatelessWidget {
  const AppearanceBackdrop({required this.settings, super.key});

  final AppearanceSettings settings;

  @override
  Widget build(BuildContext context) {
    final backgroundPath = settings.backgroundPath;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: backgroundPath == null
          ? const SizedBox.expand()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(backgroundPath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
                if (settings.blur > 0)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: settings.blur,
                      sigmaY: settings.blur,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ColoredBox(color: Colors.black.withValues(alpha: settings.dim)),
              ],
            ),
    );
  }
}
