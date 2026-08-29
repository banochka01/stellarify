// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StoredTracksTable extends StoredTracks
    with TableInfo<$StoredTracksTable, StoredTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedTitleMeta = const VerificationMeta(
    'normalizedTitle',
  );
  @override
  late final GeneratedColumn<String> normalizedTitle = GeneratedColumn<String>(
    'normalized_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedArtistMeta = const VerificationMeta(
    'normalizedArtist',
  );
  @override
  late final GeneratedColumn<String> normalizedArtist = GeneratedColumn<String>(
    'normalized_artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MusicProvider?, String>
  preferredProvider =
      GeneratedColumn<String>(
        'preferred_provider',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<MusicProvider?>(
        $StoredTracksTable.$converterpreferredProvidern,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    normalizedTitle,
    artist,
    normalizedArtist,
    album,
    durationMs,
    artworkUrl,
    preferredProvider,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('normalized_title')) {
      context.handle(
        _normalizedTitleMeta,
        normalizedTitle.isAcceptableOrUnknown(
          data['normalized_title']!,
          _normalizedTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedTitleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('normalized_artist')) {
      context.handle(
        _normalizedArtistMeta,
        normalizedArtist.isAcceptableOrUnknown(
          data['normalized_artist']!,
          _normalizedArtistMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedArtistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      normalizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      normalizedArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      preferredProvider: $StoredTracksTable.$converterpreferredProvidern
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}preferred_provider'],
            ),
          ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StoredTracksTable createAlias(String alias) {
    return $StoredTracksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MusicProvider, String, String>
  $converterpreferredProvider = const EnumNameConverter<MusicProvider>(
    MusicProvider.values,
  );
  static JsonTypeConverter2<MusicProvider?, String?, String?>
  $converterpreferredProvidern = JsonTypeConverter2.asNullable(
    $converterpreferredProvider,
  );
}

class StoredTrack extends DataClass implements Insertable<StoredTrack> {
  final String id;
  final String title;
  final String normalizedTitle;
  final String artist;
  final String normalizedArtist;
  final String? album;
  final int? durationMs;
  final String? artworkUrl;
  final MusicProvider? preferredProvider;
  final DateTime updatedAt;
  const StoredTrack({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    required this.artist,
    required this.normalizedArtist,
    this.album,
    this.durationMs,
    this.artworkUrl,
    this.preferredProvider,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['normalized_title'] = Variable<String>(normalizedTitle);
    map['artist'] = Variable<String>(artist);
    map['normalized_artist'] = Variable<String>(normalizedArtist);
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || preferredProvider != null) {
      map['preferred_provider'] = Variable<String>(
        $StoredTracksTable.$converterpreferredProvidern.toSql(
          preferredProvider,
        ),
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredTracksCompanion toCompanion(bool nullToAbsent) {
    return StoredTracksCompanion(
      id: Value(id),
      title: Value(title),
      normalizedTitle: Value(normalizedTitle),
      artist: Value(artist),
      normalizedArtist: Value(normalizedArtist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      preferredProvider: preferredProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredProvider),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredTrack(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      normalizedTitle: serializer.fromJson<String>(json['normalizedTitle']),
      artist: serializer.fromJson<String>(json['artist']),
      normalizedArtist: serializer.fromJson<String>(json['normalizedArtist']),
      album: serializer.fromJson<String?>(json['album']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      preferredProvider: $StoredTracksTable.$converterpreferredProvidern
          .fromJson(serializer.fromJson<String?>(json['preferredProvider'])),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'normalizedTitle': serializer.toJson<String>(normalizedTitle),
      'artist': serializer.toJson<String>(artist),
      'normalizedArtist': serializer.toJson<String>(normalizedArtist),
      'album': serializer.toJson<String?>(album),
      'durationMs': serializer.toJson<int?>(durationMs),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'preferredProvider': serializer.toJson<String?>(
        $StoredTracksTable.$converterpreferredProvidern.toJson(
          preferredProvider,
        ),
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredTrack copyWith({
    String? id,
    String? title,
    String? normalizedTitle,
    String? artist,
    String? normalizedArtist,
    Value<String?> album = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    Value<MusicProvider?> preferredProvider = const Value.absent(),
    DateTime? updatedAt,
  }) => StoredTrack(
    id: id ?? this.id,
    title: title ?? this.title,
    normalizedTitle: normalizedTitle ?? this.normalizedTitle,
    artist: artist ?? this.artist,
    normalizedArtist: normalizedArtist ?? this.normalizedArtist,
    album: album.present ? album.value : this.album,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    preferredProvider: preferredProvider.present
        ? preferredProvider.value
        : this.preferredProvider,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredTrack copyWithCompanion(StoredTracksCompanion data) {
    return StoredTrack(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      normalizedTitle: data.normalizedTitle.present
          ? data.normalizedTitle.value
          : this.normalizedTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      normalizedArtist: data.normalizedArtist.present
          ? data.normalizedArtist.value
          : this.normalizedArtist,
      album: data.album.present ? data.album.value : this.album,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      preferredProvider: data.preferredProvider.present
          ? data.preferredProvider.value
          : this.preferredProvider,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredTrack(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('artist: $artist, ')
          ..write('normalizedArtist: $normalizedArtist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('preferredProvider: $preferredProvider, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    normalizedTitle,
    artist,
    normalizedArtist,
    album,
    durationMs,
    artworkUrl,
    preferredProvider,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredTrack &&
          other.id == this.id &&
          other.title == this.title &&
          other.normalizedTitle == this.normalizedTitle &&
          other.artist == this.artist &&
          other.normalizedArtist == this.normalizedArtist &&
          other.album == this.album &&
          other.durationMs == this.durationMs &&
          other.artworkUrl == this.artworkUrl &&
          other.preferredProvider == this.preferredProvider &&
          other.updatedAt == this.updatedAt);
}

class StoredTracksCompanion extends UpdateCompanion<StoredTrack> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> normalizedTitle;
  final Value<String> artist;
  final Value<String> normalizedArtist;
  final Value<String?> album;
  final Value<int?> durationMs;
  final Value<String?> artworkUrl;
  final Value<MusicProvider?> preferredProvider;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredTracksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.normalizedTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.normalizedArtist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.preferredProvider = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredTracksCompanion.insert({
    required String id,
    required String title,
    required String normalizedTitle,
    required String artist,
    required String normalizedArtist,
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.preferredProvider = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       normalizedTitle = Value(normalizedTitle),
       artist = Value(artist),
       normalizedArtist = Value(normalizedArtist);
  static Insertable<StoredTrack> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? normalizedTitle,
    Expression<String>? artist,
    Expression<String>? normalizedArtist,
    Expression<String>? album,
    Expression<int>? durationMs,
    Expression<String>? artworkUrl,
    Expression<String>? preferredProvider,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (normalizedTitle != null) 'normalized_title': normalizedTitle,
      if (artist != null) 'artist': artist,
      if (normalizedArtist != null) 'normalized_artist': normalizedArtist,
      if (album != null) 'album': album,
      if (durationMs != null) 'duration_ms': durationMs,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (preferredProvider != null) 'preferred_provider': preferredProvider,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? normalizedTitle,
    Value<String>? artist,
    Value<String>? normalizedArtist,
    Value<String?>? album,
    Value<int?>? durationMs,
    Value<String?>? artworkUrl,
    Value<MusicProvider?>? preferredProvider,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredTracksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      artist: artist ?? this.artist,
      normalizedArtist: normalizedArtist ?? this.normalizedArtist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (normalizedTitle.present) {
      map['normalized_title'] = Variable<String>(normalizedTitle.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (normalizedArtist.present) {
      map['normalized_artist'] = Variable<String>(normalizedArtist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (preferredProvider.present) {
      map['preferred_provider'] = Variable<String>(
        $StoredTracksTable.$converterpreferredProvidern.toSql(
          preferredProvider.value,
        ),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredTracksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('artist: $artist, ')
          ..write('normalizedArtist: $normalizedArtist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('preferredProvider: $preferredProvider, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredTrackSourcesTable extends StoredTrackSources
    with TableInfo<$StoredTrackSourcesTable, StoredTrackSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredTrackSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stored_tracks (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MusicProvider, String> provider =
      GeneratedColumn<String>(
        'provider',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MusicProvider>(
        $StoredTrackSourcesTable.$converterprovider,
      );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalUrlMeta = const VerificationMeta(
    'externalUrl',
  );
  @override
  late final GeneratedColumn<String> externalUrl = GeneratedColumn<String>(
    'external_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    trackId,
    provider,
    externalId,
    externalUrl,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_track_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredTrackSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('external_url')) {
      context.handle(
        _externalUrlMeta,
        externalUrl.isAcceptableOrUnknown(
          data['external_url']!,
          _externalUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_externalUrlMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {provider, externalId},
  ];
  @override
  StoredTrackSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredTrackSource(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      provider: $StoredTrackSourcesTable.$converterprovider.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}provider'],
        )!,
      ),
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      externalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_url'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
    );
  }

  @override
  $StoredTrackSourcesTable createAlias(String alias) {
    return $StoredTrackSourcesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MusicProvider, String, String> $converterprovider =
      const EnumNameConverter<MusicProvider>(MusicProvider.values);
}

class StoredTrackSource extends DataClass
    implements Insertable<StoredTrackSource> {
  final int rowId;
  final String trackId;
  final MusicProvider provider;
  final String externalId;
  final String externalUrl;
  final String metadataJson;
  const StoredTrackSource({
    required this.rowId,
    required this.trackId,
    required this.provider,
    required this.externalId,
    required this.externalUrl,
    required this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    map['track_id'] = Variable<String>(trackId);
    {
      map['provider'] = Variable<String>(
        $StoredTrackSourcesTable.$converterprovider.toSql(provider),
      );
    }
    map['external_id'] = Variable<String>(externalId);
    map['external_url'] = Variable<String>(externalUrl);
    map['metadata_json'] = Variable<String>(metadataJson);
    return map;
  }

  StoredTrackSourcesCompanion toCompanion(bool nullToAbsent) {
    return StoredTrackSourcesCompanion(
      rowId: Value(rowId),
      trackId: Value(trackId),
      provider: Value(provider),
      externalId: Value(externalId),
      externalUrl: Value(externalUrl),
      metadataJson: Value(metadataJson),
    );
  }

  factory StoredTrackSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredTrackSource(
      rowId: serializer.fromJson<int>(json['rowId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      provider: $StoredTrackSourcesTable.$converterprovider.fromJson(
        serializer.fromJson<String>(json['provider']),
      ),
      externalId: serializer.fromJson<String>(json['externalId']),
      externalUrl: serializer.fromJson<String>(json['externalUrl']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'trackId': serializer.toJson<String>(trackId),
      'provider': serializer.toJson<String>(
        $StoredTrackSourcesTable.$converterprovider.toJson(provider),
      ),
      'externalId': serializer.toJson<String>(externalId),
      'externalUrl': serializer.toJson<String>(externalUrl),
      'metadataJson': serializer.toJson<String>(metadataJson),
    };
  }

  StoredTrackSource copyWith({
    int? rowId,
    String? trackId,
    MusicProvider? provider,
    String? externalId,
    String? externalUrl,
    String? metadataJson,
  }) => StoredTrackSource(
    rowId: rowId ?? this.rowId,
    trackId: trackId ?? this.trackId,
    provider: provider ?? this.provider,
    externalId: externalId ?? this.externalId,
    externalUrl: externalUrl ?? this.externalUrl,
    metadataJson: metadataJson ?? this.metadataJson,
  );
  StoredTrackSource copyWithCompanion(StoredTrackSourcesCompanion data) {
    return StoredTrackSource(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      provider: data.provider.present ? data.provider.value : this.provider,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      externalUrl: data.externalUrl.present
          ? data.externalUrl.value
          : this.externalUrl,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredTrackSource(')
          ..write('rowId: $rowId, ')
          ..write('trackId: $trackId, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('externalUrl: $externalUrl, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rowId,
    trackId,
    provider,
    externalId,
    externalUrl,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredTrackSource &&
          other.rowId == this.rowId &&
          other.trackId == this.trackId &&
          other.provider == this.provider &&
          other.externalId == this.externalId &&
          other.externalUrl == this.externalUrl &&
          other.metadataJson == this.metadataJson);
}

class StoredTrackSourcesCompanion extends UpdateCompanion<StoredTrackSource> {
  final Value<int> rowId;
  final Value<String> trackId;
  final Value<MusicProvider> provider;
  final Value<String> externalId;
  final Value<String> externalUrl;
  final Value<String> metadataJson;
  const StoredTrackSourcesCompanion({
    this.rowId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalId = const Value.absent(),
    this.externalUrl = const Value.absent(),
    this.metadataJson = const Value.absent(),
  });
  StoredTrackSourcesCompanion.insert({
    this.rowId = const Value.absent(),
    required String trackId,
    required MusicProvider provider,
    required String externalId,
    required String externalUrl,
    this.metadataJson = const Value.absent(),
  }) : trackId = Value(trackId),
       provider = Value(provider),
       externalId = Value(externalId),
       externalUrl = Value(externalUrl);
  static Insertable<StoredTrackSource> custom({
    Expression<int>? rowId,
    Expression<String>? trackId,
    Expression<String>? provider,
    Expression<String>? externalId,
    Expression<String>? externalUrl,
    Expression<String>? metadataJson,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (trackId != null) 'track_id': trackId,
      if (provider != null) 'provider': provider,
      if (externalId != null) 'external_id': externalId,
      if (externalUrl != null) 'external_url': externalUrl,
      if (metadataJson != null) 'metadata_json': metadataJson,
    });
  }

  StoredTrackSourcesCompanion copyWith({
    Value<int>? rowId,
    Value<String>? trackId,
    Value<MusicProvider>? provider,
    Value<String>? externalId,
    Value<String>? externalUrl,
    Value<String>? metadataJson,
  }) {
    return StoredTrackSourcesCompanion(
      rowId: rowId ?? this.rowId,
      trackId: trackId ?? this.trackId,
      provider: provider ?? this.provider,
      externalId: externalId ?? this.externalId,
      externalUrl: externalUrl ?? this.externalUrl,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(
        $StoredTrackSourcesTable.$converterprovider.toSql(provider.value),
      );
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (externalUrl.present) {
      map['external_url'] = Variable<String>(externalUrl.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredTrackSourcesCompanion(')
          ..write('rowId: $rowId, ')
          ..write('trackId: $trackId, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('externalUrl: $externalUrl, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaylistsTable extends LocalPlaylists
    with TableInfo<$LocalPlaylistsTable, LocalPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPlaylist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaylist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalPlaylistsTable createAlias(String alias) {
    return $LocalPlaylistsTable(attachedDatabase, alias);
  }
}

class LocalPlaylist extends DataClass implements Insertable<LocalPlaylist> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPlaylist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaylist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPlaylist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalPlaylist(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalPlaylist copyWithCompanion(LocalPlaylistsCompanion data) {
    return LocalPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalPlaylistsCompanion extends UpdateCompanion<LocalPlaylist> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlaylistsCompanion.insert({
    required String id,
    required String name,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<LocalPlaylist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaylistTracksTable extends LocalPlaylistTracks
    with TableInfo<$LocalPlaylistTracksTable, LocalPlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stored_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    trackId,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, trackId};
  @override
  LocalPlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaylistTrack(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LocalPlaylistTracksTable createAlias(String alias) {
    return $LocalPlaylistTracksTable(attachedDatabase, alias);
  }
}

class LocalPlaylistTrack extends DataClass
    implements Insertable<LocalPlaylistTrack> {
  final String playlistId;
  final String trackId;
  final int position;
  final DateTime addedAt;
  const LocalPlaylistTrack({
    required this.playlistId,
    required this.trackId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['track_id'] = Variable<String>(trackId);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LocalPlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaylistTracksCompanion(
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory LocalPlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaylistTrack(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'trackId': serializer.toJson<String>(trackId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LocalPlaylistTrack copyWith({
    String? playlistId,
    String? trackId,
    int? position,
    DateTime? addedAt,
  }) => LocalPlaylistTrack(
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  LocalPlaylistTrack copyWithCompanion(LocalPlaylistTracksCompanion data) {
    return LocalPlaylistTrack(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, trackId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaylistTrack &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class LocalPlaylistTracksCompanion extends UpdateCompanion<LocalPlaylistTrack> {
  final Value<String> playlistId;
  final Value<String> trackId;
  final Value<int> position;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const LocalPlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlaylistTracksCompanion.insert({
    required String playlistId,
    required String trackId,
    required int position,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       position = Value(position);
  static Insertable<LocalPlaylistTrack> custom({
    Expression<String>? playlistId,
    Expression<String>? trackId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlaylistTracksCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? trackId,
    Value<int>? position,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return LocalPlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteTracksTable extends FavoriteTracks
    with TableInfo<$FavoriteTracksTable, FavoriteTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stored_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  FavoriteTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteTrack(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoriteTracksTable createAlias(String alias) {
    return $FavoriteTracksTable(attachedDatabase, alias);
  }
}

class FavoriteTrack extends DataClass implements Insertable<FavoriteTrack> {
  final String trackId;
  final DateTime addedAt;
  const FavoriteTrack({required this.trackId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoriteTracksCompanion toCompanion(bool nullToAbsent) {
    return FavoriteTracksCompanion(
      trackId: Value(trackId),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteTrack(
      trackId: serializer.fromJson<String>(json['trackId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteTrack copyWith({String? trackId, DateTime? addedAt}) => FavoriteTrack(
    trackId: trackId ?? this.trackId,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoriteTrack copyWithCompanion(FavoriteTracksCompanion data) {
    return FavoriteTrack(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTrack(')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteTrack &&
          other.trackId == this.trackId &&
          other.addedAt == this.addedAt);
}

class FavoriteTracksCompanion extends UpdateCompanion<FavoriteTrack> {
  final Value<String> trackId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoriteTracksCompanion({
    this.trackId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteTracksCompanion.insert({
    required String trackId,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId);
  static Insertable<FavoriteTrack> custom({
    Expression<String>? trackId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteTracksCompanion copyWith({
    Value<String>? trackId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoriteTracksCompanion(
      trackId: trackId ?? this.trackId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTracksCompanion(')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListeningHistoryEntriesTable extends ListeningHistoryEntries
    with TableInfo<$ListeningHistoryEntriesTable, ListeningHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListeningHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stored_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, trackId, playedAt, positionMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listening_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListeningHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListeningHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListeningHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
    );
  }

  @override
  $ListeningHistoryEntriesTable createAlias(String alias) {
    return $ListeningHistoryEntriesTable(attachedDatabase, alias);
  }
}

class ListeningHistoryEntry extends DataClass
    implements Insertable<ListeningHistoryEntry> {
  final int id;
  final String trackId;
  final DateTime playedAt;
  final int positionMs;
  const ListeningHistoryEntry({
    required this.id,
    required this.trackId,
    required this.playedAt,
    required this.positionMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<String>(trackId);
    map['played_at'] = Variable<DateTime>(playedAt);
    map['position_ms'] = Variable<int>(positionMs);
    return map;
  }

  ListeningHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return ListeningHistoryEntriesCompanion(
      id: Value(id),
      trackId: Value(trackId),
      playedAt: Value(playedAt),
      positionMs: Value(positionMs),
    );
  }

  factory ListeningHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListeningHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<String>(json['trackId']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<String>(trackId),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'positionMs': serializer.toJson<int>(positionMs),
    };
  }

  ListeningHistoryEntry copyWith({
    int? id,
    String? trackId,
    DateTime? playedAt,
    int? positionMs,
  }) => ListeningHistoryEntry(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    playedAt: playedAt ?? this.playedAt,
    positionMs: positionMs ?? this.positionMs,
  );
  ListeningHistoryEntry copyWithCompanion(
    ListeningHistoryEntriesCompanion data,
  ) {
    return ListeningHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListeningHistoryEntry(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackId, playedAt, positionMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListeningHistoryEntry &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.playedAt == this.playedAt &&
          other.positionMs == this.positionMs);
}

class ListeningHistoryEntriesCompanion
    extends UpdateCompanion<ListeningHistoryEntry> {
  final Value<int> id;
  final Value<String> trackId;
  final Value<DateTime> playedAt;
  final Value<int> positionMs;
  const ListeningHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.positionMs = const Value.absent(),
  });
  ListeningHistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String trackId,
    this.playedAt = const Value.absent(),
    this.positionMs = const Value.absent(),
  }) : trackId = Value(trackId);
  static Insertable<ListeningHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? trackId,
    Expression<DateTime>? playedAt,
    Expression<int>? positionMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (playedAt != null) 'played_at': playedAt,
      if (positionMs != null) 'position_ms': positionMs,
    });
  }

  ListeningHistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? trackId,
    Value<DateTime>? playedAt,
    Value<int>? positionMs,
  }) {
    return ListeningHistoryEntriesCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      playedAt: playedAt ?? this.playedAt,
      positionMs: positionMs ?? this.positionMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListeningHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('positionMs: $positionMs')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryEntriesTable extends SearchHistoryEntries
    with TableInfo<$SearchHistoryEntriesTable, SearchHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, query, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryEntriesTable createAlias(String alias) {
    return $SearchHistoryEntriesTable(attachedDatabase, alias);
  }
}

class SearchHistoryEntry extends DataClass
    implements Insertable<SearchHistoryEntry> {
  final int id;
  final String query;
  final DateTime searchedAt;
  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query'] = Variable<String>(query);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryEntriesCompanion(
      id: Value(id),
      query: Value(query),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'query': serializer.toJson<String>(query),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryEntry copyWith({int? id, String? query, DateTime? searchedAt}) =>
      SearchHistoryEntry(
        id: id ?? this.id,
        query: query ?? this.query,
        searchedAt: searchedAt ?? this.searchedAt,
      );
  SearchHistoryEntry copyWithCompanion(SearchHistoryEntriesCompanion data) {
    return SearchHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntry(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, query, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryEntry &&
          other.id == this.id &&
          other.query == this.query &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryEntriesCompanion
    extends UpdateCompanion<SearchHistoryEntry> {
  final Value<int> id;
  final Value<String> query;
  final Value<DateTime> searchedAt;
  const SearchHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  SearchHistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String query,
    this.searchedAt = const Value.absent(),
  }) : query = Value(query);
  static Insertable<SearchHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? query,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  SearchHistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? query,
    Value<DateTime>? searchedAt,
  }) {
    return SearchHistoryEntriesCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

class $ProviderPreferencesTable extends ProviderPreferences
    with TableInfo<$ProviderPreferencesTable, ProviderPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderPreferencesTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<MusicProvider, String> provider =
      GeneratedColumn<String>(
        'provider',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MusicProvider>(
        $ProviderPreferencesTable.$converterprovider,
      );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _fallbackPriorityMeta = const VerificationMeta(
    'fallbackPriority',
  );
  @override
  late final GeneratedColumn<int> fallbackPriority = GeneratedColumn<int>(
    'fallback_priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AudioQuality, String> quality =
      GeneratedColumn<String>(
        'quality',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(AudioQuality.high.name),
      ).withConverter<AudioQuality>(
        $ProviderPreferencesTable.$converterquality,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    provider,
    enabled,
    fallbackPriority,
    quality,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('fallback_priority')) {
      context.handle(
        _fallbackPriorityMeta,
        fallbackPriority.isAcceptableOrUnknown(
          data['fallback_priority']!,
          _fallbackPriorityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fallbackPriorityMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider};
  @override
  ProviderPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderPreference(
      provider: $ProviderPreferencesTable.$converterprovider.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}provider'],
        )!,
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      fallbackPriority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fallback_priority'],
      )!,
      quality: $ProviderPreferencesTable.$converterquality.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}quality'],
        )!,
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProviderPreferencesTable createAlias(String alias) {
    return $ProviderPreferencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MusicProvider, String, String> $converterprovider =
      const EnumNameConverter<MusicProvider>(MusicProvider.values);
  static JsonTypeConverter2<AudioQuality, String, String> $converterquality =
      const EnumNameConverter<AudioQuality>(AudioQuality.values);
}

class ProviderPreference extends DataClass
    implements Insertable<ProviderPreference> {
  final MusicProvider provider;
  final bool enabled;
  final int fallbackPriority;
  final AudioQuality quality;
  final DateTime updatedAt;
  const ProviderPreference({
    required this.provider,
    required this.enabled,
    required this.fallbackPriority,
    required this.quality,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['provider'] = Variable<String>(
        $ProviderPreferencesTable.$converterprovider.toSql(provider),
      );
    }
    map['enabled'] = Variable<bool>(enabled);
    map['fallback_priority'] = Variable<int>(fallbackPriority);
    {
      map['quality'] = Variable<String>(
        $ProviderPreferencesTable.$converterquality.toSql(quality),
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProviderPreferencesCompanion toCompanion(bool nullToAbsent) {
    return ProviderPreferencesCompanion(
      provider: Value(provider),
      enabled: Value(enabled),
      fallbackPriority: Value(fallbackPriority),
      quality: Value(quality),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderPreference(
      provider: $ProviderPreferencesTable.$converterprovider.fromJson(
        serializer.fromJson<String>(json['provider']),
      ),
      enabled: serializer.fromJson<bool>(json['enabled']),
      fallbackPriority: serializer.fromJson<int>(json['fallbackPriority']),
      quality: $ProviderPreferencesTable.$converterquality.fromJson(
        serializer.fromJson<String>(json['quality']),
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(
        $ProviderPreferencesTable.$converterprovider.toJson(provider),
      ),
      'enabled': serializer.toJson<bool>(enabled),
      'fallbackPriority': serializer.toJson<int>(fallbackPriority),
      'quality': serializer.toJson<String>(
        $ProviderPreferencesTable.$converterquality.toJson(quality),
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderPreference copyWith({
    MusicProvider? provider,
    bool? enabled,
    int? fallbackPriority,
    AudioQuality? quality,
    DateTime? updatedAt,
  }) => ProviderPreference(
    provider: provider ?? this.provider,
    enabled: enabled ?? this.enabled,
    fallbackPriority: fallbackPriority ?? this.fallbackPriority,
    quality: quality ?? this.quality,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderPreference copyWithCompanion(ProviderPreferencesCompanion data) {
    return ProviderPreference(
      provider: data.provider.present ? data.provider.value : this.provider,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      fallbackPriority: data.fallbackPriority.present
          ? data.fallbackPriority.value
          : this.fallbackPriority,
      quality: data.quality.present ? data.quality.value : this.quality,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderPreference(')
          ..write('provider: $provider, ')
          ..write('enabled: $enabled, ')
          ..write('fallbackPriority: $fallbackPriority, ')
          ..write('quality: $quality, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(provider, enabled, fallbackPriority, quality, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderPreference &&
          other.provider == this.provider &&
          other.enabled == this.enabled &&
          other.fallbackPriority == this.fallbackPriority &&
          other.quality == this.quality &&
          other.updatedAt == this.updatedAt);
}

class ProviderPreferencesCompanion extends UpdateCompanion<ProviderPreference> {
  final Value<MusicProvider> provider;
  final Value<bool> enabled;
  final Value<int> fallbackPriority;
  final Value<AudioQuality> quality;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderPreferencesCompanion({
    this.provider = const Value.absent(),
    this.enabled = const Value.absent(),
    this.fallbackPriority = const Value.absent(),
    this.quality = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderPreferencesCompanion.insert({
    required MusicProvider provider,
    this.enabled = const Value.absent(),
    required int fallbackPriority,
    this.quality = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider),
       fallbackPriority = Value(fallbackPriority);
  static Insertable<ProviderPreference> custom({
    Expression<String>? provider,
    Expression<bool>? enabled,
    Expression<int>? fallbackPriority,
    Expression<String>? quality,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (enabled != null) 'enabled': enabled,
      if (fallbackPriority != null) 'fallback_priority': fallbackPriority,
      if (quality != null) 'quality': quality,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderPreferencesCompanion copyWith({
    Value<MusicProvider>? provider,
    Value<bool>? enabled,
    Value<int>? fallbackPriority,
    Value<AudioQuality>? quality,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderPreferencesCompanion(
      provider: provider ?? this.provider,
      enabled: enabled ?? this.enabled,
      fallbackPriority: fallbackPriority ?? this.fallbackPriority,
      quality: quality ?? this.quality,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(
        $ProviderPreferencesTable.$converterprovider.toSql(provider.value),
      );
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (fallbackPriority.present) {
      map['fallback_priority'] = Variable<int>(fallbackPriority.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(
        $ProviderPreferencesTable.$converterquality.toSql(quality.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderPreferencesCompanion(')
          ..write('provider: $provider, ')
          ..write('enabled: $enabled, ')
          ..write('fallbackPriority: $fallbackPriority, ')
          ..write('quality: $quality, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackQueueEntriesTable extends PlaybackQueueEntries
    with TableInfo<$PlaybackQueueEntriesTable, PlaybackQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stored_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [position, trackId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {position};
  @override
  PlaybackQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueueEntry(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $PlaybackQueueEntriesTable createAlias(String alias) {
    return $PlaybackQueueEntriesTable(attachedDatabase, alias);
  }
}

class PlaybackQueueEntry extends DataClass
    implements Insertable<PlaybackQueueEntry> {
  final int position;
  final String trackId;
  final DateTime addedAt;
  const PlaybackQueueEntry({
    required this.position,
    required this.trackId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['track_id'] = Variable<String>(trackId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  PlaybackQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackQueueEntriesCompanion(
      position: Value(position),
      trackId: Value(trackId),
      addedAt: Value(addedAt),
    );
  }

  factory PlaybackQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueueEntry(
      position: serializer.fromJson<int>(json['position']),
      trackId: serializer.fromJson<String>(json['trackId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'trackId': serializer.toJson<String>(trackId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  PlaybackQueueEntry copyWith({
    int? position,
    String? trackId,
    DateTime? addedAt,
  }) => PlaybackQueueEntry(
    position: position ?? this.position,
    trackId: trackId ?? this.trackId,
    addedAt: addedAt ?? this.addedAt,
  );
  PlaybackQueueEntry copyWithCompanion(PlaybackQueueEntriesCompanion data) {
    return PlaybackQueueEntry(
      position: data.position.present ? data.position.value : this.position,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueEntry(')
          ..write('position: $position, ')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(position, trackId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackQueueEntry &&
          other.position == this.position &&
          other.trackId == this.trackId &&
          other.addedAt == this.addedAt);
}

class PlaybackQueueEntriesCompanion
    extends UpdateCompanion<PlaybackQueueEntry> {
  final Value<int> position;
  final Value<String> trackId;
  final Value<DateTime> addedAt;
  const PlaybackQueueEntriesCompanion({
    this.position = const Value.absent(),
    this.trackId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  PlaybackQueueEntriesCompanion.insert({
    this.position = const Value.absent(),
    required String trackId,
    this.addedAt = const Value.absent(),
  }) : trackId = Value(trackId);
  static Insertable<PlaybackQueueEntry> custom({
    Expression<int>? position,
    Expression<String>? trackId,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (trackId != null) 'track_id': trackId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  PlaybackQueueEntriesCompanion copyWith({
    Value<int>? position,
    Value<String>? trackId,
    Value<DateTime>? addedAt,
  }) {
    return PlaybackQueueEntriesCompanion(
      position: position ?? this.position,
      trackId: trackId ?? this.trackId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueEntriesCompanion(')
          ..write('position: $position, ')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedMetadataEntriesTable extends CachedMetadataEntries
    with TableInfo<$CachedMetadataEntriesTable, CachedMetadataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMetadataEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MusicProvider?, String> provider =
      GeneratedColumn<String>(
        'provider',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<MusicProvider?>(
        $CachedMetadataEntriesTable.$converterprovidern,
      );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    provider,
    payloadJson,
    expiresAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_metadata_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMetadataEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CachedMetadataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMetadataEntry(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      provider: $CachedMetadataEntriesTable.$converterprovidern.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}provider'],
        ),
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedMetadataEntriesTable createAlias(String alias) {
    return $CachedMetadataEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MusicProvider, String, String> $converterprovider =
      const EnumNameConverter<MusicProvider>(MusicProvider.values);
  static JsonTypeConverter2<MusicProvider?, String?, String?>
  $converterprovidern = JsonTypeConverter2.asNullable($converterprovider);
}

class CachedMetadataEntry extends DataClass
    implements Insertable<CachedMetadataEntry> {
  final String cacheKey;
  final MusicProvider? provider;
  final String payloadJson;
  final DateTime? expiresAt;
  final DateTime updatedAt;
  const CachedMetadataEntry({
    required this.cacheKey,
    this.provider,
    required this.payloadJson,
    this.expiresAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(
        $CachedMetadataEntriesTable.$converterprovidern.toSql(provider),
      );
    }
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedMetadataEntriesCompanion toCompanion(bool nullToAbsent) {
    return CachedMetadataEntriesCompanion(
      cacheKey: Value(cacheKey),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      payloadJson: Value(payloadJson),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedMetadataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMetadataEntry(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      provider: $CachedMetadataEntriesTable.$converterprovidern.fromJson(
        serializer.fromJson<String?>(json['provider']),
      ),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'provider': serializer.toJson<String?>(
        $CachedMetadataEntriesTable.$converterprovidern.toJson(provider),
      ),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedMetadataEntry copyWith({
    String? cacheKey,
    Value<MusicProvider?> provider = const Value.absent(),
    String? payloadJson,
    Value<DateTime?> expiresAt = const Value.absent(),
    DateTime? updatedAt,
  }) => CachedMetadataEntry(
    cacheKey: cacheKey ?? this.cacheKey,
    provider: provider.present ? provider.value : this.provider,
    payloadJson: payloadJson ?? this.payloadJson,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedMetadataEntry copyWithCompanion(CachedMetadataEntriesCompanion data) {
    return CachedMetadataEntry(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      provider: data.provider.present ? data.provider.value : this.provider,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMetadataEntry(')
          ..write('cacheKey: $cacheKey, ')
          ..write('provider: $provider, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cacheKey, provider, payloadJson, expiresAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMetadataEntry &&
          other.cacheKey == this.cacheKey &&
          other.provider == this.provider &&
          other.payloadJson == this.payloadJson &&
          other.expiresAt == this.expiresAt &&
          other.updatedAt == this.updatedAt);
}

class CachedMetadataEntriesCompanion
    extends UpdateCompanion<CachedMetadataEntry> {
  final Value<String> cacheKey;
  final Value<MusicProvider?> provider;
  final Value<String> payloadJson;
  final Value<DateTime?> expiresAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedMetadataEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.provider = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMetadataEntriesCompanion.insert({
    required String cacheKey,
    this.provider = const Value.absent(),
    required String payloadJson,
    this.expiresAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payloadJson = Value(payloadJson);
  static Insertable<CachedMetadataEntry> custom({
    Expression<String>? cacheKey,
    Expression<String>? provider,
    Expression<String>? payloadJson,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (provider != null) 'provider': provider,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMetadataEntriesCompanion copyWith({
    Value<String>? cacheKey,
    Value<MusicProvider?>? provider,
    Value<String>? payloadJson,
    Value<DateTime?>? expiresAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedMetadataEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      provider: provider ?? this.provider,
      payloadJson: payloadJson ?? this.payloadJson,
      expiresAt: expiresAt ?? this.expiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(
        $CachedMetadataEntriesTable.$converterprovidern.toSql(provider.value),
      );
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMetadataEntriesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('provider: $provider, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxEntriesTable extends SyncOutboxEntries
    with TableInfo<$SyncOutboxEntriesTable, SyncOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationJsonMeta = const VerificationMeta(
    'operationJson',
  );
  @override
  late final GeneratedColumn<String> operationJson = GeneratedColumn<String>(
    'operation_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, operationJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('operation_json')) {
      context.handle(
        _operationJsonMeta,
        operationJson.isAcceptableOrUnknown(
          data['operation_json']!,
          _operationJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      operationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncOutboxEntriesTable createAlias(String alias) {
    return $SyncOutboxEntriesTable(attachedDatabase, alias);
  }
}

class SyncOutboxEntry extends DataClass implements Insertable<SyncOutboxEntry> {
  final String id;
  final String? userId;
  final String operationJson;
  final DateTime createdAt;
  const SyncOutboxEntry({
    required this.id,
    this.userId,
    required this.operationJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['operation_json'] = Variable<String>(operationJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxEntriesCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      operationJson: Value(operationJson),
      createdAt: Value(createdAt),
    );
  }

  factory SyncOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      operationJson: serializer.fromJson<String>(json['operationJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'operationJson': serializer.toJson<String>(operationJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncOutboxEntry copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? operationJson,
    DateTime? createdAt,
  }) => SyncOutboxEntry(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    operationJson: operationJson ?? this.operationJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncOutboxEntry copyWithCompanion(SyncOutboxEntriesCompanion data) {
    return SyncOutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      operationJson: data.operationJson.present
          ? data.operationJson.value
          : this.operationJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('operationJson: $operationJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, operationJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.operationJson == this.operationJson &&
          other.createdAt == this.createdAt);
}

class SyncOutboxEntriesCompanion extends UpdateCompanion<SyncOutboxEntry> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> operationJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SyncOutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.operationJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxEntriesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String operationJson,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationJson = Value(operationJson);
  static Insertable<SyncOutboxEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? operationJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (operationJson != null) 'operation_json': operationJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? operationJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      operationJson: operationJson ?? this.operationJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (operationJson.present) {
      map['operation_json'] = Variable<String>(operationJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('operationJson: $operationJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StoredTracksTable storedTracks = $StoredTracksTable(this);
  late final $StoredTrackSourcesTable storedTrackSources =
      $StoredTrackSourcesTable(this);
  late final $LocalPlaylistsTable localPlaylists = $LocalPlaylistsTable(this);
  late final $LocalPlaylistTracksTable localPlaylistTracks =
      $LocalPlaylistTracksTable(this);
  late final $FavoriteTracksTable favoriteTracks = $FavoriteTracksTable(this);
  late final $ListeningHistoryEntriesTable listeningHistoryEntries =
      $ListeningHistoryEntriesTable(this);
  late final $SearchHistoryEntriesTable searchHistoryEntries =
      $SearchHistoryEntriesTable(this);
  late final $ProviderPreferencesTable providerPreferences =
      $ProviderPreferencesTable(this);
  late final $PlaybackQueueEntriesTable playbackQueueEntries =
      $PlaybackQueueEntriesTable(this);
  late final $CachedMetadataEntriesTable cachedMetadataEntries =
      $CachedMetadataEntriesTable(this);
  late final $SyncOutboxEntriesTable syncOutboxEntries =
      $SyncOutboxEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    storedTracks,
    storedTrackSources,
    localPlaylists,
    localPlaylistTracks,
    favoriteTracks,
    listeningHistoryEntries,
    searchHistoryEntries,
    providerPreferences,
    playbackQueueEntries,
    cachedMetadataEntries,
    syncOutboxEntries,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stored_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stored_track_sources', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stored_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stored_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stored_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('listening_history_entries', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stored_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playback_queue_entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$StoredTracksTableCreateCompanionBuilder =
    StoredTracksCompanion Function({
      required String id,
      required String title,
      required String normalizedTitle,
      required String artist,
      required String normalizedArtist,
      Value<String?> album,
      Value<int?> durationMs,
      Value<String?> artworkUrl,
      Value<MusicProvider?> preferredProvider,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredTracksTableUpdateCompanionBuilder =
    StoredTracksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> normalizedTitle,
      Value<String> artist,
      Value<String> normalizedArtist,
      Value<String?> album,
      Value<int?> durationMs,
      Value<String?> artworkUrl,
      Value<MusicProvider?> preferredProvider,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$StoredTracksTableReferences
    extends BaseReferences<_$AppDatabase, $StoredTracksTable, StoredTrack> {
  $$StoredTracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StoredTrackSourcesTable, List<StoredTrackSource>>
  _storedTrackSourcesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.storedTrackSources,
        aliasName: 'stored_tracks__id__stored_track_sources__track_id',
      );

  $$StoredTrackSourcesTableProcessedTableManager get storedTrackSourcesRefs {
    final manager = $$StoredTrackSourcesTableTableManager(
      $_db,
      $_db.storedTrackSources,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _storedTrackSourcesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LocalPlaylistTracksTable,
    List<LocalPlaylistTrack>
  >
  _localPlaylistTracksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localPlaylistTracks,
        aliasName: 'stored_tracks__id__local_playlist_tracks__track_id',
      );

  $$LocalPlaylistTracksTableProcessedTableManager get localPlaylistTracksRefs {
    final manager = $$LocalPlaylistTracksTableTableManager(
      $_db,
      $_db.localPlaylistTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localPlaylistTracksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoriteTracksTable, List<FavoriteTrack>>
  _favoriteTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favoriteTracks,
    aliasName: 'stored_tracks__id__favorite_tracks__track_id',
  );

  $$FavoriteTracksTableProcessedTableManager get favoriteTracksRefs {
    final manager = $$FavoriteTracksTableTableManager(
      $_db,
      $_db.favoriteTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoriteTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ListeningHistoryEntriesTable,
    List<ListeningHistoryEntry>
  >
  _listeningHistoryEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.listeningHistoryEntries,
        aliasName: 'stored_tracks__id__listening_history_entries__track_id',
      );

  $$ListeningHistoryEntriesTableProcessedTableManager
  get listeningHistoryEntriesRefs {
    final manager = $$ListeningHistoryEntriesTableTableManager(
      $_db,
      $_db.listeningHistoryEntries,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _listeningHistoryEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PlaybackQueueEntriesTable,
    List<PlaybackQueueEntry>
  >
  _playbackQueueEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playbackQueueEntries,
        aliasName: 'stored_tracks__id__playback_queue_entries__track_id',
      );

  $$PlaybackQueueEntriesTableProcessedTableManager
  get playbackQueueEntriesRefs {
    final manager = $$PlaybackQueueEntriesTableTableManager(
      $_db,
      $_db.playbackQueueEntries,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playbackQueueEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StoredTracksTableFilterComposer
    extends Composer<_$AppDatabase, $StoredTracksTable> {
  $$StoredTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedArtist => $composableBuilder(
    column: $table.normalizedArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MusicProvider?, MusicProvider, String>
  get preferredProvider => $composableBuilder(
    column: $table.preferredProvider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> storedTrackSourcesRefs(
    Expression<bool> Function($$StoredTrackSourcesTableFilterComposer f) f,
  ) {
    final $$StoredTrackSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storedTrackSources,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTrackSourcesTableFilterComposer(
            $db: $db,
            $table: $db.storedTrackSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localPlaylistTracksRefs(
    Expression<bool> Function($$LocalPlaylistTracksTableFilterComposer f) f,
  ) {
    final $$LocalPlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localPlaylistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.localPlaylistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoriteTracksRefs(
    Expression<bool> Function($$FavoriteTracksTableFilterComposer f) f,
  ) {
    final $$FavoriteTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTracksTableFilterComposer(
            $db: $db,
            $table: $db.favoriteTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> listeningHistoryEntriesRefs(
    Expression<bool> Function($$ListeningHistoryEntriesTableFilterComposer f) f,
  ) {
    final $$ListeningHistoryEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.listeningHistoryEntries,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ListeningHistoryEntriesTableFilterComposer(
                $db: $db,
                $table: $db.listeningHistoryEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> playbackQueueEntriesRefs(
    Expression<bool> Function($$PlaybackQueueEntriesTableFilterComposer f) f,
  ) {
    final $$PlaybackQueueEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackQueueEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackQueueEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playbackQueueEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StoredTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredTracksTable> {
  $$StoredTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedArtist => $composableBuilder(
    column: $table.normalizedArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredProvider => $composableBuilder(
    column: $table.preferredProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredTracksTable> {
  $$StoredTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get normalizedArtist => $composableBuilder(
    column: $table.normalizedArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MusicProvider?, String>
  get preferredProvider => $composableBuilder(
    column: $table.preferredProvider,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> storedTrackSourcesRefs<T extends Object>(
    Expression<T> Function($$StoredTrackSourcesTableAnnotationComposer a) f,
  ) {
    final $$StoredTrackSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.storedTrackSources,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StoredTrackSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.storedTrackSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> localPlaylistTracksRefs<T extends Object>(
    Expression<T> Function($$LocalPlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$LocalPlaylistTracksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localPlaylistTracks,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalPlaylistTracksTableAnnotationComposer(
                $db: $db,
                $table: $db.localPlaylistTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> favoriteTracksRefs<T extends Object>(
    Expression<T> Function($$FavoriteTracksTableAnnotationComposer a) f,
  ) {
    final $$FavoriteTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> listeningHistoryEntriesRefs<T extends Object>(
    Expression<T> Function($$ListeningHistoryEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$ListeningHistoryEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.listeningHistoryEntries,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ListeningHistoryEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.listeningHistoryEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> playbackQueueEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaybackQueueEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaybackQueueEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playbackQueueEntries,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaybackQueueEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.playbackQueueEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StoredTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredTracksTable,
          StoredTrack,
          $$StoredTracksTableFilterComposer,
          $$StoredTracksTableOrderingComposer,
          $$StoredTracksTableAnnotationComposer,
          $$StoredTracksTableCreateCompanionBuilder,
          $$StoredTracksTableUpdateCompanionBuilder,
          (StoredTrack, $$StoredTracksTableReferences),
          StoredTrack,
          PrefetchHooks Function({
            bool storedTrackSourcesRefs,
            bool localPlaylistTracksRefs,
            bool favoriteTracksRefs,
            bool listeningHistoryEntriesRefs,
            bool playbackQueueEntriesRefs,
          })
        > {
  $$StoredTracksTableTableManager(_$AppDatabase db, $StoredTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> normalizedTitle = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> normalizedArtist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<MusicProvider?> preferredProvider = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredTracksCompanion(
                id: id,
                title: title,
                normalizedTitle: normalizedTitle,
                artist: artist,
                normalizedArtist: normalizedArtist,
                album: album,
                durationMs: durationMs,
                artworkUrl: artworkUrl,
                preferredProvider: preferredProvider,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String normalizedTitle,
                required String artist,
                required String normalizedArtist,
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<MusicProvider?> preferredProvider = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredTracksCompanion.insert(
                id: id,
                title: title,
                normalizedTitle: normalizedTitle,
                artist: artist,
                normalizedArtist: normalizedArtist,
                album: album,
                durationMs: durationMs,
                artworkUrl: artworkUrl,
                preferredProvider: preferredProvider,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoredTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                storedTrackSourcesRefs = false,
                localPlaylistTracksRefs = false,
                favoriteTracksRefs = false,
                listeningHistoryEntriesRefs = false,
                playbackQueueEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (storedTrackSourcesRefs) db.storedTrackSources,
                    if (localPlaylistTracksRefs) db.localPlaylistTracks,
                    if (favoriteTracksRefs) db.favoriteTracks,
                    if (listeningHistoryEntriesRefs) db.listeningHistoryEntries,
                    if (playbackQueueEntriesRefs) db.playbackQueueEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (storedTrackSourcesRefs)
                        await $_getPrefetchedData<
                          StoredTrack,
                          $StoredTracksTable,
                          StoredTrackSource
                        >(
                          currentTable: table,
                          referencedTable: $$StoredTracksTableReferences
                              ._storedTrackSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoredTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).storedTrackSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localPlaylistTracksRefs)
                        await $_getPrefetchedData<
                          StoredTrack,
                          $StoredTracksTable,
                          LocalPlaylistTrack
                        >(
                          currentTable: table,
                          referencedTable: $$StoredTracksTableReferences
                              ._localPlaylistTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoredTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).localPlaylistTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoriteTracksRefs)
                        await $_getPrefetchedData<
                          StoredTrack,
                          $StoredTracksTable,
                          FavoriteTrack
                        >(
                          currentTable: table,
                          referencedTable: $$StoredTracksTableReferences
                              ._favoriteTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoredTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).favoriteTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (listeningHistoryEntriesRefs)
                        await $_getPrefetchedData<
                          StoredTrack,
                          $StoredTracksTable,
                          ListeningHistoryEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StoredTracksTableReferences
                              ._listeningHistoryEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoredTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).listeningHistoryEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playbackQueueEntriesRefs)
                        await $_getPrefetchedData<
                          StoredTrack,
                          $StoredTracksTable,
                          PlaybackQueueEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StoredTracksTableReferences
                              ._playbackQueueEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoredTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playbackQueueEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StoredTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredTracksTable,
      StoredTrack,
      $$StoredTracksTableFilterComposer,
      $$StoredTracksTableOrderingComposer,
      $$StoredTracksTableAnnotationComposer,
      $$StoredTracksTableCreateCompanionBuilder,
      $$StoredTracksTableUpdateCompanionBuilder,
      (StoredTrack, $$StoredTracksTableReferences),
      StoredTrack,
      PrefetchHooks Function({
        bool storedTrackSourcesRefs,
        bool localPlaylistTracksRefs,
        bool favoriteTracksRefs,
        bool listeningHistoryEntriesRefs,
        bool playbackQueueEntriesRefs,
      })
    >;
typedef $$StoredTrackSourcesTableCreateCompanionBuilder =
    StoredTrackSourcesCompanion Function({
      Value<int> rowId,
      required String trackId,
      required MusicProvider provider,
      required String externalId,
      required String externalUrl,
      Value<String> metadataJson,
    });
typedef $$StoredTrackSourcesTableUpdateCompanionBuilder =
    StoredTrackSourcesCompanion Function({
      Value<int> rowId,
      Value<String> trackId,
      Value<MusicProvider> provider,
      Value<String> externalId,
      Value<String> externalUrl,
      Value<String> metadataJson,
    });

final class $$StoredTrackSourcesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StoredTrackSourcesTable,
          StoredTrackSource
        > {
  $$StoredTrackSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StoredTracksTable _trackIdTable(_$AppDatabase db) => db.storedTracks
      .createAlias('stored_track_sources__track_id__stored_tracks__id');

  $$StoredTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$StoredTracksTableTableManager(
      $_db,
      $_db.storedTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StoredTrackSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredTrackSourcesTable> {
  $$StoredTrackSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MusicProvider, MusicProvider, String>
  get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalUrl => $composableBuilder(
    column: $table.externalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  $$StoredTracksTableFilterComposer get trackId {
    final $$StoredTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableFilterComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoredTrackSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredTrackSourcesTable> {
  $$StoredTrackSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalUrl => $composableBuilder(
    column: $table.externalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoredTracksTableOrderingComposer get trackId {
    final $$StoredTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableOrderingComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoredTrackSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredTrackSourcesTable> {
  $$StoredTrackSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MusicProvider, String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalUrl => $composableBuilder(
    column: $table.externalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  $$StoredTracksTableAnnotationComposer get trackId {
    final $$StoredTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoredTrackSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredTrackSourcesTable,
          StoredTrackSource,
          $$StoredTrackSourcesTableFilterComposer,
          $$StoredTrackSourcesTableOrderingComposer,
          $$StoredTrackSourcesTableAnnotationComposer,
          $$StoredTrackSourcesTableCreateCompanionBuilder,
          $$StoredTrackSourcesTableUpdateCompanionBuilder,
          (StoredTrackSource, $$StoredTrackSourcesTableReferences),
          StoredTrackSource,
          PrefetchHooks Function({bool trackId})
        > {
  $$StoredTrackSourcesTableTableManager(
    _$AppDatabase db,
    $StoredTrackSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredTrackSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredTrackSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredTrackSourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<MusicProvider> provider = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String> externalUrl = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
              }) => StoredTrackSourcesCompanion(
                rowId: rowId,
                trackId: trackId,
                provider: provider,
                externalId: externalId,
                externalUrl: externalUrl,
                metadataJson: metadataJson,
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                required String trackId,
                required MusicProvider provider,
                required String externalId,
                required String externalUrl,
                Value<String> metadataJson = const Value.absent(),
              }) => StoredTrackSourcesCompanion.insert(
                rowId: rowId,
                trackId: trackId,
                provider: provider,
                externalId: externalId,
                externalUrl: externalUrl,
                metadataJson: metadataJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoredTrackSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$StoredTrackSourcesTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$StoredTrackSourcesTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StoredTrackSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredTrackSourcesTable,
      StoredTrackSource,
      $$StoredTrackSourcesTableFilterComposer,
      $$StoredTrackSourcesTableOrderingComposer,
      $$StoredTrackSourcesTableAnnotationComposer,
      $$StoredTrackSourcesTableCreateCompanionBuilder,
      $$StoredTrackSourcesTableUpdateCompanionBuilder,
      (StoredTrackSource, $$StoredTrackSourcesTableReferences),
      StoredTrackSource,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$LocalPlaylistsTableCreateCompanionBuilder =
    LocalPlaylistsCompanion Function({
      required String id,
      required String name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalPlaylistsTableUpdateCompanionBuilder =
    LocalPlaylistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LocalPlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $LocalPlaylistsTable, LocalPlaylist> {
  $$LocalPlaylistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LocalPlaylistTracksTable,
    List<LocalPlaylistTrack>
  >
  _localPlaylistTracksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localPlaylistTracks,
        aliasName: 'local_playlists__id__local_playlist_tracks__playlist_id',
      );

  $$LocalPlaylistTracksTableProcessedTableManager get localPlaylistTracksRefs {
    final manager = $$LocalPlaylistTracksTableTableManager(
      $_db,
      $_db.localPlaylistTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localPlaylistTracksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalPlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localPlaylistTracksRefs(
    Expression<bool> Function($$LocalPlaylistTracksTableFilterComposer f) f,
  ) {
    final $$LocalPlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localPlaylistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.localPlaylistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalPlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> localPlaylistTracksRefs<T extends Object>(
    Expression<T> Function($$LocalPlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$LocalPlaylistTracksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localPlaylistTracks,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalPlaylistTracksTableAnnotationComposer(
                $db: $db,
                $table: $db.localPlaylistTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalPlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPlaylistsTable,
          LocalPlaylist,
          $$LocalPlaylistsTableFilterComposer,
          $$LocalPlaylistsTableOrderingComposer,
          $$LocalPlaylistsTableAnnotationComposer,
          $$LocalPlaylistsTableCreateCompanionBuilder,
          $$LocalPlaylistsTableUpdateCompanionBuilder,
          (LocalPlaylist, $$LocalPlaylistsTableReferences),
          LocalPlaylist,
          PrefetchHooks Function({bool localPlaylistTracksRefs})
        > {
  $$LocalPlaylistsTableTableManager(
    _$AppDatabase db,
    $LocalPlaylistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalPlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localPlaylistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localPlaylistTracksRefs) db.localPlaylistTracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localPlaylistTracksRefs)
                    await $_getPrefetchedData<
                      LocalPlaylist,
                      $LocalPlaylistsTable,
                      LocalPlaylistTrack
                    >(
                      currentTable: table,
                      referencedTable: $$LocalPlaylistsTableReferences
                          ._localPlaylistTracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalPlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).localPlaylistTracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalPlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPlaylistsTable,
      LocalPlaylist,
      $$LocalPlaylistsTableFilterComposer,
      $$LocalPlaylistsTableOrderingComposer,
      $$LocalPlaylistsTableAnnotationComposer,
      $$LocalPlaylistsTableCreateCompanionBuilder,
      $$LocalPlaylistsTableUpdateCompanionBuilder,
      (LocalPlaylist, $$LocalPlaylistsTableReferences),
      LocalPlaylist,
      PrefetchHooks Function({bool localPlaylistTracksRefs})
    >;
typedef $$LocalPlaylistTracksTableCreateCompanionBuilder =
    LocalPlaylistTracksCompanion Function({
      required String playlistId,
      required String trackId,
      required int position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$LocalPlaylistTracksTableUpdateCompanionBuilder =
    LocalPlaylistTracksCompanion Function({
      Value<String> playlistId,
      Value<String> trackId,
      Value<int> position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$LocalPlaylistTracksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalPlaylistTracksTable,
          LocalPlaylistTrack
        > {
  $$LocalPlaylistTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalPlaylistsTable _playlistIdTable(_$AppDatabase db) => db
      .localPlaylists
      .createAlias('local_playlist_tracks__playlist_id__local_playlists__id');

  $$LocalPlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$LocalPlaylistsTableTableManager(
      $_db,
      $_db.localPlaylists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StoredTracksTable _trackIdTable(_$AppDatabase db) => db.storedTracks
      .createAlias('local_playlist_tracks__track_id__stored_tracks__id');

  $$StoredTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$StoredTracksTableTableManager(
      $_db,
      $_db.storedTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalPlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlaylistTracksTable> {
  $$LocalPlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalPlaylistsTableFilterComposer get playlistId {
    final $$LocalPlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.localPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.localPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StoredTracksTableFilterComposer get trackId {
    final $$StoredTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableFilterComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlaylistTracksTable> {
  $$LocalPlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalPlaylistsTableOrderingComposer get playlistId {
    final $$LocalPlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.localPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.localPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StoredTracksTableOrderingComposer get trackId {
    final $$StoredTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableOrderingComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlaylistTracksTable> {
  $$LocalPlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$LocalPlaylistsTableAnnotationComposer get playlistId {
    final $$LocalPlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.localPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.localPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StoredTracksTableAnnotationComposer get trackId {
    final $$StoredTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPlaylistTracksTable,
          LocalPlaylistTrack,
          $$LocalPlaylistTracksTableFilterComposer,
          $$LocalPlaylistTracksTableOrderingComposer,
          $$LocalPlaylistTracksTableAnnotationComposer,
          $$LocalPlaylistTracksTableCreateCompanionBuilder,
          $$LocalPlaylistTracksTableUpdateCompanionBuilder,
          (LocalPlaylistTrack, $$LocalPlaylistTracksTableReferences),
          LocalPlaylistTrack,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$LocalPlaylistTracksTableTableManager(
    _$AppDatabase db,
    $LocalPlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaylistTracksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalPlaylistTracksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPlaylistTracksCompanion(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String trackId,
                required int position,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPlaylistTracksCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalPlaylistTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable:
                                    $$LocalPlaylistTracksTableReferences
                                        ._playlistIdTable(db),
                                referencedColumn:
                                    $$LocalPlaylistTracksTableReferences
                                        ._playlistIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$LocalPlaylistTracksTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$LocalPlaylistTracksTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalPlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPlaylistTracksTable,
      LocalPlaylistTrack,
      $$LocalPlaylistTracksTableFilterComposer,
      $$LocalPlaylistTracksTableOrderingComposer,
      $$LocalPlaylistTracksTableAnnotationComposer,
      $$LocalPlaylistTracksTableCreateCompanionBuilder,
      $$LocalPlaylistTracksTableUpdateCompanionBuilder,
      (LocalPlaylistTrack, $$LocalPlaylistTracksTableReferences),
      LocalPlaylistTrack,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$FavoriteTracksTableCreateCompanionBuilder =
    FavoriteTracksCompanion Function({
      required String trackId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$FavoriteTracksTableUpdateCompanionBuilder =
    FavoriteTracksCompanion Function({
      Value<String> trackId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$FavoriteTracksTableReferences
    extends BaseReferences<_$AppDatabase, $FavoriteTracksTable, FavoriteTrack> {
  $$FavoriteTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StoredTracksTable _trackIdTable(_$AppDatabase db) => db.storedTracks
      .createAlias('favorite_tracks__track_id__stored_tracks__id');

  $$StoredTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$StoredTracksTableTableManager(
      $_db,
      $_db.storedTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoriteTracksTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteTracksTable> {
  $$FavoriteTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StoredTracksTableFilterComposer get trackId {
    final $$StoredTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableFilterComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteTracksTable> {
  $$FavoriteTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoredTracksTableOrderingComposer get trackId {
    final $$StoredTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableOrderingComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteTracksTable> {
  $$FavoriteTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$StoredTracksTableAnnotationComposer get trackId {
    final $$StoredTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteTracksTable,
          FavoriteTrack,
          $$FavoriteTracksTableFilterComposer,
          $$FavoriteTracksTableOrderingComposer,
          $$FavoriteTracksTableAnnotationComposer,
          $$FavoriteTracksTableCreateCompanionBuilder,
          $$FavoriteTracksTableUpdateCompanionBuilder,
          (FavoriteTrack, $$FavoriteTracksTableReferences),
          FavoriteTrack,
          PrefetchHooks Function({bool trackId})
        > {
  $$FavoriteTracksTableTableManager(
    _$AppDatabase db,
    $FavoriteTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteTracksCompanion(
                trackId: trackId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteTracksCompanion.insert(
                trackId: trackId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoriteTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$FavoriteTracksTableReferences
                                    ._trackIdTable(db),
                                referencedColumn:
                                    $$FavoriteTracksTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteTracksTable,
      FavoriteTrack,
      $$FavoriteTracksTableFilterComposer,
      $$FavoriteTracksTableOrderingComposer,
      $$FavoriteTracksTableAnnotationComposer,
      $$FavoriteTracksTableCreateCompanionBuilder,
      $$FavoriteTracksTableUpdateCompanionBuilder,
      (FavoriteTrack, $$FavoriteTracksTableReferences),
      FavoriteTrack,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ListeningHistoryEntriesTableCreateCompanionBuilder =
    ListeningHistoryEntriesCompanion Function({
      Value<int> id,
      required String trackId,
      Value<DateTime> playedAt,
      Value<int> positionMs,
    });
typedef $$ListeningHistoryEntriesTableUpdateCompanionBuilder =
    ListeningHistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> trackId,
      Value<DateTime> playedAt,
      Value<int> positionMs,
    });

final class $$ListeningHistoryEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ListeningHistoryEntriesTable,
          ListeningHistoryEntry
        > {
  $$ListeningHistoryEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StoredTracksTable _trackIdTable(_$AppDatabase db) => db.storedTracks
      .createAlias('listening_history_entries__track_id__stored_tracks__id');

  $$StoredTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$StoredTracksTableTableManager(
      $_db,
      $_db.storedTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ListeningHistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ListeningHistoryEntriesTable> {
  $$ListeningHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  $$StoredTracksTableFilterComposer get trackId {
    final $$StoredTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableFilterComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListeningHistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ListeningHistoryEntriesTable> {
  $$ListeningHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoredTracksTableOrderingComposer get trackId {
    final $$StoredTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableOrderingComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListeningHistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListeningHistoryEntriesTable> {
  $$ListeningHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  $$StoredTracksTableAnnotationComposer get trackId {
    final $$StoredTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListeningHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListeningHistoryEntriesTable,
          ListeningHistoryEntry,
          $$ListeningHistoryEntriesTableFilterComposer,
          $$ListeningHistoryEntriesTableOrderingComposer,
          $$ListeningHistoryEntriesTableAnnotationComposer,
          $$ListeningHistoryEntriesTableCreateCompanionBuilder,
          $$ListeningHistoryEntriesTableUpdateCompanionBuilder,
          (ListeningHistoryEntry, $$ListeningHistoryEntriesTableReferences),
          ListeningHistoryEntry,
          PrefetchHooks Function({bool trackId})
        > {
  $$ListeningHistoryEntriesTableTableManager(
    _$AppDatabase db,
    $ListeningHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListeningHistoryEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ListeningHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ListeningHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
              }) => ListeningHistoryEntriesCompanion(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                positionMs: positionMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String trackId,
                Value<DateTime> playedAt = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
              }) => ListeningHistoryEntriesCompanion.insert(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                positionMs: positionMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ListeningHistoryEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$ListeningHistoryEntriesTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$ListeningHistoryEntriesTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ListeningHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListeningHistoryEntriesTable,
      ListeningHistoryEntry,
      $$ListeningHistoryEntriesTableFilterComposer,
      $$ListeningHistoryEntriesTableOrderingComposer,
      $$ListeningHistoryEntriesTableAnnotationComposer,
      $$ListeningHistoryEntriesTableCreateCompanionBuilder,
      $$ListeningHistoryEntriesTableUpdateCompanionBuilder,
      (ListeningHistoryEntry, $$ListeningHistoryEntriesTableReferences),
      ListeningHistoryEntry,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$SearchHistoryEntriesTableCreateCompanionBuilder =
    SearchHistoryEntriesCompanion Function({
      Value<int> id,
      required String query,
      Value<DateTime> searchedAt,
    });
typedef $$SearchHistoryEntriesTableUpdateCompanionBuilder =
    SearchHistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> query,
      Value<DateTime> searchedAt,
    });

class $$SearchHistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryEntriesTable,
          SearchHistoryEntry,
          $$SearchHistoryEntriesTableFilterComposer,
          $$SearchHistoryEntriesTableOrderingComposer,
          $$SearchHistoryEntriesTableAnnotationComposer,
          $$SearchHistoryEntriesTableCreateCompanionBuilder,
          $$SearchHistoryEntriesTableUpdateCompanionBuilder,
          (
            SearchHistoryEntry,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryEntriesTable,
              SearchHistoryEntry
            >,
          ),
          SearchHistoryEntry,
          PrefetchHooks Function()
        > {
  $$SearchHistoryEntriesTableTableManager(
    _$AppDatabase db,
    $SearchHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryEntriesCompanion(
                id: id,
                query: query,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String query,
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryEntriesCompanion.insert(
                id: id,
                query: query,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryEntriesTable,
      SearchHistoryEntry,
      $$SearchHistoryEntriesTableFilterComposer,
      $$SearchHistoryEntriesTableOrderingComposer,
      $$SearchHistoryEntriesTableAnnotationComposer,
      $$SearchHistoryEntriesTableCreateCompanionBuilder,
      $$SearchHistoryEntriesTableUpdateCompanionBuilder,
      (
        SearchHistoryEntry,
        BaseReferences<
          _$AppDatabase,
          $SearchHistoryEntriesTable,
          SearchHistoryEntry
        >,
      ),
      SearchHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$ProviderPreferencesTableCreateCompanionBuilder =
    ProviderPreferencesCompanion Function({
      required MusicProvider provider,
      Value<bool> enabled,
      required int fallbackPriority,
      Value<AudioQuality> quality,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderPreferencesTableUpdateCompanionBuilder =
    ProviderPreferencesCompanion Function({
      Value<MusicProvider> provider,
      Value<bool> enabled,
      Value<int> fallbackPriority,
      Value<AudioQuality> quality,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderPreferencesTable> {
  $$ProviderPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<MusicProvider, MusicProvider, String>
  get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fallbackPriority => $composableBuilder(
    column: $table.fallbackPriority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AudioQuality, AudioQuality, String>
  get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderPreferencesTable> {
  $$ProviderPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fallbackPriority => $composableBuilder(
    column: $table.fallbackPriority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderPreferencesTable> {
  $$ProviderPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<MusicProvider, String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get fallbackPriority => $composableBuilder(
    column: $table.fallbackPriority,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AudioQuality, String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderPreferencesTable,
          ProviderPreference,
          $$ProviderPreferencesTableFilterComposer,
          $$ProviderPreferencesTableOrderingComposer,
          $$ProviderPreferencesTableAnnotationComposer,
          $$ProviderPreferencesTableCreateCompanionBuilder,
          $$ProviderPreferencesTableUpdateCompanionBuilder,
          (
            ProviderPreference,
            BaseReferences<
              _$AppDatabase,
              $ProviderPreferencesTable,
              ProviderPreference
            >,
          ),
          ProviderPreference,
          PrefetchHooks Function()
        > {
  $$ProviderPreferencesTableTableManager(
    _$AppDatabase db,
    $ProviderPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProviderPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<MusicProvider> provider = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> fallbackPriority = const Value.absent(),
                Value<AudioQuality> quality = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderPreferencesCompanion(
                provider: provider,
                enabled: enabled,
                fallbackPriority: fallbackPriority,
                quality: quality,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required MusicProvider provider,
                Value<bool> enabled = const Value.absent(),
                required int fallbackPriority,
                Value<AudioQuality> quality = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderPreferencesCompanion.insert(
                provider: provider,
                enabled: enabled,
                fallbackPriority: fallbackPriority,
                quality: quality,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderPreferencesTable,
      ProviderPreference,
      $$ProviderPreferencesTableFilterComposer,
      $$ProviderPreferencesTableOrderingComposer,
      $$ProviderPreferencesTableAnnotationComposer,
      $$ProviderPreferencesTableCreateCompanionBuilder,
      $$ProviderPreferencesTableUpdateCompanionBuilder,
      (
        ProviderPreference,
        BaseReferences<
          _$AppDatabase,
          $ProviderPreferencesTable,
          ProviderPreference
        >,
      ),
      ProviderPreference,
      PrefetchHooks Function()
    >;
typedef $$PlaybackQueueEntriesTableCreateCompanionBuilder =
    PlaybackQueueEntriesCompanion Function({
      Value<int> position,
      required String trackId,
      Value<DateTime> addedAt,
    });
typedef $$PlaybackQueueEntriesTableUpdateCompanionBuilder =
    PlaybackQueueEntriesCompanion Function({
      Value<int> position,
      Value<String> trackId,
      Value<DateTime> addedAt,
    });

final class $$PlaybackQueueEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaybackQueueEntriesTable,
          PlaybackQueueEntry
        > {
  $$PlaybackQueueEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StoredTracksTable _trackIdTable(_$AppDatabase db) => db.storedTracks
      .createAlias('playback_queue_entries__track_id__stored_tracks__id');

  $$StoredTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$StoredTracksTableTableManager(
      $_db,
      $_db.storedTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StoredTracksTableFilterComposer get trackId {
    final $$StoredTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableFilterComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoredTracksTableOrderingComposer get trackId {
    final $$StoredTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableOrderingComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$StoredTracksTableAnnotationComposer get trackId {
    final $$StoredTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.storedTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoredTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.storedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackQueueEntriesTable,
          PlaybackQueueEntry,
          $$PlaybackQueueEntriesTableFilterComposer,
          $$PlaybackQueueEntriesTableOrderingComposer,
          $$PlaybackQueueEntriesTableAnnotationComposer,
          $$PlaybackQueueEntriesTableCreateCompanionBuilder,
          $$PlaybackQueueEntriesTableUpdateCompanionBuilder,
          (PlaybackQueueEntry, $$PlaybackQueueEntriesTableReferences),
          PlaybackQueueEntry,
          PrefetchHooks Function({bool trackId})
        > {
  $$PlaybackQueueEntriesTableTableManager(
    _$AppDatabase db,
    $PlaybackQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => PlaybackQueueEntriesCompanion(
                position: position,
                trackId: trackId,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                required String trackId,
                Value<DateTime> addedAt = const Value.absent(),
              }) => PlaybackQueueEntriesCompanion.insert(
                position: position,
                trackId: trackId,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackQueueEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$PlaybackQueueEntriesTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$PlaybackQueueEntriesTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackQueueEntriesTable,
      PlaybackQueueEntry,
      $$PlaybackQueueEntriesTableFilterComposer,
      $$PlaybackQueueEntriesTableOrderingComposer,
      $$PlaybackQueueEntriesTableAnnotationComposer,
      $$PlaybackQueueEntriesTableCreateCompanionBuilder,
      $$PlaybackQueueEntriesTableUpdateCompanionBuilder,
      (PlaybackQueueEntry, $$PlaybackQueueEntriesTableReferences),
      PlaybackQueueEntry,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$CachedMetadataEntriesTableCreateCompanionBuilder =
    CachedMetadataEntriesCompanion Function({
      required String cacheKey,
      Value<MusicProvider?> provider,
      required String payloadJson,
      Value<DateTime?> expiresAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CachedMetadataEntriesTableUpdateCompanionBuilder =
    CachedMetadataEntriesCompanion Function({
      Value<String> cacheKey,
      Value<MusicProvider?> provider,
      Value<String> payloadJson,
      Value<DateTime?> expiresAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedMetadataEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMetadataEntriesTable> {
  $$CachedMetadataEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MusicProvider?, MusicProvider, String>
  get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMetadataEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMetadataEntriesTable> {
  $$CachedMetadataEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMetadataEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMetadataEntriesTable> {
  $$CachedMetadataEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MusicProvider?, String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedMetadataEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMetadataEntriesTable,
          CachedMetadataEntry,
          $$CachedMetadataEntriesTableFilterComposer,
          $$CachedMetadataEntriesTableOrderingComposer,
          $$CachedMetadataEntriesTableAnnotationComposer,
          $$CachedMetadataEntriesTableCreateCompanionBuilder,
          $$CachedMetadataEntriesTableUpdateCompanionBuilder,
          (
            CachedMetadataEntry,
            BaseReferences<
              _$AppDatabase,
              $CachedMetadataEntriesTable,
              CachedMetadataEntry
            >,
          ),
          CachedMetadataEntry,
          PrefetchHooks Function()
        > {
  $$CachedMetadataEntriesTableTableManager(
    _$AppDatabase db,
    $CachedMetadataEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMetadataEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedMetadataEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedMetadataEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<MusicProvider?> provider = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMetadataEntriesCompanion(
                cacheKey: cacheKey,
                provider: provider,
                payloadJson: payloadJson,
                expiresAt: expiresAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                Value<MusicProvider?> provider = const Value.absent(),
                required String payloadJson,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMetadataEntriesCompanion.insert(
                cacheKey: cacheKey,
                provider: provider,
                payloadJson: payloadJson,
                expiresAt: expiresAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMetadataEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMetadataEntriesTable,
      CachedMetadataEntry,
      $$CachedMetadataEntriesTableFilterComposer,
      $$CachedMetadataEntriesTableOrderingComposer,
      $$CachedMetadataEntriesTableAnnotationComposer,
      $$CachedMetadataEntriesTableCreateCompanionBuilder,
      $$CachedMetadataEntriesTableUpdateCompanionBuilder,
      (
        CachedMetadataEntry,
        BaseReferences<
          _$AppDatabase,
          $CachedMetadataEntriesTable,
          CachedMetadataEntry
        >,
      ),
      CachedMetadataEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxEntriesTableCreateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      required String id,
      Value<String?> userId,
      required String operationJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$SyncOutboxEntriesTableUpdateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> operationJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SyncOutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationJson => $composableBuilder(
    column: $table.operationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationJson => $composableBuilder(
    column: $table.operationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get operationJson => $composableBuilder(
    column: $table.operationJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxEntry,
          $$SyncOutboxEntriesTableFilterComposer,
          $$SyncOutboxEntriesTableOrderingComposer,
          $$SyncOutboxEntriesTableAnnotationComposer,
          $$SyncOutboxEntriesTableCreateCompanionBuilder,
          $$SyncOutboxEntriesTableUpdateCompanionBuilder,
          (
            SyncOutboxEntry,
            BaseReferences<
              _$AppDatabase,
              $SyncOutboxEntriesTable,
              SyncOutboxEntry
            >,
          ),
          SyncOutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxEntriesTableTableManager(
    _$AppDatabase db,
    $SyncOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> operationJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion(
                id: id,
                userId: userId,
                operationJson: operationJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String operationJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion.insert(
                id: id,
                userId: userId,
                operationJson: operationJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxEntriesTable,
      SyncOutboxEntry,
      $$SyncOutboxEntriesTableFilterComposer,
      $$SyncOutboxEntriesTableOrderingComposer,
      $$SyncOutboxEntriesTableAnnotationComposer,
      $$SyncOutboxEntriesTableCreateCompanionBuilder,
      $$SyncOutboxEntriesTableUpdateCompanionBuilder,
      (
        SyncOutboxEntry,
        BaseReferences<_$AppDatabase, $SyncOutboxEntriesTable, SyncOutboxEntry>,
      ),
      SyncOutboxEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StoredTracksTableTableManager get storedTracks =>
      $$StoredTracksTableTableManager(_db, _db.storedTracks);
  $$StoredTrackSourcesTableTableManager get storedTrackSources =>
      $$StoredTrackSourcesTableTableManager(_db, _db.storedTrackSources);
  $$LocalPlaylistsTableTableManager get localPlaylists =>
      $$LocalPlaylistsTableTableManager(_db, _db.localPlaylists);
  $$LocalPlaylistTracksTableTableManager get localPlaylistTracks =>
      $$LocalPlaylistTracksTableTableManager(_db, _db.localPlaylistTracks);
  $$FavoriteTracksTableTableManager get favoriteTracks =>
      $$FavoriteTracksTableTableManager(_db, _db.favoriteTracks);
  $$ListeningHistoryEntriesTableTableManager get listeningHistoryEntries =>
      $$ListeningHistoryEntriesTableTableManager(
        _db,
        _db.listeningHistoryEntries,
      );
  $$SearchHistoryEntriesTableTableManager get searchHistoryEntries =>
      $$SearchHistoryEntriesTableTableManager(_db, _db.searchHistoryEntries);
  $$ProviderPreferencesTableTableManager get providerPreferences =>
      $$ProviderPreferencesTableTableManager(_db, _db.providerPreferences);
  $$PlaybackQueueEntriesTableTableManager get playbackQueueEntries =>
      $$PlaybackQueueEntriesTableTableManager(_db, _db.playbackQueueEntries);
  $$CachedMetadataEntriesTableTableManager get cachedMetadataEntries =>
      $$CachedMetadataEntriesTableTableManager(_db, _db.cachedMetadataEntries);
  $$SyncOutboxEntriesTableTableManager get syncOutboxEntries =>
      $$SyncOutboxEntriesTableTableManager(_db, _db.syncOutboxEntries);
}
