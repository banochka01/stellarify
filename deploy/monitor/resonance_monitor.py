#!/usr/bin/env python3
"""Resonance watchdog: a private Telegram bot that watches the music service.

It answers exactly one person (the paired owner) and stays silent for
everyone else. Checks run on the server itself, independent of the API
container, so it can tell when that container dies.

Config: /opt/resonance/monitor/monitor.env (KEY=VALUE lines)
  TELEGRAM_BOT_TOKEN   bot token from @BotFather (required)
  TELEGRAM_OWNER_ID    numeric Telegram user id (optional: pairing sets it)
  TELEGRAM_PROXY_URL   http proxy for api.telegram.org, "ip:port:login:pass"
                       or an http:// URL (optional)
  API_BASE             default http://127.0.0.1:8788
  PUBLIC_BASE          default https://music.webcordes.ru
  REPORTS_PATH         default /opt/resonance/data/client-reports.jsonl
State: /opt/resonance/monitor/state.json

Pairing: without an owner the bot prints a one-time code to its journal
(`journalctl -u resonance-monitor`). Send `/start <code>` to the bot.

Python standard library only.
"""

from __future__ import annotations

import json
import os
import secrets
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

HOME = Path(os.environ.get("MONITOR_HOME", "/opt/resonance/monitor"))
ENV_PATH = HOME / "monitor.env"
STATE_PATH = HOME / "state.json"


def log(message: str) -> None:
    print(f"{datetime.now().strftime('%H:%M:%S')} {message}", flush=True)


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def proxy_url(raw: str) -> str | None:
    raw = raw.strip()
    if not raw:
        return None
    if raw.startswith(("http://", "https://")):
        return raw
    parts = raw.split(":")
    if len(parts) == 4:
        host, port, login, password = parts
        return (
            f"http://{urllib.parse.quote(login)}:{urllib.parse.quote(password)}"
            f"@{host}:{port}"
        )
    if len(parts) == 2:
        return f"http://{raw}"
    return None


CONFIG = load_env(ENV_PATH)
TOKEN = CONFIG.get("TELEGRAM_BOT_TOKEN", "")
API_BASE = CONFIG.get("API_BASE", "http://127.0.0.1:8788").rstrip("/")
PUBLIC_BASE = CONFIG.get("PUBLIC_BASE", "https://music.webcordes.ru").rstrip("/")
REPORTS_PATH = Path(
    CONFIG.get("REPORTS_PATH", "/opt/resonance/data/client-reports.jsonl")
)
PUBLIC_HOST = urllib.parse.urlparse(PUBLIC_BASE).hostname or "music.webcordes.ru"

_tg_proxy = proxy_url(CONFIG.get("TELEGRAM_PROXY_URL", ""))
TG_OPENER = urllib.request.build_opener(
    urllib.request.ProxyHandler(
        {"https": _tg_proxy, "http": _tg_proxy} if _tg_proxy else {}
    )
)
# Service checks never go through a proxy: they test the server as is.
DIRECT = urllib.request.build_opener(urllib.request.ProxyHandler({}))
UA = {"User-Agent": "resonance-monitor/1"}

# --------------------------------------------------------------- state ---

_state_lock = threading.Lock()


def load_state() -> dict:
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


STATE: dict = load_state()


def save_state() -> None:
    with _state_lock:
        tmp = STATE_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(STATE, ensure_ascii=False, indent=1), "utf-8")
        os.chmod(tmp, 0o600)
        tmp.replace(STATE_PATH)


def owner_id() -> int | None:
    configured = CONFIG.get("TELEGRAM_OWNER_ID", "").strip()
    if configured.lstrip("-").isdigit():
        return int(configured)
    value = STATE.get("owner_id")
    return int(value) if isinstance(value, int) else None


# ------------------------------------------------------------ telegram ---


class TelegramError(Exception):
    pass


def tg(method: str, payload: dict | None = None, timeout: float = 30) -> object:
    if not TOKEN:
        raise TelegramError("no token")
    body = json.dumps(payload or {}).encode("utf-8")
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{TOKEN}/{method}",
        data=body,
        headers={"Content-Type": "application/json", **UA},
    )
    try:
        with TG_OPENER.open(request, timeout=timeout) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        # Never print the URL: it carries the token.
        try:
            detail = json.loads(error.read().decode("utf-8")).get("description")
        except Exception:  # noqa: BLE001
            detail = None
        raise TelegramError(f"HTTP {error.code} {detail or ''}".strip()) from None
    except (urllib.error.URLError, OSError, ValueError) as error:
        raise TelegramError(type(error).__name__) from None
    if not isinstance(data, dict) or not data.get("ok"):
        raise TelegramError(str(data.get("description") if isinstance(data, dict) else data))
    return data.get("result")


_outbox: deque[str] = deque(maxlen=50)


def send(text: str) -> bool:
    """Sends to the owner; on failure the message waits for the next try."""
    owner = owner_id()
    if owner is None:
        return False
    chunks = [text[i : i + 3800] for i in range(0, len(text), 3800)] or [""]
    try:
        for chunk in chunks:
            tg(
                "sendMessage",
                {
                    "chat_id": owner,
                    "text": chunk,
                    "disable_web_page_preview": True,
                },
            )
        return True
    except TelegramError as error:
        log(f"send failed: {error}")
        _outbox.append(text)
        return False


def flush_outbox() -> None:
    while _outbox:
        text = _outbox.popleft()
        if not send(text):
            return


# --------------------------------------------------------------- http ---


@dataclass
class Http:
    status: int
    body: bytes
    headers: dict[str, str]


def http(
    url: str,
    *,
    method: str = "GET",
    data: dict | None = None,
    headers: dict[str, str] | None = None,
    timeout: float = 15,
    limit: int = 2_000_000,
) -> Http:
    body = json.dumps(data).encode("utf-8") if data is not None else None
    request = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            **UA,
            **({"Content-Type": "application/json"} if body else {}),
            **(headers or {}),
        },
    )
    try:
        with DIRECT.open(request, timeout=timeout) as response:
            return Http(
                response.status,
                response.read(limit) if method != "HEAD" else b"",
                {k.lower(): v for k, v in response.headers.items()},
            )
    except urllib.error.HTTPError as error:
        return Http(
            error.code,
            error.read(limit) if error.fp else b"",
            {k.lower(): v for k, v in (error.headers or {}).items()},
        )


def json_of(response: Http) -> dict:
    try:
        value = json.loads(response.body.decode("utf-8"))
        return value if isinstance(value, dict) else {}
    except ValueError:
        return {}


def short_error(error: BaseException) -> str:
    if isinstance(error, (socket.timeout, TimeoutError)):
        return "таймаут"
    if isinstance(error, urllib.error.URLError):
        reason = error.reason
        if isinstance(reason, (socket.timeout, TimeoutError)):
            return "таймаут"
        return f"нет соединения ({type(reason).__name__})"
    return f"{type(error).__name__}: {str(error)[:160]}"


# ------------------------------------------------------------- checks ---


class Skip(Exception):
    """The check cannot judge right now (not configured upstream)."""


@dataclass
class Check:
    key: str
    title: str
    every: int
    run: Callable[[], str]
    # Failures in a row before alerting: one blip is not an outage.
    confirm: int = 2
    ok: bool | None = None
    detail: str = ""
    fails: int = 0
    last_run: float = 0
    down_since: float | None = None
    last_alert: float = 0
    skipped: bool = False
    history: deque = field(default_factory=lambda: deque(maxlen=60))


def check_api() -> str:
    response = http(f"{API_BASE}/api/health", timeout=8)
    if response.status != 200 or json_of(response).get("ok") is not True:
        raise RuntimeError(f"HTTP {response.status}")
    return "ok"


def check_public() -> str:
    started = time.monotonic()
    response = http(f"{PUBLIC_BASE}/api/health", timeout=12)
    if response.status != 200:
        raise RuntimeError(f"HTTP {response.status}")
    landing = http(f"{PUBLIC_BASE}/", timeout=12, limit=4096)
    if landing.status != 200:
        raise RuntimeError(f"лендинг HTTP {landing.status}")
    return f"{(time.monotonic() - started) * 1000:.0f} мс"


def check_container() -> str:
    try:
        result = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}} {{.RestartCount}}", "resonance-api"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Skip(type(error).__name__) from None
    if result.returncode != 0:
        raise RuntimeError("контейнер не найден")
    parts = result.stdout.split()
    status = parts[0] if parts else "?"
    health = parts[1] if len(parts) > 2 else ""
    restarts = parts[-1] if parts else "0"
    if status != "running" or health not in ("", "healthy"):
        raise RuntimeError(f"{status} {health}".strip())
    previous = STATE.get("restart_count")
    STATE["restart_count"] = restarts
    if previous is not None and previous != restarts:
        notify(f"⚠️ resonance-api перезапускался (счётчик {previous} → {restarts}).")
    return f"{status} {health}".strip()


def provider_checks() -> list[Check]:
    status_cache: dict = {"at": 0.0, "data": {}}

    def snapshot() -> dict:
        if time.monotonic() - status_cache["at"] > 50:
            response = http(f"{API_BASE}/api/v1/status", timeout=25)
            if response.status != 200:
                raise RuntimeError(f"/status HTTP {response.status}")
            status_cache["data"] = json_of(response)
            status_cache["at"] = time.monotonic()
        return status_cache["data"]

    def make(service_id: str, label: str) -> Check:
        def run() -> str:
            for service in snapshot().get("services", []):
                if service.get("id") != service_id:
                    continue
                state = service.get("state")
                if state == "unconfigured":
                    raise Skip("не настроен")
                if state == "down":
                    raise RuntimeError(service.get("error") or "down")
                latency = service.get("latencyMs")
                return f"{state}, {latency} мс" if latency is not None else str(state)
            raise Skip("нет в /status")

        return Check(f"provider:{service_id}", f"Каталог {label}", 120, run)

    return [
        make("soundcloud", "SoundCloud"),
        make("yandex", "Яндекс"),
        make("youtube", "YouTube"),
        make("spotify", "Spotify"),
        make("vk", "VK"),
        make("lyrics", "тексты песен"),
    ]


PROBE_QUERIES = [
    "daft punk get lucky",
    "the weeknd blinding lights",
    "linkin park numb",
    "земфира хочешь",
]


def fetch_audio(url: str) -> int:
    """Downloads the first bytes of a stream, following one HLS level."""
    response = http(url, headers={"Range": "bytes=0-131071"}, timeout=20, limit=262_144)
    if response.status not in (200, 206):
        raise RuntimeError(f"поток HTTP {response.status}")
    body = response.body
    kind = response.headers.get("content-type", "")
    if body.lstrip().startswith(b"#EXTM3U") or "mpegurl" in kind:
        for depth in range(3):
            lines = [
                line.strip()
                for line in body.decode("utf-8", "replace").splitlines()
                if line.strip() and not line.startswith("#")
            ]
            if not lines:
                raise RuntimeError("пустой HLS-плейлист")
            url = urllib.parse.urljoin(url, lines[0])
            response = http(url, timeout=20, limit=262_144)
            if response.status not in (200, 206):
                raise RuntimeError(f"сегмент HLS HTTP {response.status}")
            body = response.body
            if not body.lstrip().startswith(b"#EXTM3U"):
                break
    if len(body) < 4096:
        raise RuntimeError(f"поток слишком короткий ({len(body)} Б)")
    return len(body)


def audio_check(provider: str, label: str) -> Check:
    def run() -> str:
        query = PROBE_QUERIES[int(time.time() // 600) % len(PROBE_QUERIES)]
        search = http(
            f"{API_BASE}/api/v1/catalog/search?"
            + urllib.parse.urlencode({"provider": provider, "q": query, "limit": 5}),
            timeout=20,
        )
        if search.status != 200:
            code = json_of(search).get("error", {}).get("code", "")
            if search.status in (401, 403) or "AUTH" in code or "UNCONFIGURED" in code:
                raise Skip(f"поиск недоступен ({code or search.status})")
            raise RuntimeError(f"поиск HTTP {search.status} {code}".strip())
        tracks = [
            track
            for track in json_of(search).get("tracks", [])
            if 60_000 <= (track.get("durationMs") or 180_000) <= 600_000
        ]
        if not tracks:
            raise RuntimeError(f"поиск «{query}» ничего не вернул")
        errors = []
        for track in tracks[:3]:
            started = time.monotonic()
            resolved = http(
                f"{API_BASE}/api/v1/playback/resolve",
                method="POST",
                data={"provider": provider, "externalId": track["id"]},
                timeout=25,
            )
            payload = json_of(resolved)
            if resolved.status != 200:
                code = payload.get("error", {}).get("code", "")
                if resolved.status in (401, 403) or "AUTH" in code or "CREDENTIAL" in code:
                    raise Skip(f"нужен токен пользователя ({code or resolved.status})")
                errors.append(f"resolve {resolved.status} {code}".strip())
                continue
            source = payload.get("source") or {}
            stream = source.get("streamUrl")
            if not stream:
                errors.append("нет streamUrl")
                continue
            try:
                size = fetch_audio(stream)
            except Exception as error:  # noqa: BLE001
                errors.append(short_error(error) if not isinstance(error, RuntimeError) else str(error))
                continue
            took = (time.monotonic() - started) * 1000
            return (
                f"«{track.get('artist', '?')} — {track.get('title', '?')}»: "
                f"{source.get('protocol', '?')}/{source.get('codec', '?')}, "
                f"{size // 1024} КБ за {took:.0f} мс"
            )
        raise RuntimeError("; ".join(errors[:3]) or "не удалось")

    return Check(f"audio:{provider}", f"Звук {label}", 600, run, confirm=2)


DOWNLOADS = [
    ("/downloads/windows", "Windows установщик"),
    ("/downloads/windows-portable", "Windows ZIP"),
    ("/downloads/android", "Android"),
    ("/downloads/ios", "iOS"),
    ("/downloads/alpha/windows", "α Windows"),
    ("/downloads/alpha/ios", "α iOS"),
]


def check_downloads() -> str:
    broken = []
    for path, label in DOWNLOADS:
        try:
            response = http(f"{PUBLIC_BASE}{path}", method="HEAD", timeout=15)
            size = int(response.headers.get("content-length", "0") or 0)
            if response.status != 200 or size < 1_000_000:
                broken.append(f"{label}: HTTP {response.status}, {size} Б")
        except Exception as error:  # noqa: BLE001
            broken.append(f"{label}: {short_error(error)}")
    try:
        latest = http(f"{PUBLIC_BASE}/downloads/alpha/latest.json", timeout=10)
        if latest.status != 200 or "build" not in json_of(latest):
            broken.append(f"α latest.json: HTTP {latest.status}")
    except Exception as error:  # noqa: BLE001
        broken.append(f"α latest.json: {short_error(error)}")
    if broken:
        raise RuntimeError("; ".join(broken))
    return f"{len(DOWNLOADS)} ссылок + latest.json"


def check_disk() -> str:
    usage = shutil.disk_usage("/")
    free_gb = usage.free / 1024**3
    text = f"свободно {free_gb:.1f} ГБ из {usage.total / 1024**3:.0f}"
    if free_gb < 0.8:
        raise RuntimeError(text)
    return text


def check_tls() -> str:
    context = ssl.create_default_context()
    with socket.create_connection((PUBLIC_HOST, 443), timeout=10) as sock:
        with context.wrap_socket(sock, server_hostname=PUBLIC_HOST) as tls:
            cert = tls.getpeercert()
    expires = datetime.strptime(cert["notAfter"], "%b %d %H:%M:%S %Y %Z").replace(
        tzinfo=timezone.utc
    )
    days = (expires - datetime.now(timezone.utc)).days
    text = f"сертификат ещё {days} дн."
    if days < 14:
        raise RuntimeError(text)
    return text


CHECKS: list[Check] = [
    Check("api", "API (локально)", 60, check_api),
    Check("public", "Сайт и API снаружи", 120, check_public),
    Check("container", "Контейнер resonance-api", 60, check_container),
    *provider_checks(),
    audio_check("soundcloud", "SoundCloud"),
    audio_check("yandex", "Яндекс"),
    Check("downloads", "Ссылки на скачивание", 1800, check_downloads),
    Check("disk", "Диск сервера", 300, check_disk, confirm=1),
    Check("tls", "HTTPS-сертификат", 6 * 3600, check_tls, confirm=1),
]

REMIND_EVERY = 3 * 3600
_check_lock = threading.Lock()


def muted() -> bool:
    return time.time() < float(STATE.get("mute_until", 0))


def notify(text: str) -> None:
    if muted():
        log(f"muted: {text[:80]}")
        return
    send(text)


def minutes(seconds: float) -> str:
    seconds = int(seconds)
    if seconds < 90:
        return f"{seconds} с"
    if seconds < 5400:
        return f"{seconds // 60} мин"
    return f"{seconds // 3600} ч {seconds % 3600 // 60} мин"


def run_check(check: Check, *, quiet: bool = False) -> None:
    now = time.time()
    check.last_run = now
    try:
        detail = check.run()
        ok: bool | None = True
        check.skipped = False
    except Skip as reason:
        check.skipped = True
        check.detail = str(reason)
        return
    except Exception as error:  # noqa: BLE001
        ok = False
        detail = str(error) if isinstance(error, RuntimeError) else short_error(error)
    check.detail = detail
    check.history.append((now, ok))
    if ok:
        if check.ok is False and check.down_since and not quiet:
            notify(
                f"🟢 {check.title}: снова работает "
                f"(простой {minutes(now - check.down_since)}). {detail}"
            )
        check.ok = True
        check.fails = 0
        check.down_since = None
        return
    check.fails += 1
    if check.fails < check.confirm:
        return
    if check.ok is not False:
        check.ok = False
        check.down_since = check.down_since or now
        check.last_alert = now
        if not quiet:
            notify(f"🔴 {check.title}: {detail}")
    elif now - check.last_alert > REMIND_EVERY and not quiet:
        check.last_alert = now
        notify(
            f"🔴 {check.title} всё ещё не работает "
            f"({minutes(now - (check.down_since or now))}): {detail}"
        )


def run_due(force: Callable[[Check], bool] | None = None) -> None:
    with _check_lock:
        now = time.time()
        for check in CHECKS:
            if (force and force(check)) or now - check.last_run >= check.every:
                try:
                    run_check(check)
                except Exception:  # noqa: BLE001
                    log(traceback.format_exc())


def status_text() -> str:
    lines = []
    for check in CHECKS:
        if check.skipped:
            icon = "⚪"
        elif check.ok is None:
            icon = "…" if check.fails == 0 else "🟡"
        elif check.ok:
            icon = "🟢"
        else:
            icon = "🔴"
        ago = (
            f" · {minutes(time.time() - check.last_run)} назад"
            if check.last_run
            else ""
        )
        lines.append(f"{icon} {check.title}: {check.detail or 'ещё не проверено'}{ago}")
    head = "Resonance — состояние"
    if muted():
        head += f" (уведомления выключены до {datetime.fromtimestamp(STATE['mute_until']).strftime('%H:%M')})"
    return head + "\n\n" + "\n".join(lines)


# ------------------------------------------------------ client reports ---


@dataclass
class ReportWatch:
    pending: list[dict] = field(default_factory=list)
    last_digest: float = 0
    recent: deque = field(default_factory=lambda: deque(maxlen=200))


REPORTS = ReportWatch()
DIGEST_EVERY = 300


def read_new_reports() -> None:
    try:
        info = REPORTS_PATH.stat()
    except OSError:
        return
    position = STATE.get("reports_pos")
    inode = STATE.get("reports_inode")
    if position is None or inode != info.st_ino or position > info.st_size:
        # First start or the file rotated: start from its current end.
        STATE["reports_inode"] = info.st_ino
        STATE["reports_pos"] = info.st_size if position is None else 0
        save_state()
        if position is None:
            return
        position = 0
    if info.st_size <= position:
        return
    with REPORTS_PATH.open("rb") as handle:
        handle.seek(position)
        chunk = handle.read(1_000_000)
    end = chunk.rfind(b"\n")
    if end < 0:
        return
    for line in chunk[: end + 1].splitlines():
        try:
            report = json.loads(line)
        except ValueError:
            continue
        if isinstance(report, dict):
            REPORTS.pending.append(report)
            REPORTS.recent.append(report)
    STATE["reports_pos"] = position + end + 1
    save_state()


def report_label(report: dict) -> str:
    channel = report.get("channel") or ("alpha" if str(report.get("appVersion", "")).startswith("0.") else "stable")
    channel = "α" if channel == "alpha" else "stable"
    return f"{channel} {report.get('appVersion', '?')} {report.get('platform', '?')}"


def digest_reports(force: bool = False) -> None:
    if not REPORTS.pending:
        return
    if not force and time.time() - REPORTS.last_digest < DIGEST_EVERY:
        return
    batch, REPORTS.pending = REPORTS.pending, []
    REPORTS.last_digest = time.time()
    groups = Counter(
        (
            report.get("kind", "?"),
            report_label(report),
            report.get("provider") or "",
            str(report.get("message", ""))[:160],
        )
        for report in batch
    )
    playback = sum(1 for report in batch if report.get("kind") == "playback")
    crashes = sum(1 for report in batch if report.get("kind") == "crash")
    head = "🧾 Отчёты клиентов"
    if playback >= 10:
        head = f"🚨 Всплеск ошибок звука: {playback} за ~{DIGEST_EVERY // 60} мин"
    elif crashes:
        head = "💥 Падения клиента"
    lines = [f"{head} — {len(batch)} шт."]
    for (kind, label, provider, message), count in groups.most_common(8):
        prefix = {"crash": "💥", "playback": "🔇", "network": "📡"}.get(kind, "•")
        provider_text = f" [{provider}]" if provider else ""
        times = f" ×{count}" if count > 1 else ""
        lines.append(f"{prefix} {label}{provider_text}{times}\n   {message}")
    if len(groups) > 8:
        lines.append(f"…и ещё {len(groups) - 8} видов")
    notify("\n".join(lines))


def reports_text(limit: int) -> str:
    items = list(REPORTS.recent)[-limit:]
    if not items:
        return "Новых отчётов с момента запуска бота нет."
    lines = [f"Последние отчёты ({len(items)}):"]
    for report in items:
        when = str(report.get("receivedAt", ""))[5:16].replace("T", " ")
        provider = f" [{report['provider']}]" if report.get("provider") else ""
        lines.append(
            f"{when} {report.get('kind', '?')} · {report_label(report)}{provider}\n"
            f"   {str(report.get('message', ''))[:200]}"
        )
    return "\n".join(lines)


# ------------------------------------------------------------ commands ---

HELP = (
    "Команды:\n"
    "/status — состояние всего\n"
    "/check — прогнать все проверки сейчас (со звуком)\n"
    "/reports [N] — последние отчёты клиентов\n"
    "/mute [часы] — тишина (по умолчанию 2 ч)\n"
    "/unmute — включить уведомления"
)


def handle(message: dict) -> None:
    chat = message.get("chat", {})
    sender = message.get("from", {})
    text = (message.get("text") or "").strip()
    if chat.get("type") != "private":
        return
    owner = owner_id()
    if owner is None:
        code = STATE.get("pair_code")
        if code and text == f"/start {code}":
            STATE["owner_id"] = int(sender["id"])
            STATE.pop("pair_code", None)
            save_state()
            log("paired with owner")
            register_commands()
            send("Привязано. Буду писать сюда, если что-то сломается.\n\n" + HELP)
            threading.Thread(target=lambda: send(status_text()), daemon=True).start()
        return
    if int(sender.get("id", 0)) != owner:
        return  # strangers get silence
    command, _, argument = text.partition(" ")
    command = command.split("@")[0].lower()
    if command in ("/start", "/help"):
        send(HELP)
    elif command == "/status":
        send(status_text())
    elif command == "/check":
        send("Проверяю всё, включая звук…")
        run_due(force=lambda _: True)
        digest_reports(force=True)
        send(status_text())
    elif command == "/reports":
        limit = int(argument) if argument.strip().isdigit() else 10
        send(reports_text(max(1, min(limit, 30))))
    elif command == "/mute":
        try:
            hours = float(argument.replace(",", ".")) if argument.strip() else 2.0
        except ValueError:
            hours = 2.0
        STATE["mute_until"] = time.time() + hours * 3600
        save_state()
        send(f"Тишина до {datetime.fromtimestamp(STATE['mute_until']).strftime('%d.%m %H:%M')}.")
    elif command == "/unmute":
        STATE["mute_until"] = 0
        save_state()
        send("Уведомления снова включены.")
    else:
        send(HELP)


def register_commands() -> None:
    owner = owner_id()
    if owner is None:
        return
    commands = [
        {"command": "status", "description": "Состояние"},
        {"command": "check", "description": "Проверить всё сейчас"},
        {"command": "reports", "description": "Отчёты клиентов"},
        {"command": "mute", "description": "Тишина на N часов"},
        {"command": "unmute", "description": "Включить уведомления"},
    ]
    try:
        # Menu only in the owner's chat; nothing public.
        tg("deleteMyCommands", {})
        tg("setMyCommands", {"commands": commands, "scope": {"type": "chat", "chat_id": owner}})
    except TelegramError as error:
        log(f"setMyCommands failed: {error}")


def poll_updates() -> None:
    backoff = 5
    while True:
        try:
            updates = tg(
                "getUpdates",
                {
                    "offset": STATE.get("update_offset", 0),
                    "timeout": 50,
                    "allowed_updates": ["message"],
                },
                timeout=65,
            )
            backoff = 5
            for update in updates or []:
                STATE["update_offset"] = int(update["update_id"]) + 1
                save_state()
                if "message" in update:
                    try:
                        handle(update["message"])
                    except Exception:  # noqa: BLE001
                        log(traceback.format_exc())
            flush_outbox()
        except TelegramError as error:
            log(f"getUpdates: {error}")
            time.sleep(backoff)
            backoff = min(backoff * 2, 300)


# ---------------------------------------------------------------- main ---


def main() -> None:
    HOME.mkdir(parents=True, exist_ok=True)
    if not TOKEN:
        log(f"TELEGRAM_BOT_TOKEN is empty in {ENV_PATH}; checks run, alerts are only logged")
    if owner_id() is None:
        STATE.setdefault("pair_code", secrets.token_hex(4))
        save_state()
        log(f"not paired yet. Send the bot: /start {STATE['pair_code']}")
    if TOKEN:
        try:
            me = tg("getMe")
            log(f"bot @{me.get('username')} ready")  # type: ignore[union-attr]
            register_commands()
        except TelegramError as error:
            log(f"getMe failed: {error}")
        threading.Thread(target=poll_updates, daemon=True).start()

    # First pass: learn the current state without alerting about it, then
    # send one summary, so a restart does not replay old outages.
    with _check_lock:
        for check in CHECKS:
            try:
                for _ in range(check.confirm):
                    run_check(check, quiet=True)
            except Exception:  # noqa: BLE001
                log(traceback.format_exc())
    down = [c for c in CHECKS if c.ok is False]
    if STATE.get("announced_start") != STATE.get("owner_id") or down:
        summary = "Монитор запущен.\n\n" + status_text()
        if send(summary):
            STATE["announced_start"] = STATE.get("owner_id")
            save_state()
    log("checks: " + ", ".join(f"{c.key}={'ok' if c.ok else ('skip' if c.skipped else c.ok)}" for c in CHECKS))

    while True:
        try:
            read_new_reports()
            digest_reports()
            run_due()
            flush_outbox()
        except Exception:  # noqa: BLE001
            log(traceback.format_exc())
        time.sleep(15)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
