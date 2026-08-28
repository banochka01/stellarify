// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResonancePlaybackState {

 List<UnifiedTrack> get queue; int get currentIndex; bool get playing; bool get buffering; Duration get position; Duration get duration; double get volume; bool get shuffle; PlaybackRepeatMode get repeatMode; TrackSource? get activeTrackSource; ResolvedAudioSource? get activeAudioSource; String? get errorMessage;
/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResonancePlaybackStateCopyWith<ResonancePlaybackState> get copyWith => _$ResonancePlaybackStateCopyWithImpl<ResonancePlaybackState>(this as ResonancePlaybackState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResonancePlaybackState&&const DeepCollectionEquality().equals(other.queue, queue)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.buffering, buffering) || other.buffering == buffering)&&(identical(other.position, position) || other.position == position)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.shuffle, shuffle) || other.shuffle == shuffle)&&(identical(other.repeatMode, repeatMode) || other.repeatMode == repeatMode)&&(identical(other.activeTrackSource, activeTrackSource) || other.activeTrackSource == activeTrackSource)&&(identical(other.activeAudioSource, activeAudioSource) || other.activeAudioSource == activeAudioSource)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(queue),currentIndex,playing,buffering,position,duration,volume,shuffle,repeatMode,activeTrackSource,activeAudioSource,errorMessage);

@override
String toString() {
  return 'ResonancePlaybackState(queue: $queue, currentIndex: $currentIndex, playing: $playing, buffering: $buffering, position: $position, duration: $duration, volume: $volume, shuffle: $shuffle, repeatMode: $repeatMode, activeTrackSource: $activeTrackSource, activeAudioSource: $activeAudioSource, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $ResonancePlaybackStateCopyWith<$Res>  {
  factory $ResonancePlaybackStateCopyWith(ResonancePlaybackState value, $Res Function(ResonancePlaybackState) _then) = _$ResonancePlaybackStateCopyWithImpl;
@useResult
$Res call({
 List<UnifiedTrack> queue, int currentIndex, bool playing, bool buffering, Duration position, Duration duration, double volume, bool shuffle, PlaybackRepeatMode repeatMode, TrackSource? activeTrackSource, ResolvedAudioSource? activeAudioSource, String? errorMessage
});


$TrackSourceCopyWith<$Res>? get activeTrackSource;$ResolvedAudioSourceCopyWith<$Res>? get activeAudioSource;

}
/// @nodoc
class _$ResonancePlaybackStateCopyWithImpl<$Res>
    implements $ResonancePlaybackStateCopyWith<$Res> {
  _$ResonancePlaybackStateCopyWithImpl(this._self, this._then);

  final ResonancePlaybackState _self;
  final $Res Function(ResonancePlaybackState) _then;

/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? queue = null,Object? currentIndex = null,Object? playing = null,Object? buffering = null,Object? position = null,Object? duration = null,Object? volume = null,Object? shuffle = null,Object? repeatMode = null,Object? activeTrackSource = freezed,Object? activeAudioSource = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
queue: null == queue ? _self.queue : queue // ignore: cast_nullable_to_non_nullable
as List<UnifiedTrack>,currentIndex: null == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,shuffle: null == shuffle ? _self.shuffle : shuffle // ignore: cast_nullable_to_non_nullable
as bool,repeatMode: null == repeatMode ? _self.repeatMode : repeatMode // ignore: cast_nullable_to_non_nullable
as PlaybackRepeatMode,activeTrackSource: freezed == activeTrackSource ? _self.activeTrackSource : activeTrackSource // ignore: cast_nullable_to_non_nullable
as TrackSource?,activeAudioSource: freezed == activeAudioSource ? _self.activeAudioSource : activeAudioSource // ignore: cast_nullable_to_non_nullable
as ResolvedAudioSource?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrackSourceCopyWith<$Res>? get activeTrackSource {
    if (_self.activeTrackSource == null) {
    return null;
  }

  return $TrackSourceCopyWith<$Res>(_self.activeTrackSource!, (value) {
    return _then(_self.copyWith(activeTrackSource: value));
  });
}/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResolvedAudioSourceCopyWith<$Res>? get activeAudioSource {
    if (_self.activeAudioSource == null) {
    return null;
  }

  return $ResolvedAudioSourceCopyWith<$Res>(_self.activeAudioSource!, (value) {
    return _then(_self.copyWith(activeAudioSource: value));
  });
}
}


/// Adds pattern-matching-related methods to [ResonancePlaybackState].
extension ResonancePlaybackStatePatterns on ResonancePlaybackState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResonancePlaybackState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResonancePlaybackState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResonancePlaybackState value)  $default,){
final _that = this;
switch (_that) {
case _ResonancePlaybackState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResonancePlaybackState value)?  $default,){
final _that = this;
switch (_that) {
case _ResonancePlaybackState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UnifiedTrack> queue,  int currentIndex,  bool playing,  bool buffering,  Duration position,  Duration duration,  double volume,  bool shuffle,  PlaybackRepeatMode repeatMode,  TrackSource? activeTrackSource,  ResolvedAudioSource? activeAudioSource,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResonancePlaybackState() when $default != null:
return $default(_that.queue,_that.currentIndex,_that.playing,_that.buffering,_that.position,_that.duration,_that.volume,_that.shuffle,_that.repeatMode,_that.activeTrackSource,_that.activeAudioSource,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UnifiedTrack> queue,  int currentIndex,  bool playing,  bool buffering,  Duration position,  Duration duration,  double volume,  bool shuffle,  PlaybackRepeatMode repeatMode,  TrackSource? activeTrackSource,  ResolvedAudioSource? activeAudioSource,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _ResonancePlaybackState():
return $default(_that.queue,_that.currentIndex,_that.playing,_that.buffering,_that.position,_that.duration,_that.volume,_that.shuffle,_that.repeatMode,_that.activeTrackSource,_that.activeAudioSource,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UnifiedTrack> queue,  int currentIndex,  bool playing,  bool buffering,  Duration position,  Duration duration,  double volume,  bool shuffle,  PlaybackRepeatMode repeatMode,  TrackSource? activeTrackSource,  ResolvedAudioSource? activeAudioSource,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _ResonancePlaybackState() when $default != null:
return $default(_that.queue,_that.currentIndex,_that.playing,_that.buffering,_that.position,_that.duration,_that.volume,_that.shuffle,_that.repeatMode,_that.activeTrackSource,_that.activeAudioSource,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _ResonancePlaybackState extends ResonancePlaybackState {
  const _ResonancePlaybackState({final  List<UnifiedTrack> queue = const <UnifiedTrack>[], this.currentIndex = -1, this.playing = false, this.buffering = false, this.position = Duration.zero, this.duration = Duration.zero, this.volume = 70, this.shuffle = false, this.repeatMode = PlaybackRepeatMode.off, this.activeTrackSource, this.activeAudioSource, this.errorMessage}): _queue = queue,super._();
  

 final  List<UnifiedTrack> _queue;
@override@JsonKey() List<UnifiedTrack> get queue {
  if (_queue is EqualUnmodifiableListView) return _queue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_queue);
}

@override@JsonKey() final  int currentIndex;
@override@JsonKey() final  bool playing;
@override@JsonKey() final  bool buffering;
@override@JsonKey() final  Duration position;
@override@JsonKey() final  Duration duration;
@override@JsonKey() final  double volume;
@override@JsonKey() final  bool shuffle;
@override@JsonKey() final  PlaybackRepeatMode repeatMode;
@override final  TrackSource? activeTrackSource;
@override final  ResolvedAudioSource? activeAudioSource;
@override final  String? errorMessage;

/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResonancePlaybackStateCopyWith<_ResonancePlaybackState> get copyWith => __$ResonancePlaybackStateCopyWithImpl<_ResonancePlaybackState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResonancePlaybackState&&const DeepCollectionEquality().equals(other._queue, _queue)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.buffering, buffering) || other.buffering == buffering)&&(identical(other.position, position) || other.position == position)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.shuffle, shuffle) || other.shuffle == shuffle)&&(identical(other.repeatMode, repeatMode) || other.repeatMode == repeatMode)&&(identical(other.activeTrackSource, activeTrackSource) || other.activeTrackSource == activeTrackSource)&&(identical(other.activeAudioSource, activeAudioSource) || other.activeAudioSource == activeAudioSource)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_queue),currentIndex,playing,buffering,position,duration,volume,shuffle,repeatMode,activeTrackSource,activeAudioSource,errorMessage);

@override
String toString() {
  return 'ResonancePlaybackState(queue: $queue, currentIndex: $currentIndex, playing: $playing, buffering: $buffering, position: $position, duration: $duration, volume: $volume, shuffle: $shuffle, repeatMode: $repeatMode, activeTrackSource: $activeTrackSource, activeAudioSource: $activeAudioSource, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$ResonancePlaybackStateCopyWith<$Res> implements $ResonancePlaybackStateCopyWith<$Res> {
  factory _$ResonancePlaybackStateCopyWith(_ResonancePlaybackState value, $Res Function(_ResonancePlaybackState) _then) = __$ResonancePlaybackStateCopyWithImpl;
@override @useResult
$Res call({
 List<UnifiedTrack> queue, int currentIndex, bool playing, bool buffering, Duration position, Duration duration, double volume, bool shuffle, PlaybackRepeatMode repeatMode, TrackSource? activeTrackSource, ResolvedAudioSource? activeAudioSource, String? errorMessage
});


@override $TrackSourceCopyWith<$Res>? get activeTrackSource;@override $ResolvedAudioSourceCopyWith<$Res>? get activeAudioSource;

}
/// @nodoc
class __$ResonancePlaybackStateCopyWithImpl<$Res>
    implements _$ResonancePlaybackStateCopyWith<$Res> {
  __$ResonancePlaybackStateCopyWithImpl(this._self, this._then);

  final _ResonancePlaybackState _self;
  final $Res Function(_ResonancePlaybackState) _then;

/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? queue = null,Object? currentIndex = null,Object? playing = null,Object? buffering = null,Object? position = null,Object? duration = null,Object? volume = null,Object? shuffle = null,Object? repeatMode = null,Object? activeTrackSource = freezed,Object? activeAudioSource = freezed,Object? errorMessage = freezed,}) {
  return _then(_ResonancePlaybackState(
queue: null == queue ? _self._queue : queue // ignore: cast_nullable_to_non_nullable
as List<UnifiedTrack>,currentIndex: null == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,shuffle: null == shuffle ? _self.shuffle : shuffle // ignore: cast_nullable_to_non_nullable
as bool,repeatMode: null == repeatMode ? _self.repeatMode : repeatMode // ignore: cast_nullable_to_non_nullable
as PlaybackRepeatMode,activeTrackSource: freezed == activeTrackSource ? _self.activeTrackSource : activeTrackSource // ignore: cast_nullable_to_non_nullable
as TrackSource?,activeAudioSource: freezed == activeAudioSource ? _self.activeAudioSource : activeAudioSource // ignore: cast_nullable_to_non_nullable
as ResolvedAudioSource?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrackSourceCopyWith<$Res>? get activeTrackSource {
    if (_self.activeTrackSource == null) {
    return null;
  }

  return $TrackSourceCopyWith<$Res>(_self.activeTrackSource!, (value) {
    return _then(_self.copyWith(activeTrackSource: value));
  });
}/// Create a copy of ResonancePlaybackState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResolvedAudioSourceCopyWith<$Res>? get activeAudioSource {
    if (_self.activeAudioSource == null) {
    return null;
  }

  return $ResolvedAudioSourceCopyWith<$Res>(_self.activeAudioSource!, (value) {
    return _then(_self.copyWith(activeAudioSource: value));
  });
}
}

// dart format on
