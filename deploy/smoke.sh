#!/bin/sh
# Post-deploy smoke test: ./deploy/smoke.sh [base-url] [expected-client-version]
set -eu
BASE="${1:-https://music.webcordes.ru}"
EXPECTED="${2:-}"
fail() { echo "FAIL: $*" >&2; exit 1; }

curl -fsS --max-time 10 "$BASE/api/health" | grep -q '"ok":true' || fail "/api/health"
echo "ok   /api/health"

version_json="$(curl -fsS --max-time 10 "$BASE/api/client-version")" || fail "/api/client-version"
if [ -n "$EXPECTED" ]; then
  echo "$version_json" | grep -q "\"version\":\"$EXPECTED\"" || fail "client-version != $EXPECTED"
fi
echo "ok   /api/client-version"

curl -fsS --max-time 10 -o /dev/null "$BASE/" || fail "landing"
echo "ok   landing"
echo "smoke passed: $BASE"
