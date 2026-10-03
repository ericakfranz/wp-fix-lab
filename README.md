# WP Fix Lab

A hands-on troubleshooting lab for WordPress support and operations roles. It boots a
real WordPress stack, breaks it the way production sites actually break, hands you the
support ticket, and grades whether you fixed it — with a clear **PASS / FAIL**.

[![Scenarios](https://github.com/YOUR-GITHUB-USERNAME/wp-fix-lab/actions/workflows/scenarios.yml/badge.svg)](https://github.com/YOUR-GITHUB-USERNAME/wp-fix-lab/actions/workflows/scenarios.yml)

## Why it's not just a quiz

Each error **type** is a *generator*, not a fixed puzzle. A seed picks one of several
root causes and a set of red herrings, so starting the same type twice gives you a
different problem. You can't pass by memorising "the answer to the 429 one" — you have
to actually diagnose what's in front of you. The grader checks that the **site works
again**, not that you ran a particular command, so "fixing" a red herring still FAILs.

## Try it in two minutes

**In the browser:** Code → Codespaces → *Create codespace*. Then:

```bash
./lab list
./lab start fatal        # training mode by default
```

**Locally:** you need Docker. Clone, then the same two commands. Site: http://localhost:8080 (`admin` / `admin`).

## Two modes

```bash
./lab start database             # TRAINING: ticket, ./lab hint, and after a PASS,
                                 # diagnosis questions + ./lab runbook
./lab start database --test      # TEST: ticket + PASS/FAIL only. No hints, no runbook,
                                 # no answers. For proving the skill, not teaching it.
./lab start database --seed 42   # reproduce an exact scenario (same seed = same problem)
```

- **Training mode** is for learning: `./lab hint` gives one more nudge each time, and a
  PASS unlocks the runbook and a few diagnosis questions so a lucky fix isn't mistaken
  for understanding.
- **Test mode** gives you the ticket and nothing else. `./lab check` returns PASS or
  FAIL. Hints, runbooks and quizzes are refused.

## How a round works

1. `./lab start <type> [--test] [--seed N]` builds a clean site, breaks it, shows the
   ticket, starts the clock.
2. Investigate like it's a real server: browser + dev tools, `./lab logs`, `./lab wp …`
   (WP-CLI), `./lab shell`.
3. `./lab check` grades by how the site behaves → **PASS / FAIL**. Results append to
   `results.log`.

## Error types (this release)

| Type | Ticket | Variants |
|---|---|---|
| `database` | "Error establishing a database connection" | wrong host / password / DB name / port, with seed-randomised values |
| `fatal` | Blank white page / fatal 500 | missing plugin dependency · mu-plugin syntax error · null-method fatal (PHP 8) |
| `429` | "Connection lost" + 429 errors | one fast poller · hard-coded interval with a decoy setting · two plugins that only flood *together* |

Each type folder has a `RUNBOOK.md` with the full triage path for every variant. It's a
spoiler — so are `scenario.sh`'s `fix`/`break` functions.

## How it's tested

GitHub Actions runs every type across seeds 0–5 (covering all variants) on a real
WordPress stack and proves, for each: the grader **FAILs** while broken, then **PASSes**
after the reference fix. It also smoke-tests that test mode refuses hints and runbooks.

## Adding a variant or a type

A type is one file: `scenarios/<type>/scenario.sh`, which defines `VARIANTS` and the
functions `break`, `fix`, `check`, `ticket`, `hint`, `hint_count`, `quiz`. Each switches
on `$LAB_VARIANT`. To add a variant, add its key to `VARIANTS` and handle it in those
functions. Shared helpers (`wp`, `wp_safe`, `cli_sh`, `mu_install`, `lab_curl`,
`seed_pick`, `is_training`, `pass`/`fail`) live in `lib/common.sh`.

## Roadmap

This is the first slice, built to prove the generator + grader pattern on real
infrastructure. Planned next, same pattern:

- **Environment upgrades** — legacy code fatalling on PHP 8.x; a core/plugin update that
  breaks against custom code.
- **502 / 504** — PHP-FPM down, upstream timeouts (needs a couple of extra stack knobs).
- **Deeper database** — a crashed table needing repair; broken serialized data from a
  careless search-replace.
- **Post-compromise recovery** — a no-malware cleanup drill: find core files that don't
  match official checksums, a rogue admin user, and a rogue scheduled task, in the right
  order. (Contains no malicious code — the "injected" marker is harmless.)

## Stack

nginx → PHP-FPM (official `wordpress` image) → MariaDB, plus WP-CLI on demand. Scenarios
that need "hosting platform" rules drop nginx config into `nginx/lab/`.

## License

MIT
