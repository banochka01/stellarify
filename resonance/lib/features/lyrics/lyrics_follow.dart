import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

/// Индекс строки, которая звучит в [position], или -1 до первой строки.
int activeLyricLine(List<LyricLine> lines, Duration position) {
  var result = -1;
  for (var index = 0; index < lines.length; index++) {
    final start = lines[index].start;
    if (start == null || start > position) break;
    result = index;
  }
  return result;
}

/// Плавно подводит строку к [alignment] внутри своего списка.
///
/// В отличие от `Scrollable.ensureVisible`, не трогает внешние прокрутки:
/// страница плеера больше не дёргается при каждой новой строке. Если строка
/// ещё не построена (далеко после перемотки), сначала прыгает примерно к ней,
/// а на следующем кадре доводит точно.
void followLyricLine({
  required ScrollController controller,
  required GlobalKey line,
  required int index,
  required int count,
  required double alignment,
  required Duration duration,
  bool retry = true,
}) {
  if (!controller.hasClients) return;
  final position = controller.position;
  final box = line.currentContext?.findRenderObject();
  if (box == null || !box.attached) {
    if (!retry || count <= 1) return;
    controller.jumpTo(position.maxScrollExtent * index / (count - 1));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => followLyricLine(
        controller: controller,
        line: line,
        index: index,
        count: count,
        alignment: alignment,
        duration: duration,
        retry: false,
      ),
    );
    return;
  }
  final viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport == null) return;
  final target = viewport
      .getOffsetToReveal(box, alignment)
      .offset
      .clamp(position.minScrollExtent, position.maxScrollExtent);
  if ((target - position.pixels).abs() < 1) return;
  if (duration == Duration.zero) {
    controller.jumpTo(target);
  } else {
    controller.animateTo(
      target,
      duration: duration,
      curve: ResonanceMotion.curve,
    );
  }
}

/// Строка текста: активная — яркая и в полный размер, остальные — тише и
/// чуть меньше. Размер меняется трансформацией, а не шрифтом, поэтому список
/// не перестраивает раскладку посреди прокрутки.
class LyricLineText extends StatelessWidget {
  const LyricLineText({
    required this.text,
    required this.style,
    required this.active,
    required this.dimColor,
    this.activeColor = const Color(0xFFF0EBF5),
    this.inactiveScale = .86,
    super.key,
  });

  final String text;
  final TextStyle style;
  final bool active;
  final Color activeColor;
  final Color dimColor;
  final double inactiveScale;

  @override
  Widget build(BuildContext context) {
    final duration = ResonanceMotion.durationOf(
      context,
      ResonanceMotion.gentle,
    );
    return AnimatedScale(
      scale: active ? 1 : inactiveScale,
      alignment: AlignmentDirectional.centerStart.resolve(
        Directionality.of(context),
      ),
      duration: duration,
      curve: ResonanceMotion.curve,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: active ? activeColor : dimColor),
        duration: duration,
        curve: ResonanceMotion.curve,
        builder: (context, color, _) =>
            Text(text, style: style.copyWith(color: color)),
      ),
    );
  }
}
