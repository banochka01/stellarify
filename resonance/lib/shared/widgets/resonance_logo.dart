import 'package:flutter/material.dart';

/// Знак Resonance: точечная сфера на тёмной плашке, как иконка приложения.
class ResonanceLogo extends StatelessWidget {
  const ResonanceLogo({this.size = 28, super.key});

  static const asset = 'assets/images/resonance_mark.png';

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Resonance',
    image: true,
    child: Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(size * .24),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Image.asset(
        asset,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    ),
  );
}
