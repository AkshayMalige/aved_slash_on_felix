#!/usr/bin/env bash
# make_sd_image.sh -- wrap a complete Versal boot PDI into an SD-card .img you can
# flash with Balena Etcher (or dd).
#
# WHY not v++ --package: that is the Vitis acceleration flow (Linux + rootfs +
# xclbin). Our felix_slash_amc.pdi is already a full bare-metal boot image (PLM +
# base design + AMC on R5), and SLASH uses .vbin not .xclbin -- so there is nothing
# to "package". SD boot just needs the PDI on a FAT32 card as BOOT.BIN. This script
# builds that as a single .img.
#
# Method: MBR partition table + one bootable FAT32 partition, PDI copied in as
# BOOT.BIN. Uses `parted` on the image file and `mtools` (mformat/mcopy) to write
# the filesystem -- NO root, NO loop devices.
#
# Usage:
#   ./scripts/make_sd_image.sh [pdi] [out.img] [size_MB]
# Defaults:
#   pdi     = dfx_build/amc_pdi/build/felix_slash_amc.pdi
#   out.img = felix_sd.img
#   size_MB = 64
#
# Then flash out.img to the SD card with Balena Etcher, set boot switch SW1=1110
# (SD1), insert into the FLX-155, cold boot.

set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDI="${1:-$REPO/dfx_build/amc_pdi/build/felix_slash_amc.pdi}"
OUT="${2:-$REPO/felix_sd.img}"
SIZE_MB="${3:-64}"
PART_OFFSET="1M"     # first partition starts at 1 MiB (sector 2048) -- standard

# --- checks ---
[ -f "$PDI" ] || { echo "ERROR: PDI not found: $PDI" >&2; exit 1; }
for t in parted mformat mcopy dd; do
    command -v "$t" >/dev/null || { echo "ERROR: '$t' not found (install parted + mtools)" >&2; exit 1; }
done
PDI_MB=$(( ($(stat -c %s "$PDI") + 1048575) / 1048576 ))
if [ "$SIZE_MB" -lt $(( PDI_MB + 4 )) ]; then
    echo "ERROR: size_MB=$SIZE_MB too small for a ${PDI_MB} MB PDI (need >= $((PDI_MB+4)))" >&2
    exit 1
fi

echo "==> PDI     : $PDI ($(du -h "$PDI" | cut -f1))"
echo "==> Output  : $OUT (${SIZE_MB} MB)"

# --- 1. blank image ---
rm -f "$OUT"
dd if=/dev/zero of="$OUT" bs=1M count="$SIZE_MB" status=none

# --- 2. MBR partition table + one FAT32 partition (bootable) ---
parted -s "$OUT" mklabel msdos
parted -s "$OUT" mkpart primary fat32 "$PART_OFFSET" 100%
parted -s "$OUT" set 1 boot on
parted -s "$OUT" set 1 lba on
# parted's 'mkpart fat32' can leave the MBR type byte as 0x83 (Linux) because the
# filesystem doesn't exist yet -- force it to 0x0c (W95 FAT32 LBA) so the Versal
# boot ROM (and the host OS) treat it as FAT. Needs a real MBR type id.
sfdisk --part-type "$OUT" 1 0c >/dev/null

# --- 3. FAT32 filesystem inside that partition + copy the PDI as BOOT.BIN ---
#     mtools @@offset targets the partition without a loop device or root.
export MTOOLS_SKIP_CHECK=1
mformat -i "$OUT@@${PART_OFFSET}" -F -v BOOT ::
mcopy   -i "$OUT@@${PART_OFFSET}" "$PDI" ::/BOOT.BIN

# --- 4. verify ---
echo "==> Partition table (type must be 'c'/FAT32 LBA):"
sfdisk -l "$OUT" 2>/dev/null | grep -E "Device|img1|\.img1|type=|Id" | sed 's/^/    /'
echo "==> FAT contents (must show BOOT.BIN):"
mdir -i "$OUT@@${PART_OFFSET}" ::/ | sed 's/^/    /'

echo
echo "SD image ready: $OUT"
echo "Next:"
echo "  1. Flash it with Balena Etcher (or: sudo dd if=$OUT of=/dev/sdX bs=4M conv=fsync)"
echo "  2. Set boot switch SW1 = 1110 (SD1) on the FLX-155"
echo "  3. Insert the card, COLD power-cycle the card"
echo "  4. Verify:  lspci -d 10ee: -nn   &&   v80-smi list"
