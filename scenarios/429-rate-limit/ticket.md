# Dashboard keeps saying "Connection lost" and 429 errors

> **From:** Marcus (store manager)
> **Priority:** High
>
> Ever since this week, the dashboard is unusable after a minute or two. We get
> "Connection lost. Saving has been disabled until you are reconnected." while
> editing products, and our developer saw lots of "429 Too Many Requests" in the
> browser console. Can you just turn off whatever is blocking us?
>
> We did add a cool live order popup plugin on Monday, if that matters.

Note: you're on the hosting company's support team. The platform's rate-limit
rules (nginx/lab/platform-ratelimit.*) are protecting every customer on the
server and are **not** yours to change. Fix the site, not the guardrail.

Tip: reproduce it. Log in at the site URL (admin / admin), open your browser's
dev tools Network tab, and wait.

Run `./lab ticket` to see this again. You have WP-CLI (`./lab wp ...`),
a shell (`./lab shell`) and logs (`./lab logs nginx`).
