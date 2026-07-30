# PROJECT_CONTEXT.md — SLASH→FELIX port, accumulated knowledge base

> Purpose: give a fresh Claude session full context fast. Read this FIRST,
> then `plan_070726.md` (the step-by-step plan) and `diagrams.md` (ASCII
> picture book). Update this file whenever a fact changes or a step
> completes — it should only get more accurate over time.
> Last updated: 2026-07-21.

## 0. Progress snapshot (2026-07-24) — read this first

- **On-card bring-up: WORKING.** `00_axilite` + a second example run on the powered
  FLX-155 (2026-07-24): host streams the partial PDI, PMC reconfigures `slash`, kernels
  verify. See `DEPLOY_RUNBOOK.md`. Two hardware bugs found + fixed during bring-up:
  1. **PMC/RPU had no NoC route to DDR** (single-DDR consolidation left `S02_AXI`/`S03_AXI`
     on the dead `M00_INI`) → PLM stalled loading `amc.elf` to DDR / AMC shared-mem dead.
     Fixed in `05_fix_static.tcl` (re-point to `M01_INI`) + `30_integrate.tcl` (map DDR into
     `PMC_NOC_AXI_0`/`LPD_AXI_NOC_0`, with a build-time assertion). Verified on silicon.
  2. **Base PDI missing `boot_device { pcie }`** → SBI never armed for host DFX → the
     host-streamed-PDI DMA hard-crashed the server (SBI stuck in JTAG mode → CPM
     uncorrectable error → PCIe endpoint dropped, no Linux log). Root cause: felix CIPS
     ported from VEK280 (SD/JTAG boot) never declared PCIe boot; V80's PDI has the directive.
     Every CIPS/PS_PMC/CPM knob is otherwise identical — the directive is synthesized by
     `write_device_image`, not a settable property we could find. **Permanent fix:**
     `dfx_build/scripts/inject_boot_device_pcie.tcl` (called from `run_impl.tcl`) injects it
     into the BIF + re-bootgens; idempotent + self-verifying. Replaces the manual
     `scripts/diag/40_sbi_axi_slave.tcl` (write `SBI_CTRL 0xF1220004 = 0x9`), kept as a
     fallback. **Built + verified offline (2026-07-24); NOT yet re-verified on silicon
     without the manual step** — next on-card run confirms.
- **Hardware/DFX shell: DONE + verified.** `dfx_build/` builds the felix_cips static
  region + `slash` & `service_layer` DFX partitions, runs synth→impl→device image, and
  exports the abstract shell (`run_impl.tcl`). See `BUILD_RUNBOOK.md`.
- **v80++ linker port: DONE + verified end-to-end.** `linker/` (felix `resources/` +
  patched `src/`) links an HLS kernel into the `slash` partition → partial PDI/`.vbin`.
  Proven with `examples/{00_axilite,01_aximm}` (real Vitis HLS on vp1552 + `LINK_EXIT=0`).
  See `linker/FELIX_LINKER_GUIDE.md` (files/bugs) + `BUILD_RUNBOOK.md` (commands).
- **SLASH software Bucket 1 (drivers/vrt): BUILDS clean for felix, zero source changes** —
  `slash.ko` (+qdma), `libslash`, `libvrt`, `vrtd` (+AMI lib from AVED), `smi`. Device IDs
  50b4/5/6 match; hardcoded map (DDR 0x600, SBR gpio 0x1040000, clk BAR4) verified. One item
  to confirm on-card: `QDMA_LOGIC_BASE 0x201_0002_0000` (`vrt/device.hpp`). NOTE: slash/vrt use
  a HARDCODED map — they do NOT read the hw_discovery VSEC; **only AMI reads it**.
- **Bucket 2/3 (AMI + AMC firmware): pending.** hw_discovery VSEC (3 entries: uuid/gcq/gcq_payload)
  is correct AND the GCQ_PAYLOAD 128M DDR window is already plumbed (see §"host→DDR REMAP" below).
  Remaining: build AMC firmware for felix + embed in base PDI; build ami driver/lib; wire gcq↔RPU.
  Kernel-swap demo can bypass AMI (`vrtd reset.c` → SBR-only). See memory `felix-slash-software-port-plan`.
- Build order note below (§1) is historical; the shell + linker are already done.

## 0b. Platform limits — READ before designing kernels (FELIX single-channel)

**DDR is ONE physical channel.** FELIX wires exactly **1 DDRMC** to **1 DDR4 mini-DIMM**
(DDR4-2666, 72-bit = 64+8 ECC, dual-rank). Silicon has 4 DDRMC blocks but only one has
DRAM on the board. **Theoretical peak ≈ 21.3 GB/s; realistic ≈ 15–18 GB/s.** The other
3 DDRMCs are dark (no board wiring). More memory bandwidth is *not* available on this
board — only a faster DIMM (DDR4-3200 → 25.6) or a different board (more channels/HBM)
would change it.

**`DDR0`/`DDR1`/`DDR2`/`DDR3` are NOT 4 channels — they are up to 4 NoC access ports
("doors") into the SAME single DDRMC.** All four lead to the same one DIMM and share the
same ~21 GB/s. Do not confuse a DDR *port* (NoC path, `M0x_INI`) with a DDR*MC*
(controller) or a channel.
- **Only 2 doors are wired today:** the DDRMC has `NUM_NSI {2}` (`00_felix_cips_static_region.tcl`,
  `axi_noc_mc_ddr4_0`) → `MC_0`=DDR0, `MC_1`=DDR1. **DDR2/DDR3 are unmapped → a kernel
  mapped to them (`sp=...:DDR2/3`) segfaults the host** at buffer alloc. `01_aximm` (DDR0+DDR1)
  works; `02_ddr_bw` (DDR0-3) crashed for this reason.
- **The "4" is a template default, NOT a hardware cap.** `linker/resources/slash.tcl`
  hardcodes 4 `ddr_noc` bridges and `bd_ports.py` sets `num_ddr=4`. You can open more
  doors (raise `NUM_NSI`, route `M02/M03_INI`, edit the template) — but **it buys zero
  bandwidth**: one channel, 21 GB/s, shared. **~2 wide (512-bit) ports already saturate it.**
  More ports = concurrency only, and too many interleaved masters can *lower* effective BW
  (DDR row thrashing). Rule of thumb: **1–2 wide, sequential-burst ports.**
- One AXI `m_axi` port does **both** read and write (independent AXI R/W channels) — you do
  not need separate read/write ports.

**Kernel clock is capped at 333.33 MHz by software, not by timing.**
`vrt/include/vrt/device.hpp:95 CLOCK_MAX_FREQ = 333333333`; `device.cpp:251-254` clamps any
vbin requesting more (warns "exceeds maximum frequency 333333333"). Kernels are *implemented*
at a 400 MHz base (`linker/src/emit/metadata/timing_freq.py base_freq_hz`) and the vbin may
record 400, but **they RUN at ≤333 MHz**. Harmless for memory BW: 512-bit × 333 MHz =
21.3 GB/s ≥ the DDR ceiling. **To raise:** ≤400 MHz — bump `CLOCK_MAX_FREQ` + rebuild/reinstall
the `vrt` package (kernels already close 400); >400 MHz — also raise the linker `base_freq_hz`,
ensure the RM closes timing, and note `clk_wizard_slash` VCO range may need a base rebuild.
Only worth it for *compute*-bound kernels; irrelevant to DDR/QDMA bandwidth. Set
`freqhz=333333333` in a kernel's `config.cfg` `[clock]` block to avoid the warning.

**Base NoC QoS is placeholder-low.** As shipped from the VEK280/SLASH port, the DDR
controller was provisioned at only ~1.5 GB/s (`MC_0 {1000}`+`MC_1 {500}`) and the QDMA→DDR
hop at 128 MB/s — raised in the base PDI. But NoC QoS is a *floor, not a cap* (a DDR kernel
write hits 23.8 GB/s over a 5 GB/s reservation), so it was **not** the QDMA limiter.

**QDMA host↔card = ~4.3 GB/s, correct (SOLVED 2026-07-30) — a felix perf change, NOT an
upstream bug.** The reference SLASH pairs `{buffer.c 4 KB writes, driver aperture_size 4096
(keyhole)}` = self-consistent but ~0.3–1 GB/s. The port changed `buffer.c` to ≤128 MB writes
but left `aperture=4096` → 128 MB wrapped into a 4 KB keyhole window = **silent data
corruption** (`01_aximm` 4 MB → `Test failed`). Fix = matched pair: keep big writes AND set
`driver/slash_qdma.c` **`aperture_size = 0`** (linear DMA). Verified: `Test passed`, ~4.3 GB/s.
PCIe link is now genuine **Gen5 x8 32GT/s** (earlier "Gen3 downgraded" was a cable issue, fixed).
The ~4.3 ceiling is the single-queue `buffer.sync()` path (same path V80 uses) — going further
(SGL page-coalescing + hugepages, or multi-queue) is custom, off the reference path; don't
unless load time actually bottlenecks. See DEPLOY_RUNBOOK "QDMA host↔card bandwidth" appendix.

## 1. The goal (user: Akshay)

Port the AMD/Xilinx **SLASH** SmartNIC/accelerator shell from the Alveo V80
(`xcv80-lsva4737-2MHP-e-S`, HBM part) to the **FELIX FLX-155** PCIe card
(Brookhaven Lab; `xcvp1552-vsva3340-2MHP-e-S`, Versal Premium).

Decisions already made — do not relitigate:
- **Skip entirely: HBM, DCMAC, SMBus** (FLX-155 has none of them).
- **Memory = one DDR4-2666 72-bit ECC Mini-DIMM via Versal NoC.**
- Build order: flat static shell first → board bring-up → DFX later →
  software (vrtd/VRT) → firmware (AMC) last/optional.
- Hand-built Tcl flow (not the official v80++ toolchain) for now; may adopt
  FELIX-ized copies of the official scripts at Phase C4.

## 2. Directory map (absolute paths)

| Path | What it is |
|---|---|
| `~/VersalPrjs/felix/felix-xpfm-pcie/porting_slash/slash_felix/` | **THE working repo** (this dir). BD scripts + Vivado project `myproj/project_1.xpr`, BD `felix_cips`. |
| `…/porting_slash/slash_vek280/` | Earlier VEK280 port, reference only. |
| `~/VersalPrjs/felix/felix-xpfm-pcie/SLASH/` | Full upstream SLASH checkout (github.com/Xilinx/SLASH). sw + fw + hw. `my-notes.md` there = user's own V80→FLX155 audit (part-number hit list, phased plan, sw/fw change list — trustworthy). |
| **`SLASH/linker/src/install.prj/`** | **★ GROUND TRUTH: the actual BUILT V80 project** (`slash.xpr`, part xcv80). Real BDs are JSON `.bd` files: `slash.srcs/sources_1/bd/top/top.bd` (1.9M — full static_region+slash+service_layer tree + `addressing` = the real assigned address map), `slash.gen/.../service_layer_inst_0.bd` + `slash_base_inst_0.bd` (the two DFX BDC contents). **Parse with python `json.load` — do NOT read the scripts as truth.** |
| `SLASH/linker/resources/base/scripts/` | V80 hw *generator scripts* (`top.tcl` 533K, `slash_base.tcl` 200K, `service_layer.tcl` 79K, `enable_dfx_bdc.tcl`). These BUILD install.prj but the built `.bd` above is the authoritative artifact — use scripts only for the REMAPS/CONNECTIONS Tcl syntax, not for what's actually in the design. |
| `SLASH/linker/resources/{slash,service_layer}.tcl` (top level) | **Jinja templates** for `v80++ link` (kernel splicing) — NOT the shell; ignore for shell work. |
| `SLASH/linker/resources/submodules/AVED/` | AVED submodule: `hw/` XSA build, `fw/AMC/` RPU firmware, `sw/AMI/` host mgmt. |
| `~/VersalPrjs/felix/felix-xpfm-project/step1_vp1552/` | **Proven-good FELIX board config**: `run.tcl` (DDR4 MC settings, CIPS), `pinout.xdc` (DDR4 + clk pins). Use as ground truth for pins/DDR. |
| `~/Downloads/slash-fpga-readthedocs-io-en-latest.pdf` + `SLASH/docs/` | Official docs (architecture, pcie-topology, memory-model, platform-modes). |

## 3. SLASH stack in one paragraph each

- **Software (host)**: user app → VRT (libvrt) → libvrtd++/libvrtd →
  vrtd daemon (AF_UNIX) → libslash → `slash` kernel module. Three PCIe PFs:
  PF0 `ami` 0x50B4 (mgmt), PF1 `slash_qdma` 0x50B5 (DMA), PF2 `slash_ctl`
  0x50B6 (BAR MMIO). All in `SLASH/{vrt,driver,smi}`.
- **Firmware**: AMC runs on the Versal RPU (Cortex-R5F) — sensors/QSFP/flash
  /host-command-queue. PLM (AMD vendor fw on PMC) boots the PDI. FELIX
  first-light needs NO firmware (gcq stays idle).
- **Hardware**: one Vivado BD. `static_region` (never reconfigured: CIPS/CPM5
  PCIe, base_logic mgmt, NoC, DDR MCs) + two DFX partitions (`slash`,
  `service_layer` — BD containers, marked by enable_dfx_bdc.tcl) where
  `v80++ link` splices user kernels.

## 4-AUTH. AUTHORITATIVE V80 facts (parsed from install.prj/top.bd JSON, 2026-07-09)

These SUPERSEDE anything below that came from reading the .tcl scripts.
Source: `SLASH/linker/src/install.prj/slash.srcs/sources_1/bd/top/top.bd`.

- **V80 axi_noc_cips**: NUM_SI=4, NUM_MI=2, NUM_NMI=7, NUM_NSI=24, **NUM_HBM_BLI=64**
  (the HBM controller lives INSIDE this cell). FELIX has no HBM keys → correct.
- **V80 DDR = TWO controllers** (`axi_noc_mc_ddr4_0/_1`), each: DDR4-3200AA(22-22-22),
  **MC_MEMORY_DEVICETYPE=Components**, MC_COMPONENT_WIDTH=x16, 72-bit, MC_RANK=1,
  **MC_ROWADDRESSWIDTH=16**, NUM_MC=1, NUM_MCP=4, NUM_NSI=2, MC_INPUTCLK0_PERIOD=5000.
  - **FELIX = ONE controller**: DDR4-2666V(19-19-19), **DEVICETYPE=UDIMMs**, 72-bit,
    **RANK=2**, **ROWADDRESSWIDTH=17**, NUM_MC=1, NUM_MCP=4, NUM_NSI=2. (UDIMM+ROW17+RANK2
    differ from V80 Components+ROW16+RANK1 — proven-good per step1_vp1552, keep as-is.)
    <!-- corrected 2026-07-22: this line previously said RANK=1. Both the felix design
         (00_felix_cips_static_region.tcl `CONFIG.MC_RANK {2}`) and the proven-good
         step1_vp1552/run.tcl say RANK=2. -->

> ⚠️ **The single-channel consolidation in `05_fix_static.tcl` severs the PMC and RPU
> DDR paths.** `axi_noc_cips/M00_INI → axi_noc_mc_ddr4_0/S00_INI` is disconnected, but
> `S02_AXI` (PMC, `ps_pmc`) and `S03_AXI` (RPU, `ps_rpu`) still list **only `M00_INI`**
> as their route to DDR. Result: the PLM cannot load `amc.elf` (21.5 MB @ `0x4000_0000`)
> → **"PLM stalled during programming", DONE bit LOW**; and the AMC could never reach
> `HAL_RPU_SHARED_MEMORY_BASE_ADDR 0x3800_0000` → AMC shared-memory magic reads `0x0`.
> V80 by contrast maps DDR into **both** `PMC_NOC_AXI_0` and `LPD_AXI_NOC_0`
> (verified in `install.prj/.../top.bd` `addressing`). See §"AMC DDR path gap".
- **V80 REAL ADDRESS MAP** (host view via cips CPM_PCIE_NOC, the `addressing` block):
  | base | range | what |
  |---|---|---|
  | `0x0201_0100_0000` | 4K | hw_discovery |
  | `0x0201_0100_1000` | 4K | uuid_rom |
  | `0x0201_0101_0000` | 4K | gcq_m2r S00_AXI |
  | `0x0201_0104_0000` | 4K | pcie_mgmt_pdi_reset_gpio |
  | (M00_AXI aperture `0x201_0000_0000` / 32M covers all mgmt above) | | |
  | `0x0202_0000_0000`+ | 64K each | slash self-test regs (hbm_bandwidth/ddr_bandwidth/traffic_producer/traffic_virt) — M04_INI aperture `0x202_0000_0000`/16M |
  | `0x0203_0000_0000`+ | 64K each | service_layer regs (eth_x, dcmac, gt gpio) — M05_INI aperture `0x203_0000_0000`/4M |
  | `0x0204_0000_0000` | 64K | clk_wizard_slash |
  | `0x0204_0001_0000` | 64K | clk_wizard_service |
  | `0x0050_0800_0000` | 2G | DDR CH1 (axi_noc_mc_ddr4_0) |
  | `0x0060_0000_0000` | 32G | DDR CH2 (axi_noc_mc_ddr4_1) |
  | `0x0040_0000_0000`..`0x004F..` | 32×1G | HBM (skip on FELIX) |
- **host→DDR REMAP (GCQ_PAYLOAD window) — PRESENT in FELIX** (added by `dfx_build/scripts/05_fix_static.tcl`,
  confirmed in built-BD export): `axi_noc_cips/S00_AXI CONFIG.REMAPS {M01_INI {{0x20108000000 0x00038000000 0x08000000}}}`
  maps host-BAR window `0x201_0800_0000` (128M) → low DDR `0x0_0380_0000`, plus
  `assign_bd_address 0x201_0800_0000/128M` in `CPM_PCIE_NOC_0` → `axi_noc_mc_ddr4_0/S01_INI/C0_DDR_LOW0`.
  Matches V80 exactly (same `0x3800_0000` target; only the door M00_INI→M01_INI changed for FELIX's
  single-channel DDR). This is the AMI↔AMC 128M shared payload buffer (hw_discovery VSEC entry 2,
  type `0x55`=GCQ_PAYLOAD). (Older revisions of this note said "FELIX lacks this" — no longer true.)
- **slash BDC real inventory** (slash_base_inst_0.bd): 81 hbm_bandwidth, 70 smartconnect
  (HBM fanout), 18 axi_noc, 16 axis_noc, 8 traffic_producer, 98 intf ports (64 HBM_AXI +
  DDR M00-03_INI + S_AXILITE_INI + SL_VIRT + QDMA_SLAVE_BRIDGE). **~90% HBM → strip.**
- **service_layer BDC real inventory** (service_layer_inst_0.bd): 19 axi_noc, **16 axis_noc
  + 2 dcmac + 2 dcmac200g_ctl_port + 2 gt_quad_base + 8 clock_to_serdes + axis converters/
  fifos = ALL DCMAC ethernet → strip**; 8 hbm_bandwidth (misnamed counters), 6 traffic_producer,
  8 axi_gpio (DCMAC ctrl), 5 axi4_full_passthrough, 10 axi_register_slice, 4 smartconnect.
  **KEEP: axi_noc (sl2noc/virt/qdma-bridge), axi_register_slice, axi4_full_passthrough, smartconnect.**
- **FELIX bugs found & status (2026-07-09)**: M00_AXI aperture 0x203→0x201 (FIXED by user),
  aclk5 no clock (FIXED), axi_noc_1/M00_AXI category pl→ps_pcie (FIXED); STILL OPEN:
  M04_INI/M05_INI have NO apertures (need 0x202/16M + 0x203/4M), S00_AXI REMAP missing,
  assign_bd_address never run (0 segments assigned), service_layer+slash not built.

## 4. Verified V80 architecture facts (from reading top.tcl etc. — cite-able)
### ⚠️ OUTDATED — kept for history; §4-AUTH above is authoritative where they conflict.

- top.tcl instantiates slash + service_layer as **BD containers** (L4272,
  L4368); static_region is a hier cell (L2970) containing: `aved`
  (= cips + base_logic + clock_reset, L1459), `noc` (= axi_noc_cips +
  axi_noc_mc_ddr4_0/_1, L1851), `virt_noc` (5 INI retimers), `clk_rst_shell`
  (host-programmable kernel clocks), `axi_noc_1` (QDMA loopback return),
  `dcmac_noc` (skip), `dfx_decoupler_0` (HBM-only, skip).
- **axi_noc_cips = 4 SI / 2 MI / 7 NMI / 24 NSI** — every port is a headcount
  of a named consumer (full port-map tables in plan_070726.md §0.1 and in the
  conversation-derived tables; short form):
  - 4 SI ← CIPS masters: CPM_PCIE_NOC_0 (QDMA data), CPM_PCIE_NOC_1 (BAR/
    mgmt), PMC, LPD/RPU.
  - 2 MI → base_logic mgmt regs (aperture 0x201_0000_0000/32M); NOC_PMC_AXI_0
    loopback (host→flash/boot).
  - 7 NMI → 2 DDR MCs × 2 INI each (host/kernel traffic split) + slash ctrl
    (0x202…/16M) + service_layer ctrl (0x203…/4M) + clk_rst_shell.
  - 24 NSI ← 4 slash ddr_noc sockets + 8 HBM VNoC (skip) + 8 SL2NOC + 4
    M_VIRT returns.
- **HBM controller is INSIDE axi_noc_cips** (HBM_NUM_CHNL=16, NUM_HBM_BLI=64,
  64 HBMxx_AXI BLI pins) — no separate cell. Skipping HBM = never set those
  CONFIG keys.
- **dfx_decoupler exists ONLY for the 64 HBM BLI pins** (raw AXI across DFX
  boundary needs gating; INI tunnels don't). No HBM ⇒ no decoupler needed.
- **QDMA slave-bridge loopback** (static infra, needed on FELIX):
  slash/QDMA_SLAVE_BRIDGE_0 → virt_noc → service_layer/S_QDMA_SLV_BRIDGE →
  (reg_slice→passthrough→reg_slice chain) → M_QDMA_SLV_BRIDGE →
  static_region/axi_noc_1 (NSI→MI) → M00_AXI → aved/NOC_CPM_PCIE_0.
- V80 DDR4 MCs: CONTROLLERTYPE DDR4_SDRAM, NUM_NSI=2 (S00=host, S01=kernel),
  DDR4-3200AA x16 components. FELIX differs: UDIMM DDR4-2666V(19-19-19),
  72-bit, 2-rank, ROWADDRESSWIDTH 17, MC_INPUTCLK0_PERIOD 5000 — these FELIX
  values are PROVEN in step1_vp1552/run.tcl L82-94 and already match
  am_felix_noc.tcl.
- Real service_layer.tcl: DCMAC gated behind DCMAC0/1_ENABLED flags;
  dummy_noc_* are real axis_noc ethernet bridges (not placeholders);
  eth_0..7 (VLNV hls:hbm_bandwidth — misleading name, generic bandwidth
  counter) drive sl2noc in the self-test build; the true shell contract
  leaves sl2noc_x/S00_AXI open for kernels. It has NO M_AXILITE_MGMT port
  and no SMBus. axi4_full_passthrough = plain pipeline stage, nothing DFX.
- base_logic (V80): rpu_sc NUM_MI=2 with axi_smbus_rpu (smbus:1.1) on M01;
  top-level `smbus_0` port is iic_rtl-typed (an axi_iic is drop-in-shaped
  later for FELIX INA226/ADM1266 mgmt).
- CIPS CPM_PCIE1 config: FELIX copy already faithful to V80 (QDMA mode,
  32GT/s, X8, PF IDs 50b4/50b5/50b6, same BARs/AXIBARs).

## 5. Current state of the FELIX design (as of 2026-07-07)

BD `felix_cips` (myproj/project_1.xpr, Vivado 2025.1, part
xcvp1552-vsva3340-2MHP-e-S). Built by `am_felix_cips.tcl` →
`am_felix_noc.tcl` → `am_felix_service_layer.tcl`, then GUI surgery captured
in `am_felix_bd_full.tcl` / `felix_cips_export_raw_2026-07-02.tcl`
(near-identical write_bd_tcl exports; CLAUDE.md predates the GUI changes).

Actual hierarchy now: `static_region/{aved{cips,base_logic,clock_reset},
axi_noc_cips(4SI/1MI/1NMI/8NSI), axi_noc_ddr4(NUM_NSI=1),
dfx_decoupler_0(orphan, unconnected)}` + top-level sibling `service_layer`
(SL2NOC_0..7, S/M_VIRT_0..3, S/M_QDMA_SLV_BRIDGE, S_AXILITE_INI,
M_AXILITE_MGMT, service_clk, service_resetn — internals fully wired,
externals dangling).

**Correct already**: cips config; base_logic (no SMBus, rpu_sc NUM_MI=1);
clock_reset; service_layer internal chains (exact match to real shell minus
DCMAC); axi_noc_ddr4 MC values; 0x203 aperture choice.

**Known gaps (= plan Phase A)**:
1. orphaned dfx_decoupler_0 → delete (A1)
2. axi_noc_ddr4 NUM_NSI=1 → 2 (host/kernel split) + axi_noc_cips NUM_NMI 1→2 (A2)
3. top-level wiring CIPS↔NoC↔DDR↔service_layer unconnected (A3)
4. QDMA slave-bridge loopback missing entirely (axi_noc_qdma_ret cell +
   NOC_CPM_PCIE_0 connection + forward NMI) (A4)
5. service_layer M_AXILITE_MGMT/S_AXILITE_INI don't match real shell —
   recommended: delete both, mgmt goes axi_noc_cips/M00_AXI →
   aved/s_axi_pcie_mgmt_slr0 directly (A5)
6. no validate/address-map pass yet; no pins; no impl (A6, Phase B)

FELIX target NoC sizing: SI=4, MI=1, NMI=2–4, NSI=8–13 (see plan).

## 6. How to work in this repo (conventions & gotchas)

- Vivado **2025.1** only (cips script errors otherwise). Run scripts FROM
  slash_felix/ (paths resolve via `[info script]`).
- Script order matters: cips → noc → service_layer. service_layer script is
  idempotent (deletes its own cells first); the other two are not.
- Preserve `xilinx.com:ip:<name>:<version>` VLNV pins when editing.
- iprepo/ has the 4 custom IPs: hw_discovery_v1_0, shell_utils_uuid_rom_v2_0,
  cmd_queue_v2_0, axi4_full_passthrough.
- After BD changes: `validate_bd_design`, `assign_bd_address`, then
  `write_bd_tcl -force` a fresh export so the BD stays reproducible.
- Big generated Tcl (top.tcl etc.): NEVER read sequentially — grep + targeted
  offsets, or spawn parallel research forks (worked well: 3 forks for
  top/slash_base/service_layer).
- myproj/, vivado logs/journals/.str = generated, gitignored, ignorable.

## 7. User working style (observed)

- Wants to understand *why* before wiring — explanations with exact port
  names, per-port "who is this really / why does it exist" tables, and ASCII
  diagrams (see diagrams.md) land well. Numbers must be accounted for, never
  hand-waved ("is it random?" → show the headcount).
- Verify against the real sources; he asks "make sure you are correct" —
  cite file+line, flag inference vs. verified fact explicitly.
- Step-by-step execution preferred; keep plan_070726.md checklist updated as
  steps complete.
- Don't remove content when asked to expand/rewrite ("dont remove anything").

## 8. Next actions (start here next session)

1. Ask/confirm where we are in the plan checklist (plan_070726.md bottom).
2. If nothing changed since 2026-07-07: implement Phase A1+A2 as Tcl (user
   already offered-to be written), then A3–A6.
3. After Phase A: B1 pins from step1_vp1552/pinout.xdc + FLX-155 schematic
   (PCIe GTYP banks 102–105, refclk via Si5156).
4. Keep this file and plan_070726.md updated after every completed step.

## 9. UPDATE 2026-07-07 evening: standalone validated build exists

**`~/VersalPrjs/felix/felix-xpfm-pcie/slash_felix155/`** — new standalone
deliverable (like `testc/`): `felix_slash.tcl` + `iprepo/` + `pinout.xdc` +
README. Runs start-to-finish in Vivado 2025.1 batch: builds BD `felix_slash`
(static_region{aved, axi_noc_cips 4SI/2MI/4NMI/16NSI, axi_noc_ddr4 NUM_MC=1
NUM_NSI=2, axi_noc_qdma_ret} + slash{9 kernel sockets + 0x202 ctrl} +
service_layer{SLASH-faithful, no M_AXILITE_MGMT}), **validate_bd_design
PASSES, 0 errors**, V80-identical address map (hw_discovery 0x0201_0100_0000,
uuid +0x1000, gcq 0x0201_0101_0000, pdi gpio 0x0201_0104_0000, RPU gcq
0x8001_0000), DDR 2G+30G, QDMA loopback maps psv_noc_pcie_2 @0x80_0000_0000.
Lessons: DDR4 MC pins need explicit NUM_MC=1/NUM_MCP=4; NoC pins at CIPS need
CATEGORY ps_pcie/ps_pmc/ps_rpu; INI driver→load strategy must not be set on
both ends; 16 kernel paths @500MB/s oversubscribe one MC port (use 250).
Expected criticals: 17× "S00_AXI not driven" (kernel sockets, by design).
This supersedes Phase A of plan_070726.md; next = Phase B2 (synth/impl/PDI).
