#!/usr/bin/env bash
# Simulates: client deleted a dependency plugin; the plugin that needs it now fatals on every request.
set -euo pipefail
source "$LAB_ROOT/lib/common.sh"

install_plugin_from wsod/files/simple-share-counts
wp plugin activate simple-share-counts

# Production-style config: no on-screen errors, and no "critical error" screen,
# so the failure shows up as a true white screen.
wp config set WP_DEBUG false --raw
wp config set WP_DISABLE_FATAL_ERROR_HANDLER true --raw
