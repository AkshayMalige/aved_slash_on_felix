# FELIX SLASH — full DFX design (static_region + slash + service_layer)

Faithful port of the V80 SLASH shell to FELIX (xcvp1552), preserving the
SLASH architecture: `slash` and `service_layer` are **DFX Block Design
Containers** wired to the preserved `static_region`. HBM, DCMAC, SMBus removed;
one DDR4 channel.

## Build
```
cd dfx_build
vivado -mode batch -source run_all.tcl
```
Produces project `dfx_build/proj/felix_slash.xpr`, BD `felix_cips`, containing:
- `static_region` (unchanged from the proven baseline; virt_noc intact)
- `slash`  — DFX BDC: S_AXILITE_INI(0x202)->smartconnect->4 ddr_bandwidth
  kernels->M00..M03_INI->DDR; 5 traffic_virt->SL_VIRT/QDMA. No HBM.
- `service_layer` — DFX BDC: 8 eth kernels->sl2noc_0..7->DDR (S_AXILITE_INI
  @0x203 control); 4 VIRT + 1 QDMA passthrough chains. No DCMAC/QSFP.
Both containers `ENABLE_DFX=true` + `LOCK_PROPAGATE=true`.
`validate_bd_design` passes with **0 errors**.

## Files (run in this order; run_all.tcl does it for you)
- `00_felix_cips_static_region.tcl` — clean static_region (write_bd_tcl export)
- `10_service_layer.tcl` — service_layer BD design
- `20_slash.tcl` — slash BD design
- `30_integrate.tcl` — instantiate BDCs, wire to static_region, address, DFX, export

## Verified address map (assign_bd_address, host/PCIe view)
- hw_discovery/mgmt @ 0x201_0100_0000 (matches V80)
- kernel control    @ 0x202_0000_0000 (slash S_AXILITE_INI)
- service control   @ 0x203_0000_0000 (service_layer S_AXILITE_INI)
- DDR: low 2G @ 0x0, high 14G @ 0x580_0000_0000 (16GB DIMM)

## Self-test kernels
The `hbm_bandwidth`/`traffic_producer` HLS IPs (generic AXI bandwidth counters,
work on DDR — from /usr/share/v80++, copied into ../iprepo) stand in as
placeholder kernels so the design is standalone-verifiable. `v80++ link`
replaces them with real user kernels at link time.

## Notes / next steps
- Requires `../iprepo` (includes hbm_bandwidth, added for this build).
- Expected non-error criticals: none blocking. DDR "shared segments" INFO msgs
  are advisory. Reset-domain of the service passthrough chain is a minor timing
  advisory (uses aved reset, not the dedicated service reset) — optional fix.
- Next: pin constraints (DDR + PCIe), synth/impl, PDI; then pblocks + abstract
  shell for the DFX partitions.
