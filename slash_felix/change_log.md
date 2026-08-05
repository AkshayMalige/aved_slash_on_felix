# CHANGELOG — felix SLASH vs upstream SLASH / AVED

File-by-file comparison of this felix repo against the base SLASH reference
(`Xilinx/AVED` submodule included). felix = SLASH ported from Alveo **V80**
(`xcv80`, HBM) to **FLX-155** (`xcvp1552`, 1× DDR, no HBM/DCMAC/SMBus).

**Scope note:** the hardware build (`dfx_build/`) is felix-specific and is **not**
diffed here (it has no SLASH counterpart — SLASH's hardware lives in `AVED/hw/`).
Build outputs (`*.o/*.ko/*.so`, `build/`, `amc_bsp/`, `ip/`, `*.dcp/*.pdi/*.xsa`)
are excluded from the comparison.

**Headline:** the drivers, host libraries and daemon are **near-identical** to
SLASH (device IDs + address map were matched during the hardware port), with four
deltas: **two genuine upstream bug fixes in `vrt` — (1) allocator, 2026-07-29 and
(2) the kernel clock `freqhz` never being applied, 2026-08-05**; and a
**matched QDMA performance pair — (3) `buffer.c` big-chunk writes + (4) driver
`aperture_size 4096→0`** — which is a *deliberate felix divergence*, not an upstream
bug (see the `buffer.c`+`slash_qdma.c` row). All other felix deltas are concentrated
in the **linker** (resources + a few emit modules), the **AMC firmware profile**, and
the **examples**.

---

## 1. MODIFIED — files changed from SLASH/AVED

| File | What changed | Why |
|---|---|---|
| `vrt/include/vrt/allocator/allocator.hpp` | **upstream bug fix (2026-07-29):** `BuddySuperblockBase::allocate()` `return nullptr` → `throw std::bad_alloc()` when a superblock is full | full superblock returned null instead of throwing, so `Allocator::allocate`'s `catch(bad_alloc)` never rolled over to a new superblock → null wrapped → `getPhysAddr` segfault. Broke multi-superblock DDR (only ~64 MB usable). V80 never hit it (big buffers→HBM); FELIX (no HBM) does. Fix unlocks full 16 GB. **Report to SLASH team.** See `DEPLOY_RUNBOOK.md` Appendix. |
| `vrt/src/device.cpp` | **upstream bug fix (2026-08-05):** the constructor's clock block gained the missing `else` — was `if (clockFreq > CLOCK_MAX_FREQ) setUserClockRate(CAP);` with no else, now `… else setUserClockRate(clockFreq);`, plus a `clockFreq > 0` guard so a `system_map.xml` with no `<ClockFrequency>` never programs 0 Hz. | Upstream programs the MMCM **only** when `freqhz` is *strictly above* `CLOCK_MAX_FREQ` (333333333). Every value at or below the cap — i.e. every realistic value, and every felix example, which all used exactly `333333333` — programmed **nothing at all**, so the fabric silently kept whatever rate the clk_wiz was last left at. That rate survives partial reconfiguration and process exit, and only resets on a power cycle, so `[clock] freqhz=` looks like it sets the kernel clock, doesn't, and gives no warning. **The real damage is non-reproducibility:** the same vbin + same binary gave different bandwidth on different days depending on what last touched the board — the source of the historical 23 / 15 / 11.9 GB/s confusion. Measured on one 512-bit port: **6.40 GB/s at 100 MHz vs 13.48 GB/s at 250–333 MHz**. It survived upstream because SLASH's only `freqhz` example (`04_freq`) uses `400000000`, deliberately *above* the cap — the one case that ever worked. Note `freqhz` is a **load-time MMCM setting shipped in the vbin**, not a synthesis constraint (HLS builds against `hls/<k>.cfg clock=`, the RM is routed against the static `clk_wizard_0`), so honouring it here is the whole fix. **Report to SLASH team.** |
| `vrt/vrtd/libvrtd/src/buffer.c` **+** `driver/slash_qdma.c` | **felix perf change (2026-07-29..30), matched pair:** (a) `vrtd_buffer_sync_to/from_device` `4 KB TRANSFER_STEP_SIZE` write loop → whole-range `write()`/`read()` in ≤128 MB chunks; (b) `qconf.aperture_size` `4096` → **`0`** (keyhole OFF → linear DMA) **for data queues only — see the `aperture_size` row below, this was globally applied at first and that broke DFX.** | **NOT an upstream bug — a deliberate divergence.** Reference SLASH ships a *self-consistent* slow pairing: `{4 KB writes, aperture 4096}` (keyhole confines each 4 KB write to one 4 KB window — correct but ~0.3–1 GB/s, syscall-bound). We switched to the faster consistent pairing `{≤128 MB writes, aperture 0}`. **Changing only (a) without (b) is a corruption bug** (128 MB write wraps into a 4 KB keyhole window — proven: `01_aximm` 4 MB → `Test failed`). With both: correct (`Test passed`) and **0.3 → ~4.3 GB/s** (~5–14× over reference). Ceiling is the single-queue `buffer.sync()` path — same path V80 uses; going further (SGL coalescing / hugepages / multi-queue) is custom, not something the reference does. |
| `driver/libslash/include/slash/uapi/slash_interface.h` **+** `driver/libslash/src/qdma.c` **+** `driver/slash_qdma.c` **+** `vrt/vrtd/src/design_writer.c` **+** `vrt/vrtd/src/buffer.c` | **`aperture_size` made PER-QUEUE (2026-07-31/08-01), correcting the row above.** Added `__u32 aperture_size` to `struct slash_qdma_qpair_add` + a frozen `slash_qdma_qpair_add_v1` used *only* to derive the ioctl number; driver takes `req->aperture_size` instead of hardcoding `0`, validating `0 \|\| (power-of-two ≥ PAGE_SIZE)`; `design_writer.c` requests **4096** (keyhole), `buffer.c` requests **0** (linear) explicitly in both create paths. | The earlier global `aperture_size = 0` was right for card DDR but **silently broke DFX-from-host for 2 days**. `0x102100000` is the PMC Slave Boot Interface — a **fixed-address FIFO**, not a memory range — so linear addressing walks `ep_addr` off the FIFO into unmapped PMC space; `write()` returned `EIO` after the driver's 10 s timeout having moved **0 bytes**, while `design_writer_transfer()` still reported success. Net effect: **partial reconfiguration never ran**, the `slash` partition kept the base PDI's default RM (9× `hbm_bandwidth` self-test IPs, `20_slash.tcl`), and every example drove *those* registers — producing phantom "kernel↔DDR corruption", a flat ~96 ms "m_axi stall", a fake ≥16 MB / 64 MB boundary, and a physically impossible 23.8 GB/s. Hardcoding either value breaks the other path, hence per-queue. **The frozen v1 struct is essential:** `_IOWR()` encodes `sizeof(struct)` in the ioctl number, so growing the struct changed it → `ENOTTY` → vrtd crash-loop; pinning it keeps `0xc01c7651` and lets the existing `size` field do version negotiation, so a driver/libslash skew degrades gracefully. **Report to SLASH team.** |
| `linker/resources/bd_ports.txt` | removed 64 HBM + 8 MEM lines; kept DDR0-3 / VIRT0-3 / HOST | felix has 1 DDR channel, no HBM |
| `linker/resources/slash.tcl` | stripped HBM/DCMAC (1336→623 lines); DDR apertures `{0x0 2G}{0x600… 32G}`; clock/reset boundary `user_clk`/`arstn` → `slash_clk`/`slash_resetn` | felix topology + boundary |
| `linker/resources/base/scripts/slash_base.tcl` | replaced V80's 4016-line recipe with a 97-line felix boundary recipe | felix partition boundary |
| `linker/resources/base/scripts/slash_project_build.tcl` | `-part`→vp1552; top→`felix_cips_wrapper`; RP cell `top_i/slash`→`felix_cips_i/slash` | felix part + hierarchy |
| `linker/src/emit/hw/tcl_gen.py` | `num_mem`→0 (no hbm_vnoc terminators/smartconnect); `dcmac_rx_tready_tie_slots`→[] | no HBM/DCMAC on felix |
| `linker/src/emit/hw/user_region/terminator_ctx.py` | hardcoded `"user_clk"`→`"slash_clk"` (VIRT+HOST terminator clocks) | felix boundary; the emit context overrode the template default |
| `linker/src/emit/hw/user_region/hbm_ctx.py` | `"user_clk"`→`"slash_clk"` | felix boundary (HBM path inert but fixed for consistency) |
| `linker/src/emit/metadata/report_util.py` | `nodes["top_wrapper"]` → platform-aware (`felix_cips_wrapper`, fallback) | felix top module name |
| `…/AVED/fw/AMC/CMakeLists.txt` | added `felix` profile branch (no `-DOOB_ENABLED`); felix added to ospi/emmc debug gating; `-Wno-error=format/address` for the dormant SMBus stub | felix AMC build (vs upstream AVED) |
| `…/AVED/fw/AMC/src/profiles/felix/profile_hal.h` | SMBus HAL removed (felix has none); GCQ symbol `XPAR_BASE_LOGIC_GCQ_M2R_BASEADDR` → `XPAR_STATIC_REGION_AVED_BASE_LOGIC_GCQ_M2R_BASEADDR` | felix has no SMBus; felix wraps base_logic in `static_region/aved` so the GCQ XPAR symbol is prefixed |
| `examples/00_axilite/config.cfg` | `sp=increment_0…:HBM1` → `:DDR0` | felix has no HBM |
| `examples/01_aximm/config.cfg` | `sp=dma_0…:HBM0` → `:DDR1` (offset already DDR0) | felix has no HBM |
| `examples/{00_axilite,01_aximm}/hls/*.cfg` | `part=xcv80…` → `part=xcvp1552…` | felix part |
| `examples/{00_axilite,01_aximm}/CMakeLists.txt` | `DEVICE` default `xcv80…` → `xcvp1552…` | felix part |
| `scripts/package-deb.sh` | exports `SLASH_PKG_SKIP_ROOT_DESIGN_BUILD=1`; removed the SMBus IP prerequisite check | felix's static shell is built in `dfx_build/`, not by this script (skipping also stops it wiping `linker/resources/abstract_shell`); FLX-155 has no SMBus |
| `scripts/package-ami.sh` | restores its temporarily patched AVED files from plain backups instead of `git checkout`; selects an interpreter that still provides `pkg_resources` | felix **vendors** AVED (not a submodule, so there is no submodule index to restore from); setuptools ≥81 removed `pkg_resources`, so a conda `python3` fails |

> Note on the AMC: `CMakeLists.txt` + `profiles/felix/` are felix changes **vs
> upstream `Xilinx/AVED`**. (They may also appear in a local SLASH working tree if
> AVED was edited in place before vendoring — they originate here.)

`ami_driver_version.h` shows as "differ" only because it's a **build-generated
stub** (empty in git; `getVersion.sh` writes the version at build) — **not** a felix change.

---

## 1a. Packaging — CORRECTION (2026-07-22)

An earlier revision of this file listed `packaging/{debian,rpm}` and SLASH's
`scripts/` under "skipped — felix builds from source". **That was wrong and it
broke deployment.** Those two directories are where vrtd's *runtime* install
lives: the systemd units, the udev rules, `/etc/vrt/vrtd.conf` (the role policy)
and the `vrtd` user are installed **only by the `.deb`**
(`packaging/debian/vrtd.install` + `vrtd.postinst`, driven by
`scripts/package-deb.sh`). `cmake --install` installs just the binaries.

Consequence on hardware: `vrtd` is **socket-activated**
(`vrt/vrtd/src/main.c:configure_sockets()` → `sd_listen_fds_with_names()`), so
with no `vrtd.socket` unit it cannot be started at all — `sudo vrtd` exits 1 with
*"No socket provided"*, and `v80-smi list` reports
`VRTD NOT READY: Failed to open socket`.

**Resolved** by adopting upstream's packaging flow verbatim: `packaging/debian/`
is kept, and `scripts/{pconfigure,pbuild,pinstall,package-deb,package-ami}.sh` are
vendored from SLASH (two of them with small felix deltas, see §1). felix now
builds and installs the same 15 packages as upstream SLASH.

---

## 2. ADDED — new files in felix, not in SLASH

| File / dir | Why it exists |
|---|---|
| `…/AVED/fw/AMC/src/profiles/felix/` (10 files) | the felix AMC profile. **Only `profile_hal.h` is edited**; the other 9 (`profile_sensors.h`, `profile_pdr.h`, `profile_fal.c/.h`, `profile_bim.h`, `profile_debug_menu.c/.h`, `profile_muxed_device.h`, `profile_print.h`) are **cloned verbatim from v80** → still hold **V80 board data** (sensors/flash/PDR), to retarget to the FLX-155 board later |
| `linker/gen_slash_base.tcl` | generates `slash_base.bd` (partition boundary) for felix |
| `dfx_build/amc_pdi/felix_pdi_combine.bif` + `combine_amc_pdi.sh` | bootgen combine of felix base PDI + `amc.elf` → `felix_slash_amc.pdi` |
| `dfx_build/scripts/inject_boot_device_pcie.tcl` | **arms the SBI for host DFX.** Adds `boot_device { pcie }` to the base image's BIF and re-runs bootgen (called from `run_impl.tcl` after `write_device_image`). The felix CIPS, ported from VEK280 (SD/JTAG boot), lacked this directive that V80's PCIe-card PDI has; without it the host-streamed-PDI DMA hard-crashes the server (SBI stuck in JTAG mode → CPM uncorrectable error). Idempotent + self-verifying. Replaces the manual `scripts/diag/40_sbi_axi_slave.tcl` workaround. |
| `scripts/stage_artifacts.sh` | copies `run_impl.tcl` outputs (dcp/pdi/xsa) into the linker/AMC locations |
| `scripts/preflight_check.sh` | offline pre-hardware verification (DDR-route assertion, AMC load addr, combined-PDI contents, artifact freshness, host stack) — run before a JTAG session |
| `scripts/diag/` (6 files) | SBI/JTAG bring-up diagnostics: `40_sbi_axi_slave.tcl` (manual SBI arm — writes `SBI_CTRL 0xF1220004 = 0x9`, the fallback for `inject_boot_device_pcie.tcl`), `20_jtag_harvest.tcl` + `30_jtag_partial_load.tcl` (JTAG state/partial-PDI probes), `00_baseline.sh` + `10_after_crash.sh` (host PCIe state capture), `README.md` |
| `examples/00_axilite/no_program_test.cpp` | diagnostic: exercises the QDMA→NoC→DDR data path with `program=false` (no PMC boot-stream write), to isolate DMA-path faults from DFX-from-host |
| `examples/04_test_felix/` | **platform regression test + benchmark.** `04_test_felix <BDF> <vbin> [--quick]` → sectioned report: [0] program time/BDF/kernel clock, [1] QDMA round-trip correctness (fill→H2D→wipe host→D2H→compare, 4 KB…256 MB), [2] QDMA bandwidth sweep (1 MB…512 MB), [3] kernel↔DDR correctness (write-pattern + read-accumulate, cross-checked over QDMA), [4] kernel↔DDR bandwidth, [5] latency vs size, [6] pass/fail ledger + VERDICT. `--quick` trims sizes/iterations. Verified on hardware 2026-08-01: **11/11 full, 9/9 quick.** Its linear time-vs-size scaling in [5] is the check that distinguishes a real measurement from the constant-time signature of a kernel that never got loaded. |
| `build_all.sh` | one-command clean build (`hw`\|`fw`\|`sw`\|`all`) |
| `scripts/install_sw.sh` | installs the `deb/` packages with `--reinstall` (every package is version `0.1.0`, so a plain `apt-get install ./x.deb` reports "already newest" and **silently skips**) and then **verifies** the uapi header + dkms source actually landed before declaring it safe to power cycle. A partial install leaves the module and libslash built from different `slash_interface.h` revisions. |
| `scripts/uninstall_sw.sh` | scripted `DEPLOY_RUNBOOK.md` Part 0 — purge packages/DKMS/units/`/usr/local` leftovers, then verify clean. `--check` verifies only. |
| `FELIX_SLASH_PLAN.md`, `DEPLOY_RUNBOOK.md`, `BUILD_RUNBOOK.md`, `DRIVERS_BUILD_TEST_FLASH.md`, `CONCEPTS.md`, `linker/FELIX_LINKER_GUIDE.md`, `linker/FELIX_LINKER_PORT.md`, `PROJECT_CONTEXT.md`, `diagrams.md`, `plan_070726.md`, `change_log.md` | felix port documentation |
| `iprepo/` | felix `dfx_build` IP repo (`hw_discovery`, `uuid_rom`, `cmd_queue`, `axi4_full_passthrough`, `hbm_bandwidth`) |
| `dfx_build/` | **felix hardware build** — no SLASH counterpart (SLASH hw is in `AVED/hw/`); not diffed per scope note |

---

## 3. UNCHANGED — vendored from SLASH byte-for-byte (no felix edits)

| Component | Note |
|---|---|
| `driver/` (slash.ko + libslash) | device IDs 50b4/5/6 match → **0 changes** |
| `vrt/` (libvrt + vrtd), `smi/` | hardcoded map already matched → **0 changes** |
| `cmake/`, `packaging/debian/`, `submodules/qdma_drv/` | build infra / Debian packaging / DMA driver, unmodified |
| `scripts/{pconfigure,pbuild,pinstall}.sh` | vendored from SLASH byte-for-byte |
| `…/AVED/sw/AMI/` (ami.ko + ami_tool + AMI lib) | binds via VSEC discovery → **0 changes** |
| `…/AVED/fw/AMC/` (everything except `CMakeLists.txt` + `profiles/felix/`) | the AMC engine itself is unmodified |
| `linker/src/**` (except the 4 emit files above) | the v80++ engine is reused as-is |
| `linker/resources/system_map.xml` | **card-agnostic** — reused unchanged (values come from context) |
| `linker/resources/service_layer.tcl`, `sim/`, `sw_emu/`, `base/` (minus the 2 scripts) | reused |

---

## 4. IN SLASH, NOT in felix — skipped, with reason

| Path (in SLASH) | Why skipped |
|---|---|
| `linker/resources/submodules/AVED/hw/` | V80 hardware reference designs → felix uses its own `dfx_build/` |
| `linker/resources/submodules/AVED/deploy/`, `README.md`, `.git`, `.gitignore`, `fw/.gitkeep` | AVED submodule meta/deploy — not needed once vendored |
| `linker/resources/dcmac/` | DCMAC (600G Ethernet) networking — felix has none |
| `linker/resources/aved/` | V80 AVED XSA/linker resources — replaced by felix `dfx_build` outputs |
| `linker/resources/abstract_shell/` (SLASH's V80 one) | felix generates its own abstract shell (`stage_artifacts.sh` + `gen_slash_base.tcl`); gitignored, not committed |
| `submodules/v80-vitis-flow/` | a V80 Vitis-flow example — not needed for the felix build |
| `examples/{02_chain, 03_multiple_boards, 04_freq}` | additional SLASH example designs — not ported to felix (only `00_axilite` + `01_aximm` were retargeted; candidates for later) |
| `scripts/package-rpm.sh` | RPM packaging helper — felix is Debian-only (see `packaging/rpm/` above) |
| `.github/`, `.gitmodules`, `.readthedocs.yaml` | CI / submodule / RTD-docs config — felix is vendored (no submodules) and self-documented |
| `packaging/rpm/` | RPM packaging — felix targets Debian/Ubuntu only; `packaging/debian/` **is** kept and used (see §1a) |
| `scripts/{root-design-build,root-design-clean}.sh` | rebuild V80's static shell — felix's hardware is built in `dfx_build/` instead, and `package-deb.sh` sets `SLASH_PKG_SKIP_ROOT_DESIGN_BUILD=1` so they are never called |
| `scripts/{stress-test,test-examples,test-fresh-install,vrtd-debug}.sh` | upstream test/debug helpers — not ported (candidates for later) |
| `docs/`, `CONTRIBUTING.md`, `LICENSE`, `README.md`, `requirements.txt`, `my-notes.md`, `*.pdf` | SLASH project docs/scaffolding → felix has its own docs |
| `scripts/` (SLASH's) | SLASH's helper scripts → felix has its own `scripts/` + `build_all.sh` |
| `vivado.jou`, `vivado.log`, `amc_build.log`, `bsp_build.log` | stray logs |

---

## 5. Quick tally

- **Modified vs SLASH/AVED:** 8 linker files + 2 AMC files + 8 example files + 2 packaging scripts = **20**.
- **New felix source (non-doc, non-hw):** felix AMC profile (10, of which 1 edited);
  helper scripts `stage_artifacts.sh`, `build_all.sh`, `preflight_check.sh`,
  `gen_slash_base.tcl`, `dfx_build/amc_pdi/{combine_amc_pdi.sh,felix_pdi_combine.bif}`,
  `dfx_build/scripts/inject_boot_device_pcie.tcl`; `scripts/diag/` (6 files);
  `examples/00_axilite/no_program_test.cpp`.
- **Vendored from SLASH verbatim:** `scripts/{pconfigure,pbuild,pinstall}.sh`.
- **Unchanged (vendored):** all of `driver/ vrt/ smi/ cmake/ packaging/ qdma_drv/ AMI/`, most of `AMC/` and the linker.
- **The felix delta is small and localized** — because SLASH is board-discovered at
  runtime (VSEC) and the felix hardware port deliberately matched V80's device IDs and
  address map. The remaining "V80 leftovers" are the 9 cloned AMC profile files (board
  sensors/flash), which need FLX-155 data for full management (not for kernel swapping).
