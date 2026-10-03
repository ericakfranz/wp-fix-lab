# Runbook: Blank white page / fatal 500

> Spoilers. Solve it first. Three root causes; the seed picks one.

## Symptoms
- Every page, including `/wp-login.php`, is blank. `curl -I` shows 500 with no body.

## Triage, in order
1. **Confirm it's PHP, not nginx.** Static assets still load; PHP pages are empty → a
   PHP fatal that isn't being displayed.
2. **Get the error text.** It's hidden, not gone: `./lab logs wordpress`, look for
   `PHP Fatal error`. It names the file and line. `Deprecated` notices are noise.
3. **Classify the fatal:**
   - *Call to undefined function* in a `/plugins/` file → it depends on a plugin that
     was deleted.
   - *syntax error* / *parse error* in a `/mu-plugins/` file → a bad edit/paste.
   - *Call to a member function … on null* → runtime fatal (common when legacy code
     meets PHP 8).
4. **Note the folder.** `wp-content/plugins` can be deactivated; `wp-content/mu-plugins`
   (must-use) cannot, and loads even in WP-CLI.
5. **The "Cache Helper" the client just enabled is a decoy.** Rule it out via the log,
   don't assume newest = guilty.

## Fix
- Plugin fatal: `./lab wp --skip-plugins plugin deactivate <name>` (WP-CLI loads plugins
  too, so `--skip-plugins` is what lets it run at all).
- mu-plugin fatal: you can't deactivate it and WP-CLI dies with it — remove the file:
  `./lab shell`, then `rm wp-content/mu-plugins/<file>`.
- Then re-enable the fatal-error handler for the client
  (`WP_DISABLE_FATAL_ERROR_HANDLER` → false) so next time they get a recovery link,
  not a white page.

## Prevent
Leave the fatal-error handler on in production; check `Requires Plugins` headers before
deleting plugins; stage plugin cleanups first.
