# Runbook: 429 Too Many Requests

Read this only after you have tried to solve it. This type has three possible
causes, and the seed picks one of them.

## What you see

The dashboard says "Connection lost. Saving has been disabled...". The browser
console shows many `429` responses on `admin-ajax.php`.

## How to work through it

1. Find out who sends the 429. Run `./lab logs nginx`. You will see it rejecting
   requests with `limiting requests ... zone "ajax"`. That is the hosting platform's
   rule, and the ticket says you cannot change it. So the real question is what is
   making so many requests.
2. Find what is polling. Open the browser Network tab and filter for `admin-ajax`.
   Watch how often the same request repeats, and note its `action=` name. Then match
   that name to a plugin with `grep -r wp_ajax_<name> wp-content/plugins`.
3. Understand why the editor breaks. WordPress Heartbeat also uses `admin-ajax.php`.
   When a plugin uses up the limit, Heartbeat gets blocked too, and the editor thinks
   you are offline. The editor problem is a result, not the cause.
4. Work out which of the three causes it is:
   - One plugin that polls every second. Easy to spot.
   - A plugin with a "poll interval" setting that it ignores, because the speed is
     fixed in the code. Changing the setting does nothing. Confirm that in view-source,
     then turn the plugin off.
   - Two plugins that each look fine on their own, but together go over the limit. You
     have to notice the total, not judge each one alone.

## How to fix it

Fix the plugin, not the rule. Slow it down if its setting works (`./lab wp option
update <setting> 60` sets it to once a minute), or turn it off. With two plugins,
slowing or turning off one is enough to get back under the limit. Never remove the
rate limit. It protects every other site on the server, and it hides the real cause.

## How to prevent it

Treat any plugin that polls `admin-ajax.php` over and over as a performance risk.
Real-time features belong on a slow timer, a cached endpoint, or a proper push service.
