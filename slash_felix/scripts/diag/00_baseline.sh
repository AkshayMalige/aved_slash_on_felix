#!/usr/bin/env bash
# Phase-1 baseline capture: run ONCE per boot, after JTAG programming + host
# reboot, BEFORE any test that can crash. Everything goes into diag_logs/.
# Needs sudo for lspci -vvv / dmesg / ipmitool.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
OUT=diag_logs/$(date +%Y%m%d_%H%M%S)_baseline
mkdir -p "$OUT"
echo "capturing baseline into $OUT"

# --- artifact fingerprints: these must stay IDENTICAL across all iterations
md5sum dfx_build/amc_pdi/build/felix_slash_amc.pdi \
       examples/00_axilite/axilite_hw.vbin \
       examples/00_axilite/axilite_hw.vbin.prj/images/top_i_slash_slash_axilite_hw_inst_0_partial.pdi \
       2>/dev/null | tee "$OUT/artifact_md5.txt"

# --- PCI state of the card and its upstream root port
lspci -d 10ee: -nn | tee "$OUT/lspci_short.txt"
ROOT=$(basename "$(dirname "$(readlink -f /sys/bus/pci/devices/0000:01:00.0)")")
echo "root port: $ROOT" | tee -a "$OUT/lspci_short.txt"
sudo lspci -vvv -s 01:00.0 > "$OUT/lspci_pf0.txt" 2>&1
sudo lspci -vvv -s 01:00.1 > "$OUT/lspci_pf1.txt" 2>&1
sudo lspci -vvv -s 01:00.2 > "$OUT/lspci_pf2.txt" 2>&1
sudo lspci -vvv -s "${ROOT#0000:}" > "$OUT/lspci_rootport.txt" 2>&1
grep -E "LnkSta:|DevSta:|UESta:|CESta:|AERCap" "$OUT"/lspci_*.txt | tee "$OUT/pcie_status_summary.txt"

# --- IOMMU / AER ownership: tells us who handles faults (OS vs firmware)
sudo dmesg | grep -iE "iommu|AMD-Vi|aer|apei|hest|ghes" > "$OUT/dmesg_iommu_aer.txt"
cat /proc/cmdline > "$OUT/cmdline.txt"

# --- driver + AMC liveness
lsmod | grep -E "^(slash|ami) " > "$OUT/modules.txt"
sudo dmesg | grep -iE "slash|qdma| ami |AMC" | tail -60 > "$OUT/dmesg_slash_ami.txt"
v80-smi list > "$OUT/v80smi.txt" 2>&1
systemctl status vrtd.socket --no-pager > "$OUT/vrtd_socket.txt" 2>&1

# --- IPMI SEL as-is before the test (so post-crash diff is unambiguous)
sudo ipmitool sel elist > "$OUT/sel_before.txt" 2>&1 || echo "ipmitool failed" > "$OUT/sel_before.txt"

echo; echo "baseline complete: $OUT"
