import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowBar extends StatelessWidget {
  const DesktopWindowBar({super.key});

  static bool get supported => Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D0C), Color(0xFF080909)],
        ),
        border: Border(bottom: BorderSide(color: ResonanceColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: const DragToMoveArea(
                child: Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x24FF5A36),
                          borderRadius: BorderRadius.all(Radius.circular(9)),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0x55FF5A36)),
                          ),
                        ),
                        child: SizedBox.square(
                          dimension: 28,
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            size: 17,
                            color: ResonanceColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'RESONANCE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Color(0xFFE8E3DC),
                        ),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'музыка звучит вместе',
                        style: TextStyle(
                          fontSize: 10,
                          color: ResonanceColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const _LiveIndicator(),
          const SizedBox(width: 8),
          _WindowAction(
            tooltip: 'Свернуть',
            icon: Icons.remove_rounded,
            onPressed: windowManager.minimize,
          ),
          _WindowAction(
            tooltip: 'Развернуть',
            icon: Icons.crop_square_rounded,
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowAction(
            tooltip: 'Закрыть',
            icon: Icons.close_rounded,
            destructive: true,
            onPressed: windowManager.close,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: Color(0xFF151514),
      borderRadius: BorderRadius.all(Radius.circular(99)),
      border: Border.fromBorderSide(BorderSide(color: ResonanceColors.border)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ResonanceColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 7),
          Text(
            'ONLINE',
            style: TextStyle(
              color: Color(0xFFAAA59F),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _WindowAction extends StatelessWidget {
  const _WindowAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: destructive ? const Color(0x18FF5A63) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          hoverColor: destructive
              ? const Color(0xCCB72A36)
              : ResonanceColors.surfaceRaised,
          onTap: () => unawaited(onPressed()),
          child: SizedBox(
            width: 38,
            height: 32,
            child: Icon(
              icon,
              size: 17,
              color: destructive
                  ? const Color(0xFFFF8E94)
                  : const Color(0xFFC8C3BC),
            ),
          ),
        ),
      ),
    ),
  );
}
