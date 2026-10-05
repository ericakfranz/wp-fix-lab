#!/usr/bin/env bash
# SPOILER. Used by CI to prove the scenario is fixable.
set -euo pipefail
source "$LAB_ROOT/lib/common.sh"
# Plain `wp plugin deactivate` would fatal too, because WP-CLI loads plugins. Skip them.
wp --skip-plugins plugin deactivate simple-share-counts
