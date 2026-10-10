import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/rooms/room_controller.dart';

Map<String, Object?> _track(String id) => {
  'id': id,
  'title': 'Track $id',
  'normalizedTitle': 'track $id',
  'artist': 'Artist',
  'normalizedArtist': 'artist',
  'sources': [
    {
      'provider': 'vk',
      'externalId': id,
      'externalUrl': 'https://vk.com/audio$id',
      'metadata': <String, Object?>{},
    },
  ],
};

void main() {
  test('invite links round-trip and bare codes are accepted', () {
    final link = roomInviteLink('A1B2C3', invite: 'tok_en-1');
    final parsed = parseRoomInvite(link);
    expect(parsed?.code, 'A1B2C3');
    expect(parsed?.invite, 'tok_en-1');
    expect(parseRoomInvite(' a1b2c3 ')?.code, 'A1B2C3');
    expect(parseRoomInvite('a1b2c3')?.invite, isNull);
    expect(parseRoomInvite('resonance://rooms?code=zzz'), isNull);
    expect(parseRoomInvite('hello'), isNull);
  });

  test('played tracks are deduplicated and broken entries skipped', () {
    final played = parseRoomPlayed([
      {'track': _track('vk:1'), 'playedAt': 1},
      {'track': _track('vk:1'), 'playedAt': 2},
      {'track': 'broken'},
      {'track': _track('vk:2'), 'playedAt': 3},
    ]);
    expect(played.map((track) => track.id), ['vk:1', 'vk:2']);
  });

  test('history keeps sessions with tracks for «Переслушать»', () {
    final sessions = parseRoomHistory([
      {
        'id': 's1',
        'code': 'ABCDEF',
        'startedAt': 1000,
        'tracks': [
          {'track': _track('vk:9'), 'playedAt': 1},
        ],
      },
      {'id': 's2', 'code': 'ABCDEF', 'startedAt': 2000, 'tracks': <Object>[]},
    ]);
    expect(sessions, hasLength(1));
    expect(sessions.single.tracks.single.id, 'vk:9');
  });

  test('chat parsing drops empty messages and reads roles', () {
    final chat = parseRoomChat([
      {
        'id': 'm1',
        'from': {'id': 'a', 'name': 'Аня'},
        'text': 'привет',
        'at': 5,
      },
      {'id': 'm2', 'text': ''},
    ]);
    expect(chat.single.fromName, 'Аня');
    expect(RoomRole.parse('dj'), RoomRole.dj);
    expect(RoomRole.parse('weird'), RoomRole.listener);
  });

  test('DJ can control and remove entries', () {
    const state = ListeningRoomState(
      code: 'ABCDEF',
      hostId: 'h',
      selfId: 'd',
      participants: [
        RoomParticipant(id: 'h', name: 'H', role: RoomRole.host),
        RoomParticipant(id: 'd', name: 'D', role: RoomRole.dj),
      ],
    );
    expect(state.isHost, isFalse);
    expect(state.canControl, isTrue);
  });
}
