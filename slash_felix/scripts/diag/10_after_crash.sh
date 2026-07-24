#!/usr/bin/env bash
# Run IMMEDIATELY after the host comes back from a crash-reboot,
# BEFORE reprogramming the card and BEFORE loading drivers if possible.
# The card still holds its post-crash state -- harvest host-side evidence here,
# then run 20_jtag_harvest.tcl for the card-side evidence.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
OUT=diag_logs/$(date +%Y%m%d_%H%M%S)_postcrash
mkdir -p "$OUT"
echo "collecting post-crash evidence into $OUT"

# --- 1. IPMI SEL: on Supermicro H13 a firmware-fatal (sync flood) leaves
#        entries here even when the OS logged nothing. THE key breadcrumb.
sudo ipmitool sel elist > "$OUT/sel_after.txt" 2>&1
tail -15 "$OUT/sel_after.txt"

# --- 2. Previous boot's journal tail (kernel + all units)
journalctl -b -1 --no-pager -o short-precise | tail -200 > "$OUT/prevboot_tail.txt"
journalctl -b -1 --no-pager -o short-precise -k | tail -100 > "$OUT/prevboot_kernel_tail.txt"
journalctl --list-boots --no-pager | tail -5 > "$OUT/boots.txt"

# --- 3. pstore: a kernel panic (as opposed to firmware reset) leaves files here
ls -la /sys/fs/pstore/ > "$OUT/pstore_ls.txt" 2>&1
sudo cp -r /sys/fs/pstore/. "$OUT/pstore/" 2>/dev/null || true

# --- 4. kdump crash dumps, if kdump is configured
ls -la /var/crash/ > "$OUT/var_crash_ls.txt" 2>&1

# --- 5. Card enumeration state after the crash (did the static survive?)
lspci -d 10ee: -nn > "$OUT/lspci_short.txt" 2>&1
sudo lspci -vvv -s 01:00.0 > "$OUT/lspci_pf0.txt" 2>&1
grep -E "LnkSta:|DevSta:|UESta:|CESta:" "$OUT"/lspci_pf0.txt || true

echo; echo "post-crash host evidence in $OUT"
echo "NOW run the JTAG harvest BEFORE reprogramming:"
echo "  xsdb scripts/diag/20_jtag_harvest.tcl | tee $OUT/jtag_harvest.txt"
