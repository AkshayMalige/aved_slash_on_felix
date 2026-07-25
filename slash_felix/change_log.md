# CHANGELOG — felix SLASH vs upstream SLASH / AVED

File-by-file comparison of this felix repo against the base SLASH reference
(`Xilinx/AVED` submodule included). felix = SLASH ported from Alveo **V80**
(`xcv80`, HBM) to **FLX-155** (`xcvp1552`, 1× DDR, no HBM/DCMAC/SMBus).

**Scope note:** the hardware build (`dfx_build/`) is felix-specific and is **not**
diffed here (it has no SLASH counterpart — SLASH's hardware lives in `AVED/hw/`).
Build outputs (`*.o/*.ko/*.so`, `build/`, `amc_bsp/`, `ip/`, `*.dcp/*.pdi/*.xsa`)
are excluded from the comparison.

**Headline:** the drivers, host libraries and daemon are **byte-identical** to
SLASH (device IDs + address map were matched during the hardware port). All felix
deltas are concentrated in the **linker** (resources + a few emit modules), the
**AMC firmware profile**, and the **examples**.

---

## 1. MODIFIED — files changed from SLASH/AVED

| File | What changed | Why |
|---|---|---|
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
| `build_all.sh` | one-command clean build (`hw`\|`fw`\|`sw`\|`all`) |
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
- **New felix source (non-doc, non-hw):** felix AMC profile (10, of which 1 edited) + 4 helper scripts.
- **Vendored from SLASH verbatim:** `scripts/{pconfigure,pbuild,pinstall}.sh`.
- **Unchanged (vendored):** all of `driver/ vrt/ smi/ cmake/ packaging/ qdma_drv/ AMI/`, most of `AMC/` and the linker.
- **The felix delta is small and localized** — because SLASH is board-discovered at
  runtime (VSEC) and the felix hardware port deliberately matched V80's device IDs and
  address map. The remaining "V80 leftovers" are the 9 cloned AMC profile files (board
  sensors/flash), which need FLX-155 data for full management (not for kernel swapping).
