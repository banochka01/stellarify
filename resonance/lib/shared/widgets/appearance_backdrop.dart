import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';

class AppearanceBackdrop extends StatelessWidget {
  const AppearanceBackdrop({required this.settings, super.key});

  final AppearanceSettings settings;

  /// Ширина декодирования фона: длинная сторона экрана в физических
  /// пикселях, округлённая вверх до 512, чтобы поворот и ресайз окна не
  /// декодировали фон заново на каждый пиксель.
  static int decodeWidthFor(Size logical, double pixelRatio) {
    final longest = logical.longestSide * pixelRatio;
    final rounded = ((longest / 512).ceil() * 512).clamp(512, 4096);
    return rounded.toInt();
  }

  static int _decodeWidth(BuildContext context) => decodeWidthFor(
    MediaQuery.sizeOf(context),
    MediaQuery.devicePixelRatioOf(context),
  );

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
                  // Фото пользователя бывает 4000+ px: декодируем по ширине
                  // окна, иначе фон держит в памяти десятки мегабайт.
                  cacheWidth: _decodeWidth(context),
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
