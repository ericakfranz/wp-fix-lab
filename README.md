# WP Fix Lab

A hands-on troubleshooting lab for WordPress support and operations roles. It boots a
real WordPress stack, mimicks the way production sites break, hands you a
support ticket, and grades whether you fixed it with a clear **PASS / FAIL**.

## How it works

Each error **type** has several different root causes, and a seed decides which one you get. The problem's identity is randomised every run. Read the logs, find the specific thing that's broken, and act on that.

The grader checks that the site actually works again, that its real data is intact, and that you didn't take a shortcut; like disabling the entire plugin folder. 

Want a real test? `bash lab exam 5` runs five random scenarios back-to-back in test mode (no hints, no answers) and times you. Add `--minutes N` to fail the run if the clock runs out. See [Exam mode](#exam-mode).

## Remote or localhost

1. **On your own computer with Docker** — the full step-by-step guide is below. Best if you want it offline and permanent.
2. **In your web browser with GitHub Codespaces** — no install at all. See [Run it in the browser](#run-it-in-the-browser-no-install) near the end.

---

## Run it on your own computer (step by step)

This guide assumes you have never used Docker or a terminal before. Follow it in order.

### Step 1 — Install Docker Desktop (one time only)

1. Go to **https://www.docker.com/products/docker-desktop/** and click **Download**. Pick the version for your computer:
   - **Mac:** choose "Apple Silicon" if your Mac is from 2020 or later; choose "Intel chip" if it's older. (Not sure? Click the Apple logo, top-left → *About This Mac*. If it says "Apple M1/M2/M3…", that's Apple Silicon.)
   - **Windows:** download "Docker Desktop for Windows." During install, keep the default options and click Yes if it asks to add WSL 2.
2. Open the downloaded file and follow the installer, like installing any other app.
3. **Start Docker Desktop** (open it from your Applications/Start menu). The first launch might take a minute. Wait until the little whale icon in your menu bar / system tray stops animating and sits still. **Docker Desktop must be open and running whenever you use the lab**, so start it first each time.

### Step 2 — Download WP Fix Lab to your computer

If you already have the `wp-fix-lab` folder, skip to Step 3. Otherwise, download it from your GitHub repository:

1. Navigate to the [WP Fix Lab GitHub repo](https://github.com/ericakfranz/wp-fix-lab).
2. Click the green **Code** button → **Download ZIP**.
3. Find the downloaded ZIP (usually in your Downloads folder) and **unzip it** (double-click on Mac; right-click → Extract All on Windows). You now have a folder named `wp-fix-lab` (or `wp-fix-lab-main`). Remember where it is.

### Step 3 — Open a terminal in that folder

A "terminal" is a window where you type commands. The easiest way to open one already pointed at the right folder:

- **Mac:** open the **Terminal** app (press `Cmd + Space`, type `Terminal`, hit Enter). Then type `cd ` (the letters c, d, and a space), drag the `wp-fix-lab` folder from Finder onto the Terminal window (this pastes its location), and press Enter.
- **Windows:** open **File Explorer**, go into the `wp-fix-lab` folder, click the address bar at the top, type `cmd`, and press Enter. A black window opens, already in the folder.

To check you're in the right place, type this and press Enter:

```
docker --version
```

If it prints a version number (like `Docker version 29.x`), Docker is installed. If it says "command not found," Docker Desktop isn't installed or isn't finished starting — go back to Step 1.

### Step 4 — Start your first broken site

Type this command into your terminal and press Enter:

```
bash lab start fatal
```

**The very first time, this takes a few minutes** — Docker is downloading the website pieces. That's normal, and it only happens once; later runs take seconds. When it finishes, it prints a support ticket describing a "broken" site for you to fix.

> We're using `bash lab …` (not `./lab …`) throughout, because files downloaded as a ZIP can lose permission to run on their own. `bash lab …` always works. (If you prefer `./lab …`, run `chmod +x lab` once first.)

### Step 5 — Look at the broken site

Open your web browser and go to:

```
http://localhost:8080
```

That's the WordPress site, running on your own computer using Docker. To log in, add `/wp-login.php` to the address and use username **admin**, password **admin**. Poke around, and read the behind-the-scenes error messages with:

```
bash lab logs wordpress
```

### Step 6 — Try to fix it, then get graded

Investigate, make a change, then check your work:

```
bash lab check
```

You'll get a green **PASS** or red **FAIL**. Stuck? In training mode you can ask for help:

```
bash lab hint        # one more clue each time you run it
bash lab runbook     # shows the full answer for this problem
```

### Step 7 — Start another, or stop for now

See all the problems, or start a specific one:

```
bash lab list
bash lab start database
bash lab start 429
```

When you're done for the day, free up your computer's memory with:

```
bash lab down
```

That stops the local WordPress site through Docker. Your progress and files are safe; `bash lab start …` brings it back any time.

---

## Common Fixes / FAQs

- **`permission denied`** when running `./lab` → use `bash lab …` instead (see Step 4), or run `chmod +x lab` once.
- **"Cannot connect to the Docker daemon" / "Is the docker daemon running?"** → Docker Desktop isn't open. Start it, wait for the whale icon to settle, and try again.
- **"port is already allocated" / port 8080 in use** → another program is using port 8080. Close other local-website tools (like Local, XAMPP, or MAMP) and run the command again.
- **`docker: command not found`** → Docker Desktop isn't installed or your terminal was open before you installed it. Install it (Step 1), then close and reopen the terminal.
- **The site won't load at `localhost:8080`** → give it a few more seconds after `bash lab start`, then refresh. If it still fails, run `bash lab logs` to see what the site is complaining about.
- **You do NOT need to build anything.** There is no image to make and no `Dockerfile` to add. The lab uses the official WordPress, database, and web-server images, and Docker downloads them for you the first time you start it. You just install Docker and run one command.

---

## Two modes

```bash
bash lab start database             # TRAINING: ticket, bash lab hint, and after a PASS,
                                 # diagnosis questions + bash lab runbook
bash lab start database --test      # TEST: ticket + PASS/FAIL only. No hints, no runbook,
                                 # no answers. For proving the skill, not teaching it.
bash lab start database --seed 42   # reproduce an exact scenario (same seed = same problem)
```

- **Training mode** is for learning: `bash lab hint` gives one more nudge each time, and a
  PASS unlocks the runbook and a few diagnosis questions so a lucky fix isn't mistaken
  for understanding.
- **Test mode** gives you the ticket and nothing else. `bash lab check` returns PASS or
  FAIL. Hints, runbooks and quizzes are refused.

## How a round works

1. `bash lab start <type> [--test] [--seed N]` builds a clean site, breaks it, shows the
   ticket and starts the clock.
2. Investigate like it's a real server: browser + dev tools, `bash lab logs`, `bash lab wp …`
   (WP-CLI), `bash lab shell`.
3. `bash lab check` grades by how the site behaves → **PASS / FAIL**. Results append to
   `results.log`.

## Run it in the browser (no install)

Prefer not to install anything? GitHub Codespaces runs the whole lab in your browser on a free Linux machine:

1. Clone WP Fix Lab to your own GitHub repository.
2. On your repo page, click the green **Code** button → **Codespaces** tab → **Create codespace on main**.
3. Wait a minute for the editor to open, then in its terminal at the bottom run `bash lab start fatal`.
4. When it offers to open the forwarded port, click it to see the site (or use the **Ports** tab, port 8080).

Everything else should work the same as on your computer. Delete the codespace at **github.com/codespaces** when done, so it doesn't use your free hours.

## Error types (this release)

| Type | Ticket | Root causes |
|---|---|---|
| `database` | "Error establishing a database connection" | 6: wrong host / password / DB name / port, the database server stopped, wrong table prefix |
| `fatal` | Blank white page / fatal 500 | 10: missing dependency, mu-plugin syntax error, null-method fatal, memory exhausted, `wp-config.php` syntax error, active-theme `functions.php` error, PHP-8 removed function, "Cannot redeclare", plus two **layered** runs where fixing one fatal reveals another |
| `429` | "Connection lost" + 429 errors | 4: one fast poller, a hard-coded interval with a decoy setting, two plugins that only flood *together*, a plugin that only polls for logged-out visitors |

On top of the cause, the seed randomises the specifics so one cause still produces many distinct problems. Each type folder has a `RUNBOOK.md` with the full triage path. It's a spoiler, and so are `scenario.sh`'s `fix` and `apply_break` functions.

## Exam mode

```bash
bash lab exam              # 5 random scenarios, back-to-back, test mode, no time limit
bash lab exam 8            # pick how many
bash lab exam 5 --minutes 20   # fail the run if 20 minutes pass before you finish
bash lab exam status       # progress and time left
bash lab exam stop         # cancel
```

Exam mode runs a random, non-repeating sequence in test mode. Each time you `check` a scenario and pass, it loads the next one. With `--minutes`, the clock is evaluated on every `check`; if it's run out, the exam ends with a failure and tells you to try again. With no limit (the default), it reports your total time when you clear them all. 

## Adding a variant or a type

A type is one file: `scenarios/<type>/scenario.sh`, which defines `VARIANTS` and the functions `break`, `fix`, `check`, `ticket`, `hint`, `hint_count`, `quiz`. Each switches on `$LAB_VARIANT`. To add a variant, add its key to `VARIANTS` and handle it in those functions. Shared helpers (`wp`, `wp_safe`, `cli_sh`, `mu_install`, `lab_curl`, `seed_pick`, `is_training`, `pass`/`fail`) live in `lib/common.sh`.

## Roadmap

This is the first slice, built to prove the generator + grader pattern on real
infrastructure. Future planning:

- **Environment upgrades** — legacy code fatalling on PHP 8.x; a core/plugin update that
  breaks against custom code.
- **502 / 504** — PHP-FPM down, upstream timeouts (needs a couple of extra stack knobs).
- **Deeper database** — a crashed table needing repair; broken serialized data from a
  careless search-replace.
- **Post-compromise recovery** — a no-malware cleanup drill: find core files that don't
  match official checksums, a rogue admin user, and a rogue scheduled task, in the right
  order. (Contains no malicious code — the "injected" marker is harmless.)

## Stack

nginx → PHP-FPM (official `wordpress` image) → MariaDB, plus WP-CLI on demand. Scenarios that need "hosting platform" rules drop nginx config into `nginx/lab/`.

## License

MIT
