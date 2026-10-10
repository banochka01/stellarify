import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/desktop/quick_actions.dart';
import 'package:resonance/core/diagnostics/client_error_reporter.dart';
import 'package:resonance/core/playback/android_home_widget.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/settings/service_status_screen.dart';

void main() {
  test('quick actions parse jump-list, widget and plain forms', () {
    expect(QuickAction.parse('--action=wave'), QuickAction.wave);
    expect(QuickAction.parse('lastPlaylist'), QuickAction.lastPlaylist);
    expect(QuickAction.parse('resonance://action/pause'), QuickAction.pause);
    expect(QuickAction.parse('--other'), isNull);
    expect(QuickAction.parse(null), isNull);
  });

  test('service status report parses server payload', () {
    final report = ServiceStatusReport.fromJson({
      'overall': 'degraded',
      'checkedAt': '2026-10-11T10:00:00.000Z',
      'services': [
        {
          'id': 'yandex',
          'label': 'Яндекс Музыка',
          'state': 'ok',
          'latencyMs': 120,
        },
        {'id': 'vk', 'label': 'VK', 'state': 'unconfigured'},
        {'id': 'x', 'state': 'weird'},
      ],
    });
    expect(report.overall, ServiceHealthState.degraded);
    expect(report.services, hasLength(3));
    expect(report.services.first.latency, const Duration(milliseconds: 120));
    expect(report.services[1].state, ServiceHealthState.unconfigured);
    expect(report.services[2].state, ServiceHealthState.unknown);
    expect(healthLabel(ServiceHealthState.down), 'Недоступен');
  });

  test('error reporter strips urls, dedupes and caps per session', () async {
    final sent = <Map<String, dynamic>>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(Map<String, dynamic>.from(options.data as Map));
            handler.resolve(Response(requestOptions: options, statusCode: 202));
          },
        ),
      );
    final reporter = ClientErrorReporter(
      dio: dio,
      endpoint: () => Uri.parse('https://example.test/api/v1/client-reports'),
      maxPerSession: 2,
    );
    expect(
      await reporter.report(
        ClientReportKind.playback,
        'failed https://cdn.example/stream?token=secret',
        provider: 'yandex',
      ),
      isTrue,
    );
    expect(sent.single['message'], 'failed <url>');
    expect(sent.single['provider'], 'yandex');
    expect(
      await reporter.report(
        ClientReportKind.playback,
        'failed https://cdn.example/stream?token=secret',
      ),
      isFalse,
    );
    expect(await reporter.report(ClientReportKind.crash, 'boom'), isTrue);
    expect(await reporter.report(ClientReportKind.crash, 'another'), isFalse);
  });

  test('home widget payload falls back to the wave prompt', () {
    final payload = homeWidgetPayload(const ResonancePlaybackState());
    expect(payload['title'], 'Resonance');
    expect(payload['artist'], 'Нажмите «Моя волна»');
    expect(payload['playing'], isFalse);
  });
}
