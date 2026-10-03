# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: fatal error / White Screen of Death / HTTP 500. The screen is blank on
# purpose (display_errors off, WordPress's "critical error" handler disabled), so
# you have to go to the logs. Three different root causes.
SCENARIO_TITLE="Blank white page / fatal 500"
VARIANTS=(missing_dep mu_syntax mu_null)

apply_break() {
  # Decoy: an innocent plugin activated the same week. Shows up in `wp plugin list`
  # as "recently changed" and sends people down the wrong path.
  install_plugin_from fatal/files/cache-helper
  wp plugin activate cache-helper

  # Production-style config: no on-screen errors, and no "critical error" page,
  # so the failure is a true white screen - done BEFORE any fatal file is dropped.
  wp config set WP_DEBUG false --raw
  wp config set WP_DISABLE_FATAL_ERROR_HANDLER true --raw

  case "$LAB_VARIANT" in
    missing_dep)
      install_plugin_from fatal/files/simple-share-counts
      wp plugin activate simple-share-counts ;;
    mu_syntax)
      mu_install fatal/files/mu-syntax.php ;;   # parse error, every request dies
    mu_null)
      mu_install fatal/files/mu-null.php ;;      # method-on-null fatal at runtime
  esac
}

fix() {
  case "$LAB_VARIANT" in
    missing_dep)
      # WP-CLI loads plugins too; --skip-plugins lets you disable the bad one anyway.
      wp_safe plugin deactivate simple-share-counts ;;
    mu_syntax|mu_null)
      # mu-plugins can't be deactivated and take WP-CLI down with them. Remove the file.
      local f="mu-syntax.php"; [[ "$LAB_VARIANT" == mu_null ]] && f="mu-null.php"
      cli_sh "rm -f /var/www/html/wp-content/mu-plugins/$f" ;;
  esac
}

check() {
  local home; home="$(lab_curl / -w '\n%{http_code}' || true)"
  if [[ "${home##*$'\n'}" == 200 && "$home" == *"</html>"* ]]; then
    pass "Homepage renders real HTML (HTTP 200)"
  else
    fail "Homepage still broken (HTTP ${home##*$'\n'})"
  fi

  local login; login="$(lab_curl /wp-login.php -w '\n%{http_code}' || true)"
  if [[ "${login##*$'\n'}" == 200 && "$login" == *'name="log"'* ]]; then
    pass "Login page renders (client can get back in)"
  else
    fail "Login page still broken (HTTP ${login##*$'\n'})"
  fi

  if wp option get blogname 2>/dev/null | grep -qx 'WP Fix Lab'; then
    pass "Site data intact (not a reinstall)"
  else
    fail "Can't read the site's data yet"
  fi
}

ticket() {
  cat <<'EOF'
# The whole site is a blank white page

From:     Dana (client, small bakery - takes online orders)
Priority: URGENT

I was tidying up plugins last night because a notice said I had too many. This
morning the site is just WHITE. Nothing loads, and the login page is blank too,
so I can't even get into the dashboard. We're losing orders. Help!

(She also mentions she turned on a new "Cache Helper" plugin this week.)

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "A blank page with nothing in it is almost always a PHP fatal error that isn't being shown on screen. Confirm it's PHP and not nginx: static files still load, but every PHP page is empty. Now you need the error text." ;;
    2) echo "The error is hidden, not gone. Read './lab logs wordpress' and look for 'PHP Fatal error'. The message names the file and line. Don't get distracted by 'Deprecated' notices - those aren't fatal." ;;
    3) echo "Dana's 'Cache Helper' is a decoy - check it, rule it out, move on. Read the fatal line itself: is it a plugin calling a function that no longer exists, a parse/syntax error, or a call on a null value? And note WHERE it lives - wp-content/plugins vs wp-content/mu-plugins." ;;
    4) echo "If it's in /plugins, './lab wp --skip-plugins plugin deactivate <name>' disables it even though WP-CLI itself loads plugins. If it's in /mu-plugins, you can't deactivate it and WP-CLI dies too - remove the file: './lab shell' then rm the offending file in wp-content/mu-plugins. Then put the fatal-error handler back on for the client." ;;
  esac
}

quiz() {
  cat <<'EOF'
Q: Why was the page completely blank instead of showing an error message?
A) The theme files were deleted
B) On-screen errors were off and WordPress's "critical error" handler was disabled
C) The database was unreachable
ANSWER: B

Q: A must-use (mu-plugin) fatal is nastier than a regular plugin fatal because:
A) It can't be deactivated from the admin and WP-CLI loads it too, so you must remove the file
B) It encrypts the database
C) It only happens on PHP 7
ANSWER: A

Q: Dana points at the "Cache Helper" plugin she just enabled. The right move is:
A) Delete it immediately - the newest change is always the cause
B) Check it, but let the actual fatal-error log line tell you the real culprit
C) Ignore her entirely
ANSWER: B
EOF
}
