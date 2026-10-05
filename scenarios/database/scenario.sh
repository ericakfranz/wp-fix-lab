# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: database problems. Mostly the same "Error establishing a database connection"
# symptom, but six different root causes with seed-randomized values, so you can't
# pattern-match "it's always the host." Two causes look different on the surface
# (the server being down, and a wrong table prefix), which is the point.
SCENARIO_TITLE="Error establishing a database connection"
VARIANTS=(wrong_host wrong_password wrong_name wrong_port db_stopped wrong_prefix)

# Correct values (what a clean install uses; see docker-compose.yml).
DB_GOOD_HOST=db DB_GOOD_PASS=wordpress DB_GOOD_NAME=wordpress DB_GOOD_PREFIX=wp_

apply_break() {
  # Red herring in every variant: the developer "only turned on debug." It didn't
  # cause the outage, but it's the last thing they touched, so it draws the eye.
  wp config set WP_DEBUG true --raw

  case "$LAB_VARIANT" in
    wrong_host)
      local hosts=(127.0.0.1 localhost db-primary mysql)
      wp config set DB_HOST "${hosts[$(seed_pick host ${#hosts[@]})]}" ;;
    wrong_password)
      local pws=(hunter2 Prod_Pass_2023 letmein changeme)
      wp config set DB_PASSWORD "${pws[$(seed_pick pw ${#pws[@]})]}" ;;
    wrong_name)
      local names=(wordpress_prod wp_db wordpress2 maindb)
      wp config set DB_NAME "${names[$(seed_pick name ${#names[@]})]}" ;;
    wrong_port)
      local ports=(3307 3308 33060 3300)
      wp config set DB_HOST "db:${ports[$(seed_pick port ${#ports[@]})]}" ;;
    db_stopped)
      # The config is fine; the database server itself is down.
      compose stop db >/dev/null 2>&1 ;;
    wrong_prefix)
      # WordPress connects, but looks for its tables under the wrong prefix, so they
      # all appear to be "missing."
      local pfx=(wp2_ prod_ wpold_ backup_)
      wp config set table_prefix "${pfx[$(seed_pick prefix ${#pfx[@]})]}" --type=variable ;;
  esac
}

fix() {
  # Diagnose, then change the ONE thing that's wrong. WP-CLI's config command edits
  # wp-config.php directly, so it works even while WordPress itself can't connect.
  case "$LAB_VARIANT" in
    wrong_host|wrong_port) wp config set DB_HOST "$DB_GOOD_HOST" ;;
    wrong_password)        wp config set DB_PASSWORD "$DB_GOOD_PASS" ;;
    wrong_name)            wp config set DB_NAME "$DB_GOOD_NAME" ;;
    db_stopped)            compose up -d --wait db >/dev/null ;;   # bring the server back
    wrong_prefix)          wp config set table_prefix "$DB_GOOD_PREFIX" --type=variable ;;
  esac
  wp config set WP_DEBUG false --raw   # and undo the debug flag on the live site
}

check() {
  local home; home="$(lab_curl / -w '\n%{http_code}' || true)"
  if [[ "$home" == *"Error establishing a database connection"* ]]; then
    fail "Homepage still can't reach the database"
  elif [[ "${home##*$'\n'}" == 200 && "$home" == *"</html>"* ]]; then
    pass "Homepage renders a real page (HTTP 200)"
  else
    fail "Homepage returned HTTP ${home##*$'\n'}"
  fi

  # The strongest check: can WordPress actually read its OWN data? This catches the
  # wrong-prefix case (the site may render an install page but the real data is gone).
  if wp option get blogname 2>/dev/null | grep -qx 'WP Fix Lab'; then
    pass "Site is reading its ORIGINAL database (not a fresh/blank install)"
  else
    fail "Can't read the site's original data - wrong database, prefix, or the server is down?"
  fi
}

ticket() {
  # Vague, client-voice tickets by seed. None of them says which setting is wrong or
  # whether the server is down - the logs and the config tell you that.
  case "$(seed_pick ticket 3)" in
    0)
      cat <<'EOF'
# "Error establishing a database connection"

From:     Priya (freelance dev, working on a client's store)
Priority: URGENT - whole site is down

The site went down while I was poking around in wp-config.php. I only meant to turn
on debug mode to chase a layout bug. Now every page shows a database error. Is your
database server down, or did I break something?

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress   ./lab logs db
EOF
      ;;
    1)
      cat <<'EOF'
# Site is down with a database error

From:     Marcus (store manager)
Priority: URGENT

Every page is showing a database error this morning and the whole shop is offline.
I don't know what changed. Can you find out why it can't reach the database and get
us back up?

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress   ./lab logs db
EOF
      ;;
    *)
      cat <<'EOF'
# Database error / content looks gone

From:     Sam (developer)
Priority: URGENT

The site won't load - it throws a database error, and at one point it looked like it
wanted to run the WordPress installer, as if our content vanished. The data should
still be there. I need to work out what it's actually failing on.

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress   ./lab logs db
EOF
      ;;
  esac
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "First question: is the database actually down, or can WordPress just not reach it? Run './lab logs db'. If MariaDB says 'ready for connections', the server is up and the problem is how WordPress connects. If the container is stopped or missing from the logs, the server itself is down - bring it back." ;;
    2) echo "Turn the error into a specific one. With WP_DEBUG on, read './lab logs wordpress' for the mysqli line: 'Connection refused' (2002) is a host/port problem; 'Access denied' (1045) is credentials; 'Unknown database' (1049) is the DB name. 'Table ... doesn't exist' points at the table prefix, not the connection." ;;
    3) echo "Compare config to reality: './lab wp config list'. In this stack the database is a separate container: host 'db', port 3306, and user/password/name all 'wordpress'. The table prefix should be 'wp_'. One of those is wrong - unless the server itself is down." ;;
    4) echo "Don't be misled by the debug line - that's a symptom of editing, not the cause. Then make the smallest fix: set the one wrong value back with './lab wp config set ...', or if the database server is down, start it. Turn debug back off when you're done." ;;
  esac
}

quiz() {
  cat <<'EOF'
Q: Before changing wp-config.php, what's the first thing worth confirming?
A) That the database server is up and accepting connections
B) That the theme is compatible with the PHP version
C) That the WordPress core files aren't corrupted
ANSWER: A

Q: The same "database connection" error can have very different causes. Which is NOT one of them?
A) The database server is stopped
B) A wrong host, port, user, password, or database name in wp-config.php
C) A missing favicon
ANSWER: C

Q: Which mysqli error points at a bad DB_HOST or port, rather than a password?
A) 1045 Access denied
B) 1049 Unknown database
C) 2002 Connection refused
ANSWER: C
EOF
}
