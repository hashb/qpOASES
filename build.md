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
The development package installs headers, `libqpOASES.so`, and the CMake
package config under the Debian multiarch library directory.

## GitHub Actions

`.github/workflows/cmake-and-debian.yml` verifies both supported paths:

```sh
find_package(qpOASES CONFIG REQUIRED)
dpkg-buildpackage -us -uc -b
```

The workflow also uploads the generated `.deb` files as a build artifact.

## Launchpad PPA

Create a PPA named `qpoases` under your Launchpad account:

```text
https://launchpad.net/~hashb
```

The publish workflow defaults to:

```text
ppa:hashb/qpoases
```

If you use Launchpad's default PPA name, run the workflow with `ppa_name` set
to `ppa` instead.

The upload must be signed by a GPG key registered on the `hashb` Launchpad
account. Export that private key locally and add it to GitHub Actions:

```text
LAUNCHPAD_GPG_PRIVATE_KEY=<ASCII-armored private key registered with Launchpad>
LAUNCHPAD_GPG_PASSPHRASE=<optional key passphrase>
DEBFULLNAME=<optional changelog signer name>
DEBEMAIL=<optional changelog signer email>
LAUNCHPAD_PPA=<optional override, for example ppa:hashb/qpoases>
```

With the GitHub CLI:

```sh
gpg --list-secret-keys --keyid-format LONG
gpg --armor --export-secret-keys <key-id> > /tmp/qpoases-launchpad-private.asc
gh secret set LAUNCHPAD_GPG_PRIVATE_KEY < /tmp/qpoases-launchpad-private.asc
gh secret set LAUNCHPAD_GPG_PASSPHRASE
gh secret set DEBFULLNAME --body "<your name>"
gh secret set DEBEMAIL --body "<email registered on Launchpad>"
```

Run the `Publish PPA source package` workflow manually with the defaults:

```text
launchpad_owner: hashb
ppa_name: qpoases
ubuntu_series: noble,jammy,focal,bionic,xenial
```

The workflow creates one signed source upload per Ubuntu series. Versions use
numeric Ubuntu suffixes so upgrades sort correctly across releases, for example:

```text
3.2.2-1~ubuntu16.04.123.1
3.2.2-1~ubuntu18.04.123.1
3.2.2-1~ubuntu20.04.123.1
3.2.2-1~ubuntu22.04.123.1
3.2.2-1~ubuntu24.04.123.1
```

To publish fewer releases, pass a shorter comma-separated list such as
`noble,jammy,focal`. To include Ubuntu 26.04 when your Launchpad PPA lists it,
add `resolute`.

After Launchpad finishes building:

```sh
sudo add-apt-repository ppa:hashb/qpoases
sudo apt-get update
sudo apt-get install libqpoases-dev
```
