import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_alpha/design/tokens.dart';

/// Squashes on press, lifts on hover. The only tap feedback in α.
class Press extends StatefulWidget {
  const Press({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.tooltip,
    this.scale = .94,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double scale;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    Widget child = AnimatedScale(
      scale: _down ? widget.scale : (_hover ? 1.02 : 1),
      duration: Motion.fast,
      curve: Motion.curve,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .35,
        duration: Motion.fast,
        child: widget.child,
      ),
    );
    child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) child = Tooltip(message: tooltip, child: child);
    return Semantics(button: true, label: tooltip, child: child);
  }
}

/// Round icon control. [filled] paints it with [color].
class Knob extends StatelessWidget {
  const Knob({
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.filled = false,
    this.color = Pal.paper,
    this.iconColor,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool filled;
  final Color color;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      tooltip: tooltip,
      child: AnimatedContainer(
        duration: Motion.base,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: Pal.line, width: 1.2),
        ),
        child: Icon(
          icon,
          size: size * .44,
          color: iconColor ?? (filled ? Pal.stage : color),
        ),
      ),
    );
  }
}

/// Capsule with text: chips, filters, primary actions.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
    this.accent = Pal.acid,
    this.large = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool active;
  final Color accent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Pal.stage : Pal.paper;
    return Press(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        padding: EdgeInsets.symmetric(
          horizontal: large ? 26 : 16,
          vertical: large ? 16 : 10,
        ),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? accent : Pal.line, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: large ? 20 : 16, color: fg),
              SizedBox(width: large ? 10 : 7),
            ],
            Text(
              label,
              style: Txt.body(large ? 16 : 14, color: fg, weight: 700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numbered editorial section heading: "01 — ПОТОК".
class SectionHead extends StatelessWidget {
  const SectionHead({
    required this.index,
    required this.title,
    this.trailing,
    super.key,
  });

  final String index;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(index, style: Txt.mono(12)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Txt.title(26))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Plain message for empty and failed states.
class Hollow extends StatelessWidget {
  const Hollow({required this.title, this.body, this.action, super.key});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Txt.title(22)),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, style: Txt.body(15, color: Pal.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

String clock(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Russian plural: plural(5, 'трек', 'трека', 'треков').
String plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
