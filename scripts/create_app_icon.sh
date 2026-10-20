#!/bin/bash
set -euo pipefail

repository_directory="$(cd "$(dirname "$0")/.." && pwd)"
source_image="${1:-$repository_directory/assets/icon-macos.png}"
# Renditions of 32 pixels or fewer use simplified art that stays readable in Finder lists.
small_source_image="${2:-$repository_directory/assets/icon-macos-small.png}"
output_icon="${3:-$repository_directory/Resources/AppIcon.icns}"
for image in "$source_image" "$small_source_image"; do
    if [[ ! -f "$image" ]]; then
        printf 'Icon source does not exist: %s\n' "$image" >&2
        exit 1
    fi
done
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/little-mac-stats-icon.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT
iconset="$temporary_directory/AppIcon.iconset"
mkdir -p "$iconset" "$(dirname "$output_icon")"
render() {
    local pixels="$1" destination="$2" image="$source_image"
    if (( pixels <= 32 )); then
        image="$small_source_image"
    fi
    sips -z "$pixels" "$pixels" "$image" --out "$destination" >/dev/null
}
for size in 16 32 128 256 512; do
    render "$size" "$iconset/icon_${size}x${size}.png"
    render "$((size * 2))" "$iconset/icon_${size}x${size}@2x.png"
done
iconutil --convert icns --output "$output_icon" "$iconset"
printf 'Created %s\n' "$output_icon"
