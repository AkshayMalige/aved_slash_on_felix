# FELIX SLASH — Full Deployment Runbook (from scratch)

The one detailed procedure: **remove old drivers → build hardware → firmware →
software/drivers → install → build the example kernel → program the FLX-155 →
run the design from the host.** Follow top to bottom.

This repo is self-contained — everything builds locally, no external tree. For
*what each piece is* see `CONCEPTS.md`; `FELIX_SLASH_PLAN.md` is the short version.

> ⚠️ Read before starting
> - Run **every command from the repo root** (this directory).
> - Source the toolchain first: `source /tools/Xilinx/2025.1/Vitis/settings64.sh`
>   (gives `vivado`, `v++`, `bootgen`, `sdtgen`, `empyro`).
> - Parts 0–5 are build/host — no card needed. Parts 6–9 need the **powered
>   FLX-155** with **JTAG** access.
> - Shortcut: `./build_all.sh {hw|fw|sw|all}` runs Parts 1–3. The detailed steps
>   below are exactly what it does, so you can run/debug them individually.

```bash
source /tools/Xilinx/2025.1/Vitis/settings64.sh
cd <this repo>                       # everything is relative to here
```

---

## Part 0 — Remove OLD installed drivers (do this fully, once)

A machine that previously ran V80/AVED has `ami`+`slash` installed via **DKMS + .deb**;
they auto-load via `modprobe` and will shadow your freshly built modules. Remove them.

```bash
# 0.1 stop the daemon + unload any loaded modules (ignore "not loaded" errors)
sudo systemctl stop vrtd 2>/dev/null || true
sudo rmmod ami   2>/dev/null || true
sudo rmmod slash 2>/dev/null || true

# 0.2 purge the packages. Errors are NOT suppressed here so you see failures.
#     apt continues past names that "are not installed" -- that's harmless.
sudo apt-get remove --purge -y \
    ami slash-dkms libslash libslash-dev libvrt libvrt-dev libvrtd libvrtd-dev vrtd

# IMPORTANT: 'v80++' must be purged with dpkg, NOT apt. On the apt command line a
# trailing '+' is an action modifier, so apt misreads 'v80++' as package 'v80',
# fails to find it, and ABORTS the whole remove without touching anything.
sudo dpkg --purge v80++ 2>/dev/null || true
# these may already be gone (amd-vrt often 'rc'); ignore "not installed":
sudo dpkg --purge v80-smi amd-vrt slash-dev 2>/dev/null || true
sudo apt-get autoremove --purge -y

# 0.3 force-remove any DKMS leftovers for ALL kernels
for m in ami/2.4.0 slash/0.1; do sudo dkms remove "$m" --all 2>/dev/null || true; done
sudo depmod -a
```

**If `ami` fails to purge** with `ami.prerm … rmmod … Killed … exit status 137`:
its removal script tries to `rmmod ami`, but the old loaded `ami` module is
wedged (it waits on a card that isn't there), so `rmmod` gets killed and dpkg
aborts. Everything else removes fine; only `ami` is stuck. Fix it:
```bash
lsmod | grep ami                              # still loaded?
sudo rmmod ami                                # try to unload; Ctrl-C if it hangs
sudo rm -f /var/lib/dpkg/info/ami.prerm       # neutralize the failing rmmod step
sudo dpkg --purge --force-all ami             # complete the purge (+ DKMS via postrm)
# if rmmod above hung/failed, REBOOT now to clear the wedged module -- it will
# not reload (the DKMS package is gone). Then re-run the verify below.
```

**Verify clean — all four must be empty** (`node-slash` is an unrelated Node.js
package — ignore it):
```bash
dpkg -l | grep -iE '\bami\b|slash|libvrt|vrtd' | grep '^ii' | grep -v node-slash
dkms status | grep -iE 'ami|slash'
lsmod | grep -iE 'ami|slash|qdma'
find /lib/modules/$(uname -r) -name 'ami.ko*' -o -name 'slash.ko*'
```
If anything prints (other than `node-slash`), resolve it before continuing — e.g.
purge it directly with `sudo dpkg --purge <name>`.

---

## Part 1 — Build the hardware  (`./build_all.sh hw`, ~1 h)

Produces the base image, XSA, and the abstract shell the linker needs.
```bash
( cd iprepo/hbm_bandwidth && make )                            # HLS iprepo IP (else BD errors)
vivado -mode batch -source dfx_build/scripts/run_all.tcl        # build the DFX project
vivado -mode batch -source dfx_build/scripts/run_impl.tcl       # synth+impl -> PDI, XSA, abs shell
./scripts/stage_artifacts.sh                                    # place dcp/pdi/xsa (see below)
( cd linker/resources/base/iprepo/hbm_bandwidth && make )       # linker self-test IP
( cd linker/resources/base/iprepo/traffic_producer && make )       # linker self-test IP
( cd linker && vivado -mode batch -source gen_slash_base.tcl )  # -> slash_base.bd
```
`stage_artifacts.sh` copies from `dfx_build/proj/.../impl_1/`:
`abs_shell_slash.dcp` → `linker/resources/abstract_shell/`; `felix_slash.xsa` +
`felix_cips_wrapper.pdi` → `dfx_build/artifacts/`.
**Check:** `ls dfx_build/artifacts/felix_slash.xsa linker/resources/abstract_shell/abs_shell_slash.dcp`

---

## Part 2 — Build the firmware  (`./build_all.sh fw`, ~10 min)

AMC firmware for the RPU + the base image that boots it.
```bash
AMC=linker/resources/submodules/AVED/fw/AMC
( cd $AMC/scripts && ./build_bsp.sh -xsa "$(pwd)/dfx_build/artifacts/felix_slash.xsa" -os freertos )
( cd $AMC && ./scripts/build.sh -amc -profile felix -os freertos )     # -> $AMC/build/amc.elf
( cd dfx_build/amc_pdi && ./combine_amc_pdi.sh )                        # -> build/felix_slash_amc.pdi
```
**Check:** `ls dfx_build/amc_pdi/build/felix_slash_amc.pdi`
(For a kernel-swap-only demo without firmware, skip Part 2 and use
`dfx_build/artifacts/felix_cips_wrapper.pdi` in Part 6 — see CONCEPTS.md.)

---

## Part 3 — Build the software / drivers  (`./build_all.sh sw`, ~5 min)

```bash
( cd driver && make clean && make )                                              # slash.ko (PF1+PF2)
( cd linker/resources/submodules/AVED/sw/AMI/driver && make clean && make )       # ami.ko  (PF0)

# The host libs are a find_package() chain: libslash <- vrtd <- vrt <- smi.
# Nothing is installed yet (Part 0 purged the old .debs), so each build must be
# pointed at the build trees of the ones before it.
ROOT=$(pwd); PREFIX=""
for c in driver/libslash vrt/vrtd vrt smi; do
  ( cd $c && rm -rf build \
      && cmake -S . -B build -G Ninja -DCMAKE_PREFIX_PATH="$PREFIX" \
      && cmake --build build )
  PREFIX="${PREFIX:+$PREFIX;}$ROOT/$c/build"
done
```
> Dropping `-DCMAKE_PREFIX_PATH` gives
> `find_package … Could not find a package configuration file provided by "slash"`
> at `vrt/vrtd/CMakeLists.txt:52` — that means libslash isn't visible, not missing.
**Check:** `ls driver/slash.ko linker/resources/submodules/AVED/sw/AMI/driver/ami.ko`

---

## Part 4 — Install libraries + load the drivers

```bash
# 4.1 install the host libraries/daemon/CLI system-wide
for c in driver/libslash vrt/vrtd vrt smi; do ( cd $c && sudo cmake --install build ); done
sudo ldconfig

# 4.2 load the freshly built modules by explicit path — slash FIRST, then ami
sudo insmod driver/slash.ko
sudo insmod linker/resources/submodules/AVED/sw/AMI/driver/ami.ko
lsmod | grep -iE 'ami|slash|qdma'      # both present
dmesg | tail -40                       # probe + VSEC logs, no errors
```
> `ami` matches any Xilinx function and keeps only the one with the hw_discovery
> VSEC (**PF0** on felix). Loading `slash` first lets it claim PF1/PF2; `ami` then
> binds PF0 and rejects the rest — confirm in `dmesg`.

*(This step needs the card present in Part 6 to be meaningful; you can build Parts
1–3 anytime, but only load drivers once the board is programmed and enumerated.)*

---

## Part 5 — Build the example kernel `00_axilite` → `.vbin`

```bash
( cd examples && ./build_hls.sh 00_axilite increment accumulate )     # HLS synth (vp1552)
HLS=$(pwd)/examples/00_axilite/hls
V80PP_RESOURCE_DIR=$(pwd)/linker/resources python3 linker/src/main.py link \
  -c examples/00_axilite/config.cfg -p hw \
  -o examples/00_axilite/axilite_hw.vbin \
  -k $HLS/build_increment.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
     $HLS/build_accumulate.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
  --vivado "$(which vivado)"
( cd examples/00_axilite && cmake -B build -S . -G Ninja -DSLASH_USE_REPO=ON && cmake --build build )
```
**Check:** `ls examples/00_axilite/axilite_hw.vbin examples/00_axilite/build/00_axilite`
(A `.vbin` is a gzip tar: `tar tzf examples/00_axilite/axilite_hw.vbin`.)

---

## Part 6 — Program the FLX-155 (JTAG)  ⚠️ needs the card

Program the base image (full stack = the AMC PDI). Requires JTAG access.
```bash
vivado -mode tcl
```
```tcl
open_hw_manager ; connect_hw_server ; open_hw_target

# NOTE: on Versal, program_hw_devices has NO -file option. Set PROGRAM.FILE as a
# property on the device first, then program. Use an ABSOLUTE path to the PDI.
get_hw_devices                                     ;# list the JTAG chain
current_hw_device [lindex [get_hw_devices] 0]      ;# or: [get_hw_devices xcvp1552*]
set_property PROGRAM.FILE {<ABS-PATH>/dfx_build/amc_pdi/build/felix_slash_amc.pdi} [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]
exit
```
Then let PCIe re-enumerate:
```bash
echo 1 | sudo tee /sys/bus/pci/rescan       # or reboot the host on first cold program
```
> The PLM configures the fabric + PS and hands the AMC off to the Cortex-R5.

---

## Part 7 — Verify enumeration

```bash
lspci -d 10ee: -nn                          # expect 50b4 (PF0), 50b5 (PF1), 50b6 (PF2)
lspci -s <BDF> -k | grep -i "in use"        # PF0 -> ami ; PF1/PF2 -> slash_*
# if drivers not yet loaded, do Part 4 now (card is up), then:
sudo vrtd &                                 # start the daemon (or: systemctl start vrtd)
v80-smi list                                # PF0/PF1/PF2/VRTD should all pass
dmesg | grep -iE 'slash|ami|qdma|vsec'      # binding + VSEC discovery
```
⚠️ First real check that the three PFs bind and the VSEC (uuid/gcq/gcq_payload) reads back.

---

## Part 8 — Run the design from the host

```bash
# get the PF2 (slash) BDF from lspci, then:
./examples/00_axilite/build/00_axilite <PF2-BDF> examples/00_axilite/axilite_hw.vbin
```
What happens: libvrt → `vrtd` → `design_writer` DMAs the partial PDI over QDMA to
`0x102100000` → the PMC partially reconfigures the `slash` partition → `clock.c`
sets the kernel clock (BAR4) → `reset.c` re-enumerates (SBR + hotplug) → the kernel
is live and the app reads/writes it over the BAR and DDR.
**Success:** the program prints matching `increment → accumulate` results. The card
blips out/in of PCIe once during the load — that's the swap, not a fault.

---

## Part 9 — (optional) Flash the base image to the card (permanent)  ⚠️ risky

Makes the card boot without JTAG. Needs `ami.ko` loaded and the AMC alive (Parts 4/6).
```bash
ami_tool overview                                       # AMI sees the device + logic UUID?
ami_tool cfgmem_fpt -d <PF0-BDF> -t primary -i dfx_build/amc_pdi/build/felix_slash_amc.pdi
ami_tool reload -d <PF0-BDF>                            # or power-cycle
```
> A bad/interrupted flash of the **primary** partition can brick the card (recover
> via JTAG). If a **secondary/golden** partition exists, flash `-t secondary` first
> and test it before primary. Never power-cycle mid-flash. Verify exact flag names
> with `ami_tool cfgmem_fpt -h`.

---

## Verification checklist (on the card)

- [ ] Part 0 clean: no old `ami`/`slash` in `dpkg`/`dkms`/`lsmod`.
- [ ] Parts 1–3: `felix_slash_amc.pdi`, `slash.ko`, `ami.ko`, host libs all built.
- [ ] `lspci` shows `50b4`/`50b5`/`50b6`, correct driver per PF.
- [ ] `v80-smi list` → PF0/PF1/PF2/VRTD pass.
- [ ] ⚠️ `QDMA_LOGIC_BASE 0x201_0002_0000` responds (the one unverified addr in
      `vrt/device.hpp`); if reads fail here, confirm the felix QDMA aperture + edit it.
- [ ] Part 8: `00_axilite` returns correct data.
- [ ] (full stack) `ami_tool overview` reads the logic UUID → AMI↔AMC mailbox alive.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `[BD 5-390] hbm_bandwidth not found` (Part 1) | run `( cd iprepo/hbm_bandwidth && make )` first |
| only 1–2 PFs in `lspci` | base image not programmed / needs host reboot after first program |
| `ami` bound to PF1/PF2 | load `slash.ko` before `ami.ko`; check `ami` rejected non-VSEC PFs in `dmesg` |
| `v80-smi list` VRTD fail | `vrtd` not running / socket perms — `sudo vrtd`, check `/run/vrtd` |
| kernel load hangs at reconfig | design_writer→`0x102100000`; check QDMA H2C queue + PLM log (JTAG/XSDB) |
| `ami_tool sensors` garbage | expected — AMC still has V80 `profile_sensors.h`/`profile_pdr.h`; retarget to FLX-155 |
| reset/reprogram fails (full stack) | AMC not alive on R5 — verify the AMC PDI booted (XSDB on R5), or use the SBR-only shortcut |

## Status
Build side (Parts 1–5) verified on the workstation. Parts 6–9 need the powered
FLX-155 — not yet run. Watch the two ⚠️ items (`QDMA_LOGIC_BASE`, AMI↔AMC) on first
hardware bring-up.
