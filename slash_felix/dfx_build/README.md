# FELIX SLASH — DFX design (static_region + slash + service_layer)

Faithful port of the V80 SLASH shell to FELIX (xcvp1552), preserving the SLASH
architecture: `slash` and `service_layer` are **DFX Block Design Containers**
wired to the preserved `static_region`. No HBM/DCMAC/SMBus; one 2-rank DDR4
channel (32 GB, config17). Fully scripted — no manual GUI steps.

## Build the project

```
cd dfx_build
vivado -mode batch -source scripts/run_all.tcl
```

Builds `proj/felix_slash.xpr`: block design `felix_cips`, top wrapper
`felix_cips_wrapper` (generated automatically), constraints attached, and the
DFX configuration `config_1` set up. Ready to implement — no "Create HDL
Wrapper", no DFX Wizard.

## Run implementation (synth → impl → Versal device image)

```
cd dfx_build
vivado -mode batch -source scripts/run_impl.tcl
```

Produces the device image (`.pdi`) and per-partition abstract shells in
`proj/felix_slash.runs/impl_1/`.

## Layout

```
scripts/       00..30 (build the 3 BDs) + make_wrapper + build_project + run_all + run_impl
constraints/   felix_slash_pinout.xdc (DDR + PCIe), felix_pblock.xdc (DFX floorplan)
../iprepo      custom IP (hw_discovery, uuid_rom, cmd_queue, hbm_bandwidth, ...)
../proj        generated output (git-ignored)
```

## Notes

- `run_all.tcl` builds the project only; to go all the way to a device image in
  one command, uncomment the STAGE blocks at the bottom of `run_all.tcl`.
- `run_impl.tcl` runs the downstream flow on the already-built project (no BD
  rebuild) — comment a stage there to run only synthesis, etc.
- The self-test kernels (`hbm_bandwidth` etc.) are placeholders; `v80++ link`
  swaps in real user kernels via the abstract shells.
