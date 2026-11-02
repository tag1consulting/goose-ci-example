#!/usr/bin/env bash
# Starts the Umami site in site/compose.yaml, waits until it serves its front
# page, then warms it with one load test run that is not measured.
#
# A freshly installed Drupal answers some first requests with 503 while it
# generates image derivatives, and a rare 500 while it creates cache tables.
# Goose's examples/umami README advises one unmeasured 3 minute run at 50
# users first; this is that run. Its results are thrown away.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
url="http://localhost:${UMAMI_PORT:-8080}"

docker compose -f "$here/compose.yaml" up -d

echo "Waiting for Drupal to install and serve $url/en ..."
for i in $(seq 1 120); do
  if curl -fsS "$url/en" 2>/dev/null | grep -q "<title>Home |"; then
    echo "Drupal is up after about $((i * 5)) seconds."
    break
  fi
  if [ -n "$(docker compose -f "$here/compose.yaml" ps -a --status exited -q web)" ]; then
    echo "The Drupal install failed." >&2
    docker compose -f "$here/compose.yaml" logs --tail 100 >&2
    exit 1
  fi
  if [ "$i" -eq 120 ]; then
    echo "Drupal did not come up in 10 minutes." >&2
    docker compose -f "$here/compose.yaml" logs --tail 100 >&2
    exit 1
  fi
  sleep 5
done

echo "Warming the site with one unmeasured run (50 users, 3 minutes) ..."
cargo run --release -- --host "$url" --users 50 --increase-rate 5 --run-time 3m --quiet
echo "Warm up done."
