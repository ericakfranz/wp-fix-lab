# Runbook: Error establishing a database connection

Read this only after you have tried to solve it. This type has four possible
causes, and the seed picks one of them.

## What you see

Every page shows the same line: "Error establishing a database connection."

## How to work through it

1. Check that the database server is up. Run `./lab logs db`. If it says "ready for
   connections," the server is fine. So the problem is how WordPress connects to it.
2. Read the exact error. With `WP_DEBUG` on, run `./lab logs wordpress` and read the
   mysqli line. The wording tells you which setting is wrong:
   - "Connection refused" (2002): wrong host or port.
   - "Access denied" (1045): wrong username or password.
   - "Unknown database" (1049): wrong database name.
3. Compare the settings to reality. Run `./lab wp config list`. In this lab the
   database is a separate container: host `db`, port `3306`, and the username,
   password, and name are all `wordpress`. One of those four is wrong.
4. Ignore the decoy. The debug line the developer added did not break the site. It is
   only the last thing they touched. Trust the file, not their memory.

## How to fix it

Set the one wrong value back, for example `./lab wp config set DB_HOST db`. Then turn
debug off with `./lab wp config set WP_DEBUG false --raw`. WP-CLI's config command
edits wp-config.php directly, so it works even when WordPress cannot connect.

## How to prevent it

Keep site-specific values out of hand-typed edits. Back up wp-config.php before you
change it, so you can compare it afterward and see what changed.
