#!/bin/bash
set -e

#
## This script adjusts `--platform=` of the final Dockerfile stage according to provided CPU architecture.
#

ARCH=$1

if [[ -z "${ARCH}" ]]; then
  >&2 printf "\nERR: This scripts requires architecture passed.  Try:\n"
  >&2 printf "\t./%s  %s\n\n"   "$(basename "$0")"  "arm64"
  exit 1
fi

FILE=$2
if [[ -z "${FILE}" ]]; then
  FILE="Dockerfile"
fi


# Convert matrix-supplied architecture to a format understood by Docker's `--platform=`  
case "${ARCH}" in
arm32v6)  CPU="arm/v6" ;;
arm32v7)  CPU="arm/v7" ;;
arm64)    CPU="arm64"  ;;
esac


# If `${CPU}` is empty here, we're done, as final image base needn't be changed
if [[ -z "${CPU}" ]]; then
  exit 0
fi

# If `gsed` is available in the system, then use it instead as the available `sed` might not be too able (MacOS)…
SED="sed"
if command -v gsed >/dev/null; then
  SED=gsed
fi

##
## APPROACH #1 (new):  Use `--platform=` flag in the final `FROM` directive
##
# Decyphering `sed` expressions is always "fun"…  So to make it easier on the reader here's an explanation:
# tl;dr: Replace last FROM with one that specifies target CPU architecture.
#
# This command replaces the last `FROM` statement in `Dockerfile`, with one that specifies `--platform=`,
#   ex for arm32v7:
#
#   FROM                         alpine:3.10 AS final
#     ⬇                               ⬇           ⬇
#   FROM --platform=linux/arm/v7 alpine:3.10 AS final
#
# Note:
#   `-i` - apply changes in-place (actually change the file)
#   `s/` - substitute; followed by two `|`-separated sections:
#     1st section looks for a match.  Escaped \(\) define a _capture group_
#     2nd section defines replacement.  `\1` is the value of the _capture group_ from the 1st section
#
platform() {
  # Convert matrix-supplied architecture to a format understood by Docker's `--platform=`
  case "$1" in
  arm32v6)  CPU="arm/v6" ;;
  arm32v7)  CPU="arm/v7" ;;
  arm64)    CPU="arm64"  ;;
  esac

  ${SED} -i "s|^FROM \(.*final\)$|FROM --platform=linux/$CPU \1|" "${FILE}"
}


##
## APPROACH #2 (old):  Use platform prefix for the image name
##
# This one does very similar things to the example above, except it uses the "raw" $ARCH, and
# this is the permutation occuring:
#
#   FROM       alpine:3.10 AS final
#     ⬇             ⬇           ⬇
#   FROM armv7/alpine:3.10 AS final
prefix() {
  CPU="$1"
  if [[ "${CPU}" == "arm64" ]]; then
    CPU="arm64v8"
  fi

  ${SED} -i "s|^FROM \(.*final\)$|FROM $CPU/\1|" "${FILE}"
}

## NOTE: Currently commented out, as it doesn't seem o work yet…
#platform "${ARCH}"

# TODO: fix `--platorm=`
prefix "${ARCH}"

echo "Dockerfile modified: 'final' stage is now:"

grep '^FROM.*final$' "${FILE}"