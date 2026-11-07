#!/bin/sh
# Draws the app icon and writes it as an .icns:   app/make-icon.sh OUT.icns
# The icon is generated from icon.swift, so the repository holds no image files.
set -eu
[ $# -eq 1 ] || { echo "usage: make-icon.sh OUT.icns" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -O "$HERE/icon.swift" -o "$TMP/icon"
"$TMP/icon" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$1"
