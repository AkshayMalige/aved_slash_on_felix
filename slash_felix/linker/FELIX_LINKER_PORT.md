# FELIX v80++ linker port

Port of the SLASH `v80++` DFX linker resources from the Alveo V80 (HBM) to the
FELIX FLX-155 (`xcvp1552-vsva3340-2MHP-e-S`, 1 DDR channel, no HBM / no DCMAC).
Goal: link an HLS kernel (`examples/00_axilite`, `examples/01_aximm`) into the
felix `slash` reconfigurable partition and emit a partial PDI / vbin.

## What the linker consumes (slash link path)

`resources/abstract_shell/abs_shell_slash.dcp` + `.../slash_base/slash_base.bd`,
`resources/base/iprepo`, `resources/bd_ports.txt`, `resources/slash.tcl`
(Jinja template), `resources/system_map.xml` (Jinja template), and
`resources/base/scripts/slash_project_build.tcl` (the link engine).

## Files authored for felix (done)

| file | change |
|---|---|
| `resources/bd_ports.txt` | DDR0-3→M00-03_INI, VIRT0-3→SL_VIRT_00-03, HOST→QDMA_SLAVE_BRIDGE_0; all HBM/MEM lines removed. `clock:aclk1` / `reset:ap_rst_n` kept (same as V80). |
| `resources/slash.tcl` | HBM/DCMAC stripped (1336→623 lines). DDR apertures `{0x0 2G}{0x600_0000_0000 32G}`. Clock/reset boundary renamed `user_clk`→`slash_clk`, `arstn`→`slash_resetn` to match the felix partition boundary. |
| `resources/system_map.xml` | unchanged — card-agnostic; ethernet auto-disables with no network config. |
| `resources/base/scripts/slash_project_build.tcl` | `-part`→vp1552, `top`→`felix_cips_wrapper`, RP cell `top_i/slash`→`felix_cips_i/slash`. |
| `resources/base/scripts/slash_base.tcl` | replaced the 4016-line V80 recipe with a clean felix recipe: builds the `slash_base` boundary (S_AXILITE_INI, M00-03_INI, SL_VIRT_00-03, QDMA_SLAVE_BRIDGE_0, slash_clk, slash_resetn) + a self-test interior (wiped at link time). |
| `resources/base/iprepo` | felix custom IP incl. `hbm_bandwidth` (used as the self-test kernel). |
| `src/emit/hw/tcl_gen.py` | `num_mem`→0 (no hbm_vnoc terminators/smartconnect), `dcmac_rx_tready_tie_slots`→[] (no DCMAC cells). DDR (num_ddr=4) / VIRT (num_virt=4) / HOST unchanged. |
| `src/emit/hw/user_region/terminator_ctx.py`, `hbm_ctx.py` | hardcoded `"user_clk"`→`"slash_clk"` (3 sites). These set the terminator/HBM clock in the emit context, overriding the template default — the template-level rename alone did NOT reach them. |
| `src/emit/metadata/report_util.py` | `nodes["top_wrapper"]`→ platform-aware lookup (`felix_cips_wrapper`, fall back to `top_wrapper` / the `(top)`-flagged row). Post-P&R util-report step; failed with `KeyError: 'top_wrapper'` on felix. |
| `gen_slash_base.tcl` | standalone generator: builds `slash_base.bd` and exports it to `resources/abstract_shell/slash_base/`. |
| `../examples/{00_axilite,01_aximm}` | retargeted: HBM→DDR (`increment→DDR0`, `dma→DDR1`, `offset→DDR0`); HLS `part`→vp1552. |
| `../dfx_build/scripts/run_impl.tcl` | now also emits `felix_slash.xsa` (write_hw_platform) + `felix_cips_wrapper_routed_bb.dcp` (black-boxed static) alongside the abstract shells + base PDI. |

## Boundary consistency (the load-bearing invariant)

The **same boundary** must appear in three places, or the link fails:
`abs_shell_slash.dcp` partition pins == `slash_base.bd` ports == every port ref
in `slash.tcl`. All three now use: `S_AXILITE_INI`, `M00_INI..M03_INI`,
`SL_VIRT_00..03`, `QDMA_SLAVE_BRIDGE_0`, `slash_clk`, `slash_resetn`.
`slash.tcl` wipes the interior (`delete_bd_objs [get_bd_cells]`) and rebuilds it,
so only the boundary of `slash_base.bd` matters.

## VERIFIED end-to-end (Vivado/Vitis 2025.1, 2026-07-20)

Ran the whole pipeline: `gen_slash_base.tcl` → `slash_base.bd` (validates); HLS-synth
`increment`/`accumulate` (+ `dma`/`offset`) for vp1552 (clean); dfx_build `run_impl.tcl`
→ `abs_shell_slash.dcp` + base PDI + XSA + routed_bb (+ a self-test slash partial PDI,
proving the DFX partition); `v80++ link -c examples/00_axilite -p hw` →
**`write_device_image -cell felix_cips_i/slash` produced
`images/top_i_slash_slash_axilite_hw_inst_0_partial.pdi` (~3.9 MB)** and the `.vbin`
tarball (slash partial PDI + util XML + system_map.xml). The two hardcoded-`user_clk`
and `top_wrapper` bugs above were found and fixed during this run.

## Remaining run steps (need Vivado 2025.1 / Vitis HLS — not yet run)

1. **slash_base.bd** — `cd linker && vivado -mode batch -source gen_slash_base.tcl`
   → produces `resources/abstract_shell/slash_base/slash_base.bd`.
2. **abstract shell + base PDI + XSA** — build the dfx_build project then
   `vivado -mode batch -source ../dfx_build/scripts/run_impl.tcl` (hours).
   Copy `impl_1/abs_shell_slash.dcp` → `resources/abstract_shell/abs_shell_slash.dcp`.
3. **link** — HLS-synth the example kernels, then
   `V80PP_RESOURCE_DIR=$PWD/resources python3 src/main.py link -p hw -c ../examples/00_axilite/config.cfg ...`
   → renders `slash.tcl`/`system_map.xml`, imports `slash_base.bd`, places the RM
   against `abs_shell_slash.dcp`, `write_device_image -cell felix_cips_i/slash`
   → partial PDI. A clean partial PDI = resources are internally consistent.
   Repeat with `01_aximm`.
