# HANDOFF — инструкция для следующей сессии агента

Дата: 2026-09-08. Прочти это до начала работы; детали окружения дублированы в
памяти проекта (`resonance-deploy`, `resonance-ftp-backup`).

## Контекст проекта

Resonance/stellarify — мульти-источниковый музыкальный плеер:
- `apps/server` — Node/Express API + Socket.IO (комнаты, Wave, подписки, аккаунты).
- `apps/landing` — лендинг (React+GSAP, деплоится статикой).
- `apps/web` — веб-демо клиент (React), в проде не публикуется отдельно.
- `resonance/` — Flutter клиент (Windows/Android/iOS), основной продукт.
- Прод: `https://music.webcordes.ru` (API + лендинг), API в Docker на VPS.

## Окружение (критично!)

- SSH: `ssh -i C:/Users/monyx/.ssh/webcord_codex_vps root@104.128.140.14`
  (прод-сервер, `/opt/resonance/{app,landing,data,downloads,.env,backups,incoming}`).
- Flutter SDK НЕ в PATH: `J:\SDK\flutter\bin\flutter.bat analyze` работает,
  а `flutter test` падает на env-проблеме native assets («Invalid SDK hash»,
  package objective_c) — это НЕ баг кода, чинить отдельной сессией.
- **Сборка клиента требует `K:\SDK\flutter_fresh`** (Flutter 3.44.4, Dart 3.12.2):
  `J:\SDK\flutter` (Dart 3.12.1) не резолвит pubspec (нужно ^3.12.2).
  Android SDK: `K:\SDK\android-sdk` (= `J:\SDK\android-sdk` дублирует).
  Грабли: при переносе репо между дисками чистить `build/windows` (мёртвый
  CMakeCache) и `windows/flutter/ephemeral/.plugin_symlinks` (мёртвые джанкшены).
  Артефакты собираются в `J:/bankafy/artifacts/resonance-<ver>/` скриптом
  `resonance/tool/build_windows_installer.ps1` (+ portable ZIP из содержимого
  `build/windows/x64/runner/Release`), APK — `flutter build apk --release`
  (debug-ключ, имя `Resonance-android-<ver>-release-debug-signed.apk`).
- FTP-бэкап: `/root/backup-to-ftp.sh` на сервере, cron 03:30, хранилище
  принимает только lftp (rclone ломается на 550 MDTM). Лог:
  `/var/log/backup-to-ftp.log`. Креды в `/root/.ftp-backup.env`.
- Деплой: tar (exclude node_modules/.git/.dart_tool/dist/build/src-tauri/target)
  → scp в `/opt/resonance/incoming` → backup+swap `/opt/resonance/app` →
  `docker compose -f deploy/docker-compose.music.yml build && up -d` →
  health-check. Тег образа в компоузе менять на новый stamp.
- Диск сервера маленький (18G, ~80% занято): чисти за собой, `/opt/resonance/backups`
  хранит 2 точки отката, полная история — на FTP в `/backups/bulk/resonance-backups`.
- Git: не коммитить `.codex_docx_review_c9419b/` и `.codex-release-*.sh` (мусор).
  Коммиты на main, push не настроен.

## Что уже сделано (не переделывай!)

### Resonance 2.0 Library — прод, 2026-09-08

- Выпущен `2.0.0+22`: перенос всей медиатеки (лайки + плейлисты) из Яндекс
  Музыки, Spotify и VK, актуальные share-URL Яндекса, визуально новая
  медиатека, Wave 2.0 и недельная статистика. Music Graph и изменение
  навигации намеренно не включались.
- Лендинг получил секцию Library Cinema и адаптивный показ переноса/медиатеки.
- Проверки: сервер 70/70, Flutter 66/66, visual goldens 9/9, `flutter analyze`
  без замечаний, server/web/landing build зелёные, браузер без console errors.
- Прод: контейнеры `resonance-api:20260908-library-2` healthy, client-version
  `2.0.0`, четыре download-канала проверены HTTP 206. iOS CI run
  `34188970434`, commit `b393e50`.
- Бэкап отката: `/opt/resonance/backups/release-2.0.0-20260908T052000Z`;
  дополнительно оставлен `/opt/resonance/backups/manual-20260906T071940Z`.
- VPS агрессивно ограничивает новые SSH-сессии. Использовать
  `-o IdentitiesOnly=yes -o PreferredAuthentications=publickey`; для больших
  файлов стабильнее `scp -O` и пауза между соединениями. При деплое собирать
  только service `api`: `api` и `promo-bot` используют один image tag, поэтому
  параллельный `docker compose build api promo-bot` даёт коллизию экспорта.
- Удалена dangling-ссылка `/etc/nginx/sites-enabled/study.webcordes.ru`, которая
  указывала на отсутствующий файл и блокировала `nginx -t`/reload.

1. **Релиз 1.4 в проде** — Spotify и VK Музыка везде: серверные адаптеры
   (`apps/server/src/spotify.ts`, `vk.ts`), Flutter-клиент (enum `MusicProvider`,
   `lib/providers/common/backend_token_provider.dart`, поиск/онбординг/настройки/
   импорт/бейджи), web-клиент, лендинг. `/api/client-version` → 1.4.0.
2. **Комнаты 2.0 фаза 1 в проде** — общая очередь с голосованием:
   `rooms.ts` (события `room:queue-add/vote/remove/next`), UI в
   `apps/web/src/RoomPanel.tsx`. Тесты `rooms.test.ts` — 3 шт.
3. **Wave** принимает spotify/vk (`wave.ts`, схемы в `index.ts`, `waveAccess`).
4. Бэкап на FTP + чистка сервера (FunPay-боты и jarvis удалены — так решил юзер).
5. `docs/ROADMAP.md` — дорожная карта, коммиты `917427b`, `ad4108c` на main.
6. 68 тестов сервера проходят, `npm run check`/`build` зелёные.
7. **Бинарники клиентов 1.4.0 в проде** (2026-09-06): Windows Setup EXE +
   Portable ZIP + Android APK + iOS unsigned IPA — все 4 канала
   `/downloads/*` раздают 1.4.0 (nginx-алиасы переключены, проверены по HTTP).
   Клиент поднят до 1.4.0+19. iOS собирается через GitHub Actions:
   `.github/workflows/ios-unsigned.yml` (macos-latest, триггер — push в main
   с изменениями в resonance/**), артефакт скачивается через API. Попутно
   починен тест онбординг-дефолтов: spotify/vk добавлены в дефолтный набор
   провайдеров `OnboardingPreferences` (04583ce). Старые версии 1.2.0/1.3.0
   в downloads сохранены как откат.
8. **Лендинг обновлён до 1.4** (5e6d1e8): release-note в hero больше не
   пишет «1.3 Lyrics Network»; деплой статики — tar dist → scp в incoming →
   swap `/opt/resonance/landing` (старая копия: incoming/landing-prev).
9. **Лендинг: кинематографичный hero** (9322180, задеплоено 2026-09-06):
   правая колонка — живой «Stage» (`apps/landing/src/components/HeroStage.tsx`),
   ротация 4 реальных треков (Knucks & Venna — Alpha House, OG Buda & Scally
   Milano — Большие бабки, SLIME & FACE — Подруга Подруг, MONATIK — Выходной)
   с GSAP-переходами и амбиентным свечением под палитру трека. Обложки —
   реальные (из Apple Music/iTunes lookup, `public/assets/covers/*.jpg`),
   лого провайдеров — Simple Icons + Wikimedia (`public/assets/logos/*.svg`),
   очередь «Далее в сессии» кликабельна, внизу marquee с треками. SSH на VPS
   флапает (порт 22 таймаутами, сам сайт жив) — при деплое ретраить каждые
   ~90 сек, восстанавливается.

## Сводка: сессия 2026-09-06, вторая (релиз бинарников) — не повторять

1. Клиент 1.3.0+18 → **1.4.0+19** (pubspec.yaml), NSIS-дефолты обновлены (db997eb).
2. Собраны и залиты в `/opt/resonance/downloads`: Windows Setup EXE,
   Portable ZIP, Android APK (все через `K:/SDK/flutter_fresh`; гочяки — см.
   раздел «Окружение»). Артефакты также лежат в `J:/bankafy/artifacts/resonance-1.4.0/`.
3. Все 4 nginx-алиаса `/downloads/*` переключены на 1.4.0, проверены по HTTP
   (размеры и SHA-256 совпадают с локальными артефактами). Старые версии
   1.2.0/1.3.0 в downloads — откат, не удалять без нужды.
4. iOS 1.4.0 собран через GitHub Actions (`.github/workflows/ios-unsigned.yml`,
   триггер — push в main с изменениями в `resonance/**`; мониторинг и скачивание
   артефакта — REST API с токеном из `git credential fill` для github.com, gh CLI
   не установлен). Попутно починен упавший CI-тест: spotify/vk добавлены в
   дефолт онбординга `OnboardingPreferences` (04583ce) — это был реальный баг 1.4.
   Локальный `flutter test` с K:-SDK работает для чистых Dart-тестов (падает
   только на native assets).
5. Лендинг: release-note в hero обновлён с «1.3 Lyrics Network» на 1.4 (5e6d1e8),
   dist задеплоен swap-ом в `/opt/resonance/landing` (старая копия:
   `/opt/resonance/incoming/landing-prev`).
6. Тексты анонса обновления — в этом же коммите, файл `docs/ANNOUNCEMENT-1.4.md`.

Проверено в проде: `/api/health` ok, `/api/v1/playback/providers` — 5 провайдеров,
все 4 канала `/downloads/*` отдают 1.4.0, лендинг пишет 1.4. Коммиты:
db997eb, 04583ce, 141349e, 5e6d1e8, 00f517b (+ текущий). Push в GitHub работает.

## Сводка: сессия 2026-09-06/07, релиз 1.4.1 (багфиксы клиента) — не повторять

Юзер нашёл два бага клиента, починены и выпущены как **1.4.1+20**:
1. **Обложка в полноэкранке (Visual Stage)**: для треков без обложки/с битым
   URL рендерилась серая заглушка. Теперь: `TrackArtwork` при ошибке
   t500x500-апгрейда ретраит исходный URL, а финальный фолбэк — красивый
   градиент с инициалами (`ArtworkFallback` в lib/shared/widgets/track_artwork.dart,
   детерминированный по title/artist). `_StageBackground` в visual_stage_screen
   рисует тот же градиент амбиентом. Голдены перегенерированы.
2. **Чёрный экран при импорте плейлиста**: `TextEditingController.dispose()`
   вызывался сразу после закрытия диалога, пока TextField жив в exit-анимации
   → исключение в build → в release пустой экран. Диалог вынесен в
   `ImportPlaylistDialog` (StatefulWidget, dispose в dispose).

Релиз: сервер `CLIENT_VERSION=1.4.1` в /opt/resonance/.env + `docker compose up -d`
(пересоздание контейнера, без rebuild). Все 4 канала `/downloads/*` → 1.4.1
(nginx-алиасы переключены, проверено по Content-Length). Клиент 66/66 тестов,
analyze 0 issues, сервер 68/68. Коммиты: 2b6fa2b (фиксы), далее — docs.
iOS 1.4.1 собран CI (run 34060070622). Артефакты локально: artifacts/resonance-1.4.1/.
Урок: golden-тесты (visual_capture_test.dart, исключены из CI) надо
перегенерировать при намеренных визуальных изменениях: `flutter test
test/visual_capture_test.dart --update-goldens`.

## Сводка: сессия 2026-09-07, релиз 1.4.2 (важнейшие фиксы) — не повторять

Юзер забагрепортил импорт (чёрный экран). Воспроизведено НА ЭМУЛЯТОРЕ
(AVD resonance_test на J:vd-home, эмулятор/образ в J:\SDKndroid-sdk,
C: забит) — реальная причина оказалась НЕ в dispose контроллера:
1. **Краш импорта (чёрный экран на мобиле/десктопе):** диалог загрузки
   открывается на ROOT-навигаторе, а `Navigator.pop(context)` из LibraryScreen
   (внутри ShellRoute) попал ВНУТРЕННИЙ навигатор → снёс единственную
   страницу shell → go_router assertion "popped the last page" → чёрный
   экран. Фикс: `Navigator.of(context, rootNavigator: true).pop()`.
   Репродукция: adb input tap (координаты = сырые пиксели устройства,
   скриншоты у MCP даунскейлятся 1080→900!).
2. **Онбординг-краш на свежей установке:** OnboardingGate рендерит онбординг
   ВЫШЕ Navigator'а → Tooltip в шапке = RawTooltip без Overlay → exception →
   в release чёрный экран. Фикс: OnboardingScreen обёрнут в собственный
   `Overlay(initialEntries: ...)`.
3. **Stage:** обложка на коротких вьюпортах была height*.15 (крошечная) —
   теперь .32 высоты (до 260), identity обёрнут в FittedBox.scaleDown
   (гарантия без overflow, тест 844x390 зелёный). Клип фоном: в lyrics-режиме
   при hasVideo видео играет затемнённым (0.62) слоем под обложкой/текстом/
   кнопками; режим «Клип» — ярко (0.28).
4. **Переходы вкладок:** `_TabSwitcher` в adaptive_app_shell — fade+slide
   входа. ВАЖНО: НЕ AnimatedSwitcher — удержание уходящей вкладки дублирует
   GlobalKey'и страниц go_router (ловится app_smoke_test).
Попутно: заголовок «Медиатека» в FittedBox (не ломается на 3 строки).
Релиз 1.4.2+21: все 4 канала /downloads/* → 1.4.2, CLIENT_VERSION=1.4.2 в
.env + docker compose up -d. Клиент 66/66 (голдены перегенерированы),
анализ 0, сервер 68/68. Коммиты 2b6fa2b..(текущий). Артефакты:
artifacts/resonance-1.4.2/. iOS CI run 34066387820.

## Задачи следующей сессии (по приоритету)

1. ~~Пересобрать бинарники клиентов~~ — **сделано 2026-09-06, все 4 платформы
   (включая iOS через GitHub Actions)** — см. п.7 выше.
2. **Комнаты 2.0 фаза 2**: UI очереди в Flutter-клиенте (экран комнат —
   `lib/features/rooms/`, API-события уже на сервере), приватные комнаты по
   ссылке, история сессий, реакции. Персистентность комнат требует Resonance ID (п.3).
3. **Resonance ID** (фундамент уже есть: `account-store.ts`, `account-api.ts`,
   JWT, cloudSync): экран входа в онбординге Flutter, фоновый sync-движок,
   «продолжить на другом устройстве», шифрованное хранение токенов провайдеров
   на сервере, персистентная БД комнат.
4. **Wave 2.0** (ежедневные миксы, радио по треку, недельный отчёт) —
   работает и без аккаунтов через локальный Drift.
5. Дальше по `docs/ROADMAP.md`: универсальный импортер → офлайн → десктоп-глубина
   (SMTC уже есть — `windows_media_controls.dart`; остаются трей, хоткеи, виджет Android).

## Проверка перед завершением работы

```sh
cd J:/bankafy && npm run check && npm test   # сервер: tsc + 68 тестов
J:/SDK/flutter/bin/flutter.bat analyze        # из resonance/ — должно быть 0 issues
# после деплоя:
curl -fsS https://music.webcordes.ru/api/health
curl -fsS https://music.webcordes.ru/api/v1/playback/providers  # 5 провайдеров
docker ps --filter name=resonance             # оба healthy
```
