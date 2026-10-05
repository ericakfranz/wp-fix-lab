# shellcheck shell=bash
# Sourced by ./lab check. Report with pass/fail; never exit.
# Intent: real pages load from the real database again. Any route there is fine.

home="$(lab_curl / -w '\n%{http_code}' || true)"
if [[ "$home" == *"Error establishing a database connection"* ]]; then
  fail "Homepage still can't reach the database"
elif [[ "${home##*$'\n'}" == 200 && "$home" == *"</html>"* ]]; then
  pass "Homepage renders from the database"
else
  fail "Homepage returned status ${home##*$'\n'}"
fi

if wp option get blogname 2>/dev/null | grep -qx 'Break/Fix Lab'; then
  pass "Site is reading its original data (not a fresh install)"
else
  fail "WP-CLI can't read the site's original options"
fi
