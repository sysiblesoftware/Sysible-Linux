#!/bin/sh
# Build the Sysible Linux ISO. Run on a Debian host, or in a debian:bookworm
# container, with network access:
#     sudo ./build.sh
#
# Resilient by design: the Sysible packages are built and included DIRECTLY, so
# no live apt repo is required yet, and each upstream vendor repo is added only if
# reachable — a TLS-inspecting proxy that blocks HTTPS just means those tools are
# deferred, the ISO still builds.
set -e
cd "$(dirname "$0")"
ROOT=$(cd .. && pwd)
if [ "$(id -u)" = 0 ]; then SUDO=; else SUDO="sudo"; fi
CODENAME="${SYSIBLE_CODENAME:-bookworm}"; export SYSIBLE_CODENAME="$CODENAME"

# --- host tooling + trust store -------------------------------------------
$SUDO apt-get update -qq || true
$SUDO apt-get install -y --no-install-recommends \
    live-build ca-certificates curl gnupg sudo openssl || true
$SUDO update-ca-certificates || true
# Trust any enterprise/proxy CAs dropped in config/extra-ca/ (see its README).
if ls config/extra-ca/*.crt >/dev/null 2>&1; then
    $SUDO cp config/extra-ca/*.crt /usr/local/share/ca-certificates/ || true
    $SUDO update-ca-certificates || true
fi

# --- build the Sysible packages and include them directly ------------------
if ! ls "$ROOT"/dist/*.deb >/dev/null 2>&1; then
    echo "== building Sysible packages =="
    "$ROOT/scripts/build-all.sh"
fi
mkdir -p config/packages.chroot
cp "$ROOT"/dist/*.deb config/packages.chroot/ 2>/dev/null || true
echo "Included $(ls config/packages.chroot/*.deb 2>/dev/null | wc -l) Sysible package(s) directly."

# --- upstream vendor repos: add only the ones we can actually reach ---------
mkdir -p config/archives
: > config/archives/vendors.list.chroot
try_repo() {  # try_repo "<deb line>" <key-url> <name>
    if curl -fsSL "$2" > "config/archives/${3}.key.chroot" 2>/dev/null \
       && [ -s "config/archives/${3}.key.chroot" ]; then
        echo "$1" >> config/archives/vendors.list.chroot; echo "  + $3"
    else
        rm -f "config/archives/${3}.key.chroot"; echo "  - $3 (unreachable — deferred)"
    fi
}
echo "== upstream vendor repos (best-effort) =="
try_repo "deb https://download.docker.com/linux/debian ${CODENAME} stable"   https://download.docker.com/linux/debian/gpg            docker
try_repo "deb https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /"                https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key kubernetes
try_repo "deb https://baltocdn.com/helm/stable/debian/ all main"             https://baltocdn.com/helm/signing.asc                  helm
try_repo "deb https://apt.releases.hashicorp.com ${CODENAME} main"           https://apt.releases.hashicorp.com/gpg                  hashicorp
try_repo "deb https://packages.opentofu.org/opentofu/tofu/any/ any main"     https://get.opentofu.org/opentofu.gpg                   opentofu
try_repo "deb https://packages.microsoft.com/repos/code stable main"         https://packages.microsoft.com/keys/microsoft.asc      microsoft
try_repo "deb https://packages.cloud.google.com/apt cloud-sdk main"          https://packages.cloud.google.com/apt/doc/apt-key.gpg  google-cloud

# --- the Sysible apt repo, only if it's actually published -----------------
if curl -fsI "https://repo.sysible.io/apt/dists/sysible-stable/Release" >/dev/null 2>&1; then
    echo "deb https://repo.sysible.io/apt sysible-stable main" > config/archives/sysible.list.chroot
    curl -fsSL "https://repo.sysible.io/apt/sysible-archive-keyring.asc" \
        > config/archives/sysible.key.chroot 2>/dev/null || true
    echo "  + sysible repo"
else
    rm -f config/archives/sysible.list.chroot config/archives/sysible.key.chroot
    echo "  - sysible repo (not published yet — using the included packages)"
fi

# --- assemble -------------------------------------------------------------
lb clean --purge || true
lb config
$SUDO lb build
