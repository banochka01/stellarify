import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

enum ServiceHealthState { ok, degraded, down, unconfigured, unknown }

final class ServiceHealthEntry {
  const ServiceHealthEntry({
    required this.id,
    required this.label,
    required this.state,
    this.latency,
    this.error,
  });

  factory ServiceHealthEntry.fromJson(Map<String, dynamic> json) {
    final latency = json['latencyMs'];
    return ServiceHealthEntry(
      id: '${json['id'] ?? ''}',
      label: '${json['label'] ?? json['id'] ?? ''}',
      state: parseHealthState(json['state']),
      latency: latency is num ? Duration(milliseconds: latency.round()) : null,
      error: json['error'] as String?,
    );
  }

  final String id;
  final String label;
  final ServiceHealthState state;
  final Duration? latency;
  final String? error;
}

final class ServiceStatusReport {
  const ServiceStatusReport({
    required this.overall,
    required this.services,
    this.checkedAt,
  });

  factory ServiceStatusReport.fromJson(Map<String, dynamic> json) {
    final services = json['services'];
    return ServiceStatusReport(
      overall: parseHealthState(json['overall']),
      checkedAt: DateTime.tryParse('${json['checkedAt']}')?.toLocal(),
      services: [
        if (services is List)
          for (final item in services)
            if (item is Map<String, dynamic>) ServiceHealthEntry.fromJson(item),
      ],
    );
  }

  final ServiceHealthState overall;
  final DateTime? checkedAt;
  final List<ServiceHealthEntry> services;
}

ServiceHealthState parseHealthState(Object? value) =>
    ServiceHealthState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => ServiceHealthState.unknown,
    );

final serviceStatusProvider = FutureProvider.autoDispose<ServiceStatusReport>((
  ref,
) async {
  final dio = ref.watch(resonanceHttpClientProvider).dio;
  final response = await dio.getUri<Map<String, dynamic>>(
    BackendEndpoint.requireCurrent().resolve('/api/v1/status'),
    options: Options(receiveTimeout: const Duration(seconds: 25)),
  );
  return ServiceStatusReport.fromJson(response.data ?? const {});
});

class ServiceStatusScreen extends ConsumerWidget {
  const ServiceStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serviceStatusProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Состояние сервисов'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Проверить снова',
            onPressed: () => ref.invalidate(serviceStatusProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serviceStatusProvider);
          await ref
              .read(serviceStatusProvider.future)
              .catchError(
                (_) => const ServiceStatusReport(
                  overall: ServiceHealthState.unknown,
                  services: [],
                ),
              );
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: switch (status) {
            AsyncData(:final value) => [
              _OverallCard(report: value),
              const SizedBox(height: 12),
              for (final service in value.services) _ServiceTile(service),
            ],
            AsyncError() => [
              const _OverallCard(
                report: ServiceStatusReport(
                  overall: ServiceHealthState.down,
                  services: [],
                ),
                serverUnreachable: true,
              ),
            ],
            _ => const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          },
        ),
      ),
    );
  }
}

String healthLabel(ServiceHealthState state) => switch (state) {
  ServiceHealthState.ok => 'Работает',
  ServiceHealthState.degraded => 'Медленно',
  ServiceHealthState.down => 'Недоступен',
  ServiceHealthState.unconfigured => 'Не подключён на сервере',
  ServiceHealthState.unknown => 'Неизвестно',
};

Color healthColor(ServiceHealthState state) => switch (state) {
  ServiceHealthState.ok => ResonanceColors.success,
  ServiceHealthState.degraded => ResonanceColors.yandex,
  ServiceHealthState.down => ResonanceColors.youtube,
  _ => ResonanceColors.muted,
};

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.report, this.serverUnreachable = false});

  final ServiceStatusReport report;
  final bool serverUnreachable;

  @override
  Widget build(BuildContext context) {
    final color = healthColor(report.overall);
    final title = serverUnreachable
        ? 'Сервер Resonance недоступен'
        : switch (report.overall) {
            ServiceHealthState.ok => 'Все сервисы работают',
            ServiceHealthState.degraded =>
              'Часть сервисов работает с перебоями',
            ServiceHealthState.down => 'Сервисы недоступны',
            _ => 'Нет данных о сервисах',
          };
    final checked = report.checkedAt;
    return Card(
      child: ListTile(
        leading: Icon(Icons.monitor_heart_rounded, color: color, size: 32),
        title: Text(title),
        subtitle: Text(
          serverUnreachable
              ? 'Проверьте подключение к интернету или адрес сервера'
              : checked == null
              ? 'Проверка выполнена сервером'
              : 'Проверено в ${checked.hour.toString().padLeft(2, '0')}:'
                    '${checked.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.service);

  final ServiceHealthEntry service;

  @override
  Widget build(BuildContext context) {
    final color = healthColor(service.state);
    final latency = service.latency;
    final details = [
      healthLabel(service.state),
      if (latency != null && service.state != ServiceHealthState.unconfigured)
        '${latency.inMilliseconds} мс',
      if (service.error == 'timeout') 'нет ответа',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          title: Text(service.label),
          subtitle: Text(details),
        ),
      ),
    );
  }
}

/// Small helper for Settings: opens the status screen.
void openServiceStatus(BuildContext context) {
  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ServiceStatusScreen()),
    ),
  );
}
