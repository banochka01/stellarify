import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> playTrackOrOpenOfficial(WidgetRef ref, UnifiedTrack track) async {
  final provider =
      track.preferredProvider ?? track.sources.firstOrNull?.provider;
  if (provider == MusicProvider.youtube) {
    final url = track.sourceFor(MusicProvider.youtube)?.externalUrl;
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
    return;
  }
  final service = await ref.read(playbackServiceProvider.future);
  await service.playTrack(track);
}
