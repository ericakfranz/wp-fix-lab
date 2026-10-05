#!/usr/bin/env bash
# SPOILER. Used by CI to prove the scenario is fixable.
set -euo pipefail
source "$LAB_ROOT/lib/common.sh"
# The database lives in its own container, reachable as "db" - not on the PHP server.
wp config set DB_HOST db
# Debug output on a live site leaks paths and queries; turn it back off.
wp config set WP_DEBUG false --raw
