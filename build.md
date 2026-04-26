# Build and Packaging

## CMake

Build and install qpOASES with CMake:

```sh
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build .
cmake --build . --target install
```

The default CMake build creates both `libqpOASES.so` and `libqpOASES.a` on
Linux. Disable one with `QPOASES_BUILD_SHARED_LIBRARY=OFF` or
`QPOASES_BUILD_STATIC_LIBRARY=OFF` if needed.

Downstream projects can consume the installed package with:

```cmake
find_package(qpOASES CONFIG REQUIRED)
target_link_libraries(my_target PRIVATE qpOASES::qpOASES)
```

## Debian Packages

On Ubuntu, install the packaging tools and build local binary packages:

```sh
sudo apt-get update
sudo apt-get install -y build-essential cmake debhelper devscripts dpkg-dev
dpkg-buildpackage -us -uc -b
```

This produces `libqpoases3.2` and `libqpoases-dev` in the parent directory.
The development package installs headers, `libqpOASES.so`, `libqpOASES.a`, and
the CMake package config under the Debian multiarch library directory.

## GitHub Actions

`.github/workflows/cmake-and-debian.yml` verifies both supported paths:

```sh
find_package(qpOASES CONFIG REQUIRED)
dpkg-buildpackage -us -uc -b
```

The workflow also uploads the generated `.deb` files as a build artifact. It
runs on pull requests and manual dispatch only.

## Launchpad PPA

Create a PPA named `qpoases` under your Launchpad account:

```text
https://launchpad.net/~hashb
```

Use `ppa:hashb/qpoases` for a PPA named `qpoases`, or `ppa:hashb/ppa` for
Launchpad's default PPA name.

The upload must be signed by a GPG key registered on the `hashb` Launchpad
account. Keep the private key on your own machine and upload locally with
`dput`; do not put the private key in GitHub Actions secrets.

Create one signed source upload per Ubuntu series. Versions should use numeric
Ubuntu suffixes so upgrades sort correctly across releases, for example:

```text
3.2.2-1~ubuntu18.04.123.1
3.2.2-1~ubuntu20.04.123.1
3.2.2-1~ubuntu22.04.123.1
3.2.2-1~ubuntu24.04.123.1
3.2.2-1~ubuntu26.04.123.1
```

Suggested series list:

```text
resolute noble jammy focal bionic
```

Example local source upload for one series:

```sh
sudo apt-get update
sudo apt-get install -y build-essential cmake debhelper devscripts dpkg-dev dput gnupg

series=noble
series_version=ubuntu24.04
run_suffix=1
upstream_version="$(dpkg-parsechangelog -S Version | sed -E 's/-.*$//')"
upload_version="${upstream_version}-1~${series_version}.${run_suffix}"

git archive --format=tar \
  --prefix="qpoases-${upstream_version}/" \
  HEAD -- . ':(exclude)debian' \
  | gzip -n > "../qpoases_${upstream_version}.orig.tar.gz"

dch --force-distribution \
  --distribution "${series}" \
  --newversion "${upload_version}" \
  "Build for ${series} PPA."

dpkg-buildpackage -S -sa
dput ppa:hashb/qpoases "../qpoases_${upload_version}_source.changes"
```

After Launchpad finishes building:

```sh
sudo add-apt-repository ppa:hashb/qpoases
sudo apt-get update
sudo apt-get install libqpoases-dev
```
