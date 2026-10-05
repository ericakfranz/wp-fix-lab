# Runbook: Error establishing a database connection

> Spoilers. Solve it first. This type has four root causes; the seed picks one.

## Symptoms
- Every page: "Error establishing a database connection."
- With `WP_DEBUG` on, a line in `./lab logs wordpress` such as
  `mysqli_real_connect(): (HY000/2002): Connection refused`.

## Triage, in order
1. **Is the DB server actually down?** `./lab logs db` — if MariaDB says "ready for
   connections," the server is fine and the problem is how WordPress *connects*.
2. **Read the specific error code** (this is what tells the variants apart):
   - `2002 Connection refused` → wrong **host** or **port** (nothing is listening there).
   - `1045 Access denied` → wrong **user/password**.
   - `1049 Unknown database` → wrong **DB name** (server reached, database missing).
3. **Compare config to reality:** `./lab wp config list`. On this stack the database
   is a separate container: host `db`, port `3306`, user/pass/name all `wordpress`.
4. **Ignore the decoy.** `WP_DEBUG` being on is the last thing the dev touched, not the
   cause. Trust the file, not their memory — people paste more than they remember.

## Fix
`./lab wp config set DB_<thing> <correct value>` for the one wrong value, then
`./lab wp config set WP_DEBUG false --raw`. WP-CLI's `config` edits wp-config.php
directly, so it works even when WordPress itself can't connect.

## Prevent
Keep environment-specific values out of hand edits (env vars / a separate local
config), and diff wp-config.php before and after any change.
