# Mac Stats

Build a small native macOS menu bar utility that shows CPU usage by app and lets the user stop eligible processes. Keep the product simple, fast, and understandable without developer knowledge.

## Repository map

- `Package.swift`: Swift 6, macOS 14 minimum, Swift Package Manager. Sparkle is the only external dependency.
- `Sources/MacStats/`: AppKit status item, popover, settings, and updates.
- `Sources/ProcessCore/`: native sampling, CPU calculations, attribution, and guarded termination.
- `Sources/ProcessProbe/`: command-line integration checks and measurements.
- `Tests/ProcessCoreTests/`: focused Swift Testing behavior tests.
- `scripts/package_app.sh`: canonical local app packaging, including embedded Sparkle and signing.
- `docs/STRATEGY.md`, `docs/NATIVE-DESIGN.md`: product scope and native interface criteria.
- `docs/VALIDATION.md`, `docs/RELEASING.md`: measured evidence, known limits, and distribution procedure.

## Working method

- Read the affected code and current Git state before editing. Preserve unrelated work.
- Define the observable result and the cheapest reliable check that could disprove it. Reuse existing checks before adding tests.
- Use precise types, professional names, direct error handling, and small changes. Explain non-obvious boundaries; avoid speculative abstractions or compatibility layers.
- Preserve Swift 6 concurrency checking. AppKit state belongs on the main actor; sampling and process work stay outside UI updates. Keep ownership and data flow explicit.
- Follow the existing AppKit architecture. Do not introduce SwiftUI, web views, a new build system, or dependencies to implement an ordinary control.
- Use one agent for work that fits one pass. When parallel work is requested and useful, assign file ownership first and coordinate shared APIs. Never revert another contributor's changes.
- A question asks for an answer, not an implementation. Follow the user's requested scope and publishing disposition.

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
open -n "dist/Mac Stats.app"
```

These are available commands, not a requirement to run all four for every edit. Packaging builds the app in Release mode, embeds Sparkle, and signs ad hoc by default. Launch the GUI through the packaged `.app`; a raw `swift run MacStats` is not a substitute for bundle validation. Quit the previous development instance before comparing builds.

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
| Swift code | Run `swift test` and `swift build -c release`. Add or retain tests only for meaningful contracts or plausible failures. |
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

## Contributions and releases

Follow [CONTRIBUTING.md](CONTRIBUTING.md) and the [PR template](.github/pull_request_template.md). Keep each PR focused, read every changed line, and tie proof to the submitted commit. Use a short conventional title consistent with this repository, such as `fix: preserve selection during sampling`.

Keep release work within the user's authorization. Reuse `scripts/package_app.sh` and `docs/RELEASING.md`; ordinary local debugging does not need notarization. Do not publish a release, change the update feed, or merge a PR merely because checks passed.

## Workflow references

These instructions adapt OpenAI's [Build macOS Apps 0.1.4](https://github.com/openai/plugins/tree/0722921d5542fc593105c27bd52630babd8b8c2a/plugins/build-macos-apps) skills for this AppKit and SwiftPM repository: `swiftpm-macos`, `build-run-debug`, `appkit-interop`, `test-triage`, and `packaging-notarization`. Use their project discovery, native bundle launch, focused debugging, explicit ownership, and artifact verification patterns. No plugin installation is required to contribute.

Keep repository instructions concise and tool-neutral, with one home for each rule. See OpenAI's [AGENTS.md guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md) for instruction discovery and scoped review rules.
