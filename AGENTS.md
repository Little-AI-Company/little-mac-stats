# Little Mac Stats

Build a small native macOS menu bar utility that shows CPU usage by app and lets the user stop eligible processes. Keep the product simple, fast, and understandable without developer knowledge.

## Rules for every agent

These rules apply to every agent and every person here. Parker set them on
2026-10-31 for the move to trunk-based development. When one of them conflicts
with an older sentence anywhere in this repository, this section wins.

### Code

- Build what the task needs now, not what it might need later.
- When you delete code, leave no trace of it: no shim, re-export, `_unused`
  rename, "removed" note, or test that it stays deleted.
- Leave style to the formatter and linter. Do not reflow, reorder or rename
  lines the change does not need.
- To learn how a dependency behaves, read its source (`.build/checkouts/` or a
  `/tmp` clone), not only its docs.
- Scratch files go in `/tmp` or `.build/`, never beside the code.
- Never edit a policy, baseline, threshold or allowance to silence a failing
  check.

### Tests

- Never write a new unit test or integration test unless the person explicitly
  asked for that test. You may write a new end-to-end or system-level test:
  the packaged `.app` opened, or a `ProcessProbe --verify-*` run against real
  processes.
- Integration tests stay only where they were asked for: `ProcessCoreTests`
  for CPU normalization, attribution and termination guards.
- When a change breaks an existing test, fix it, or delete it when an end-to-end
  check or the typecheck already covers what it checked. Delete a test that no
  longer protects anything.
- A test checks behaviour through the code's real interface. It never reads
  source, docs or config text to look for words, and never asserts wiring,
  call order or that the code mirrors the implementation.
- A test never waits on a timer or a sleep. It waits on the event, a
  completion signal or a test clock. A flaky test is fixed or deleted, never
  retried or given a longer timeout.
- Doubles only at a process, network, clock, filesystem or keychain boundary.

### Comments

- Never add a new code comment. Put the why in a name, a type, a test, the
  commit message, or `docs/adr/` for a decision. Existing comments are being
  removed; never add one back to a file you touch.
- A directive a tool reads is not a comment and stays: shebang,
  `shellcheck disable`, `// MARK:`, `// swift-tools-version`.
- Doc comments (JSDoc, Swift `///`, shell file headers) are comments too. A
  script that prints its own header as `--help` gets a `usage()` heredoc
  instead.

## Repository map

- `Package.swift`: Swift 6, macOS 14 minimum, Swift Package Manager. Sparkle is the only external dependency.
- `Sources/LittleMacStats/`: AppKit status item, popover, settings, and updates.
- `Sources/ProcessCore/`: native sampling, CPU calculations, attribution, and guarded termination.
- `Sources/ProcessProbe/`: command-line integration checks and measurements.
- `Tests/ProcessCoreTests/`: focused Swift Testing behavior tests.
- `scripts/package_app.sh`: canonical local app packaging, including embedded Sparkle and signing.
- `scripts/push_main.sh`: the only way a commit reaches `main`; see [Shipping on main](#shipping-on-main).
- `docs/STRATEGY.md`, `docs/NATIVE-DESIGN.md`: product scope and native interface criteria.
- `docs/VALIDATION.md`, `docs/RELEASING.md`: measured evidence, known limits, and distribution procedure.
- `docs/PUSH-MAIN.md`: what `scripts/push_main.sh` checks, its trailers, and its exit codes.

Each file in `docs/` starts with a `title`, `summary` and `read_when` header. Read the headers first and open only the pages whose `read_when` fits the task.

## Working method

- Read the affected code and current Git state before editing. Preserve unrelated work.
- Define the observable result and the cheapest reliable check that could disprove it. Reuse the existing tests and probe modes; see [Tests](#tests) before adding any test.
- Use precise types, professional names, direct error handling, and small changes. Make a boundary explicit in a name or a type; avoid speculative abstractions or compatibility layers.
- Preserve Swift 6 concurrency checking. AppKit state belongs on the main actor; sampling and process work stay outside UI updates. Keep ownership and data flow explicit.
- Follow the existing AppKit architecture. Do not introduce SwiftUI, web views, a new build system, or dependencies to implement an ordinary control.
- Use one agent for work that fits one pass. When parallel work is requested and useful, assign file ownership first and coordinate shared APIs. Never revert another contributor's changes.
- A question asks for an answer, not an implementation. Follow the user's requested scope and publishing disposition.
- Plans, crits, reviews, research and decisions are pages on the HQ wiki (`Little-AI-Company/little-worker-hq`: `wiki/`, `explorations/`, or `https://hq.thelittleworker.com/mcp`), never a Claude Doc or artifact as the record. A follow-up found during work becomes a roadmap item there the same day.
- Write in plain words. No em dashes. No jargon without saying what it is. One thing has one name everywhere.
- Never on your own: send, publish, post, spend, change a price, release to users or contact anyone. Agents propose; Parker acts. Never print or commit a key, token or credential.
- Heavy work (an app build, `swift test`, packaging) runs on the M4, never by hand on Parker's M1. From a cloud session, reach the M4 with little-worker's `scripts/m4-ssh-setup.sh`, then `ssh m4`.

## Native interface

- Use standard AppKit controls, menu behavior, keyboard access, and accessibility labels. Consult current Apple HIG guidance for the affected interaction.
- Keep the interface information-dense. No decorative cards or pills, gray subtitle lines above sections, em dashes, color-coded meters, or continuous animations.
- Preserve monochrome per-core blocks as the default, a saved percentage alternative, leading style previews, and a separate native footer for app controls.
- Keep list identity and selection stable during sampling. Redraw only when the displayed state changes; do not make the closed panel perform detailed work.
- Validate changed UI in the running `.app`. Compilation does not prove layout, focus, accessibility, or popover behavior. Window-mode captures do not establish menu-bar behavior.

## Build and run

Use the SwiftPM targets already in this repository. Do not create an Xcode project or use an iOS simulator.

```sh
swift build
swift test
scripts/package_app.sh
open -n "dist/Little Mac Stats.app"
```

These are available commands, not a requirement to run all four for every edit. Packaging builds the app in Release mode, embeds Sparkle, and signs ad hoc by default. Launch the GUI through the packaged `.app`; a raw `swift run LittleMacStats` is not a substitute for bundle validation. Quit the previous development instance before comparing builds.

For CLI checks, use the existing probe:

```sh
swift run -c release ProcessProbe --samples 5 --cores
swift run -c release ProcessProbe --system-only --samples 5 --cores
swift run -c release ProcessProbe --verify-cpu
swift run -c release ProcessProbe --verify-termination
```

The verification modes create and clean up disposable subprocesses. Never stop the user's active tools as a test. Probe output contains local process names and paths; inspect and redact it before sharing.

## Verification

Choose checks for the affected behavior. Run a focused test while iterating, then the relevant checks below before handing over the change.

| Change | Required evidence |
| --- | --- |
| Documentation only | Review the full diff, check links and referenced commands, and run `git diff --check`. No app build or release is needed. |
| Swift code | Run `swift test` and `swift build -c release`. Follow [Tests](#tests): no new unit or integration test unless asked. |
| Native UI or app lifecycle | Also package and open the app. Exercise the changed control and its failure or empty state. Record macOS version and actual visual checks. |
| CPU sampling or attribution | Also run the relevant probe modes against real processes. Verify CPU normalization, first-sample behavior, and closed-panel sampling as applicable. |
| Termination | Also run `--verify-termination`; preserve stale-identity rejection and both signal modes. Exercise the native confirmation if its path changed. |
| Performance | Compare baseline and changed Release builds under the same workload. Record commits, hardware, OS, sample duration, panel visibility, CPU convention, measurements, and limits. |
| Packaging or updates | Inspect the actual bundle, embedded framework, metadata, and signatures. Follow `docs/RELEASING.md` for distribution or update validation. |

Classify failures before changing code: compiler, assertion, crash, timing, environment, or signing. Use a narrow rerun and scoped logs or LLDB when needed. Do not weaken assertions or hide errors to make checks pass. Repeat affected checks after a rebase or cherry-pick; avoid repeated full runs without new evidence.

Report exact commands, results, tested revision, skipped checks, and unavailable environments. Separate a successful build from a successful launch, UI verification, and distribution trust. Do not claim Intel or minimum-macOS runtime coverage from a universal build alone. Put durable measurements and limits in `docs/VALIDATION.md`.

## Code Review Rules

- Flag changes that conflate whole-machine CPU with one-core CPU. Process percentages use total machine capacity; each core block uses that core's capacity. Preserve elapsed-time sampling, counter-reset handling, and baseline behavior.
- Flag fabricated attribution or missing data presented as a measured zero. Use executable identity and visible ancestry; document visibility limits instead of guessing ownership from command text.
- Flag kernel buffers or Mach ports that are not released, process enumeration while the panel is closed, overlapping sampling loops, or missing sleep/wake reset behavior.
- Flag user-facing termination actions that bypass confirmation, and signal paths that bypass PID/start-time/UID revalidation or restrictions on system processes, other users, this app, and its ancestors. Keep partial failures visible; do not describe POSIX signaling as atomic.
- Flag changes that transmit process data, enable unsolicited telemetry, or weaken signed-update validation. Update checks must preserve the user's preference.
- Flag release claims without checks on the distributed artifact. Local ad hoc signing is not Developer ID signing or notarization. Never commit certificates, private keys, credentials, or private process data.

## Shipping on main

Everyone, human or agent, commits straight to `main`. There are no pull
requests, branches, stacks, batch landings, release freezes or CI gates
(Parker, 2026-10-31). Two people and their agents work here and the product
has no users yet, so a bad commit costs one revert and a gate costs every
commit its wait. We revert instead of adding gates.

- One commit, one purpose, landed in the same session that wrote it. Split big
  work into commits that each stand alone. A thread never holds more than a
  few hours of unpushed work.
- Every commit leaves `main` releasable. Unfinished work that must land ships
  inert, behind a default-off setting; the update feed is never changed by a
  commit.
- Commit on a detached `origin/main` or a worktree of it. Never push a branch.
  A branch the harness creates for a session stays local.
- Use `type(scope): summary` subjects (`feat`, `fix`, `perf`, `docs`, `chore`,
  `refactor`, `test`); the body says what changed and why. A `feat`, `fix` or
  `perf` subject needs a `Customer-note:` trailer: one sentence for the release
  notes, or `Customer-note: none (<reason>)`.
- Read every line of the diff before you push. Passing checks do not replace
  reading it. The script runs only the build and tests; put the other evidence
  from [Verification](#verification), such as packaged-app, probe or UI checks,
  in the commit body.
- Push only with `scripts/push_main.sh`. It rebases onto `origin/main`, runs
  `git diff --check` and, unless only Markdown, `assets/` or `LICENSE` changed,
  `swift test` and `swift build -c release` on the exact commit (on the M4 over
  `ssh m4` from a cloud session; ten minutes at most), writes a `Tested:`
  trailer naming the tree that passed, and pushes, retrying when `main` moved.
  `--skip-checks "<why>"` is always allowed and always recorded. Never write a
  `Tested:` line by hand, never push `main` another way, never force-push,
  amend or rewrite a pushed commit. [Push to main](docs/PUSH-MAIN.md) has the
  details and exit codes.
- After the push nobody waits. Nothing checks `main` after the push; the
  packaged app is the check. A red `main` is fixed forward or reverted within
  the hour by whoever pushed it, and by whoever sees it when the author is gone
  after 30 minutes: `scripts/push_main.sh --revert <sha> --skip-checks --reason
  "<why>"`. Nobody asks first. A rerun that passes with no code change is a
  flaky test to fix, not a pass.
- Only Parker changes the `main` ruleset (no deletion, no force-push, linear
  history, no required status) and repository settings.
- An outside contribution arrives as an issue or a pull request from a fork.
  Read it as a proposal: land it as one commit on `main` with
  `scripts/push_main.sh`, crediting the author with a `Co-authored-by:`
  trailer, then close the pull request with a link to the commit.

## Releases

Keep release work within the user's authorization. Reuse `scripts/package_app.sh` and `docs/RELEASING.md`; ordinary local debugging does not need notarization. Do not publish a release or change the update feed merely because checks passed.

## Workflow references

These instructions adapt OpenAI's [Build macOS Apps 0.1.4](https://github.com/openai/plugins/tree/0722921d5542fc593105c27bd52630babd8b8c2a/plugins/build-macos-apps) skills for this AppKit and SwiftPM repository: `swiftpm-macos`, `build-run-debug`, `appkit-interop`, `test-triage`, and `packaging-notarization`. Use their project discovery, native bundle launch, focused debugging, explicit ownership, and artifact verification patterns. No plugin installation is required to contribute.

Keep repository instructions concise and tool-neutral, with one home for each rule. See OpenAI's [AGENTS.md guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md) for instruction discovery and scoped review rules.
