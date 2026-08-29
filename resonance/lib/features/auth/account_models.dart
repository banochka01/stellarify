import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/unified_track.dart';

final class AccountUser {
  const AccountUser({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
    id: json['id'] as String,
    email: json['email'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
  );

  final String id;
  final String email;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
  };
}

final class AccountSession {
  const AccountSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
    user: AccountUser.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessExpiresAt: DateTime.parse(json['accessExpiresAt'] as String).toUtc(),
    refreshExpiresAt: DateTime.parse(
      json['refreshExpiresAt'] as String,
    ).toUtc(),
  );

  final AccountUser user;
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
}

final class RemoteLibrarySnapshot {
  const RemoteLibrarySnapshot({
    required this.favorites,
    required this.playlists,
  });

  factory RemoteLibrarySnapshot.fromJson(Map<String, dynamic> json) {
    final favorites = (json['favorites'] as List<dynamic>? ?? const [])
        .map((item) => UnifiedTrack.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final playlists = (json['playlists'] as List<dynamic>? ?? const [])
        .map((item) {
          final value = item as Map<String, dynamic>;
          final tracks = (value['tracks'] as List<dynamic>? ?? const [])
              .map(
                (entry) => UnifiedTrack.fromJson(
                  (entry as Map<String, dynamic>)['track']
                      as Map<String, dynamic>,
                ),
              )
              .toList(growable: false);
          return LocalPlaylistSnapshot(
            id: value['id'] as String,
            name: value['name'] as String,
            createdAt: DateTime.parse(value['createdAt'] as String).toUtc(),
            updatedAt: DateTime.parse(value['updatedAt'] as String).toUtc(),
            tracks: tracks,
          );
        })
        .toList(growable: false);
    return RemoteLibrarySnapshot(favorites: favorites, playlists: playlists);
  }

  final List<UnifiedTrack> favorites;
  final List<LocalPlaylistSnapshot> playlists;

  LocalLibrarySnapshot toLocal() =>
      LocalLibrarySnapshot(favorites: favorites, playlists: playlists);
}

final class AccountApiException implements Exception {
  const AccountApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
