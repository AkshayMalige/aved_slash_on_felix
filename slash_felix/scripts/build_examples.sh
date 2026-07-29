#!/bin/bash
# build_examples.sh -- build one or more felix example kernels end-to-end:
#   HLS synth (build_hls.sh)  ->  linker (main.py link -> .vbin)  ->  cmake host exe.
#
#   ./scripts/build_examples.sh                 # build ALL examples/*/ that have a config.cfg
#   ./scripts/build_examples.sh 02_ddr_bw       # build just one, by directory name
#   ./scripts/build_examples.sh 02_ddr_bw 03_qdma_bw   # build several
#
# Per example it auto-derives:
#   - kernel names  = the hls/*.cpp basenames
#   - hw vbin name  = the add_vbin(TARGET "..." PLATFORM "hw" ...) target in CMakeLists.txt
# so new examples need no edits here.
#
# Prereqs: Vitis 2025.1 on PATH (source settings64.sh) AND './build_all.sh hw' already
# done (the link places kernels against the staged abstract_shell). The host build links
# against the INSTALLED vrt/SlashTools packages (DEPLOY_RUNBOOK Part 4) -- not -DSLASH_USE_REPO.
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
command -v vivado >/dev/null || { echo "ERROR: source Vitis 2025.1 settings64.sh first" >&2; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 not found" >&2; exit 1; }
DEVICE="xcvp1552-vsva3340-2MHP-e-S"

build_example() {
    local dir="$1"
    local exdir="$ROOT/examples/$dir"
    [ -d "$exdir" ]            || { echo "ERROR: examples/$dir not found" >&2; exit 2; }
    [ -f "$exdir/config.cfg" ] || { echo "ERROR: examples/$dir/config.cfg missing" >&2; exit 2; }
    [ -f "$exdir/CMakeLists.txt" ] || { echo "ERROR: examples/$dir/CMakeLists.txt missing" >&2; exit 2; }

    # kernel names = hls/*.cpp basenames
    local kernels=()
    local f
    for f in "$exdir"/hls/*.cpp; do [ -e "$f" ] && kernels+=( "$(basename "$f" .cpp)" ); done
    [ ${#kernels[@]} -gt 0 ] || { echo "ERROR: no hls/*.cpp kernels in examples/$dir" >&2; exit 2; }

    # hw vbin target from CMakeLists add_vbin(... PLATFORM "hw" ...)
    local vbin=""
    vbin=$(grep -E 'add_vbin\(TARGET' "$exdir/CMakeLists.txt" | grep 'PLATFORM "hw"' \
           | sed -E 's/.*TARGET "([^"]+)".*/\1/' | head -1) || true
    [ -n "$vbin" ] || { echo "ERROR: no hw add_vbin target in examples/$dir/CMakeLists.txt" >&2; exit 2; }

    echo "########## EXAMPLE $dir  (kernels: ${kernels[*]}  ->  ${vbin}.vbin) ##########"

    # 1. HLS synth of each kernel
    ( cd "$ROOT/examples" && ./build_hls.sh "$dir" "${kernels[@]}" )

    # 2. link kernels -> .vbin. NOTE: -k takes MULTIPLE values (nargs="+"), so it
    #    must be a single -k followed by every component.xml. Repeating -k per kernel
    #    makes argparse keep only the LAST one -> "kernel type ... not found".
    local kargs=( -k )
    local k
    for k in "${kernels[@]}"; do
        kargs+=( "$exdir/hls/build_${k}.${DEVICE}/hls/impl/ip/component.xml" )
    done
    V80PP_RESOURCE_DIR="$ROOT/linker/resources" python3 "$ROOT/linker/src/main.py" link \
        -c "$exdir/config.cfg" -p hw -o "$exdir/${vbin}.vbin" \
        "${kargs[@]}" --vivado "$(command -v vivado)"

    # 3. host executable
    ( cd "$exdir" && rm -rf build && cmake -B build -S . -G Ninja && cmake --build build )

    echo "EXAMPLE_DONE: $dir  ->  examples/$dir/${vbin}.vbin  +  examples/$dir/build/"
}

targets=()
if [ "$#" -gt 0 ]; then
    targets=( "$@" )
else
    for d in "$ROOT"/examples/*/; do
        [ -f "$d/config.cfg" ] && targets+=( "$(basename "$d")" )
    done
fi
[ ${#targets[@]} -gt 0 ] || { echo "ERROR: no examples to build" >&2; exit 2; }

for d in "${targets[@]}"; do build_example "$d"; done
echo "BUILD_EXAMPLES_DONE: ${targets[*]}"
