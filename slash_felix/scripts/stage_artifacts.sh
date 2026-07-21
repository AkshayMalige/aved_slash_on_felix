#!/bin/bash
# stage_artifacts.sh -- copy the Vivado hardware build outputs to where the
# linker + AMC firmware flow expect them. Run ONCE after run_impl.tcl finishes.
#
# run_impl.tcl produces the abstract shell, base PDI, XSA and routed_bb.dcp in
# the impl_1 run directory, but does not place them. This script does that
# handoff so the rest of the flow (gen_slash_base, AMC BSP/combine, v80++ link)
# finds them without any manual copying.
#
# Usage:  ./scripts/stage_artifacts.sh
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMPL="${ROOT}/dfx_build/proj/felix_slash.runs/impl_1"
ABS="${ROOT}/linker/resources/abstract_shell"
ART="${ROOT}/dfx_build/artifacts"

[ -d "$IMPL" ] || { echo "ERROR: impl dir not found: $IMPL (run run_impl.tcl first)" >&2; exit 1; }
mkdir -p "$ABS" "$ART"

copy() {  # copy() <src-basename> <dest-dir> [required]
    local src="${IMPL}/$1" dst="$2/$1"
    if [ -f "$src" ]; then cp -f "$src" "$dst"; echo "  staged: $1 -> ${dst#$ROOT/}";
    elif [ "${3:-}" = required ]; then echo "ERROR: missing required artifact: $src" >&2; exit 1;
    else echo "  (skip, absent): $1"; fi
}

echo "=== staging hardware artifacts from impl_1 ==="
# linker inputs:
copy abs_shell_slash.dcp          "$ABS" required   # the slash-link place context
copy abs_shell_service_layer.dcp  "$ABS"            # networking path (optional on felix)
# AMC firmware + deploy inputs:
copy felix_slash.xsa              "$ART" required   # -> AMC BSP build
copy felix_cips_wrapper.pdi       "$ART" required   # -> AMC PDI combine (base image)
copy felix_cips_wrapper_routed_bb.dcp "$ART"        # deploy artifact

echo "=== checking slash_base.bd (produced by gen_slash_base.tcl) ==="
if [ -f "${ABS}/slash_base/slash_base.bd" ]; then
    echo "  present: linker/resources/abstract_shell/slash_base/slash_base.bd"
else
    echo "  NOT present -- run: ( cd linker && vivado -mode batch -source gen_slash_base.tcl )"
fi

echo "STAGE_ARTIFACTS_DONE"
