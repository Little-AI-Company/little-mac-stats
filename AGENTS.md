# Mac Stats

Build a small native macOS menu bar utility. Use plain language, precise names, strict Swift concurrency, and focused tests. No web views, telemetry, decorative cards, color-coded meters, or continuous animation.

## Ownership for the initial implementation

- Process executor: `Sources/ProcessCore/`, `Sources/ProcessProbe/`, `Tests/ProcessCoreTests/`.
- Interface executor: `Sources/MacStats/` except `UpdateController.swift`.
- Release executor: `Package.swift`, `Package.resolved`, `Sources/MacStats/UpdateController.swift`, `Resources/`, `scripts/`, `README.md`, `LICENSE`, `.gitignore`, and `docs/RELEASING.md`.
- Orchestrator: integration, `docs/STRATEGY.md`, `docs/VALIDATION.md`, `assets/`, GitHub publication, and verification.

Other agents share this directory. Do not revert their edits. Coordinate API changes and report files changed.

## Required verification

Run `swift test`, a release build, and the packaging script. Verify the running native app, real process grouping, normalized CPU sampling, and termination against disposable test processes only. Record measured overhead and limitations. Never stop the user's active tools as a test.
