# shellcheck shell=bash
# shellcheck disable=SC2034  # these are consumed by ./lab after this file is sourced
# Type: database connection failures. One clean symptom - "Error establishing a
# database connection" - with four different root causes and seed-randomized values,
# so you can't pattern-match "it's always the host."
SCENARIO_TITLE="Error establishing a database connection"
VARIANTS=(wrong_host wrong_password wrong_name wrong_port)

# Correct values (what a clean install uses; see docker-compose.yml).
DB_GOOD_HOST=db DB_GOOD_PASS=wordpress DB_GOOD_NAME=wordpress

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
  esac
}

fix() {
  # Diagnose, then set the one wrong value back. (Setting them all also works, but
  # on a real site you change the minimum.) WP-CLI's config command edits
  # wp-config.php directly, so it works even while WordPress itself can't connect.
  case "$LAB_VARIANT" in
    wrong_host|wrong_port) wp config set DB_HOST "$DB_GOOD_HOST" ;;
    wrong_password)        wp config set DB_PASSWORD "$DB_GOOD_PASS" ;;
    wrong_name)            wp config set DB_NAME "$DB_GOOD_NAME" ;;
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

  if wp option get blogname 2>/dev/null | grep -qx 'WP Fix Lab'; then
    pass "Site is reading its ORIGINAL database (not a fresh/blank install)"
  else
    fail "Can't read the site's original data - is it pointed at the right database?"
  fi
}

ticket() {
  cat <<'EOF'
# "Error establishing a database connection"

From:     Priya (freelance dev, working on a client's store)
Priority: URGENT - whole site is down

The site went down while I was in wp-config.php. I SWEAR I only added a line to
turn on debug mode to chase a layout bug. Now every page says "Error establishing
a database connection." Is your database server down??

You have: ./lab wp ...   ./lab shell   ./lab logs wordpress   ./lab logs db
EOF
}

hint_count() { echo 4; }
hint() {
  case "$1" in
    1) echo "First rule: is the database actually down, or can WordPress just not reach it? Check './lab logs db' - if MariaDB says 'ready for connections', the server is fine and the problem is in how WordPress connects." ;;
    2) echo "Turn the error into a specific one. With WP_DEBUG on, look at './lab logs wordpress' for the mysqli line: 'Connection refused' (2002) is a host/port problem; 'Access denied' (1045) is credentials; 'Unknown database' (1049) is the DB name." ;;
    3) echo "Compare config to reality: './lab wp config list'. The database in this stack is a separate container reachable as host 'db' on port 3306, user/pass/name all 'wordpress'. One of those four is wrong." ;;
    4) echo "Don't be misled by the debug line Priya added - that's a symptom of her editing, not the cause. Fix the wrong DB_* value with './lab wp config set DB_<thing> <value>', then turn debug back off." ;;
  esac
}

quiz() {
  cat <<'EOF'
Q: Before changing wp-config.php, what's the first thing worth confirming?
A) That the database server is up and accepting connections
B) That the theme is compatible with the PHP version
C) That the WordPress core files aren't corrupted
ANSWER: A

Q: Priya insists she "only turned on debug mode." How should you treat that?
A) Trust it and rule out wp-config.php entirely
B) Trust the file, not the memory - diff wp-config.php, since people paste more than they remember
C) Reinstall WordPress to be safe
ANSWER: B

Q: Which mysqli error points at a bad DB_HOST or port, rather than a password?
A) 1045 Access denied
B) 1049 Unknown database
C) 2002 Connection refused
ANSWER: C
EOF
}
