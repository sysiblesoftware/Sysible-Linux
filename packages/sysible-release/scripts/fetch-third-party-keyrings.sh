#!/bin/sh
# Populate /usr/share/keyrings with the upstream vendor signing keys that the
# .sources files in this package reference. Run at ISO build time (live-build
# hook) or once on a fresh install — dpkg builds have no network, so the keys
# are fetched here rather than vendored. Each key is dearmored to the exact path
# named by Signed-By in its .sources file.
set -e
KR=/usr/share/keyrings
command -v update-ca-certificates >/dev/null 2>&1 && update-ca-certificates >/dev/null 2>&1 || true
mkdir -p "$KR"

fetch() {  # fetch <url> <dest.gpg>
    printf 'sysible-release: fetching %s\n' "$2"
    curl -fsSL "$1" | gpg --dearmor > "$KR/$2"
    chmod 0644 "$KR/$2"
}

fetch https://download.docker.com/linux/debian/gpg                      docker.gpg
fetch https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key           kubernetes.gpg
fetch https://baltocdn.com/helm/signing.asc                             helm.gpg
fetch https://apt.releases.hashicorp.com/gpg                            hashicorp.gpg
fetch https://get.opentofu.org/opentofu.gpg                             opentofu.gpg
fetch https://packages.microsoft.com/keys/microsoft.asc                 microsoft.gpg
fetch https://packages.cloud.google.com/apt/doc/apt-key.gpg             google-cloud.gpg

echo "sysible-release: vendor keyrings installed in $KR"
