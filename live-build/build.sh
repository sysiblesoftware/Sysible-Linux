#!/bin/sh
# Build the Sysible Linux ISO. Run on a Debian host with live-build installed:
#     sudo apt install live-build
#     ./build.sh
# Produces live-image-amd64.hybrid.iso in this directory.
set -e
cd "$(dirname "$0")"

# The build chroot needs the Sysible repo + the upstream vendor repos so apt can
# install sysible-workstation and everything it recommends. live-build reads repo
# lists + keys from config/archives/. We generate them here (keys are fetched now,
# since the build itself may run offline).
mkdir -p config/archives
CODENAME=bookworm
KEYS="https://download.docker.com/linux/debian/gpg docker
https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key kubernetes
https://baltocdn.com/helm/signing.asc helm
https://apt.releases.hashicorp.com/gpg hashicorp
https://get.opentofu.org/opentofu.gpg opentofu
https://packages.microsoft.com/keys/microsoft.asc microsoft
https://packages.cloud.google.com/apt/doc/apt-key.gpg google-cloud"

cat > config/archives/sysible.list.chroot <<LST
deb https://repo.sysible.io/apt sysible-stable main
LST
{
  echo "deb https://download.docker.com/linux/debian ${CODENAME} stable"
  echo "deb https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /"
  echo "deb https://baltocdn.com/helm/stable/debian/ all main"
  echo "deb https://apt.releases.hashicorp.com ${CODENAME} main"
  echo "deb https://packages.opentofu.org/opentofu/tofu/any/ any main"
  echo "deb https://packages.microsoft.com/repos/code stable main"
  echo "deb https://packages.cloud.google.com/apt cloud-sdk main"
} > config/archives/vendors.list.chroot

# Fetch each vendor key (armored) for the build chroot.
echo "$KEYS" | while read url name; do
  [ -n "$name" ] || continue
  echo "fetching key: $name"
  curl -fsSL "$url" > "config/archives/${name}.key.chroot"
done
# The Sysible archive key ships armored alongside sysible-release.
if [ -f ../packages/sysible-release/keyrings/sysible-archive-keyring.asc ]; then
  cp ../packages/sysible-release/keyrings/sysible-archive-keyring.asc config/archives/sysible.key.chroot
fi

lb clean --purge || true
lb config
sudo lb build
