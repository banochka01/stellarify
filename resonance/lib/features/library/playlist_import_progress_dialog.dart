import 'dart:async';

import 'package:flutter/material.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

final class PlaylistImportOutcome {
  const PlaylistImportOutcome({required this.name, required this.trackCount});

  final String name;
  final int trackCount;
}

/// Owns the import future and its visual state. Keeping both in one route
/// avoids a race between an unawaited loading dialog and manual Navigator.pop.
class PlaylistImportProgressDialog extends StatefulWidget {
  const PlaylistImportProgressDialog({required this.run, super.key});

  final Future<PlaylistImportOutcome> Function() run;

  @override
  State<PlaylistImportProgressDialog> createState() =>
      _PlaylistImportProgressDialogState();
}

class _PlaylistImportProgressDialogState
    extends State<PlaylistImportProgressDialog> {
  bool _working = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    if (!_working) {
      setState(() {
        _working = true;
        _error = null;
      });
    }
    try {
      final outcome = await widget.run();
      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error.toString().replaceFirst(RegExp(r'^\w+: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_working,
    child: AlertDialog(
      title: Text(_working ? 'Переносим плейлист' : 'Импорт не завершён'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_working) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 20),
              const Text(
                'Получаем треки, объединяем совпадения и сохраняем их в медиатеке.',
                style: TextStyle(color: ResonanceColors.muted, height: 1.45),
              ),
            ] else ...[
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFFA69D),
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(_error ?? 'Не удалось импортировать плейлист.'),
            ],
          ],
        ),
      ),
      actions: _working
          ? const []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
              FilledButton.icon(
                onPressed: _run,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
    ),
  );
}
