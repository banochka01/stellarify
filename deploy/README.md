# Resonance VPS deployment

Production topology for `music.webcordes.ru`:

- Nginx terminates TLS on ports 80/443.
- `resonance-api` listens only on `127.0.0.1:8788`.
- Docker Compose builds the Node 22 API and restarts it unless stopped.
- `/opt/resonance/.env` contains production configuration and is never copied
  into the image.
- `PUBLIC_BASE_URL` is the trusted HTTPS origin used in short-lived playback
  relay URLs (the Compose default is `https://music.webcordes.ru`).
- Native release artifacts live in `/opt/resonance/downloads` and are exposed
  through stable attachment endpoints.

SoundCloud uses a public API v2 Client ID. Store the shared fallback Client ID
only in `/opt/resonance/.env`; users may optionally save their own Client ID in
Resonance Settings. Yandex continues to use a per-user OAuth token.

`SOUNDCLOUD_PROXY_URL` is optional and server-only. The preferred compact form
is `IPv4:port:login:password`; absolute `http://` and `https://` URLs are also
accepted only when their host is a literal IPv4 address. Hostnames, IPv6 and
SOCKS proxy URLs are rejected.
Clients never receive that URL: they can only request the configured route with
the SoundCloud proxy toggle. When enabled, SoundCloud API calls and progressive
MP3 playback use the proxy; audio is exposed only through a short-lived opaque
relay ticket with byte-range support. When the proxy is requested but
unavailable, the server fails closed instead of silently falling back to a
direct request.

Plus/Family Wave can use AgentRouter to turn recent listening feedback, likes,
and playlist tracks into bounded search and ranking parameters. Configure
`AGENTROUTER_API_KEY` in `/opt/resonance/.env`; the defaults use the
OpenAI-compatible `https://co.agentrouter.org/v1` endpoint and `glm-5.2` model.
`AGENTROUTER_MODEL`, `AGENTROUTER_TIMEOUT_MS`, and `AGENTROUTER_CACHE_MS` are
optional overrides. If AgentRouter is unavailable or unconfigured, Wave keeps
working with the same account signals through its deterministic local ranker.
Only track metadata and outcomes are sent for personalization; account IDs,
provider credentials, stream URLs, and playlist names are not sent.

Account mail (email verification, password reset codes, "password changed"
notices) goes through the SMTP relay already used by WebCord Mail. Set
`RESONANCE_SMTP_HOST`, `RESONANCE_SMTP_PORT` (587 STARTTLS or 465 TLS),
`RESONANCE_SMTP_USERNAME`, `RESONANCE_SMTP_PASSWORD` and optionally
`RESONANCE_MAIL_FROM` (default `Resonance <noreply@webcordes.ru>`) in
`/opt/resonance/.env`. Without `RESONANCE_SMTP_HOST` the forgot/verify endpoints
answer 503 and everything else keeps working. Delivery depends on the relay
DKIM-signing for `webcordes.ru`: the domain publishes `SPF -all` and
`DMARC p=reject`.

Validate a release with:

```sh
cd /opt/resonance/app
docker compose -f deploy/docker-compose.music.yml config
docker compose -f deploy/docker-compose.music.yml up -d --build
docker compose -f deploy/docker-compose.music.yml ps
docker inspect --format '{{json .State.Health}}' resonance-api
curl -fsS http://127.0.0.1:8788/api/health
nginx -t
curl -fsS https://music.webcordes.ru/api/health
```

Rollback by restoring the timestamped `/opt/resonance/backups/app-*` archive
and the matching Nginx backup, then rebuilding the Compose service.

After deploy, run `./deploy/smoke.sh https://music.webcordes.ru [version]`. It
only issues read-only GETs: health, client version, provider lists,
`/api/v1/status` (per-provider health, cached 60 s), lyrics and
`/api/v1/rooms/stats` (counts only).

Client crash/playback reports (`POST /api/v1/client-reports`, 30 per IP per
10 minutes) are appended as JSON lines to `client-reports.jsonl` next to the
auth database (override with `CLIENT_REPORTS_PATH`); the file rotates to
`.1` above 5 MB.
