#!/usr/bin/env bash
# Tests for scripts/push_main.sh: the 10 minute cap, --skip-checks, the retry
# count and the Swift check paths, against a temporary bare origin.
#
#   scripts/push_main_test.sh
#
# Nothing here needs a Mac, Swift or the real M4. `uname`, `ssh`, `swift` and
# `sw_vers` are stubs on PATH: the ssh stub runs the remote command in a local
# shell, so the detached job, its polling and its cleanup run as they do on the
# M4. The cap and the poll interval are a few seconds.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/push-main-test.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export GIT_CONFIG_GLOBAL=/dev/null

mkdir -p "$ROOT/bin"
cat >"$ROOT/bin/uname" <<'STUB'
#!/usr/bin/env bash
echo "${STUB_UNAME:-Linux}"
STUB
cat >"$ROOT/bin/sw_vers" <<'STUB'
#!/usr/bin/env bash
echo 26.0
STUB
# STUB_SWIFT: pass | fail | hang (sleeps until killed, pid in $STUB_PIDFILE) |
# race (pushes a commit to origin from the second clone once, then passes).
cat >"$ROOT/bin/swift" <<'STUB'
#!/usr/bin/env bash
echo "swift $*" >>"$STUB_SWIFT_LOG"
case "${STUB_SWIFT:-pass}" in
  pass) echo "Test run with 3 tests passed" ;;
  fail) echo "Test run with 3 tests failed"; exit 1 ;;
  hang) sleep 300 & echo $! >"$STUB_PIDFILE"; wait ;;
  race)
    if [ ! -e "$STUB_RACED" ]; then
      touch "$STUB_RACED"
      git -C "$STUB_MAC" commit -q --allow-empty -m "chore: other push"
      git -C "$STUB_MAC" push -q origin HEAD:main
    fi
    echo "Test run with 1 tests passed"
    ;;
esac
STUB
cat >"$ROOT/bin/ssh" <<'STUB'
#!/usr/bin/env bash
# Drop the options and the host, run the command in a local shell.
echo "ssh $*" >>"$STUB_SSH_LOG"
while [ $# -gt 0 ]; do
  case "$1" in
    -o) shift 2 ;;
    *) break ;;
  esac
done
shift
exec bash -c "$*"
STUB
chmod +x "$ROOT/bin/"*

failures=0
tests=0
fail() {
  echo "  FAIL: $*"
  failures=$((failures + 1))
}
expect_eq() { [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; }
expect_has() { grep -qF -- "$2" <<<"$1" || fail "$3: expected to find '$2' in: $1"; }
expect_lacks() { ! grep -qF -- "$2" <<<"$1" || fail "$3: did not expect '$2' in: $1"; }

# A bare origin, a work clone holding a copy of the script and one Swift file,
# a second clone that plays another pusher, and a pre-made "M4" checkout.
setup() {
  T="$ROOT/t$tests"
  mkdir -p "$T"
  git init -q --bare -b main "$T/origin.git"
  git clone -q "$T/origin.git" "$T/work" 2>/dev/null
  mkdir -p "$T/work/scripts" "$T/work/Sources"
  cp "$REPO/scripts/push_main.sh" "$T/work/scripts/push_main.sh"
  echo "let a = 1" >"$T/work/Sources/a.swift"
  git -C "$T/work" add -A
  git -C "$T/work" commit -q -m "chore: start"
  git -C "$T/work" push -q origin HEAD:main
  git clone -q "$T/origin.git" "$T/mac" 2>/dev/null
  git clone -q "$T/origin.git" "$T/m4dir" 2>/dev/null
  : >"$T/ssh.log"
  : >"$T/swift.log"
  echo "let b = 2" >"$T/work/Sources/b.swift"
  git -C "$T/work" add -A
  git -C "$T/work" commit -q -m "${1:-chore: add b}"
}

# push [VAR=value ...] -- [args]: runs the copied script with the stubs.
push() {
  local envs=()
  while [ "$1" != -- ]; do
    envs+=("$1")
    shift
  done
  shift
  OUT="$(cd "$T/work" && env "${envs[@]}" PATH="$ROOT/bin:$PATH" \
    PUSH_MAIN_M4_DIR="$T/m4dir" STUB_SSH_LOG="$T/ssh.log" STUB_SWIFT_LOG="$T/swift.log" \
    STUB_PIDFILE="$T/hang.pid" STUB_RACED="$T/raced" STUB_MAC="$T/mac" \
    bash scripts/push_main.sh "$@" 2>"$T/stderr")"
  RC=$?
  ERR="$(cat "$T/stderr")"
  LAST="${OUT##*$'\n'}"
}
origin_body() { git -C "$T/origin.git" log -1 --format=%B main; }
origin_head() { git -C "$T/origin.git" rev-parse main; }
begin() {
  tests=$((tests + 1))
  echo "- $1"
}

begin "a passing check records the trailers and pushes (10 retries, 10m default)"
setup
push --
expect_eq "$RC" 0 "exit"
expect_eq "$LAST" "PUSH: pushed $(origin_head)" "last line"
expect_has "$(origin_body)" "Tested: diff-check pass tree " "diff-check trailer"
expect_has "$(origin_body)" "Tested: swift-test pass (3 tests, M4 macOS 26.0) tree " "swift trailer"
grep -q 'CAP="${PUSH_MAIN_CHECK_TIMEOUT:-600}"' "$REPO/scripts/push_main.sh" || fail "the default cap is not 600 seconds"
grep -q '^RETRIES=10$' "$REPO/scripts/push_main.sh" || fail "RETRIES is not 10"

begin "the M4 polling wait has a cap: the job is stopped, the trailer says so, the push goes ahead"
setup
started=$SECONDS
push STUB_SWIFT=hang PUSH_MAIN_CHECK_TIMEOUT=5 PUSH_MAIN_POLL=1 --
expect_eq "$RC" 0 "exit"
[ $((SECONDS - started)) -lt 60 ] || fail "took too long"
expect_eq "$LAST" "PUSH: pushed $(origin_head)" "last line"
expect_has "$ERR" "WARNING: swift test and swift build ran past 5s" "warning"
body="$(origin_body)"
expect_has "$body" "Tested: swift-test+build-release timed out after 5s" "timeout trailer"
expect_lacks "$body" "swift-test pass" "no pass line"
expect_eq "$(grep -c '^Tested: ' <<<"$body")" 2 "trailer count (diff-check and timeout)"
# The hung swift on the "M4" is killed by the watchdog, the lock and job dirs go.
for _ in $(seq 20); do
  kill -0 "$(cat "$T/hang.pid" 2>/dev/null || echo 0)" 2>/dev/null || break
  sleep 1
done
kill -0 "$(cat "$T/hang.pid" 2>/dev/null || echo 0)" 2>/dev/null && fail "the hung swift is still running"
[ ! -d "$T/m4dir.lock" ] || fail "the lock was left behind"
[ -z "$(ls "$T/m4dir.jobs" 2>/dev/null)" ] || fail "the job directory was left behind"

begin "a local Mac run has the same cap"
setup
push STUB_UNAME=Darwin STUB_SWIFT=hang PUSH_MAIN_CHECK_TIMEOUT=3 --
expect_eq "$RC" 0 "exit"
expect_has "$(origin_body)" "Tested: swift-test+build-release timed out after 3s" "timeout trailer"
expect_eq "$(cat "$T/ssh.log")" "" "no ssh on a Mac"
kill -0 "$(cat "$T/hang.pid" 2>/dev/null || echo 0)" 2>/dev/null && fail "the hung swift is still running"

begin "a check that fails inside the cap still exits 2 and pushes nothing"
setup
before="$(origin_head)"
push STUB_SWIFT=fail PUSH_MAIN_CHECK_TIMEOUT=30 PUSH_MAIN_POLL=1 --
expect_eq "$RC" 2 "exit"
expect_eq "$(origin_head)" "$before" "origin unchanged"
expect_has "$LAST" "PUSH: red " "last line"

begin "--skip-checks runs nothing and writes only Tested: skipped: <why>"
setup
push STUB_SWIFT=fail -- --skip-checks "scripts only, nothing to run"
expect_eq "$RC" 0 "exit"
body="$(origin_body)"
expect_has "$body" "Tested: skipped: scripts only, nothing to run" "skipped trailer"
expect_eq "$(grep -c '^Tested: ' <<<"$body")" 1 "one Tested line"
expect_eq "$(cat "$T/ssh.log")" "" "no ssh"
expect_eq "$(cat "$T/swift.log")" "" "no swift"

begin "--skip-checks needs a non-empty reason"
setup
before="$(origin_head)"
check_refused() {
  expect_eq "$RC" 1 "exit for $1"
  expect_has "$ERR" "--skip-checks needs a reason" "message for $1"
  expect_eq "$(origin_head)" "$before" "origin unchanged for $1"
}
push -- --skip-checks
check_refused "no reason"
push -- --skip-checks ""
check_refused "an empty reason"
push -- --skip-checks "   "
check_refused "a blank reason"

begin "--skip-checks is allowed with --verify and pushes nothing"
setup
before="$(origin_head)"
push -- --verify --skip-checks "why"
expect_eq "$RC" 0 "exit"
expect_has "$LAST" "PUSH: verified " "last line"
expect_eq "$(origin_head)" "$before" "origin unchanged"

begin "main moving retries with 10 tries and one set of Tested lines"
setup
push STUB_SWIFT=race PUSH_MAIN_POLL=1 --
expect_eq "$RC" 0 "exit"
expect_has "$ERR" "main moved (try 1 of 10)" "retry message"
expect_eq "$(grep -c '^Tested: swift-test pass' <<<"$(origin_body)")" 1 "one swift trailer"
expect_eq "$(git -C "$T/origin.git" log --format=%s main | head -2 | tr '\n' '|')" "chore: add b|chore: other push|" "history"

begin "a Customer-note is still required for fix"
setup "fix: b"
before="$(origin_head)"
push -- --skip-checks "why"
expect_eq "$RC" 5 "exit"
expect_has "$LAST" "PUSH: no-customer-note" "last line"
expect_eq "$(origin_head)" "$before" "origin unchanged"

echo
if [ "$failures" -eq 0 ]; then
  echo "push_main_test: $tests tests passed"
else
  echo "push_main_test: $failures check(s) failed in $tests tests"
  exit 1
fi
