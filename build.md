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

Create a PPA named `robotics` under your Launchpad account:

```text
https://launchpad.net/~hashb
```

This repository includes a local publishing script for your robotics PPA:

```text
ppa:hashb/robotics
```

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

Install the packaging tools, then run the script from a clean committed
checkout on Ubuntu or Debian:

```sh
sudo apt-get update
sudo apt-get install -y build-essential cmake debhelper devscripts dpkg-dev dput gnupg
scripts/publish-ppa.sh
```

On macOS, use Docker Desktop and run the Ubuntu wrapper instead:

```sh
scripts/publish-ppa-docker.sh
```

The Docker wrapper mounts the repository and your local `~/.gnupg`, copies the
keyring into an ephemeral Ubuntu container, installs Debian packaging tools
there, and calls `scripts/publish-ppa.sh`.

Useful overrides:

```sh
scripts/publish-ppa.sh --series "noble,jammy,focal"
scripts/publish-ppa.sh --suffix 2
scripts/publish-ppa.sh --key <gpg-key-id>
scripts/publish-ppa-docker.sh --series "noble,jammy,focal"
```

After Launchpad finishes building:

```sh
sudo add-apt-repository ppa:hashb/robotics
sudo apt-get update
sudo apt-get install libqpoases-dev
```
