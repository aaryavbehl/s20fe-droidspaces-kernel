#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

: "${KERNEL_SRC:?Set KERNEL_SRC to extracted patched kernel source}"
: "${CLANG_DIR:?Set CLANG_DIR to clang-r596125 directory}"

OUT="${OUT:-$REPO/build}"
JOBS="${JOBS:-6}"

export PATH="$CLANG_DIR/bin:$PATH"

clang --version

mkdir -p "$OUT"
cp "$REPO/configs/droidspaces.config" "$OUT/.config"

make -C "$KERNEL_SRC" O="$OUT" \
    ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig

make -C "$KERNEL_SRC" O="$OUT" \
    ARCH=arm64 LLVM=1 LLVM_IAS=1 \
    -j"$JOBS" Image

sha256sum "$OUT/arch/arm64/boot/Image"
