# Runbook: Error establishing a database connection

> Spoilers. Solve the scenario first.

## Symptoms
- Every page shows "Error establishing a database connection."
- With `WP_DEBUG` on, a warning above it: `mysqli_real_connect(): (HY000/2002): Connection refused`.

## Triage
1. **Is the database actually down?** `./lab logs db` shows MariaDB "ready for connections," and the container is healthy. The server is fine, so the problem is how WordPress connects to it.
2. **Read the connection error.** `2002 Connection refused` means nothing is listening where WordPress is looking. That's a host/port problem. A credentials problem would be `1045 Access denied` instead.
3. **Compare config to reality.** `./lab wp config get DB_HOST` → `127.0.0.1`. On this stack the database is a separate host named `db`; `127.0.0.1` is the PHP container itself.
4. **"I only changed WP_DEBUG."** People paste whole blocks from their local `wp-config.php`. Trust the file, not the memory.

## Root cause
`DB_HOST` was changed from `db` to `127.0.0.1` while the developer was editing wp-config.php.

## Fix
`wp config set DB_HOST db` (WP-CLI's `config` commands work even when WordPress can't connect), then turn `WP_DEBUG` back off on the live site.

## Prevent
- Keep environment-specific values out of hand edits: environment variables or a separate local config.
- Back up `wp-config.php` before editing, and diff after.
