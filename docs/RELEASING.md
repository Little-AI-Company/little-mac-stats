# Releasing Mac Stats

The initial version is 0.1.0, build 1. The bundle identifier is `com.parkerrex.mac-stats`. Source publication does not imply a trusted public binary release. Production signing, notarization, and a real signed update installation have not been validated in this initial development environment.

## Local development package

```sh
swift test
swift build -c release
scripts/package_app.sh
open "dist/Mac Stats.app"
```

Packaging uses the checked-in version defaults, lockfile, icon, and plist. It embeds the pinned Sparkle binary with `ditto` to preserve framework symlinks and permissions. It signs inner helpers before the framework and the app, then verifies all signatures. The result is `dist/Mac Stats.app` and `dist/Mac-Stats-0.1.0.zip`. Existing files with those names in the output directory are replaced. This is a repeatable build procedure; byte-for-byte reproducibility is not promised because toolchains and signing timestamps can differ.

Ad hoc signing is the default and does not enable hardened runtime. This allows the embedded framework to load locally without Library Validation rejecting its signature. To use an existing development certificate instead:

```sh
SIGNING_IDENTITY='Apple Development: Your Name (TEAMID)' scripts/package_app.sh
```

Apple Development signing is for development. It does not replace Developer ID signing and notarization for public downloads.

The packaging script accepts these environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `VERSION` | `0.1.0` | Numeric marketing version, three components |
| `BUILD_NUMBER` | `1` | Positive integer, increased for each distributed build |
| `UNIVERSAL` | `0` | `1` builds arm64 and x86_64; otherwise builds for the current machine |
| `OUTPUT_DIRECTORY` | `dist` in the repository | Output directory |
| `SIGNING_IDENTITY` | `-` | Ad hoc, Apple Development, or Developer ID identity |
| `UPDATE_FEED_URL` | Empty | HTTPS appcast URL |
| `UPDATE_PUBLIC_KEY` | Empty | Base64 32-byte Ed25519 public key |
| `DISTRIBUTION` | `0` | `1` requires production prerequisites and notarizes |
| `NOTARY_PROFILE` | Empty | Saved Keychain profile for `notarytool` |

The update feed and public key must be supplied together. They are embedded in the generated bundle, not written back into the source plist. With neither set, the app disables updates and reports that the development build is not configured. Automatic checks, automatic installation, system profiling, and HTML release notes are off by default. Users can enable scheduled checks in Settings.

## Production prerequisites

Before publishing a binary, obtain a Developer ID Application certificate and an Apple notarization account. Save notarization credentials with `xcrun notarytool store-credentials`; follow its prompts or Apple's current guidance. Credentials stay in the Keychain. Never commit certificates, private keys, API keys, app-specific passwords, or exported signing files.

Use Sparkle's `generate_keys` tool once to create the update-signing private key in the login Keychain and print the public key. The resolved package includes tools under `.build/artifacts/sparkle/Sparkle/bin/`. Back up the key securely outside the repository. Embed only its public key. Choose a permanent HTTPS URL for the appcast and a public HTTPS location for update archives before the first distributed build.

Increase `BUILD_NUMBER` for every update. Keep the bundle identifier and signing team stable. The settings below are examples with placeholders; they do not identify a configured release service:

```sh
swift test
VERSION=0.1.0 BUILD_NUMBER=1 UNIVERSAL=1 DISTRIBUTION=1 \
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='MacStatsNotary' \
UPDATE_FEED_URL='https://your-update-host.example/mac-stats/appcast.xml' \
UPDATE_PUBLIC_KEY='PUBLIC_KEY_FROM_GENERATE_KEYS' \
scripts/package_app.sh
```

The script enables hardened runtime, signs and verifies the app, submits a temporary archive with `notarytool --wait`, staples and validates the accepted ticket, and assesses the app with Gatekeeper. The final archive is created after stapling. A failed prerequisite, signature, notarization, or assessment stops packaging. Keep release binaries, build logs, toolchain versions, and debug symbols outside the source repository for diagnosis.

## Signed appcast and update test

Copy the notarized archive into a dedicated release archive directory, preserving earlier release archives. Run Sparkle's `generate_appcast` with that directory and its real public download URL prefix:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --download-url-prefix 'https://your-update-host.example/mac-stats/releases/' \
  /path/to/release-archives
```

Read `generate_appcast --help` for the pinned version's options. It signs each update archive with the private key in the Keychain and writes EdDSA signatures into the appcast. The app validates signed archives before extraction. This procedure signs the archive entries; it does not claim the appcast XML itself is cryptographically signed. Optional signed-feed support requires Sparkle's additional `SURequireSignedFeed` configuration and feed/release-note signing procedure.

Publish archives and any generated delta files before publishing the appcast that references them. Verify public URLs, file sizes, signatures, version numbers, and minimum macOS version. An HTTPS URL alone does not establish that the archive is signed correctly.

Before announcing a release, install a genuine older Developer ID signed, notarized build in `/Applications`. Update to the new signed, notarized build through Sparkle. Verify manual Check for Updates, automatic checks disabled, automatic checks enabled, the quiet inline reminder when the panel opens, cancellation, failed downloads, and successful replacement/relaunch. Scheduled discovery must not open an unsolicited alert, including near launch. Keep HTML release notes disabled to preserve the no-web-view design.

For the public download, test fresh installation and launch on supported macOS versions and both architectures. Record evidence in `docs/VALIDATION.md`. Only then attach the notarized archive to a public GitHub release. No release binary or appcast should be advertised as ready until this validation is complete.

## References

- [Sparkle setup, embedding, signing, and appcast generation](https://sparkle-project.org/documentation/)
- [Sparkle gentle reminders](https://sparkle-project.org/documentation/gentle-reminders/)
- [Sparkle programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/)
- [Apple notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
