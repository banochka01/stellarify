// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrackSource {

 MusicProvider get provider; String get externalId;@UriStringConverter() Uri get externalUrl; Map<String, dynamic> get metadata;
/// Create a copy of TrackSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackSourceCopyWith<TrackSource> get copyWith => _$TrackSourceCopyWithImpl<TrackSource>(this as TrackSource, _$identity);

  /// Serializes this TrackSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackSource&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.externalUrl, externalUrl) || other.externalUrl == externalUrl)&&const DeepCollectionEquality().equals(other.metadata, metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,provider,externalId,externalUrl,const DeepCollectionEquality().hash(metadata));

@override
String toString() {
  return 'TrackSource(provider: $provider, externalId: $externalId, externalUrl: $externalUrl, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $TrackSourceCopyWith<$Res>  {
  factory $TrackSourceCopyWith(TrackSource value, $Res Function(TrackSource) _then) = _$TrackSourceCopyWithImpl;
@useResult
$Res call({
 MusicProvider provider, String externalId,@UriStringConverter() Uri externalUrl, Map<String, dynamic> metadata
});




}
/// @nodoc
class _$TrackSourceCopyWithImpl<$Res>
    implements $TrackSourceCopyWith<$Res> {
  _$TrackSourceCopyWithImpl(this._self, this._then);

  final TrackSource _self;
  final $Res Function(TrackSource) _then;

/// Create a copy of TrackSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? provider = null,Object? externalId = null,Object? externalUrl = null,Object? metadata = null,}) {
  return _then(_self.copyWith(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as MusicProvider,externalId: null == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String,externalUrl: null == externalUrl ? _self.externalUrl : externalUrl // ignore: cast_nullable_to_non_nullable
as Uri,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackSource].
extension TrackSourcePatterns on TrackSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackSource value)  $default,){
final _that = this;
switch (_that) {
case _TrackSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackSource value)?  $default,){
final _that = this;
switch (_that) {
case _TrackSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MusicProvider provider,  String externalId, @UriStringConverter()  Uri externalUrl,  Map<String, dynamic> metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackSource() when $default != null:
return $default(_that.provider,_that.externalId,_that.externalUrl,_that.metadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MusicProvider provider,  String externalId, @UriStringConverter()  Uri externalUrl,  Map<String, dynamic> metadata)  $default,) {final _that = this;
switch (_that) {
case _TrackSource():
return $default(_that.provider,_that.externalId,_that.externalUrl,_that.metadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MusicProvider provider,  String externalId, @UriStringConverter()  Uri externalUrl,  Map<String, dynamic> metadata)?  $default,) {final _that = this;
switch (_that) {
case _TrackSource() when $default != null:
return $default(_that.provider,_that.externalId,_that.externalUrl,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackSource implements TrackSource {
  const _TrackSource({required this.provider, required this.externalId, @UriStringConverter() required this.externalUrl, final  Map<String, dynamic> metadata = const <String, dynamic>{}}): _metadata = metadata;
  factory _TrackSource.fromJson(Map<String, dynamic> json) => _$TrackSourceFromJson(json);

@override final  MusicProvider provider;
@override final  String externalId;
@override@UriStringConverter() final  Uri externalUrl;
 final  Map<String, dynamic> _metadata;
@override@JsonKey() Map<String, dynamic> get metadata {
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metadata);
}


/// Create a copy of TrackSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackSourceCopyWith<_TrackSource> get copyWith => __$TrackSourceCopyWithImpl<_TrackSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackSourceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackSource&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.externalUrl, externalUrl) || other.externalUrl == externalUrl)&&const DeepCollectionEquality().equals(other._metadata, _metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,provider,externalId,externalUrl,const DeepCollectionEquality().hash(_metadata));

@override
String toString() {
  return 'TrackSource(provider: $provider, externalId: $externalId, externalUrl: $externalUrl, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$TrackSourceCopyWith<$Res> implements $TrackSourceCopyWith<$Res> {
  factory _$TrackSourceCopyWith(_TrackSource value, $Res Function(_TrackSource) _then) = __$TrackSourceCopyWithImpl;
@override @useResult
$Res call({
 MusicProvider provider, String externalId,@UriStringConverter() Uri externalUrl, Map<String, dynamic> metadata
});




}
/// @nodoc
class __$TrackSourceCopyWithImpl<$Res>
    implements _$TrackSourceCopyWith<$Res> {
  __$TrackSourceCopyWithImpl(this._self, this._then);

  final _TrackSource _self;
  final $Res Function(_TrackSource) _then;

/// Create a copy of TrackSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? provider = null,Object? externalId = null,Object? externalUrl = null,Object? metadata = null,}) {
  return _then(_TrackSource(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as MusicProvider,externalId: null == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String,externalUrl: null == externalUrl ? _self.externalUrl : externalUrl // ignore: cast_nullable_to_non_nullable
as Uri,metadata: null == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
