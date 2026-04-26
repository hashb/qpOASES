#!/usr/bin/env bash

set -euo pipefail

IMAGE="${QPOASES_PUBLISH_IMAGE:-ubuntu:24.04}"

usage() {
    cat <<'EOF'
Usage: scripts/publish-ppa-docker.sh [publish-ppa options]

Run scripts/publish-ppa.sh inside an Ubuntu Docker container. This is intended
for macOS hosts that do not have Debian packaging tools installed.

The wrapper mounts the repository read-only and mounts ~/.gnupg read-only, then
copies the keyring into the ephemeral container before signing source uploads.

Examples:
  scripts/publish-ppa-docker.sh
  scripts/publish-ppa-docker.sh --series "noble,jammy,focal"
  QPOASES_PUBLISH_IMAGE=ubuntu:24.10 scripts/publish-ppa-docker.sh --help
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

command -v docker >/dev/null 2>&1 || die "Docker is required on macOS"
docker info >/dev/null 2>&1 || die "Docker is not running"

repo_root="$(git rev-parse --show-toplevel)"
gnupg_home="${GNUPGHOME:-${HOME}/.gnupg}"

[ -d "${gnupg_home}" ] || die "GnuPG home not found: ${gnupg_home}"

docker_args=(
    run
    --rm
    -e DEBEMAIL="${DEBEMAIL:-}"
    -e DEBFULLNAME="${DEBFULLNAME:-}"
    -e GIT_OPTIONAL_LOCKS=0
    -v "${repo_root}:/work:ro"
    -v "${gnupg_home}:/host-gnupg:ro"
    -w /work
)

if [ -t 0 ] && [ -t 1 ]; then
    docker_args+=(-it)
fi

docker "${docker_args[@]}" "${IMAGE}" bash -lc '
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    debhelper \
    devscripts \
    dpkg-dev \
    dput \
    git \
    gnupg \
    gzip \
    pinentry-curses \
    tar

git config --global --add safe.directory /work

export GNUPGHOME=/tmp/gnupg
cp -a /host-gnupg "${GNUPGHOME}"
chmod -R go-rwx "${GNUPGHOME}"

scripts/publish-ppa.sh "$@"
' bash "$@"
