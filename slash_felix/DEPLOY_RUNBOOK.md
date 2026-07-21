# FELIX SLASH — Deployment Runbook (on-card bring-up)

How to bring the SLASH stack up on a **powered FLX-155** card: program the base
image, load the drivers, start `vrtd`, run a kernel, and (optionally) bring up
AMI/AMC. Assumes the **build** side is done — see `BUILD_RUNBOOK.md` (hardware +
linker) and the AMC/AMI build steps recorded below.

Target: FELIX FLX-155 (`xcvp1552-vsva3340-2MHP-e-S`), Vivado/Vitis **2025.1**.
`SLASH/` = `~/VersalPrjs/felix/felix-xpfm-pcie/SLASH`.
Device identity: **PF0 `ami` `10ee:50b4`**, **PF1 `qdma` `10ee:50b5`**, **PF2 `slash` `10ee:50b6`**.

> Nothing here has been run on real hardware yet — this is the intended
> procedure. Items that can only be confirmed on the card are marked ⚠️.

---

## Phase 0 — Artifacts you need

| Artifact | Path | Made by |
|---|---|---|
| Base PDI **with AMC** (full stack) | `dfx_build/amc_pdi/build/felix_slash_amc.pdi` | `combine_amc_pdi.sh` |
| Base PDI **without AMC** (kernel-swap only) | `dfx_build/proj/felix_slash.runs/impl_1/felix_cips_wrapper.pdi` | `run_impl.tcl` |
| slash driver (+qdma) | `SLASH/driver/slash.ko` | `cd SLASH/driver && make` |
| AMI driver | `SLASH/linker/resources/submodules/AVED/sw/AMI/driver/ami.ko` | `cd …/AMI/driver && make` |
| Kernel `.vbin` | `examples/00_axilite/axilite_hw.vbin` | `v80++ link` (BUILD_RUNBOOK B) |

Plus: **JTAG access** to the card (onboard USB-JTAG or a cable) for programming.

---

## Phase 1 — Program the base image (JTAG)

Choose ONE base PDI (full-stack vs kernel-swap-only, see Phase 5 shortcut).

```bash
source /tools/Xilinx/2025.1/Vitis/settings64.sh
vivado -mode tcl
```
```tcl
open_hw_manager ; connect_hw_server ; open_hw_target
# full stack (boots the AMC on the R5):
program_hw_devices -file dfx_build/amc_pdi/build/felix_slash_amc.pdi [current_hw_device]
refresh_hw_device [current_hw_device]
```
The PLM configures PL + PS and (for the AMC PDI) hands off the AMC to Cortex-R5-0.
**Then reboot the host or rescan PCIe** so the endpoint enumerates:
```bash
# if the card was cold: a host reboot is the reliable path on first program.
# otherwise force a rescan:
echo 1 | sudo tee /sys/bus/pci/rescan
```

---

## Phase 2 — Build + install the host stack

Install in dependency order (from `SLASH/`):
```bash
cd SLASH
# slash driver (binds PF1 qdma + PF2 slash)
cd driver && make && sudo insmod slash.ko && cd ..
# host libraries + daemon
cd driver/libslash && cmake -S . -B build -G Ninja && cmake --build build && sudo cmake --install build && cd ../..
cd vrt/vrtd     && cmake -S . -B build -G Ninja && cmake --build build && sudo cmake --install build && cd ../..
cd vrt          && cmake -S . -B build -G Ninja && cmake --build build && sudo cmake --install build && cd ..
cd smi          && cmake -S . -B build -G Ninja && cmake --build build && sudo cmake --install build && cd ..
# AMI driver (binds PF0 via VSEC) — only needed for the full AMI/AMC path
cd linker/resources/submodules/AVED/sw/AMI/driver && make && sudo insmod ami.ko && cd -
```

**Driver coexistence note:** `ami.ko` matches `PCI_DEVICE(0x10ee, PCI_ANY_ID)` and
accepts a function only if it exposes the hw_discovery **VSEC** (PF0 only on felix).
`slash.ko` binds the exact IDs `50b5`/`50b6`. To avoid any race, a safe load order is
**`slash.ko` first, then `ami.ko`**. If `ami` grabs PF1/PF2, its probe should reject
them (no VSEC) and release — verify with `dmesg`.

---

## Phase 3 — Verify enumeration

```bash
lspci -d 10ee: -nn            # expect three functions: 50b4 (PF0), 50b5 (PF1), 50b6 (PF2)
lspci -s <BDF> -vvv | grep -i "Kernel driver in use"   # PF0->ami, PF1/PF2->slash_*
v80-smi list                  # SLASH readiness: PF0, PF1, PF2, VRTD should all pass
dmesg | grep -iE "slash|ami|qdma|vsec"                 # binding + VSEC discovery logs
```
⚠️ First real check that PF0/1/2 bind and the VSEC (uuid/gcq/gcq_payload) reads back.

---

## Phase 4 — Start vrtd and run a kernel

```bash
sudo vrtd                            # or: sudo systemctl enable --now vrtd
# get the PF2 (slash) BDF from lspci, then run the example:
cd examples/00_axilite
./build/00_axilite <PF2-BDF> axilite_hw.vbin
```
What happens: libvrt → `vrtd` → `design_writer` DMAs the partial PDI over **QDMA**
(H2C) to **`0x102100000`** → PMC PLM does partial reconfiguration of the `slash`
partition → driver does SBR + hotplug re-enum → the kernel is live and the app
reads/writes it over the BAR (AXI-Lite `0x0202_…`) and DDR (`0x600_…`).

Success = the example prints matching results (increment→accumulate over DDR0).

---

## Phase 5 — AMI / AMC bring-up (full stack only)

Needed for management, sensors, and vrtd's AMI-based reset path.
```bash
# ami.ko already loaded in Phase 2. Then the AMI CLI (built from AVED/sw/AMI/app):
ami_tool overview            # lists the device, logic UUID (from the VSEC)
ami_tool sensors             # ⚠️ will report V80 sensors until PDR/sensors retargeted
```
The host↔AMC path: AMI (PF0) ↔ GCQ mailbox (`0x201_0101_0000`) ↔ AMC on R5
(LPD `0x8000_0000`) with a 128M DDR payload buffer (`0x201_0800_0000`→DDR `0x3800_0000`).

---

## Kernel-swap-only shortcut (no AMI, no AMC)

To demo a kernel swap **without** building/deploying AMC or AMI:
1. Program `felix_cips_wrapper.pdi` (the no-AMC base) in Phase 1.
2. Skip `ami.ko` in Phase 2.
3. In `vrt/vrtd/src/reset.c`, bypass the `AMI_IOC_DEVICE_BOOT` call so the reset
   uses **SBR + hotplug only** (`slash_hotplug_*`, GPIO `0x1040000`) — these live in
   the slash driver, not AMI. Rebuild vrtd.
4. Phases 3–4 as normal. Kernel swap works with zero firmware.

---

## On-card verification checklist (the still-open items)

- [ ] `lspci` shows `50b4`/`50b5`/`50b6`; correct `Kernel driver in use` per PF.
- [ ] `v80-smi list` → PF0/PF1/PF2/VRTD all pass.
- [ ] ⚠️ **`QDMA_LOGIC_BASE 0x201_0002_0000`** responds (the one unverified hardcoded
      addr in `vrt/device.hpp`). If `v80-smi`/reads fail here, confirm the felix QDMA
      logic aperture and edit that constant.
- [ ] Kernel `.vbin` loads and the example returns correct data (DFX-from-host path).
- [ ] (full stack) `ami_tool overview` reads the logic UUID → AMI↔AMC mailbox alive.
- [ ] (full stack) vrtd AMI reset path completes a reprogram cycle.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Only 1–2 PFs in `lspci` | base PDI not programmed / needs host reboot after first program |
| `ami` bound to PF1/PF2 | load `slash.ko` before `ami.ko`; check `ami` probe rejected non-VSEC PFs in `dmesg` |
| `v80-smi list` VRTD fail | `vrtd` not running / socket perms — `sudo vrtd`, check `/run/vrtd` |
| kernel load hangs at reconfig | design_writer→`0x102100000` path; check QDMA H2C queue + PLM log (JTAG/XSDB) |
| `ami_tool sensors` garbage | expected — AMC still has V80 `profile_sensors.h`/`profile_pdr.h`; retarget to FLX-155 |
| reset/reprogram fails (full stack) | AMC not alive on R5 — verify the AMC PDI booted (XSDB on R5), or use SBR-only shortcut |
