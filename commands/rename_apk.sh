#!/bin/bash

PUBSPEC="pubspec.yaml"
APK_DIR="build/app/outputs/flutter-apk"

VERSION_LINE=$(grep '^version:' "$PUBSPEC")
VERSION=$(echo "$VERSION_LINE" | sed 's/version: *//;s/+.*//')
BUILD=$(echo "$VERSION_LINE" | sed 's/.*+//')

FOUND=0
for FLAVOR in production development; do
  APK_NAME="app-${FLAVOR}-release.apk"
  SRC="$APK_DIR/$APK_NAME"
  if [ -f "$SRC" ]; then
    DEST="$APK_DIR/app-${FLAVOR}-release-version_${VERSION}-build_${BUILD}.apk"
    mv "$SRC" "$DEST"
    echo "Renamed to: $DEST"
    FOUND=1
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "Error: no APK found in $APK_DIR"
  exit 1
fi
