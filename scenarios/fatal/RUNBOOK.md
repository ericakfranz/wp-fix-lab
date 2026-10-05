# Runbook: Blank white page (fatal 500)

Read this only after you have tried to solve it. This type has three possible
causes, and the seed picks one of them.

## What you see

Every page is blank, even the login page. `curl -I` shows a 500 error with no text.

## How to work through it

1. Check that it is PHP, not the web server. The images and styles still load, but
   the pages are blank. That means PHP stopped, not nginx.
2. Find the error text. It is hidden, not gone. Run `./lab logs wordpress` and look
   for `PHP Fatal error`. The message names the file and the line. Lines that say
   `Deprecated` are only warnings, so ignore them.
3. Read what kind of fatal it is:
   - "Call to undefined function" in a file under `/plugins/`: the plugin needs
     another plugin that was deleted.
   - "syntax error" or "parse error" in a file under `/mu-plugins/`: a bad edit or paste.
   - "Call to a member function ... on null": the code expected something that was
     not there. This is common when old code runs on PHP 8.
4. Note which folder the file is in. A plugin in `wp-content/plugins` can be turned
   off. A must-use plugin in `wp-content/mu-plugins` cannot, and it loads even in WP-CLI.
5. The "Cache Helper" plugin the client just turned on is a decoy. Check it, then rule
   it out using the log. Do not assume the newest change is the cause.

## How to fix it

- Plugin fatal: `./lab wp --skip-plugins plugin deactivate <name>`. WP-CLI loads
  plugins too, so `--skip-plugins` is what lets it run at all.
- Must-use plugin fatal: you cannot turn it off, and WP-CLI stops on it too. Remove
  the file. Run `./lab shell`, then `rm wp-content/mu-plugins/<file>`.
- Then turn the fatal-error handler back on for the client (set
  `WP_DISABLE_FATAL_ERROR_HANDLER` to false), so next time they get a recovery link
  instead of a blank page.

## How to prevent it

Leave the fatal-error handler on in production. Check a plugin's `Requires Plugins`
header before you delete another plugin. Test plugin changes on a staging copy first.
