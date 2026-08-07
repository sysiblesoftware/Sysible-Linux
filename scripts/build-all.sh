#!/bin/sh
# Build every Sysible package to a .deb and collect them in ../dist/.
# Run on a Debian box:  sudo apt install build-essential debhelper dh-python
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIST="$ROOT/dist"
mkdir -p "$DIST"
rm -f "$DIST"/*.deb

for pkg in "$ROOT"/packages/*/; do
    [ -f "${pkg}debian/control" ] || continue
    name=$(basename "$pkg")
    echo "== building $name =="
    ( cd "$pkg" && dpkg-buildpackage -us -uc -b )
    # dpkg drops artifacts in the parent dir (packages/); sweep them into dist/.
    mv "$ROOT"/packages/*.deb "$DIST"/ 2>/dev/null || true
    rm -f "$ROOT"/packages/*.buildinfo "$ROOT"/packages/*.changes 2>/dev/null || true
done

echo
echo "Built into $DIST:"
ls -1 "$DIST"/*.deb
