# WP Break/Fix Lab

A hands-on troubleshooting lab for WordPress support and operations roles. It boots a real WordPress site, breaks it the way production sites really break, gives you the support ticket, and grades whether you fixed it **and** understood why.

[![Scenarios](https://github.com/YOUR-GITHUB-USERNAME/wp-breakfix-lab/actions/workflows/scenarios.yml/badge.svg)](https://github.com/YOUR-GITHUB-USERNAME/wp-breakfix-lab/actions/workflows/scenarios.yml)

## Try it in two minutes

**In the browser:** Code → Codespaces → *Create codespace*. Then in the terminal:

```bash
./lab list
./lab start wsod
```

**Locally:** you need Docker. Clone, then the same two commands. The site runs at http://localhost:8080 (`admin` / `admin`).

## How a round works

1. `./lab start <scenario>` builds a clean site, breaks it, and shows you the client's ticket. The clock starts.
2. Investigate with whatever you'd use on a real server: the browser and dev tools, `./lab logs`, `./lab wp ...` (WP-CLI), `./lab shell`.
3. `./lab check` grades the fix by how the site behaves, not by how you fixed it. If it passes, you answer a few diagnosis questions so a lucky fix isn't counted as understanding.
4. Your result and time go into `results.log`.

## Scenarios

| Scenario | The ticket |
|---|---|
| `wsod` | The whole site is a blank white page |
| `429-rate-limit` | Dashboard keeps saying "Connection lost" and 429 errors |
| `db-connection` | "Error establishing a database connection" |

Each folder in `scenarios/` has a `RUNBOOK.md` with the full triage path, root cause, fix and prevention. **They're spoilers**, and so are `break.sh` and `solution.sh`.

## How it's tested

GitHub Actions runs every scenario against a real WordPress stack on each push and proves two things:

1. After the break, the grader **fails**, so the scenario really breaks the site.
2. After the reference fix, the grader **passes**, so the scenario can be fixed and the grader recognizes the fix.

## Adding a scenario

Create `scenarios/<name>/` with:

| File | Purpose |
|---|---|
| `ticket.md` | What the client reports. The first line is the title. |
| `break.sh` | Breaks a clean site. Can use helpers from `lib/common.sh` (`wp`, `in_php`, `install_plugin_from`). |
| `check.sh` | Sourced by `./lab check`. Uses `pass` / `fail`, never exits. Test the outcome the client cares about. |
| `solution.sh` | The reference fix, used by CI. |
| `quiz.txt` | Diagnosis questions (`Q:`, `A)`…, `ANSWER:`). |
| `RUNBOOK.md` | The write-up. |

Then add the name to the matrix in `.github/workflows/scenarios.yml`.

## Stack

nginx → PHP-FPM (official `wordpress` image) → MariaDB, plus WP-CLI on demand. Scenarios that need "hosting platform" rules drop nginx config into `nginx/lab/`.

## License

MIT
