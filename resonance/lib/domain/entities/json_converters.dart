import 'package:freezed_annotation/freezed_annotation.dart';

class DurationMillisecondsConverter implements JsonConverter<Duration?, int?> {
  const DurationMillisecondsConverter();

  @override
  Duration? fromJson(int? value) =>
      value == null ? null : Duration(milliseconds: value);

  @override
  int? toJson(Duration? value) => value?.inMilliseconds;
}

class UriStringConverter implements JsonConverter<Uri, String> {
  const UriStringConverter();

  @override
  Uri fromJson(String value) => Uri.parse(value);

  @override
  String toJson(Uri value) => value.toString();
}

class NullableUriStringConverter implements JsonConverter<Uri?, String?> {
  const NullableUriStringConverter();

  @override
  Uri? fromJson(String? value) => value == null ? null : Uri.parse(value);

  @override
  String? toJson(Uri? value) => value?.toString();
}
