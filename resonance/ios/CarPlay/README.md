# CarPlay (выключено по умолчанию)

Код: `ios/Runner/CarPlaySceneDelegate.swift` (CPListTemplate: Недавнее / Плейлисты / Волна / Миксы → CPNowPlayingTemplate), Dart-сторона: `lib/core/playback/carplay_bridge.dart` (канал `app.resonance/carplay`, общий каталог с Android Auto).

CarPlay-сцена не объявлена в `Info.plist`, поэтому в обычных и unsigned-сборках не активируется. Для аудио-приложения CarPlay Apple должна выдать entitlement `com.apple.developer.carplay-audio` для команды разработчика; unsigned IPA его нести не может.

Включение: `bash ios/CarPlay/enable_carplay.sh` (добавляет сцену `CPTemplateApplicationSceneSessionRoleApplication` и entitlements). В CI это делает `ios-testflight.yml` при переменной репозитория `RESONANCE_CARPLAY=1` и профиле с этим entitlement.
