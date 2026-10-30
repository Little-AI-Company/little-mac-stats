---
title: "Releasing Little Mac Stats"
summary: "Version and build numbers, packaging, Developer ID signing, notarization, the Sparkle appcast and the Homebrew cask."
read_when:
  - "You package the app, cut a release, or change signing, notarization, the update feed or the cask."
  - "You need the release text for a version."
---

# Releasing Little Mac Stats

The current version is 0.3.0, build 7, as recorded in `Resources/Info.plist`. Packaging reads its default version and build number from that file; `VERSION` and `BUILD_NUMBER` can override them. The bundle identifier is `com.thelittleworker.little-mac-stats`.

Releases through 0.2.0 shipped as Mac Stats with the bundle identifier `com.parkerrex.mac-stats`, the Sparkle key account of the same name, and the `mac-stats` Homebrew cask. The rename to Little Mac Stats is a clean break: those builds do not update to Little Mac Stats, and the release evidence below was recorded on them. Little Mac Stats 0.3.0 starts a new update chain. Its signing, notarization, appcast, and Homebrew checks are recorded in [validation](VALIDATION.md); an installed update from one Little Mac Stats build to the next has not been exercised yet.

For the Mac Stats builds, Developer ID signing, Xcode archive upload, notarized export, stapling, and Gatekeeper acceptance have been validated. Earlier installed updates from build 1 to 3 and build 3 to 4 passed, including download, installation, relaunch, executable-hash comparison, and signature/ticket checks. See [validation](VALIDATION.md) for the current release evidence and remaining limits.

## Local development package

```sh
swift test
swift build -c release
scripts/package_app.sh
open "dist/Little Mac Stats.app"
```

Packaging uses the checked-in version defaults, lockfile, icon, and plist. It embeds the pinned Sparkle binary with `ditto` to preserve framework symlinks and permissions. It signs inner helpers before the framework and the app, then verifies all signatures. With the current defaults, the result is `dist/Little Mac Stats.app` and `dist/Little-Mac-Stats-0.3.0.zip`. Existing files with those names in the output directory are replaced. This is a repeatable build procedure; byte-for-byte reproducibility is not promised because toolchains and signing timestamps can differ.

Ad hoc signing is the default and does not enable hardened runtime. This allows the embedded framework to load locally without Library Validation rejecting its signature. To use an existing development certificate instead:

```sh
SIGNING_IDENTITY='Apple Development: Your Name (TEAMID)' scripts/package_app.sh
```

Apple Development signing is for development. It does not replace Developer ID signing and notarization for public downloads.

The packaging script accepts these environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `VERSION` | `CFBundleShortVersionString` from `Resources/Info.plist`, currently `0.3.0` | Numeric marketing version, three components |
| `BUILD_NUMBER` | `CFBundleVersion` from `Resources/Info.plist`, currently `7` | Positive integer, increased for each distributed build |
| `UNIVERSAL` | `0` | `1` builds arm64 and x86_64; otherwise builds for the current machine |
| `OUTPUT_DIRECTORY` | `dist` in the repository | Output directory |
| `SIGNING_IDENTITY` | `-` | Ad hoc, Apple Development, or Developer ID identity |
| `UPDATE_FEED_URL` | Empty | HTTPS appcast URL |
| `UPDATE_PUBLIC_KEY` | Empty | Base64 32-byte Ed25519 public key |
| `DISTRIBUTION` | `0` | `1` requires production prerequisites and notarizes |
| `NOTARY_PROFILE` | Empty | Saved Keychain profile for `notarytool` |

The update feed and public key must be supplied together. They are embedded in the generated bundle, not written back into the source plist. With neither set, the app disables updates and reports that the development build is not configured. Automatic checks, automatic installation, system profiling, and HTML release notes are off by default. Users can enable scheduled checks in Settings.

## Production prerequisites

Before publishing a binary, obtain a Developer ID Application signing identity, including its private key, and access to Apple notarization. Use the existing Xcode account workflow below, or save separate CLI credentials with `xcrun notarytool store-credentials`. Credentials stay in the Keychain. Never commit certificates, private keys, API keys, app-specific passwords, or exported signing files.

Little Mac Stats uses Sparkle's Keychain account `com.thelittleworker.little-mac-stats` for its update-signing key. That key was generated on October 20, 2026, for the rename; the Mac Stats key under `com.parkerrex.mac-stats` signs only the old builds. Back up the new private key with `generate_keys --account com.thelittleworker.little-mac-stats -x` to a file kept outside the repository. The resolved package includes tools under `.build/artifacts/sparkle/Sparkle/bin/`. Read the existing public key with `generate_keys --account com.thelittleworker.little-mac-stats -p`; do not generate a replacement for an established release. The production feed is `https://github.com/ParkerRex/little-mac-stats/releases/latest/download/appcast.xml`. Update archives are GitHub Release assets. The Apple certificate and Sparkle key are separate identities: a second release Mac needs both existing private keys. Keep backups outside the repository; import the existing keys instead of rotating them accidentally.

Increase `BUILD_NUMBER` for every update. Keep the bundle identifier and signing team stable. The settings below are examples with placeholders; they do not identify a configured release service:

```sh
swift test
VERSION=0.1.1 BUILD_NUMBER=4 UNIVERSAL=1 DISTRIBUTION=1 \
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='LittleMacStatsNotary' \
UPDATE_FEED_URL='https://your-update-host.example/little-mac-stats/appcast.xml' \
UPDATE_PUBLIC_KEY='PUBLIC_KEY_FROM_GENERATE_KEYS' \
scripts/package_app.sh
```

The script enables hardened runtime, signs and verifies the app, submits a temporary archive with `notarytool --wait`, staples and validates the accepted ticket, and assesses the app with Gatekeeper. The final archive is created after stapling. A failed prerequisite, signature, notarization, or assessment stops packaging. Keep release binaries, build logs, toolchain versions, and debug symbols outside the source repository for diagnosis.

## Use the existing Xcode account for notarization

If Xcode is already signed in to the release team, its distribution workflow can use that account instead of a `notarytool` Keychain profile. First package the app with an available certificate using `SIGNING_IDENTITY`. Then wrap the actual packaged app:

```sh
scripts/create_xcode_archive.sh \
  'dist/signed-development/Little Mac Stats.app' \
  'dist/Little Mac Stats.xcarchive'
open 'dist/Little Mac Stats.xcarchive'
```

The script copies the app into `Products/Applications` with `ditto`, preserves its signatures and framework symlinks, and records its bundle version, identifier, and available signer/team metadata. It refuses to replace an existing archive. It does not build, sign, upload, notarize, publish, or collect debug symbols. Keep the original build's debug symbols separately.

Apple documents Xcode's archive distribution workflow, but does not publish a supported schema for manually constructed archive metadata. This script uses a small conventional archive layout. On October 9, 2026, Xcode 27.0 (27A266a) accepted the wrapper for local `developer-id` export and notarization upload using its signed-in account. Exported apps and nested Sparkle code passed strict signature verification with hardened runtime and secure timestamps; framework symlinks remained intact. Notarized exports passed stapler validation and Gatekeeper assessment. Other Xcode versions remain untested. If another version refuses to recognize the wrapper, use the `notarytool` packaging path above or create a native Xcode app archive.

In Xcode's Organizer, select the archive and use Direct Distribution, or the custom Developer ID method and Upload destination where offered. That action submits the app to Apple's notary service. After acceptance, export the notarized app. Upload and acceptance are separate from creating the local archive.

For command-line use, the installed `xcodebuild -help` lists `method=developer-id`, `destination=export` or `upload`, `teamID`, `signingStyle`, and `signingCertificate` export options. A local `destination=export` validates the archive/export path without submitting the app for notarization. The validated local export used manual signing with the certificate's exact SHA-1 identifier and its team ID. Create an ignored export-options plist using the values for your certificate:

```sh
mkdir -p build
plutil -create xml1 build/XcodeExportOptions.plist
plutil -insert method -string developer-id build/XcodeExportOptions.plist
plutil -insert destination -string export build/XcodeExportOptions.plist
plutil -insert signingStyle -string manual build/XcodeExportOptions.plist
plutil -insert signingCertificate -string "$RELEASE_SIGNING_CERTIFICATE" build/XcodeExportOptions.plist
plutil -insert teamID -string "$RELEASE_TEAM_ID" build/XcodeExportOptions.plist
xcodebuild -exportArchive \
  -archivePath 'dist/Little Mac Stats.xcarchive' \
  -exportPath 'dist/xcode-export' \
  -exportOptionsPlist build/XcodeExportOptions.plist
```

Set `RELEASE_SIGNING_CERTIFICATE` to the certificate SHA-1 identifier from `security find-identity -v -p codesigning` and `RELEASE_TEAM_ID` to its team ID before running those commands. Local export re-signs the copied app for distribution and adds a secure timestamp; it does not notarize the app. For notarization, copy the options plist, change `destination` to `upload`, and run the same `-exportArchive` command with that copy. Upload success is not notarization acceptance. After Apple accepts the submission, use:

```sh
xcodebuild -exportNotarizedApp \
  -archivePath 'dist/Little Mac Stats.xcarchive' \
  -exportPath 'dist/notarized'
```

Verify the exported app with `codesign --verify --deep --strict`, `xcrun stapler validate`, and `spctl --assess --type execute` before making its distribution archive. See [Apple's Xcode notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [distribution signing guidance](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/).

## Signed appcast and update test

Copy the notarized archive into a dedicated release archive directory, preserving earlier release archives. Run Sparkle's `generate_appcast` with that directory and its real public download URL prefix:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --account com.thelittleworker.little-mac-stats \
  --download-url-prefix 'https://github.com/ParkerRex/little-mac-stats/releases/download/v0.1.1/' \
  --maximum-deltas 0 \
  /path/to/release-archives
```

Read `generate_appcast --help` for the pinned version's options. It signs each update archive with the private key in the Keychain and writes EdDSA signatures into the appcast. The app validates signed archives before extraction. This procedure signs the archive entries; it does not claim the appcast XML itself is cryptographically signed. Optional signed-feed support requires Sparkle's additional `SURequireSignedFeed` configuration and feed/release-note signing procedure.

Publish archives and any generated delta files before publishing the appcast that references them. Verify public URLs, file sizes, signatures, version numbers, and minimum macOS version. An HTTPS URL alone does not establish that the archive is signed correctly.

Before announcing a release, install a genuine older Developer ID signed, notarized build in `/Applications`. Update to the new signed, notarized build through Sparkle. Verify manual Check for Updates, automatic checks disabled, automatic checks enabled, the quiet inline reminder when the panel opens, cancellation, failed downloads, and successful replacement/relaunch. Scheduled discovery must not open an unsolicited alert, including near launch. Keep HTML release notes disabled to preserve the no-web-view design.

The version and build change is an ordinary commit on `main`, such as `chore: set version 0.3.1, build 8`, landed with `scripts/push_main.sh` like any other ([Push to main](PUSH-MAIN.md)); tag that commit `vX.Y.Z` after it lands. A cloud session cannot create tags, so push the tag from a Mac. Write the GitHub release text from the `Customer-note:` trailers since the previous tag, skipping `none` entries:

```sh
git log --format='%(trailers:key=Customer-note,valueonly,unfold)' v0.3.0..main | sed '/^$/d;/^none/d'
```

Attach the notarized archive and generated appcast to a clearly marked GitHub prerelease while verifying the update path. This provides a real HTTPS download endpoint without announcing the build as stable. After successful installation/update checks, promote the release and mark it latest so the production feed URL resolves. Test available macOS versions and architectures and record the exact tested combinations in `docs/VALIDATION.md`; do not imply runtime coverage from cross-compilation alone. The first release was run on Apple silicon; Intel and earlier macOS runtime checks remain follow-up work.

## Homebrew distribution

The canonical cask is [`Casks/little-mac-stats.rb` in ParkerRex/homebrew-tap](https://github.com/ParkerRex/homebrew-tap/blob/main/Casks/little-mac-stats.rb). Users install it with `brew install --cask parkerrex/tap/little-mac-stats`. It downloads the same signed, notarized release archive as the direct GitHub download; no separate build or Homebrew account is needed.

After publishing each stable release:

1. Download the public versioned archive and compute its SHA-256 with `shasum -a 256`. Verify it against the release checksum and inspect the extracted app with `codesign --verify --deep --strict`, `xcrun stapler validate`, and `spctl --assess --type execute`.
2. Update `version` and `sha256` in the tap's cask. Preserve the versioned download URL, minimum macOS version, and `auto_updates true` while Sparkle updates are supported. Never use `sha256 :no_check` or disable quarantine.
3. Run `brew style --cask parkerrex/tap/little-mac-stats`, `brew audit --cask --online parkerrex/tap/little-mac-stats`, and `brew livecheck --cask parkerrex/tap/little-mac-stats`. Test installation or upgrade against the actual public archive and record the result in [validation](VALIDATION.md).
4. Review, commit, and push the tap change. Confirm the public cask has the intended version and checksum. `brew livecheck` reports available releases; it does not publish cask updates.

The app's own updater remains available. For a Homebrew-managed upgrade, use `brew update` followed by `brew upgrade --cask --greedy parkerrex/tap/little-mac-stats`. The `--greedy` option includes casks with built-in updaters. Homebrew's installed version record does not track updates made through Sparkle.

## References

- [Sparkle setup, embedding, signing, and appcast generation](https://sparkle-project.org/documentation/)
- [Sparkle gentle reminders](https://sparkle-project.org/documentation/gentle-reminders/)
- [Sparkle programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/)
- [Apple notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
