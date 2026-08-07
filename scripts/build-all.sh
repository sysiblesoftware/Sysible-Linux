#!/bin/sh
# Build every Sysible package to a .deb and collect them in ../dist/.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIST="$ROOT/dist"
mkdir -p "$DIST"
rm -f "$DIST"/*.deb

if [ "$(id -u)" = 0 ]; then SUDO=; else SUDO="sudo"; fi
if [ "${SYSIBLE_SKIP_DEPS:-0}" != "1" ]; then
    echo "== installing build dependencies =="
    $SUDO apt-get update -qq || true
    $SUDO apt-get install -y --no-install-recommends \
        build-essential debhelper dh-python python3-all python3-setuptools \
        pybuild-plugin-pyproject
fi

for pkg in "$ROOT"/packages/*/; do
    [ -f "${pkg}debian/control" ] || continue
    echo "== building $(basename "$pkg") =="
    ( cd "$pkg" && dpkg-buildpackage -us -uc -b )
    mv "$ROOT"/packages/*.deb "$DIST"/ 2>/dev/null || true
    rm -f "$ROOT"/packages/*.buildinfo "$ROOT"/packages/*.changes 2>/dev/null || true
done

echo
echo "Built into $DIST:"
ls -1 "$DIST"/*.deb
