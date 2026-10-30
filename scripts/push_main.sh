#!/usr/bin/env bash
# Check HEAD's one commit and fast-forward main with it (docs/PUSH-MAIN.md).
# There are no pull requests, branches or CI runs in this repository
# (Parker, 2026-10-30); every change lands through this script.
#
#   scripts/push_main.sh                  # check HEAD's one commit and push it
#   scripts/push_main.sh --revert <sha>   # revert a commit on main and push that
#   scripts/push_main.sh --verify         # check HEAD, change and push nothing
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
# The trailers change the message, not the tree, so the tree they name is the
# tree that was checked. When main moved meanwhile it rebases, checks again
# and retries (three tries). The last line on standard output is
# "PUSH: <state> <sha>", and the exit code says what to do next:
#   0  pushed (or checked, with --verify)
#   1  usage, or a git error
#   2  a check failed or could not run (main is unchanged)
#   3  the rebase conflicts (it is aborted and the branch left as it was)
#   4  main kept moving for three tries
#   5  not pushable: dirty tree, nothing to push, more than one commit,
#      or no Customer-note
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Changes to these files need no Swift build.
NO_BUILD_PATHS='(\.md$|^assets/|^LICENSE$)'
M4_DIR="${PUSH_MAIN_M4_DIR:-/Volumes/Claude/little-mac-stats-push}"
CLONE_URL="https://github.com/Little-AI-Company/little-mac-stats.git"
RETRIES=3

say() { echo "push-main: $*" >&2; }
finish() {
  local code="$1"
  shift
  echo "PUSH: $*"
  exit "$code"
}

usage() {
  sed -n '6,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}
verify=0
revert=""
while [ $# -gt 0 ]; do
  case "$1" in
    --verify) verify=1 ;;
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
trap 'rm -rf "$tmp"' EXIT

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

# Runs `swift test` and `swift build -c release` on HEAD, here on a Mac or on
# the M4 from anywhere else. Sets SWIFT_WHERE; returns the checks' exit code
# (test failure 10, build failure 11, cannot run 12).
swift_checks() {
  if [ "$(uname -s)" = Darwin ] && command -v swift >/dev/null 2>&1; then
    SWIFT_WHERE="local macOS $(sw_vers -productVersion)"
    swift test >"$tmp/swift.log" 2>&1 || return 10
    swift build -c release >>"$tmp/swift.log" 2>&1 || return 11
    return 0
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
# A mkdir lock keeps two pushes from sharing the checkout at once.
find "\$d.lock" -maxdepth 0 -mmin +60 -exec rm -rf {} + 2>/dev/null
until mkdir "\$d.lock" 2>/dev/null; do echo "waiting for \$d.lock"; sleep 10; done
trap 'rm -rf "\$d.lock"' EXIT
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
run
echo \$? >"\$job/exit"
REMOTE
  ssh_m4() { ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 m4 "$@"; }
  ssh_m4 "mkdir -p '$job' && cat >'$job/head.bundle'" <"$tmp/head.bundle" &&
    ssh_m4 "cat >'$job/job.sh' && nohup bash '$job/job.sh' >'$job/log' 2>&1 </dev/null &" <"$tmp/job.sh" || {
    SWIFT_WHERE="M4 unreachable"
    return 12
  }
  SWIFT_WHERE="M4"
  local waited=0 misses=0
  code=""
  while [ -z "$code" ]; do
    sleep 15
    waited=$((waited + 15))
    if out="$(ssh_m4 "cat '$job/exit' 2>/dev/null; true" 2>/dev/null)"; then
      misses=0
      code="$out"
    else
      misses=$((misses + 1))
      [ "$misses" -lt 8 ] || code=12
    fi
    [ "$waited" -lt 3600 ] || code=12
    [ $((waited % 120)) -ne 0 ] || say "still running on the M4 (${waited}s)"
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
