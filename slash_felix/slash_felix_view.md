# SLASH-on-FELIX — The Visual Guide

> A single, picture-first walk through the whole system: **hardware → firmware →
> software → drivers**, how data actually moves, what every block is for, which
> patch fixed what, and where FELIX deliberately differs from the V80 original.
>
> Companion to `PROJECT_CONTEXT.md` (facts), `diagrams.md` (picture book),
> `DEPLOY_RUNBOOK.md` (how to run). This file is the "read it and you understand
> the machine" document.
>
> Board: **FELIX FLX-155**, Versal Premium `xcvp1552-vsva3340-2MHP-e-S`.
> Origin: AMD/Xilinx **SLASH** shell, ported from Alveo **V80** (`xcv80`, HBM).

---

## 0. The 10,000-foot view — four layers, one job

The whole point of SLASH: **let a host program load and run a custom compute
kernel on the FPGA over PCIe, with the kernel reading/writing the card's DDR —
and swap that kernel at runtime without rebooting the card.**

```
   ┌─────────────────────────────────────────────────────────────────────┐
   │  YOUR APP        offset.start();  dma.start();  buffer.sync();        │  software
   ├─────────────────────────────────────────────────────────────────────┤
   │  VRT / vrtd      C++ runtime + daemon: owns the card, does DMA,       │  (host x86)
   │  libslash        programs kernels, arbitrates access                  │
   ├─────────────────────────────────────────────────────────────────────┤
   │  slash.ko        Linux kernel driver: QDMA engine + BAR MMIO + reset  │  driver
   │  (+ ami.ko)      ami.ko = board management (sensors/flash), optional   │
   ├───────────────────────────────════ PCIe Gen5 x8 ════──────────────────┤
   │  CPM5 / QDMA     PCIe endpoint + DMA engine (hard block in Versal)    │  hardware
   │  NoC + DDR MC    on-chip network routes traffic to DDR & to kernels   │  (the FPGA)
   │  slash region    ← your HLS kernel is spliced in HERE (DFX)           │
   ├─────────────────────────────────────────────────────────────────────┤
   │  PLM  (on PMC)   boots the PDI, does partial reconfiguration          │  firmware
   │  AMC  (on R5)    board housekeeping, host command queue (GCQ)         │  (on-chip CPUs)
   └─────────────────────────────────────────────────────────────────────┘
```

Three PCIe **Physical Functions (PFs)** are how the host sees the card — remember
these, they recur everywhere:

| PF   | Device ID | Linux driver  | Purpose                                   |
|------|-----------|---------------|-------------------------------------------|
| PF0  | `0x50b4`  | `ami`         | **Management** — sensors, flash, VSEC ROM |
| PF1  | `0x50b5`  | `slash_qdma`  | **Data** — QDMA DMA engine (host↔DDR)     |
| PF2  | `0x50b6`  | `slash_ctl`   | **Control** — BAR MMIO (kernel regs, reset) |

---
---

# PART I — THE HARDWARE

## I.1 Device floorplan: one static motherboard + swappable cards

A Versal device running SLASH is split into a **static region** (built once, never
changes) and two **DFX partitions** (`slash` and `service_layer`) that can be
reconfigured at runtime by streaming a *partial* PDI.

```
 HOST (x86)
   │  PCIe Gen5 x8   (GTYP banks 102-103)
   ▼
╔══════════════════════ STATIC REGION (felix_cips_i, never reconfigured) ═══════════╗
║                                                                                   ║
║   ┌──────────── aved ────────────┐        ┌──────────── noc ─────────────────┐    ║
║   │  cips  (PS + PMC + CPM5)      │  4 SI  │  axi_noc_cips                    │    ║
║   │    PF0 mgmt  50b4             ├───────►│    (routing crossbar)            │    ║
║   │    PF1 QDMA  50b5   ◄──DMA──► │        │      │                           │    ║
║   │    PF2 BAR   50b6             │◄───────┤      ▼  NMI tunnels              │    ║
║   │                              M00_AXI   │   axi_noc_ddr4 ──────► DDR4 DIMM │    ║
║   │  base_logic                  │ (mgmt)  │   (1 controller, 72-bit ECC)     │    ║
║   │    hw_discovery (VSEC ROM)   │         │                                  │    ║
║   │    uuid_rom                  │         │   axi_noc_qdma_ret (loopback)    │    ║
║   │    gcq_m2r (command queue)   │         └───▲──────────▲──────────▲────────┘    ║
║   │  clock_reset (kernel clks)   │        NSI  │          │ NSI ×8   │ loopback    ║
║   └──────────────────────────────┘   tunnels  │          │          │             ║
╚═══════════════════════════════════════════════╪══════════╪══════════╪════════════╝
                                                 │          │          │
      ══ DFX BOUNDARY — every crossing is a NoC "INI tunnel" (safe across reconfig) ══
                                                 │          │          │
┌──────────── slash (DFX) ───────────┐  ┌────────┴──────────┴──────────┴────────────┐
│  kernel control (AXI-Lite regs)    │  │            service_layer (DFX)             │
│  kernel DDR sockets                │  │  SL2NOC_0..7   kernel→DDR data sockets     │
│  QDMA_SLAVE_BRIDGE_0               │  │  S/M_VIRT_0..3 runtime buffer paths        │
│      ▲                             │  │  QDMA slave-bridge loopback chain          │
│      │  YOUR HLS KERNEL lands here │  │      ▲                                      │
└──────┴─────────────────────────────┘  └──────┴──────────────────────────────────────┘
        (v80++ linker splices it in)            (linker wires kernel m_axi here)
```

**Why this split?** The static region holds everything the host needs to *stay
connected* — the PCIe endpoint, DMA, DDR, management. If that were ever
reconfigured, the PCIe link would drop and the host would crash. So kernels only
ever land in the DFX partitions, which are reconfigured *through* the static
region's PCIe/PMC path while the link stays up. That is the entire trick that
makes "swap the kernel without rebooting" possible.

---

## I.2 The NoC: four kinds of "door"

Almost everything on-chip is wired through the **NoC** (Network-on-Chip) — a
hardened, chip-wide packet network. You don't run AXI wires across the die; you
attach to a NoC "door" and the NoC compiler bakes static routes into the PDI.

```
              normal AXI world                    NoC-internal world
           (real fabric/hard wires)             (logical links, no wires)

  AXI master ──►  SI  (Sxx_AXI)   ┌─────────┐   NMI (Mxx_INI) ──► to another
  (CPM5, kernel     "entrance"    │         │       "tunnel out"     NoC cell
   m_axi)                         │  axi_   │
                                  │  noc    │
  AXI slave  ◄──  MI  (Mxx_AXI)   │  cell   │   NSI (Sxx_INI) ◄── from another
  (registers,       "exit"        └─────────┘       "tunnel in"     NoC cell
   GPIO)
```

- **SI / MI** — where *real* AXI attaches. Masters enter at **SI**; slaves
  (register blocks) sit behind **MI**.
- **NSI / NMI** — **INI = Inter-NoC Interface**, a logical tunnel between two NoC
  cells. An **NMI** on one cell always mates to an **NSI** on another. No wires —
  just "traffic may flow A→B." **These tunnels are what cross the DFX boundary
  safely** (raw AXI can't; that's why HBM on V80 needed a `dfx_decoupler` and INI
  paths don't).

Read `axi_noc_cips = 4 SI / 1-2 MI / N NMI / M NSI` as: 4 masters enter, a couple
of register exits, N tunnels out (to DDR / kernel-control apertures), M tunnels in
(from the kernel sockets returning traffic).

---

## I.3 CIPS-AVED — the "processor system" and PCIe front door

`aved` bundles the hard Versal blocks plus the SLASH management logic:

```
┌───────────────────────────────── aved ──────────────────────────────────┐
│                                                                          │
│  ┌───────────────────────── cips (versal_cips) ────────────────────────┐ │
│  │                                                                     │ │
│  │   PS  ── Cortex-A72 APU + Cortex-R5F RPU  (RPU runs the AMC fw)      │ │
│  │   PMC ── Platform Management Controller: runs the PLM, owns boot,    │ │
│  │          does partial reconfiguration, owns the SBI (slave boot)     │ │
│  │   CPM5 ─ the PCIe/QDMA hard block:                                   │ │
│  │            • PCIe Gen5 x8 endpoint (the 3 PFs)                       │ │
│  │            • QDMA engine (host↔DDR memory-mapped DMA)                │ │
│  │            • CPM_PCIE_NOC_0  → QDMA *data* master into the NoC       │ │
│  │            • CPM_PCIE_NOC_1  → BAR/*mgmt* master into the NoC        │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌── base_logic ──┐   ┌── clock_reset ──┐                                │
│  │ hw_discovery   │   │ kernel clocks   │  (host-programmable clk wizard  │
│  │ uuid_rom       │   │ + resets        │   feeding the slash region)     │
│  │ gcq_m2r        │   └─────────────────┘                                │
│  └────────────────┘                                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

The **CPM5** is the single most important block: it *is* the PCIe endpoint the
host enumerates, and it contains the DMA engine. It presents **two** masters to
the NoC — one for bulk DMA data (`CPM_PCIE_NOC_0`) and one for register/BAR
traffic (`CPM_PCIE_NOC_1`). Keep those two names in mind; the data-flow diagrams
below are just "which of these two doors did the traffic come in?"

The **PMC** matters for the *reprogramming* path (§I.11) — it owns the **SBI**,
the interface that accepts a host-streamed partial PDI.

---

## I.4 base_logic — management ROMs + the command queue (GCQ)

```
┌───────────────────────── base_logic ──────────────────────────┐
│                                                               │
│  hw_discovery  ── a PCIe **VSEC** ROM. Tells the host, by     │
│    (BAR layout)   reading a capability, where things live:    │
│                   entry 0 = uuid, entry 1 = gcq,              │
│                   entry 2 = gcq_payload (128 MB DDR window).  │
│                   ONLY `ami` reads this; slash/vrt hardcode   │
│                   the map (see §IV).                          │
│                                                               │
│  uuid_rom      ── the shell's build UUID (identity check).    │
│                                                               │
│  gcq_m2r       ── "**G**eneric **C**ommand **Q**ueue,          │
│    (cmd_queue)    management-to-RPU". A mailbox: the host      │
│                   (via ami) writes commands, the AMC firmware  │
│                   on the R5 reads them and acts (flash, load   │
│                   PDI, sensors). See §III.                     │
└───────────────────────────────────────────────────────────────┘
```

### What is the GCQ *for*?
It is the **host ↔ on-card-firmware doorbell**. The host cannot call functions on
the R5; instead it drops a command descriptor in the GCQ ring and rings a
doorbell. The AMC firmware polls the ring, executes (e.g. "program this region",
"read this sensor"), and writes a completion back. Bulk payloads too large for the
ring travel through the **128 MB gcq_payload window in DDR** (host writes to a BAR
aperture that the NoC remaps into low DDR — see §I.9 / §II). On FELIX first-light
the GCQ is **idle**: kernel-swap can be done purely by the PMC/SBI path without
AMC involvement.

---

## I.5 The NoC cells and what each one routes

```
                       ┌───────────────── axi_noc_cips ─────────────────┐
   CPM_PCIE_NOC_0 ───► │ S00_AXI                                        │
   (QDMA data)         │                     routing                    │
   CPM_PCIE_NOC_1 ───► │ S01_AXI             crossbar         M00_AXI   │───► base_logic
   (BAR / mgmt)        │                                     (mgmt regs)│     mgmt aperture
   PMC (ps_pmc)   ───► │ S02_AXI                                        │     0x201_0000_0000/32M
   RPU (ps_rpu)   ───► │ S03_AXI     M01_INI ──► (to DDR) ──────────────│
                       │             M0x_INI ──► slash control aperture │
                       │             M0x_INI ──► service ctrl aperture  │
                       │  NSI ◄── kernel sockets return here (SL2NOC…)  │
                       └────────────────────────────────────────────────┘
                                          │ M01_INI (tunnel)
                                          ▼
                       ┌───────────────── axi_noc_ddr4 ─────────────────┐
                       │  1 memory controller, NUM_MCP=4, NUM_NSI=2     │
                       │  DDR4-2666V, 72-bit ECC, UDIMM, 2-rank, row17  │
                       │  S00 = host traffic   S01 = kernel traffic     │───► DDR DIMM
                       └────────────────────────────────────────────────┘

                       ┌──────────── axi_noc_qdma_ret ──────────────────┐
                       │ QDMA slave-bridge loopback: kernel/service      │
                       │ traffic that must re-enter CPM5 comes back here │───► CPM_PCIE_NOC
                       └────────────────────────────────────────────────┘
```

- **axi_noc_cips** — the central crossbar. All four CIPS masters enter here; it
  fans traffic out to DDR (via `M01_INI`), to the kernel-control apertures, and
  back from the kernel sockets.
- **axi_noc_ddr4** — the DDR memory controller front-end. Its two NSIs split
  **host** traffic (buffer up/download) from **kernel** traffic (compute) so they
  don't contend on the same port.
- **axi_noc_qdma_ret** — the return path so a kernel/bridge master can loop back
  *into* the host's PCIe space (used by the QDMA slave-bridge chain).

---

## I.6 service_layer — a row of pre-wired "wall sockets"

The shell is built **before anyone knows what kernel will run.** So it exposes
fixed, pre-routed sockets that the linker plugs a kernel into later.

```
                     service_layer (DFX partition)

   kernel's m_axi plugs in here  ◄── left OPEN in the shell
        │
        ▼ S00_AXI                                        M00_INI (tunnel)
   ┌──────────┐                                          to axi_noc_cips NSI
   │ sl2noc_0 │ ───────────────────────────────────────────────────► … ► DDR4
   └──────────┘         (8 identical sockets: SL2NOC_0 … SL2NOC_7)

   VIRT path ×4 — runtime buffer plumbing, pre-wired end to end:
   S_VIRT_x ─►[noc]─►[reg_slice]─►[axi4_full_passthrough]─►[reg_slice]─►[noc]─► M_VIRT_x
   (tunnel in)              just pipeline stages, no compute            (tunnel out → DDR)

   QDMA loopback — same chain shape, one instance:
   S_QDMA_SLV_BRIDGE ─► … ─► M_QDMA_SLV_BRIDGE ─► (tunnel) ─► axi_noc_qdma_ret ─► CPM5
```

`axi4_full_passthrough` (one of the custom IPs in `iprepo/`) is exactly what it
sounds like — a transparent AXI pipeline stage. It exists so the DFX container has
a real, place-able cell holding the route open across the boundary; it does no
computation.

---

## I.7 slash — where your kernel actually lives

The `slash` DFX partition holds the kernel's **control** interface (its AXI-Lite
register block, reached through a NoC control aperture) and additional DDR
sockets. On V80 this also held dozens of HBM sockets; on FELIX those are gone.

```
              ┌──────────── your HLS kernel ────────────┐
  control ──► │ s_axi_control                            │   AXI-Lite slave:
  (from NoC   │   0x00 CTRL(start/done)  0x10 arg0 …     │   host pokes args + START,
   aperture)  │                                          │   polls DONE
              │ m_axi_gmem  ────────────────────────────┼─► reads/writes DDR
              └──────────────────────────────────────────┘   via an SL2NOC socket
```

An HLS kernel always compiles to these two port kinds: a **control** slave (how
the host starts it and passes pointers/scalars) and one or more **m_axi** masters
(how it streams data to/from DDR). The linker's whole job is to connect those two
kinds of port to the sockets above (§IV.3).

---

## I.8 The address map (what the host sees)

This is the FELIX host-side view (through CPM5's PCIe→NoC apertures). Matches V80
except for the single DDR channel.

```
  host physical addr        size   what it is
  ──────────────────────────────────────────────────────────────────────
  0x0201_0000_0000          32M    mgmt aperture (base_logic) ┐
    0x0201_0100_0000         4K      hw_discovery (VSEC ROM)   │ M00_AXI
    0x0201_0100_1000         4K      uuid_rom                  │ exit of
    0x0201_0101_0000         4K      gcq_m2r  (command queue)  │ axi_noc_cips
    0x0201_0104_0000         4K      pcie_mgmt_pdi_reset_gpio ┘
  0x0201_0800_0000         128M    gcq_payload window  ──REMAP──► DDR 0x0380_0000
  0x0202_0000_0000          16M    slash control aperture (kernel regs)
  0x0203_0000_0000           4M    service_layer control aperture
  0x0050_0800_0000           2G    DDR (low window)      ┐ the card's DRAM,
  0x0060_0000_0000          32G    DDR (high window)     ┘ reached via axi_noc_ddr4
```

The `gcq_payload` **REMAP** is the clever bit: a host BAR window at
`0x201_0800_0000` is silently redirected by the NoC into *low DDR*
(`0x0380_0000`), giving AMI↔AMC a 128 MB shared buffer without a dedicated BAR.

---

## I.9 DATA FLOW #1 — host uploads a buffer to DDR

`in_buff.sync(HOST_TO_DEVICE)` → PF1/QDMA, memory-mapped DMA:

```
 host RAM ─PCIe─► CPM5 QDMA ─► CPM_PCIE_NOC_0 ─► axi_noc_cips S00_AXI
                                                        │
                                                 M01_INI (tunnel)
                                                        ▼
                                          axi_noc_ddr4 S00 (host port) ─► DDR DIMM
```

## I.10 DATA FLOW #2 — host programs & starts the kernel

BAR write → PF2, register poke into the slash control aperture:

```
 host write ─PCIe─► CPM5 (BAR) ─► CPM_PCIE_NOC_1 ─► axi_noc_cips S01_AXI
 (0x0202_….)                                              │
                                                   M0x_INI (tunnel, 0x202 aperture)
                                                          ▼
                                                slash ─► s_axi_control
                                                         (arg ptrs, scalars, START=1)
```

## I.11 DATA FLOW #3 — the kernel computes (DDR → kernel → DDR)

Once started, the kernel drives its own `m_axi` reads/writes; **the host is not
involved.** This is the path your `offset`/`dma` kernels use:

```
  kernel m_axi_gmem ─► SL2NOC_x S00_AXI ─► M00_INI ─► axi_noc_cips NSI
       reads input[i]        (enter NoC)   (tunnel)        │
       writes output[i]                              M01_INI (tunnel)
                                                            ▼
                                             axi_noc_ddr4 S01 (kernel port) ─► DDR
       ◄──────────────── data returns along the same route ────────────────►
```

Two chained kernels (like `01_aximm`: `offset → dma`) add an **AXI-Stream**
directly between them in the fabric, so intermediate data never touches DDR:

```
  DDR0 ─►[offset]═══AXI-Stream═══►[dma]─► DDR1
         val=in*m+n     (on-chip)  passthrough
```

## I.12 DATA FLOW #4 — the reprogramming path (DFX from host) ★

This is the crown jewel and the source of every crash we debugged. To swap the
kernel, the host streams a **partial PDI** to the PMC's **Slave Boot Interface**,
and the PLM does partial reconfiguration of the `slash` partition — while PCIe
stays up.

```
  vrtd designWriteFile()               ┌──────────── PMC ────────────┐
      │  partial PDI bytes             │                             │
      ▼  (QDMA H2C, memory-mapped)     │   SBI  (Slave Boot Iface)   │
 host RAM ─PCIe─► CPM5 QDMA ─────────► │   must be AXI_SLAVE+ENABLE   │
                  write to             │   (SBI_CTRL 0xF1220004=0x9)  │
                  0x1_0210_0000        │        │                     │
                  (slave-boot stream)  │        ▼                     │
                                       │   PLM partial reconfig ──────┼─► slash region
                                       │   loads new kernel bits      │   reprogrammed
                                       └─────────────────────────────┘
```

**If the SBI is NOT armed** (left in JTAG mode, `SBI_CTRL=0x4`), that write hits a
disabled interface → AXI error → **CPM uncorrectable error → the PCIe endpoint
dies → the host hard-crashes with nothing logged.** That was the "server reboots"
bug. The fix (§II.4) arms the SBI in the PDI so this path just works.

---
---

# PART II — THE PATCHES (which patch fixes what)

Four FELIX-specific changes turn "V80 shell" into "works on FLX-155." Each maps to
a specific script and a specific symptom.

## II.1 Single-DDR consolidation — `05_fix_static.tcl`
**What:** V80 has **two** DDR controllers (`axi_noc_mc_ddr4_0/_1`); FELIX has one
DIMM. The patch disconnects `axi_noc_cips/M00_INI → mc_ddr4_0` and routes *all*
DDR traffic through a single controller via `M01_INI`.
**Why:** FLX-155 has one DDR4-2666 72-bit ECC UDIMM, not V80's two Components
channels. **Symptom if wrong:** no DRAM / address-map errors.

## II.2 PMC & RPU DDR route fix — `05_fix_static.tcl` + `30_integrate.tcl`
**What:** After II.1, the PMC master (`S02_AXI`, `ps_pmc`) and RPU master
(`S03_AXI`, `ps_rpu`) still listed only the now-dead `M00_INI` as their route to
DDR. The patch re-points both to `M01_INI` (with `initial_boot {true}`), and
`30_integrate.tcl` maps DDR into `PMC_NOC_AXI_0` / `LPD_AXI_NOC_0`.
**Why:** the PLM must load `amc.elf` (~21.5 MB) into DDR at boot, and the AMC needs
its shared-memory base in DDR. **Symptom if wrong:** *"PLM stalled during
programming, DONE bit LOW"* when JTAG-programming the AMC PDI; AMC shared memory
reads `0x0`.

```
  BEFORE (broken)                    AFTER (05_fix_static)
  S02_AXI(PMC) ─► M00_INI ✗ dead     S02_AXI(PMC) ─► M01_INI ─► DDR ✓
  S03_AXI(RPU) ─► M00_INI ✗ dead     S03_AXI(RPU) ─► M01_INI ─► DDR ✓
```

## II.3 GCQ_PAYLOAD 128 MB remap — `05_fix_static.tcl`
**What:** `CONFIG.REMAPS {M01_INI {{0x20108000000 0x00038000000 0x08000000}}}` —
host BAR window `0x201_0800_0000` (128 M) → low DDR `0x0380_0000`.
**Why:** gives AMI↔AMC their shared payload buffer (hw_discovery VSEC entry 2).
Identical target to V80; only the door changed (`M00_INI`→`M01_INI`) for the
single channel.

## II.4 Arm the SBI for host DFX — `inject_boot_device_pcie.tcl` (from `run_impl.tcl`) ★
**What:** Vivado's `write_device_image` does **not** emit `boot_device { pcie }`
for the FELIX CIPS (it was ported from the VEK280 eval board, which boots from
SD/JTAG). This script injects that one BIF directive and re-runs `bootgen`, so the
PLM brings the **SBI up in AXI-slave mode** at boot.
**Why:** without it the host-streamed-PDI path (§I.12) crashes the machine.
**Symptom if wrong:** running any example (`00_axilite`, `01_aximm`) instantly
reboots/hangs the whole server. **Verified fix:** with it, `SBI_CTRL` reads `0x9`
at boot and both examples pass with no runtime workaround.

```
  V80 (flash boot)          FELIX before patch         FELIX after patch
  BIF has boot_device{pcie} BIF lacks it (VEK280 heritage)  injected + re-bootgen
  → SBI armed from flash     → SBI stuck JTAG (0x4)     → SBI armed (0x9) ✓
```

> Manual fallback: `scripts/diag/40_sbi_axi_slave.tcl` writes `SBI_CTRL=0x9` over
> xsdb at runtime. Only needed if you ever run a base PDI built without II.4.

## II.5 (Not a patch — a hardware lesson) DDR reseat / `PLM 0x32B`
A `PLM Error Major 0x32B` (`XLOADER_ERR_DEFERRED_CDO_PROCESS`) on JTAG-program
with `DDRMC0` red / `F0_DQS_GATE_CAL` failing is **not** a build bug — it's
marginal DDR DQS-gate calibration (a loose/under-seated DIMM). Reseat the DIMM.
It was briefly *mis*blamed on II.4; proven independent (the DDR config CDOs are
byte-identical between working and failing builds). If `0x32B` recurs, suspect the
DIMM/PDN margin, not `boot_device`.

---
---

# PART III — THE FIRMWARE

Two processors inside the Versal run firmware. Neither is your application; both
are infrastructure.

## III.1 PLM on the PMC — the boot & reconfig manager

```
  power on ─► PMC ROM ─► loads PLM ─► PLM loads the PDI, partition by partition:
     [Boot PDI Load: Started]
       Image#1 SUB_SYSTEM_BOOT   (NoC/PL config)
       Image#2 lpd               (low-power domain, PSM firmware)
       Image#3 cpm               (CPM5 / PCIe — the endpoint comes alive here)
       Image#4 fpd               (full-power domain)
       Image#5 CONFIG_MASTER     (the big PL/CFI partition — 5.7 MB)
       Image#6 rpu_subsystem     (AMC firmware handed to the R5)
     [Boot PDI Load: Done]  ─► DONE bit HIGH
```

The PLM also owns **partial reconfiguration**: when the host streams a partial PDI
to the SBI (§I.12), it is the PLM that receives it and reprograms the `slash`
partition. You read PLM progress/errors over JTAG with `xsdb`'s `plm log` — that
log *survives host crashes*, which is how we caught the `CPM_NCR` error and the
`0x32B` cal failure.

## III.2 AMC on the R5 — board housekeeping + command queue

```
  ┌──────────────── AMC (Cortex-R5F, FreeRTOS) ────────────────┐
  │  polls the GCQ ring  ◄── host (ami) posts commands         │
  │  services:  sensors · flash program · PDI download · ...    │
  │  uses HAL_RPU_SHARED_MEMORY_BASE in DDR (needs II.2 route)  │
  └─────────────────────────────────────────────────────────────┘
```

Built from the AVED submodule (`linker/resources/submodules/AVED/fw/AMC`) with a
FELIX **profile** (`profiles/felix/`) that removes SMBus (FLX-155 has none) and
fixes the GCQ base-address symbol. The `amc.elf` is combined into the deployable
base PDI by `combine_amc_pdi.sh` (`felix_pdi_combine.bif`) so it boots on the R5 as
`Image#6` above.

**Important:** for the **kernel-swap demo, the AMC is not required** — the DFX-from-
host path goes host→QDMA→SBI→PLM and never rings the GCQ. AMC/AMI matter for full
board *management* (sensors, flash), which is a later phase.

---
---

# PART IV — THE SOFTWARE & DRIVERS

## IV.1 The host stack, top to bottom

```
   your app  (examples/01_aximm.cpp)
      │  vrt::Device / vrt::Kernel / vrt::Buffer
      ▼
   libvrt            C++ user API (buffers, kernels, sync)
      │
   libvrtd (+ ++)    marshals requests to the daemon
      │  AF_UNIX socket
      ▼
   vrtd  (daemon)    OWNS the card: does DMA, programs PDIs, arbitrates
      │              multi-process access, enforces role policy
   libslash          thin userspace lib over the driver ioctls
      │  ioctl / mmap
      ▼
   slash.ko          kernel driver: QDMA engine + BAR MMIO + SBR reset
      │  PCIe
      ▼
   the card
```

**Why a daemon?** The card is a single shared resource. `vrtd` is the one process
that holds it open, so multiple apps can't corrupt each other's DMA or half-program
the fabric. It is **socket-activated** by systemd — that is why, when removing
drivers, stopping `vrtd.service` isn't enough; you must also stop `vrtd.socket`
(which can re-spawn it).

## IV.2 The drivers — one module, several PCI bindings

`slash.ko` is a **single module** that registers **multiple PCI drivers**, one per
PF-role, plus char devices:

```
  slash.ko  ├─ slash_qdma  ──bound to──► PF1 (50b5)   DMA engine   /dev/slash_qdma_ctl0
            ├─ slash_ctl   ──bound to──► PF2 (50b6)   BAR MMIO     /dev/slash_ctl0
            └─ slash_hotplug                          hotplug      /dev/slash_hotplug

  ami.ko    └─ ami         ──bound to──► PF0 (50b4)   management (sensors/flash/VSEC)
```

This is why unloading needs care: the module's refcount = number of bound PFs +
open char devs. `rmmod slash` fails with *"in use"* until you unbind the PFs
(`/sys/bus/pci/drivers/slash_qdma/unbind`, `…/slash_ctl/unbind`) or the driver is
otherwise released. No process needs to be killed — the binding itself holds it.

**Key fact:** `slash`/`vrt` use a **hardcoded** address map (DDR `0x600…`, SBR gpio,
clk BAR4) — they do **not** read the hw_discovery VSEC. Only `ami` reads the VSEC.
So the FELIX port had to make the hardware match V80's device IDs and map exactly,
rather than teaching the driver a new layout. That is why the drivers build for
FELIX with **zero source changes**.

## IV.3 The linker (`v80++ link`) — how a kernel becomes a `.vbin`

The linker is the toolchain that splices your compiled HLS kernel into the `slash`
DFX partition and emits the partial PDI the host streams.

```
  HLS source (offset.cpp, dma.cpp)
      │  Vitis HLS (v++ -c --mode hls) on part xcvp1552
      ▼
  component.xml (packaged IP per kernel)
      │
  linker/src/main.py  link  -c config.cfg  -p hw
      │   • reads config.cfg: nk= (how many of each kernel),
      │     sp= (which m_axi → which DDR), stream_connect= (kernel→kernel)
      │   • opens the abstract shell (place context from run_impl.tcl)
      │   • wires kernel control → slash control aperture,
      │     kernel m_axi → SL2NOC sockets
      │   • runs place & route of ONLY the slash partition
      ▼
  aximm_hw.vbin   ── the partial PDI + metadata the host loads
```

`config.cfg` is the contract. For `01_aximm`:
```
  nk=offset:1:offset_0        # instantiate 1 "offset" kernel
  nk=dma:1:dma_0              # instantiate 1 "dma" kernel
  stream_connect=offset_0.axis_out:dma_0.axis_in   # on-chip AXI-Stream
  sp=offset_0.m_axi_gmem0:DDR0    # offset reads DDR0
  sp=dma_0.m_axi_gmem0:DDR1       # dma writes DDR1
```

The **abstract shell** (`abs_shell_slash.dcp`, produced by `run_impl.tcl` and
staged by `stage_artifacts.sh`) is what lets the linker place-and-route just the
kernel partition without rebuilding the whole static region — it's the "place
context" describing everything around the DFX hole.

## IV.4 What happens when you run the example

```
  ./01_aximm 01:00.1 aximm_hw.vbin
     │
     1. vrt::Device(bdf, vbin)   ─► vrtd programs aximm_hw.vbin into slash (DFX, §I.12)
     2. in_buff.sync(H2D)        ─► QDMA DMA host→DDR0            (§I.9)
     3. offset.setArg / dma.setArg, .start()  ─► BAR writes to control regs (§I.10)
     4. kernels run              ─► DDR0 ─offset─►stream─►dma─► DDR1   (§I.11)
     5. out_buff.sync(D2H)       ─► QDMA DMA DDR1→host
     6. verify out[i]==in[i]*m+n ─► "Test passed"
```

"Test passed" means: the PDI programmed, both kernels ran on real silicon, the DMA
round-trip worked, and every output element equaled `in*3+2`. All five layers of
the stack exercised end to end.

---
---

# PART V — FELIX vs V80: what differs and why

| Area | V80 (original) | FELIX (this port) | Why |
|---|---|---|---|
| **Memory** | 2× DDR4-3200 Components channels **+ HBM** | 1× DDR4-2666 72-bit ECC UDIMM | FLX-155 has one DIMM, no HBM |
| **axi_noc_cips** | 4 SI / 2 MI / 7 NMI / 24 NSI, **HBM ctrl inside (64 BLI)** | 4 SI, fewer MI/NMI/NSI, **no HBM keys** | no HBM → drop 64 BLI pins + VNoC sockets |
| **DFX decoupler** | present (gates 64 raw HBM AXI across DFX) | **none** | INI tunnels don't need gating; only HBM did |
| **DDR controllers** | `mc_ddr4_0` + `mc_ddr4_1` | one `axi_noc_ddr4` | single channel (§II.1) |
| **PMC/RPU→DDR** | DDR mapped into both PMC & LPD NoC | had to be **re-added** (§II.2) | single-DDR consolidation severed it |
| **DDR params** | Components, RANK 1, ROW 16 | UDIMM, RANK 2, ROW 17 | FLX-155 DIMM (proven in step1_vp1552) |
| **Networking** | DCMAC 600G Ethernet in service_layer | **stripped** | FLX-155 has no DCMAC |
| **SMBus** | `axi_smbus_rpu` in base_logic | **removed** | FLX-155 has no SMBus |
| **Boot** | flash (OSPI) → `boot_device{pcie}` in PDI | JTAG bring-up → **inject** `boot_device{pcie}` (§II.4) | CIPS ported from VEK280, never declared PCIe boot |
| **Drivers/vrt** | — | **byte-identical, 0 source changes** | HW matched V80 device IDs + map on purpose |

The guiding principle of the whole port: **make the FELIX hardware look like V80 to
the software** (same device IDs `50b4/5/6`, same address map), so the drivers,
libvrt, vrtd and the linker port with minimal or zero changes. Everything that
*couldn't* be identical (one DDR, no HBM/DCMAC/SMBus, JTAG boot) is where the
FELIX-specific patches live — and they're all localized in `dfx_build/` and the
AMC profile.

---

## Appendix — where each thing lives in the repo

| Layer | Path |
|---|---|
| Static region + DFX BD scripts | `dfx_build/scripts/*.tcl` (`00_…static_region`, `05_fix_static`, `10_service_layer`, `20_slash`, `30_integrate`, `run_all`, `run_impl`) |
| Custom IP (hw_discovery, uuid_rom, cmd_queue/gcq, axi4_full_passthrough) | `iprepo/` |
| Constraints (pins, pblocks) | `dfx_build/constraints/*.xdc` |
| SBI arming | `dfx_build/scripts/inject_boot_device_pcie.tcl`; fallback `scripts/diag/40_sbi_axi_slave.tcl` |
| AMC PDI combine | `dfx_build/amc_pdi/combine_amc_pdi.sh` + `felix_pdi_combine.bif` |
| AMC firmware (FELIX profile) | `linker/resources/submodules/AVED/fw/AMC/{CMakeLists.txt, src/profiles/felix/}` |
| Linker | `linker/src/`, resources in `linker/resources/` |
| Drivers | `driver/` (slash + qdma), AMI under `linker/resources/submodules/AVED/sw/AMI/` |
| Host libs / daemon | `vrt/` (libvrt, libvrtd, vrtd), `smi/` (v80-smi) |
| Examples | `examples/{00_axilite,01_aximm}/` |
| Deploy / runbooks | `DEPLOY_RUNBOOK.md`, `PROJECT_CONTEXT.md`, `diagrams.md`, this file |
```
