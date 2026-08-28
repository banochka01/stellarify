// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'unified_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UnifiedTrack {

 String get id; String get title; String get normalizedTitle; String get artist; String get normalizedArtist; String? get album;@DurationMillisecondsConverter() Duration? get duration;@NullableUriStringConverter() Uri? get artworkUrl; List<TrackSource> get sources; MusicProvider? get preferredProvider;
/// Create a copy of UnifiedTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnifiedTrackCopyWith<UnifiedTrack> get copyWith => _$UnifiedTrackCopyWithImpl<UnifiedTrack>(this as UnifiedTrack, _$identity);

  /// Serializes this UnifiedTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnifiedTrack&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.normalizedTitle, normalizedTitle) || other.normalizedTitle == normalizedTitle)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.normalizedArtist, normalizedArtist) || other.normalizedArtist == normalizedArtist)&&(identical(other.album, album) || other.album == album)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&const DeepCollectionEquality().equals(other.sources, sources)&&(identical(other.preferredProvider, preferredProvider) || other.preferredProvider == preferredProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,normalizedTitle,artist,normalizedArtist,album,duration,artworkUrl,const DeepCollectionEquality().hash(sources),preferredProvider);

@override
String toString() {
  return 'UnifiedTrack(id: $id, title: $title, normalizedTitle: $normalizedTitle, artist: $artist, normalizedArtist: $normalizedArtist, album: $album, duration: $duration, artworkUrl: $artworkUrl, sources: $sources, preferredProvider: $preferredProvider)';
}


}

/// @nodoc
abstract mixin class $UnifiedTrackCopyWith<$Res>  {
  factory $UnifiedTrackCopyWith(UnifiedTrack value, $Res Function(UnifiedTrack) _then) = _$UnifiedTrackCopyWithImpl;
@useResult
$Res call({
 String id, String title, String normalizedTitle, String artist, String normalizedArtist, String? album,@DurationMillisecondsConverter() Duration? duration,@NullableUriStringConverter() Uri? artworkUrl, List<TrackSource> sources, MusicProvider? preferredProvider
});




}
/// @nodoc
class _$UnifiedTrackCopyWithImpl<$Res>
    implements $UnifiedTrackCopyWith<$Res> {
  _$UnifiedTrackCopyWithImpl(this._self, this._then);

  final UnifiedTrack _self;
  final $Res Function(UnifiedTrack) _then;

/// Create a copy of UnifiedTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? normalizedTitle = null,Object? artist = null,Object? normalizedArtist = null,Object? album = freezed,Object? duration = freezed,Object? artworkUrl = freezed,Object? sources = null,Object? preferredProvider = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,normalizedTitle: null == normalizedTitle ? _self.normalizedTitle : normalizedTitle // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,normalizedArtist: null == normalizedArtist ? _self.normalizedArtist : normalizedArtist // ignore: cast_nullable_to_non_nullable
as String,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as Uri?,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<TrackSource>,preferredProvider: freezed == preferredProvider ? _self.preferredProvider : preferredProvider // ignore: cast_nullable_to_non_nullable
as MusicProvider?,
  ));
}

}


/// Adds pattern-matching-related methods to [UnifiedTrack].
extension UnifiedTrackPatterns on UnifiedTrack {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnifiedTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnifiedTrack() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnifiedTrack value)  $default,){
final _that = this;
switch (_that) {
case _UnifiedTrack():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnifiedTrack value)?  $default,){
final _that = this;
switch (_that) {
case _UnifiedTrack() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String normalizedTitle,  String artist,  String normalizedArtist,  String? album, @DurationMillisecondsConverter()  Duration? duration, @NullableUriStringConverter()  Uri? artworkUrl,  List<TrackSource> sources,  MusicProvider? preferredProvider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnifiedTrack() when $default != null:
return $default(_that.id,_that.title,_that.normalizedTitle,_that.artist,_that.normalizedArtist,_that.album,_that.duration,_that.artworkUrl,_that.sources,_that.preferredProvider);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String normalizedTitle,  String artist,  String normalizedArtist,  String? album, @DurationMillisecondsConverter()  Duration? duration, @NullableUriStringConverter()  Uri? artworkUrl,  List<TrackSource> sources,  MusicProvider? preferredProvider)  $default,) {final _that = this;
switch (_that) {
case _UnifiedTrack():
return $default(_that.id,_that.title,_that.normalizedTitle,_that.artist,_that.normalizedArtist,_that.album,_that.duration,_that.artworkUrl,_that.sources,_that.preferredProvider);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String normalizedTitle,  String artist,  String normalizedArtist,  String? album, @DurationMillisecondsConverter()  Duration? duration, @NullableUriStringConverter()  Uri? artworkUrl,  List<TrackSource> sources,  MusicProvider? preferredProvider)?  $default,) {final _that = this;
switch (_that) {
case _UnifiedTrack() when $default != null:
return $default(_that.id,_that.title,_that.normalizedTitle,_that.artist,_that.normalizedArtist,_that.album,_that.duration,_that.artworkUrl,_that.sources,_that.preferredProvider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UnifiedTrack extends UnifiedTrack {
  const _UnifiedTrack({required this.id, required this.title, required this.normalizedTitle, required this.artist, required this.normalizedArtist, this.album, @DurationMillisecondsConverter() this.duration, @NullableUriStringConverter() this.artworkUrl, final  List<TrackSource> sources = const <TrackSource>[], this.preferredProvider}): _sources = sources,super._();
  factory _UnifiedTrack.fromJson(Map<String, dynamic> json) => _$UnifiedTrackFromJson(json);

@override final  String id;
@override final  String title;
@override final  String normalizedTitle;
@override final  String artist;
@override final  String normalizedArtist;
@override final  String? album;
@override@DurationMillisecondsConverter() final  Duration? duration;
@override@NullableUriStringConverter() final  Uri? artworkUrl;
 final  List<TrackSource> _sources;
@override@JsonKey() List<TrackSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

@override final  MusicProvider? preferredProvider;

/// Create a copy of UnifiedTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnifiedTrackCopyWith<_UnifiedTrack> get copyWith => __$UnifiedTrackCopyWithImpl<_UnifiedTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnifiedTrackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnifiedTrack&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.normalizedTitle, normalizedTitle) || other.normalizedTitle == normalizedTitle)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.normalizedArtist, normalizedArtist) || other.normalizedArtist == normalizedArtist)&&(identical(other.album, album) || other.album == album)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&const DeepCollectionEquality().equals(other._sources, _sources)&&(identical(other.preferredProvider, preferredProvider) || other.preferredProvider == preferredProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,normalizedTitle,artist,normalizedArtist,album,duration,artworkUrl,const DeepCollectionEquality().hash(_sources),preferredProvider);

@override
String toString() {
  return 'UnifiedTrack(id: $id, title: $title, normalizedTitle: $normalizedTitle, artist: $artist, normalizedArtist: $normalizedArtist, album: $album, duration: $duration, artworkUrl: $artworkUrl, sources: $sources, preferredProvider: $preferredProvider)';
}


}

/// @nodoc
abstract mixin class _$UnifiedTrackCopyWith<$Res> implements $UnifiedTrackCopyWith<$Res> {
  factory _$UnifiedTrackCopyWith(_UnifiedTrack value, $Res Function(_UnifiedTrack) _then) = __$UnifiedTrackCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String normalizedTitle, String artist, String normalizedArtist, String? album,@DurationMillisecondsConverter() Duration? duration,@NullableUriStringConverter() Uri? artworkUrl, List<TrackSource> sources, MusicProvider? preferredProvider
});




}
/// @nodoc
class __$UnifiedTrackCopyWithImpl<$Res>
    implements _$UnifiedTrackCopyWith<$Res> {
  __$UnifiedTrackCopyWithImpl(this._self, this._then);

  final _UnifiedTrack _self;
  final $Res Function(_UnifiedTrack) _then;

/// Create a copy of UnifiedTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? normalizedTitle = null,Object? artist = null,Object? normalizedArtist = null,Object? album = freezed,Object? duration = freezed,Object? artworkUrl = freezed,Object? sources = null,Object? preferredProvider = freezed,}) {
  return _then(_UnifiedTrack(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,normalizedTitle: null == normalizedTitle ? _self.normalizedTitle : normalizedTitle // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,normalizedArtist: null == normalizedArtist ? _self.normalizedArtist : normalizedArtist // ignore: cast_nullable_to_non_nullable
as String,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as Uri?,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<TrackSource>,preferredProvider: freezed == preferredProvider ? _self.preferredProvider : preferredProvider // ignore: cast_nullable_to_non_nullable
as MusicProvider?,
  ));
}


}

// dart format on
