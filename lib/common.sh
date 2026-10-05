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

# Copy a plugin folder from a scenario into wp-content/plugins.
install_plugin_from() { cli_sh "cp -r '/lab/scenarios/$1' /var/www/html/wp-content/plugins/"; }
