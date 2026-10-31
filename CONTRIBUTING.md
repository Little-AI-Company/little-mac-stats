# Contributing

Small, well-explained contributions are welcome. You are responsible for every line you submit, whether you wrote it yourself or used an AI tool. Read the diff, verify the behavior, and remove anything the change does not need.

## Choose one change

- Check current `main` and existing issues and pull requests before starting. If another contribution covers the same fix, coordinate there instead of submitting a duplicate.
- Name the behavior you want to change. Keep unrelated dependency updates, formatting, and refactors out of the change.
- Stay within the [product scope](docs/STRATEGY.md): a lightweight native macOS CPU utility. Discuss substantial features or architecture changes in an issue first. Small fixes do not need prior permission.
- Read [AGENTS.md](AGENTS.md) for the module map, native macOS workflow, protected behavior, and required checks. Those rules apply to human and AI-assisted contributions.

## Establish the problem

For a bug fix, reproduce the problem on a named baseline commit before editing. Keep the command or user steps, expected behavior, observed result, and relevant source location. Fix the cause rather than hiding the symptom.

Define an observable result and choose the cheapest reliable check that could detect a real failure. Reuse the existing tests and `ProcessProbe` modes. Do not add a unit or integration test unless a maintainer asks for one; an end-to-end check against a real process or the native UI is welcome.

Do not add code comments: say why through names, types and the commit message. Never weaken assertions to get green or build extra production layers just to support a test.

## Implement and verify

Follow the [build instructions](README.md#build-and-run) and [verification requirements](AGENTS.md#verification) for the affected area. Documentation-only changes do not require compiling or releasing the app.

Preserve type safety, explicit ownership, and Swift concurrency checks. Keep failures visible and preserve supported behavior unless the change deliberately updates that contract. Update the relevant documentation in the same change rather than leaving contradictory instructions.

For native UI changes, include actual screenshots when they help review the change. Exercise the packaged app, including the menu-bar path when it changes. State which views were inspected. Do not publish process names, paths, or other private information from your machine without reviewing the capture.

For performance changes, measure the baseline and changed Release builds under comparable conditions. Include before and after results, commits, hardware, OS, workload, duration, and relevant panel state. Explain the tradeoff and measurement limits. A design goal or estimate is not a measured improvement.

## Send the change

Changes land on `main` as single commits; there are no branches, merge buttons or CI runs. Maintainers and agents commit on `main` and run `scripts/push_main.sh`, which rebases, runs the build and tests on the exact commit, records them as `Tested:` trailers and pushes. See [Push to main](docs/PUSH-MAIN.md).

From outside the project, open an issue, or a pull request against `main` with the fix. A maintainer reviews it, lands it on `main` as one commit with you credited as co-author, and closes the pull request with a link to that commit. Before you send it:

1. Rebase onto the latest `main` and re-run the affected checks. Record the tested commit ID; results from an earlier commit are historical evidence.
2. Read every line of the diff and the description. Passing tests do not replace review. Remove unrelated changes and claims you cannot support.

Use a short subject that names the behavior change, following the repository's conventional subjects: `fix: preserve selection during sampling`, `feat: add a display option`, or `docs: clarify local builds`. Add a scope only when it helps. A `feat`, `fix` or `perf` change also carries one sentence for the release notes (the `Customer-note:` trailer).

Keep the description proportional to the change:

- **Summary:** Start with the concrete problem and resulting behavior, then explain the cause and fix. For bug fixes, include the reproduction against the named baseline and the source location of the cause. Only claim baseline failure if you observed it.
- **Test plan:** List the exact commands run, results, pass counts when available, and tested revision. State failures, skips, unavailable environments, and material limits plainly. Add UI evidence or performance measurements when relevant.
- **Disclosure:** End with a brief, accurate statement naming any AI model and harness used. If none were used, say so. Do not guess model details you cannot verify.

Do not paste private maintainer research, personal profiles, or links to private analysis into the change. This repository's current requirements govern the contribution; another project's restrictions do not become universal rules.

## Follow through

Verify each review finding against the code before acting. Fix real defects and explain false positives with a specific source or check. Keep replies brief and useful; avoid repeated status requests or comments when nothing has changed.

A broken `main` is fixed or reverted within the hour by whoever pushed it (`scripts/push_main.sh --revert <sha>`). Publishing a release stays a maintainer decision; passing checks do not authorize one.
