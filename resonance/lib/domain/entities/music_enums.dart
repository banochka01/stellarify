import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum MusicProvider { youtube, yandex, soundcloud }

@JsonEnum()
enum StreamProtocol { progressive, hls, dash }

@JsonEnum()
enum AudioQuality { low, medium, high, lossless }

@JsonEnum()
enum PlaybackRepeatMode { off, all, one }
