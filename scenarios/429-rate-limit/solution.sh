#!/usr/bin/env bash
# SPOILER. Used by CI to prove the scenario is fixable.
set -euo pipefail
source "$LAB_ROOT/lib/common.sh"
# Keep the feature, fix the behavior: poll once a minute instead of once a second.
# (Deactivating the plugin also passes; talk to the client about which they want.)
wp option update lof_poll_interval 60
