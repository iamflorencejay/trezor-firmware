#!/usr/bin/env bash
set -e -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ -z "$ALPINE_ARCH" ]; then
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64)
      ALPINE_ARCH="aarch64"
      ;;
    x86_64)
      ALPINE_ARCH="x86_64"
      ;;
    *)
      echo "Unsupported arch"
      exit
  esac
fi

if [ -z "$ALPINE_CHECKSUM" ]; then
  case "$ALPINE_ARCH" in
    aarch64)
      ALPINE_CHECKSUM="a5de8f89f3851d929704feafda9ff0d7402ae138176bba8b3f6a25ecbb0b8f46"
      ;;
    x86_64)
      ALPINE_CHECKSUM="4591f811a5515b13d60ab76f78bb8fd1cb9d9857a98cf7e2e5b200e89701e62c"
      ;;
    *)
      exit
  esac
 fi


CONTAINER_NAME=${CONTAINER_NAME:-trezor-firmware-env.nix}
ALPINE_CDN=${ALPINE_CDN:-https://dl-cdn.alpinelinux.org/alpine}
ALPINE_RELEASE=${ALPINE_RELEASE:-3.14}
ALPINE_VERSION=${ALPINE_VERSION:-3.14.2}
ALPINE_TARBALL=${ALPINE_FILE:-alpine-minirootfs-$ALPINE_VERSION-$ALPINE_ARCH.tar.gz}
NIX_VERSION=${NIX_VERSION:-2.3.15}
CONTAINER_FS_URL=${CONTAINER_FS_URL:-"$ALPINE_CDN/v$ALPINE_RELEASE/releases/$ALPINE_ARCH/$ALPINE_TARBALL"}

VARIANTS_core=(0 1)
VARIANTS_legacy=(0 1)

if [ "$1" == "--skip-core" ]; then
  VARIANTS_core=()
  shift
fi

if [ "$1" == "--skip-legacy" ]; then
  VARIANTS_legacy=()
  shift
fi

if [ "$1" == "--skip-bitcoinonly" ]; then
  VARIANTS_core=(0)
  VARIANTS_legacy=(0)
  shift
fi

TAG=${1:-master}
REPOSITORY=${2:-/local}
PRODUCTION=${PRODUCTION:-1}
MEMORY_PROTECT=${MEMORY_PROTECT:-1}


if which wget > /dev/null ; then
  wget --no-config -nc -P ci/ "$CONTAINER_FS_URL"
else
  if ! [ -f "ci/$ALPINE_TARBALL" ]; then
    curl -L -o "ci/$ALPINE_TARBALL" "$CONTAINER_FS_URL"
  fi
fi

# check alpine checksum
if command -v sha256sum &> /dev/null ; then
    echo "${ALPINE_CHECKSUM}  ci/${ALPINE_TARBALL}" | sha256sum -c
else
    echo "${ALPINE_CHECKSUM}  ci/${ALPINE_TARBALL}" | shasum -a 256 -c
fi

docker build --build-arg ALPINE_VERSION="$ALPINE_VERSION" --build-arg ALPINE_ARCH="$ALPINE_ARCH" --build-arg NIX_VERSION="$NIX_VERSION" -t "$CONTAINER_NAME" ci/

# stat under macOS has slightly different cli interface
USER=$(stat -c "%u" . 2>/dev/null || stat -f "%u" .)
GROUP=$(stat -c "%g" . 2>/dev/null || stat -f "%g" .)

mkdir -p build/core build/legacy
mkdir -p build/core-bitcoinonly build/legacy-bitcoinonly

DIR=$(pwd)

# build core

for BITCOIN_ONLY in ${VARIANTS_core[@]}; do

  DIRSUFFIX=${BITCOIN_ONLY/1/-bitcoinonly}
  DIRSUFFIX=${DIRSUFFIX/0/}

  SCRIPT_NAME=".build_core_$BITCOIN_ONLY.sh"
  cat <<EOF > "build/$SCRIPT_NAME"
    # DO NOT MODIFY!
    # this file was generated by ${BASH_SOURCE[0]}
    # variant: core build BITCOIN_ONLY=$BITCOIN_ONLY
    set -e -o pipefail
    cd /tmp
    git clone "$REPOSITORY" trezor-firmware
    cd trezor-firmware/core
    ln -s /build build
    git checkout "$TAG"
    git submodule update --init --recursive
    poetry install
    poetry run make clean vendor build_firmware
    poetry run ../python/tools/firmware-fingerprint.py \
               -o build/firmware/firmware.bin.fingerprint \
               build/firmware/firmware.bin
    chown -R $USER:$GROUP /build
EOF

  docker run -it --rm \
    -v "$DIR:/local" \
    -v "$DIR/build/core$DIRSUFFIX":/build:z \
    --env BITCOIN_ONLY="$BITCOIN_ONLY" \
    --env PRODUCTION="$PRODUCTION" \
    --init \
    "$CONTAINER_NAME" \
    /nix/var/nix/profiles/default/bin/nix-shell --run "bash /local/build/$SCRIPT_NAME"
done

# build legacy

for BITCOIN_ONLY in ${VARIANTS_legacy[@]}; do

  DIRSUFFIX=${BITCOIN_ONLY/1/-bitcoinonly}
  DIRSUFFIX=${DIRSUFFIX/0/}

  SCRIPT_NAME=".build_legacy_$BITCOIN_ONLY.sh"
  cat <<EOF > "build/$SCRIPT_NAME"
    # DO NOT MODIFY!
    # this file was generated by ${BASH_SOURCE[0]}
    # variant: legacy build BITCOIN_ONLY=$BITCOIN_ONLY
    set -e -o pipefail
    cd /tmp
    git clone "$REPOSITORY" trezor-firmware
    cd trezor-firmware/legacy
    ln -s /build build
    git checkout "$TAG"
    git submodule update --init --recursive
    poetry install
    poetry run script/cibuild
    mkdir -p build/bootloader build/firmware build/intermediate_fw
    cp bootloader/bootloader.bin build/bootloader/bootloader.bin
    cp intermediate_fw/trezor.bin build/intermediate_fw/inter.bin
    cp firmware/trezor.bin build/firmware/firmware.bin
    cp firmware/trezor.elf build/firmware/firmware.elf
    poetry run ../python/tools/firmware-fingerprint.py \
               -o build/firmware/firmware.bin.fingerprint \
               build/firmware/firmware.bin
    chown -R $USER:$GROUP /build
EOF

  docker run -it --rm \
    -v "$DIR:/local" \
    -v "$DIR/build/legacy$DIRSUFFIX":/build:z \
    --env BITCOIN_ONLY="$BITCOIN_ONLY" \
    --env MEMORY_PROTECT="$MEMORY_PROTECT" \
    --init \
    "$CONTAINER_NAME" \
    /nix/var/nix/profiles/default/bin/nix-shell --run "bash /local/build/$SCRIPT_NAME"

done

# all built, show fingerprints

echo "Fingerprints:"
for VARIANT in core legacy; do

  VARIANTS="VARIANTS_$VARIANT[@]"

  for BITCOIN_ONLY in ${!VARIANTS}; do

    DIRSUFFIX=${BITCOIN_ONLY/1/-bitcoinonly}
    DIRSUFFIX=${DIRSUFFIX/0/}

    FWPATH=build/${VARIANT}${DIRSUFFIX}/firmware/firmware.bin
    FINGERPRINT=$(tr -d '\n' < $FWPATH.fingerprint)
    echo "$FINGERPRINT $FWPATH"
  done
done
