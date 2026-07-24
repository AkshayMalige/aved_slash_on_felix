# Crash diagnostic protocol — DFX-from-host host reboot

Symptom: `./build/00_axilite 01:00.1 axilite_hw.vbin` reboots the whole server
the instant vrtd's design writer starts the QDMA write of the partial PDI to
`0x102100000` (PMC slave-boot stream). No kernel log survives → firmware-level
fatal (sync flood) is the working theory; the card's static shell survives
every crash (all 3 PFs re-enumerate), so the device itself never resets.

Working hypothesis ranking:
  H1. SBI is not in AXI-slave-boot mode on this JTAG-booted card → the stream
      write backpressures → CPM wedges → host MMIO completion timeout → sync flood.
  H2. The QDMA MM path (CPM_PCIE_NOC_*) is broken generally (never exercised
      before) → any MM DMA would crash, PMC target is incidental.
  H3. The partial PDI content itself is bad (DFX/NoC partitions) and the PLM
      wedges the NoC while applying it.

Every experiment below is chosen to separate H1/H2/H3.

## Phase 0 — one-time setup (do once, ~30 min)

1. **Freeze artifacts.** One clean build, then `./scripts/diag/00_baseline.sh`
   records md5sums. Do NOT rebuild between iterations.
2. **kdump** (catches the kernel-panic case, if any):
   `sudo apt-get install -y linux-crashdump` → reboot → `kdump-config show`.
3. **netconsole** (streams kernel messages to another machine in real time —
   survives cases where disk logging doesn't). On another Linux box on the LAN
   run `nc -ulk 6666`, then on the server:
   `sudo modprobe netconsole netconsole=@/,6666@<listener-ip>/`
   If the listener stays silent through a crash → firmware reset (H1/H2 path),
   if it prints a panic → kernel bug, different investigation.
4. **`pcie_ports=native` kernel arg** (GRUB_CMDLINE_LINUX) — makes Linux own
   AER instead of firmware. On some Supermicro boards this converts the silent
   sync-flood reboot into a *logged, survivable* AER event. Cheap to try;
   remove later if it changes nothing.
5. Optional BIOS: look for AMD CBS → NBIO → error-reporting / "Sync Flood"
   settings; disabling fatal-error sync flood keeps the OS alive to log.

## Phase 1 — no-crash-risk experiments (JTAG only)

After JTAG-programming `felix_slash_amc.pdi` (before or after host reboot):

1. `xsdb scripts/diag/20_jtag_harvest.tcl | tee diag_logs/jtag_baseline.txt`
   → PLM log + SLAVE_BOOT (SBI) regs + reset reason. This is the H1 baseline:
   what mode is the SBI in on a JTAG-booted card?
2. `xsdb scripts/diag/30_jtag_partial_load.tcl | tee diag_logs/jtag_partial.txt`
   → applies the vbin partial PDI over JTAG.
   * FAIL → **H3 confirmed**: the partial PDI/DFX content is the problem;
     the xsdb error + plm log names the partition. Stop crashing the host.
   * PASS → PDI content is good; continue.
3. Reboot host, `./scripts/diag/00_baseline.sh`, and re-run the harvest —
   does PERST/re-enumeration change the SBI state?

## Phase 2 — instrumented crash iterations (max 3; each must answer one question)

Per-iteration protocol (identical every time):
  pre : `sudo ipmitool sel clear` ; start netconsole listener ;
        `./scripts/diag/00_baseline.sh`
  run : the ONE experiment for this iteration
  post: after reboot, FIRST `./scripts/diag/10_after_crash.sh`,
        THEN `xsdb scripts/diag/20_jtag_harvest.tcl | tee ...`
        (harvest the card BEFORE reprogramming it — it still holds the
        post-crash PLM/SBI state), only then reprogram for the next round.

* **Iteration B — `no_program_test`** (already built):
  `./build/no_program_test 0000:01:00 axilite_hw.vbin`
  Same QDMA MM machinery, DDR target instead of PMC.
  * crashes → **H2**: generic MM-path fault; compare CPM_PCIE_NOC wiring /
    NoC apertures; the SBI was never the issue.
  * passes  → H2 eliminated; fault is PMC-target-specific → H1 front-runner.

* **Iteration C — minimal PMC probe** (tool to be written from vrtd's qpair
  code when we get here): MM read 64B @ 0x102000000 (PMC RAM), then read
  @ 0x101220000 (SBI regs), then 4-byte write @ 0x102100000 (stream FIFO).
  Whichever step wedges pinpoints the exact target, with the PLM log showing
  whether the PLM saw anything.

* **Iteration D — SBI-mode fix attempt**: via xsdb put the SBI into
  AXI-slave-boot mode (exact `mwr` derived from the Phase-1 SBI dump), rerun
  `00_axilite`. Works → **H1 confirmed + fix identified** (bake the SBI setup
  into the base PDI as CDO, or have vrtd program the SBI regs at 0x101220000
  over the same QDMA queue before streaming).

## Evidence checklist per iteration (all land in diag_logs/)

- [ ] artifact md5s unchanged (00_baseline)
- [ ] SEL diff (sel_before vs sel_after) — the firmware's cause-of-death
- [ ] previous-boot journal tail + pstore + /var/crash
- [ ] netconsole capture (silent vs panic)
- [ ] JTAG harvest: plm log, SLAVE_BOOT regs, reset reason — post-crash,
      pre-reprogram
- [ ] lspci -vvv of PF0 + root port (LnkSta/UESta/CESta)
