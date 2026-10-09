#!/bin/bash
set -euo pipefail

# The same checked-in sources and lockfile supply development and distribution builds.
repository_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repository_directory"
output_directory="${OUTPUT_DIRECTORY:-$repository_directory/dist}"
signing_identity="${SIGNING_IDENTITY:--}"
distribution="${DISTRIBUTION:-0}"
version="${VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
update_feed="${UPDATE_FEED_URL:-}"
update_public_key="${UPDATE_PUBLIC_KEY:-}"

if [[ "$distribution" != 0 && "$distribution" != 1 ]]; then
    printf 'DISTRIBUTION must be 0 or 1.\n' >&2
    exit 1
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    printf 'VERSION must contain three numeric components; BUILD_NUMBER must be a positive integer.\n' >&2
    exit 1
fi
if [[ -n "$update_feed" || -n "$update_public_key" ]]; then
    if [[ "$update_feed" != https://* || -z "$update_public_key" ]]; then
        printf 'Updates require an HTTPS UPDATE_FEED_URL and UPDATE_PUBLIC_KEY together.\n' >&2
        exit 1
    fi
    key_length="$(printf '%s' "$update_public_key" | /usr/bin/base64 -D | wc -c | tr -d ' ')"
    if [[ "$key_length" != 32 ]]; then
        printf 'UPDATE_PUBLIC_KEY must be a base64-encoded 32-byte Ed25519 public key.\n' >&2
        exit 1
    fi
fi
if [[ "$distribution" == 1 ]]; then
    if [[ "$signing_identity" != 'Developer ID Application:'* || -z "${NOTARY_PROFILE:-}" || -z "$update_feed" ]]; then
        printf 'Distribution requires a Developer ID Application signing identity, NOTARY_PROFILE, and update configuration.\n' >&2
        exit 1
    fi
fi

build_arguments=(-c release --product MacStats --force-resolved-versions)
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
    build_arguments+=(--arch arm64 --arch x86_64)
fi
swift build "${build_arguments[@]}"
binary_directory="$(swift build "${build_arguments[@]}" --show-bin-path)"
framework_source="$repository_directory/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$framework_source" ]]; then
    printf 'Sparkle framework not found at its resolved package artifact location.\n' >&2
    exit 1
fi
if [[ ! -f Resources/AppIcon.icns ]]; then
    scripts/create_app_icon.sh
fi

mkdir -p "$output_directory"
temporary_directory="$(mktemp -d "$output_directory/.package.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT
application="$temporary_directory/Mac Stats.app"
mkdir -p "$application/Contents/MacOS" "$application/Contents/Frameworks" "$application/Contents/Resources"
install -m 755 "$binary_directory/MacStats" "$application/Contents/MacOS/MacStats"
ditto "$framework_source" "$application/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$application/Contents/Info.plist"
cp Resources/AppIcon.icns "$application/Contents/Resources/AppIcon.icns"
cp LICENSE "$application/Contents/Resources/LICENSE.txt"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$application/Contents/Resources/Sparkle-LICENSE.txt"
plutil -replace CFBundleShortVersionString -string "$version" "$application/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$application/Contents/Info.plist"
if [[ -n "$update_feed" ]]; then
    plutil -insert SUFeedURL -string "$update_feed" "$application/Contents/Info.plist"
    plutil -insert SUPublicEDKey -string "$update_public_key" "$application/Contents/Info.plist"
fi
plutil -lint "$application/Contents/Info.plist"

signing_arguments=(--force --sign "$signing_identity")
if [[ "$distribution" == 1 ]]; then
    signing_arguments+=(--options runtime --timestamp)
elif [[ "$signing_identity" != - ]]; then
    signing_arguments+=(--options runtime --timestamp=none)
else
    # Ad hoc local builds omit hardened runtime so Library Validation permits Sparkle.
    signing_arguments+=(--timestamp=none)
fi
framework="$application/Contents/Frameworks/Sparkle.framework"
framework_version="$framework/Versions/Current"
# Sign from the inner helpers outwards. Do not use --deep to create signatures.
codesign "${signing_arguments[@]}" "$framework_version/Autoupdate"
codesign "${signing_arguments[@]}" "$framework_version/Updater.app"
codesign "${signing_arguments[@]}" "$framework_version/XPCServices/Downloader.xpc"
codesign "${signing_arguments[@]}" "$framework_version/XPCServices/Installer.xpc"
codesign "${signing_arguments[@]}" "$framework"
codesign "${signing_arguments[@]}" "$application"
codesign --verify --deep --strict --verbose=2 "$application"

if [[ "$distribution" == 1 ]]; then
    submission_archive="$temporary_directory/notarization.zip"
    ditto -c -k --keepParent "$application" "$submission_archive"
    xcrun notarytool submit "$submission_archive" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$application"
    xcrun stapler validate "$application"
    spctl --assess --type execute --verbose=2 "$application"
fi

destination="$output_directory/Mac Stats.app"
if [[ -e "$destination" ]]; then
    rm -rf "$destination"
fi
mv "$application" "$destination"
archive="$output_directory/Mac-Stats-$version.zip"
ditto -c -k --keepParent "$destination" "$archive"
printf 'Packaged %s\nArchive: %s\n' "$destination" "$archive"
if [[ "$distribution" == 0 ]]; then
    printf 'Development build only. This archive is not a notarized public release.\n'
fi
