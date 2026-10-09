# Mac Stats

Build a small native macOS menu bar utility. Use plain language, precise names, strict Swift concurrency, and focused tests. No web views, telemetry, decorative cards, color-coded meters, or continuous animation.

## Ownership for the native interface pass

- Data display executor: `Sources/MacStats/ProcessPanelController.swift` and new panel-specific history/bar views.
- Native controls executor: `ApplicationDelegate.swift`, `SettingsWindowController.swift`, and `MacStatsApplication.swift` under `Sources/MacStats/`.
- HIG reviewer: read-only source review and `docs/NATIVE-DESIGN.md`.
- Release executor: `scripts/create_xcode_archive.sh` and `docs/RELEASING.md`.
- Process performance executor: `Sources/ProcessCore/`, `Sources/ProcessProbe/`, and `Tests/ProcessCoreTests/`.
- Orchestrator: integration, `docs/STRATEGY.md`, `docs/VALIDATION.md`, `README.md`, `assets/`, GitHub publication, signing, and verification.

Performance changes must preserve sampling accuracy and process-identity checks. The updater remains unchanged unless an identified issue requires a coordinated fix.

Other agents share this directory. Do not revert their edits. Coordinate API changes and report files changed.

## Required verification

Run `swift test`, a release build, and the packaging script. Verify the running native app, real process grouping, normalized CPU sampling, and termination against disposable test processes only. Record measured overhead and limitations. Never stop the user's active tools as a test.
