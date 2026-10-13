import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/features/recap/card_export.dart';
import 'package:resonance/features/recap/recap_screen.dart' show RecapCard;
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

/// Выбор строки для карточки-цитаты: список строк, тап — превью 4:5.
Future<void> showLyricQuotePicker(
  BuildContext context, {
  required UnifiedTrack track,
  required LyricsDocument document,
  int initialIndex = -1,
}) async {
  final lines = document.lines;
  if (lines.isEmpty) return;
  final index = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ResonanceColors.surface,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Text(
                'Выберите строку для цитаты',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lines.length,
                itemBuilder: (context, i) => ListTile(
                  selected: i == initialIndex,
                  title: Text(lines[i].text),
                  onTap: () => Navigator.of(context).pop(i),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (index == null || !context.mounted) return;
  await showLyricQuoteCard(context, track: track, line: lines[index].text);
}

/// Превью карточки-цитаты и сохранение в PNG тем же путём, что и «Итоги».
Future<void> showLyricQuoteCard(
  BuildContext context, {
  required UnifiedTrack track,
  required String line,
}) => showDialog<void>(
  context: context,
  builder: (context) => _QuoteDialog(track: track, line: line),
);

class _QuoteDialog extends StatefulWidget {
  const _QuoteDialog({required this.track, required this.line});

  final UnifiedTrack track;
  final String line;

  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<_QuoteDialog> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await saveCardImage(
        _cardKey,
        dialogTitle: 'Сохранить цитату',
        fileName: 'resonance-quote-${cardDateStamp()}.png',
      );
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Карточка с цитатой сохранена')),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить картинку')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ResonanceColors.surface,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: LyricQuoteCard(
                        track: widget.track,
                        line: widget.line,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Закрыть'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Сохранить картинку'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка 4:5 в размере карточки итогов: строка крупно, трек внизу.
class LyricQuoteCard extends ConsumerWidget {
  const LyricQuoteCard({required this.track, required this.line, super.key});

  final UnifiedTrack track;
  final String line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchTrackPalette(ref, track);
    final glow = palette.glow;
    final long = line.length > 90;
    return SizedBox(
      width: RecapCard.width,
      height: RecapCard.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(glow, const Color(0xFF0E0B14), .3)!,
                const Color(0xFF120D1A),
                const Color(0xFF0B0810),
              ],
              stops: const [0, .6, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/resonance_mark.webp',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'RESONANCE · ЦИТАТА',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                        color: Color(0xCCEFE9F5),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.format_quote_rounded,
                  size: 44,
                  color: palette.accent.withValues(alpha: .9),
                ),
                const SizedBox(height: 6),
                Text(
                  line,
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: long ? 26 : 34,
                    height: 1.16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    color: const Color(0xFFF4EFF8),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    TrackArtwork(track: track, size: 52, borderRadius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFFEFE9F5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xB3EFE9F5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
