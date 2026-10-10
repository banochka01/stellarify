import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/migration/migration_api.dart';
import 'package:resonance/shared/russian_plural.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';

/// Подтягивает перенесённую медиатеку из Resonance ID в локальную базу.
final migrationLibraryRefreshProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    await ref.read(librarySyncServiceProvider).sync();
    ref.invalidate(libraryControllerProvider);
  };
});

/// Открывает «Переезд» поверх текущего экрана, не трогая маршруты вкладок.
Future<void> openMigrationScreen(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const MigrationScreen()));

class MigrationScreen extends ConsumerStatefulWidget {
  const MigrationScreen({super.key});

  @override
  ConsumerState<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends ConsumerState<MigrationScreen> {
  MusicProvider _source = MusicProvider.spotify;
  MusicProvider _target = MusicProvider.yandex;
  MigrationJob? _job;
  MigrationReport? _report;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _setup = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  MigrationApi get _api => ref.read(migrationApiProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _api.jobs();
      final latest = jobs.firstOrNull;
      if (!mounted) return;
      setState(() {
        _job = latest;
        _setup = latest == null;
        if (latest != null) {
          _source = latest.source;
          _target = latest.target;
        }
      });
      if (latest != null) await _follow(latest);
    } on MigrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow(MigrationJob job) async {
    _poll?.cancel();
    if (job.isActive) {
      var inFlight = false;
      _poll = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
        // Медленный сервер не должен копить параллельные запросы.
        if (inFlight) return;
        inFlight = true;
        try {
          final next = await _api.job(job.id);
          if (!mounted || !timer.isActive) return;
          setState(() {
            _job = next;
            _error = null;
          });
          if (!next.isActive) {
            timer.cancel();
            await _follow(next);
          }
        } on MigrationException catch (error) {
          if (mounted) setState(() => _error = error.message);
        } finally {
          inFlight = false;
        }
      });
      return;
    }
    if (job.isCompleted) {
      await _loadReport(job.id);
      await _syncLibrary();
    }
  }

  Future<void> _loadReport(String jobId) async {
    final report = await _api.report(jobId);
    if (mounted) setState(() => _report = report);
  }

  /// Повторная загрузка отчёта, если она сорвалась после завершения переноса.
  Future<void> _retryReport() async {
    final job = _job;
    if (job == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _follow(job);
    } on MigrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncLibrary() async {
    try {
      await ref.read(migrationLibraryRefreshProvider)();
    } on Object {
      // Медиатека подтянется при следующей синхронизации аккаунта.
    }
  }

  Future<void> _run(Future<MigrationJob> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final job = await action();
      if (!mounted) return;
      setState(() {
        _job = job;
        _report = null;
        _setup = false;
      });
      await _follow(job);
    } on MigrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _itemAction(Future<void> Function() action) async {
    final job = _job;
    if (job == null) return;
    try {
      await action();
      await _loadReport(job.id);
      unawaited(_syncLibrary());
    } on MigrationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _findManually(MigrationItem item) async {
    final job = _job;
    if (job == null) return;
    final picked = await showModalBottomSheet<MigrationTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ResonanceColors.surface,
      showDragHandle: true,
      builder: (_) => _ManualSearchSheet(api: _api, job: job, item: item),
    );
    if (picked == null) return;
    await _itemAction(() => _api.replace(job.id, item.itemId, picked));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountControllerProvider, (previous, next) {
      // Вошли после открытия экрана — список переездов нужно перечитать.
      final wasSignedOut =
          previous != null && previous.hasValue && previous.value == null;
      if (wasSignedOut && next.valueOrNull != null) {
        unawaited(_load());
      }
    });
    final account = ref.watch(accountControllerProvider);
    final user = account.valueOrNull;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final Widget body;
    if (user == null && account.isLoading) {
      // Аккаунт ещё читается — не мигаем приглашением войти.
      body = const Center(child: CircularProgressIndicator());
    } else if (user == null) {
      body = _SignInPrompt(
        onSignIn: () {
          Navigator.of(context).pop();
          GoRouter.of(context).go('/account');
        },
      );
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_setup || _job == null) {
      body = _SetupView(
        source: _source,
        target: _target,
        busy: _busy,
        onSource: (value) => setState(() {
          _source = value;
          if (_target == value) {
            _target = migrationTargets.firstWhere((item) => item != value);
          }
        }),
        onTarget: (value) => setState(() => _target = value),
        onStart: () => _run(() => _api.start(_source, _target)),
        onCancel: _job == null ? null : () => setState(() => _setup = false),
      );
    } else if (_job!.isCompleted && _report != null) {
      body = _ReportView(
        report: _report!,
        busy: _busy,
        onConfirm: (item) =>
            _itemAction(() => _api.confirm(_job!.id, item.itemId)),
        onFind: _findManually,
        onResync: () =>
            _run(() => _api.start(_job!.source, _job!.target, resync: true)),
        onNew: () => setState(() => _setup = true),
      );
    } else {
      body = _ProgressView(
        job: _job!,
        busy: _busy,
        onResume: () => _run(() => _api.resume(_job!)),
        onShowReport: _retryReport,
        onNew: () => setState(() => _setup = true),
      );
    }
    return Scaffold(
      backgroundColor: ResonanceColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Переезд'),
        actions: [
          if (user != null && !_loading)
            IconButton(
              tooltip: 'Обновить',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null && user != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Notice(
                        icon: Icons.error_outline_rounded,
                        text: _error!,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.luggage_rounded,
                size: 40,
                color: ResonanceColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Переезд работает через Resonance ID',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Медиатека переносится на сервере и сохраняется в аккаунте — '
                'её увидят все ваши устройства.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ResonanceColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onSignIn,
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.source,
    required this.target,
    required this.busy,
    required this.onSource,
    required this.onTarget,
    required this.onStart,
    this.onCancel,
  });

  final MusicProvider source;
  final MusicProvider target;
  final bool busy;
  final ValueChanged<MusicProvider> onSource;
  final ValueChanged<MusicProvider> onTarget;
  final VoidCallback onStart;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Вся музыка — в один переезд',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Перенесём лайки, плейлисты, сохранённые альбомы и подписки на '
          'артистов. Каждый трек найдём в новом каталоге и покажем, где '
          'совпадение сомнительное.',
          style: TextStyle(color: ResonanceColors.muted, height: 1.4),
        ),
        const SizedBox(height: 26),
        const _Label('ОТКУДА'),
        const SizedBox(height: 10),
        _ProviderPicker(
          options: migrationSources,
          selected: source,
          onSelected: onSource,
        ),
        const SizedBox(height: 22),
        const _Label('КУДА · КАТАЛОГ ДЛЯ ВОСПРОИЗВЕДЕНИЯ'),
        const SizedBox(height: 10),
        _ProviderPicker(
          options: migrationTargets
              .where((item) => item != source)
              .toList(growable: false),
          selected: target,
          onSelected: onTarget,
        ),
        const SizedBox(height: 22),
        const _Notice(
          icon: Icons.info_outline_rounded,
          text:
              'Нужен подключённый токен источника. Перенос идёт на сервере — '
              'экран можно закрыть и вернуться позже.',
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('migration-start'),
              onPressed: busy ? null : onStart,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping_rounded),
              label: const Text('Начать переезд'),
            ),
            if (onCancel != null)
              TextButton(onPressed: onCancel, child: const Text('Отмена')),
          ],
        ),
      ],
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<MusicProvider> options;
  final MusicProvider selected;
  final ValueChanged<MusicProvider> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in options)
          ChoiceChip(
            avatar: ProviderLogo(provider: provider, size: 18),
            label: Text(migrationProviderTitle(provider)),
            selected: provider == selected,
            onSelected: (_) => onSelected(provider),
          ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.job,
    required this.busy,
    required this.onResume,
    required this.onShowReport,
    required this.onNew,
  });

  final MigrationJob job;
  final bool busy;
  final VoidCallback onResume;
  final VoidCallback onShowReport;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final label = switch (job.status) {
      'queued' => 'Готовимся к переезду',
      'fetching' =>
        'Забираем медиатеку из ${migrationProviderTitle(job.source)}',
      'matching' => 'Ищем треки в ${migrationProviderTitle(job.target)}',
      'saving' => 'Сохраняем в Resonance ID',
      'paused' => 'Перенос на паузе',
      'failed' => 'Перенос остановился',
      'completed' => 'Перенос завершён',
      _ => 'Перенос',
    };
    return ListView(
      children: [
        _Route(source: job.source, target: job.target),
        const SizedBox(height: 26),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: job.status == 'fetching' || job.total == 0
                      ? (job.isActive ? null : 0)
                      : (job.progress / 100).clamp(0, 1),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                job.total == 0
                    ? 'Считаем треки…'
                    : '${job.processed} из ${job.total} · ${job.progress.toStringAsFixed(0)}%',
                style: const TextStyle(color: ResonanceColors.muted),
              ),
              if (job.isActive) ...[
                const SizedBox(height: 14),
                const Text(
                  'Можно закрыть экран — перенос продолжится на сервере.',
                  style: TextStyle(color: ResonanceColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (job.canResume) ...[
          const SizedBox(height: 16),
          if (job.error != null)
            _Notice(icon: Icons.pause_circle_outline_rounded, text: job.error!),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onResume,
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Продолжить'),
              ),
              TextButton(onPressed: onNew, child: const Text('Новый переезд')),
            ],
          ),
        ] else if (!job.isActive) ...[
          // Завершён, но отчёт не загрузился, или неизвестный статус:
          // экран не должен становиться тупиком.
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (job.isCompleted)
                FilledButton.icon(
                  onPressed: busy ? null : onShowReport,
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Показать отчёт'),
                ),
              TextButton(onPressed: onNew, child: const Text('Новый переезд')),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.busy,
    required this.onConfirm,
    required this.onFind,
    required this.onResync,
    required this.onNew,
  });

  final MigrationReport report;
  final bool busy;
  final ValueChanged<MigrationItem> onConfirm;
  final ValueChanged<MigrationItem> onFind;
  final VoidCallback onResync;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final job = report.job;
    final synced = job.lastSyncedAt?.toLocal();
    return ListView(
      children: [
        _Route(source: job.source, target: job.target),
        const SizedBox(height: 22),
        _Card(
          child: Row(
            children: [
              Text(
                '${report.percent.toStringAsFixed(report.percent % 1 == 0 ? 0 : 1)}%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: ResonanceColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.kind == 'resync'
                          ? 'Новые лайки перенесены'
                          : 'Медиатека переехала',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Перенесено ${report.migrated} из ${report.total} '
                      '${ruPlural(report.total, 'трека', 'треков', 'треков')}'
                      '${report.collections > 0 ? ' · ${report.collections} плейлистов и альбомов' : ''}',
                      style: const TextStyle(color: ResonanceColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat('Точно', report.exact, ResonanceColors.success),
            _Stat('Уверенно', report.high, ResonanceColors.primary),
            _Stat('Проверить', report.low, ResonanceColors.yandex),
            _Stat('Не найдено', report.none, ResonanceColors.youtube),
            if (report.manual > 0)
              _Stat('Вручную', report.manual, ResonanceColors.secondary),
          ],
        ),
        if (job.warning != null) ...[
          const SizedBox(height: 12),
          _Notice(icon: Icons.warning_amber_rounded, text: job.warning!),
        ],
        if (job.truncated) ...[
          const SizedBox(height: 12),
          const _Notice(
            icon: Icons.content_cut_rounded,
            text: 'Медиатека очень большая — перенесена её основная часть.',
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('migration-resync'),
              onPressed: busy ? null : onResync,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Синхронизировать новые лайки'),
            ),
            TextButton(onPressed: onNew, child: const Text('Новый переезд')),
            if (synced != null)
              Text(
                'Последняя синхронизация: ${_formatDate(synced)}',
                style: const TextStyle(color: ResonanceColors.muted),
              ),
          ],
        ),
        if (report.lowConfidence.isNotEmpty) ...[
          const SizedBox(height: 28),
          _Label('ПРОВЕРЬТЕ СОВПАДЕНИЯ · ${report.lowConfidence.length}'),
          const SizedBox(height: 8),
          for (final item in report.lowConfidence)
            _ItemTile(
              item: item,
              onConfirm: () => onConfirm(item),
              onFind: () => onFind(item),
            ),
        ],
        if (report.unmatched.isNotEmpty) ...[
          const SizedBox(height: 28),
          _Label('НЕ НАШЛИ · ${report.unmatched.length}'),
          const SizedBox(height: 8),
          for (final item in report.unmatched)
            _ItemTile(item: item, onFind: () => onFind(item)),
        ],
        if (report.lowConfidence.isEmpty && report.unmatched.isEmpty) ...[
          const SizedBox(height: 28),
          const _Notice(
            icon: Icons.check_circle_outline_rounded,
            text: 'Все треки нашлись — проверять нечего.',
          ),
        ],
        if (report.artists.isNotEmpty) ...[
          const SizedBox(height: 28),
          _Label('АРТИСТЫ, НА КОТОРЫХ ВЫ ПОДПИСАНЫ · ${report.artists.length}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final artist in report.artists.take(60))
                ActionChip(
                  label: Text(artist),
                  onPressed: () => GoRouter.of(
                    context,
                  ).go('/artist/${Uri.encodeComponent(artist)}'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onFind, this.onConfirm});

  final MigrationItem item;
  final VoidCallback onFind;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final where = item.section == 'favorite'
        ? 'Любимые'
        : item.collectionTitle ?? 'Плейлист';
    final match = item.match;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: ResonanceColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ResonanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.source.artist} — ${item.source.title}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            where,
            style: const TextStyle(color: ResonanceColors.muted, fontSize: 12),
          ),
          if (match != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: ResonanceColors.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${match.artist} — ${match.title}'
                    '${match.durationMs != null ? ' · ${_formatDuration(match.durationMs!)}' : ''}',
                    style: const TextStyle(color: ResonanceColors.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: [
              if (onConfirm != null && match != null)
                TextButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Подтвердить'),
                ),
              TextButton.icon(
                onPressed: onFind,
                icon: const Icon(Icons.manage_search_rounded, size: 18),
                label: Text(match == null ? 'Найти вручную' : 'Заменить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualSearchSheet extends StatefulWidget {
  const _ManualSearchSheet({
    required this.api,
    required this.job,
    required this.item,
  });

  final MigrationApi api;
  final MigrationJob job;
  final MigrationItem item;

  @override
  State<_ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends State<_ManualSearchSheet> {
  late final TextEditingController _query = TextEditingController(
    text: '${widget.item.source.artist} ${widget.item.source.title}',
  );
  List<MigrationCandidate> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_search());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.candidates(
        widget.job,
        widget.item.itemId,
        query: _query.text,
      );
      if (mounted) setState(() => _results = results);
    } on MigrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Найти в ${migrationProviderTitle(widget.job.target)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? _error != null
                        ? const SizedBox.shrink()
                        : const Center(
                            child: Text(
                              'Ничего не нашлось — попробуйте другой запрос.',
                              style: TextStyle(color: ResonanceColors.muted),
                            ),
                          )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final candidate = _results[index];
                        final track = candidate.track;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(track.title),
                          subtitle: Text(
                            [
                              track.artist,
                              if (track.album != null) track.album!,
                              if (track.durationMs != null)
                                _formatDuration(track.durationMs!),
                            ].join(' · '),
                          ),
                          trailing: _ConfidenceBadge(candidate.confidence),
                          onTap: () => Navigator.of(context).pop(track),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge(this.confidence);
  final MigrationConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      MigrationConfidence.exact => ('точно', ResonanceColors.success),
      MigrationConfidence.high => ('похоже', ResonanceColors.primary),
      MigrationConfidence.low => ('сомнительно', ResonanceColors.yandex),
      MigrationConfidence.none => ('другое', ResonanceColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.source, required this.target});
  final MusicProvider source;
  final MusicProvider target;

  @override
  Widget build(BuildContext context) {
    Widget side(MusicProvider provider) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProviderLogo(provider: provider, size: 22),
        const SizedBox(width: 8),
        Text(
          migrationProviderTitle(provider),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        side(source),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.east_rounded, color: ResonanceColors.muted),
        ),
        side(target),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ResonanceColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: ResonanceColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$label · $value'),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ResonanceColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ResonanceColors.border),
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? ResonanceColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color ?? ResonanceColors.muted),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ResonanceColors.muted,
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _formatDuration(int ms) {
  final seconds = (ms / 1000).round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
