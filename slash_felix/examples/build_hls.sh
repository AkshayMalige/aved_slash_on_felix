#!/bin/bash
# Build the felix HLS kernels for a given example dir: v++ -c --mode hls + vitis-run --package
# usage: build_hls.sh <example_dir> <kernel1> [kernel2...]
set -e
source /tools/Xilinx/2025.1/Vitis/settings64.sh 2>/dev/null
ex="$1"; shift
hls="$ex/hls"
for k in "$@"; do
  bd="$hls/build_${k}.xcvp1552-vsva3340-2MHP-e-S"
  echo "=== HLS $k -> $bd ==="
  mkdir -p "$bd"
  cp -f "$hls/${k}.cpp" "$bd/${k}.cpp"
  cp -f "$hls/${k}.cfg" "$bd/${k}.cfg"
  ( cd "$bd" && \
    v++ -c --mode hls --config "${k}.cfg" --work_dir . && \
    vitis-run --mode hls --package --config "${k}.cfg" --work_dir . )
  echo "=== component.xml: $(ls $bd/hls/impl/ip/component.xml 2>/dev/null || echo MISSING) ==="
done
echo "BUILD_HLS_DONE"
