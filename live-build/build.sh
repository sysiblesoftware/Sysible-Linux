#!/bin/sh
# Build the Sysible Linux ISO. Run on a Debian host, or in a debian:bookworm
# container, with network access:  sudo ./build.sh
#
# Everything is baked in — nothing to install after first boot:
#   * Debian-native tools come from the package list (below).
#   * The Sysible packages are built here and included directly.
#   * The non-Debian vendor tools (Docker, Kubernetes, Terraform, cloud CLIs,
#     VS Code, k9s/sops/eza) are installed by a chroot hook that controls apt
#     directly — reliable, unlike live-build's archive-key handling.
set -e
cd "$(dirname "$0")"
ROOT=$(cd .. && pwd)
if [ "$(id -u)" = 0 ]; then SUDO=; else SUDO="sudo"; fi
CODENAME="${SYSIBLE_CODENAME:-bookworm}"; export SYSIBLE_CODENAME="$CODENAME"
ARCH="${SYSIBLE_ARCH:-amd64}"; export SYSIBLE_ARCH="$ARCH"
echo "Building for architecture: $ARCH"

# --- host tooling + trust store -------------------------------------------
$SUDO apt-get update -qq || true
$SUDO apt-get install -y --no-install-recommends \
    live-build ca-certificates curl gnupg sudo openssl || true
$SUDO update-ca-certificates || true
if ls config/extra-ca/*.crt >/dev/null 2>&1; then
    $SUDO cp config/extra-ca/*.crt /usr/local/share/ca-certificates/ || true
    $SUDO update-ca-certificates || true
    # Also trust it INSIDE the chroot so the vendor hook's HTTPS verifies on an
    # inspected network (includes.chroot is copied in before hooks run).
    mkdir -p config/includes.chroot/usr/local/share/ca-certificates
    cp config/extra-ca/*.crt config/includes.chroot/usr/local/share/ca-certificates/ || true
fi

# --- build the Sysible packages and include them directly ------------------
if ! ls "$ROOT"/dist/*.deb >/dev/null 2>&1; then
    echo "== building Sysible packages =="
    "$ROOT/scripts/build-all.sh"
fi
mkdir -p config/packages.chroot
cp "$ROOT"/dist/*.deb config/packages.chroot/ 2>/dev/null || true
echo "Included $(ls config/packages.chroot/*.deb 2>/dev/null | wc -l) Sysible package(s) directly."

# --- build SysTerm from its own public repo and include the .deb -----------
# SysTerm ships full debian/ packaging; build it here (needs a real Debian
# toolchain, which CI provides) so the terminal is installed on the ISO.
if ! ls config/packages.chroot/systerm_*.deb >/dev/null 2>&1; then
    echo "== building SysTerm =="
    $SUDO apt-get install -y --no-install-recommends \
        git build-essential debhelper dh-python pybuild-plugin-pyproject \
        python3-all python3-setuptools || true
    rm -rf /tmp/systerm-src
    git clone --depth 1 https://github.com/sysiblesoftware/SysTerm /tmp/systerm-src
    ( cd /tmp/systerm-src && dpkg-buildpackage -us -uc -b )
    cp /tmp/systerm_*.deb config/packages.chroot/
    echo "Included SysTerm: $(ls config/packages.chroot/systerm_*.deb)"
fi

# --- expand the metapackage into the Debian-native toolkit -----------------
# Every package in sysible-workstation's Depends/Recommends/Suggests EXCEPT the
# sysible-* ones (included directly), systerm (its own repo), and the vendor /
# GitHub-binary tools (installed by the hook, since they aren't in Debian). One
# source of truth: the metapackage control.
awk '
    BEGIN {
        split("docker-ce docker-compose-plugin containerd.io kubectl helm k9s terraform opentofu packer azure-cli google-cloud-cli code sops eza", v, " ")
        for (i in v) VEND[v[i]] = 1
    }
    /^Description:/ { f=0 }
    /^(Depends|Recommends|Suggests):/ { f=1 }
    f {
        line=$0; sub(/^(Depends|Recommends|Suggests):/,"",line)
        if (line ~ /^[[:space:]]*#/) next
        n=split(line, a, ",")
        for (i=1;i<=n;i++) {
            gsub(/^[[:space:]]+|[[:space:]]+$/,"",a[i])
            split(a[i], b, /[[:space:]]/); name=b[1]
            if (name ~ /^[a-z0-9][a-z0-9.+-]+$/ && name !~ /^sysible-/ && name != "systerm" && !(name in VEND))
                print name
        }
    }
' "$ROOT/packages/sysible-meta/debian/control" | sort -u \
    > config/package-lists/sysible-toolkit.list.chroot
echo "Debian toolkit: $(grep -c . config/package-lists/sysible-toolkit.list.chroot) packages (vendor tools via hook)."

# --- assemble -------------------------------------------------------------
lb clean --purge || true
lb config

# --- brand the isolinux (BIOS) boot menu ----------------------------------
# live-build assembles isolinux during binary_iso — which runs AFTER binary
# hooks — so branding must be a source-level bootloader override (config/
# bootloaders/isolinux/), applied while the ISO is built. Base it on live-build's
# own templates so it stays format-compatible, then patch title/labels + splash.
ISO_TPL="/usr/share/live/build/bootloaders/isolinux"
if [ -d "$ISO_TPL" ] && [ -f config/branding/splash.png ]; then
    echo "== branding isolinux boot menu (source override) =="
    rm -rf config/bootloaders/isolinux
    mkdir -p config/bootloaders/isolinux
    cp -a "$ISO_TPL"/. config/bootloaders/isolinux/
    sed -i 's/^menu title .*/menu title Sysible Linux/' config/bootloaders/isolinux/menu.cfg 2>/dev/null || true
    for cfg in config/bootloaders/isolinux/*.cfg config/bootloaders/isolinux/*.cfg.in; do
        [ -f "$cfg" ] || continue
        sed -i -e 's/Live system (\(.*\) fail-safe mode)/Sysible Linux (Live, safe graphics) [\1]/g' \
               -e 's/Live system (\(.*\))/Sysible Linux (Live) [\1]/g' \
               -e 's/\^Live (@FLAVOUR@ failsafe)/Sysible Linux (Live, safe graphics)/g' \
               -e 's/\^Live (@FLAVOUR@)/Sysible Linux (Live)/g' \
               -e 's|Debian GNU/Linux|Sysible Linux|g' "$cfg"
    done
    # Sysible splash: wrap our PNG in an SVG so whichever way live-build renders
    # the splash, the result is Sysible art; also drop the PNG directly.
    b64=$(base64 -w0 config/branding/splash.png)
    printf '%s' "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"640\" height=\"480\"><image width=\"640\" height=\"480\" xlink:href=\"data:image/png;base64,${b64}\"/></svg>" \
        > config/bootloaders/isolinux/splash.svg
    cp config/bootloaders/isolinux/splash.svg config/bootloaders/isolinux/splash.svg.in 2>/dev/null || true
    cp config/branding/splash.png config/bootloaders/isolinux/splash.png
    echo "-- patched menu.cfg --";     sed -n '1,8p' config/bootloaders/isolinux/menu.cfg 2>/dev/null || true
    echo "-- patched live.cfg.in --";  sed -n '1,12p' config/bootloaders/isolinux/live.cfg.in 2>/dev/null || true
    echo "-- isolinux override files --"; ls -1 config/bootloaders/isolinux/
fi

$SUDO lb build
