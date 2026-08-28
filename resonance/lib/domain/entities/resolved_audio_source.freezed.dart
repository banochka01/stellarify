// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'resolved_audio_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ResolvedAudioSource {

@UriStringConverter() Uri get streamUrl; StreamProtocol get protocol; String? get codec; int? get bitrate; DateTime? get expiresAt; Map<String, String> get headers;
/// Create a copy of ResolvedAudioSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResolvedAudioSourceCopyWith<ResolvedAudioSource> get copyWith => _$ResolvedAudioSourceCopyWithImpl<ResolvedAudioSource>(this as ResolvedAudioSource, _$identity);

  /// Serializes this ResolvedAudioSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResolvedAudioSource&&(identical(other.streamUrl, streamUrl) || other.streamUrl == streamUrl)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.bitrate, bitrate) || other.bitrate == bitrate)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.headers, headers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,streamUrl,protocol,codec,bitrate,expiresAt,const DeepCollectionEquality().hash(headers));

@override
String toString() {
  return 'ResolvedAudioSource(streamUrl: $streamUrl, protocol: $protocol, codec: $codec, bitrate: $bitrate, expiresAt: $expiresAt, headers: $headers)';
}


}

/// @nodoc
abstract mixin class $ResolvedAudioSourceCopyWith<$Res>  {
  factory $ResolvedAudioSourceCopyWith(ResolvedAudioSource value, $Res Function(ResolvedAudioSource) _then) = _$ResolvedAudioSourceCopyWithImpl;
@useResult
$Res call({
@UriStringConverter() Uri streamUrl, StreamProtocol protocol, String? codec, int? bitrate, DateTime? expiresAt, Map<String, String> headers
});




}
/// @nodoc
class _$ResolvedAudioSourceCopyWithImpl<$Res>
    implements $ResolvedAudioSourceCopyWith<$Res> {
  _$ResolvedAudioSourceCopyWithImpl(this._self, this._then);

  final ResolvedAudioSource _self;
  final $Res Function(ResolvedAudioSource) _then;

/// Create a copy of ResolvedAudioSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streamUrl = null,Object? protocol = null,Object? codec = freezed,Object? bitrate = freezed,Object? expiresAt = freezed,Object? headers = null,}) {
  return _then(_self.copyWith(
streamUrl: null == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as Uri,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as StreamProtocol,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,bitrate: freezed == bitrate ? _self.bitrate : bitrate // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ResolvedAudioSource].
extension ResolvedAudioSourcePatterns on ResolvedAudioSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResolvedAudioSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResolvedAudioSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResolvedAudioSource value)  $default,){
final _that = this;
switch (_that) {
case _ResolvedAudioSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResolvedAudioSource value)?  $default,){
final _that = this;
switch (_that) {
case _ResolvedAudioSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@UriStringConverter()  Uri streamUrl,  StreamProtocol protocol,  String? codec,  int? bitrate,  DateTime? expiresAt,  Map<String, String> headers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResolvedAudioSource() when $default != null:
return $default(_that.streamUrl,_that.protocol,_that.codec,_that.bitrate,_that.expiresAt,_that.headers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@UriStringConverter()  Uri streamUrl,  StreamProtocol protocol,  String? codec,  int? bitrate,  DateTime? expiresAt,  Map<String, String> headers)  $default,) {final _that = this;
switch (_that) {
case _ResolvedAudioSource():
return $default(_that.streamUrl,_that.protocol,_that.codec,_that.bitrate,_that.expiresAt,_that.headers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@UriStringConverter()  Uri streamUrl,  StreamProtocol protocol,  String? codec,  int? bitrate,  DateTime? expiresAt,  Map<String, String> headers)?  $default,) {final _that = this;
switch (_that) {
case _ResolvedAudioSource() when $default != null:
return $default(_that.streamUrl,_that.protocol,_that.codec,_that.bitrate,_that.expiresAt,_that.headers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResolvedAudioSource extends ResolvedAudioSource {
  const _ResolvedAudioSource({@UriStringConverter() required this.streamUrl, required this.protocol, this.codec, this.bitrate, this.expiresAt, final  Map<String, String> headers = const <String, String>{}}): _headers = headers,super._();
  factory _ResolvedAudioSource.fromJson(Map<String, dynamic> json) => _$ResolvedAudioSourceFromJson(json);

@override@UriStringConverter() final  Uri streamUrl;
@override final  StreamProtocol protocol;
@override final  String? codec;
@override final  int? bitrate;
@override final  DateTime? expiresAt;
 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}


/// Create a copy of ResolvedAudioSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResolvedAudioSourceCopyWith<_ResolvedAudioSource> get copyWith => __$ResolvedAudioSourceCopyWithImpl<_ResolvedAudioSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResolvedAudioSourceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResolvedAudioSource&&(identical(other.streamUrl, streamUrl) || other.streamUrl == streamUrl)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.bitrate, bitrate) || other.bitrate == bitrate)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other._headers, _headers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,streamUrl,protocol,codec,bitrate,expiresAt,const DeepCollectionEquality().hash(_headers));

@override
String toString() {
  return 'ResolvedAudioSource(streamUrl: $streamUrl, protocol: $protocol, codec: $codec, bitrate: $bitrate, expiresAt: $expiresAt, headers: $headers)';
}


}

/// @nodoc
abstract mixin class _$ResolvedAudioSourceCopyWith<$Res> implements $ResolvedAudioSourceCopyWith<$Res> {
  factory _$ResolvedAudioSourceCopyWith(_ResolvedAudioSource value, $Res Function(_ResolvedAudioSource) _then) = __$ResolvedAudioSourceCopyWithImpl;
@override @useResult
$Res call({
@UriStringConverter() Uri streamUrl, StreamProtocol protocol, String? codec, int? bitrate, DateTime? expiresAt, Map<String, String> headers
});




}
/// @nodoc
class __$ResolvedAudioSourceCopyWithImpl<$Res>
    implements _$ResolvedAudioSourceCopyWith<$Res> {
  __$ResolvedAudioSourceCopyWithImpl(this._self, this._then);

  final _ResolvedAudioSource _self;
  final $Res Function(_ResolvedAudioSource) _then;

/// Create a copy of ResolvedAudioSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streamUrl = null,Object? protocol = null,Object? codec = freezed,Object? bitrate = freezed,Object? expiresAt = freezed,Object? headers = null,}) {
  return _then(_ResolvedAudioSource(
streamUrl: null == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as Uri,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as StreamProtocol,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,bitrate: freezed == bitrate ? _self.bitrate : bitrate // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
