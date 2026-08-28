// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_capabilities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderCapabilities {

 bool get supportsSearch; bool get supportsAuthentication; bool get supportsLibrary; bool get supportsPlaylists; bool get supportsRecommendations; bool get supportsDirectResolution;
/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderCapabilitiesCopyWith<ProviderCapabilities> get copyWith => _$ProviderCapabilitiesCopyWithImpl<ProviderCapabilities>(this as ProviderCapabilities, _$identity);

  /// Serializes this ProviderCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderCapabilities&&(identical(other.supportsSearch, supportsSearch) || other.supportsSearch == supportsSearch)&&(identical(other.supportsAuthentication, supportsAuthentication) || other.supportsAuthentication == supportsAuthentication)&&(identical(other.supportsLibrary, supportsLibrary) || other.supportsLibrary == supportsLibrary)&&(identical(other.supportsPlaylists, supportsPlaylists) || other.supportsPlaylists == supportsPlaylists)&&(identical(other.supportsRecommendations, supportsRecommendations) || other.supportsRecommendations == supportsRecommendations)&&(identical(other.supportsDirectResolution, supportsDirectResolution) || other.supportsDirectResolution == supportsDirectResolution));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supportsSearch,supportsAuthentication,supportsLibrary,supportsPlaylists,supportsRecommendations,supportsDirectResolution);

@override
String toString() {
  return 'ProviderCapabilities(supportsSearch: $supportsSearch, supportsAuthentication: $supportsAuthentication, supportsLibrary: $supportsLibrary, supportsPlaylists: $supportsPlaylists, supportsRecommendations: $supportsRecommendations, supportsDirectResolution: $supportsDirectResolution)';
}


}

/// @nodoc
abstract mixin class $ProviderCapabilitiesCopyWith<$Res>  {
  factory $ProviderCapabilitiesCopyWith(ProviderCapabilities value, $Res Function(ProviderCapabilities) _then) = _$ProviderCapabilitiesCopyWithImpl;
@useResult
$Res call({
 bool supportsSearch, bool supportsAuthentication, bool supportsLibrary, bool supportsPlaylists, bool supportsRecommendations, bool supportsDirectResolution
});




}
/// @nodoc
class _$ProviderCapabilitiesCopyWithImpl<$Res>
    implements $ProviderCapabilitiesCopyWith<$Res> {
  _$ProviderCapabilitiesCopyWithImpl(this._self, this._then);

  final ProviderCapabilities _self;
  final $Res Function(ProviderCapabilities) _then;

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supportsSearch = null,Object? supportsAuthentication = null,Object? supportsLibrary = null,Object? supportsPlaylists = null,Object? supportsRecommendations = null,Object? supportsDirectResolution = null,}) {
  return _then(_self.copyWith(
supportsSearch: null == supportsSearch ? _self.supportsSearch : supportsSearch // ignore: cast_nullable_to_non_nullable
as bool,supportsAuthentication: null == supportsAuthentication ? _self.supportsAuthentication : supportsAuthentication // ignore: cast_nullable_to_non_nullable
as bool,supportsLibrary: null == supportsLibrary ? _self.supportsLibrary : supportsLibrary // ignore: cast_nullable_to_non_nullable
as bool,supportsPlaylists: null == supportsPlaylists ? _self.supportsPlaylists : supportsPlaylists // ignore: cast_nullable_to_non_nullable
as bool,supportsRecommendations: null == supportsRecommendations ? _self.supportsRecommendations : supportsRecommendations // ignore: cast_nullable_to_non_nullable
as bool,supportsDirectResolution: null == supportsDirectResolution ? _self.supportsDirectResolution : supportsDirectResolution // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderCapabilities].
extension ProviderCapabilitiesPatterns on ProviderCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _ProviderCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool supportsSearch,  bool supportsAuthentication,  bool supportsLibrary,  bool supportsPlaylists,  bool supportsRecommendations,  bool supportsDirectResolution)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
return $default(_that.supportsSearch,_that.supportsAuthentication,_that.supportsLibrary,_that.supportsPlaylists,_that.supportsRecommendations,_that.supportsDirectResolution);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool supportsSearch,  bool supportsAuthentication,  bool supportsLibrary,  bool supportsPlaylists,  bool supportsRecommendations,  bool supportsDirectResolution)  $default,) {final _that = this;
switch (_that) {
case _ProviderCapabilities():
return $default(_that.supportsSearch,_that.supportsAuthentication,_that.supportsLibrary,_that.supportsPlaylists,_that.supportsRecommendations,_that.supportsDirectResolution);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool supportsSearch,  bool supportsAuthentication,  bool supportsLibrary,  bool supportsPlaylists,  bool supportsRecommendations,  bool supportsDirectResolution)?  $default,) {final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
return $default(_that.supportsSearch,_that.supportsAuthentication,_that.supportsLibrary,_that.supportsPlaylists,_that.supportsRecommendations,_that.supportsDirectResolution);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderCapabilities implements ProviderCapabilities {
  const _ProviderCapabilities({this.supportsSearch = false, this.supportsAuthentication = false, this.supportsLibrary = false, this.supportsPlaylists = false, this.supportsRecommendations = false, this.supportsDirectResolution = false});
  factory _ProviderCapabilities.fromJson(Map<String, dynamic> json) => _$ProviderCapabilitiesFromJson(json);

@override@JsonKey() final  bool supportsSearch;
@override@JsonKey() final  bool supportsAuthentication;
@override@JsonKey() final  bool supportsLibrary;
@override@JsonKey() final  bool supportsPlaylists;
@override@JsonKey() final  bool supportsRecommendations;
@override@JsonKey() final  bool supportsDirectResolution;

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCapabilitiesCopyWith<_ProviderCapabilities> get copyWith => __$ProviderCapabilitiesCopyWithImpl<_ProviderCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCapabilities&&(identical(other.supportsSearch, supportsSearch) || other.supportsSearch == supportsSearch)&&(identical(other.supportsAuthentication, supportsAuthentication) || other.supportsAuthentication == supportsAuthentication)&&(identical(other.supportsLibrary, supportsLibrary) || other.supportsLibrary == supportsLibrary)&&(identical(other.supportsPlaylists, supportsPlaylists) || other.supportsPlaylists == supportsPlaylists)&&(identical(other.supportsRecommendations, supportsRecommendations) || other.supportsRecommendations == supportsRecommendations)&&(identical(other.supportsDirectResolution, supportsDirectResolution) || other.supportsDirectResolution == supportsDirectResolution));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supportsSearch,supportsAuthentication,supportsLibrary,supportsPlaylists,supportsRecommendations,supportsDirectResolution);

@override
String toString() {
  return 'ProviderCapabilities(supportsSearch: $supportsSearch, supportsAuthentication: $supportsAuthentication, supportsLibrary: $supportsLibrary, supportsPlaylists: $supportsPlaylists, supportsRecommendations: $supportsRecommendations, supportsDirectResolution: $supportsDirectResolution)';
}


}

/// @nodoc
abstract mixin class _$ProviderCapabilitiesCopyWith<$Res> implements $ProviderCapabilitiesCopyWith<$Res> {
  factory _$ProviderCapabilitiesCopyWith(_ProviderCapabilities value, $Res Function(_ProviderCapabilities) _then) = __$ProviderCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 bool supportsSearch, bool supportsAuthentication, bool supportsLibrary, bool supportsPlaylists, bool supportsRecommendations, bool supportsDirectResolution
});




}
/// @nodoc
class __$ProviderCapabilitiesCopyWithImpl<$Res>
    implements _$ProviderCapabilitiesCopyWith<$Res> {
  __$ProviderCapabilitiesCopyWithImpl(this._self, this._then);

  final _ProviderCapabilities _self;
  final $Res Function(_ProviderCapabilities) _then;

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supportsSearch = null,Object? supportsAuthentication = null,Object? supportsLibrary = null,Object? supportsPlaylists = null,Object? supportsRecommendations = null,Object? supportsDirectResolution = null,}) {
  return _then(_ProviderCapabilities(
supportsSearch: null == supportsSearch ? _self.supportsSearch : supportsSearch // ignore: cast_nullable_to_non_nullable
as bool,supportsAuthentication: null == supportsAuthentication ? _self.supportsAuthentication : supportsAuthentication // ignore: cast_nullable_to_non_nullable
as bool,supportsLibrary: null == supportsLibrary ? _self.supportsLibrary : supportsLibrary // ignore: cast_nullable_to_non_nullable
as bool,supportsPlaylists: null == supportsPlaylists ? _self.supportsPlaylists : supportsPlaylists // ignore: cast_nullable_to_non_nullable
as bool,supportsRecommendations: null == supportsRecommendations ? _self.supportsRecommendations : supportsRecommendations // ignore: cast_nullable_to_non_nullable
as bool,supportsDirectResolution: null == supportsDirectResolution ? _self.supportsDirectResolution : supportsDirectResolution // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
