# HANDOFF — инструкция для следующей сессии агента

Дата: 2026-09-06. Прочти это до начала работы; детали окружения дублированы в
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

## Задачи следующей сессии (по приоритету)

1. **Пересобрать бинарники клиентов** — в `/opt/resonance/downloads` лежат
   сборки 1.3.0, а сервер уже раздаёт 1.4.0: пользователи получат апдейт,
   которого нет. Нужно: `flutter build` Windows (Setup EXE/Portable ZIP) и
   APK, залить в `/opt/resonance/downloads`, проверить HTTP-заголовки
   `/downloads/*`. Артефакты Flutter-сборки Windows собираются локально
   (`J:/bankafy/resonance/windows`), Android требует SDK (`J:/SDK/android-sdk`).
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
