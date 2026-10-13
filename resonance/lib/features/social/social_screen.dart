import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_playback.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/features/social/social_api.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider(FeatureFlag.social))) {
      return const FeaturePage(
        eyebrow: 'ДРУЗЬЯ',
        title: 'Слушать с друзьями',
        children: [FeatureUnavailableView()],
      );
    }
    final feedEnabled = ref.watch(
      featureEnabledProvider(FeatureFlag.socialFeed),
    );
    final compact = MediaQuery.sizeOf(context).width < 650;
    final padding = compact ? 18.0 : 34.0;
    return DefaultTabController(
      length: feedEnabled ? 3 : 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              compact ? 24 : 32,
              padding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ДРУЗЬЯ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: ResonanceColors.primary,
                        ),
                      ),
                    ),
                    FeatureGate(
                      flag: FeatureFlag.collaborativePlaylists,
                      child: TextButton.icon(
                        onPressed: () => context.push('/collab'),
                        icon: const Icon(Icons.queue_music_rounded, size: 18),
                        label: const Text('Совместные плейлисты'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Что слушают свои',
                  style: TextStyle(
                    fontSize: compact ? 32 : 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              if (feedEnabled) const Tab(text: 'Лента'),
              const Tab(text: 'Друзья'),
              const Tab(text: 'Профиль'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (feedEnabled) _FeedTab(padding: padding),
                _FriendsTab(padding: padding),
                _ProfileTab(padding: padding),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

EdgeInsets _tabPadding(double padding) =>
    EdgeInsets.fromLTRB(padding, 18, padding, 130);

void joinFriendRoom(BuildContext context, String code) =>
    context.go(Uri(path: '/rooms', queryParameters: {'code': code}).toString());

class _FeedTab extends ConsumerWidget {
  const _FeedTab({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(socialFeedProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(socialFeedProvider.future),
      child: ListView(
        padding: _tabPadding(padding),
        children: feed.when(
          loading: () => const [LinearProgressIndicator(minHeight: 2)],
          error: (error, _) => [
            FeatureUnavailableView(
              error: error,
              onRetry: () => ref.invalidate(socialFeedProvider),
            ),
          ],
          data: (items) => items.isEmpty
              ? const [
                  FeatureEmpty(
                    icon: Icons.people_outline_rounded,
                    text:
                        'Друзья пока ничего не слушают или скрыли активность.',
                  ),
                ]
              : [for (final item in items) FeedItemTile(item: item)],
        ),
      ),
    );
  }
}

class FeedItemTile extends ConsumerWidget {
  const FeedItemTile({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = item.nowPlaying ?? item.recent.firstOrNull;
    final room = item.room;
    final roomsVisible = ref.watch(
      featureEnabledProvider(FeatureFlag.socialRooms),
    );
    return FeatureCard(
      highlight: room != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: item.friend.displayName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.friend.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (playing != null)
                      Text(
                        '${item.nowPlaying != null ? 'Сейчас' : 'Недавно'}: ${playing.title} — ${playing.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ResonanceColors.muted),
                      ),
                  ],
                ),
              ),
              _FriendActions(friend: item.friend),
            ],
          ),
          if (room != null && roomsVisible) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 18,
                  color: ResonanceColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      'В комнате',
                      if (room.participants > 0)
                        '${room.participants} слушателей',
                      if (room.track case final track?)
                        '${track.title} — ${track.artist}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.code case final code?)
                  FilledButton.tonal(
                    onPressed: () => joinFriendRoom(context, code),
                    child: const Text('Присоединиться'),
                  )
                else
                  const Tooltip(
                    message: 'Закрытая комната — нужна ссылка-приглашение',
                    child: Icon(Icons.lock_rounded, size: 18),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: ResonanceColors.surfaceHigh,
    child: Text(
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
    ),
  );
}

/// Compatibility + Blend entry for a friend.
class _FriendActions extends StatelessWidget {
  const _FriendActions({required this.friend});

  final PublicProfile friend;

  @override
  Widget build(BuildContext context) => FeatureGate(
    flag: FeatureFlag.socialCompatibility,
    child: IconButton(
      tooltip: 'Совместимость',
      onPressed: () => unawaited(
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => CompatibilitySheet(friend: friend),
        ),
      ),
      icon: const Icon(Icons.favorite_border_rounded),
    ),
  );
}

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab({required this.padding});

  final double padding;

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  final _query = TextEditingController();
  List<PublicProfile>? _results;
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(socialFriendsProvider);
      if (done != null && mounted) showFeatureSnack(context, done);
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.length < 2) return;
    final api = ref.read(socialApiProvider);
    // An invite code or @handle can be used directly.
    if (text.startsWith('@')) {
      await _run(
        () => api.requestFriend(handle: text.substring(1)),
        'Заявка отправлена',
      );
      return;
    }
    await _run(() async {
      final results = await api.search(text);
      if (mounted) setState(() => _results = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(socialFriendsProvider);
    final api = ref.read(socialApiProvider);
    return ListView(
      padding: _tabPadding(widget.padding),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                onSubmitted: (_) => unawaited(_search()),
                decoration: const InputDecoration(
                  labelText: 'Имя или @ник',
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: _busy ? null : () => unawaited(_search()),
              child: const Text('Найти'),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Добавить по коду приглашения',
              onPressed: _busy ? null : () => unawaited(_inviteDialog()),
              icon: const Icon(Icons.qr_code_rounded),
            ),
          ],
        ),
        if (_results != null) ...[
          const FeatureSectionTitle('Результаты поиска'),
          if (_results!.isEmpty)
            const FeatureEmpty(text: 'Никого не нашли среди публичных профилей')
          else
            for (final user in _results!)
              _PersonTile(
                person: user,
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _run(
                            () => api.requestFriend(userId: user.userId),
                            'Заявка отправлена',
                          ),
                        ),
                  child: const Text('В друзья'),
                ),
              ),
        ],
        ...friends.when(
          loading: () => const [LinearProgressIndicator(minHeight: 2)],
          error: (error, _) => [
            FeatureUnavailableView(
              error: error,
              onRetry: () => ref.invalidate(socialFriendsProvider),
            ),
          ],
          data: (value) => [
            if (value.incoming.isNotEmpty) ...[
              const FeatureSectionTitle('Заявки'),
              for (final person in value.incoming)
                _PersonTile(
                  person: person,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => unawaited(
                                _run(() => api.accept(person.userId)),
                              ),
                        child: const Text('Принять'),
                      ),
                      IconButton(
                        tooltip: 'Отклонить',
                        onPressed: _busy
                            ? null
                            : () => unawaited(
                                _run(() => api.cancelRequest(person.userId)),
                              ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
            ],
            const FeatureSectionTitle('Друзья'),
            if (value.friends.isEmpty)
              const FeatureEmpty(text: 'Пока ни одного друга')
            else
              for (final person in value.friends)
                _PersonTile(
                  person: person,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FriendActions(friend: person),
                      PopupMenuButton<String>(
                        onSelected: (_) => unawaited(
                          _run(() => api.removeFriend(person.userId)),
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Удалить из друзей'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            if (value.outgoing.isNotEmpty) ...[
              const FeatureSectionTitle('Отправленные заявки'),
              for (final person in value.outgoing)
                _PersonTile(
                  person: person,
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _run(() => api.cancelRequest(person.userId)),
                          ),
                    child: const Text('Отменить'),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _inviteDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Код приглашения'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;
    await _run(
      () => ref.read(socialApiProvider).requestFriend(inviteCode: code.trim()),
      'Заявка отправлена',
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.trailing});

  final PublicProfile person;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Row(
      children: [
        _Avatar(name: person.displayName),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (person.handle != null)
                Text(
                  '@${person.handle}',
                  style: const TextStyle(
                    color: ResonanceColors.muted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

class CompatibilitySheet extends ConsumerStatefulWidget {
  const CompatibilitySheet({required this.friend, super.key});

  final PublicProfile friend;

  @override
  ConsumerState<CompatibilitySheet> createState() => _CompatibilitySheetState();
}

class _CompatibilitySheetState extends ConsumerState<CompatibilitySheet> {
  bool _blending = false;

  Future<void> _blend() async {
    setState(() => _blending = true);
    try {
      final mix = await ref.read(socialApiProvider).blend(widget.friend.userId);
      final count = await playTrackList(ref, mix.tracks);
      if (!mounted) return;
      showFeatureSnack(
        context,
        count == 0
            ? 'В Blend пока нет доступных треков'
            : '${mix.title}: $count треков в очереди',
      );
      unawaited(Navigator.of(context).maybePop());
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _blending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compatibility = ref.watch(
      socialCompatibilityProvider(widget.friend.userId),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы и ${widget.friend.displayName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            compatibility.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (error, _) => FeatureUnavailableView(error: error),
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.enoughData ? '${value.percent}%' : '—',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: ResonanceColors.primary,
                    ),
                  ),
                  Text(
                    value.enoughData
                        ? 'музыкальная совместимость'
                        : 'Пока мало данных — послушайте ещё немного',
                    style: const TextStyle(color: ResonanceColors.muted),
                  ),
                  if (value.sharedArtists.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final artist in value.sharedArtists.take(8))
                          Chip(label: Text(artist)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            FeatureGate(
              flag: FeatureFlag.socialBlend,
              child: FilledButton.icon(
                onPressed: _blending ? null : () => unawaited(_blend()),
                icon: const Icon(Icons.blender_rounded),
                label: const Text('Слушать Blend'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab({required this.padding});

  final double padding;

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  bool _saving = false;

  Future<void> _save(Future<void> Function(SocialApi api) action) async {
    setState(() => _saving = true);
    try {
      await action(ref.read(socialApiProvider));
      ref.invalidate(socialProfileProvider);
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(socialProfileProvider);
    return ListView(
      padding: _tabPadding(widget.padding),
      children: profile.when(
        loading: () => const [LinearProgressIndicator(minHeight: 2)],
        error: (error, _) => [
          FeatureUnavailableView(
            error: error,
            onRetry: () => ref.invalidate(socialProfileProvider),
          ),
        ],
        data: (value) => [
          FeatureCard(
            child: Row(
              children: [
                _Avatar(name: value.displayName),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        value.handle == null
                            ? 'Ник не задан'
                            : '@${value.handle}',
                        style: const TextStyle(color: ResonanceColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (value.inviteCode != null)
            FeatureCard(
              child: Row(
                children: [
                  Expanded(child: Text('Код приглашения: ${value.inviteCode}')),
                  IconButton(
                    tooltip: 'Скопировать',
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: value.inviteCode!),
                    ),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  IconButton(
                    tooltip: 'Новый код',
                    onPressed: _saving
                        ? null
                        : () => unawaited(_save((api) => api.newInvite())),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          const FeatureSectionTitle('Приватность'),
          FeatureCard(
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('social-public'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Публичный профиль'),
                  subtitle: const Text('Вас можно найти по имени и нику'),
                  value: value.isPublic,
                  onChanged: _saving
                      ? null
                      : (next) => unawaited(
                          _save((api) => api.updateProfile(isPublic: next)),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Показывать друзьям, что я слушаю'),
                  value: value.shareListening,
                  onChanged: _saving
                      ? null
                      : (next) => unawaited(
                          _save(
                            (api) => api.updateProfile(shareListening: next),
                          ),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Показывать мои комнаты друзьям'),
                  value: value.shareRooms,
                  onChanged: _saving
                      ? null
                      : (next) => unawaited(
                          _save((api) => api.updateProfile(shareRooms: next)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
