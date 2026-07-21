# FELIX SLASH — Drivers: clean build, install, uninstall, test & flash

A careful, ordered procedure to: remove any **old** SLASH/AMI drivers, do a
**clean from-source build**, load them, **test `00_axilite`** on the board, and
**flash** the base design into the card's flash. Read `DEPLOY_RUNBOOK.md` for the
on-card programming/enumeration detail and `CONCEPTS.md` for what each piece is.

> ⚠️ **Read this first.**
> - The SLASH/AMI **drivers are unchanged for felix** (same device IDs 50b4/5/6).
>   This clean rebuild is about a single, consistent, source-matched install — not
>   fixing a felix incompatibility.
> - This machine already has **old drivers installed via DKMS + .deb**
>   (`ami`, `slash-dkms`, `libslash*`, `libvrt*`, `libvrtd*`). They auto-load via
>   `modprobe`. **You must remove them before a from-source install**, or you may
>   end up running the DKMS copy instead of your freshly built one.
> - **Flashing requires a card that is already up** (booted via JTAG) with a live
>   AMI/AMC. You cannot flash a bare card — JTAG-boot it first.

`SLASH=~/VersalPrjs/felix/felix-xpfm-pcie/SLASH` ;
`FELIX=~/VersalPrjs/felix/felix-xpfm-pcie/porting_slash/slash_felix`

---

## Part 0 — Survey what's currently installed

```bash
dpkg -l | grep -iE '\bami\b|slash|libvrt|vrtd|amd-vrt'     # installed .deb packages
dkms status | grep -iE 'ami|slash'                          # DKMS-managed modules
lsmod | grep -iE 'ami|slash|qdma'                           # currently loaded modules
ls /lib/modules/$(uname -r)/updates/dkms/ | grep -iE 'ami|slash'
```
On this machine you will see `ami/2.4.0` and `slash/0.1` in DKMS (for two kernels),
and `ami`, `slash-dkms`, `libslash(-dev)`, `libvrt(-dev)`, `libvrtd(-dev)` in dpkg.

---

## Part 1 — Remove the OLD drivers (careful, do this fully)

```bash
# 1. stop the daemon and unload any loaded modules (ignore "not loaded" errors)
sudo systemctl stop vrtd 2>/dev/null || true
sudo rmmod ami   2>/dev/null || true
sudo rmmod slash 2>/dev/null || true    # slash bundles qdma; one module

# 2. purge the .deb packages (this also triggers DKMS removal for slash/ami)
sudo apt-get remove --purge -y \
    ami slash-dkms slash-dev \
    libslash libslash-dev libvrt libvrt-dev libvrtd libvrtd-dev \
    vrtd v80-smi v80++ amd-vrt 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

# 3. belt-and-suspenders: force-remove any DKMS leftovers for ALL kernels
for m in ami/2.4.0 slash/0.1; do sudo dkms remove "$m" --all 2>/dev/null || true; done

# 4. refresh module DB
sudo depmod -a
```

**Verify it's clean (all four should be empty):**
```bash
dpkg -l | grep -iE '\bami\b|slash|libvrt|vrtd' | grep '^ii'
dkms status | grep -iE 'ami|slash'
lsmod | grep -iE 'ami|slash|qdma'
find /lib/modules/$(uname -r) -name 'ami.ko*' -o -name 'slash.ko*'
```
If anything remains, stop and resolve it before continuing.

---

## Part 2 — Clean build from source

```bash
source /tools/Xilinx/2025.1/Vitis/settings64.sh
cd $SLASH

# slash driver (binds PF1 qdma + PF2 slash) -> slash.ko
cd driver && make clean && make && cd ..

# AMI driver (binds PF0 via VSEC) -> ami.ko
cd linker/resources/submodules/AVED/sw/AMI/driver && make clean && make && cd -

# host libraries + daemon + CLI (fresh build dirs)
cd driver/libslash && rm -rf build && cmake -S . -B build -G Ninja && cmake --build build && cd ../..
cd vrt/vrtd        && rm -rf build && cmake -S . -B build -G Ninja && cmake --build build && cd ../..
cd vrt             && rm -rf build && cmake -S . -B build -G Ninja && cmake --build build && cd ..
cd smi             && rm -rf build && cmake -S . -B build -G Ninja && cmake --build build && cd ..
```
Confirm the two modules exist:
```bash
ls -la $SLASH/driver/slash.ko
ls -la $SLASH/linker/resources/submodules/AVED/sw/AMI/driver/ami.ko
```

---

## Part 3 — Install the host libraries + load the drivers

Install the userspace pieces (libraries/daemon/CLI) system-wide:
```bash
cd $SLASH/driver/libslash && sudo cmake --install build && cd ../..
cd $SLASH/vrt/vrtd        && sudo cmake --install build && cd ../..
cd $SLASH/vrt             && sudo cmake --install build && cd ..
cd $SLASH/smi             && sudo cmake --install build && cd ..
sudo ldconfig
```
Load the freshly built modules **by explicit path** (avoids any modprobe ambiguity),
**slash first, then ami**:
```bash
sudo insmod $SLASH/driver/slash.ko
sudo insmod $SLASH/linker/resources/submodules/AVED/sw/AMI/driver/ami.ko
lsmod | grep -iE 'ami|slash|qdma'
dmesg | tail -40                     # check probe + VSEC discovery, no errors
```
> Load-order note: `ami` matches any Xilinx function and accepts one only if it has
> the hw_discovery VSEC (PF0 only on felix). Loading `slash` first lets it claim
> PF1/PF2; `ami` should then bind PF0 and reject the others — confirm in `dmesg`.

*(For a persistent install instead of `insmod`: `cd driver && sudo make install`
copies `slash.ko` to `/lib/modules/.../extra` + `depmod`; the AMI driver has no
install target — copy `ami.ko` there yourself and `sudo depmod -a`. For testing,
prefer `insmod`.)*

---

## Part 4 — Bring the card up + verify

The card needs a base image running. For bring-up, JTAG-program it (see
`DEPLOY_RUNBOOK.md` Phase 1). Use the AMC image for the full stack:
```tcl
# vivado -mode tcl
open_hw_manager ; connect_hw_server ; open_hw_target
program_hw_devices -file $FELIX/dfx_build/amc_pdi/build/felix_slash_amc.pdi [current_hw_device]
```
Then rescan/reboot the host so PCIe enumerates, and verify:
```bash
echo 1 | sudo tee /sys/bus/pci/rescan
lspci -d 10ee: -nn                          # expect 50b4 (PF0), 50b5 (PF1), 50b6 (PF2)
lspci -s <BDF> -k | grep -i "in use"        # PF0->ami, PF1/PF2->slash_*
sudo vrtd &                                 # start the daemon (or: systemctl start vrtd)
v80-smi list                                # PF0/PF1/PF2/VRTD should all pass
```

---

## Part 5 — Test the `00_axilite` example

Build the example + its `.vbin` (see `BUILD_RUNBOOK.md` Phase B for the linker
details), then run it against the **PF2 (slash)** BDF:
```bash
cd $FELIX/examples/00_axilite
# (if not already linked) build the HLS + vbin — needs Vivado/Vitis:
#   ../build_hls.sh 00_axilite increment accumulate
#   V80PP_RESOURCE_DIR=$FELIX/linker/resources python3 $FELIX/linker/src/main.py link \
#     -c config.cfg -p hw -o axilite_hw.vbin -k <inc component.xml> <acc component.xml> --vivado $(which vivado)

# build the host app and run it:
cmake -B build -S . -G Ninja -DSLASH_USE_REPO=ON && cmake --build build
./build/00_axilite <PF2-BDF> axilite_hw.vbin
```
Loading the `.vbin` triggers the kernel swap (DMA → PMC reconfig → `reset.c`
re-enum). Success = the app prints matching increment→accumulate results.
The device will blip out/in of PCIe once during the swap — that's expected.

---

## Part 6 — Flash the base design into the card (permanent)

This writes `felix_slash_amc.pdi` into the card's flash so it boots **without JTAG**
next power-on. Requires `ami.ko` loaded and the AMC alive (Part 4).

```bash
# confirm AMI can talk to the card first:
ami_tool overview                                  # should list the device + logic UUID
# program the primary boot partition + update the flash partition table:
ami_tool cfgmem_fpt -d <PF0-BDF> -t primary -i $FELIX/dfx_build/amc_pdi/build/felix_slash_amc.pdi
# (cfgmem_program does the same without touching the FPT; check `ami_tool cfgmem_fpt -h`)
```
After it reports success, set/confirm the boot partition and reload:
```bash
ami_tool device_boot -d <PF0-BDF> -p primary       # verify arg names with -h
ami_tool reload -d <PF0-BDF>                        # or power-cycle the host
```
> ⚠️ Flashing is the one genuinely risky step — a bad/interrupted flash of the
> *primary* partition can leave the card unbootable (recover via JTAG). If your
> card has a **secondary/golden** partition, flash `-t secondary` first, test it,
> then do primary. Do not power-cycle mid-flash.

---

## Part 7 — Uninstall / roll back what you installed

```bash
# unload modules
sudo systemctl stop vrtd 2>/dev/null || true
sudo rmmod ami slash 2>/dev/null || true
# remove installed host libraries (cmake records what it installed)
for c in driver/libslash vrt/vrtd vrt smi; do
  [ -f "$SLASH/$c/build/install_manifest.txt" ] && \
    sudo xargs rm -f < "$SLASH/$c/build/install_manifest.txt"
done
sudo ldconfig
# if you used `make install` for slash.ko:
sudo rm -f /lib/modules/$(uname -r)/extra/slash.ko && sudo depmod -a
```
(Flash rollback: re-flash a known-good image via `ami_tool cfgmem_fpt`, or JTAG.)

---

## Quick cautions checklist

- [ ] Old DKMS/`.deb` `ami`+`slash` fully removed **before** source install (Part 1 verify).
- [ ] Loaded **slash first, then ami**; confirmed PF bindings in `dmesg`.
- [ ] Card JTAG-booted and `v80-smi list` green **before** any `ami_tool` flash.
- [ ] Flash **secondary/golden first** if available; never power-cycle mid-flash.
- [ ] `00_axilite` swap causes one PCIe blip — expected, not a fault.
