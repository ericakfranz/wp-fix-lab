#!/usr/bin/env bash
# Simulates: a developer pasted wp-config values from their local machine, where MySQL runs on 127.0.0.1.
set -euo pipefail
source "$LAB_ROOT/lib/common.sh"
wp config set WP_DEBUG true --raw
wp config set DB_HOST 127.0.0.1
