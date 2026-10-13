import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/recognize/recognition_api.dart';

/// Кнопка «Что играет?». Видна, только если сервер сообщил, что
/// распознавание настроено.
class RecognizeButton extends ConsumerWidget {
  const RecognizeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available =
        ref.watch(recognitionAvailableProvider).valueOrNull ?? false;
    if (!available) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Распознать трек',
      onPressed: () => unawaited(
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          isDismissible: true,
          builder: (context) => const _RecognizeSheet(),
        ),
      ),
      icon: const Icon(Icons.mic_none_rounded),
    );
  }
}

enum _Stage { listening, sending, found, notFound, failed }

class _RecognizeSheet extends ConsumerStatefulWidget {
  const _RecognizeSheet();

  @override
  ConsumerState<_RecognizeSheet> createState() => _RecognizeSheetState();
}

class _RecognizeSheetState extends ConsumerState<_RecognizeSheet> {
  final _recorder = AudioRecorder();
  _Stage _stage = _Stage.listening;
  String? _message;
  RecognizedTrack? _recognized;
  UnifiedTrack? _match;
  bool _exact = false;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _message = message;
    });
  }

  Future<void> _run() async {
    File? file;
    try {
      if (!await _recorder.hasPermission()) {
        _fail('Нет доступа к микрофону.');
        return;
      }
      final directory = await getTemporaryDirectory();
      file = File(
        p.join(
          directory.path,
          'resonance-recognize-${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 22050,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: file.path,
      );
      await Future<void>.delayed(RecognitionApi.sampleDuration);
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      final path = await _recorder.stop();
      setState(() => _stage = _Stage.sending);
      final recorded = File(path ?? file.path);
      final bytes = await recorded.readAsBytes();
      // Фрагмент нигде не храним: удаляем сразу после чтения.
      await _deleteQuietly(recorded);
      if (recorded.path != file.path) await _deleteQuietly(file);
      final recognized = await ref
          .read(recognitionApiProvider)
          .recognize(bytes, contentType: 'audio/mp4');
      if (!mounted) return;
      if (recognized == null) {
        setState(() => _stage = _Stage.notFound);
        return;
      }
      final match = await _findInCatalogs(recognized);
      if (!mounted) return;
      setState(() {
        _recognized = recognized;
        _match = match?.track;
        _exact = match?.exact ?? false;
        _stage = _Stage.found;
      });
      // Автоматически — только точное совпадение; похожее добавит человек.
      if (match != null && match.exact) await _addToLibrary(match.track);
    } on RecognitionException catch (error) {
      _fail(error.message);
    } on Object {
      _fail('Не удалось записать фрагмент.');
    } finally {
      // На случай ошибки до чтения файла.
      if (file != null) await _deleteQuietly(file);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Временная папка очистится системой.
    }
  }

  Future<({UnifiedTrack track, bool exact})?> _findInCatalogs(
    RecognizedTrack recognized,
  ) async {
    final registry = ref.read(providerRegistryProvider);
    final batches = await Future.wait([
      for (final provider in MusicProvider.values)
        if (registry.catalogFor(provider) case final catalog?)
          catalog
              .searchTracks(recognized.query, limit: 5)
              .onError((_, _) => const <UnifiedTrack>[]),
    ]);
    final tracks = const MusicGraphBuilder().canonicalize(
      batches.expand((batch) => batch),
    );
    return catalogMatch(recognized, tracks);
  }

  Future<void> _addToLibrary(UnifiedTrack track) async {
    final library = ref.read(libraryControllerProvider);
    final already =
        library.valueOrNull?.favoriteIds.contains(track.id) ?? false;
    if (!already) {
      await ref.read(libraryControllerProvider.notifier).toggleFavorite(track);
    }
    if (mounted) setState(() => _added = true);
  }

  Future<void> _play(UnifiedTrack track) async {
    final service = await ref.read(playbackServiceProvider.future);
    await service.playTrack(track);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final recognized = _recognized;
    final match = _match;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Что сейчас играет?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            switch (_stage) {
              _Stage.listening => _Progress(
                icon: Icons.mic_rounded,
                text: 'Слушаю 8 секунд — поднесите устройство ближе к звуку.',
              ),
              _Stage.sending => const _Progress(
                icon: Icons.travel_explore_rounded,
                text: 'Ищу совпадение…',
              ),
              _Stage.notFound => Text(
                'Не получилось узнать трек. Попробуйте ещё раз ближе к источнику.',
                style: TextStyle(color: muted),
              ),
              _Stage.failed => Text(
                _message ?? 'Что-то пошло не так.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              _Stage.found => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(recognized!.title),
                    subtitle: Text(
                      [
                        recognized.artist,
                        if (recognized.album != null) recognized.album!,
                      ].join(' · '),
                    ),
                  ),
                  if (match == null)
                    Text(
                      'Трека нет в подключённых каталогах — добавить его в медиатеку нельзя.',
                      style: TextStyle(color: muted),
                    )
                  else ...[
                    Text(
                      _added
                          ? 'Добавлено в «Любимое».'
                          : _exact
                          ? 'Добавляю в медиатеку…'
                          : 'Похожий трек: «${match.title}» — ${match.artist}. Проверьте, тот ли это.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 12),
                    if (!_exact && !_added)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => unawaited(_addToLibrary(match)),
                          icon: const Icon(Icons.favorite_border_rounded),
                          label: const Text('Добавить в «Любимое»'),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: () => unawaited(_play(match)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Слушать'),
                    ),
                  ],
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
