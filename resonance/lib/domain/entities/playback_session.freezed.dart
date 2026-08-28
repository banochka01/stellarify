// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackSession {

 List<UnifiedTrack> get queue; int get currentIndex; double get volume;
/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackSessionCopyWith<PlaybackSession> get copyWith => _$PlaybackSessionCopyWithImpl<PlaybackSession>(this as PlaybackSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackSession&&const DeepCollectionEquality().equals(other.queue, queue)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(queue),currentIndex,volume);

@override
String toString() {
  return 'PlaybackSession(queue: $queue, currentIndex: $currentIndex, volume: $volume)';
}


}

/// @nodoc
abstract mixin class $PlaybackSessionCopyWith<$Res>  {
  factory $PlaybackSessionCopyWith(PlaybackSession value, $Res Function(PlaybackSession) _then) = _$PlaybackSessionCopyWithImpl;
@useResult
$Res call({
 List<UnifiedTrack> queue, int currentIndex, double volume
});




}
/// @nodoc
class _$PlaybackSessionCopyWithImpl<$Res>
    implements $PlaybackSessionCopyWith<$Res> {
  _$PlaybackSessionCopyWithImpl(this._self, this._then);

  final PlaybackSession _self;
  final $Res Function(PlaybackSession) _then;

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? queue = null,Object? currentIndex = null,Object? volume = null,}) {
  return _then(_self.copyWith(
queue: null == queue ? _self.queue : queue // ignore: cast_nullable_to_non_nullable
as List<UnifiedTrack>,currentIndex: null == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaybackSession].
extension PlaybackSessionPatterns on PlaybackSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackSession value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackSession value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UnifiedTrack> queue,  int currentIndex,  double volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
return $default(_that.queue,_that.currentIndex,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UnifiedTrack> queue,  int currentIndex,  double volume)  $default,) {final _that = this;
switch (_that) {
case _PlaybackSession():
return $default(_that.queue,_that.currentIndex,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UnifiedTrack> queue,  int currentIndex,  double volume)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
return $default(_that.queue,_that.currentIndex,_that.volume);case _:
  return null;

}
}

}

/// @nodoc


class _PlaybackSession implements PlaybackSession {
  const _PlaybackSession({final  List<UnifiedTrack> queue = const <UnifiedTrack>[], this.currentIndex = -1, this.volume = 70}): _queue = queue;
  

 final  List<UnifiedTrack> _queue;
@override@JsonKey() List<UnifiedTrack> get queue {
  if (_queue is EqualUnmodifiableListView) return _queue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_queue);
}

@override@JsonKey() final  int currentIndex;
@override@JsonKey() final  double volume;

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackSessionCopyWith<_PlaybackSession> get copyWith => __$PlaybackSessionCopyWithImpl<_PlaybackSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackSession&&const DeepCollectionEquality().equals(other._queue, _queue)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_queue),currentIndex,volume);

@override
String toString() {
  return 'PlaybackSession(queue: $queue, currentIndex: $currentIndex, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$PlaybackSessionCopyWith<$Res> implements $PlaybackSessionCopyWith<$Res> {
  factory _$PlaybackSessionCopyWith(_PlaybackSession value, $Res Function(_PlaybackSession) _then) = __$PlaybackSessionCopyWithImpl;
@override @useResult
$Res call({
 List<UnifiedTrack> queue, int currentIndex, double volume
});




}
/// @nodoc
class __$PlaybackSessionCopyWithImpl<$Res>
    implements _$PlaybackSessionCopyWith<$Res> {
  __$PlaybackSessionCopyWithImpl(this._self, this._then);

  final _PlaybackSession _self;
  final $Res Function(_PlaybackSession) _then;

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? queue = null,Object? currentIndex = null,Object? volume = null,}) {
  return _then(_PlaybackSession(
queue: null == queue ? _self._queue : queue // ignore: cast_nullable_to_non_nullable
as List<UnifiedTrack>,currentIndex: null == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
