import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_dialogs.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_playback.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/features/social/social_api.dart';

/// Wire contract for /api/v1/collab-playlists (docs/API-5.0.md §5).
abstract final class CollabPaths {
  static const root = '/api/v1/collab-playlists';
  static String _id(String id) => Uri.encodeComponent(id);
  static String playlist(String id) => '$root/${_id(id)}';
  static String member(String id, String userId) =>
      '${playlist(id)}/members/${_id(userId)}';
  static String history(String id) => '${playlist(id)}/history';
  static String revert(String id, String historyId) =>
      '${history(id)}/${_id(historyId)}/revert';
  static String tracks(String id) => '${playlist(id)}/tracks';
}

enum CollaboratorRole {
  owner('Владелец'),
  editor('Редактор'),
  viewer('Слушатель');

  const CollaboratorRole(this.label);

  final String label;

  static CollaboratorRole parse(Object? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => CollaboratorRole.viewer,
  );
}

final class CollabPlaylistSummary {
  const CollabPlaylistSummary({
    required this.id,
    required this.name,
    this.role = CollaboratorRole.viewer,
    this.trackCount = 0,
    this.memberCount = 0,
  });

  factory CollabPlaylistSummary.fromJson(Map<String, dynamic> json) =>
      CollabPlaylistSummary(
        id: jsonString(json['id']),
        name: jsonString(json['name'], 'Плейлист'),
        role: CollaboratorRole.parse(json['role']),
        trackCount: jsonInt(json['trackCount']),
        memberCount: jsonInt(json['memberCount']),
      );

  final String id;
  final String name;
  final CollaboratorRole role;
  final int trackCount;
  final int memberCount;
}

final class PlaylistMember {
  const PlaylistMember({
    required this.userId,
    required this.displayName,
    this.role = CollaboratorRole.editor,
  });

  factory PlaylistMember.fromJson(Map<String, dynamic> json) => PlaylistMember(
    userId: jsonString(json['userId'] ?? json['id']),
    displayName: jsonString(json['displayName'], 'Участник'),
    role: CollaboratorRole.parse(json['role']),
  );

  final String userId;
  final String displayName;
  final CollaboratorRole role;
}

final class CollabEntry {
  const CollabEntry({required this.entryId, required this.track});

  final String entryId;
  final UnifiedTrack track;
}

final class CollabPlaylist {
  const CollabPlaylist({
    required this.id,
    required this.name,
    required this.role,
    this.version = 0,
    this.members = const [],
    this.entries = const [],
  });

  factory CollabPlaylist.fromJson(Map<String, dynamic> json) {
    final body = json['playlist'] is Map ? jsonMap(json['playlist']) : json;
    return CollabPlaylist(
      id: jsonString(body['id']),
      name: jsonString(body['name'], 'Плейлист'),
      role: CollaboratorRole.parse(body['role']),
      version: jsonInt(body['version']),
      members: jsonList(body['members']).map(PlaylistMember.fromJson).toList(),
      entries: [
        for (final entry in jsonList(body['tracks']))
          if (jsonTrack(entry['track']) case final track?)
            CollabEntry(entryId: jsonString(entry['entryId']), track: track),
      ],
    );
  }

  final String id;
  final String name;
  final CollaboratorRole role;
  final int version;
  final List<PlaylistMember> members;
  final List<CollabEntry> entries;

  bool get canEdit => role != CollaboratorRole.viewer;
  bool get isOwner => role == CollaboratorRole.owner;
}

final class PlaylistHistoryEntry {
  const PlaylistHistoryEntry({
    required this.id,
    required this.userId,
    required this.action,
    this.trackTitle,
    this.oldName,
    this.newName,
    this.at,
    this.revertOf,
    this.revertedBy,
  });

  factory PlaylistHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PlaylistHistoryEntry(
        id: jsonString(json['id']),
        userId: jsonString(json['userId']),
        action: jsonString(json['action']),
        trackTitle: jsonOptString(jsonMap(json['track'])['title']),
        oldName: jsonOptString(json['oldName']),
        newName: jsonOptString(json['newName']),
        at: jsonDate(json['createdAt']),
        revertOf: jsonOptString(json['revertOf']),
        revertedBy: jsonOptString(json['revertedBy']),
      );

  final String id;
  final String userId;
  final String action;
  final String? trackTitle;
  final String? oldName;
  final String? newName;
  final DateTime? at;
  final String? revertOf;
  final String? revertedBy;

  bool get revertible => revertedBy == null;

  String describe(String author) {
    final what = switch (action) {
      'add' => 'добавил(а) «${trackTitle ?? 'трек'}»',
      'remove' => 'удалил(а) «${trackTitle ?? 'трек'}»',
      'rename' => 'переименовал(а) «${oldName ?? ''}» → «${newName ?? ''}»',
      _ => action,
    };
    return '$author $what${revertOf != null ? ' (откат)' : ''}';
  }
}

final class CollaborativePlaylistApi {
  const CollaborativePlaylistApi(this._transport);

  final FeatureTransport _transport;

  Future<List<CollabPlaylistSummary>> list() async => jsonList(
    (await _transport.request('GET', CollabPaths.root))['playlists'],
  ).map(CollabPlaylistSummary.fromJson).toList();

  Future<CollabPlaylist> create(String name) async => CollabPlaylist.fromJson(
    await _transport.request(
      'POST',
      CollabPaths.root,
      body: {'name': name.trim()},
    ),
  );

  Future<CollabPlaylist> get(String id) async => CollabPlaylist.fromJson(
    await _transport.request('GET', CollabPaths.playlist(id)),
  );

  Future<void> setMember(String id, String userId, CollaboratorRole role) =>
      _transport.request(
        'PUT',
        CollabPaths.member(id, userId),
        body: {'role': role.name},
      );

  Future<void> removeMember(String id, String userId) =>
      _transport.request('DELETE', CollabPaths.member(id, userId));

  Future<void> rename(String id, String name) => _transport.request(
    'PATCH',
    CollabPaths.playlist(id),
    body: {'name': name.trim()},
  );

  Future<void> delete(String id) =>
      _transport.request('DELETE', CollabPaths.playlist(id));

  Future<void> addTrack(String id, UnifiedTrack track) => _transport.request(
    'POST',
    CollabPaths.tracks(id),
    body: {'track': track.toJson()},
  );

  Future<void> removeTrack(String id, String entryId) => _transport.request(
    'DELETE',
    '${CollabPaths.tracks(id)}/${Uri.encodeComponent(entryId)}',
  );

  Future<List<PlaylistHistoryEntry>> history(String id) async => jsonList(
    (await _transport.request(
      'GET',
      CollabPaths.history(id),
      query: {'limit': '100'},
    ))['history'],
  ).map(PlaylistHistoryEntry.fromJson).toList();

  Future<void> revert(String id, String historyId) =>
      _transport.request('POST', CollabPaths.revert(id, historyId));
}

final collaborativePlaylistApiProvider = Provider<CollaborativePlaylistApi>(
  (ref) => CollaborativePlaylistApi(ref.watch(featureTransportProvider)),
);

final collabPlaylistsProvider =
    FutureProvider.autoDispose<List<CollabPlaylistSummary>>(
      (ref) => ref.watch(collaborativePlaylistApiProvider).list(),
    );

final collabPlaylistProvider = FutureProvider.autoDispose
    .family<CollabPlaylist, String>(
      (ref, id) => ref.watch(collaborativePlaylistApiProvider).get(id),
    );

final playlistHistoryProvider = FutureProvider.autoDispose
    .family<List<PlaylistHistoryEntry>, String>(
      (ref, id) => ref.watch(collaborativePlaylistApiProvider).history(id),
    );

class CollaborativePlaylistsScreen extends ConsumerWidget {
  const CollaborativePlaylistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showTextPrompt(
      context,
      title: 'Новый совместный плейлист',
      label: 'Название',
      action: 'Создать',
    );
    if (name == null || name.isEmpty) return;
    try {
      final playlist = await ref
          .read(collaborativePlaylistApiProvider)
          .create(name);
      ref.invalidate(collabPlaylistsProvider);
      if (context.mounted) unawaited(context.push('/collab/${playlist.id}'));
    } on Object catch (error) {
      if (context.mounted) showFeatureSnack(context, featureErrorText(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(
      featureEnabledProvider(FeatureFlag.collaborativePlaylists),
    )) {
      return const FeaturePage(
        eyebrow: 'СОВМЕСТНЫЕ ПЛЕЙЛИСТЫ',
        title: 'Собирайте вместе',
        children: [FeatureUnavailableView()],
      );
    }
    final playlists = ref.watch(collabPlaylistsProvider);
    return FeaturePage(
      eyebrow: 'СОВМЕСТНЫЕ ПЛЕЙЛИСТЫ',
      title: 'Собирайте вместе',
      actions: [
        FilledButton.tonalIcon(
          onPressed: () => unawaited(_create(context, ref)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Создать'),
        ),
      ],
      children: playlists.when(
        loading: () => const [LinearProgressIndicator(minHeight: 2)],
        error: (error, _) => [
          FeatureUnavailableView(
            error: error,
            onRetry: () => ref.invalidate(collabPlaylistsProvider),
          ),
        ],
        data: (items) => items.isEmpty
            ? const [FeatureEmpty(text: 'Совместных плейлистов пока нет')]
            : [
                for (final item in items)
                  FeatureCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.trackCount} треков · ${item.memberCount} участников · ${item.role.label}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/collab/${item.id}'),
                    ),
                  ),
              ],
      ),
    );
  }
}

class CollaborativePlaylistScreen extends ConsumerStatefulWidget {
  const CollaborativePlaylistScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  ConsumerState<CollaborativePlaylistScreen> createState() =>
      _CollaborativePlaylistScreenState();
}

class _CollaborativePlaylistScreenState
    extends ConsumerState<CollaborativePlaylistScreen> {
  bool _busy = false;

  CollaborativePlaylistApi get _api =>
      ref.read(collaborativePlaylistApiProvider);

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(collabPlaylistProvider(widget.playlistId))
        ..invalidate(playlistHistoryProvider(widget.playlistId));
      if (mounted) showFeatureSnack(context, done);
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, featureErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite(CollabPlaylist playlist) async {
    SocialFriends friends;
    try {
      friends = await ref.read(socialApiProvider).friends();
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, featureErrorText(error));
      return;
    }
    final members = playlist.members.map((member) => member.userId).toSet();
    final candidates = friends.friends
        .where((friend) => !members.contains(friend.userId))
        .toList();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<PublicProfile>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: candidates.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Пригласить можно только друзей Resonance'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final friend in candidates)
                    ListTile(
                      title: Text(friend.displayName),
                      subtitle: friend.handle == null
                          ? null
                          : Text('@${friend.handle}'),
                      onTap: () => Navigator.pop(sheetContext, friend),
                    ),
                ],
              ),
      ),
    );
    if (chosen == null) return;
    await _run(
      () => _api.setMember(
        widget.playlistId,
        chosen.userId,
        CollaboratorRole.editor,
      ),
      '${chosen.displayName} теперь редактор',
    );
  }

  Future<void> _playlistMenu(CollabPlaylist playlist, String action) async {
    switch (action) {
      case 'rename':
        final name = await showTextPrompt(
          context,
          title: 'Название плейлиста',
          action: 'Сохранить',
          initial: playlist.name,
        );
        if (name == null || name.isEmpty || !mounted) return;
        await _run(() => _api.rename(playlist.id, name), 'Переименовано');
      case 'delete' || 'leave':
        final delete = action == 'delete';
        final confirmed = await showConfirm(
          context,
          title: delete ? 'Удалить «${playlist.name}»?' : 'Выйти из плейлиста?',
          message: delete
              ? 'Плейлист пропадёт у всех участников.'
              : 'Вернуться можно только по новому приглашению.',
          action: delete ? 'Удалить' : 'Выйти',
        );
        if (!confirmed || !mounted) return;
        final me = ref.read(featureAccountIdProvider);
        try {
          if (delete) {
            await _api.delete(playlist.id);
          } else if (me != null) {
            await _api.removeMember(playlist.id, me);
          }
          ref.invalidate(collabPlaylistsProvider);
          if (mounted) context.pop();
        } on Object catch (error) {
          if (mounted) showFeatureSnack(context, featureErrorText(error));
        }
    }
  }

  Future<void> _memberMenu(PlaylistMember member, String action) async {
    if (action == 'remove') {
      final confirmed = await showConfirm(
        context,
        title: 'Убрать ${member.displayName}?',
        action: 'Убрать',
      );
      if (!confirmed || !mounted) return;
      await _run(
        () => _api.removeMember(widget.playlistId, member.userId),
        'Участник удалён',
      );
      return;
    }
    final role = CollaboratorRole.parse(action);
    await _run(
      () => _api.setMember(widget.playlistId, member.userId, role),
      '${member.displayName}: ${role.label.toLowerCase()}',
    );
  }

  Future<void> _revert(PlaylistHistoryEntry entry, String author) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Откатить правку?'),
        content: Text(
          '${entry.describe(author)}. Будет применено обратное действие.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Откатить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _api.revert(widget.playlistId, entry.id),
      'Правка отменена',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(
      featureEnabledProvider(FeatureFlag.collaborativePlaylists),
    )) {
      return const FeaturePage(
        eyebrow: 'СОВМЕСТНЫЙ ПЛЕЙЛИСТ',
        title: 'Плейлист',
        children: [FeatureUnavailableView()],
      );
    }
    final playlist = ref.watch(collabPlaylistProvider(widget.playlistId));
    final history = ref.watch(playlistHistoryProvider(widget.playlistId));
    return playlist.when(
      loading: () => const FeaturePage(
        eyebrow: 'СОВМЕСТНЫЙ ПЛЕЙЛИСТ',
        title: 'Плейлист',
        children: [LinearProgressIndicator(minHeight: 2)],
      ),
      error: (error, _) => FeaturePage(
        eyebrow: 'СОВМЕСТНЫЙ ПЛЕЙЛИСТ',
        title: 'Плейлист',
        children: [FeatureUnavailableView(error: error)],
      ),
      data: (value) {
        final names = {
          for (final member in value.members) member.userId: member.displayName,
        };
        return FeaturePage(
          eyebrow: 'СОВМЕСТНЫЙ ПЛЕЙЛИСТ',
          title: value.name,
          actions: [
            if (value.entries.isNotEmpty)
              IconButton(
                tooltip: 'Слушать',
                onPressed: () => unawaited(
                  playTrackList(ref, value.entries.map((entry) => entry.track)),
                ),
                icon: const Icon(Icons.play_circle_rounded),
              ),
            PopupMenuButton<String>(
              key: const ValueKey('collab-menu'),
              enabled: !_busy,
              onSelected: (action) => unawaited(_playlistMenu(value, action)),
              itemBuilder: (_) => [
                if (value.canEdit)
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Переименовать'),
                  ),
                if (value.isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить плейлист'),
                  )
                else
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('Выйти из плейлиста'),
                  ),
              ],
            ),
          ],
          children: [
            Row(
              children: [
                const Expanded(child: FeatureSectionTitle('Участники')),
                if (value.isOwner)
                  TextButton.icon(
                    onPressed: _busy ? null : () => unawaited(_invite(value)),
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('Пригласить друга'),
                  ),
              ],
            ),
            for (final member in value.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_rounded),
                title: Text(member.displayName),
                subtitle: Text(member.role.label),
                trailing: value.isOwner && member.role != CollaboratorRole.owner
                    ? PopupMenuButton<String>(
                        tooltip: 'Роль и доступ',
                        enabled: !_busy,
                        onSelected: (action) =>
                            unawaited(_memberMenu(member, action)),
                        itemBuilder: (_) => [
                          for (final role in const [
                            CollaboratorRole.editor,
                            CollaboratorRole.viewer,
                          ])
                            CheckedPopupMenuItem(
                              value: role.name,
                              checked: member.role == role,
                              child: Text(role.label),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Убрать из плейлиста'),
                          ),
                        ],
                      )
                    : null,
              ),
            FeatureSectionTitle('Треки · ${value.entries.length}'),
            for (final entry in value.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.track.title),
                subtitle: Text(entry.track.artist),
                trailing: value.canEdit
                    ? IconButton(
                        tooltip: 'Убрать трек',
                        onPressed: _busy
                            ? null
                            : () => unawaited(
                                _run(
                                  () => _api.removeTrack(
                                    widget.playlistId,
                                    entry.entryId,
                                  ),
                                  'Трек убран',
                                ),
                              ),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      )
                    : null,
              ),
            const FeatureSectionTitle('История правок'),
            ...history.when(
              loading: () => const [LinearProgressIndicator(minHeight: 2)],
              error: (error, _) => [FeatureUnavailableView(error: error)],
              data: (items) => items.isEmpty
                  ? const [FeatureEmpty(text: 'Правок пока не было')]
                  : [
                      for (final entry in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded),
                          title: Text(
                            entry.describe(names[entry.userId] ?? 'Участник'),
                          ),
                          subtitle: Text(formatShortDate(entry.at)),
                          trailing: value.canEdit && entry.revertible
                              ? TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => unawaited(
                                          _revert(
                                            entry,
                                            names[entry.userId] ?? 'Участник',
                                          ),
                                        ),
                                  child: const Text('Откатить'),
                                )
                              : null,
                        ),
                    ],
            ),
          ],
        );
      },
    );
  }
}

/// "Добавить в совместный плейлист" — playlists where the user may edit.
Future<List<CollabPlaylistSummary>> editableCollabPlaylists(
  WidgetRef ref,
) async {
  if (!ref.read(featureEnabledProvider(FeatureFlag.collaborativePlaylists))) {
    return const [];
  }
  try {
    final all = await ref.read(collaborativePlaylistApiProvider).list();
    return all.where((item) => item.role != CollaboratorRole.viewer).toList();
  } on Object {
    return const [];
  }
}
