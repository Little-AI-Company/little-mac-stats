---
title: "Push to main"
summary: "How a change lands: scripts/push_main.sh checks one commit, records the result in Tested: trailers and fast-forwards main."
read_when:
  - "A change is done and you land it on main."
  - "You revert a commit on main."
  - "You read a commit's Tested: or Customer-note: trailer."
  - "push_main.sh exited with a code other than 0."
---

# Push to main

Work lands on `main` directly. There are no branches, pull requests or CI runs
in this repository (Parker, 2026-10-30). The check runs on the machine that
pushes, on the exact commit that lands. This is the small-repo version of
Little Worker's `docs/push-main.md`; there is no commit status, proof loop or
feature flag here.

## Commands

```sh
scripts/push_main.sh                  # check HEAD's one commit and push it
scripts/push_main.sh --revert <sha>   # revert a commit on main and push that
scripts/push_main.sh --verify         # check HEAD, change and push nothing
scripts/push_main.sh --skip-checks "<why>"   # push without running any check
```

`scripts/push_main_test.sh` tests the script against a temporary origin with
stubbed `ssh` and `swift`: the cap, `--skip-checks`, the retries and the check
paths. Run it after you change `push_main.sh`.

## What it does

1. Refuses a dirty tree, fetches `origin/main`, and needs exactly one commit
   ahead of it. Squash several with `git reset --soft origin/main && git commit`.
2. Gates the message. A `feat`, `fix` or `perf` subject needs a
   `Customer-note:` trailer: one sentence a user would read in the release
   notes, or `Customer-note: none (<reason>)`. A `Customer-note:` line that is
   not in the last paragraph is not a trailer.
3. Rebases the commit onto `origin/main`. A conflict aborts the rebase and
   exits 3.
4. Runs `git diff --check`. When anything other than Markdown, `assets/` or
   `LICENSE` changed, it also runs `swift test` and `swift build -c release`:
   in place on a Mac, and from Linux (a cloud session) on the M4 over
   `ssh m4`. There the commit goes over as a git bundle into a checkout at
   `/Volumes/Claude/little-mac-stats-push`, the job runs detached and the
   script polls it, because one long ssh session drops through the cloud
   proxy. A busy M4 can take about six minutes. With no Mac and no `ssh m4`
   it stops: Swift changes are never pushed unchecked. The Swift checks have
   10 minutes in all (see [The 10 minute cap](#the-10-minute-cap)).
5. Writes the results as `Tested:` trailers. They change the message, not the
   tree, so the tree they name is the tree that was checked.
6. Runs `git push origin <sha>:main`. When main moved meanwhile, it fetches,
   rebases, checks again and retries, 10 times.

A cloud session gets `ssh m4` from Little Worker's
`bash scripts/m4-ssh-setup.sh` (run it from a little-worker checkout).

## The 10 minute cap

`swift test` and `swift build -c release` together get 10 minutes, wherever
they run. On the M4 the 10 minutes count everything the script waits for: the
upload, the queue for the one checkout, and the polling. When they run out the
script stops the job (on the M4 it removes the job directory, which its
watchdog sees, and the watchdog stops the whole process group and frees the
checkout lock), warns, and pushes anyway. The commit says so in place of the
Swift lines:

```
Tested: swift-test+build-release timed out after 10m
```

A timeout is not a failure: nothing is blocked and the exit code is 0. It is
also not a pass, so run the Swift checks yourself when the commit matters. A
check that fails inside the 10 minutes still exits 2. `git diff --check` is not
capped. `PUSH_MAIN_CHECK_TIMEOUT` and `PUSH_MAIN_POLL` (seconds between polls
of the M4, default 15) are for the test script.

## Skipping the checks

```sh
scripts/push_main.sh --skip-checks "<why>"
```

Runs no check, not even `git diff --check`, and writes only
`Tested: skipped: <why>`. The reason is required and one line; an empty or
missing one is a usage error (exit 1) and nothing changes. The
`Customer-note:` gate still applies. Say in the reason why the checks cannot
say anything about the change.

## Trailers

```
Customer-note: The selected row stays selected while the list refreshes.
Customer-note: none (internal refactor)
Tested: diff-check pass tree 3f2a9c1d7e0b
Tested: swift-test pass (12 tests, M4 macOS 26.7.2) tree 3f2a9c1d7e0b
Tested: swift-build-release pass (M4 macOS 26.7.2) tree 3f2a9c1d7e0b
Tested: swift skipped (docs only) tree 3f2a9c1d7e0b
Tested: swift-test+build-release timed out after 10m
Tested: skipped: scripts only, nothing the app builds from changed
```

`Tested:` follows
`^Tested: (\S+) (pass|fail|skipped|not-run)(?: \(([^)]*)\))? tree ([0-9a-f]{12})$`
except the two lines that name no tree because no check passed on one:
`^Tested: (\S+) timed out after \d+[ms]$` and `^Tested: skipped: .+$`. Only
the script writes it. The checks it does not run, such as the
packaged app, the probe modes and UI checks in
[AGENTS.md "Verification"](../AGENTS.md#verification), are written in the
commit body as commands and results. Read trailers with
`git log --format='%(trailers:key=Customer-note,valueonly,unfold)' v0.3.0..main`.

## Exit codes

The last line on standard output is `PUSH: <state> <sha>`.

| Code | Meaning | Next |
|---|---|---|
| 0 | pushed (or checked, with `--verify`) | report the SHA |
| 1 | usage or git error (such as `--skip-checks` without a reason), or the remote refused the push | read the message |
| 2 | a check failed or could not run (a timeout is neither); main is unchanged | fix the cause, amend, run again |
| 3 | rebase conflict; the rebase was aborted | rebase by hand, run again |
| 4 | main moved on all 10 tries | run again |
| 5 | not pushable: dirty tree, nothing to push, several commits, no `Customer-note:` | fix the commit, run again |

## Main's rules

The `main` ruleset refuses deletion and force-pushes and keeps history
linear. It requires no status and no pull request. Only Parker changes it.
