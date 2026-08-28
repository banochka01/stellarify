import 'package:flutter/material.dart';

class SeekTimeline extends StatelessWidget {
  const SeekTimeline({
    required this.value,
    required this.onSeek,
    this.height = 18,
    super.key,
  });

  final double value;
  final ValueChanged<double> onSeek;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset position) =>
            onSeek((position.dx / constraints.maxWidth).clamp(0.0, 1.0));
        return Semantics(
          slider: true,
          label: 'Позиция воспроизведения',
          value: '${(safeValue * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seek(details.localPosition),
            onHorizontalDragStart: (details) => seek(details.localPosition),
            onHorizontalDragUpdate: (details) => seek(details.localPosition),
            child: SizedBox(
              height: height,
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: safeValue,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
