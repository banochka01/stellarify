import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/features/rooms/room_queue_panel.dart';

UnifiedTrack _track(String id) => UnifiedTrack(
  id: id,
  title: 'Track $id',
  normalizedTitle: 'track $id',
  artist: 'Resonance',
  normalizedArtist: 'resonance',
  preferredProvider: MusicProvider.vk,
  sources: [
    TrackSource(
      provider: MusicProvider.vk,
      externalId: id,
      externalUrl: Uri.parse('https://example.invalid/vk/$id'),
    ),
  ],
);

void main() {
  test('room queue survives a server round trip and skips broken entries', () {
    // Сокет передаёт очередь как JSON — повторяем этот путь целиком.
    final wire = jsonDecode(
      jsonEncode([
        {
          'id': 'a',
          'track': _track('vk:1').toJson(),
          'addedBy': {'id': 'guest', 'name': 'lena'},
          'votes': 2,
          'voters': ['guest', 'host'],
        },
        {'id': 'broken', 'track': 'not a track'},
        {'track': _track('vk:2').toJson()},
      ]),
    );
    final queue = parseRoomQueue(wire);

    expect(queue, hasLength(1));
    expect(queue.single.track.id, 'vk:1');
    expect(queue.single.addedByName, 'lena');
    expect(queue.single.votes, 2);

    final asHost = ListeningRoomState(
      code: 'ABC123',
      hostId: 'host',
      selfId: 'host',
      queue: queue,
    );
    expect(asHost.isHost, isTrue);
    expect(asHost.votedFor(queue.single), isTrue);
    expect(asHost.canRemove(queue.single), isTrue);

    final asOutsider = ListeningRoomState(
      code: 'ABC123',
      hostId: 'host',
      selfId: 'other',
      queue: queue,
    );
    expect(asOutsider.isHost, isFalse);
    expect(asOutsider.votedFor(queue.single), isFalse);
    expect(asOutsider.canRemove(queue.single), isFalse);
  });

  test('listener count uses Russian plural forms', () {
    expect(listenersLabel(1), '1 слушатель');
    expect(listenersLabel(4), '4 слушателя');
    expect(listenersLabel(11), '11 слушателей');
    expect(listenersLabel(22), '22 слушателя');
    expect(listenersLabel(25), '25 слушателей');
  });
}
