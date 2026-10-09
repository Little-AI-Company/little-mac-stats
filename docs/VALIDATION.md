# Validation

## Observable outcomes

1. Launching the packaged app shows compact per-core blocks by default, or the saved percentage style, and no Dock icon. The panel accepts keyboard input and shows measured CPU after a sampling interval.
2. Codex and Claude are identifiable on the live host, and app helpers or descendant workloads are counted once. CPU percentages use all logical processors as 100 percent.
3. Expanding a group reveals its processes. A termination action requires confirmation and rechecks identity before sending a signal. A disposable fixture can be stopped; the user's active processes are never used as termination tests.
4. Settings and Escape/Command-comma/Command-Q behave as native macOS controls. Launch-at-login status and unavailable release-update configuration are reported truthfully.
5. Closed-panel sampling skips process enumeration. Resource use is measured in both closed and open states; no periodic animation drives rendering.
6. Tests and a release package build pass. The app's signature and embedded dependency are verified. The public repository matches the tested commit.

## Evidence from October 9, 2026

Environment: Apple silicon Mac with 10 logical processors, macOS 27.0.1, Xcode 27.0, Swift 6.4. Runtime compatibility was exercised on this machine only; the deployment target is macOS 14.

- `swift test`: all nine Swift Testing tests pass. Coverage includes whole-machine normalization, Apple Silicon Mach clock conversion, tick rollover, descendant attribution without double counting, unrelated-name false positives, protected processes, stale identities, a real disposable process receiving SIGTERM, cached ancestor precedence, and executable changes that retain a PID/start identity.
- `UNIVERSAL=1 scripts/package_app.sh`: passes. `lipo -archs` reports `x86_64 arm64`; Intel compilation is verified, but Intel execution is not. The redesigned universal app is approximately 4.6 MB. The app and nested Sparkle framework/helpers pass `codesign --verify --deep --strict`. Xcode also uploaded and exported notarized builds using the existing Apple account. Stapler validation passes, and Gatekeeper reports `accepted` with `source=Notarized Developer ID`.
- Release `ProcessProbe --verify-cpu`: a disposable single-threaded `/usr/bin/yes` process measured 9.729% and 9.939% of whole-machine capacity in separate runs, compared with a maximum of 10% on this machine. The original underreporting from Mach tick units was found by this check and corrected.
- Release `ProcessProbe --verify-termination`: stale start identities are rejected while the disposable process remains alive; the current identities receive SIGTERM (15) and SIGKILL (9) as requested.
- Live attribution identifies Codex from its app bundle identifier even when the outer app is named ChatGPT. Codex renderers, services, native CLI, and descendants appear together. Claude includes its app helpers and native versioned CLI. Roughly 725 processes were visible; roughly 334 had unavailable CPU details and were explicitly marked.
- Native interface inspection confirms CPU values are visible, group expansion shows individual process names and PIDs, Command-comma opens Settings, and unconfigured updates are disabled with explanatory text.
- A native Force Quit alert named the exact disposable test PID. Cancel was the default focused button; pressing Return cancelled and the process remained alive. Confirming Force Quit then removed that exact PID. No active user workload was terminated.
- The redesigned interface passed native inspection in light, dark, and high-contrast appearances. App icons identify the owning application rather than an arbitrary child. Search, Command-F, standard text editing, empty results, and keyboard selection worked. Selected-row values remained readable. The new Stop dialog kept Cancel as the Return default; confirming Quit terminated only the disposable process named in the dialog.

## Measured overhead

These are short measurements on a busy development Mac, not performance guarantees. Whole-machine percentages use all 10 logical processors as 100%. The command-line sampler and full application are measured separately.

| Measurement | Result |
| --- | --- |
| Release process sampler, 5 samples over 4.299 seconds | 0.3293% whole-machine CPU, 10.62 MiB resident memory |
| Detailed scan duration, approximately 725 processes | 24–33 ms after the initial sample |
| Release system-only sampler, 5 samples over 8.425 seconds | 0.0016% whole-machine CPU, 6.48 MiB resident memory |
| System-only scan duration after the initial sample | 0.039–0.068 ms |
| Full app, live panel in a native window, 20.010 seconds | 1.02 CPU seconds: 0.510% whole-machine CPU, or 5.098% of one core |
| Full app, window closed with Escape, 20.010 seconds | 0.01 CPU seconds: approximately 0.005% whole-machine CPU, near the measurement resolution |
| Full app resident memory after native accessibility inspection | 154.44 MiB; includes shared frameworks and inspection-related allocations |
| Full app resident memory after closing the inspected window | 112.55 MiB |

The table above records the initial implementation before the native interface pass. Full-app CPU measurements use the change in `ps` cumulative process CPU time, with 0.01-second resolution. Resident memory is not the same as private memory or physical footprint.

### Native interface and performance pass

In 0.1.1, the menu bar switched to system text that updates only when its rounded CPU value or sampling state changes. Version 0.2.0 adds the default core blocks, redrawn only when a shade level changes. History is recorded while closed without loading or repainting the panel. Native metadata remains fresh on every process scan; classification caches exist only within one snapshot. The panel updates visible rows only, caches search matches with identity/name/path invalidation, skips unchanged presentation writes, and retains small raster app icons.

| Check | Before | After |
| --- | --- | --- |
| Core sampler CPU time across eight samples | 0.399439 seconds | 0.117862 seconds, 70.5% less work |
| Core sampler whole-machine CPU | 0.5012% | 0.1556% |
| Core steady scan duration under heavy host load | 63–142 ms | 13–25 ms |
| Full app with Codex search, no UI automation during each 15-second measurement | 0.653% whole-machine CPU | 0.346% whole-machine CPU |
| Full app resident memory after native inspection | 309.95 MiB | 138.70 MiB |
| Full app physical footprint reported by `sample` | 147.0 MB | 51.1 MB |

After the production update, a fresh normal menu-bar launch with no UI automation used 0.03 CPU seconds over 20.043 seconds, approximately 0.015% of whole-machine CPU. Resident memory was 72.94 MiB in that closed-panel run. This includes post-launch work and is near the timer's measurement resolution; it is not a claim of zero resource use.

Core comparisons used approximately 840 visible processes under heavy system load. Core RSS increased from 11.67 to 13.00 MiB because of the small snapshot caches; the memory reduction in the full app comes from the interface changes. These short observations are workload-dependent and compare separate launches. Native accessibility inspection itself temporarily raises CPU and memory, so it was excluded from the timed full-app CPU intervals. Physical footprint peaks were 156.8 MB before and 56.1 MB after. The final subsequent source adjustment changed singular/plural display text only.

## Repeating the checks

```sh
swift test
swift build -c release --product ProcessProbe
probe_directory="$(swift build -c release --show-bin-path)"
"$probe_directory/ProcessProbe" --verify-cpu
"$probe_directory/ProcessProbe" --verify-termination
"$probe_directory/ProcessProbe" --samples 5 --interval 1 --limit 5
"$probe_directory/ProcessProbe" --system-only --samples 5 --interval 2
UNIVERSAL=1 scripts/package_app.sh
```

The probe's termination modes only create and terminate their own disposable fixtures. They do not accept arbitrary target PIDs.

The native automation tool cannot attach to an accessory-only app or its popover. For inspection, `dist/Mac Stats.app/Contents/MacOS/MacStats --show-window` displays the same live panel in a regular AppKit window. `--show-window --freeze-after-sample` takes two real samples and stops the timer so accessibility element identifiers remain stable. This mode clearly titles the window `Mac Stats Validation Snapshot`; it is used to inspect confirmation controls. Add `--dark-appearance` or `--high-contrast-appearance` with `--show-window` to inspect this app without changing system settings. Normal launches do not use these modes and remain menu-bar-only. Exit the validation instance before launching normally.

## Remaining limits

- Direct mouse interaction with the actual menu bar popover was not verified through automation because the native tool could not attach to that surface. The shared panel, keyboard Settings command, expansion, cancellation, and confirmed termination were inspected through the native window mode.
- Launch-at-login registration and a real logout/login cycle were not exercised. macOS reported no background-service record even for an installed app. The 0.1.1 patch therefore permits explicit registration instead of disabling the control or assuming the app is outside Applications. Registration errors remain visible, and the preference stays off until the user enables it.
- Sleep/wake reset is implemented and reviewed but was not tested by suspending the user's machine.
- Developer ID signing and notarization have been verified through Xcode. Scheduled update timing still requires longer-running observation. Development builds deliberately disable unconfigured updates.
- Process visibility is limited by macOS permissions and races with process exit. Unknown readings are not zero measurements. Host CPU and group sums can differ because of unreadable work and sampling windows.
- Detached or reparented workloads can lose attribution. Generic `node` or `python` command wrappers are attributed through known ancestry; arbitrary command arguments are not inspected or matched.
- Group termination targets the captured members. It can partially succeed if a member exits during the operation. PID, start identity, and real/effective user IDs are checked immediately before each signal, but POSIX `kill` does not provide an atomic identity-bound process handle.

## Per-core display verification

Version 0.2.0 adds real per-core kernel measurements, a default block display, a saved percentage alternative, leading style previews, and a separate Settings/updates/About/Quit footer.

- All 12 focused tests pass, including per-core normalization, counter wraparound, baseline/reset, core-count changes, and a live closed-panel read.
- The release probe returned ten per-core readings on this ten-core Mac, with no process enumeration in closed mode. The first reading was unavailable until a baseline existed. Four samples over 6.072 seconds consumed 0.001770 CPU seconds, approximately 0.0029% of whole-machine CPU. Steady sampling took 0.131–0.381 ms, and resident memory was 6.53 MiB.
- A separate 2,000-sample debug stress check showed no accumulating kernel buffer allocation: resident memory was 6.95 MiB compared with 6.64 MiB in a short normal run. The returned VM buffer and host send right are explicitly released.
- Native interaction verified selection of Percentage, persistence across quitting and relaunching, and restoration of CPU Cores. Both radios reflected the saved selection. The footer Quit command and native About panel worked; About reported 0.2.0/build 6. Settings and process search remained accessible.
- Live startup caught an early constraint activation error in the new selector; row-width constraints were moved until after the views share a parent. The corrected packaged app opened successfully, and the overview, details, and settings screenshots were captured from it.

## Signed update installation

A Developer ID signed and notarized build 1 was installed in Applications with a feed pointing to the public validation prerelease. Sparkle downloaded build 3 from GitHub, verified its EdDSA signature, replaced the app, and relaunched it. The installed `CFBundleVersion` became 3, strict code-signature validation passed, and its executable SHA-256 matched the notarized release artifact exactly. Sparkle's system log records signature acceptance and archive extraction at 12:54:25 Central on October 9, 2026.

The stable 0.1.1 build 4 adds only the launch-at-login registration control correction and canonical packaging version defaults. The production `releases/latest/download/appcast.xml` endpoint was fetched and compared byte-for-byte with the generated feed. Its version, download URL, archive length, and Ed25519 signature were independently verified using the embedded public key.

The installed build 3 then opened Sparkle's native Software Update window, identified 0.1.1 as newer than 0.1.0, downloaded the archive, and displayed Install and Relaunch. After confirmation, the installed app relaunched normally with no validation flags. Its version became 0.1.1/build 4, its executable SHA-256 matched the notarized release artifact, strict signature verification passed, its stapled ticket validated, and Gatekeeper accepted it as Notarized Developer ID. The GitHub release is public, not a draft, and not a prerelease. Update scheduling over a full day and an actual logout/login cycle remain outside these checks.
