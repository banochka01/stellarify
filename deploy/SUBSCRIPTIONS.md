# Resonance access and Telegram promo issuance

Implementation candidate; do not enable the paywall on production until updated
clients and the admin bot have been verified together. Old 0.3.x clients do not
send account/device access headers and will receive access errors. Do not switch
production API independently of the clients.

## Actual features

| Access | Sources | Library | Wave | Rooms | Devices |
| --- | --- | --- | --- | --- | --- |
| Guest, 24h | SoundCloud | Local | 3 batches total | None | Installation |
| Base | SoundCloud + Yandex | Local + cloud | Standard | Join | 2 |
| Plus | SoundCloud + Yandex | Local + cloud | Natural language, memory, handoff | Create/join + shared Wave | 10 |
| Family | Same as Plus | Separate per account | Same as Plus | Create/join | 10 per member |

Family: owner plus four members; revocable one-use invitations valid for 24h.
New invitations replace previous outstanding invitations. Expiration of the
owner's Family period immediately removes inherited access. Joining does not
merge libraries, share provider credentials, or consume a member's paid period;
accounts with their own purchased periods must wait or decline the invitation.

No offline downloads or room votes are advertised/sold yet. There is one native
Resonance player; YouTube playback/external player launch is disabled, while
paid playlist metadata import can retain old YouTube entries as non-playable.
Provider subscriptions/permissions remain independent of Resonance access.

## Bot configuration

Use a dedicated bot. In `/opt/resonance/.env` set (not in source control):

```
PROMO_BOT_TOKEN=<BotFather token>
PROMO_CODE_SECRET=<stable random secret, at least 32 characters>
PROMO_BOT_ADMIN_IDS=<comma-separated numeric Telegram user IDs>
PROMO_BOT_PROXY_URL=http://<username>:<URL-encoded-password>@<IPv4>:<port>
```

Only HTTP and HTTPS CONNECT proxies with a literal IPv4 host are supported.
Hostnames, IPv6 and SOCKS proxy configuration are rejected; it never falls back
to direct. The exact dispatcher is used for every Telegram call, redirects are
rejected, proxy/TLS validation is never disabled.
Only private messages from an allowlisted human account can issue codes. No
HTTP endpoint creates promo codes. Do not reuse a bot already running a webhook
or a second long-polling process. Stop the old poller first through its normal
service manager; webhook changes require an explicit operator action.

Bot commands:

```
/promo base 30
/promo plus 90 60
/promo family 365
/status <promo-UUID>
/revoke <promo-UUID>
```

The optional third argument is days before activation expires (default 90,
maximum 365). Subscription duration is 1–3660 days. Each code is single-use.
Payment is verified manually by an administrator before issuing the code; this
is NOT a payment gateway, receipt system, or Telegram checkout. Raw codes are
returned privately by the bot and not written to the database or logs.
Restart/retry of the same Telegram update returns the same code, derived with
HMAC from `PROMO_CODE_SECRET`. Keep this secret stable across releases and bot
token rotations; losing it can make a redelivered code differ from the hash
already stored for that Telegram update.
Revocation only affects unused codes; cancelling paid access is deliberately
not implemented as an unaudited shortcut.

## Access and storage

SQLite additions are additive and use the existing AUTH_DB_PATH. WAL and
BEGIN IMMEDIATE serialize grants across API/bot processes. Promo hashes,
idempotent activations, period scheduling and append-only audit rows are durable.
Same-user activation retries do not extend again. Higher tiers move remaining
lower-tier time into the future; same/lower tiers queue after equal/higher tiers.

Guest identity is a random 256-bit secret in OS secure storage, not fingerprinting.
The server stores only its hash and the original expiration. Registration binds
that trial once; login/logout do not reset it. Trial creation is IP-rate-limited.
This deters simple repeats, but cannot perfectly prevent reinstall/new-identity
abuse without attestation or mandatory verified accounts. IP limits are local to
the single API process and reset on restart; distributed rollout requires a
shared rate limiter first.

Protected provider, resolve, import, cloud-library, Wave and Socket.IO operations
are checked server-side, not by trusting the UI. Invalid account authorization
does not fall back to guest. Wave sessions are owner-and-tier-bound. Room access
is rechecked per event and periodically. The account JWT is verified on every
transport handshake; an established socket keeps the authenticated account ID
while subscription/device rights remain live checks. Network reconnects obtain
a refreshed access token through the normal account path and try to rejoin the
previous room. Devices occupy a slot for up to 30 days after
last use. Removing a device frees a slot, not a session revocation: it can rejoin
if a slot is available. Account logout revokes its refresh session separately.

The genuine client rechecks playback access before using cached sources and
periodically while playing. Already-issued direct provider URLs cannot be
revoked at the CDN by Resonance; expiration metadata is bounded by access expiry
and proxied tickets expire accordingly. Do not claim DRM-grade prevention of a
modified client retaining a provider URL. Server proxy secrets never reach clients.

## Safe release gate

1. Complete server tests, Flutter analyze/tests and native runtime checks.
2. Back up the account DB using SQLite's backup API (or stop both writers and
   back up DB/WAL/SHM together). A live copy of only the .sqlite file is unsafe.
3. Preserve current app/artifact/Nginx rollback backups; check free disk.
4. Publish compatible Windows, Android (debug-signed) and iOS (unsigned) clients
   with accurate version/download metadata. Do not call local binaries a release.
5. With secrets configured, run `docker compose -f deploy/docker-compose.music.yml
   --profile promo-bot up -d --build`. Do not print expanded Compose environment.
6. Verify both container health states, HTTPS health/version and range downloads.
   Bot health is an ephemeral /tmp heartbeat, not a persistent DB timestamp.
7. An allowlisted administrator issues a test code through Telegram; a test
   account activates it in the native client. Verify repeated activation does
   not extend time, another account cannot redeem, guest Yandex is denied, and
   SoundCloud plays with advancing native position. This test requires the actual
   Telegram/proxy configuration and is not replaced by mocks.

Rollback: restore the previous app and downloads together. Additive subscription
tables may remain (old server ignores them). Restoring an older database can
lose purchases/revive redeemed codes, so never roll back billing data blindly.
