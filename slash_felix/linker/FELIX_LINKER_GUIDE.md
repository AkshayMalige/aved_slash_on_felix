# FELIX v80++ Linker — Complete Guide

Porting the ESnet/AMD **SLASH** `v80++` DFX linker from the Alveo **V80** (HBM) to the
**FELIX FLX-155** (`xcvp1552-vsva3340-2MHP-e-S`; 1 DDR channel, no HBM, no DCMAC, no SMBus),
so an HLS kernel can be linked into the felix `slash` reconfigurable partition and emitted
as a partial PDI / `.vbin`. Verified end-to-end on Vivado/Vitis **2025.1** with
`examples/00_axilite` and `examples/01_aximm`.

---

## 1. What the linker does (the big picture)

The felix hardware is a **DFX (Dynamic Function eXchange)** design: a fixed *static region*
(`felix_cips`) with one reconfigurable partition called **`slash`** (cell path
`felix_cips_i/slash`). The static region is built + implemented **once** (`dfx_build/`), which
emits an **abstract shell** — a lightweight routed context that lets you place a new module into
the `slash` partition *without* re-implementing the whole chip.

`v80++ link` takes an HLS kernel and:

```
 HLS kernel(s)                resources/  (the felix "platform")
 (component.xml)                   │
      │                           │
      ▼                           ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  1. RENDER   (pure Python, Jinja2)                            │
 │     bd_ports.txt + config.cfg + kernel metadata              │
 │       → rendered slash.tcl  (builds the RM block design)     │
 │       → rendered system_map.xml (runtime metadata)           │
 ├──────────────────────────────────────────────────────────────┤
 │  2. BUILD RM (Vivado batch: slash_project_build.tcl)         │
 │     import slash_base.bd  (partition boundary)               │
 │     add abs_shell_slash.dcp  (place context)                │
 │     source rendered slash.tcl  (wipe + rebuild interior      │
 │        with the user kernels wired to DDR/VIRT/HOST/ctrl)    │
 │     synth RM → impl against abstract shell                   │
 │     write_device_image -cell felix_cips_i/slash             │
 │       → top_i_slash_slash_<proj>_inst_0_partial.pdi         │
 ├──────────────────────────────────────────────────────────────┤
 │  3. PACKAGE (Python)                                          │
 │     report_utilization → XML ; tar{partial PDI, util XML,    │
 │        system_map.xml} → <name>.vbin                         │
 └──────────────────────────────────────────────────────────────┘
```

At runtime, the host DMAs that partial PDI over QDMA to `0x102100000`; the PMC PLM does the
partial reconfiguration and the kernel goes live in the `slash` partition. (Runtime side is a
later phase — this guide covers producing the `.vbin`.)

### The load-bearing invariant

Three things must describe the **exact same partition boundary**, or the link fails:

```
abs_shell_slash.dcp partition pins  ==  slash_base.bd ports  ==  slash.tcl port references
```

For felix that boundary is:
`S_AXILITE_INI`, `M00_INI..M03_INI`, `SL_VIRT_00..03`, `QDMA_SLAVE_BRIDGE_0`,
`slash_clk`, `slash_resetn`.
Because `slash.tcl` starts with `delete_bd_objs [get_bd_cells]`, only the **boundary** of
`slash_base.bd` matters — its interior is wiped and rebuilt every link.

---

## 2. File inventory

Location root: `porting_slash/slash_felix/`. The whole `linker/` and `examples/` trees are new
in this repo (copied from `SLASH/linker` then felix-adapted). Below, "authored" = written from
scratch; "modified" = edited from the SLASH original; "generated" = produced by a Vivado run.

### 2a. Authored (new) files

| File | Purpose |
|---|---|
| `linker/gen_slash_base.tcl` | Standalone Vivado generator: builds `slash_base.bd` and exports it into `resources/abstract_shell/slash_base/`. Run once. |
| `linker/resources/base/scripts/slash_base.tcl` | **Replaced** V80's 4016-line recipe with a clean 97-line felix recipe that builds the `slash_base` boundary + a self-test interior (wiped at link). |
| `linker/FELIX_LINKER_PORT.md` | Short change-log / invariant reference. |
| `linker/FELIX_LINKER_GUIDE.md` | This document. |
| `examples/build_hls.sh` | Helper: `v++ -c --mode hls` + `vitis-run --package` for a list of kernels → `component.xml`. |
| `examples/00_axilite/*`, `examples/01_aximm/*` | Copied from SLASH, retargeted (below). |

### 2b. Modified files (felix-adapted from SLASH)

| File | Change |
|---|---|
| `linker/resources/bd_ports.txt` | Logical→RTL port map. Removed all 64 HBM + 8 MEM lines. Kept DDR0-3→`M00-03_INI`, VIRT0-3→`SL_VIRT_00-03`, HOST→`QDMA_SLAVE_BRIDGE_0`, `clock:aclk1`, `reset:ap_rst_n`. |
| `linker/resources/slash.tcl` | Jinja template that builds the RM. Stripped HBM/DCMAC (1336→623 lines); DDR apertures set to `{0x0 2G}{0x600_0000_0000 32G}`; **clock/reset boundary renamed** `user_clk`→`slash_clk`, `arstn`→`slash_resetn`. |
| `linker/resources/base/scripts/slash_project_build.tcl` | The Vivado "link engine". `-part`→vp1552; top→`felix_cips_wrapper`; RP cell `top_i/slash`→`felix_cips_i/slash` (3 sites). |
| `linker/src/emit/hw/tcl_gen.py` | Terminator/context builder. `num_mem`→0 (no `hbm_vnoc`), `dcmac_rx_tready_tie_slots`→`[]` (no DCMAC). DDR=4/VIRT=4/HOST kept. |
| `linker/src/emit/hw/user_region/terminator_ctx.py` | Hardcoded `"user_clk"`→`"slash_clk"` (VIRT + HOST terminator clocks). |
| `linker/src/emit/hw/user_region/hbm_ctx.py` | Hardcoded `"user_clk"`→`"slash_clk"` (inert on felix, fixed for consistency). |
| `linker/src/emit/metadata/report_util.py` | `nodes["top_wrapper"]` → platform-aware lookup (`felix_cips_wrapper`, fall back to `top_wrapper` / the `(top)`-flagged row). |
| `dfx_build/scripts/run_impl.tcl` | Also emits `felix_slash.xsa` (`write_hw_platform`) + `felix_cips_wrapper_routed_bb.dcp` (black-boxed static) alongside abstract shells + base PDI. |

`linker/resources/system_map.xml` was **not** changed — it is card-agnostic (all values come
from context; ethernet auto-disables when there is no network config).

### 2c. Generated artifacts (produced by Vivado runs, live under `resources/`)

| Artifact | Produced by | Size |
|---|---|---|
| `resources/abstract_shell/slash_base/slash_base.bd` (+ `ip/`) | `gen_slash_base.tcl` | ~57 KB |
| `resources/abstract_shell/abs_shell_slash.dcp` | `dfx_build/scripts/run_impl.tcl` (copied in) | ~12.6 MB |
| `resources/base/iprepo/` | copied from felix `iprepo` | — |

### 2d. Files intentionally NOT ported (skip/defer)

`service_layer.tcl` + `abstract_shell/service_layer/*` + `dcmac/*` (networking — never runs on
felix), `aved/*` (AMC firmware, later phase), `base/scripts/{create_project,top}.tcl` (the V80
*install* regeneration — unneeded because we cut the abstract shell directly from `run_impl.tcl`).

---

## 3. How each linker input file was generated

- **`bd_ports.txt`** — authored by hand from the felix `slash` boundary. Format is
  `LOGICAL:RTL_PORT BUS_TYPE`. It tells the linker which NoC/port a `sp=<kernel.port>:<TARGET>`
  maps to. All HBM/MEM lines deleted; DDR/VIRT/HOST kept.
- **`slash.tcl`** — started from V80's template; stripped every HBM (64 `HBM_AXI`, 8 `hbm_vnoc`)
  and DCMAC block with a Python pass, fixed the DDR apertures, and renamed the clock/reset
  boundary to felix names. It stays a **Jinja2 template**: the `{% ... %}` scaffolding renders
  per-kernel at link time; you author it once per platform.
- **`system_map.xml`** — reused as-is; `<Platform>Hardware</Platform>` and
  `<ClockFrequency>` come from context.
- **`slash_base.bd`** — generated by `gen_slash_base.tcl`, which sources the authored
  `slash_base.tcl` recipe. The recipe mirrors `dfx_build/scripts/20_slash.tcl` (same boundary the
  abstract shell is cut from) but under the BD name `slash_base`.
- **`abs_shell_slash.dcp`** — cut from the felix static impl:
  `write_abstract_shell -cell felix_cips_i/slash` inside `run_impl.tcl`, then copied to
  `resources/abstract_shell/`. It and `slash_base.bd` are generated from the **same** felix design
  so the partition boundary matches exactly.
- **`base/iprepo/`** — the felix custom IP (`hw_discovery`, `uuid_rom`, `cmd_queue`,
  `axi4_full_passthrough`, `hbm_bandwidth` self-test kernel), copied in.

---

## 4. Bugs found & fixed (all surfaced by the end-to-end run)

A render-only dry run passes all of these — they only appear when Vivado/Python actually execute.

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `slash.tcl` clock/reset refer to `user_clk`/`arstn` that don't exist on the felix boundary | template used V80 boundary names | renamed to `slash_clk`/`slash_resetn` in `slash.tcl` |
| 2 | `ERROR [BD 41-701] connect_bd_net requires at least two pins` on `axi_register_slice_virtterm_0/aclk` … `user_clk` | `terminator_ctx.py` (+`hbm_ctx.py`) **hardcode** `"user_clk"` in the emit context, overriding the template default | `"user_clk"`→`"slash_clk"` (3 sites) |
| 3 | `KeyError: 'top_wrapper'` in `generate_util_report`, *after* the partial PDI was already written | `report_util.py` hardcodes `nodes["top_wrapper"]`; felix top is `felix_cips_wrapper` | platform-aware top-node lookup |
| 4 | `[Mig 66-441]` DDR pin-triplet (earlier, hardware phase) | rank1/config14 controller vs rank2 pinout | `MC_RANK 2` at creation (see dfx_build) |

Lesson: the two `user_clk` hardcodes in the Python emit code (bug #2) were **not** reachable by
editing the `.tcl` template — the context value overrides the template's `default('slash_clk')`.
Grep the Python `src/emit/` tree for any boundary pin name you rename, not just the templates.

---

## 5. Step-by-step: link an HLS kernel onto felix

### Prerequisites (one-time, already done in this repo)

```bash
source /tools/Xilinx/2025.1/Vitis/settings64.sh      # Vivado + Vitis 2025.1 on PATH
cd porting_slash/slash_felix
```

1. **Generate `slash_base.bd`** (once per platform):
   ```bash
   cd linker && vivado -mode batch -source gen_slash_base.tcl && cd ..
   # → resources/abstract_shell/slash_base/slash_base.bd
   ```
2. **Build the static region + abstract shell** (once per platform; ~1 h):
   ```bash
   vivado -mode batch -source dfx_build/scripts/run_all.tcl      # build the project (if not built)
   vivado -mode batch -source dfx_build/scripts/run_impl.tcl     # synth+impl+abstract shell+XSA
   cp dfx_build/proj/felix_slash.runs/impl_1/abs_shell_slash.dcp \
      linker/resources/abstract_shell/abs_shell_slash.dcp
   ```

### Per-kernel flow

3. **Write the kernel** (HLS C++) and its `.cfg`. The `.cfg` must target felix:
   ```ini
   part=xcvp1552-vsva3340-2MHP-e-S
   [hls]
   flow_target=vivado
   syn.top=<top_fn>
   syn.file=<file>.cpp
   clock=4ns
   package.output.format=ip_catalog
   package.output.syn=false
   ```
4. **Write the connectivity `config.cfg`.** Targets come from `bd_ports.txt` — felix has
   **DDR0-3, VIRT0-3, HOST** (NO HBM/MEM):
   ```ini
   [connectivity]
   nk=<kernel>:<count>:<inst>            # instantiate kernels
   stream_connect=A_0.axis_out:B_0.axis_in   # kernel↔kernel AXIS (optional)
   sp=<inst>.m_axi_gmem0:DDR0            # map an AXI-MM port to a memory target
   ```
5. **Synthesize the kernels to IP** (`component.xml`):
   ```bash
   cd examples
   ./build_hls.sh <example_dir> <kernel1> <kernel2> ...
   # e.g. ./build_hls.sh 00_axilite increment accumulate
   # → <example>/hls/build_<k>.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml
   cd ..
   ```
6. **Link** → partial PDI + `.vbin`:
   ```bash
   ROOT=$(pwd)
   V80PP_RESOURCE_DIR=$ROOT/linker/resources \
   python3 linker/src/main.py link \
     -c $ROOT/examples/00_axilite/config.cfg \
     -p hw \
     -o $ROOT/examples/00_axilite/axilite_hw.vbin \
     -k <path>/increment/.../component.xml <path>/accumulate/.../component.xml \
     --vivado "$(which vivado)"
   ```
   (Or use CMake: `cmake -DSLASH_USE_REPO=ON -B build && cmake --build build --target axilite_hw`.)

### Success looks like

```
write_device_image -cell felix_cips_i/slash completed successfully
vbin archive complete: .../axilite_hw.vbin
```
The `.vbin` is a gzip tar containing `images/top_i_slash_slash_<proj>_inst_0_partial.pdi`,
`report_utilization_<proj>.xml`, `system_map.xml`.  Inspect with `tar tzf <name>.vbin`.

### Verify a link (what "correct" output shows)

Look inside `<out>.vbin.prj/slash.tcl` (the rendered per-kernel BD script):
- kernels wired to the right NoC: `<inst>/m_axi_gmem0` → `/ddr_noc_<i>/S00_AXI` for `DDRi`;
- `stream_connect` → `<A>/axis_out` → `<B>/axis_in`;
- AXI-Lite control assigned from base `0x0202_0000_0000`;
- **zero** `user_clk` / `hbm_vnoc` / `HBM_AXI` / `dcmac` references;
- unused DDR/VIRT/HOST NoC sinks terminated (`axi_register_slice_*term_*`), clocked by `slash_clk`.

### Common errors → fixes

| Error | Fix |
|---|---|
| `sp=...:HBM*` / `:MEM` not found | felix has no HBM/MEM — retarget to `DDR0-3`/`VIRT0-3` |
| `connect_bd_net requires at least two pins` on `user_clk` | a boundary pin got renamed but a Python emit context still hardcodes the old name — grep `src/emit/` |
| `KeyError` in `generate_util_report` | a hardcoded top/cell name; the partial PDI is already written, only the metadata step failed |
| boundary / partition-pin mismatch at `write_device_image` | `slash_base.bd`, `abs_shell_slash.dcp`, and `slash.tcl` disagree — regenerate `slash_base.bd` + abstract shell from the *same* design |

---

## 6. Verified results (2026-07-20, Vivado/Vitis 2025.1)

| Example | Kernels → memory | Output |
|---|---|---|
| `00_axilite` | `increment`→DDR0, `accumulate` (AXIS) | `axilite_hw.vbin` 949 KB, partial PDI 3.9 MB |
| `01_aximm` | `offset`→DDR0, `dma`→DDR1 | `aximm_hw.vbin` 952 KB, partial PDI 3.96 MB |

RM build ≈ 12 min each; both `LINK_EXIT=0`. The terminator logic correctly terminates only the
*unused* DDR channels (00_axilite: DDR1-3; 01_aximm: DDR2-3).
