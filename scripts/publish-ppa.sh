#!/usr/bin/env bash

set -euo pipefail

PPA="ppa:hashb/robotics"
SERIES="resolute noble jammy focal bionic"
VERSION_SUFFIX="$(date -u +%Y%m%d%H%M)"
SIGN_KEY=""
INCLUDE_ORIG="yes"

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
  --key VALUE        Optional GPG fingerprint/key id passed to dpkg-buildpackage -k.
  --no-orig          Do not include qpoases_<version>.orig.tar.gz in uploads.
                    Use only when the exact generated orig version already
                    exists in the PPA.
  -h, --help         Show this help.

Examples:
  scripts/publish-ppa.sh
  scripts/publish-ppa.sh --series "noble,jammy,focal"
  scripts/publish-ppa.sh --key 26D05B8BEC1F83BC3585363FBFFF31922FF3092A
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
        --no-orig)
            INCLUDE_ORIG="no"
            shift
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

if ! command -v gpg >/dev/null 2>&1; then
    die "missing required command: gpg"
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

if [ -n "$(git status --porcelain)" ]; then
    die "working tree is not clean; commit or stash changes before publishing"
fi

source_package="$(dpkg-parsechangelog -S Source)"
current_version="$(dpkg-parsechangelog -S Version)"
base_upstream_version="${current_version%%-*}"
if [ -z "${SIGN_KEY}" ]; then
    SIGN_KEY="$(gpg --batch --list-secret-keys --with-colons 2>/dev/null | awk -F: 'seen && /^fpr:/ { print $10; exit } /^sec:/ { seen = 1 }')"
fi

if [ -z "${SIGN_KEY}" ]; then
    die "no local GPG secret key is available; import/register your Launchpad signing key or pass --key"
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

series_list="$(printf '%s' "${SERIES}" | tr ',' ' ')"

echo "Publishing ${source_package} ${base_upstream_version} to ${PPA}"
echo "Series: ${series_list}"
echo "Version suffix: ${VERSION_SUFFIX}"
echo "Signing key: ${SIGN_KEY}"

for series in ${series_list}; do
    case "${series}" in
        bionic) series_version="u18.04" ;;
        focal) series_version="u20.04" ;;
        jammy) series_version="u22.04" ;;
        noble) series_version="u24.04" ;;
        resolute) series_version="u26.04" ;;
        *)
            die "unknown series '${series}'; add its Ubuntu version mapping to this script"
            ;;
    esac

    upload_upstream_version="${base_upstream_version}+ppa${VERSION_SUFFIX}${series_version}"
    upload_version="${upload_upstream_version}-1~${series_version}.${VERSION_SUFFIX}"
    source_dir="${workdir}/${source_package}-${upload_upstream_version}"
    rm -rf "${source_dir}"
    mkdir -p "${source_dir}"
    git archive --format=tar HEAD | tar -x -C "${source_dir}"

    git archive --format=tar \
        --prefix="${source_package}-${upload_upstream_version}/" \
        HEAD -- . ':(exclude)debian' \
        | gzip -n > "${workdir}/${source_package}_${upload_upstream_version}.orig.tar.gz"

    if [ "${INCLUDE_ORIG}" = "yes" ]; then
        source_option="-sa"
    else
        source_option="-sd"
    fi

    (
        cd "${source_dir}"
        dch --force-distribution \
            --distribution "${series}" \
            --newversion "${upload_version}" \
            "Build for ${series} PPA."

        dpkg-buildpackage -S "${source_option}" -k"${SIGN_KEY}"
    )

    changes_file="${workdir}/${source_package}_${upload_version}_source.changes"
    dput "${PPA}" "${changes_file}"
done

echo "Upload requests submitted to ${PPA}."
