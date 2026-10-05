# Runbook: 429 Too Many Requests on admin-ajax

> Spoilers. Solve the scenario first.

## Symptoms
- "Connection lost. Saving has been disabled until you are reconnected." in the editor.
- Browser console / Network tab: `POST /wp-admin/admin-ajax.php` → **429**.

## Triage
1. **Who sent the 429?** Check whether the 429 came from WordPress or from something in front of it. `./lab logs nginx` shows nginx returning 429 and `limiting requests, excess: ... zone "ajax"`. PHP never saw the rejected requests.
2. **What's generating the traffic?** In the Network tab, filter on `admin-ajax`. The request bodies say `action=lof_poll`, once per second, from every open tab, front end and dashboard.
3. **Why does the editor break?** Heartbeat also posts to `admin-ajax.php`. When the plugin burns through the per-IP budget, Heartbeat gets 429s and the editor decides it's offline.
4. **Map action → plugin.** `grep -r "wp_ajax_lof_poll" wp-content/plugins` → Live Order Feed, installed Monday.

## Root cause
Live Order Feed polls `admin-ajax.php` every second (its `lof_poll_interval` option defaults to 1). That's 60 requests per minute per tab against a platform limit of 30.

## Fix
- Keep the feature, fix the behavior: `wp option update lof_poll_interval 60`
- Or deactivate the plugin if the client doesn't need it.
- **Not** the fix: removing the rate limit. It protects every site on the server, and the client's PHP workers were being spent on a popup.

## Prevent
- Treat any plugin that polls `admin-ajax.php` as a performance review item.
- Real-time features belong on a long interval, the REST API with caching, or a push service, not in per-second polling.
