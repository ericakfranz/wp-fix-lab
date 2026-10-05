# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: 429 Too Many Requests. A plugin (or two) hammers admin-ajax.php and trips the
# hosting platform's per-IP rate limit, which also knocks out Heartbeat and throws
# "Connection lost" in the editor. The offending plugin is randomly named each run, so
# you must find it (grep its action) rather than memorise a name. The platform rate
# limit is the host's guardrail - fixing the SITE is the job; disabling the guardrail
# is the wrong answer, and so is disabling every plugin.
SCENARIO_TITLE="429 / admin-ajax flood"
VARIANTS=(single_fast hardcoded_decoy two_plugins logged_out_only)

# Requests/minute the front page may add before we call it a flood (headroom under 30/min).
LAB_POLL_BUDGET=20

install_guardrail() {
  cp "$LAB_ROOT"/scenarios/429/files/nginx/platform-ratelimit.*.conf "$LAB_ROOT/nginx/lab/"
  compose exec -T nginx nginx -s reload
  hash_files "$LAB_ROOT"/nginx/lab/platform-ratelimit.*.conf > "$LAB_STATE/guardrail.sha256"
}

apply_break() {
  local n=${#LAB_PLUGIN_SLUGS[@]} ci; ci=$(seed_pick culprit "$n")
  local slug="${LAB_PLUGIN_SLUGS[$ci]}" name="${LAB_PLUGIN_NAMES[$ci]}"
  local action="${slug//-/_}_poll"
  printf '%s' "$(install_decoys "$ci" 1)" > "$LAB_STATE/decoy_slug"

  case "$LAB_VARIANT" in
    single_fast)
      materialize_plugin "$slug" "$name" _templates/tpl-poller.php noop 1000 "$action"
      wp plugin activate "$slug" ;;
    hardcoded_decoy)
      materialize_plugin "$slug" "$name" _templates/tpl-poller.php noop 1000 "$action"
      wp plugin activate "$slug"
      wp option add "${slug//-/_}_interval" 60 ;;      # a tempting setting the plugin ignores
    two_plugins)
      local cj=$(( (ci + 3) % n )) s2 n2 a2
      s2="${LAB_PLUGIN_SLUGS[$cj]}"; n2="${LAB_PLUGIN_NAMES[$cj]}"; a2="${s2//-/_}_poll"
      materialize_plugin "$slug" "$name" _templates/tpl-poller.php noop 5000 "$action"
      materialize_plugin "$s2" "$n2" _templates/tpl-poller.php noop 5000 "$a2"
      wp plugin activate "$slug" "$s2" ;;
    logged_out_only)
      materialize_plugin "$slug" "$name" _templates/tpl-poller.php noop 1000 "$action" "if ( is_user_logged_in() ) { return; }"
      wp plugin activate "$slug" ;;
  esac
  install_guardrail
}

fix() {
  local n=${#LAB_PLUGIN_SLUGS[@]} ci; ci=$(seed_pick culprit "$n")
  case "$LAB_VARIANT" in
    two_plugins) local cj=$(( (ci + 3) % n )); wp plugin deactivate "${LAB_PLUGIN_SLUGS[$cj]}" ;;  # drop one; the other fits budget
    *)           wp plugin deactivate "${LAB_PLUGIN_SLUGS[$ci]}" ;;
  esac
}

# Sum of requests/minute the served front page tells browsers to make to admin-ajax.
# Each poller prints a <!--labpoll:MS--> marker.
front_poll_rate() {
  local html ms total=0
  html="$(lab_curl / || true)"
  while read -r ms; do
    [[ "$ms" =~ ^[0-9]+$ && "$ms" -gt 0 ]] && total=$(( total + 60000 / ms ))
  done < <(grep -o 'labpoll:[0-9]\+' <<<"$html" | grep -o '[0-9]\+')
  echo "$total"
}

check() {
  # 1. Platform guardrail untouched (compare hashes to the ones recorded at start).
  local now; now="$(hash_files "$LAB_ROOT"/nginx/lab/platform-ratelimit.*.conf 2>/dev/null || true)"
  if [[ -s "$LAB_STATE/guardrail.sha256" && "$now" == "$(cat "$LAB_STATE/guardrail.sha256")" ]]; then
    pass "Platform rate-limit rules are untouched"
  else
    fail "The platform rate-limit rules were changed/removed - that's the host's guardrail, not the bug"
  fi
  if compose exec -T nginx nginx -T 2>/dev/null | grep -q 'limit_req zone=ajax'; then
    pass "nginx is still enforcing the admin-ajax limit"
  else
    fail "nginx is no longer enforcing the rate limit"
  fi

  # 2. The site must stop flooding admin-ajax.
  local rate; rate="$(front_poll_rate)"
  if (( rate <= LAB_POLL_BUDGET )); then
    pass "Front-end admin-ajax polling is ${rate} req/min (within the ${LAB_POLL_BUDGET}/min budget)"
  else
    fail "Front end still fires ${rate} admin-ajax req/min (budget is ${LAB_POLL_BUDGET}/min)"
  fi

  # 3. Anti-shortcut: an innocent plugin must stay active.
  local decoy; decoy="$(cat "$LAB_STATE/decoy_slug" 2>/dev/null)"
  if [[ -n "$decoy" ]]; then
    if wp_safe plugin is-active "$decoy" >/dev/null 2>&1; then
      pass "Healthy plugins left alone (targeted fix)"
    else
      fail "A working plugin was disabled - fix the offender, not everything"
    fi
  fi
}

ticket() {
  local note='NOTE: you'"'"'re on the HOSTING SUPPORT team. The platform rate-limit rules in
nginx/lab/platform-ratelimit.* protect every customer on this server and are NOT
yours to edit. Fix the site, not the guardrail.
You have: ./lab wp ...   ./lab shell   ./lab logs nginx'
  case "$(seed_pick ticket 3)" in
    0)
      cat <<EOF
# "Connection lost" in the editor + 429 errors

From:     Marcus (store manager)
Priority: HIGH

For the last few days the dashboard becomes unusable after a minute. We get
"Connection lost. Saving has been disabled..." while editing, and our developer sees
a pile of "429 Too Many Requests" in the console. Can you switch off whatever is
blocking us? We've added a few things to the storefront lately.

$note
EOF
      ;;
    1)
      cat <<EOF
# 429 errors flooding the console

From:     Priya (the store's developer)
Priority: HIGH

We're getting "429 Too Many Requests" all over the place and "Connection lost" in the
editor. I know it's coming from admin-ajax, but I can't tell what's generating the
traffic. I need to find the source, not just mask it.

$note
EOF
      ;;
    *)
      cat <<EOF
# Visitors report errors; site feels hammered

From:     Marcus (store manager)
Priority: HIGH

Customers say the storefront is throwing errors, and our developer is seeing lots of
"429 Too Many Requests". The dashboard also keeps dropping with "Connection lost." It
started sometime this week.

$note
EOF
      ;;
  esac
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "Find out WHO returns the 429 before touching anything. './lab logs nginx' shows it rejecting requests with 'limiting requests ... zone \"ajax\"'. That's the platform guardrail, and the ticket says it's off-limits. So the real question is what's making so many requests." ;;
    2) echo "In the browser Network tab, filter on 'admin-ajax' and read the 'action=' on the repeating request. Map that action to a plugin: in './lab shell', 'grep -rl wp_ajax_<action> wp-content/plugins'. If you see nothing while logged in, reproduce in a logged-out / incognito window - some plugins only run for visitors." ;;
    3) echo "Heartbeat also uses admin-ajax.php, which is why the editor says 'Connection lost' - collateral damage from the flood. Add up the total requests/min the storefront makes; one page can be fine while two widgets together are over budget." ;;
    4) echo "Fix the plugin, not the limit, and don't disable everything (an innocent plugin must stay on). Slow the offender if its setting truly takes effect - check in view-source that the interval actually changed - otherwise deactivate it. With two offenders, dropping one is enough." ;;
  esac
}

quiz() {
  cat <<'EOF'
Q: Where were the 429 responses coming from?
A) WordPress core's REST API
B) The hosting platform's nginx rate limit on admin-ajax.php
C) The visitor's ISP
ANSWER: B

Q: Why did "Connection lost" appear in the editor?
A) Heartbeat also uses admin-ajax.php and got rate-limited along with the plugin's polling
B) The database dropped the connection
C) The login session expired
ANSWER: A

Q: You can't reproduce the flood while logged in as admin. What should you try?
A) Assume the client is wrong
B) Reproduce as a visitor - a logged-out / incognito window, since some code only runs for visitors
C) Reinstall WordPress
ANSWER: B

Q: The client asks you to remove the rate limit. Why is that the wrong fix?
A) It isn't - it's the fastest fix
B) It spends every other site's resources to cover one plugin hammering PHP, and hides the real cause
C) nginx can't be edited without a reboot
ANSWER: B
EOF
}
