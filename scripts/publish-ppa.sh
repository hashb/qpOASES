#!/usr/bin/env bash

set -euo pipefail

PPA="ppa:hashb/robotics"
SERIES="resolute noble jammy focal bionic"
VERSION_SUFFIX="$(date -u +%Y%m%d%H%M)"
SIGN_KEY=""

usage() {
    cat <<'EOF'
Usage: scripts/publish-ppa.sh [options]

Build and upload signed qpOASES source packages to Launchpad from a clean
committed checkout. Private keys stay on the local machine; signing is handled
by local gpg/debsign tooling.

Options:
  --ppa VALUE        Launchpad PPA target. Default: ppa:hashb/robotics
  --series VALUE     Space- or comma-separated Ubuntu series.
                    Default: resolute noble jammy focal bionic
  --suffix VALUE     Version suffix. Default: UTC timestamp YYYYMMDDHHMM
  --key VALUE        Optional GPG key id passed to dpkg-buildpackage -k.
  -h, --help         Show this help.

Examples:
  scripts/publish-ppa.sh
  scripts/publish-ppa.sh --series "noble,jammy,focal"
  scripts/publish-ppa.sh --key 0123456789ABCDEF
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ppa)
            [ "$#" -ge 2 ] || die "--ppa requires a value"
            PPA="$2"
            shift 2
            ;;
        --series)
            [ "$#" -ge 2 ] || die "--series requires a value"
            SERIES="$2"
            shift 2
            ;;
        --suffix)
            [ "$#" -ge 2 ] || die "--suffix requires a value"
            VERSION_SUFFIX="$2"
            shift 2
            ;;
        --key)
            [ "$#" -ge 2 ] || die "--key requires a value"
            SIGN_KEY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

for command in git tar dpkg-parsechangelog dch dpkg-buildpackage dput gzip; do
    command -v "${command}" >/dev/null 2>&1 || die "missing required command: ${command}"
done

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

if [ -n "$(git status --porcelain)" ]; then
    die "working tree is not clean; commit or stash changes before publishing"
fi

source_package="$(dpkg-parsechangelog -S Source)"
current_version="$(dpkg-parsechangelog -S Version)"
upstream_version="${current_version%%-*}"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

source_dir="${workdir}/${source_package}-${upstream_version}"
mkdir -p "${source_dir}"
git archive --format=tar HEAD | tar -x -C "${source_dir}"

git archive --format=tar \
    --prefix="${source_package}-${upstream_version}/" \
    HEAD -- . ':(exclude)debian' \
    | gzip -n > "${workdir}/${source_package}_${upstream_version}.orig.tar.gz"

cp "${source_dir}/debian/changelog" "${workdir}/changelog.orig"
series_list="$(printf '%s' "${SERIES}" | tr ',' ' ')"

echo "Publishing ${source_package} ${upstream_version} to ${PPA}"
echo "Series: ${series_list}"
echo "Version suffix: ${VERSION_SUFFIX}"

for series in ${series_list}; do
    case "${series}" in
        bionic) series_version="ubuntu18.04" ;;
        focal) series_version="ubuntu20.04" ;;
        jammy) series_version="ubuntu22.04" ;;
        noble) series_version="ubuntu24.04" ;;
        resolute) series_version="ubuntu26.04" ;;
        *)
            die "unknown series '${series}'; add its Ubuntu version mapping to this script"
            ;;
    esac

    upload_version="${upstream_version}-1~${series_version}.${VERSION_SUFFIX}"
    cp "${workdir}/changelog.orig" "${source_dir}/debian/changelog"

    (
        cd "${source_dir}"
        dch --force-distribution \
            --distribution "${series}" \
            --newversion "${upload_version}" \
            "Build for ${series} PPA."

        build_args=(-S -sa)
        if [ -n "${SIGN_KEY}" ]; then
            build_args+=("-k${SIGN_KEY}")
        fi

        dpkg-buildpackage "${build_args[@]}"
    )

    changes_file="${workdir}/${source_package}_${upload_version}_source.changes"
    dput "${PPA}" "${changes_file}"
done

echo "Upload requests submitted to ${PPA}."
