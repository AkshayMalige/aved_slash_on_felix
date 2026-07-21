#!/bin/bash
# combine_amc_pdi.sh -- stitch the felix base hardware PDI + the AMC firmware
# ELF (running on the RPU / Cortex-R5-0) into a single deployable base PDI.
#
# Mirrors the AVED hw/.../build_all.sh "PDI combine" step (bootgen), retargeted
# to felix. The FPT (flash-partition-table) step from AVED is a persistent-OSPI
# concern and is intentionally SKIPPED here -- this produces the "_nofpt" base
# PDI, which is what you JTAG-load or DFX-load for bring-up. Add the FPT later
# (gen_fpt.py + fpt_pdi_gen.py) for a flash-resident golden/production image.
#
# Usage:  source /tools/Xilinx/2025.1/Vitis/settings64.sh
#         ./combine_amc_pdi.sh [<base_pdi>] [<amc_elf>]
set -Eeuo pipefail

HERE=$(realpath "$(dirname "$0")")
BUILD="${HERE}/build"

# Defaults: felix base PDI (prefer the staged artifact from stage_artifacts.sh,
# fall back to the raw impl output), and the felix AMC ELF.
_staged="${HERE}/../artifacts/felix_cips_wrapper.pdi"
_impl="${HERE}/../proj/felix_slash.runs/impl_1/felix_cips_wrapper.pdi"
BASE_PDI="${1:-$([ -f "$_staged" ] && echo "$_staged" || echo "$_impl")}"
AMC_ELF="${2:-$(realpath "${HERE}/../../linker/resources/submodules/AVED/fw/AMC/build/amc.elf")}"

OUT_PDI="${BUILD}/felix_slash_amc.pdi"

for f in "$BASE_PDI" "$AMC_ELF"; do
    [ -f "$f" ] || { echo "ERROR: missing input: $f" >&2; exit 1; }
done
command -v bootgen >/dev/null || { echo "ERROR: bootgen not on PATH -- source Vitis settings64.sh" >&2; exit 1; }

rm -rf "$BUILD"; mkdir -p "$BUILD"
cp -a "$BASE_PDI" "${BUILD}/felix_cips_wrapper.pdi"
cp -a "$AMC_ELF"  "${BUILD}/amc.elf"

echo "=== bootgen: combining base PDI + AMC (r5-0) ==="
( cd "$HERE" && bootgen -arch versal -image "${HERE}/felix_pdi_combine.bif" -w -o "$OUT_PDI" )

echo "COMBINE_AMC_PDI_DONE: $OUT_PDI"
ls -la "$OUT_PDI"
