#!/usr/bin/env bash
# Check HEAD's one commit and fast-forward main with it (docs/PUSH-MAIN.md).
# There are no pull requests, branches or CI runs in this repository
# (Parker, 2026-10-30); every change lands through this script.
#
#   scripts/push_main.sh                  # check HEAD's one commit and push it
#   scripts/push_main.sh --revert <sha>   # revert a commit on main and push that
#   scripts/push_main.sh --verify         # check HEAD, change and push nothing
#   scripts/push_main.sh --skip-checks "<why>"   # push without running any check
#
# It refuses a dirty tree, fetches origin/main, rebases the one commit ahead
# of it onto it, and gates the message: a feat, fix or perf subject needs a
# `Customer-note:` trailer (the release notes are read from it). Then it runs
# the checks on that exact commit and writes them as trailers:
#
#   Tested: diff-check pass tree 3f2a9c1d7e0b
#   Tested: swift-test pass (local macOS 26.1) tree 3f2a9c1d7e0b
#   Tested: swift-build-release pass (local macOS 26.1) tree 3f2a9c1d7e0b
#   Tested: swift skipped (docs only) tree 3f2a9c1d7e0b
#
# A change that touches only Markdown, assets/ or LICENSE runs no Swift
# check. Otherwise it runs `swift test` and `swift build -c release` in place
# on a Mac, and from Linux (a cloud session) on the M4 over `ssh m4`
# (little-worker's scripts/m4-ssh-setup.sh), in a checkout on its build SSD
# that receives the commit as a git bundle. With neither, it stops (exit 2):
# Swift changes are not pushed unchecked. The packaged app, probe and UI
# checks in AGENTS.md "Verification" are the author's; write them in the body.
#
# The Swift checks together get 10 minutes, on the M4 including the wait for
# its checkout and the polling. Past that they are stopped (on the M4 too),
# the script warns and pushes anyway, and the commit says so:
#
#   Tested: swift-test+build-release timed out after 10m
#
# --skip-checks runs no check, not even the diff check. It needs a non-empty
# reason, which the commit keeps instead of every other Tested: line:
#
#   Tested: skipped: <why>
#
# The trailers change the message, not the tree, so the tree they name is the
# tree that was checked. When main moved meanwhile it fetches, rebases, checks
# again and retries (10 tries). The last line on standard output is
# "PUSH: <state> <sha>", and the exit code says what to do next:
#   0  pushed (or checked, with --verify)
#   1  usage, or a git error
#   2  a check failed or could not run (main is unchanged); a timeout is
#      neither
#   3  the rebase conflicts (it is aborted and the branch left as it was)
#   4  main kept moving for 10 tries
#   5  not pushable: dirty tree, nothing to push, more than one commit,
#      or no Customer-note
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Changes to these files need no Swift build.
NO_BUILD_PATHS='(\.md$|^assets/|^LICENSE$)'
M4_DIR="${PUSH_MAIN_M4_DIR:-/Volumes/Claude/little-mac-stats-push}"
CLONE_URL="https://github.com/Little-AI-Company/little-mac-stats.git"
RETRIES=10
# Seconds the Swift checks may take. Tests set PUSH_MAIN_CHECK_TIMEOUT and
# PUSH_MAIN_POLL (seconds between polls of the M4) to a few seconds.
CAP="${PUSH_MAIN_CHECK_TIMEOUT:-600}"
POLL="${PUSH_MAIN_POLL:-15}"

say() { echo "push-main: $*" >&2; }
finish() {
  local code="$1"
  shift
  echo "PUSH: $*"
  exit "$code"
}

usage() {
  sed -n '6,9p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}
[[ "$CAP" =~ ^[1-9][0-9]*$ ]] && [[ "$POLL" =~ ^[1-9][0-9]*$ ]] || {
  say "PUSH_MAIN_CHECK_TIMEOUT and PUSH_MAIN_POLL must be numbers of seconds"
  exit 1
}
cap_label() {
  if [ $((CAP % 60)) -eq 0 ]; then echo "$((CAP / 60))m"; else echo "${CAP}s"; fi
}
verify=0
revert=""
skip_why=""
while [ $# -gt 0 ]; do
  case "$1" in
    --verify) verify=1 ;;
    --skip-checks)
      [ $# -ge 2 ] && [[ "$2" =~ [^[:space:]] ]] || {
        say '--skip-checks needs a reason: --skip-checks "<why>"'
        usage
      }
      case "$2" in *$'\n'* | *$'\r'*) say "the --skip-checks reason is one line" && usage ;; esac
      skip_why="$2"
      shift
      ;;
    --revert)
      [ $# -ge 2 ] || usage
      revert="$2"
      shift
      ;;
    *) usage ;;
  esac
  shift
done
[ -z "$revert" ] || [ "$verify" -eq 0 ] || usage

tmp="$(mktemp -d "${TMPDIR:-/tmp}/push-main.XXXXXX")"
CAPPED_PID=""
cleanup() {
  [ -z "$CAPPED_PID" ] || kill -TERM -- "-$CAPPED_PID" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

[ -z "$(git status --porcelain)" ] || finish 5 "dirty - : commit or stash first"
git fetch --quiet origin main || finish 1 "fetch-failed - : git fetch origin main"

if [ -n "$revert" ]; then
  target="$(git rev-parse --verify --quiet "$revert^{commit}")" || finish 1 "usage - : $revert is not a commit"
  git merge-base --is-ancestor "$target" origin/main || finish 5 "not-on-main $target - : only a commit on main can be reverted"
  git switch --quiet --detach origin/main
  git revert --no-edit "$target" >/dev/null || {
    git revert --abort >/dev/null 2>&1 || true
    finish 3 "conflict $target - : the revert does not apply on origin/main"
  }
  say "reverted ${target:0:12} as $(git rev-parse --short=12 HEAD)"
fi

trailer() { git log -1 --format="%(trailers:key=$1,valueonly,unfold)" | sed '/^$/d'; }
rebase() {
  [ "$(git merge-base HEAD origin/main)" != "$(git rev-parse origin/main)" ] || return 0
  if ! git rebase --quiet origin/main >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1 || true
    finish 3 "conflict $(git rev-parse HEAD) : rebase onto origin/main by hand, then run this again"
  fi
}

count="$(git rev-list --count origin/main..HEAD)"
[ "$count" -ge 1 ] || finish 5 "nothing - : HEAD has no commit that origin/main lacks"
[ "$count" -eq 1 ] || finish 5 "commits=$count - : one change per push; squash with git reset --soft origin/main && git commit"
subject="$(git log -1 --format=%s)"
if [[ "$subject" =~ ^(feat|fix|perf)(\([^\)]*\))?!?: ]] && [ -z "$(trailer Customer-note)" ]; then
  if git log -1 --format=%B | grep -q '^Customer-note:'; then
    finish 5 "no-customer-note $(git rev-parse HEAD) : the Customer-note: line is not in the last paragraph, so it is not a trailer"
  fi
  finish 5 "no-customer-note $(git rev-parse HEAD) : add 'Customer-note: <one sentence>' or 'Customer-note: none (<reason>)' as a trailer"
fi

# Runs a command in its own process group with its output in a log file. It
# gets CAP seconds; after that the whole group is stopped and TIMED_OUT is 1.
# Returns the command's status.
TIMED_OUT=0
capped() {
  local log="$1" rc=0 start
  shift
  TIMED_OUT=0
  set -m
  "$@" >"$log" 2>&1 &
  CAPPED_PID=$!
  set +m
  start=$SECONDS
  while kill -0 "$CAPPED_PID" 2>/dev/null; do
    if [ $((SECONDS - start)) -ge "$CAP" ]; then
      TIMED_OUT=1
      kill -TERM -- "-$CAPPED_PID" 2>/dev/null || true
      sleep 2
      kill -KILL -- "-$CAPPED_PID" 2>/dev/null || true
      break
    fi
    sleep 1
  done
  wait "$CAPPED_PID" 2>/dev/null || rc=$?
  CAPPED_PID=""
  return "$rc"
}

local_swift_run() {
  swift test || return 10
  swift build -c release || return 11
}

# Runs `swift test` and `swift build -c release` on HEAD, here on a Mac or on
# the M4 from anywhere else, within CAP seconds. Sets SWIFT_WHERE; returns the
# checks' exit code (test failure 10, build failure 11, cannot run 12, ran
# past the cap 124).
swift_checks() {
  local start=$SECONDS
  if [ "$(uname -s)" = Darwin ] && command -v swift >/dev/null 2>&1; then
    local rc=0
    SWIFT_WHERE="local macOS $(sw_vers -productVersion)"
    capped "$tmp/swift.log" local_swift_run || rc=$?
    [ "$TIMED_OUT" -eq 0 ] || return 124
    return "$rc"
  fi
  if ! ssh -o BatchMode=yes -o ConnectTimeout=10 m4 true >/dev/null 2>&1; then
    SWIFT_WHERE="no Mac and no ssh m4"
    return 12
  fi
  # The job runs detached on the M4 and is polled with short ssh calls: one
  # ssh session held open for a whole build drops through the cloud proxy.
  local sha job code
  sha="$(git rev-parse HEAD)"
  job="$M4_DIR.jobs/${sha:0:12}-$$"
  git bundle create "$tmp/head.bundle" origin/main..HEAD >/dev/null 2>&1
  cat >"$tmp/job.sh" <<REMOTE
set -u
d='$M4_DIR'
job='$job'
cap=$CAP
run() {
  [ -d "\$d/.git" ] || git clone -q '$CLONE_URL' "\$d" || return 12
  cd "\$d" || return 12
  git fetch -q origin main || return 12
  git fetch -q "\$job/head.bundle" HEAD && git checkout -q --detach FETCH_HEAD && git clean -qfdx -e .build || return 12
  [ "\$(git rev-parse HEAD)" = '$sha' ] || return 12
  echo "macOS \$(sw_vers -productVersion)"
  swift test || return 10
  swift build -c release || return 11
}
work() {
  # A mkdir lock keeps two pushes from sharing the checkout at once.
  find "\$d.lock" -maxdepth 0 -mmin +60 -exec rm -rf {} + 2>/dev/null
  until mkdir "\$d.lock" 2>/dev/null; do echo "waiting for \$d.lock"; sleep 10; done
  trap 'rm -rf "\$d.lock"' EXIT
  run
}
# The lock wait and the checks run in their own process group, stopped by a
# watchdog when the pushing side gives up (it removes \$job) or, as a backstop,
# 30 seconds after the cap.
set -m
work &
wp=\$!
set +m
(
  start=\$SECONDS
  while kill -0 "\$wp" 2>/dev/null; do
    if [ ! -d "\$job" ] || [ \$((SECONDS - start)) -ge \$((cap + 30)) ]; then
      kill -TERM -- "-\$wp" 2>/dev/null
      sleep 3
      kill -KILL -- "-\$wp" 2>/dev/null
      break
    fi
    sleep 2
  done
) >/dev/null 2>&1 &
wd=\$!
rc=0
wait "\$wp" || rc=\$?
kill "\$wd" 2>/dev/null
[ "\$rc" -lt 128 ] || rc=124
echo \$rc >"\$job/exit"
REMOTE
  ssh_m4() { ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 m4 "$@"; }
  ssh_m4 "mkdir -p '$job' && cat >'$job/head.bundle'" <"$tmp/head.bundle" &&
    ssh_m4 "cat >'$job/job.sh' && { nohup bash '$job/job.sh' >'$job/log' 2>&1 </dev/null & }" <"$tmp/job.sh" || {
    SWIFT_WHERE="M4 unreachable"
    return 12
  }
  SWIFT_WHERE="M4"
  local elapsed misses=0 next_note=120
  code=""
  while [ -z "$code" ]; do
    sleep "$POLL"
    elapsed=$((SECONDS - start))
    if out="$(ssh_m4 "cat '$job/exit' 2>/dev/null; true" 2>/dev/null)"; then
      misses=0
      code="$out"
    else
      misses=$((misses + 1))
      [ "$misses" -lt 8 ] || code=12
    fi
    # The cap counts the whole wait, the M4's lock queue included. Removing
    # the job directory below tells the M4's watchdog to stop the job.
    [ -n "$code" ] || [ "$elapsed" -lt "$CAP" ] || code=124
    if [ -z "$code" ] && [ "$elapsed" -ge "$next_note" ]; then
      say "still running on the M4 (${elapsed}s)"
      next_note=$((next_note + 120))
    fi
  done
  ssh_m4 "cat '$job/log'; rm -rf '$job'" >"$tmp/swift.log" 2>/dev/null || true
  local os
  os="$(grep -m1 -Eo '^macOS [0-9.]+' "$tmp/swift.log" | cut -d' ' -f2 || true)"
  [ -z "$os" ] || SWIFT_WHERE="M4 macOS $os"
  return "$code"
}

# Runs the checks on HEAD and sets TESTED (trailer lines) and STATE.
run_checks() {
  local tree code tests
  tree="$(git rev-parse HEAD^{tree} | cut -c1-12)"
  TESTED=()
  STATE=pass
  if [ -n "$skip_why" ]; then
    say "skipping every check: $skip_why"
    TESTED+=("Tested: skipped: $skip_why")
    return 0
  fi
  if git diff --check origin/main HEAD >"$tmp/diff-check.log" 2>&1; then
    TESTED+=("Tested: diff-check pass tree $tree")
  else
    TESTED+=("Tested: diff-check fail tree $tree")
    STATE=fail
    cat "$tmp/diff-check.log" >&2
  fi
  if ! git diff --name-only origin/main HEAD | grep -Evq "$NO_BUILD_PATHS"; then
    TESTED+=("Tested: swift skipped (docs only) tree $tree")
    return 0
  fi
  say "running swift test and swift build -c release on $(git rev-parse --short=12 HEAD)"
  code=0
  swift_checks || code=$?
  tests="$(grep -Eo 'Test run with [0-9]+ tests' "$tmp/swift.log" | tail -1 | grep -Eo '[0-9]+' || true)"
  case "$code" in
    0)
      TESTED+=("Tested: swift-test pass (${tests:+$tests tests, }$SWIFT_WHERE) tree $tree")
      TESTED+=("Tested: swift-build-release pass ($SWIFT_WHERE) tree $tree")
      ;;
    10)
      TESTED+=("Tested: swift-test fail ($SWIFT_WHERE) tree $tree")
      STATE=fail
      ;;
    11)
      TESTED+=("Tested: swift-test pass (${tests:+$tests tests, }$SWIFT_WHERE) tree $tree")
      TESTED+=("Tested: swift-build-release fail ($SWIFT_WHERE) tree $tree")
      STATE=fail
      ;;
    124)
      # Pushed anyway: the state stays pass and the trailer says what happened.
      TESTED+=("Tested: swift-test+build-release timed out after $(cap_label)")
      tail -10 "$tmp/swift.log" >&2 || true
      say "WARNING: swift test and swift build ran past $(cap_label) and were stopped; pushing anyway, and the Tested: trailer says so"
      ;;
    *)
      TESTED+=("Tested: swift not-run ($SWIFT_WHERE) tree $tree")
      STATE=fail
      ;;
  esac
  [ "$STATE" = pass ] || tail -30 "$tmp/swift.log" >&2
}

write_trailers() {
  local args=() t
  for t in "${TESTED[@]}"; do args+=(--trailer "$t"); done
  git log -1 --format=%B | sed -E '/^Tested: /d' | git interpret-trailers --if-exists add "${args[@]}" >"$tmp/msg"
  git commit --quiet --amend --no-verify -F "$tmp/msg"
}

if [ "$verify" -eq 1 ]; then
  run_checks
  printf '%s\n' "${TESTED[@]}" >&2
  [ "$STATE" = pass ] || finish 2 "red $(git rev-parse HEAD)"
  finish 0 "verified $(git rev-parse HEAD)"
fi

for ((try = 1; try <= RETRIES; try++)); do
  rebase
  run_checks
  printf '%s\n' "${TESTED[@]}" >&2
  [ "$STATE" = pass ] || finish 2 "red $(git rev-parse HEAD)"
  write_trailers
  sha="$(git rev-parse HEAD)"
  if out="$(git push --porcelain origin "$sha:refs/heads/main" 2>&1)"; then
    finish 0 "pushed $sha"
  fi
  printf '%s\n' "$out" >&2
  case "$out" in
    *"non-fast-forward"* | *"fetch first"*) ;;
    *) finish 1 "push-refused $sha" ;;
  esac
  say "main moved (try $try of $RETRIES); fetching, rebasing and checking again"
  git fetch --quiet origin main || finish 1 "fetch-failed $sha - : git fetch origin main"
done
finish 4 "raced $(git rev-parse HEAD) : main moved $RETRIES times"
