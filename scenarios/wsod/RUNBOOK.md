# Runbook: White screen of death

> Spoilers. Solve the scenario first.

## Symptoms
- Every URL, including `/wp-login.php`, returns an empty page.
- `curl -I` shows **HTTP 500** with no body. The browser just shows white.

## Triage
1. **Confirm it's PHP, not the web server.** A 500 with an empty body on PHP pages while static files (e.g. `/wp-includes/css/dashicons.min.css`) still load tells you nginx is fine and PHP is dying.
2. **Read the error, don't guess it.** Errors are hidden from the screen, so go where they're logged:
   `./lab logs wordpress` → `PHP Fatal error: Uncaught Error: Call to undefined function ssc_core_get_counts() in .../simple-share-counts.php`
   On a real host this is the PHP error log, or `WP_DEBUG_LOG` → `wp-content/debug.log`.
3. **Ask why the error was invisible.** `WP_DISABLE_FATAL_ERROR_HANDLER` was `true`, so WordPress skipped its "There has been a critical error" page and recovery-mode email.

## Root cause
The client deleted "Share Counts Core." "Simple Share Counts" calls one of its functions on `init`, so every request fatals before output.

## Fix
- With no admin access, WP-CLI is the scalpel, but it loads plugins too, so:
  `wp --skip-plugins plugin deactivate simple-share-counts`
- No shell? Rename `wp-content/plugins/simple-share-counts` over SFTP. WordPress deactivates a plugin whose folder is gone.

## Prevent
- Leave the fatal error handler on in production so the client gets a recovery-mode link instead of a white page.
- Before deleting plugins, check `Requires Plugins` headers and dependencies (WordPress 6.5+ enforces declared ones).
- Staging first for plugin cleanups.
