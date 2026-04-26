# Build and Packaging

## CMake

Build and install qpOASES with CMake:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
cmake --install build --prefix /usr/local
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

Create a Launchpad PPA and add these GitHub repository secrets:

```text
LAUNCHPAD_PPA=ppa:<launchpad-user-or-team>/<ppa-name>
LAUNCHPAD_GPG_PRIVATE_KEY=<ASCII-armored private key registered with Launchpad>
LAUNCHPAD_GPG_PASSPHRASE=<optional key passphrase>
DEBFULLNAME=<optional changelog signer name>
DEBEMAIL=<optional changelog signer email>
```

Run the `Publish PPA source package` workflow manually. Choose an Ubuntu
series such as `noble` or `jammy`. The workflow creates an orig tarball,
updates `debian/changelog` to a unique version like
`3.2.2-1~noble123`, signs the source package, and uploads it with `dput`.

After Launchpad finishes building:

```sh
sudo add-apt-repository ppa:<launchpad-user-or-team>/<ppa-name>
sudo apt-get update
sudo apt-get install libqpoases-dev
```
