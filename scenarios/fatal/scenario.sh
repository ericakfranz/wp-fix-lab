# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: fatal error / White Screen of Death / HTTP 500. The screen is blank on purpose
# (display_errors off, "critical error" handler disabled), so you must read the logs.
# Ten root causes, and the culprit's NAME/FILE is randomised every run, so the only
# way to know what to deactivate or remove is to find it in the logs. The ticket does
# not name the cause, an innocent plugin must stay active (you can't just disable
# everything), and some runs hide a SECOND fault behind the first - clear one and the
# next surfaces, so re-check the log after every fix.
SCENARIO_TITLE="Blank white page / fatal 500"
VARIANTS=(missing_dep php8_removed_func redeclare mu_syntax mu_null memory_exhausted \
  wpconfig_syntax theme_functions two_faults_mu_plugin two_faults_theme)

# Record one fault so fix() can clear it later: "<kind>\t<arg>" (plugin|file|line).
# A scenario may record more than one; PHP shows them one at a time by load order.
rec_fault() { printf '%s\t%s\n' "$1" "$2" >> "$LAB_STATE/culprits"; }

# Drop the right payload for a plugin/mu fault and record it. Helpers keep the
# multi-fault variants readable.
break_plugin_undef() { materialize_plugin "$1" "$2" _templates/tpl-undef-fn.php "$3"; wp plugin activate "$1"; rec_fault plugin "$1"; }
break_mu()           { materialize_mu "$1" "$2" "$3"; rec_fault file "/var/www/html/wp-content/mu-plugins/$1"; }

apply_break() {
  local n=${#LAB_PLUGIN_SLUGS[@]} ci; ci=$(seed_pick culprit "$n")
  local slug="${LAB_PLUGIN_SLUGS[$ci]}" name="${LAB_PLUGIN_NAMES[$ci]}"
  local fn="${slug//-/_}_boot" mufile="${slug//-/_}.php"
  # A second, unrelated plugin for the layered variants (offset to dodge the decoys).
  local cj=$(( (ci + 5) % n ))
  local slug2="${LAB_PLUGIN_SLUGS[$cj]}" name2="${LAB_PLUGIN_NAMES[$cj]}"
  local fn2="${slug2//-/_}_init"
  : > "$LAB_STATE/culprits"

  # Innocent decoys (need WP-CLI + DB); record one so the grader checks it stays on.
  printf '%s' "$(install_decoys "$ci" 2)" > "$LAB_STATE/decoy_slug"

  # Make it a true white screen BEFORE introducing any fatal (some kill WP-CLI).
  wp config set WP_DEBUG false --raw
  wp config set WP_DISABLE_FATAL_ERROR_HANDLER true --raw

  case "$LAB_VARIANT" in
    missing_dep)       break_plugin_undef "$slug" "$name" "$fn" ;;
    php8_removed_func) break_plugin_undef "$slug" "$name" "create_function" ;;
    redeclare)
      materialize_plugin "$slug" "$name" _templates/tpl-redeclare.php; wp plugin activate "$slug"; rec_fault plugin "$slug" ;;
    mu_syntax)         break_mu "$mufile" _templates/tpl-mu-syntax.php "$name" ;;
    mu_null)           break_mu "$mufile" _templates/tpl-mu-null.php "$name" ;;
    memory_exhausted)  break_mu "$mufile" _templates/tpl-mu-memory.php "$name" ;;
    wpconfig_syntax)
      rec_fault line /var/www/html/wp-config.php
      cli_sh "printf '\n%s\n' '%%%% LAB_BAD_LINE stray edit %%%%' >> /var/www/html/wp-config.php" ;;
    theme_functions)
      local fpath; fpath="$(active_theme_functions)"; rec_fault line "$fpath"
      cli_sh "printf '\n%s\n' '%%%% LAB_BAD_LINE stray edit %%%%' >> '$fpath'" ;;

    # --- layered: fix one, another surfaces -------------------------------
    two_faults_mu_plugin)
      # Plugin first (while WP-CLI still works), then the mu-plugin parse error.
      # The mu parse error loads earliest, so it's what you see first.
      break_plugin_undef "$slug2" "$name2" "$fn2"
      break_mu "$mufile" _templates/tpl-mu-syntax.php "$name" ;;
    two_faults_theme)
      # A broken plugin AND a broken theme functions.php. Clear one, the other appears.
      break_plugin_undef "$slug" "$name" "$fn"
      local fpath; fpath="$(active_theme_functions)"; rec_fault line "$fpath"
      cli_sh "printf '\n%s\n' '%%%% LAB_BAD_LINE stray edit %%%%' >> '$fpath'" ;;
  esac
}

fix() {
  # Clear every recorded fault (CI's reference fix). A human clears them one at a
  # time as each surfaces; the grader only passes once they're all gone.
  local kind arg
  while IFS=$'\t' read -r kind arg; do
    case "$kind" in
      plugin) wp_safe plugin deactivate "$arg" ;;
      file)   cli_sh "rm -f '$arg'" ;;
      line)   cli_sh "sed -i '/LAB_BAD_LINE/d' '$arg'" ;;
    esac
  done < "$LAB_STATE/culprits"
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

  # Anti-shortcut: you must remove the FAULTY code, not disable every plugin.
  local decoy; decoy="$(cat "$LAB_STATE/decoy_slug" 2>/dev/null)"
  if [[ -n "$decoy" ]]; then
    if wp_safe plugin is-active "$decoy" >/dev/null 2>&1; then
      pass "Healthy plugins left alone (targeted fix)"
    else
      fail "A working plugin was disabled - find and remove the faulty code, don't disable everything"
    fi
  fi
}

ticket() {
  # Vague, client-voice tickets chosen by seed. None of them names the cause - that's
  # what the logs are for.
  case "$(seed_pick ticket 3)" in
    0)
      cat <<'EOF'
# The whole site is a blank white page

From:     Dana (client, small bakery)
Priority: URGENT

The site is just white this morning - front end and the login page both. I can't
get into the dashboard at all. We're losing orders. Nothing I can point to for sure,
we made a few routine changes this week. Please help.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    1)
      cat <<'EOF'
# Site down - blank page, no error

From:     Marcus (store manager)
Priority: HIGH

Customers are seeing a completely blank page and so am I. No error message, just
white. The admin login is blank too. It was fine yesterday. Can you take a look
before it costs us the weekend?

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
    *)
      cat <<'EOF'
# Urgent: white screen across the whole site

From:     Priya (developer handing off a client site)
Priority: URGENT

Every page is blank, including wp-login.php, so I'm locked out of wp-admin. I'd
rather not guess - I need to find what's actually throwing the error. Any help
getting at the logs is appreciated.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress
EOF
      ;;
  esac
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "A blank page with nothing on it is almost always a PHP fatal error that isn't being shown. Confirm it's PHP, not nginx: static files still load, but every PHP page is empty. Now go get the error text." ;;
    2) echo "The error is hidden, not gone. Read './lab logs wordpress' and look for 'PHP Fatal error'. Note the exact message AND the file path it points to - the cause is different every time, so don't assume, read it. 'Deprecated' notices are noise." ;;
    3) echo "The file path tells you WHERE to fix and HOW. wp-content/plugins/<name> - a regular plugin you can deactivate. wp-content/mu-plugins/<file> - a must-use file you must delete (can't be deactivated). wp-config.php or wp-content/themes/<theme>/functions.php - edit the file and remove the bad part. Common messages: undefined function, syntax/parse error, call on null, 'Cannot redeclare', 'Allowed memory size exhausted'." ;;
    4) echo "Fix only the faulty thing. Plugin: './lab wp --skip-plugins plugin deactivate <the name from the log>'. mu-plugin: './lab shell' then rm that file. wp-config.php / functions.php: edit the file and delete the bad line. Don't disable every plugin to make it go away - that fails the check. And after each fix, reload and read the log again: one fatal can hide another behind it, and the round isn't done until the site truly loads and './lab check' passes." ;;
  esac
}

quiz() {
  cat <<'EOF'
Q: Why was the page completely blank instead of showing an error message?
A) The theme files were deleted
B) On-screen errors were off and WordPress's "critical error" handler was disabled
C) The database was unreachable
ANSWER: B

Q: The log says the fatal is in wp-content/mu-plugins/. Why can't you just deactivate it?
A) Must-use plugins can't be deactivated from the admin; you remove the file instead
B) You need a license key
C) mu-plugins live in the database
ANSWER: A

Q: A fatal can come from a plugin, a must-use plugin, wp-config.php, or the active theme's functions.php. How do you tell which?
A) Guess based on what changed most recently
B) Read the file path in the fatal-error log line
C) Deactivate everything and turn things back on one by one
ANSWER: B

Q: Deactivating every plugin makes the white screen go away. Is that the fix?
A) Yes, ship it
B) No - find and remove the one faulty thing; disabling working plugins is collateral damage
C) Only on Fridays
ANSWER: B

Q: You remove the file the log blamed, reload, and now it's a DIFFERENT fatal error. What happened?
A) Your fix broke the site further
B) There was a second, separate fault hiding behind the first - PHP only shows one at a time
C) The cache needs clearing
ANSWER: B
EOF
}
