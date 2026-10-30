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
```

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
   it stops: Swift changes are never pushed unchecked.
5. Writes the results as `Tested:` trailers. They change the message, not the
   tree, so the tree they name is the tree that was checked.
6. Runs `git push origin <sha>:main`. When main moved meanwhile, it fetches,
   rebases, checks again and retries, three times.

A cloud session gets `ssh m4` from Little Worker's
`bash scripts/m4-ssh-setup.sh` (run it from a little-worker checkout).

## Trailers

```
Customer-note: The selected row stays selected while the list refreshes.
Customer-note: none (internal refactor)
Tested: diff-check pass tree 3f2a9c1d7e0b
Tested: swift-test pass (12 tests, M4 macOS 26.7.2) tree 3f2a9c1d7e0b
Tested: swift-build-release pass (M4 macOS 26.7.2) tree 3f2a9c1d7e0b
Tested: swift skipped (docs only) tree 3f2a9c1d7e0b
```

`Tested:` follows
`^Tested: (\S+) (pass|fail|skipped|not-run)(?: \(([^)]*)\))? tree ([0-9a-f]{12})$`
and only the script writes it. The checks it does not run, such as the
packaged app, the probe modes and UI checks in
[AGENTS.md "Verification"](../AGENTS.md#verification), are written in the
commit body as commands and results. Read trailers with
`git log --format='%(trailers:key=Customer-note,valueonly,unfold)' v0.3.0..main`.

## Exit codes

The last line on standard output is `PUSH: <state> <sha>`.

| Code | Meaning | Next |
|---|---|---|
| 0 | pushed (or checked, with `--verify`) | report the SHA |
| 1 | usage or git error, or the remote refused the push | read the message |
| 2 | a check failed or could not run; main is unchanged | fix the cause, amend, run again |
| 3 | rebase conflict; the rebase was aborted | rebase by hand, run again |
| 4 | main moved on every try | run again |
| 5 | not pushable: dirty tree, nothing to push, several commits, no `Customer-note:` | fix the commit, run again |

## Main's rules

The `main` ruleset refuses deletion and force-pushes and keeps history
linear. It requires no status and no pull request. Only Parker changes it.
