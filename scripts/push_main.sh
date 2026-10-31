#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NO_BUILD_PATHS='(\.md$|^assets/|^LICENSE$)'
M4_DIR="${PUSH_MAIN_M4_DIR:-/Volumes/Claude/little-mac-stats-push}"
CLONE_URL="https://github.com/Little-AI-Company/little-mac-stats.git"
RETRIES=10
CAP="${PUSH_MAIN_CHECK_TIMEOUT:-600}"
POLL="${PUSH_MAIN_POLL:-15}"
SWIFT_COMMENT='^[[:space:]]*(//|/\*)'
SWIFT_DIRECTIVE='^[[:space:]]*//[[:space:]]*(MARK:|swift-tools-version)'
SHELL_COMMENT='^[[:space:]]*#'
SHELL_DIRECTIVE='^[[:space:]]*#(!|[[:space:]]*shellcheck[[:space:]])'

say() { echo "push-main: $*" >&2; }
finish() {
  local code="$1"
  shift
  echo "PUSH: $*"
  exit "$code"
}

usage() {
  cat >&2 <<'USAGE'
  scripts/push_main.sh                  # check HEAD's one commit and push it
  scripts/push_main.sh --revert <sha>   # revert a commit on main and push that
  scripts/push_main.sh --verify         # check HEAD, change and push nothing
  scripts/push_main.sh --skip-checks "<why>"   # push without running any check
USAGE
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

comment_lines() {
  { git grep -hE "$SWIFT_COMMENT" "$1" -- '*.swift' | grep -Ev "$SWIFT_DIRECTIVE" || true
    git grep -hE "$SHELL_COMMENT" "$1" -- '*.sh' | grep -Ev "$SHELL_DIRECTIVE" || true; } | grep -c . || true
}

new_comment_lines() {
  { git diff -U0 origin/main HEAD -- '*.swift' | sed -n 's/^+//p' | grep -v '^++' | grep -E "$SWIFT_COMMENT" | grep -Ev "$SWIFT_DIRECTIVE" || true
    git diff -U0 origin/main HEAD -- '*.sh' | sed -n 's/^+//p' | grep -v '^++' | grep -E "$SHELL_COMMENT" | grep -Ev "$SHELL_DIRECTIVE" || true; }
}

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
  find "\$d.lock" -maxdepth 0 -mmin +60 -exec rm -rf {} + 2>/dev/null
  until mkdir "\$d.lock" 2>/dev/null; do echo "waiting for \$d.lock"; sleep 10; done
  trap 'rm -rf "\$d.lock"' EXIT
  run
}
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
  local before after
  before="$(comment_lines origin/main)"
  after="$(comment_lines HEAD)"
  if [ "$after" -gt "$before" ]; then
    TESTED+=("Tested: no-new-comments fail ($before to $after lines) tree $tree")
    STATE=fail
    say "comment lines rose from $before to $after; AGENTS.md bans new code comments. New lines:"
    new_comment_lines >&2
  else
    TESTED+=("Tested: no-new-comments pass ($after lines) tree $tree")
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
