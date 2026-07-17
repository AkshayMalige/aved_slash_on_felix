# FELIX vs V80 SLASH — design comparison + fixes applied

Compared the built FELIX design (`testd/dfx_build/proj` / this `dfx_build`) against the
reference V80 SLASH build (`SLASH/linker/src/install.prj/.../top.bd`), settings-level.

## Faithful / identical (verified — no problem)
- **CPM5 / PCIe / QDMA**: 100% identical — all 92 `CPM_CONFIG` key/value pairs match.
  Same PF device IDs (`50b4`/`50b5`/`50b6`), Gen5 x8, same AXIBAR `0x80_0000_0000`, same QDMA.
- **axi_noc_cips structure**: same 4 SI / 2 MI / 7 NMI / 24 NSI (only HBM keys removed).
- **DDR electrical**: felix uses proven `step1_vp1552` values (DDR4-2666V UDIMM, ROW17);
  differences vs V80 (DDR4-3200 Components, ROW16) are correct for the FELIX board.
- **Kernel-control apertures**: slash @ 0x202, service_layer @ 0x203 — match V80.

## Expected differences (by design)
- No HBM (64 BLI pins, HBM channels, dfx_decoupler).
- No DCMAC (dcmac/gt_quad/axis_noc/QSFP).
- 1 DDR controller vs 2: felix DDR (C0_DDR_CH2) = 14G @ 0x600_0000_0000 (+ low 2G @ 0x0)
  -- same base as V80's main DDR; V80 also had CH1 2G @ 0x500_8000_0000 (2nd controller).
- Fewer self-test kernels (8 eth + 4 ddr_bw + 5 traffic_virt vs V80's dozens).

## Bugs found and FIXED (in 05_fix_static.tcl + 30_integrate.tcl pinning)
1. **hw_discovery was UNCONFIGURED** (HIGH). The felix baseline left the hw_discovery
   BAR-layout table empty; the driver reads this ROM to locate uuid/gcq. Fixed: applied
   V80's full `C_PF0_ENTRY_ADDR_*/TYPE_*/...` table (05_fix_static.tcl). Its aperture
   auto-shrank 16M -> 4K, matching V80.
2. **base_logic addresses didn't match V80** (HIGH). assign_bd_address auto-placed
   uuid/gcq/gpio at wrong offsets vs the hw_discovery table. Fixed: pinned to V80 layout
   (30_integrate.tcl): hw_discovery 0x201_0100_0000, uuid 0x201_0100_1000,
   gcq 0x201_0101_0000, gpio 0x201_0104_0000.
3. **clk wizards at wrong aperture** (MEDIUM). Were @ 0x201_8xxx; v80-smi set-frequency
   expects 0x204. Fixed: pinned clk_wizard_slash 0x204_0000_0000,
   clk_wizard_service 0x204_0001_0000.
4. **host->DDR REMAP missing** (MEDIUM). Added V80's REMAP on axi_noc_cips/S00_AXI:
   host BAR window 0x201_0800_0000 -> low DDR 0x0380_0000 (see corrected REMAP section
   below; final door is M01_INI after the single-channel change).
5. **DDR ECC init-scrub not enabled** (LOW-MED). 72-bit ECC DDR needs it. Fixed:
   `MC_INIT_MEM_USING_ECC_SCRUB=true` on axi_noc_mc_ddr4_0.

All fixes validated: full build (00->05->10->20->30) passes `validate_bd_design` with
0 errors, DFX enabled, addresses match V80.

## DDR single-channel consolidation (SLASH developer, 2026-07-14) — applied
FELIX has one DDR channel, so the DDR MC was collapsed and remapped:
- `axi_noc_mc_ddr4_0`: `NUM_MCP 4->1`, `S00_INI` connection emptied, `S01_INI -> MC_0`
  (800/800), `MC_CHAN_REGION1 DDR_CH1_1 -> DDR_CH2`.
- `axi_noc_cips`: host `S00_AXI`/`S01_AXI` now also route to `M01_INI`; all kernel
  NSI (`S00-S03_INI`, `S12-S23_INI`) route to `M01_INI`.
- Net: all traffic reaches DDR via one path `M01_INI -> S01_INI -> MC_0`.
- **Effect: DDR base moved 0x580_0000_0000 -> 0x600_0000_0000 (DDR_CH2), which MATCHES
  where V80's main DDR lived** -> RESOLVES the "DDR base differs from V80" item below.
  (Folded into 05_fix_static.tcl + 30_integrate.tcl.)

## host->DDR REMAP — removed (DDR reached via QDMA, 2026-07-14)
V80 has a REMAP creating a small 128M host BAR "peek window" into DDR
(0x201_0800_0000 -> low DDR). On FELIX the SLASH runtime reaches DDR via QDMA
(MemoryRangeType::DDR), and DDR is fully mapped on every master as C0_DDR_CH2 (14G @
0x600) + C0_DDR_LOW0 (2G @ 0x0). The peek window is not used by the software and the
single-channel developer build did not add one, so the REMAP is OMITTED -> clean DDR
address map (no 0x201_0800 alias). hw_discovery keeps V80's ENTRY_ADDR_2 for ROM
compatibility; the REMAP can be re-added on axi_noc_cips/S00_AXI (M01_INI ->
0x0_0380_0000) if the software ever needs the window.

## Still open / future (not blocking bring-up)
- ~~DDR base differs from V80~~ -> RESOLVED by the DDR_CH2 consolidation above.
- USER_WIDTH mismatch warnings on the VIRT/QDMA passthrough chains (cosmetic; resolves
  when self-test kernels are replaced by real kernels).
- M00_AXI/M01_AXI DATA_WIDTH not explicitly pinned (V80: 32/128) — auto-resolves; pin if
  the AXI-Lite mgmt path shows issues.
