# FELIX SLASH — Full clean build → install → test (ONE plan)

Build every component of felix SLASH from scratch, install it, and test the
`00_axilite` example on the FLX-155 card. **This repo is self-contained** — drivers,
firmware, linker and hardware all live here (no external submodules to init).

Components: **hardware base image**, **AMC firmware**, **linker**, **drivers
(slash.ko, ami.ko)**, **host libs (libslash, libvrt, vrtd, smi)**, **example kernel**.

Repo layout (SLASH-shaped, felix additions in **bold**):
```
driver/  vrt/  smi/  cmake/  submodules/qdma_drv/   ← unmodified upstream SLASH
linker/           ← felix resources + src (v80++)
  resources/submodules/AVED/{fw/AMC(+profiles/felix), sw/AMI}   ← vendored AVED
examples/         ← felix-retargeted (DDR, not HBM)
dfx_build/        ← ★ felix hardware (build scripts + amc_pdi combine)
scripts/          ← ★ stage_artifacts.sh
build_all.sh      ← ★ one-command build (hw|fw|sw|all)
```

```bash
# run in every shell
source /tools/Xilinx/2025.1/Vitis/settings64.sh
cd <this repo>
```

## Fast path (one command per stage)
```bash
./build_all.sh hw     # HLS IP + Vivado hw + stage artifacts + slash_base.bd   (~1 h)
./build_all.sh fw     # AMC BSP + amc.elf + base PDI with AMC                    (~10 min)
./build_all.sh sw     # slash.ko, ami.ko, libslash, libvrt, vrtd, smi           (~5 min)
# ./build_all.sh all  # does hw, fw, sw in order
```
Then install/load drivers (Stage 3.3), build+link the kernel (Stage 4), and
deploy on the card (Stage 5). The explicit stages below are what `build_all.sh` runs.

---

## STAGE 1 — Hardware base image (Vivado, ~1 h)  [`build_all.sh hw`]
```bash
( cd iprepo/hbm_bandwidth && make )                            # HLS iprepo IP
vivado -mode batch -source dfx_build/scripts/run_all.tcl        # build DFX project
vivado -mode batch -source dfx_build/scripts/run_impl.tcl       # synth/impl -> PDI, XSA, abs shell
./scripts/stage_artifacts.sh                                    # copy dcp/pdi/xsa to the right places
( cd linker/resources/base/iprepo/hbm_bandwidth && make )       # linker self-test IP
( cd linker && vivado -mode batch -source gen_slash_base.tcl )  # -> slash_base.bd
```
`stage_artifacts.sh` places: `abs_shell_slash.dcp` → `linker/resources/abstract_shell/`,
and `felix_slash.xsa` + `felix_cips_wrapper.pdi` → `dfx_build/artifacts/`.

## STAGE 2 — AMC firmware + base PDI with AMC (~10 min)  [`build_all.sh fw`]
```bash
AMC=linker/resources/submodules/AVED/fw/AMC
( cd $AMC/scripts && ./build_bsp.sh -xsa $(pwd)/dfx_build/artifacts/felix_slash.xsa -os freertos )
( cd $AMC && ./scripts/build.sh -amc -profile felix -os freertos )     # -> build/amc.elf
( cd dfx_build/amc_pdi && ./combine_amc_pdi.sh )                        # -> build/felix_slash_amc.pdi
```

## STAGE 3 — Drivers + host software (~5 min)  [`build_all.sh sw` then install/load]

### 3.1 Remove OLD drivers first (this machine has them via DKMS/.deb)
```bash
sudo systemctl stop vrtd 2>/dev/null || true
sudo rmmod ami slash 2>/dev/null || true
sudo apt-get remove --purge -y ami slash-dkms slash-dev \
    libslash libslash-dev libvrt libvrt-dev libvrtd libvrtd-dev \
    vrtd v80-smi v80++ amd-vrt 2>/dev/null || true
for m in ami/2.4.0 slash/0.1; do sudo dkms remove "$m" --all 2>/dev/null || true; done
sudo depmod -a
dpkg -l | grep -iE '\bami\b|slash|libvrt|vrtd' | grep '^ii'; dkms status | grep -iE 'ami|slash'   # both empty
```

### 3.2 Build from source (all local)
```bash
( cd driver && make clean && make )                                              # slash.ko
( cd linker/resources/submodules/AVED/sw/AMI/driver && make clean && make )       # ami.ko
for c in driver/libslash vrt/vrtd vrt smi; do
  ( cd $c && rm -rf build && cmake -S . -B build -G Ninja && cmake --build build )
done
```

### 3.3 Install host libs + load drivers (slash first, then ami)
```bash
for c in driver/libslash vrt/vrtd vrt smi; do ( cd $c && sudo cmake --install build ); done
sudo ldconfig
sudo insmod driver/slash.ko
sudo insmod linker/resources/submodules/AVED/sw/AMI/driver/ami.ko
lsmod | grep -iE 'ami|slash|qdma'
```

## STAGE 4 — Example kernel `00_axilite` -> vbin (~15 min)
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

## STAGE 5 — Deploy + test on the FLX-155 card
```bash
# 5.1 program the base image (with AMC) over JTAG (Vivado hw manager)
#   open_hw_manager; connect_hw_server; open_hw_target
#   program_hw_devices -file dfx_build/amc_pdi/build/felix_slash_amc.pdi [current_hw_device]

# 5.2 enumerate + verify
echo 1 | sudo tee /sys/bus/pci/rescan
lspci -d 10ee: -nn                     # 50b4 (PF0), 50b5 (PF1), 50b6 (PF2)
sudo vrtd & ; v80-smi list             # PF0/PF1/PF2/VRTD pass

# 5.3 RUN THE TEST (PF2 / slash BDF)
./examples/00_axilite/build/00_axilite <PF2-BDF> examples/00_axilite/axilite_hw.vbin

# 5.4 (optional) flash the base design so it boots without JTAG (see DRIVERS_BUILD_TEST_FLASH.md)
#   ami_tool cfgmem_fpt -d <PF0-BDF> -t primary -i dfx_build/amc_pdi/build/felix_slash_amc.pdi
```

---

## Verification status
Build side (Stages 1–4) is verified on this workstation, incl. the vendored tree
building in place (`slash.ko`, `ami.ko`, `amc.elf`, `slash_base.bd`, `.vbin`).
**Stage 5 needs the powered card — not yet run.** Two items to watch on first
hardware run: `QDMA_LOGIC_BASE 0x201_0002_0000` responds (`vrt/device.hpp`), and the
AMI↔AMC mailbox is alive (`ami_tool overview`).

Deeper detail: `BUILD_RUNBOOK.md` (hw+linker), `DRIVERS_BUILD_TEST_FLASH.md`
(drivers/flash), `DEPLOY_RUNBOOK.md` (on-card), `CONCEPTS.md` (how it works).
Kernel-swap-only demo (no AMI/AMC): program `dfx_build/artifacts/felix_cips_wrapper.pdi`,
skip `ami.ko`, bypass the AMI call in `vrt/vrtd/src/reset.c` (SBR-only).
