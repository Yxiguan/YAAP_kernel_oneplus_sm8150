#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="/home/xiguan/workspace/kernel/yaap"
CLANG_DIR="/home/xiguan/workspace/Toolchain/clang-r547379"
OUT_DIR="${KERNEL_DIR}/out"
LOG_DIR="${KERNEL_DIR}/logs"
LOG_FILE="${LOG_DIR}/build-neptune-droidspaces-$(date +%Y%m%d-%H%M%S).log"
DEFCONFIG="neptune_defconfig"
FRAGMENT_DIR="${KERNEL_DIR}/arch/arm64/configs/droidspaces"
FRAGMENTS=(
  "${FRAGMENT_DIR}/droidspaces.config"
#   "${FRAGMENT_DIR}/droidspace-ufw.config"
)

export ARCH=arm64
export SUBARCH=arm64
export PATH="${CLANG_DIR}/bin:${PATH}"

: "${CROSS_COMPILE:=aarch64-linux-gnu-}"
: "${CROSS_COMPILE_COMPAT:=arm-linux-gnueabihf-}"
: "${USE_CCACHE:=1}"
: "${CCACHE_BIN:=ccache}"

TARGET_CC="clang"
CCACHE_STATUS="disabled"

if [[ "${USE_CCACHE}" != "0" ]]; then
  if ! command -v "${CCACHE_BIN}" >/dev/null 2>&1; then
    echo "Missing ccache: ${CCACHE_BIN}"
    exit 1
  fi

  TARGET_CC="${CCACHE_BIN} clang"
  CCACHE_STATUS="enabled (${CCACHE_BIN})"
fi

if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
  echo "Missing system toolchain: ${CROSS_COMPILE}gcc"
  exit 1
fi

if ! command -v "${CROSS_COMPILE_COMPAT}gcc" >/dev/null 2>&1; then
  echo "Missing system toolchain: ${CROSS_COMPILE_COMPAT}gcc"
  exit 1
fi

if ! command -v "${CROSS_COMPILE_COMPAT}ld.gold" >/dev/null 2>&1; then
  echo "Missing system linker: ${CROSS_COMPILE_COMPAT}ld.gold"
  exit 1
fi

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

MAKE_ARGS=(
  -C "${KERNEL_DIR}"
  O="${OUT_DIR}"
  CC="${TARGET_CC}"
  LD=ld.lld
  LD_COMPAT="${CROSS_COMPILE_COMPAT}ld.gold"
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  STRIP=llvm-strip
  LLVM_IAS=0
  CROSS_COMPILE="${CROSS_COMPILE}"
  CROSS_COMPILE_COMPAT="${CROSS_COMPILE_COMPAT}"
)


echo "Build log: ${LOG_FILE}"
echo "System CROSS_COMPILE: ${CROSS_COMPILE}"
echo "System CROSS_COMPILE_COMPAT: ${CROSS_COMPILE_COMPAT}"
echo "Compiler cache: ${CCACHE_STATUS}"

make -C "${KERNEL_DIR}" mrproper
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

make "${MAKE_ARGS[@]}" "${DEFCONFIG}"

"${KERNEL_DIR}/scripts/kconfig/merge_config.sh" \
  -O "${OUT_DIR}" \
  "${OUT_DIR}/.config" \
  "${FRAGMENTS[@]}"

make "${MAKE_ARGS[@]}" -j"$(nproc)"