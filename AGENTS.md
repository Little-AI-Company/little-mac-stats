# Mac Stats

Build a small native macOS menu bar utility. Use plain language, precise names, strict Swift concurrency, and focused tests. No web views, telemetry, decorative cards, color-coded meters, or continuous animation.

## Ownership for the per-core display pass

- Data display executor: `Sources/MacStats/ProcessPanelController.swift` and new panel-specific display-choice rows.
- Native controls executor: `ApplicationDelegate.swift` and new display-style/renderer types under `Sources/MacStats/`.
- HIG reviewer: read-only source review and `docs/NATIVE-DESIGN.md`.
- Release executor: `scripts/create_xcode_archive.sh` and `docs/RELEASING.md`.
- Process performance executor: `Sources/ProcessCore/`, `Sources/ProcessProbe/`, and `Tests/ProcessCoreTests/`.
- Orchestrator: integration, `docs/STRATEGY.md`, `docs/VALIDATION.md`, `README.md`, `assets/`, GitHub publication, signing, and verification.

Per-core measurements must use real kernel counters, free kernel-allocated memory, and stay inexpensive with the panel closed. Preserve sampling accuracy and process-identity checks. Use two display styles: monochrome per-core blocks by default and percentage as an alternative. Style choices need a leading preview and a separated native footer. The updater remains unchanged unless an identified issue requires a coordinated fix.

Other agents share this directory. Do not revert their edits. Coordinate API changes and report files changed.

## Required verification

Run `swift test`, a release build, and the packaging script. Verify the running native app, real process grouping, normalized CPU sampling, and termination against disposable test processes only. Record measured overhead and limitations. Never stop the user's active tools as a test.
