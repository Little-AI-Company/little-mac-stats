# Contributing

Small, well-explained contributions are welcome. You are responsible for every line you submit, whether you wrote it yourself or used an AI tool. Read the diff, verify the behavior, and remove anything the change does not need.

## Choose one change

- Check current `main`, existing issues, and open PRs before starting. If another contribution covers the same fix, coordinate there instead of submitting a duplicate.
- Name the behavior you want to change. Keep unrelated dependency updates, formatting, and refactors out of the PR.
- Stay within the [product scope](docs/STRATEGY.md): a lightweight native macOS CPU utility. Discuss substantial features or architecture changes in an issue first. Small fixes do not need prior permission.
- Read [AGENTS.md](AGENTS.md) for the module map, native macOS workflow, protected behavior, and required checks. Those rules apply to human and AI-assisted contributions.

## Establish the problem

For a bug fix, reproduce the problem on a named baseline commit before editing. Keep the command or user steps, expected behavior, observed result, and relevant source location. Fix the cause rather than hiding the symptom.

Define an observable result and choose the cheapest reliable check that could detect a real failure. Reuse existing behavior tests. Add a focused test when it protects a contract or catches a plausible regression that existing checks miss. Use a real process or native UI interaction when an isolated unit test cannot establish the behavior.

Do not add tests that mirror the implementation, weaken assertions to get green, or build extra production layers just to support a test. Test-first works well for clear contracts; explore first when the behavior is not yet understood.

## Implement and verify

Follow the [build instructions](README.md#build-and-run) and [verification requirements](AGENTS.md#verification) for the affected area. Documentation-only changes do not require compiling or releasing the app.

Preserve type safety, explicit ownership, and Swift concurrency checks. Keep failures visible and preserve supported behavior unless the change deliberately updates that contract. Update the relevant documentation in the same PR rather than leaving contradictory instructions.

For native UI changes, include actual screenshots when they help review the change. Exercise the packaged app, including the menu-bar path when it changes. State which views were inspected. Do not publish process names, paths, or other private information from your machine without reviewing the capture.

For performance changes, measure the baseline and changed Release builds under comparable conditions. Include before and after results, commits, hardware, OS, workload, duration, and relevant panel state. Explain the tradeoff and measurement limits. A design goal or estimate is not a measured improvement.

## Prepare the pull request

1. Fetch the latest upstream `main` and rebase your contribution branch onto it. Keep independent changes on independent branches; explain any real dependency on another PR.
2. Re-run affected checks after a rebase or cherry-pick. Record the baseline and tested head commit IDs; results from an earlier head are historical evidence.
3. Read every line of the diff and the description. Passing tests do not replace review. Remove unrelated changes and claims you cannot support.
4. Open a ready-for-review PR, not a draft, using the [template](.github/pull_request_template.md).

Use a short title that names the behavior change, following the repository's conventional titles: `fix: preserve selection during sampling`, `feat: add a display option`, or `docs: clarify local builds`. Add a scope only when it helps.

Keep the description proportional to the change:

- **Summary:** Start with the concrete problem and resulting behavior, then explain the cause and fix. For bug fixes, include the reproduction against the named baseline and the source location of the cause. Only claim baseline failure if you observed it; when updating an existing PR without that evidence, state the gap.
- **Test plan:** List the exact commands run, results, pass counts when available, and tested revision. Check a box only for completed verification. State failures, skips, unavailable environments, and material limits plainly. Add UI evidence or performance measurements when relevant.
- **Disclosure:** End with a brief, accurate statement naming any AI model and harness used. If none were used, say so. Do not guess model details you cannot verify.

Do not paste private maintainer research, personal profiles, or links to private analysis into the PR. This repository's current requirements govern the contribution; another project's restrictions do not become universal rules.

## Follow through

Maintain the branch and resolve conflicts. Verify each review finding against the code before acting. Fix real defects and explain false positives with a specific source or check. Keep replies brief and useful; avoid repeated status requests or comments when nothing has changed.

If an agent is asked to monitor a PR, it should inspect checks and comments newer than the last push, distinguish code failures from infrastructure failures, and stop when the configured review bots are green on the latest commit. It must not claim review approval from a passing build alone.

Only merge when the maintainer or user has authorized that disposition. Otherwise, report the current result and leave the PR open for review.
