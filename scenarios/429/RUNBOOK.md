# Runbook: 429 / admin-ajax flood

> Spoilers. Solve it first. Three root causes; the seed picks one.

## Symptoms
- "Connection lost. Saving has been disabled…" in the editor.
- `POST /wp-admin/admin-ajax.php` → 429 in the browser console.

## Triage, in order
1. **Who sends the 429?** `./lab logs nginx` → `limiting requests … zone "ajax"`. That's
   the platform guardrail. The ticket says it's off-limits, so the question is what's
   generating the traffic.
2. **What's polling?** Network tab → filter `admin-ajax`. Note the repeat rate and the
   `action=` value, then map it: `grep -r wp_ajax_<action> wp-content/plugins`.
3. **Why the editor breaks:** Heartbeat also uses admin-ajax.php, so it gets rate-limited
   alongside the plugin and the editor thinks it's offline.
4. **Count the total, not just one.** The three variants:
   - one plugin polling every second (obvious),
   - a plugin hard-coded to 1s whose "interval" setting is a **decoy** (changing it does
     nothing — confirm in view-source that the enqueued interval actually changed),
   - two plugins that each look modest (~5s) but **together** exceed the budget.

## Fix
Fix the site's behavior, never the guardrail:
- Raise the interval **if the setting really takes effect**
  (`./lab wp option update <opt> 60`), or
- deactivate the offending plugin (`./lab wp plugin deactivate <name>`); with two
  offenders, slowing or dropping one is enough to get under budget.

Removing the rate limit "works" and is the wrong answer: it spends every other site's
resources and hides a plugin hammering PHP.

## Prevent
Treat any plugin that polls admin-ajax as a performance review item; real-time features
belong on a long interval, a cached REST endpoint, or a push service.
