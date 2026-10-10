#!/bin/sh
# Post-deploy smoke test (read-only GET requests only):
#   ./deploy/smoke.sh [base-url] [expected-client-version]
set -eu
BASE="${1:-https://music.webcordes.ru}"
EXPECTED="${2:-}"
fail() { echo "FAIL: $*" >&2; exit 1; }
get() { curl -fsS --max-time "${2:-10}" "$BASE$1"; }

get /api/health | grep -q '"ok":true' || fail "/api/health"
echo "ok   /api/health"

version_json="$(get /api/client-version)" || fail "/api/client-version"
if [ -n "$EXPECTED" ]; then
  echo "$version_json" | grep -q "\"version\":\"$EXPECTED\"" || fail "client-version != $EXPECTED"
fi
echo "ok   /api/client-version"

get /api/providers | grep -q '"providers":\[' || fail "/api/providers"
echo "ok   /api/providers"

get /api/v1/playback/providers | grep -q '"providers":\[' || fail "/api/v1/playback/providers"
echo "ok   /api/v1/playback/providers"

# Probes upstreams (cached server-side for 60 s); a degraded provider is reported, not fatal.
status_json="$(get /api/v1/status 20)" || fail "/api/v1/status"
echo "$status_json" | grep -q '"services":\[' || fail "/api/v1/status shape"
overall="$(echo "$status_json" | sed -n 's/.*"overall":"\([a-z]*\)".*/\1/p')"
[ "$overall" = "down" ] && fail "/api/v1/status overall=down"
echo "ok   /api/v1/status (overall=${overall:-?})"

# Lyrics: 200 with lines or 404 LYRICS_NOT_FOUND are both a working endpoint.
lyrics_code="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' \
  "$BASE/api/v1/lyrics?title=Yesterday&artist=The%20Beatles")" || fail "/api/v1/lyrics"
case "$lyrics_code" in 200|404) ;; *) fail "/api/v1/lyrics HTTP $lyrics_code" ;; esac
echo "ok   /api/v1/lyrics ($lyrics_code)"

get /api/v1/rooms/stats | grep -q '"rooms":' || fail "/api/v1/rooms/stats"
echo "ok   /api/v1/rooms/stats"

curl -fsS --max-time 10 -o /dev/null "$BASE/" || fail "landing"
echo "ok   landing"
echo "smoke passed: $BASE"
