import 'package:flutter/material.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({
    required this.provider,
    this.compact = false,
    super.key,
  });

  final MusicProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (provider) {
      MusicProvider.youtube => ResonanceColors.youtube,
      MusicProvider.yandex => ResonanceColors.yandex,
      MusicProvider.soundcloud => ResonanceColors.soundcloud,
    };
    return Container(
      width: compact ? 23 : 30,
      height: compact ? 23 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: CustomPaint(
        size: Size.square(compact ? 14 : 18),
        painter: _ProviderLogoPainter(provider, color),
      ),
    );
  }
}

class _ProviderLogoPainter extends CustomPainter {
  const _ProviderLogoPainter(this.provider, this.color);
  final MusicProvider provider;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    switch (provider) {
      case MusicProvider.youtube:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(size.width * .28),
          ),
          paint,
        );
        final play = Path()
          ..moveTo(size.width * .42, size.height * .28)
          ..lineTo(size.width * .42, size.height * .72)
          ..lineTo(size.width * .73, size.height * .5)
          ..close();
        canvas.drawPath(play, Paint()..color = Colors.white);
      case MusicProvider.soundcloud:
        final base = size.height * .72;
        for (var i = 0; i < 5; i++) {
          final x = size.width * (.08 + i * .1);
          final h = size.height * (.25 + i * .08);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, base - h, size.width * .065, h),
              const Radius.circular(2),
            ),
            paint,
          );
        }
        canvas.drawCircle(
          Offset(size.width * .63, size.height * .52),
          size.width * .25,
          paint,
        );
        canvas.drawCircle(
          Offset(size.width * .79, size.height * .6),
          size.width * .17,
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              size.width * .48,
              size.height * .58,
              size.width * .96,
              base,
            ),
            const Radius.circular(3),
          ),
          paint,
        );
      case MusicProvider.yandex:
        canvas.drawCircle(size.center(Offset.zero), size.width * .48, paint);
        final mark = TextPainter(
          text: const TextSpan(
            text: 'Y',
            style: TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        mark.paint(
          canvas,
          Offset(
            (size.width - mark.width) / 2,
            (size.height - mark.height) / 2,
          ),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ProviderLogoPainter oldDelegate) =>
      oldDelegate.provider != provider || oldDelegate.color != color;
}
