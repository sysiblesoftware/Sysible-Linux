# Sysible packaging + repo scripts

## Build every package

```
sudo apt install build-essential debhelper dh-python
./build-all.sh          # -> ../dist/*.deb
```

## Publish to the apt repo (aptly)

```
sudo apt install aptly
cp aptly.conf.sample ~/.aptly.conf     # then edit the endpoint you use

export GNUPGHOME=/path/to/sysible-signing        # holds the private archive key
export SYSIBLE_GPG_KEY=maintainers@sysible.io

# local filesystem publish (served by nginx at repo.sysible.io/apt):
./publish-repo.sh sysible-dev

# or S3 + CloudFront (endpoint "sysible" from aptly.conf):
SYSIBLE_APTLY_ENDPOINT=s3:sysible: ./publish-repo.sh sysible-stable
```

- `sysible-dev` is republished in place on every push (CI target).
- `sysible-stable` cuts an immutable snapshot and switches the published suite to
  it, so a release is reproducible and rollback is `aptly publish switch` to an
  older snapshot.

The suites match `sysible-release`'s `sysible.sources` (`Suites: sysible-stable`).
The signing key is the Sysible archive key (fingerprint
CFA4 B4E9 5EF5 44E0 6CEE D401 FBF0 856C D302 1431); its public half ships in
`sysible-release`, so `apt update` on any Sysible box verifies the repo.

## CI sketch

On a tag: `build-all.sh` -> `publish-repo.sh sysible-stable`.
On main:  `build-all.sh` -> `publish-repo.sh sysible-dev`.
Then, on a KVM runner, `live-build/build.sh` -> boot the ISO in a VM via Sysible
Controller + provision-lab-vms -> `sysible verify` as the release gate.
