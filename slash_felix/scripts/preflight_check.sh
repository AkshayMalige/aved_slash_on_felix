#!/usr/bin/env bash
# Pre-flight checks: verify the build is sane BEFORE spending a hardware session.
#
# Every check here corresponds to a failure that actually happened during felix
# bring-up. Run it after `./build_all.sh fw` and before touching JTAG.
#
#   ./scripts/preflight_check.sh
#
# Exit 0 = safe to program. Exit 1 = do not bother, fix the build first.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PASS=0; FAIL=0; SKIP=0; WARN=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$1"; SKIP=$((SKIP+1)); }
# Non-blocking: true but expected at this point in the flow.
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; WARN=$((WARN+1)); }

BD=dfx_build/scripts/export_felix_cips_top.tcl
AMC_ELF=linker/resources/submodules/AVED/fw/AMC/build/amc.elf
BASE_PDI=dfx_build/artifacts/felix_cips_wrapper.pdi
AMC_PDI=dfx_build/amc_pdi/build/felix_slash_amc.pdi

echo
echo "=== 1. PS-side DDR route (the PLM-stall root cause) ======================"
# felix's single-channel DDR consolidation once left the PMC and RPU NoC masters
# pointing at the disconnected M00_INI, so neither could reach DDR. The PLM then
# hung loading amc.elf into DDR: "PLM stalled during programming" / DONE bit LOW.
if [ ! -f "$BD" ]; then
    bad "$BD missing - run 'vivado -mode batch -source dfx_build/scripts/run_all.tcl'"
else
    for space in PMC_NOC_AXI_0 LPD_AXI_NOC_0; do
        if grep -q "get_bd_addr_spaces static_region/aved/cips/${space}\] \[get_bd_addr_segs.*C0_DDR_LOW0" "$BD"; then
            ok "$space can reach C0_DDR_LOW0"
        else
            bad "$space has NO DDR mapping -> the AMC will stall the PLM. See 05_fix_static.tcl step 2c."
        fi
    done
    # The consolidation must leave the PS masters on the LIVE door (M01_INI).
    if grep -q "M00_INI" dfx_build/scripts/05_fix_static.tcl && \
       ! grep -q "S02_AXI" dfx_build/scripts/05_fix_static.tcl; then
        bad "05_fix_static.tcl does not re-point S02_AXI/S03_AXI off the dead M00_INI"
    else
        ok "05_fix_static.tcl re-points the PMC/RPU DDR routes"
    fi
fi

echo
echo "=== 2. AMC firmware load addresses ======================================="
# amc.elf must fit inside the DDR low region mapped above (0x0 .. 0x8000_0000).
if [ ! -f "$AMC_ELF" ]; then
    skip "$AMC_ELF not built yet (./build_all.sh fw)"
elif ! command -v readelf >/dev/null; then
    skip "readelf not available"
else
    bad_seg=0
    while read -r vaddr memsz; do
        [ -z "$vaddr" ] && continue
        end=$(( vaddr + memsz ))
        if [ "$vaddr" -ge 262144 ] && [ "$end" -gt 2147483648 ]; then   # >128K and past 2G
            bad "amc.elf segment 0x$(printf %x "$vaddr")..0x$(printf %x "$end") exceeds the 2G DDR low region"
            bad_seg=1
        fi
    done < <(readelf -lW "$AMC_ELF" | awk '/^  LOAD/{print strtonum($3), strtonum($6)}')
    [ "$bad_seg" -eq 0 ] && ok "amc.elf LOAD segments fit the mapped DDR low region"
    readelf -lW "$AMC_ELF" | awk '/^  LOAD/{printf "        LOAD vaddr=%s memsz=%s\n", $3, $6}'
fi

echo
echo "=== 3. Combined AMC PDI =================================================="
if [ ! -f "$AMC_PDI" ]; then
    skip "$AMC_PDI not built yet (cd dfx_build/amc_pdi && ./combine_amc_pdi.sh)"
else
    if [ -f "$BASE_PDI" ] && [ "$AMC_PDI" -ot "$BASE_PDI" ]; then
        bad "$AMC_PDI is OLDER than the base PDI - re-run combine_amc_pdi.sh"
    else
        ok "combined PDI is newer than the base PDI"
    fi
    if command -v bootgen >/dev/null; then
        # NOTE: bootgen -read writes its report to STDERR, hence 2>&1.
        _bg=$(bootgen -arch versal -read "$AMC_PDI" 2>&1)
        _n=$(grep -c "core: r5-0" <<<"$_bg")
        if [ "$_n" -ge 2 ]; then
            ok "combined PDI has $_n r5-0 partitions (AMC: TCM + DDR segments)"
        elif [ "$_n" -eq 1 ]; then
            bad "combined PDI has only 1 r5-0 partition - expected 2 (TCM + DDR). amc.elf may be truncated."
        else
            bad "combined PDI has no r5-0 image - the AMC is not in it"
        fi
        grep -q "rpu_subsystem \[id:0x1c000000\]" <<<"$_bg" \
            && ok "rpu_subsystem present with id 0x1c000000" \
            || bad "rpu_subsystem/id 0x1c000000 missing - check felix_pdi_combine.bif"
    else
        skip "bootgen not on PATH (source Vitis settings64.sh) - cannot inspect the PDI"
    fi
fi

echo
echo "=== 4. Artifacts staged from THIS implementation ========================="
# stage_artifacts.sh must have run after run_impl.tcl, or you will program a
# stale PDI and see the old behaviour.
IMPL=dfx_build/proj/felix_slash.runs/impl_1/felix_cips_wrapper.pdi
if [ ! -f "$IMPL" ]; then
    skip "no implemented PDI yet (run_impl.tcl still running or not started)"
elif [ ! -f "$BASE_PDI" ]; then
    bad "$BASE_PDI missing - run ./scripts/stage_artifacts.sh"
elif [ "$BASE_PDI" -ot "$IMPL" ]; then
    bad "staged PDI is OLDER than impl output - run ./scripts/stage_artifacts.sh"
else
    ok "staged base PDI is up to date with impl_1"
fi

echo
echo "=== 5. Host stack ========================================================"
for m in slash ami; do
    lsmod | grep -q "^${m} " && ok "module '$m' loaded" || bad "module '$m' NOT loaded (modprobe $m)"
done
# PF0 (ami) and PF1 (slash_qdma) must talk to FABRIC logic, so they can only bind
# once a valid design is loaded. PF2 (slash_ctl) only maps BARs, which the CPM/PCIe
# block provides from the PS, so it binds regardless. Before programming, PF0/PF1
# unbound is EXPECTED - do not let it block the programming step that fixes it.
for f in 0 1 2; do
    d=$(basename "$(readlink "/sys/bus/pci/devices/0000:01:00.$f/driver" 2>/dev/null)" 2>/dev/null)
    if [ -n "$d" ]; then
        ok "PF$f bound to '$d'"
    elif [ "$f" = "2" ]; then
        bad "PF2 unbound - slash module not loaded, or the card is not enumerated at all"
    else
        warn "PF$f unbound - expected until the card is programmed (kernel log shows 'Invalid config bar'). Re-check after Part 6 + PCI rescan."
    fi
done
if systemctl is-active --quiet vrtd.socket; then ok "vrtd.socket active"
else bad "vrtd.socket inactive - 'sudo systemctl enable --now vrtd.socket'. NEVER run 'vrtd' by hand."; fi
# A prior `systemctl disable` is honoured by deb-systemd-helper at install time, so
# the package can install correctly and still leave the daemon switched off.
if systemctl is-enabled --quiet vrtd.socket 2>/dev/null; then ok "vrtd.socket enabled at boot"
else bad "vrtd.socket DISABLED - it will not come back after reboot: sudo systemctl enable --now vrtd.socket"; fi
id -nG | tr ' ' '\n' | grep -qx vrtadmin && ok "you are in group 'vrtadmin'" \
    || bad "not in 'vrtadmin' - vrtd will refuse design-write (usermod -aG vrtadmin \$USER; newgrp vrtadmin)"

echo
echo "=========================================================================="
printf 'PASS=%d  FAIL=%d  WARN=%d  SKIP=%d\n' "$PASS" "$FAIL" "$WARN" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
    echo "NOT ready - fix the FAILs above before programming."
    exit 1
fi
[ "$WARN" -gt 0 ] && echo "WARNs are expected before the card is programmed - re-run after Part 6."
echo "Ready to program."
echo
echo "Reminders:"
echo "  * BDF is board-level with a DOT before the function: 0000:01:00 (not 01:00:02)"
echo "  * after JTAG programming: echo 1 | sudo tee /sys/bus/pci/rescan"
echo "                            sudo systemctl restart vrtd.service"
echo "  * watch the transfer:     journalctl -u vrtd -f   -> want progress N/N, not 0/N"
exit 0
