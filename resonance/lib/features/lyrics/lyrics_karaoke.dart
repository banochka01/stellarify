import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_follow.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/shared/widgets/playback_position.dart';

/// Строку без следующей отметки считаем длиной не больше этого.
const _lastLineFallback = Duration(seconds: 5);

/// Доля строки [line], которая уже прозвучала к [position] (0…1).
///
/// Если у источника есть время каждого слова — заполнение идёт по словам:
/// слово подсвечивается целиком, пока поётся, и плавно «перетекает» к
/// следующему. Иначе строка заполняется равномерно до начала следующей.
double karaokeProgress(LyricLine line, Duration? nextStart, Duration position) {
  final start = line.start;
  if (start == null || position < start) return 0;
  final end = nextStart != null && nextStart > start
      ? nextStart
      : start + _lastLineFallback;
  if (position >= end) return 1;
  final total = line.text.length;
  if (!line.hasWordTiming || total == 0) {
    return (position - start).inMilliseconds /
        (end - start).inMilliseconds.clamp(1, 1 << 31);
  }
  var consumed = 0;
  for (var index = 0; index < line.words.length; index++) {
    final word = line.words[index];
    final wordEnd = index + 1 < line.words.length
        ? line.words[index + 1].start
        : end;
    final length = word.text.length;
    if (position < word.start) break;
    if (position >= wordEnd) {
      consumed += length;
      continue;
    }
    final span = (wordEnd - word.start).inMilliseconds;
    // Короткое слово заполняется почти сразу — так его читают, а не ждут.
    final within = span <= 0
        ? 1.0
        : ((position - word.start).inMilliseconds / (span * .6)).clamp(0, 1);
    return ((consumed + length * within) / total).clamp(0, 1).toDouble();
  }
  return (consumed / total).clamp(0, 1).toDouble();
}

/// Начало строки после [index] (первая с отметкой позже текущей).
Duration? nextLyricStart(List<LyricLine> lines, int index) {
  final start = index >= 0 && index < lines.length ? lines[index].start : null;
  for (var next = index + 1; next < lines.length; next++) {
    final candidate = lines[next].start;
    if (candidate != null && (start == null || candidate > start)) {
      return candidate;
    }
  }
  return null;
}

/// Включён ли перевод вторым рядом. Живёт до закрытия приложения.
final lyricsTranslationEnabledProvider =
    NotifierProvider<_TranslationToggle, bool>(_TranslationToggle.new);

class _TranslationToggle extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Перевод строк трека. `null`, если сервер его не умеет или запрос упал.
final lyricsTranslationProvider = FutureProvider.autoDispose
    .family<List<String>?, UnifiedTrack>((ref, track) async {
      final document = await ref.watch(lyricsProvider(track).future);
      if (document == null || !document.translatable) return null;
      return ref.read(lyricsServiceProvider).translate(document.lines);
    });

/// Перевод для показа, если он включён и готов; иначе `null`.
List<String>? watchLyricsTranslation(
  WidgetRef ref,
  UnifiedTrack track,
  LyricsDocument document,
) {
  if (!document.translatable) return null;
  if (!ref.watch(lyricsTranslationEnabledProvider)) return null;
  final value = ref.watch(lyricsTranslationProvider(track)).valueOrNull;
  if (value == null || value.length != document.lines.length) return null;
  return value;
}

/// Строка текста в режиме караоке. Активная строка заполняется светом по
/// мере звучания (по словам, если источник их размечает), перевод — тихим
/// вторым рядом. Неактивные строки ведут себя как [LyricLineText].
class KaraokeLyricLine extends StatelessWidget {
  const KaraokeLyricLine({
    required this.line,
    required this.nextStart,
    required this.style,
    required this.active,
    required this.dimColor,
    this.activeColor = const Color(0xFFF0EBF5),
    this.inactiveScale = .86,
    this.karaoke = true,
    this.translation,
    super.key,
  });

  final LyricLine line;
  final Duration? nextStart;
  final TextStyle style;
  final bool active;
  final Color activeColor;
  final Color dimColor;
  final double inactiveScale;
  final bool karaoke;
  final String? translation;

  @override
  Widget build(BuildContext context) {
    final fill = active && karaoke && line.start != null;
    Widget text = LyricLineText(
      text: line.text,
      style: style,
      active: active,
      activeColor: fill ? activeColor.withValues(alpha: .42) : activeColor,
      dimColor: dimColor,
      inactiveScale: inactiveScale,
    );
    if (fill) {
      text = Stack(
        children: [
          text,
          Positioned.fill(
            child: _KaraokeFill(
              line: line,
              nextStart: nextStart,
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
              // RichText вместо Text: заливка — только слой поверх строки,
              // она не дублирует текст для поиска и экранного диктора.
              span: TextSpan(
                text: line.text,
                style: DefaultTextStyle.of(
                  context,
                ).style.merge(style.copyWith(color: activeColor)),
              ),
            ),
          ),
        ],
      );
    }
    final secondary = translation?.trim();
    if (secondary == null || secondary.isEmpty || secondary == line.text) {
      return text;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            style: TextStyle(
              fontFamily: style.fontFamily,
              fontSize: (style.fontSize ?? 20) * .52,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: active
                  ? activeColor.withValues(alpha: .66)
                  : dimColor.withValues(alpha: dimColor.a * .8),
            ),
            child: Text(secondary),
          ),
        ),
      ],
    );
  }
}

class _KaraokeFill extends ConsumerWidget {
  const _KaraokeFill({
    required this.line,
    required this.nextStart,
    required this.span,
    required this.textScaler,
    required this.textDirection,
  });

  final LyricLine line;
  final Duration? nextStart;
  final TextSpan span;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackPositionProvider);
    final progress = karaokeProgress(line, nextStart, position);
    // Строка может переноситься, поэтому свет режется не горизонтальным
    // градиентом, а по реальным прямоугольникам уже спетых символов:
    // первая строка переноса заполняется раньше второй.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: ClipPath(
            clipper: _SungTextClipper(
              span: span,
              progress: progress,
              textScaler: textScaler,
              textDirection: textDirection,
            ),
            child: RichText(
              text: span,
              textScaler: textScaler,
              textDirection: textDirection,
            ),
          ),
        ),
      ),
    );
  }
}

class _SungTextClipper extends CustomClipper<Path> {
  _SungTextClipper({
    required this.span,
    required this.progress,
    required this.textScaler,
    required this.textDirection,
  });

  final TextSpan span;
  final double progress;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  Path getClip(Size size) {
    final path = Path();
    final text = span.text ?? '';
    if (progress <= 0 || text.isEmpty) return path;
    if (progress >= 1) return path..addRect(Offset.zero & size);
    final painter = TextPainter(
      text: span,
      textScaler: textScaler,
      textDirection: textDirection,
    )..layout(maxWidth: size.width);
    final exact = progress * text.length;
    final whole = exact.floor();
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: whole),
    );
    for (final box in boxes) {
      path.addRect(box.toRect());
    }
    // Текущий символ заполняется частично — движение остаётся плавным.
    if (whole < text.length) {
      final current = painter.getBoxesForSelection(
        TextSelection(baseOffset: whole, extentOffset: whole + 1),
      );
      if (current.isNotEmpty) {
        final rect = current.first.toRect();
        final part = rect.width * (exact - whole);
        path.addRect(
          textDirection == TextDirection.rtl
              ? Rect.fromLTRB(
                  rect.right - part,
                  rect.top,
                  rect.right,
                  rect.bottom,
                )
              : Rect.fromLTRB(
                  rect.left,
                  rect.top,
                  rect.left + part,
                  rect.bottom,
                ),
        );
      }
    }
    painter.dispose();
    return path;
  }

  @override
  bool shouldReclip(_SungTextClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.span != span;
}
