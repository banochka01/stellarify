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
accepted.
Clients never receive that URL: they can only request the configured route with
the SoundCloud proxy toggle. When enabled, SoundCloud API calls and progressive
MP3 playback use the proxy; audio is exposed only through a short-lived opaque
relay ticket with byte-range support. When the proxy is requested but
unavailable, the server fails closed instead of silently falling back to a
direct request.

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
