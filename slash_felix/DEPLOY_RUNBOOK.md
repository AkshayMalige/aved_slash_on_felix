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

# 0.2b remove any ad-hoc (non-dpkg) vrtd setup.
#     CRITICAL: /etc/systemd/system OVERRIDES /lib/systemd/system, and the .deb
#     installs its units to /lib. A hand-installed unit in /etc therefore keeps
#     winning after the package is installed -- typically with an ExecStart
#     pointing at a stale /usr/local binary. dpkg will never warn you about this.
#     Use `stop`, NOT `disable`. `disable` records a persistent admin decision that
#     deb-systemd-helper deliberately honours at install time, so the .deb will
#     install the units and then leave them DISABLED -- you get a correct install
#     with a dead daemon and "VRTD NOT READY: Failed to open socket".
#     (If you already ran `disable`, fix it with: sudo systemctl enable --now vrtd.socket)
sudo systemctl stop vrtd.socket vrtd.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/vrtd.service /etc/systemd/system/vrtd.socket
sudo rm -f /etc/udev/rules.d/99-vrtd.rules      # the .deb ships 60-vrtd.rules in /lib
sudo rm -f /usr/lib/vrt/vrtd                    # symlink into /usr/local, if present
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
# keep the vrt / vrtd / vrtadmin groups -- the packages reuse them.

# 0.3 force-remove any DKMS leftovers for ALL kernels
for m in ami/2.4.0 slash/0.1; do sudo dkms remove "$m" --all 2>/dev/null || true; done
sudo depmod -a

# 0.4 remove anything a previous `cmake --install` put in /usr/local.
#     dpkg does NOT own these, so they survive every purge above -- and they
#     SHADOW the packaged copies (/usr/local/lib precedes /usr/lib for ld.so,
#     /usr/local/bin precedes /usr/bin in PATH). Symptom if you skip this:
#     the wrong libvrt/vrtd is used and nothing you rebuild takes effect.
sudo rm -f  /usr/local/lib/lib{slash,vrt,vrtd,vrtdpp}.so*
sudo rm -rf /usr/local/lib/cmake/{slash,vrt,vrtd}
sudo rm -rf /usr/local/include/{slash,vrt,vrtd}
sudo rm -f  /usr/local/bin/{vrtd,vrtd-*,v80-smi,v80++}
sudo ldconfig
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
ls /usr/local/lib/lib{slash,vrt,vrtd}* /usr/local/bin/{vrtd,v80-smi} 2>/dev/null
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

> **`run_impl.tcl` arms the SBI automatically.** After `write_device_image` it runs
> `dfx_build/scripts/inject_boot_device_pcie.tcl`, which adds `boot_device { pcie }`
> to the base image's BIF and regenerates `felix_cips_wrapper.pdi`. Without this the
> host-side kernel load (Part 8) hard-crashes the server — see Part 7b for the full
> story. The step is idempotent and self-verifying; look for
> `INJECT_BOOT_DEVICE: verified boot_device[pcie] present` in the log.
> **Verify it stuck:** `bootgen -arch versal -read dfx_build/artifacts/felix_cips_wrapper.pdi | grep boot_device` → `boot_device [pcie]`.

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

## Part 3 — Build the software packages  (~5 min)

felix uses **the same packaging flow as upstream SLASH**: build `.deb`s, then
install them with `apt`. This is the supported path — do not install by hand.

```bash
source /tools/Xilinx/2025.1/Vitis/settings64.sh    # package-deb.sh requires v++ on PATH
./scripts/package-deb.sh                           # add --noninteractive to skip the prompt
```
> ⚠️ **Run this AFTER Part 1's `stage_artifacts.sh`, never before.** `pinstall.sh`
> rsyncs the whole of `linker/resources/` into the `v80++` package — including
> `abstract_shell/`. Package first and you ship the *previous* build's abstract
> shell, so anything linked with the installed `v80++` targets the wrong shell.
That produces **all 15 packages** in `deb/` plus an apt index (`Packages`/`Release`):

| Package | Contents |
|---|---|
| `slash-dkms` | `slash.ko` source → DKMS builds it per kernel (binds **PF1** + **PF2**) |
| `ami_2.4.0-*.deb` | `ami.ko` (DKMS) + `ami_tool` + libami (binds **PF0**) |
| `vrtd` | the daemon **+ systemd units + udev rules + `/etc/vrt/vrtd.conf` + the `vrtd` user** |
| `libslash`, `libvrt`, `libvrtd` (+`-dev`) | host libraries |
| `v80-smi` | the `v80-smi` CLI |
| `v80++` | the linker (Part 5 uses the repo copy, not this) |
| `slash`, `slash-dev`, `slash-sim-emu*` | metapackages |

> The **`-dev` packages are not optional** — `libslash-dev`, `libvrt-dev` and
> `libvrtd-dev` carry the `*Config.cmake` files, and `v80++` carries the
> `SlashTools/` CMake modules. Without them Part 5's `cmake` fails with
> `Could not find a package configuration file provided by "vrtd"`.

> **Why packages and not `cmake --install`?** `cmake --install` installs *only the
> binaries*. Everything that makes `vrtd` actually runnable — the systemd units,
> the udev rules, `/etc/vrt/vrtd.conf`, the `vrtd` user and the `vrt`/`vrtadmin`
> groups — is installed by the **package**, exactly as upstream
> (`packaging/debian/vrtd.install` + `vrtd.postinst`). Installing by hand leaves
> `vrtd` unable to start: it is **socket-activated**
> (`main.c:configure_sockets()` → `sd_listen_fds_with_names()`), so running
> `sudo vrtd` from a shell always exits 1 with *"No socket provided"*.

**felix deltas vs upstream in these scripts** (all in `scripts/`):
> - `package-deb.sh` — exports `SLASH_PKG_SKIP_ROOT_DESIGN_BUILD=1` (felix's static
>   shell comes from `dfx_build/` in Part 1, not from this script — this also stops
>   it wiping `linker/resources/abstract_shell`); drops the SMBus IP prerequisite
>   check (the FLX-155 has no SMBus).
> - `package-ami.sh` — restores its temporarily patched AVED files from plain
>   backups instead of `git checkout` (felix **vendors** AVED, it isn't a
>   submodule), and picks an interpreter that still provides `pkg_resources`
>   (setuptools removed it in v81, so a conda `python3` fails).
> - `pconfigure.sh`, `pbuild.sh`, `pinstall.sh` — **verbatim from SLASH**.

**Check:** `ls deb/*.deb | wc -l` → 15

---

## Part 4 — Install the packages

```bash
# 4.1 install everything from the local repo built in Part 3.
#     ./deb/ has an apt index, so apt resolves the inter-package deps itself.
sudo apt-get install -y --allow-downgrades \
    ./deb/libslash_*.deb ./deb/libvrtd_*.deb ./deb/libvrt_*.deb \
    ./deb/vrtd_*.deb ./deb/v80-smi_*.deb ./deb/slash-dkms_*.deb \
    ./deb/ami_*_22.04.deb \
    ./deb/libslash-dev_*.deb ./deb/libvrt-dev_*.deb ./deb/libvrtd-dev_*.deb \
    ./deb/v80++_*.deb

# 4.2 confirm DKMS compiled both modules for THIS kernel
dkms status | grep -iE 'ami|slash'          # both -> "installed"

# 4.2b make sure the socket is ENABLED and running.
#      The .deb enables it on a first install, but if the unit was ever `systemctl
#      disable`d on this machine, deb-systemd-helper honours that and leaves it off.
sudo systemctl enable --now vrtd.socket
systemctl is-enabled vrtd.socket            # -> enabled
systemctl is-active  vrtd.socket            # -> active

# 4.3 join the group that vrtd's default policy grants full access to
sudo usermod -aG vrtadmin "$USER"
newgrp vrtadmin                              # or log out/in
id -nG | tr ' ' '\n' | grep vrtadmin         # must print vrtadmin

# 4.4 modules load automatically on PCI match; if the card was already up, kick it
sudo modprobe slash; sudo modprobe ami
lsmod | grep -iE 'ami|slash'
systemctl status vrtd.socket                 # active (listening)
```
> ⚠️ **Do NOT expect `v80-smi list` to pass yet.** Until the card is programmed
> (Part 6) only **PF2** and **VRTD** can come up. `PF0`/`PF1` will report
> `currently loaded driver: '(none)'` and the kernel log will show:
> ```
> qdma_is_config_bar: Invalid config bar, err:-4
> slash_qdma: probe of 0000:01:00.1 failed with error -22
> ```
> That is **correct behaviour with no valid bitstream in the fabric** — `slash_ctl`
> (PF2) only maps BARs, which the CPM/PCIe block provides from the PS, so it binds
> regardless; `slash_qdma` (PF1) and `ami` (PF0) must talk to fabric logic, so they
> fail until a design is loaded. A host reboot does NOT reconfigure the FPGA — if a
> previous programming attempt left `DONE bit: LOW`, the card stays dead until you
> re-program it. Full binding is verified in **Part 7**, after Part 6.
> `ami` matches any Xilinx function and keeps only the one carrying the
> hw_discovery VSEC (**PF0** on felix); it probe-rejects PF1/PF2 with `-22`, which
> is normal. `slash` claims **PF1** (`slash_qdma`, `50b5`) and **PF2**
> (`slash_pcie`, `50b6`) — one module, two PCI drivers.

> **Never start `vrtd` by hand.** It is socket-activated
> (`main.c:configure_sockets()` → `sd_listen_fds_with_names()`); `sudo vrtd` always
> exits 1 with *"No socket provided"*. systemd owns `/run/vrtd.sock` via
> `vrtd.socket` and hands the FD to the daemon. The `vrtd` package installs
> `/lib/systemd/system/vrtd.{socket,service}`, `/lib/udev/rules.d/60-vrtd.rules`,
> `/etc/vrt/vrtd.conf`, `/usr/lib/sysusers.d/vrtd.conf` and the binary at
> `/usr/lib/vrt/vrtd` (which is where the unit's `ExecStart` points).

> **Permissions:** the shipped `/etc/vrt/vrtd.conf` defines `[role:fullaccess]`
> (bar-access, qdma, buffer, design-write, clock, pcie-hotplug, raw-mem-access on
> any device) and grants it to `user:root` and `group:vrtadmin`; everyone else gets
> `[role:info]` (query only). So **you must be in `vrtadmin`** (step 4.3) or you
> will be able to list devices but not load a kernel. Add site-specific overrides
> as drop-ins in `/etc/vrt/vrtd.conf.d/*.conf` rather than editing `vrtd.conf`.

> ⚠️ **`ami` errors are expected if you programmed the base PDI.**
> `AMC GCQ service not ready` / `Device not ready, reboot required!` means the AMC
> firmware is not running (you used `felix_cips_wrapper.pdi`, not
> `felix_slash_amc.pdi`). This does **not** block Part 8 — see the note there.

### Uninstall / reinstall

```bash
# remove everything this runbook installed (see Part 0 for the stuck-ami case)
sudo systemctl stop vrtd.socket vrtd.service
sudo apt-get remove --purge -y ami slash-dkms vrtd v80-smi \
    libslash libslash-dev libvrt libvrt-dev libvrtd libvrtd-dev
sudo dpkg --purge v80++                     # NOT via apt -- see Part 0
sudo apt-get autoremove --purge -y

# then reinstall with 4.1 (rebuild first with Part 3 if sources changed)
```
DKMS unregisters both modules on purge, so no `/lib/modules` leftovers. To upgrade
in place after a rebuild, just re-run 4.1 — `dpkg` replaces the installed versions.

*(Parts 1–5 need no card. Only Part 6 onward needs the powered FLX-155.)*

---

## Part 5 — Build the example kernel `00_axilite` → `.vbin`

> ⚠️ **Any `.vbin` built against a previous hardware build is INVALID.** The linker
> places the kernel against `linker/resources/abstract_shell/abs_shell_slash.dcp`,
> which Part 1 regenerates every time. A new implementation changes the static
> routing at the partition boundary, so an old partial PDI no longer matches the new
> base image. **Whenever you redo Part 1, you must redo the link step below.**
> The HLS synthesis (`build_hls.sh`) does *not* need redoing — the kernels are
> independent of the shell; only the link is.

```bash
( cd examples && ./build_hls.sh 00_axilite increment accumulate )     # HLS synth (vp1552)
                                                                      # skip if kernels unchanged
HLS=$(pwd)/examples/00_axilite/hls
V80PP_RESOURCE_DIR=$(pwd)/linker/resources python3 linker/src/main.py link \
  -c examples/00_axilite/config.cfg -p hw \
  -o examples/00_axilite/axilite_hw.vbin \
  -k $HLS/build_increment.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
     $HLS/build_accumulate.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
  --vivado "$(which vivado)"
( cd examples/00_axilite && rm -rf build && cmake -B build -S . -G Ninja && cmake --build build )
```
> Build against the **installed packages** (the default). Do *not* pass
> `-DSLASH_USE_REPO=ON` — that switches `CMakeLists.txt:29` to
> `add_subdirectory(<repo>/vrt)`, and `vrt/CMakeLists.txt:105` then needs
> `vrtdConfig.cmake` anyway. It was only useful before Part 4 existed, when nothing
> was installed.
**Check:** `ls examples/00_axilite/axilite_hw.vbin examples/00_axilite/build/00_axilite`
(A `.vbin` is a gzip tar: `tar tzf examples/00_axilite/axilite_hw.vbin`.)

### Part 5a — Build the `01_aximm` example → `.vbin`

Same flow, different kernels: `01_aximm` chains two kernels — `offset` (computes
`in*m+n`, reads DDR0) streams over an on-chip AXI-Stream into `dma` (writes DDR1).
Same ⚠️ rule applies: **redo the link step whenever you redo Part 1.** Run as **one
block from the repo root** (`$HLS` and `$(pwd)` must resolve in the same shell).

```bash
( cd examples && ./build_hls.sh 01_aximm offset dma )                 # HLS synth (vp1552)
                                                                      # skip if kernels unchanged
HLS=$(pwd)/examples/01_aximm/hls
V80PP_RESOURCE_DIR=$(pwd)/linker/resources python3 linker/src/main.py link \
  -c examples/01_aximm/config.cfg -p hw \
  -o examples/01_aximm/aximm_hw.vbin \
  -k $HLS/build_offset.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
     $HLS/build_dma.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
  --vivado "$(which vivado)"
( cd examples/01_aximm && rm -rf build && cmake -B build -S . -G Ninja && cmake --build build )
```
**Check:** `ls examples/01_aximm/aximm_hw.vbin examples/01_aximm/build/01_aximm`
**Run** (PF1/QDMA BDF): `./examples/01_aximm/build/01_aximm 01:00.1 examples/01_aximm/aximm_hw.vbin`
→ expect `Test passed` (verifies `out[i] == in[i]*3 + 2`).

### Part 5c — Build the `02_ddr_bw` example → `.vbin`  (DDR bandwidth)

Measures **sustained DDR read/write bandwidth** from the kernel side, isolated from
PCIe. One 512-bit `mem_bw` kernel is instantiated **4×** (`config.cfg`) onto
`DDR0..DDR3` — four masters into the single DDR4 channel, to saturate it. The host
fills + pushes buffers once (untimed), then times **only** the concurrent 4-kernel
run. Both configs set the kernel clock to **400 MHz** at link time via a `[clock]
freqhz=400000000` block (200 MHz is the unset default — see CONCEPTS/notes). Same ⚠️
rule: **redo the link whenever you redo Part 1.**

```bash
( cd examples && ./build_hls.sh 02_ddr_bw mem_bw )                    # HLS synth (vp1552)
                                                                      # skip if kernel unchanged
HLS=$(pwd)/examples/02_ddr_bw/hls
V80PP_RESOURCE_DIR=$(pwd)/linker/resources python3 linker/src/main.py link \
  -c examples/02_ddr_bw/config.cfg -p hw \
  -o examples/02_ddr_bw/ddr_bw_hw.vbin \
  -k $HLS/build_mem_bw.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
  --vivado "$(which vivado)"
( cd examples/02_ddr_bw && rm -rf build && cmake -B build -S . -G Ninja && cmake --build build )
```
**Check:** `ls examples/02_ddr_bw/ddr_bw_hw.vbin examples/02_ddr_bw/build/02_ddr_bw`
**Run** (PF1/QDMA BDF): `sudo ./examples/02_ddr_bw/build/02_ddr_bw 01:00.1 examples/02_ddr_bw/ddr_bw_hw.vbin`
→ prints aggregate **Read** / **Write** GB/s. Optional args: `[words_per_port] [iters]`
(default `1048576` = 64 MB/port, `5` iters). DDR4-2666 ceiling ≈ 21.3 GB/s
(~15–18 realistic). If both numbers are ~1–4 GB/s, the static-region NoC QoS
(`read_bw/write_bw {250}`) is throttling → raise it and rebuild the base PDI.

### Part 5d — Build the `03_qdma_bw` example → `.vbin`  (PCIe/QDMA bandwidth)

Measures **host↔card DMA throughput**. Shares the same `mem_bw` kernel (1 instance on
`DDR0`); the host sweeps transfer sizes and times `buffer.sync()` each direction.

```bash
( cd examples && ./build_hls.sh 03_qdma_bw mem_bw )                   # HLS synth (vp1552)
                                                                      # skip if kernel unchanged
HLS=$(pwd)/examples/03_qdma_bw/hls
V80PP_RESOURCE_DIR=$(pwd)/linker/resources python3 linker/src/main.py link \
  -c examples/03_qdma_bw/config.cfg -p hw \
  -o examples/03_qdma_bw/qdma_bw_hw.vbin \
  -k $HLS/build_mem_bw.xcvp1552-vsva3340-2MHP-e-S/hls/impl/ip/component.xml \
  --vivado "$(which vivado)"
( cd examples/03_qdma_bw && rm -rf build && cmake -B build -S . -G Ninja && cmake --build build )
```
**Check:** `ls examples/03_qdma_bw/qdma_bw_hw.vbin examples/03_qdma_bw/build/03_qdma_bw`
**Run** (PF1/QDMA BDF): `sudo ./examples/03_qdma_bw/build/03_qdma_bw 01:00.1 examples/03_qdma_bw/qdma_bw_hw.vbin`
→ prints best **H2D** / **D2H** GB/s per size (sweeps 1/4/16/64 MB; override with
`[size_mb] [iters]`). Buffers live in card DDR, so both are bounded by
`min(PCIe Gen5x8, DDR)` — expect to approach the DDR ceiling, not raw PCIe.

> **After loading either vbin**, confirm the clock actually took:
> `v80-smi query -d 0000:01:00` should report `Clock frequency: 400000000`. If it
> still says `200000000`, the kernel didn't close 400 MHz and the linker capped it
> (see the WNS cap in `linker/src/emit/metadata/timing_freq.py`).

---

## Part 5b — Pre-flight check  ⚠️ run this before every hardware session

```bash
./scripts/preflight_check.sh          # must print FAIL=0 SKIP=0
```
One second, entirely offline, and it catches every failure that has cost a hardware
session on this port:

| Section | Catches |
|---|---|
| 1. PS-side DDR route | the PLM-stall root cause — `PMC_NOC_AXI_0` / `LPD_AXI_NOC_0` must map `C0_DDR_LOW0` |
| 2. AMC load addresses | `amc.elf`'s `0x40000000` segment must fit the mapped 2G low region |
| 3. Combined PDI | must contain **2** `r5-0` partitions (TCM + DDR) and `rpu_subsystem` id `0x1c000000` |
| 4. Artifact freshness | staged PDI must be newer than `impl_1` — else you program a stale image |
| 5. Host stack | modules, all 3 PF bindings, `vrtd.socket`, `vrtadmin` membership |

A `SKIP` in section 4 means `stage_artifacts.sh` has not run since the last
implementation — treat it as a failure, not a pass.

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
set_property PROGRAM.FILE {/home/synthara/VersalPrjs/felix/felix-xpfm-pcie/porting_slash/slash_felix/dfx_build/amc_pdi/build/felix_slash_amc.pdi} [current_hw_device]
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
for f in 0 1 2; do echo -n "PF$f -> "; \
  basename "$(readlink /sys/bus/pci/devices/0000:01:00.$f/driver)" 2>/dev/null || echo "(none)"; done
# expect: ami / slash_qdma / slash_pcie
systemctl status vrtd.socket                # active (listening) — never run `vrtd` by hand
v80-smi list                                # PF0/PF1/PF2/VRTD should all pass
sudo dmesg | grep -iE 'slash|ami|qdma|vsec' # binding + VSEC discovery
```
⚠️ First real check that the three PFs bind and the VSEC (uuid/gcq/gcq_payload) reads back.

`v80-smi list` tells you exactly which piece is missing:

| Symptom | Cause | Fix |
|---|---|---|
| `PF1/PF2 NOT READY: wanted 'slash_qdma'/'slash_ctl', loaded '(none)'` | `slash` module not loaded | `sudo modprobe slash`; if that fails, `dkms status` — the package may not have built for this kernel |
| `VRTD NOT READY: Failed to open socket` | `vrtd.socket` not running | `sudo systemctl start vrtd.socket`; if it was never installed you skipped Part 4 |
| lists devices but a kernel load is refused | you are not in `vrtadmin` | Part 4.3, then `newgrp vrtadmin` |

---

## Part 7b — SBI arming  ✅ now automatic (no manual step)

**Nothing to do here if you built the hardware from this repo.** The SBI is armed
by the base PDI itself — `run_impl.tcl` injects `boot_device { pcie }` (Part 1), so
the PLM brings the Slave Boot Interface up in AXI-slave mode at boot. Go to Part 8.

This section is kept for **diagnostics** and history. Skip it unless Part 8 crashes
the host.

<details>
<summary><b>The bug this fixes (and how to check it's fixed)</b></summary>

Part 8 has the host **DMA a partial PDI to `0x102100000`**, the PMC's **slave-boot
stream** aperture. For the PMC to accept a bitstream that way, its **Slave Boot
Interface (SBI)** must be in **AXI-slave mode and enabled**:

| Register | Addr (PMC-local) | Meaning |
|---|---|---|
| `SLAVE_BOOT_SBI_CTRL` | `0xF1220004` | bits [4:2] = interface, bit [0] = enable |
| | | `0x4` = JTAG, disabled (power-up default) |
| | | `0x9` = AXI-slave `(0x8)` \| enable `(0x1)` — what host DFX needs |

If the SBI is still `0x4` when vrtd streams the PDI, the AXI write is **rejected** →
propagates into the CPM (PCIe/QDMA block) as an **uncorrectable error (`CPM_NCR`)** →
the PCIe endpoint drops off the bus → **the host takes a fatal PCIe error and hard-
resets** (no Linux log; the card's PLM log shows `PMC EAM ERR1: 0x200` / `CPM_NCR`).

**Root cause (the porting bug):** felix's base PDI was missing `boot_device { pcie }`
in its boot BIF, so the PLM never armed the SBI for PCIe. V80's base PDI has that
directive — that is the *only* boot-relevant difference between the two designs
(every CIPS/PS_PMC/CPM knob is otherwise identical). felix's CIPS was ported from the
VEK280 eval board, which boots from SD/JTAG and never receives host-streamed PDIs, so
the directive was never present. `XLoader_SbiInit()` in the PLM sets `SBI_CTRL = 0x9`
for a PCIe PDI source (`XLOADER_PDI_SRC_PCIE`) precisely when the boot image declares
`boot_device { pcie }`.

**The permanent fix (in the build):** `dfx_build/scripts/inject_boot_device_pcie.tcl`,
called from `run_impl.tcl`, adds the directive to the generated BIF and re-runs
`bootgen`. It survives clean rebuilds and needs no on-card action. Confirm any PDI
carries it:
```bash
bootgen -arch versal -read dfx_build/amc_pdi/build/felix_slash_amc.pdi | grep boot_device
# -> boot_device [pcie]
```

**Manual fallback (only if you must run a base PDI that lacks the directive):** you
can arm the register by hand over JTAG. Harmless to re-run; the card keeps the state.
```bash
# card programmed (Part 6) + enumerated (Part 7) first
xsdb scripts/diag/40_sbi_axi_slave.tcl | tee diag_logs/sbi_fix.txt
# want: SBI_CTRL (0xF1220004): 00000004  ->  00000009
```
This is the last resort — the built PDI should make it unnecessary.
</details>

---

## Part 7c — After a host reboot (what carries over, what doesn't)

You do **not** rebuild or reinstall after a normal reboot. Here's the state model:

| Thing | Survives a warm `reboot`? | Survives a full power-cycle? |
|---|---|---|
| Installed packages / DKMS modules | ✅ auto-load on PCI match | ✅ |
| `vrtd.socket` (enabled) | ✅ auto-starts | ✅ |
| **FPGA configuration** (the programmed PDI) | ✅ card stays configured | ❌ **lost** — reprogram (Part 6) |
| SBI armed state | ✅ (baked into the PDI, re-applied on any FPGA boot) | ✅ (re-armed when the PDI reloads) |

So after a reboot, just verify and run:
```bash
lspci -d 10ee: -nn                     # 50b4/50b5/50b6 all present?
v80-smi list                           # PF0/PF1/PF2/VRTD all pass?
```
- **All present + pass** → go straight to Part 8. Nothing else needed.
- **Card missing from `lspci`** → the FPGA lost its configuration (this happens on a
  cold power-cycle, or if a prior run crashed the card). **Reprogram it (Part 6)**,
  then `echo 1 | sudo tee /sys/bus/pci/rescan`, then re-check.
- **PF0 only, or a PF shows `xhci_hcd`/wrong driver** → the fabric has no valid
  design (dead/garbage config). Reprogram (Part 6). See Troubleshooting.
- **VRTD fail** → `sudo systemctl start vrtd.socket` (should already be enabled).

> A **warm reboot does not reprogram the FPGA** — whatever was in it stays. Only a
> power-cycle (or a crash that drops the PCIe link) forces a reprogram.

---

## Part 8 — Run the design from the host

```bash
# Pass the BOARD-level BDF: domain:bus:device, NO function digit.
# For a card at 01:00.x that is 0000:01:00 (vrt/src/device.cpp:50 strips a
# trailing .F with a warning and prepends the 0000: domain).
./examples/00_axilite/build/00_axilite 0000:01:00 examples/00_axilite/axilite_hw.vbin
```
> **The AMC is not required for this test.** `Device::programDevice()`
> (`vrt/src/device.cpp:350`) only calls `designWriteFile()`, and vrtd's design
> writer (`design_writer.c`) DMAs the partial PDI over a `slash_qdma` queue pair —
> no AMI and no AMC on that path. `reset_with_ami()` runs only for the explicit
> `RESET_SEQUENCE` hotplug op, which this example never issues. So a dead AMC
> costs you sensors/management, not kernel swapping.
What happens: libvrt → `vrtd` → `design_writer` DMAs the partial PDI over QDMA to
`0x102100000` → the PMC partially reconfigures the `slash` partition → `clock.c`
sets the kernel clock (BAR4) → the kernel is live and the app reads/writes it over
the BAR and DDR. (`reset.c`'s SBR + re-enumeration is a *separate*, explicitly
requested operation — it does not run here.)
**Success:** the program prints matching `increment → accumulate` results.

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

## Platform limits — know before designing/benchmarking kernels

FELIX is a **single DDR channel** board. Two hard facts bite every kernel design
(full detail in `PROJECT_CONTEXT.md §0b`):

**DDR ports (`DDR0..DDR3`) are NoC doors into ONE DDRMC, not 4 channels.**
- One DDRMC ↔ one DDR4-2666 mini-DIMM. Peak ≈ **21.3 GB/s** (~15–18 realistic), shared.
- **Only DDR0 + DDR1 are wired** (`NUM_NSI {2}` on `axi_noc_mc_ddr4_0`). Mapping a kernel to
  **`DDR2`/`DDR3` segfaults the host** — those doors aren't opened in the base.
- The "4" is a linker/template default (`slash.tcl`, `num_ddr=4`), **not** a hardware cap; you
  can open more doors, but it adds **zero bandwidth** (one channel, shared). **1–2 wide
  (512-bit) sequential-burst ports saturate it.** One `m_axi` port already does read *and* write.

**Kernel clock is capped at 333.33 MHz in software** (`vrt` `CLOCK_MAX_FREQ = 333333333`,
`device.hpp:95`). Kernels build at a 400 MHz base but **run ≤333 MHz** — you'll see the warning
`Clock frequency 400000000 exceeds maximum frequency 333333333`. Harmless (512b×333 = 21.3 GB/s
≥ DDR ceiling). To raise ≤400: edit `CLOCK_MAX_FREQ` + rebuild/reinstall the `vrt` package.
Above 400 also needs the linker `base_freq_hz` + timing closure + possibly a `clk_wizard_slash`
rebuild. Set `freqhz=333333333` in a `config.cfg` `[clock]` block to silence the warning.

> Base NoC QoS ships placeholder-low (DDR ~1.5 GB/s, QDMA hop 128 MB/s) → caps QDMA at
> ~0.3 GB/s. Raising it + rebuilding the base PDI (Part 1) is required for real bandwidth.

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
| **host crashes/hangs when running Part 8** (needs reset button) | **SBI not armed.** The built PDI should arm it — check `bootgen -arch versal -read <pdi> \| grep boot_device` shows `boot_device [pcie]`. If it doesn't, you programmed an old PDI: rebuild (Part 1) or re-inject and re-combine. As a stopgap, arm it by hand (Part 7b fallback). |
| kernel load hangs at reconfig (no crash) | design_writer→`0x102100000`; SBI armed OK but PLM not consuming the stream — check QDMA H2C queue + PLM log (JTAG/XSDB) |
| `ami_tool sensors` garbage | expected — AMC still has V80 `profile_sensors.h`/`profile_pdr.h`; retarget to FLX-155 |
| reset/reprogram fails (full stack) | AMC not alive on R5 — verify the AMC PDI booted (XSDB on R5), or use the SBR-only shortcut |

## Status
Build side (Parts 1–5) verified on the workstation. **Parts 6–8 verified on the
powered FLX-155 (2026-07-24):** `00_axilite` and a second example stream the partial
PDI from the host, the PMC reconfigures the `slash` partition, and both kernels run
and verify. That first pass needed the manual SBI arm (`40_sbi_axi_slave.tcl`).

**SBI arming is now permanent in the build** (Part 1 / Part 7b): `run_impl.tcl`
injects `boot_device { pcie }` into the base PDI, so no on-card step is needed. A
base PDI rebuilt with the fix is verified to carry `boot_device [pcie]` through
`stage_artifacts.sh` → `combine_amc_pdi.sh` into `felix_slash_amc.pdi`.
**Not yet re-verified on silicon without the manual step** — next on-card run should
program the fixed PDI and run the examples *without* `40_sbi_axi_slave.tcl` to
confirm. Part 9 (flash) not yet run. Watch the two ⚠️ items (`QDMA_LOGIC_BASE`,
AMI↔AMC) for full-stack management.
