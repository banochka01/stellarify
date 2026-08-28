import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';

final class ProviderRegistry {
  ProviderRegistry({
    Iterable<MusicCatalogProvider> catalogs = const [],
    Iterable<AudioSourceResolver> resolvers = const [],
  }) : _catalogs = {for (final catalog in catalogs) catalog.provider: catalog},
       _resolvers = {
         for (final resolver in resolvers) resolver.provider: resolver,
       };

  final Map<MusicProvider, MusicCatalogProvider> _catalogs;
  final Map<MusicProvider, AudioSourceResolver> _resolvers;

  MusicCatalogProvider? catalogFor(MusicProvider provider) =>
      _catalogs[provider];

  AudioSourceResolver? resolverFor(MusicProvider provider) =>
      _resolvers[provider];
}
