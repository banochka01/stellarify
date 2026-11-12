# Resonance watchdog

A private Telegram bot that watches the production service and writes to one
person only. It runs on the host as a systemd unit (`resonance-monitor`), not in
the API container, so it notices when that container is down.

What it checks:

| Check | Interval |
| --- | --- |
| `/api/health` locally, and the site and API from outside over HTTPS | 1–2 min |
| `resonance-api` container state, health and restarts | 1 min |
| Each catalog from `/api/v1/status` | 2 min |
| Real sound: search, then resolve, then download the first bytes of the stream (follows HLS), for SoundCloud and Yandex | 10 min |
| All download links plus `alpha/latest.json` | 30 min |
| Free disk space (alert below 0.8 GB) | 5 min |
| TLS certificate (alert under 14 days) | 6 h |
| New lines in `client-reports.jsonl` (crashes, playback errors), grouped into a digest | at most once per 5 min |

Alerting rules:

- An outage is reported after two failures in a row.
- Recovery is reported with the downtime.
- While something stays down, a reminder goes out every 3 hours.

Commands, which answer the owner only (anyone else gets silence):

- `/status`
- `/check`
- `/reports [N]`
- `/mute [hours]`
- `/unmute`

## Setup

The unit file is `deploy/monitor/resonance-monitor.service`.

Server paths:

- script: `/opt/resonance/monitor/resonance_monitor.py`
- settings: `/opt/resonance/monitor/monitor.env` (mode 600)

`monitor.env`:

```
TELEGRAM_BOT_TOKEN=<from @BotFather>
TELEGRAM_PROXY_URL=<ip:port:login:password>   # api.telegram.org is not reachable directly
```

The server cannot reach Telegram directly, so traffic goes through the HTTP proxy.

Pairing:

1. Restart the unit.
2. Run `journalctl -u resonance-monitor -n 20` and find the line `Send the bot: /start <code>`.
3. Send that message to the bot.

After pairing the bot answers only that account. In BotFather it is worth running
`/setjoingroups → Disable`, so the bot cannot be added to groups.
