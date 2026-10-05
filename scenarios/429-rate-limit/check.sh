# shellcheck shell=bash
# Sourced by ./lab check. Report with pass/fail; never exit.
# Intent: staff and visitors stop flooding admin-ajax, AND the platform's rate limit is
# still in force. Turning off the guardrail is the wrong fix even though it "works".

if ( cd / && sha256sum --status -c "$LAB_STATE/ratelimit.sha256" ) 2>/dev/null; then
  pass "Platform rate-limit rules are untouched"
else
  fail "Platform rate-limit rules were changed or removed. That's the host's guardrail, not the bug."
fi

if compose exec -T nginx nginx -T 2>/dev/null | grep -q 'limit_req zone=ajax'; then
  pass "Rate limit is still loaded in nginx"
else
  fail "nginx is no longer enforcing the admin-ajax rate limit"
fi

# Polling interval (ms) the page asks the browser to use, or "none" if the feed isn't loaded.
poll_interval() {
  local html="$1" ms
  ms="$(grep -o '"interval":"\?[0-9]*' <<<"$html" | grep -o '[0-9]*$' | head -n1 || true)"
  echo "${ms:-none}"
}
# Anything at or above 15s keeps one tab under the platform limit with room for Heartbeat.
check_polling() {
  local where="$1" ms="$2"
  if [[ "$ms" == none ]]; then
    pass "$where: live feed no longer polls"
  elif (( ms >= 15000 )); then
    pass "$where: polls every $((ms / 1000))s"
  else
    fail "$where: still polls admin-ajax every ${ms}ms"
  fi
}

check_polling "Front end" "$(poll_interval "$(lab_curl / || true)")"

jar="$(mktemp)"
lab_curl /wp-login.php -c "$jar" -b 'wordpress_test_cookie=WP%20Cookie%20check' \
  --data 'log=admin&pwd=admin&testcookie=1' -o /dev/null || true
check_polling "Dashboard" "$(poll_interval "$(lab_curl /wp-admin/ -b "$jar" || true)")"
rm -f "$jar"
