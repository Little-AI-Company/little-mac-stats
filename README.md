I made this to see which AI bot is eating my CPU without digging through traces or dealing with bloated, slow stats apps.

If you want to contribute, feel free to [open a PR](https://github.com/ParkerRex/mac-stats/compare) and read the [contribution guide](CONTRIBUTING.md). Please don't throw slop grenades at me.

**Everything below here is AI slop.**

---

![Mac Stats](assets/repository-header.png)

Mac Stats is a small native macOS menu bar utility for seeing total CPU usage and which apps or command-line tools are responsible.

The menu bar shows a small block for each logical CPU. Blocks move from outline through light and medium shading to solid as that core gets busier. A percentage display is also available. Click to see a minute of CPU history and usage by app. Search for Codex, Claude, another app, or a process. Each row pairs a usage bar with its exact percentage. Expand a group to inspect its processes. Stop opens a native confirmation with Quit and Force Quit; the app rechecks the process identity before sending a signal. Display choices include previews, with Settings, updates, About, and Quit in a separate footer. There are no web views, telemetry, accounts, or continuous animations.

## Install

Requires macOS 14 or later. Install through the [Homebrew tap](https://github.com/ParkerRex/homebrew-tap):

```sh
brew install --cask parkerrex/tap/mac-stats
```

Open **Mac Stats** from Applications. If the same release is already installed manually, use `brew install --cask --adopt parkerrex/tap/mac-stats` to let Homebrew manage the identical app. Use **Check for Updates** in the app, or run `brew update` followed by `brew upgrade --cask --greedy parkerrex/tap/mac-stats`.

Signed, notarized downloads are also available through [GitHub Releases](https://github.com/ParkerRex/mac-stats/releases). Unzip the app, move it to Applications, and open it. Both installation methods use the same release archive, which supports Apple silicon and Intel; runtime validation was performed on Apple silicon with macOS 27.0.1. See [validation](docs/VALIDATION.md) for measured performance and remaining limits.

## Screenshots

Real screenshots of the running app with live data. The CPU panel is shown in window mode for capture; normal use is from the menu bar.

| CPU usage and display styles | Search and process details |
| --- | --- |
| <a href="assets/screenshots/cpu-overview.jpg"><img src="assets/screenshots/cpu-overview.jpg" alt="Live CPU history, app usage, display-style previews, and application controls" width="420"></a> | <a href="assets/screenshots/process-details.jpg"><img src="assets/screenshots/process-details.jpg" alt="Codex search with its individual processes expanded" width="420"></a> |

**Settings**

<a href="assets/screenshots/settings.jpg"><img src="assets/screenshots/settings.jpg" alt="Native settings for launch at login and automatic update checks" width="420"></a>

## Build and run

Requires macOS 14 or later and a Swift 6 toolchain. Install Xcode or its Command Line Tools. Sparkle 2.10.0 is the only external package and is pinned in `Package.resolved`.

```sh
git clone https://github.com/ParkerRex/mac-stats.git
cd mac-stats
swift test
swift build -c release
scripts/package_app.sh
open "dist/Mac Stats.app"
```

The script builds the release executable, embeds Sparkle, adds the icon and app metadata, and signs the bundle ad hoc by default. It also produces `dist/Mac-Stats-0.2.0.zip`, a local development archive. Version defaults come from `Resources/Info.plist`. The app runs only in the menu bar. Use Settings to enable launch at login. For local installation, copy `dist/Mac Stats.app` into `/Applications`, then open that copy. Local ad hoc signing does not provide the trust of a Developer ID signed and notarized release.

To build for both Apple silicon and Intel:

```sh
UNIVERSAL=1 scripts/package_app.sh
```

To regenerate the checked-in icon after changing its source:

```sh
scripts/create_app_icon.sh
```

## CPU and attribution

100% means all logical CPUs are fully busy. A process using one full logical CPU on a 12-CPU Mac shows about 8.3%. This differs from Activity Monitor's per-core process convention, where the same process shows about 100%. Whole-machine CPU comes from system CPU counters; process CPU comes from the change in each process's accumulated CPU time. The totals can differ because sampling and process visibility differ.

The app groups processes using executable paths, app bundle identity, and visible parent processes. It recognizes Codex, Claude, and selected other tools. Descendant work remains in its tool group while ancestry is visible. Ordinary apps and unclassified processes remain visible. It does not infer ownership from command contents or AI output. Reparented children, shell scripts, shared services, inaccessible processes, and short-lived work can limit attribution. A group is the observed set of processes, not a promise that every resource used by an app is represented.

System and per-core CPU are sampled every two seconds while the popover is closed, without enumerating processes. Detailed process sampling runs once per second while it is open. A core block uses four bands: under 10%, 10–39%, 40–74%, and 75% or more of that core's capacity. Unlike the process list, each block measures one core against its own full capacity. The selected display style is saved. Sampling pauses during sleep and resets after wake. The first sample establishes a baseline. History uses only measured values on a fixed 0–100% scale. Row order stays stable while you select, expand, or search; readings keep updating. The app does not sample the GPU or report memory pressure.

Termination is limited to eligible processes owned by the current user. The app refuses protected system processes, itself, and stale process identities. Quit sends SIGTERM; Force Quit sends SIGKILL. A process can exit during an action, and macOS does not provide an atomic identity-checked signal API. Group actions can therefore partially complete; see [validation and limitations](docs/VALIDATION.md).

## Updates and privacy

Release builds use signed Sparkle updates, with the feed hosted on GitHub Releases. Automatic checks are off until enabled in Settings. Scheduled discovery adds a quiet reminder to the app; Check for Updates in the footer opens Sparkle's native installation interface. Automatic installation and web-based release notes are disabled. Development bundles without an HTTPS feed and Ed25519 public key disable the updater and explain why.

Process data stays on the Mac. Mac Stats does not transmit process names, paths, CPU samples, or usage analytics. Configured Sparkle checks contact the update feed and download host; those servers can receive standard network information such as the client's IP address. Sparkle system profiling is disabled.

## Project structure

- `Sources/ProcessCore`: native sampling, attribution, CPU calculations, and guarded termination.
- `Sources/MacStats`: AppKit menu bar, popover, settings, and Sparkle integration.
- `Sources/ProcessProbe`: command-line integration checks and measurements.
- `Tests/ProcessCoreTests`: focused behavior tests.
- `scripts`: local icon generation and app packaging. No recurring GitHub Actions are required.

Measured overhead and test evidence belong in [docs/VALIDATION.md](docs/VALIDATION.md). The design and intended scope are recorded in [docs/STRATEGY.md](docs/STRATEGY.md), with [Apple HIG review criteria](docs/NATIVE-DESIGN.md).

Mac Stats is [MIT licensed](LICENSE), copyright 2026 Parker Rex. Sparkle and its bundled components have their own notices; packaging includes the complete Sparkle license in the app's resources. See [Sparkle's license](https://github.com/sparkle-project/Sparkle/blob/2.10.0/LICENSE).
