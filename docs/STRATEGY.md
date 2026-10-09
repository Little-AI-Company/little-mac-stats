# Mac Stats strategy

## Purpose

Answer two questions immediately: How busy is my Mac, and which app or AI tool is responsible?

## First release

- A small monochrome fill meter in the menu bar. No battery silhouette, color, or continuous animation.
- A native, compact popover with total CPU and a descending list of app/tool groups.
- CPU uses the capacity of the entire Mac as 100 percent, including on multicore machines.
- Recognize Codex and Claude, their app helpers, CLI processes, and descendant work. Retain visibility of ordinary apps and unclassified processes. Attribution is based on available process ancestry and executable identity, not AI inference.
- Expand a group to inspect individual processes. Explicit, confirmed Quit and Force Quit actions identify the selected process or group. Recheck the PID, start time, and ownership immediately before signalling. Reject known stale identities, other users, protected system processes, and this utility. POSIX signalling still has a narrow check-to-signal race, documented in validation.
- Native settings, launch at login, keyboard navigation, accessibility labels, and system appearance.
- Sparkle updates with quiet scheduled discovery and an explicit install/check action. Development builds without release credentials report that updates are not configured.
- MIT licensed public source with repeatable build and release instructions.

## Architecture

Use Swift Package Manager, Swift 6, macOS 14 or later, AppKit for status item/popover/window behavior, and Darwin/libproc for process information. Sparkle is the only third-party runtime dependency. No subprocess spawning on each sampling tick.

Keep process sampling off the main thread. Sample system CPU every two seconds while closed, and processes only while the popover is open. Open-panel sampling runs once per second. Stop on sleep and reset baselines after wake. Render only on new samples, with no display-linked animation.

Three modules: `ProcessCore` for sampling, classification, and safe termination; `MacStats` for the native app; `ProcessProbe` for headless integration evidence. Prefer value snapshots across concurrency boundaries.

## Executor integration contract

The process executor publishes the exact API promptly. Expected concepts: a Sendable snapshot with whole-machine CPU percent and process groups; each group includes a stable ID, display name, normalized CPU percent, and processes; each process includes PID, parent PID, UID, start identity, display name, executable path, CPU percent, and termination eligibility. A sampler supports sampling with/without process detail. A termination service revalidates identity and UID immediately before a signal. UI handles confirmation; core handles enforcement and errors.

The release executor owns `UpdateController` as an `@MainActor` type. Coordinate its API with the UI executor. Default repository and bundle identity: `ParkerRex/mac-stats`, `com.parkerrex.mac-stats`. App display name: Mac Stats. Initial version: 0.1.0.

## Ghostty lessons applied

Apply native interactions, unobtrusive updates, keyboard access, settled startup, and work proportional to visibility. Terminal-specific tabs, splits, and undo-close do not belong in this utility.

References:

- [Ghostty custom updater](https://github.com/ghostty-org/ghostty/pull/9116)
- [Sparkle setup](https://sparkle-project.org/documentation/)
- [Sparkle customization](https://sparkle-project.org/documentation/customization/)

## Release boundary

Local development and source publication can be completed here. A public binary advertised as ready for normal installation requires a Developer ID Application certificate, notarization credentials, and a configured Sparkle signing key/feed. Never claim unsigned local builds have that distribution trust.
