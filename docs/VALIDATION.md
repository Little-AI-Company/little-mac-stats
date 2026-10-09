# Validation

## Observable outcomes

1. Launching the packaged app shows a monochrome menu bar meter and no Dock icon. The panel opens immediately, accepts keyboard input, and shows measured CPU after a sampling interval.
2. Codex and Claude are identifiable on the live host, and app helpers or descendant workloads are counted once. CPU percentages use all logical processors as 100 percent.
3. Expanding a group reveals its processes. A termination action requires confirmation and rechecks identity before sending a signal. A disposable fixture can be stopped; the user's active processes are never used as termination tests.
4. Settings and Escape/Command-comma/Command-Q behave as native macOS controls. Launch-at-login status and unavailable release-update configuration are reported truthfully.
5. Closed-panel sampling skips process enumeration. Resource use is measured in both closed and open states; no periodic animation drives rendering.
6. Tests and a release package build pass. The app's signature and embedded dependency are verified. The public repository matches the tested commit.

## Evidence from October 9, 2026

Environment: Apple silicon Mac with 10 logical processors, macOS 27.0.1, Xcode 27.0, Swift 6.4. Runtime compatibility was exercised on this machine only; the deployment target is macOS 14.

- `swift test`: all seven Swift Testing tests pass. Coverage includes whole-machine normalization, Apple Silicon Mach clock conversion, tick rollover, descendant attribution without double counting, unrelated-name false positives, protected processes, stale identities, and a real disposable process receiving SIGTERM.
- `UNIVERSAL=1 scripts/package_app.sh`: passes. `lipo -archs` reports `x86_64 arm64`; Intel compilation is verified, but Intel execution is not. The universal app is approximately 4.2 MB. The nested Sparkle framework and helpers pass `codesign --verify --deep --strict`. This is an ad hoc development signature, not notarization.
- Release `ProcessProbe --verify-cpu`: a disposable single-threaded `/usr/bin/yes` process measured 9.729% and 9.939% of whole-machine capacity in separate runs, compared with a maximum of 10% on this machine. The original underreporting from Mach tick units was found by this check and corrected.
- Release `ProcessProbe --verify-termination`: stale start identities are rejected while the disposable process remains alive; the current identities receive SIGTERM (15) and SIGKILL (9) as requested.
- Live attribution identifies Codex from its app bundle identifier even when the outer app is named ChatGPT. Codex renderers, services, native CLI, and descendants appear together. Claude includes its app helpers and native versioned CLI. Roughly 725 processes were visible; roughly 334 had unavailable CPU details and were explicitly marked.
- Native interface inspection confirms CPU values are visible, group expansion shows individual process names and PIDs, Command-comma opens Settings, and unconfigured updates are disabled with explanatory text.
- A native Force Quit alert named the exact disposable test PID. Cancel was the default focused button; pressing Return cancelled and the process remained alive. Confirming Force Quit then removed that exact PID. No active user workload was terminated.

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

The full-app CPU measurement uses the change in `ps` cumulative process CPU time, with 0.01-second resolution. Resident memory is not the same as private memory or physical footprint. The app redraws the meter only when its quantized fill changes and has no continuous animations.

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

The native automation tool cannot attach to an accessory-only app or its popover. For inspection, `dist/Mac Stats.app/Contents/MacOS/MacStats --show-window` displays the same live panel in a regular AppKit window. `--show-window --freeze-after-sample` takes two real samples and stops the timer so accessibility element identifiers remain stable. This mode clearly titles the window `Mac Stats Validation Snapshot`; it is used to inspect confirmation controls. Normal launches do not use these modes and remain menu-bar-only. Exit the validation instance before launching normally.

## Remaining limits

- Direct mouse interaction with the actual menu bar popover was not verified through automation because the native tool could not attach to that surface. The shared panel, keyboard Settings command, expansion, cancellation, and confirmed termination were inspected through the native window mode.
- Launch-at-login registration and a real logout/login cycle were not exercised. A development bundle outside Applications can report unavailable registration; Settings tells the user to move it to Applications and reopen it.
- Sleep/wake reset is implemented and reviewed but was not tested by suspending the user's machine.
- No Developer ID Application certificate or notarization profile was available. A trusted public binary, update feed, scheduled update discovery, and real signed update installation remain release prerequisites. Development builds deliberately disable unconfigured updates.
- Process visibility is limited by macOS permissions and races with process exit. Unknown readings are not zero measurements. Host CPU and group sums can differ because of unreadable work and sampling windows.
- Detached or reparented workloads can lose attribution. Generic `node` or `python` command wrappers are attributed through known ancestry; arbitrary command arguments are not inspected or matched.
- Group termination targets the captured members. It can partially succeed if a member exits during the operation. PID, start identity, and real/effective user IDs are checked immediately before each signal, but POSIX `kill` does not provide an atomic identity-bound process handle.
