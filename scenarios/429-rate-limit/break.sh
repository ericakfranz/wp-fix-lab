#!/usr/bin/env bash
# Simulates: a plugin polls admin-ajax every second from every open tab, tripping the host's rate limit.
set -euo pipefail
source "$LAB_ROOT/lib/common.sh"
here="$LAB_ROOT/scenarios/429-rate-limit"

install_plugin_from 429-rate-limit/files/live-order-feed
wp plugin activate live-order-feed

cp "$here"/files/nginx/platform-ratelimit.*.conf "$LAB_ROOT/nginx/lab/"
compose exec -T nginx nginx -s reload
# Remember the platform rule so check.sh can confirm nobody "fixed" it by deleting it.
sha256sum "$LAB_ROOT"/nginx/lab/platform-ratelimit.*.conf > "$LAB_STATE/ratelimit.sha256"
