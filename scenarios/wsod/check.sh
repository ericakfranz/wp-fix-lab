# shellcheck shell=bash
# Sourced by ./lab check. Report with pass/fail; never exit.
# Intent: the public site AND the login page must render real HTML again.
# We don't care how it was fixed (deactivate, remove, install the dependency) -
# only that a visitor and the client can both use the site.

home="$(lab_curl / -w '\n%{http_code}' || true)"
if [[ "${home##*$'\n'}" == 200 && "$home" == *"</html>"* ]]; then
  pass "Homepage renders (200 with HTML)"
else
  fail "Homepage still broken (status ${home##*$'\n'})"
fi

login="$(lab_curl /wp-login.php -w '\n%{http_code}' || true)"
if [[ "${login##*$'\n'}" == 200 && "$login" == *'name="log"'* ]]; then
  pass "Login form renders"
else
  fail "Login page still broken (status ${login##*$'\n'})"
fi
