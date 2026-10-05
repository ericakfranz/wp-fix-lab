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

# Copy a plugin folder from a scenario into wp-content/plugins.
install_plugin_from() { cli_sh "cp -r '/lab/scenarios/$1' /var/www/html/wp-content/plugins/"; }

# Drop a PHP file from a scenario's files/ into wp-content/mu-plugins (always loaded,
# can't be deactivated from the admin - so a fatal here is nastier to clear).
mu_install() {
  cli_sh "mkdir -p /var/www/html/wp-content/mu-plugins && cp '/lab/scenarios/$1' /var/www/html/wp-content/mu-plugins/"
}

# True when the lab is in training mode (hints, runbook, quiz). Test mode: grader only.
is_training() { [[ "${LAB_MODE:-training}" == training ]]; }

# Deterministic 0..(n-1) pick from the seed, salted so different choices don't move together.
seed_pick() {
  local salt="$1" n="$2" h
  h=$(printf '%s' "${LAB_SEED:-0}:$salt" | cksum | cut -d' ' -f1)
  echo $(( h % n ))
}
