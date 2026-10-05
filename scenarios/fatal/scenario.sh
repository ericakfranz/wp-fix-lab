# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: fatal error / White Screen of Death / HTTP 500. The screen is blank on
# purpose (display_errors off, WordPress's "critical error" handler disabled), so
# you have to go to the logs. Six different root causes.
SCENARIO_TITLE="Blank white page / fatal 500"
VARIANTS=(missing_dep mu_syntax mu_null wpconfig_syntax memory_exhausted php8_removed_func)

apply_break() {
  # Decoy: an innocent plugin activated the same week. Shows up in `wp plugin list`
  # as "recently changed" and sends people down the wrong path.
  install_plugin_from fatal/files/cache-helper
  wp plugin activate cache-helper

  # Production-style config: no on-screen errors, and no "critical error" page, so
  # the failure is a true white screen. Done BEFORE any fatal is introduced, because
  # some variants stop WP-CLI from running at all.
  wp config set WP_DEBUG false --raw
  wp config set WP_DISABLE_FATAL_ERROR_HANDLER true --raw

  case "$LAB_VARIANT" in
    missing_dep)
      install_plugin_from fatal/files/simple-share-counts
      wp plugin activate simple-share-counts ;;
    mu_syntax)
      mu_install fatal/files/mu-syntax.php ;;        # parse error, every request dies
    mu_null)
      mu_install fatal/files/mu-null.php ;;          # method-on-null fatal at runtime
    memory_exhausted)
      mu_install fatal/files/mu-memory.php ;;        # "Allowed memory size exhausted"
    php8_removed_func)
      install_plugin_from fatal/files/legacy-gallery
      wp plugin activate legacy-gallery ;;           # create_function() removed in PHP 8
    wpconfig_syntax)
      # A broken line pasted into wp-config.php. Even WP-CLI can't parse it after this,
      # so this is the LAST thing we do.
      cli_sh "printf '\n%s\n' '%%% LAB_BAD_LINE parse error introduced by an edit %%%' >> /var/www/html/wp-config.php" ;;
  esac
}

fix() {
  case "$LAB_VARIANT" in
    missing_dep)
      # WP-CLI loads plugins too; --skip-plugins lets you disable the bad one anyway.
      wp_safe plugin deactivate simple-share-counts ;;
    php8_removed_func)
      wp_safe plugin deactivate legacy-gallery ;;
    mu_syntax|mu_null|memory_exhausted)
      # mu-plugins can't be deactivated and take WP-CLI down with them. Remove the file.
      local f="mu-syntax.php"
      [[ "$LAB_VARIANT" == mu_null ]] && f="mu-null.php"
      [[ "$LAB_VARIANT" == memory_exhausted ]] && f="mu-memory.php"
      cli_sh "rm -f /var/www/html/wp-content/mu-plugins/$f" ;;
    wpconfig_syntax)
      # Remove the broken line from wp-config.php (WP-CLI can't run, so edit the file).
      cli_sh "sed -i '/LAB_BAD_LINE/d' /var/www/html/wp-config.php" ;;
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
  # Same symptom every time (a blank white page), but a different reporter and a
  # different "what changed," so each variant reads as its own ticket. The context
  # is a realistic clue, not the answer - you still confirm the cause in the logs.
  case "$LAB_VARIANT" in
    missing_dep)
      cat <<'EOF'
# The whole site is a blank white page

From:     Dana (client, small bakery)
Priority: URGENT

The site is just white this morning, and the login page is blank too, so I can't
get into the dashboard. Last night I deleted a few plugins I didn't think we used,
and I turned on a new "Cache Helper" plugin. We're losing orders. Help!

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    mu_syntax)
      cat <<'EOF'
# The whole site went blank after a code edit

From:     Jordan (the client's part-time developer)
Priority: URGENT

I pasted a small code snippet into our custom "must-use" helper file last night to
tweak the footer. This morning every page is blank, including the login page, and I
can't reach the dashboard to undo it.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    mu_null)
      cat <<'EOF'
# Blank white page since this morning

From:     Priya (client)
Priority: URGENT

Everything was fine yesterday. This morning the whole site is a blank white page,
front end and login both. Nothing obvious changed on my end, but the site does run
a couple of custom add-ons a past developer left behind.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    wpconfig_syntax)
      cat <<'EOF'
# Site went blank while editing a config file

From:     Sam (developer)
Priority: URGENT

I was editing wp-config.php to change one setting, saved it, and now the whole site
is blank, including the login page. WP-CLI also throws an error when I try to run
anything. I think I mistyped something in the file.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    memory_exhausted)
      cat <<'EOF'
# Storefront keeps going to a blank white page

From:     Marcus (store manager)
Priority: HIGH

The site keeps showing a blank white page, with no error, just white. It got worse
this week after we switched on a big image-heavy feature on the storefront. It seems
to happen most on the busy pages.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    php8_removed_func)
      cat <<'EOF'
# Site white-screened right after a PHP upgrade

From:     Dana (client)
Priority: URGENT

Our host emailed to say they upgraded our PHP version overnight. Since then the
whole site is a blank white page and I can't log in. We didn't change anything
ourselves. Could the upgrade have done this?

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
  esac
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "A blank page with nothing on it is almost always a PHP fatal error that isn't being shown. Confirm it's PHP, not nginx: static files still load, but every PHP page is empty. Now you need the error text." ;;
    2) echo "The error is hidden, not gone. Read './lab logs wordpress' and look for 'PHP Fatal error'. Common wordings: 'Call to undefined function', 'syntax error' / 'parse error', 'Call to a member function ... on null', and 'Allowed memory size ... exhausted'. 'Deprecated' notices are noise." ;;
    3) echo "The 'Cache Helper' plugin and the 'newer PHP' note are both things to check and rule out, not assume. Let the fatal line tell you the real cause, and note WHERE the file lives: wp-content/plugins, wp-content/mu-plugins, or wp-config.php itself." ;;
    4) echo "Fix by location. In /plugins: './lab wp --skip-plugins plugin deactivate <name>' (works even though WP-CLI loads plugins). In /mu-plugins, or a bad line in wp-config.php: WP-CLI can't run, so edit the file - './lab shell', then remove the offending file or line. For a memory fatal, remove the code that eats memory. Then turn the fatal-error handler back on for the client." ;;
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

Q: A site worked for years, then went blank right after the host upgraded PHP. A likely cause is:
A) The database ran out of rows
B) Old code calling a function that newer PHP removed (e.g. create_function in PHP 8)
C) The domain expired
ANSWER: B

Q: The client points at the "Cache Helper" plugin she just enabled. The right move is:
A) Delete it immediately - the newest change is always the cause
B) Check it, but let the actual fatal-error log line name the real culprit
C) Ignore her entirely
ANSWER: B
EOF
}
