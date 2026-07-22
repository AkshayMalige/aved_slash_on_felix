#!/bin/bash
# build_all.sh -- one-stop clean build of felix SLASH (hw -> fw -> sw), for a
# fresh clone. Run stages in order; each is idempotent-ish and prints markers.
#
#   source /tools/Xilinx/2025.1/Vitis/settings64.sh   # REQUIRED first
#   ./build_all.sh <stage>
#
# Stages (run in this order on a fresh clone):
#   hw    Vivado: HLS iprepo IP + DFX project + synth/impl -> base PDI, XSA,
#         abstract shell; then stage artifacts + generate slash_base.bd.  (~1 h)
#   fw    AMC firmware: BSP (from XSA) + amc.elf (felix profile) + combine ->
#         felix_slash_amc.pdi (base image with AMC on the R5).             (~10 min)
#   sw    drivers + host libs: slash.ko, ami.ko, libslash, libvrt, vrtd, smi. (~5 min)
#   all   hw then fw then sw.
#
# After 'all': program the card + run a kernel -> see FELIX_SLASH_PLAN.md Stage 4-5.
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
command -v vivado >/dev/null || { echo "ERROR: source Vitis 2025.1 settings64.sh first" >&2; exit 1; }

stage_hw() {
    echo "########## HW ##########"
    ( cd iprepo/hbm_bandwidth && make )                                   # HLS iprepo IP
    vivado -mode batch -source dfx_build/scripts/run_all.tcl
    vivado -mode batch -source dfx_build/scripts/run_impl.tcl
    ./scripts/stage_artifacts.sh                                          # dcp/pdi/xsa -> right places
    ( cd linker/resources/base/iprepo/hbm_bandwidth && make )            # linker self-test IP
    ( cd linker && vivado -mode batch -source gen_slash_base.tcl )        # -> slash_base.bd
    echo "HW_DONE"
}

stage_fw() {
    echo "########## FW ##########"
    local AMC="$ROOT/linker/resources/submodules/AVED/fw/AMC"
    local XSA="$ROOT/dfx_build/artifacts/felix_slash.xsa"
    [ -f "$XSA" ] || { echo "ERROR: $XSA missing -- run './build_all.sh hw' first" >&2; exit 1; }
    ( cd "$AMC/scripts" && ./build_bsp.sh -xsa "$XSA" -os freertos )      # RPU BSP
    ( cd "$AMC" && ./scripts/build.sh -amc -profile felix -os freertos )  # amc.elf
    ( cd dfx_build/amc_pdi && ./combine_amc_pdi.sh )                      # felix_slash_amc.pdi
    echo "FW_DONE"
}

stage_sw() {
    echo "########## SW ##########"
    # Build the .deb packages, exactly as upstream SLASH does. This is the
    # supported install path -- `cmake --install` installs only the binaries and
    # NOT vrtd's systemd units, udev rules, /etc/vrt/vrtd.conf or the vrtd user,
    # which leaves the socket-activated daemon unable to start. See
    # DEPLOY_RUNBOOK.md Part 3.
    ./scripts/package-deb.sh --noninteractive
    echo "SW_DONE -> deb/  (install: see DEPLOY_RUNBOOK.md Part 4)"
}

case "${1:-}" in
    hw)  stage_hw ;;
    fw)  stage_fw ;;
    sw)  stage_sw ;;
    all) stage_hw; stage_fw; stage_sw ;;
    *)   echo "usage: $0 {hw|fw|sw|all}"; exit 2 ;;
esac
echo "BUILD_ALL_DONE: ${1}"
