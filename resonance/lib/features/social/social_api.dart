import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/platform/feature_api.dart';

/// Wire contract for /api/v1/social/* (docs/API-5.0.md §1). Adjust paths and
/// `fromJson` factories here; screens only use these DTOs.
abstract final class SocialPaths {
  static const profile = '/api/v1/social/profile';
  static const invite = '/api/v1/social/profile/invite';
  static const search = '/api/v1/social/users/search';
  static const friends = '/api/v1/social/friends';
  static const requests = '/api/v1/social/friends/requests';
  static const feed = '/api/v1/social/feed';
  static const blocks = '/api/v1/social/blocks';
  static const nowPlaying = '/api/v1/social/now-playing';
  static String block(String userId) => '$blocks/${_id(userId)}';
  static String _id(String id) => Uri.encodeComponent(id);
  static String accept(String userId) => '$requests/${_id(userId)}/accept';
  static String request(String userId) => '$requests/${_id(userId)}';
  static String friend(String userId) => '$friends/${_id(userId)}';
  static String compatibility(String userId) =>
      '/api/v1/social/compatibility/${_id(userId)}';
  static String blend(String userId) => '/api/v1/social/blend/${_id(userId)}';
}

final class SocialProfile {
  const SocialProfile({
    required this.userId,
    required this.displayName,
    this.handle,
    this.isPublic = false,
    this.shareListening = false,
    this.shareRooms = false,
    this.inviteCode,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    final body = json['profile'] is Map ? jsonMap(json['profile']) : json;
    return SocialProfile(
      userId: jsonString(body['userId']),
      displayName: jsonString(body['displayName'], 'Слушатель'),
      handle: jsonOptString(body['handle']),
      isPublic: jsonBool(body['isPublic']),
      shareListening: jsonBool(body['shareListening']),
      shareRooms: jsonBool(body['shareRooms']),
      inviteCode: jsonOptString(body['inviteCode']),
    );
  }

  final String userId;
  final String displayName;
  final String? handle;
  final bool isPublic;
  final bool shareListening;
  final bool shareRooms;
  final String? inviteCode;
}

enum SocialRelation { none, friends, outgoing, incoming, blocked }

final class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.displayName,
    this.handle,
    this.relation = SocialRelation.none,
  });

  factory PublicProfile.fromJson(
    Map<String, dynamic> json, {
    SocialRelation? relation,
  }) => PublicProfile(
    userId: jsonString(json['userId']),
    displayName: jsonString(json['displayName'], 'Слушатель'),
    handle: jsonOptString(json['handle']),
    relation:
        relation ??
        SocialRelation.values.firstWhere(
          (item) => item.name == json['relation'],
          orElse: () => SocialRelation.none,
        ),
  );

  final String userId;
  final String displayName;
  final String? handle;
  final SocialRelation relation;
}

final class SocialFriends {
  const SocialFriends({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.blocked = const [],
  });

  factory SocialFriends.fromJson(Map<String, dynamic> json) {
    List<PublicProfile> parse(Object? raw, SocialRelation relation) => jsonList(
      raw,
    ).map((item) => PublicProfile.fromJson(item, relation: relation)).toList();
    return SocialFriends(
      friends: parse(json['friends'], SocialRelation.friends),
      incoming: parse(json['incoming'], SocialRelation.incoming),
      outgoing: parse(json['outgoing'], SocialRelation.outgoing),
      blocked: parse(json['blocked'], SocialRelation.blocked),
    );
  }

  final List<PublicProfile> friends;
  final List<PublicProfile> incoming;
  final List<PublicProfile> outgoing;
  final List<PublicProfile> blocked;
}

final class ListenEvent {
  const ListenEvent({required this.title, required this.artist, this.at});

  factory ListenEvent.fromJson(Map<String, dynamic> json) => ListenEvent(
    title: jsonString(json['title']),
    artist: jsonString(json['artist']),
    at: jsonDate(json['at']),
  );

  final String title;
  final String artist;
  final DateTime? at;
}

final class FriendRoom {
  const FriendRoom({
    this.code,
    this.isPrivate = false,
    this.participants = 0,
    this.track,
  });

  factory FriendRoom.fromJson(Map<String, dynamic> json) => FriendRoom(
    code: jsonOptString(json['code']),
    isPrivate: jsonBool(json['isPrivate']),
    participants: jsonInt(json['participants']),
    track: json['track'] is Map
        ? ListenEvent.fromJson(jsonMap(json['track']))
        : null,
  );

  /// Null for a private room the viewer never joined.
  final String? code;
  final bool isPrivate;
  final int participants;
  final ListenEvent? track;
}

final class FeedItem {
  const FeedItem({
    required this.friend,
    this.nowPlaying,
    this.recent = const [],
    this.room,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    friend: PublicProfile.fromJson(
      jsonMap(json['friend']),
      relation: SocialRelation.friends,
    ),
    nowPlaying: json['nowPlaying'] is Map
        ? ListenEvent.fromJson(jsonMap(json['nowPlaying']))
        : null,
    recent: jsonList(json['recent']).map(ListenEvent.fromJson).toList(),
    room: json['room'] is Map
        ? FriendRoom.fromJson(jsonMap(json['room']))
        : null,
  );

  final PublicProfile friend;
  final ListenEvent? nowPlaying;
  final List<ListenEvent> recent;
  final FriendRoom? room;
}

final class SocialCompatibility {
  const SocialCompatibility({
    required this.percent,
    this.enoughData = true,
    this.sharedArtists = const [],
  });

  factory SocialCompatibility.fromJson(Map<String, dynamic> json) {
    final body = json['compatibility'] is Map
        ? jsonMap(json['compatibility'])
        : json;
    return SocialCompatibility(
      percent: jsonInt(body['percent']).clamp(0, 100),
      enoughData: jsonBool(body['enoughData'], true),
      sharedArtists: (body['sharedArtists'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final int percent;
  final bool enoughData;
  final List<String> sharedArtists;
}

final class BlendMix {
  const BlendMix({required this.title, required this.tracks});

  /// `{ title, mixes: DailyMix[] }` — all mixes are joined into one queue.
  factory BlendMix.fromJson(Map<String, dynamic> json) => BlendMix(
    title: jsonString(json['title'], 'Blend'),
    tracks: [
      for (final mix in jsonList(json['mixes'])) ...jsonTracks(mix['tracks']),
    ],
  );

  final String title;
  final List<UnifiedTrack> tracks;
}

final class SocialApi {
  const SocialApi(this._transport);

  final FeatureTransport _transport;

  Future<SocialProfile> profile() async => SocialProfile.fromJson(
    await _transport.request('GET', SocialPaths.profile),
  );

  /// [handle] — `''` clears the handle (sent as `null`).
  Future<SocialProfile> updateProfile({
    String? handle,
    String? displayName,
    bool? isPublic,
    bool? shareListening,
    bool? shareRooms,
  }) async => SocialProfile.fromJson(
    await _transport.request(
      'PATCH',
      SocialPaths.profile,
      body: {
        'displayName': ?displayName,
        if (handle != null) 'handle': handle.isEmpty ? null : handle,
        'isPublic': ?isPublic,
        'shareListening': ?shareListening,
        'shareRooms': ?shareRooms,
      },
    ),
  );

  Future<SocialProfile> newInvite() async => SocialProfile.fromJson(
    await _transport.request('POST', SocialPaths.invite),
  );

  Future<SocialFriends> friends() async => SocialFriends.fromJson(
    await _transport.request('GET', SocialPaths.friends),
  );

  Future<List<PublicProfile>> search(String query) async => jsonList(
    (await _transport.request(
      'GET',
      SocialPaths.search,
      query: {'q': query.trim()},
    ))['users'],
  ).map(PublicProfile.fromJson).toList();

  Future<void> requestFriend({
    String? userId,
    String? handle,
    String? inviteCode,
  }) => _transport.request(
    'POST',
    SocialPaths.requests,
    body: {'userId': ?userId, 'handle': ?handle, 'inviteCode': ?inviteCode},
  );

  Future<void> accept(String userId) =>
      _transport.request('POST', SocialPaths.accept(userId));

  Future<void> cancelRequest(String userId) =>
      _transport.request('DELETE', SocialPaths.request(userId));

  Future<void> removeFriend(String userId) =>
      _transport.request('DELETE', SocialPaths.friend(userId));

  Future<void> block(String userId) =>
      _transport.request('POST', SocialPaths.blocks, body: {'userId': userId});

  Future<void> unblock(String userId) =>
      _transport.request('DELETE', SocialPaths.block(userId));

  Future<List<FeedItem>> feed() async => jsonList(
    (await _transport.request('GET', SocialPaths.feed))['items'],
  ).map(FeedItem.fromJson).toList();

  Future<SocialCompatibility> compatibility(String userId) async =>
      SocialCompatibility.fromJson(
        await _transport.request('GET', SocialPaths.compatibility(userId)),
      );

  Future<BlendMix> blend(
    String userId, {
    List<String>? enabledProviders,
  }) async => BlendMix.fromJson(
    await _transport.request(
      'POST',
      SocialPaths.blend(userId),
      body: {
        'enabledProviders': ?enabledProviders,
        'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      },
      providerTokens: true,
    ),
  );
}

final socialApiProvider = Provider<SocialApi>(
  (ref) => SocialApi(ref.watch(featureTransportProvider)),
);

final socialProfileProvider = FutureProvider.autoDispose<SocialProfile>(
  (ref) => ref.watch(socialApiProvider).profile(),
);

final socialFriendsProvider = FutureProvider.autoDispose<SocialFriends>(
  (ref) => ref.watch(socialApiProvider).friends(),
);

final socialFeedProvider = FutureProvider.autoDispose<List<FeedItem>>(
  (ref) => ref.watch(socialApiProvider).feed(),
);

final socialCompatibilityProvider = FutureProvider.autoDispose
    .family<SocialCompatibility, String>(
      (ref, userId) => ref.watch(socialApiProvider).compatibility(userId),
    );
