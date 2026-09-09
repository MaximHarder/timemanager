#!/bin/bash
# Ermittelt die letzte *veröffentlichte* Version (Tags / package.json).
# Wichtig: releases/v*-Branches zählen nicht — sonst erzeugt der Dependabot-Router
# bei jedem PR eine neue Version (0.2.7 → 0.2.8 → …).
# Usage: ./get-latest-version.sh [--format=full|version-only]
# Returns: Versionsnummer (z. B. "0.2.6" oder "v0.2.6" bei format=full)

set -e

FORMAT="${1:-version-only}"
if [[ "$FORMAT" == "--format=full" ]]; then
    FORMAT="full"
else
    FORMAT="version-only"
fi

# Tags und Remotes aktualisieren
git fetch --tags --prune --prune-tags 2>/dev/null || true
git fetch origin --prune 2>/dev/null || true

# Veröffentlichte Versionen aus Tags (vX.Y.Z)
LATEST_TAG_VERSION=$(git tag -l "v[0-9]*\.[0-9]*\.[0-9]*" 2>/dev/null | \
    sed 's/^v//' | \
    sort -V | \
    tail -1)

# Fallback: Version aus package.json (aktueller Checkout)
PACKAGE_VERSION=""
if [ -f "package.json" ]; then
    PACKAGE_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || true)
fi

# Höchste aus Tag und package.json wählen
if [ -n "$LATEST_TAG_VERSION" ] && [ -n "$PACKAGE_VERSION" ]; then
    if [ "$(printf '%s\n' "$LATEST_TAG_VERSION" "$PACKAGE_VERSION" | sort -V | tail -1)" = "$LATEST_TAG_VERSION" ]; then
        LATEST_VERSION="$LATEST_TAG_VERSION"
    else
        LATEST_VERSION="$PACKAGE_VERSION"
    fi
elif [ -n "$LATEST_TAG_VERSION" ]; then
    LATEST_VERSION="$LATEST_TAG_VERSION"
elif [ -n "$PACKAGE_VERSION" ]; then
    LATEST_VERSION="$PACKAGE_VERSION"
else
    echo "Error: Keine Version aus Tags oder package.json gefunden" >&2
    exit 1
fi

# Whitespace normalisieren und Suffixe entfernen (z. B. "0.2.6-beta" -> "0.2.6")
LATEST_VERSION=$(echo "$LATEST_VERSION" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/-.*$//' | sed 's/\+.*$//' | sed 's/_.*$//')

if ! [[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Ungültiges Versionsformat: $LATEST_VERSION (erwartet X.Y.Z)" >&2
    exit 1
fi

if [ "$FORMAT" = "full" ]; then
    echo "v${LATEST_VERSION}"
else
    echo "$LATEST_VERSION"
fi
