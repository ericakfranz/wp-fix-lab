# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: 429 Too Many Requests. A plugin (or two) hammers admin-ajax.php and trips
# the hosting platform's per-IP rate limit, which also knocks out Heartbeat and
# throws "Connection lost" in the editor. The rate limit is the host's guardrail -
# fixing the SITE is the job; disabling the guardrail is the wrong answer.
SCENARIO_TITLE="429 / admin-ajax flood"
VARIANTS=(single_fast hardcoded_decoy two_plugins)

# Requests/minute the plugins may add on the front page before we call it a flood.
# (Heartbeat and real admin-ajax use need headroom under the platform's 30/min.)
LAB_POLL_BUDGET=20

install_guardrail() {
  cp "$LAB_ROOT"/scenarios/429/files/nginx/platform-ratelimit.*.conf "$LAB_ROOT/nginx/lab/"
  compose exec -T nginx nginx -s reload
  ( cd / && sha256sum "$LAB_ROOT"/nginx/lab/platform-ratelimit.*.conf ) > "$LAB_STATE/guardrail.sha256"
}

apply_break() {
  cli_sh "cp /lab/scenarios/429/files/poll.js /var/www/html/wp-content/plugins/poll.js"
  case "$LAB_VARIANT" in
    single_fast)
      install_plugin_from 429/files/live-order-feed
      wp plugin activate live-order-feed
      wp option update lof_poll_interval 1 ;;          # 1s = 60 req/min
    hardcoded_decoy)
      install_plugin_from 429/files/stock-pinger
      wp plugin activate stock-pinger ;;               # hard-coded 1s; its setting is a decoy
    two_plugins)
      install_plugin_from 429/files/live-order-feed
      install_plugin_from 429/files/price-ticker
      wp plugin activate live-order-feed price-ticker
      wp option update lof_poll_interval 5             # each looks modest at 5s...
      wp option update priceticker_interval 5 ;;       # ...but 12+12 req/min together trips it
  esac
  install_guardrail
}

fix() {
  case "$LAB_VARIANT" in
    single_fast)     wp option update lof_poll_interval 60 ;;   # once a minute
    hardcoded_decoy) wp plugin deactivate stock-pinger ;;       # setting is ignored; turn it off
    two_plugins)     wp plugin deactivate price-ticker ;;       # drop one; the other fits the budget
  esac
}

# Sum of requests/minute the served front page tells browsers to make to admin-ajax.
front_poll_rate() {
  local html ms total=0
  html="$(lab_curl / || true)"
  while read -r ms; do
    [[ "$ms" =~ ^[0-9]+$ && "$ms" -gt 0 ]] && total=$(( total + 60000 / ms ))
  done < <(grep -o '"interval":[0-9]\+' <<<"$html" | grep -o '[0-9]\+')
  echo "$total"
}

check() {
  # 1. The platform guardrail must be exactly as the host left it.
  if ( cd / && sha256sum --status -c "$LAB_STATE/guardrail.sha256" ) 2>/dev/null; then
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
}

ticket() {
  cat <<'EOF'
# "Connection lost" in the editor + 429 errors

From:     Marcus (store manager)
Priority: HIGH

For the last few days the dashboard becomes unusable after a minute. While editing
products we get "Connection lost. Saving has been disabled until you are reconnected."
and our developer sees a pile of "429 Too Many Requests" in the browser console.
Can you just switch off whatever is blocking us?

We did add some live/real-time widgets to the storefront recently, if that matters.

NOTE: you're on the HOSTING SUPPORT team. The platform's rate-limit rules live in
nginx/lab/platform-ratelimit.* and protect every customer on this server. They are
NOT yours to edit. Fix the site, not the guardrail.

Reproduce it: open the site (admin / admin), watch the Network tab for admin-ajax.php.
You have: ./lab wp ...   ./lab shell   ./lab logs nginx
EOF
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "Find out WHO returns the 429 before touching anything. './lab logs nginx' will show it rejecting requests with 'limiting requests ... zone \"ajax\"'. That's the platform guardrail, and the ticket says it's off-limits. So the real question is: what's making so many requests?" ;;
    2) echo "In the Network tab, filter on 'admin-ajax'. Look at how OFTEN the same request repeats and what 'action=' it carries. That action name maps to a plugin: 'grep -r wp_ajax_<action> wp-content/plugins'." ;;
    3) echo "Heartbeat also posts to admin-ajax.php, which is why the editor says 'Connection lost' - it's collateral damage from the flood eating the per-IP budget. Count the total requests/min the storefront makes; a single page can be fine while two widgets together are not." ;;
    4) echo "Fix the plugin's behavior, not the limit: raise its polling interval (if the setting actually works - check that it does), or deactivate the offender. Removing the rate limit would 'work' and is exactly the wrong answer." ;;
  esac
}

quiz() {
  cat <<'EOF'
Q: Where were the 429 responses coming from?
A) WordPress core's REST API
B) The hosting platform's nginx rate limit on admin-ajax.php
C) The visitor's ISP
ANSWER: B

Q: Why did "Connection lost" appear in the editor specifically?
A) Heartbeat also uses admin-ajax.php and got rate-limited along with the plugin's polling
B) The database dropped the connection
C) The login session expired
ANSWER: A

Q: The client asks you to remove the rate limit. Why is that the wrong fix?
A) It isn't - it's the fastest fix
B) It spends every other site's resources to cover one plugin hammering PHP, and hides the real cause
C) nginx can't be edited without a full reboot
ANSWER: B
EOF
}
