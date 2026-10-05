# Shared helpers for ./lab and the scenario scripts. Source, don't execute.
# shellcheck shell=bash

LAB_ROOT="${LAB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LAB_STATE="$LAB_ROOT/.lab"
LAB_PORT=8080
export LAB_ROOT LAB_STATE

# Public URL of the site. In GitHub Codespaces the forwarded port has its own HTTPS domain.
if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
  LAB_URL="https://${CODESPACE_NAME}-${LAB_PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
  LAB_URL="http://localhost:${LAB_PORT}"
fi
export LAB_URL

compose() { docker compose --project-directory "$LAB_ROOT" "$@"; }

# Run WP-CLI against the lab site.
wp() { compose run --rm -T cli wp "$@"; }

# Run a shell command inside the PHP container (as www-data, so file ownership stays sane).
in_php() { compose exec -T -u www-data wordpress sh -c "$1"; }

# curl the site from this machine, but tell WordPress the request came in on its public URL.
# Usage: lab_curl <path> [extra curl args...]
lab_curl() {
  local path="$1"; shift
  local host="${LAB_URL#*://}"
  local args=(-s --max-time 15)
  if [[ "$LAB_URL" == https://* ]]; then
    args+=(-H "X-Forwarded-Host: $host" -H "X-Forwarded-Proto: https")
  else
    args+=(-H "Host: $host")
  fi
  curl "${args[@]}" "$@" "http://127.0.0.1:${LAB_PORT}${path}"
}

# HTTP status code for a path (no redirects followed).
http_code() { lab_curl "$1" -o /dev/null -w '%{http_code}'; }

pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
# shellcheck disable=SC2034  # CHECK_FAILED is read by ./lab check
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; CHECK_FAILED=1; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Run a shell command in the WP-CLI container (has the scenarios folder mounted at /lab/scenarios).
cli_sh() { compose run --rm -T --entrypoint sh cli -c "$1"; }

# WP-CLI with plugins AND must-use plugins skipped, so a fatal in site code can't
# take WP-CLI down with it. The scalpel for a broken site.
wp_safe() { compose run --rm -T cli wp --skip-plugins --skip-themes "$@"; }

# True when the lab is in training mode (hints, runbook, quiz). Test mode: grader only.
is_training() { [[ "${LAB_MODE:-training}" == training ]]; }

# Hash files, printing "hash  path" lines. Uses sha256sum (Linux) or shasum (macOS).
hash_files() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"
  else shasum -a 256 "$@"; fi
}

# Deterministic 0..(n-1) pick from the seed, salted so different choices don't move together.
seed_pick() {
  local salt="$1" n="$2" h
  h=$(printf '%s' "${LAB_SEED:-0}:$salt" | cksum | cut -d' ' -f1)
  echo $(( h % n ))
}

# ---- randomised plugin identities -----------------------------------------
# Real-sounding (but invented) plugin names, so the culprit never stands out and
# you can't memorise "deactivate <fixed name>" - you must read the logs each run.
# shellcheck disable=SC2034
LAB_PLUGIN_SLUGS=(smart-social-share easy-contact-form simple-image-gallery rapid-cache \
  seo-meta-tags popup-box-lite related-posts cookie-consent-banner live-sales-alerts \
  currency-switcher table-of-contents simple-breadcrumbs)
# shellcheck disable=SC2034
LAB_PLUGIN_NAMES=("Smart Social Share" "Easy Contact Form" "Simple Image Gallery" "Rapid Cache" \
  "SEO Meta Tags" "Popup Box Lite" "Related Posts" "Cookie Consent Banner" "Live Sales Alerts" \
  "Currency Switcher" "Table of Contents" "Simple Breadcrumbs")

# Write a plugin from a token template into wp-content/plugins/<slug>/<slug>.php.
# Tokens: {{NAME}} {{SLUG}} {{FN}} {{MS}} {{ACTION}} {{GATE}} (unused ones are harmless).
materialize_plugin() {
  local slug="$1" name="$2" tpl="$3" fn="${4:-noop}" ms="${5:-0}" action="${6:-noop_action}" gate="${7:-}"
  cli_sh "mkdir -p /var/www/html/wp-content/plugins/'$slug' && sed \
    -e 's|{{NAME}}|$name|g' -e 's|{{SLUG}}|$slug|g' -e 's|{{FN}}|$fn|g' \
    -e 's|{{MS}}|$ms|g' -e 's|{{ACTION}}|$action|g' -e 's|{{GATE}}|$gate|g' \
    '/lab/scenarios/$tpl' > /var/www/html/wp-content/plugins/'$slug'/'$slug'.php"
}

# Write a must-use plugin from a token template into wp-content/mu-plugins/<fname>.
materialize_mu() {
  local fname="$1" tpl="$2" name="${3:-Helper}"
  cli_sh "mkdir -p /var/www/html/wp-content/mu-plugins && sed \
    -e 's|{{NAME}}|$name|g' '/lab/scenarios/$tpl' > /var/www/html/wp-content/mu-plugins/'$fname'"
}

# Install N innocent decoy plugins whose slugs are offset from the culprit's index,
# so the culprit doesn't stand out by name. Echoes the first decoy's slug (the grader
# checks it stays active, so "deactivate everything" can't pass).
install_decoys() {
  local culprit_idx="$1" count="${2:-2}" n=${#LAB_PLUGIN_SLUGS[@]} i d first=""
  for (( i=1; i<=count; i++ )); do
    d=$(( (culprit_idx + i) % n ))
    materialize_plugin "${LAB_PLUGIN_SLUGS[$d]}" "${LAB_PLUGIN_NAMES[$d]}" _templates/tpl-innocent.php
    wp plugin activate "${LAB_PLUGIN_SLUGS[$d]}" >/dev/null 2>&1 || true
    [[ -z "$first" ]] && first="${LAB_PLUGIN_SLUGS[$d]}"
  done
  echo "$first"
}

# Absolute path to the active theme's functions.php (call while WP-CLI still works).
active_theme_functions() {
  local t; t="$(wp theme list --status=active --field=name 2>/dev/null | head -n1 | tr -d '\r')"
  [[ -n "$t" ]] && echo "/var/www/html/wp-content/themes/$t/functions.php"
}
