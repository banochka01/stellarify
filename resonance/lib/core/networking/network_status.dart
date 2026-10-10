import 'package:connectivity_plus/connectivity_plus.dart';

/// Тип текущей сети. Нужен, чтобы различать качество по Wi‑Fi и по
/// мобильной сети и включать офлайн-режим без ошибок на экранах.
enum NetworkKind { wifi, mobile, offline }

NetworkKind networkKindOf(List<ConnectivityResult> results) {
  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return NetworkKind.offline;
  }
  // Ethernet/VPN/прочее считаем безлимитом, как Wi‑Fi.
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return NetworkKind.wifi;
  }
  if (results.contains(ConnectivityResult.mobile)) return NetworkKind.mobile;
  return NetworkKind.wifi;
}

/// Поток состояния сети: сначала текущее значение, затем изменения.
Stream<NetworkKind> watchNetworkKind([Connectivity? connectivity]) async* {
  final source = connectivity ?? Connectivity();
  try {
    yield networkKindOf(await source.checkConnectivity());
  } on Object {
    // Платформа без плагина: считаем, что сеть есть.
    yield NetworkKind.wifi;
    return;
  }
  yield* source.onConnectivityChanged.map(networkKindOf);
}
