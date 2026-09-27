# SLASH / Versal NoC — Picture Book

Companion to `plan_070726.md`. Same facts, drawn instead of written.

> **Corrected 2026-09-27.** Earlier versions of §2–§6 said user HLS kernels plug
> into the *service layer* (`SL2NOC_x` "kernel sockets"). **That was wrong.**
> Kernels are linked **only into the `slash` partition** (the "user region"), and
> their DDR traffic leaves through `slash`'s own `ddr_noc_N` → `M0N_INI`, never
> through the service layer. Verified in `linker/src/main.py` (`build_slash_rm`
> always; `build_service_layer_rm` only when Ethernet is enabled),
> `linker/src/emit/hw/user_region/ddr_ctx.py` (`sp=…:DDRn` → `/ddr_noc_n/S00_AXI`),
> `linker/resources/bd_ports.txt`, and `dfx_build/scripts/{20_slash,30_integrate}.tcl`.

---

## 0. The three regions in one table

| Region | What it is | Rebuilt by `v80++ link`? | FELIX contents |
|---|---|---|---|
| `static_region` | PCIe/QDMA, PMC, NoC, DDR controller, mgmt. Never reconfigured. | never | `aved`, `noc`, `virt_noc`, `clk_rst_shell`, `axi_noc_1` |
| **`slash`** ("user region") | DFX partition = **where YOUR HLS kernels go** | **every link** | your kernels + `ddr_noc_0..3`, `noc_virt_00..03`, `qdma_slave_bridge_noc`, control smartconnect |
| `service_layer` ("service region") | DFX partition for *shell services*. On V80 = DCMAC Ethernet. | only if `[network]` enabled | 1 self-test `eth_0`→`sl2noc_0`, 4 VIRT relays, 1 HOST relay. **No user kernels. Never rebuilt on FELIX.** |

Naming trap: **SLASH** (capitals) is the whole project/shell; **`slash`** (lower
case) is the one DFX partition that holds kernels. Upstream calls its BD `slash_base`.

---

## 1. The four NoC port types

An `axi_noc` block-design cell is a *doorway* into one chip-wide hardened
network. Doors come in 4 flavors:

```
                normal AXI world                 NoC-internal world
              (real fabric wires)              (logical links, no wires)

   AXI master ──►  SI (Sxx_AXI)   ┌────────┐   NMI (Mxx_INI)  ──► to another
   (CIPS, kernel      "entrance"  │        │      "tunnel out"     noc cell
    m_axi)                        │  NoC   │
                                  │  cell  │
   AXI slave  ◄──  MI (Mxx_AXI)   │        │   NSI (Sxx_INI)  ◄── from another
   (registers,        "exit"      └────────┘      "tunnel in"      noc cell
    GPIO)
```

Rules of thumb:
- **SI / MI** = where real AXI wires attach (masters enter at SI, slaves sit at MI).
- **NSI / NMI** = tunnels between two `axi_noc` cells (INI = Inter-NoC Interface).
  An NMI of one cell always mates with an NSI of another. No fabric wires —
  the NoC compiler just learns "traffic may pass from cell A to cell B".
- Tunnels are what safely cross the DFX (partial-reconfig) boundary.
- Every **SI** instantiates one hard **NMU512** (NoC master unit). NMU512s exist
  only in clock-region columns X1/X3/X5/X7 on xcvp1552, so *the number of SI
  ports in a partition, not its LUT count, decides how big its pblock must be*
  (see `dfx_build/constraints/felix_pblock.xdc`).

So "`axi_noc_cips` = 4 SI / 2 MI / 7 NMI / 24 NSI" reads as:

```
                        axi_noc_cips (V80 and FELIX — same port counts)
        4 entrances   ┌─────────────────────┐   7 tunnels out
   CIPS masters ────► │ S00..S03_AXI        │ ────► M00..M06_INI
                      │                     │       (DDR doors, slash ctrl,
                      │      routing        │        service ctrl, clk regs)
        2 exits       │      crossbar       │   24 tunnels in
   mgmt slaves  ◄──── │ M00..M01_AXI        │ ◄──── S00..S23_INI
                      └─────────────────────┘       (slash DDR ports, HBM VNoC,
                                                     SL2NOC, M_VIRT returns)
```

---

## 2. The whole V80 design, one screen

```
 HOST (x86)
   │  PCIe Gen5 x8
   ▼
╔══ STATIC REGION (never reconfigured) ════════════════════════════════════════════════╗
║ ┌── aved ────────────────────┐        ┌── noc ───────────────────────────────────┐   ║
║ │ cips (PS + PMC + CPM5)     │        │ axi_noc_cips 4SI 2MI 7NMI 24NSI (+HBM)   │   ║
║ │   PF0 mgmt  50b4           │  4 SI  │   M00-03_INI ─► mc_ddr4_0/_1 ─► DRAM     │   ║
║ │   PF1 QDMA  50b5           │──────► │   M04_INI ─► slash ctrl      (0x202)     │   ║
║ │   PF2 BAR   50b6           │◄────── │   M05_INI ─► service ctrl    (0x203)     │   ║
║ │ base_logic (ROMs, gcq)     │M00_AXI │   S00-03_INI ◄─ slash DDR0-3             │   ║
║ │ clock_reset                │        │   S12-19 ◄─ SL2NOC, S20-23 ◄─ M_VIRT     │   ║
║ └────────────────────────────┘        └──────────────────────────────────────────┘   ║
║                                                                                      ║
║ virt_noc  : INI retimers, slash VIRT/HOST ports ─► service layer                     ║
║ axi_noc_1 : service-layer HOST relay ─► CPM5 ─► host RAM                             ║
║ dfx_decoupler : gates slash's 64 raw HBM AXI ports during reconfig                   ║
╚══════════════════════════════════════════════════════════════════════════════════════╝
      ══ DFX boundary: INI tunnels (+ decoupled raw HBM AXI on V80) ══
┌── slash = USER REGION ─────────────────────┐  ┌── service_layer = SERVICE REGION ──────┐
│ * YOUR HLS KERNELS LIVE HERE *             │  │ DCMAC 200G Ethernet (QSFP0-3)          │
│ s_axi_control ◄─ S_AXILITE_INI (0x202)     │  │ eth_N ─► sl2noc_N ─► SL2NOC_N ─► memory│
│ m_axi ─► ddr_noc_0..3 ─► M00..03_INI ─► DDR│  │   ctrl: S_AXILITE_INI (0x203)          │
│ m_axi ─► HBM_AXI_00..63 (raw) ─► HBM       │  │ VIRT relay ×4: S_VIRT ─► M_VIRT ─► mem │
│ m_axi ─► noc_virt_0x ─► SL_VIRT ─► (svc)   │  │ HOST relay ×1 ─► axi_noc_1 ─► host RAM │
│ m_axi ─► qdma_slave_bridge_noc ─► (svc)    │  │ relinked only when [network] is set    │
└────────────────────────────────────────────┘  └────────────────────────────────────────┘
```

Static region = motherboard. `slash` = the swappable accelerator card.
`service_layer` = a second, separately swappable card for *shell services*
(networking on V80). SL2NOC is the service layer's **own** path to memory, for its
own Ethernet logic — not a socket for user kernels.

Upstream note (SLASH_latest, 2026): SLASH now ships **two** static shells —
a *service shell* (the layout above) and a *compute shell* with **no
service_layer at all** (`linker/slashkit/resources/base/compute/scripts/top.tcl`;
`sp=…:VIRT` "requires shell=service"). FELIX has no DCMAC, so the compute shell is
the closer match — see §6.

---

## 3. What the service layer is (and is not)

It is **not** where kernels plug in. It is a second reconfigurable partition that
the shell reserves for *services* that sit between the user region and the
static shell:

```
            service_layer (FELIX, as built by dfx_build/scripts/10_service_layer.tcl)

   ① self-test + control terminator (1 pair kept of V80's 8):
      S_AXILITE_INI (0x203_…) ─► axi_noc_0 ─► smartconnect_0 ─► eth_0/s_axi_control
      eth_0 (hls hbm_bandwidth counter) ─► sl2noc_0 ─► SL2NOC_0 ─► axi_noc_cips S12_INI ─► DDR

   ② VIRT relay ×4 — slash's VIRT0..3 ports come through here:
      S_VIRT_0x ─►[axi_noc]─►[reg_slice]─►[axi4_full_passthrough]─►[reg_slice]─►[noc_virt_x]─► M_VIRT_x
      (from slash via             pure wires today: the slot where a         (→ axi_noc_cips
       static virt_noc)           service, e.g. address translation, could   S20-23_INI → DDR)
                                  be inserted without touching slash or static

   ③ HOST relay ×1 — slash's HOST port (card-initiated access to host RAM):
      S_QDMA_SLV_BRIDGE ─► same chain ─► M_QDMA_SLV_BRIDGE ─► static axi_noc_1 ─► NOC_CPM_PCIE_0 ─► PCIe ─► host RAM
```

On FELIX today **none of ①–③ carries user traffic**: every example uses
`sp=…:DDR0/DDR1`, which never enters the service layer. `linker/src/main.py` only
rebuilds the service layer when Ethernet is enabled, which FELIX cannot do, so the
base-PDI copy is the only one that ever runs.

Why the service layer mattered for kernel size: it was *pblock-sized by NoC
masters*. V80's eight `sl2noc_N` plus the five relay NoCs (`noc_virt_0..4`) needed
13 NMU512s, forcing `pblock_serviclayer` to 38.8% of the die at 2.2% LUT use. Cutting it to one pair
(6 NMU512s) shrank it to 10.3%, and that space went to `slash`: **33.6% → 44.7%
(Phase A) → 70.5% (Phase B)**. See `PHASE_A_RESUME.md`.

`axi4_full_passthrough` (`iprepo/`) is literally `assign m_axi_* = s_axi_*` —
no logic.

---

## 4. Example: `vadd(a, b, c, n)` — how it attaches

An HLS kernel compiles to two kinds of ports:

```
              ┌──────────── vadd ────────────┐
   control ──►│ s_axi_control                │
   (AXI-Lite  │   0x00 CTRL (start/done)     │
    slave)    │   0x10 a_ptr  0x1C b_ptr     │
              │   0x28 c_ptr  0x34 n         │
              │                              │
              │ m_axi_gmem  (AXI master) ────┼──► reads a,b / writes c
              └──────────────────────────────┘
```

`v80++ link` rebuilds **only the `slash` container** around the kernel:

```
   axi_noc_cips M04_INI ──tunnel──► slash/S_AXILITE_INI ─► axi_noc_0 ─► smartconnect ─┐
   (aperture 0x202_0000_0000)                                                          │
                                                                        s_axi_control ◄┘
   config.cfg:  sp=vadd_0.m_axi_gmem:DDR0
        vadd/m_axi_gmem ─► slash/ddr_noc_0/S00_AXI ─► slash/M00_INI ─► (static) DDR
        (several ports on one DDRn → linker inserts a smartconnect reduction tree)
```

Other `sp=` targets the FELIX linker accepts (`linker/resources/bd_ports.txt`):
`DDR0..3` → `ddr_noc_0..3`; `VIRT0..3` → `noc_virt_00..03` (via the service-layer
relay); `HOST` → `qdma_slave_bridge_noc` (card → host RAM). Only `DDR0`/`DDR1` are
proven on hardware.

---

## 5. The four traffic flows of one vadd run (FELIX)

**(1) Host uploads buffers a,b — `buffer.sync(HOST_TO_DEVICE)`, PF1/QDMA:**
```
host RAM ─► CPM5 QDMA ─► CPM_PCIE_NOC_x ─► S0x_AXI ─► M01_INI ─► mc_ddr4_0 S01_INI ─► DIMM
   (PCIe)      (in cips)                  (enter NoC)  (tunnel)   (the only live MC port)
```

**(2) Host programs + starts kernel — BAR write, PF2 BAR0:**
```
host write ─► CPM_PCIE_NOC_x ─► S0x_AXI ─► M04_INI ─► slash ─► sc ─► s_axi_control
0x...202_xxxx                  (enter NoC)  (tunnel)                  a_ptr,b_ptr,
                                                                      c_ptr,n, START
```

**(3) Kernel computes — its own reads/writes (no service layer, no host):**
```
vadd/m_axi_gmem ─► slash/ddr_noc_0 S00_AXI ─► slash/M00_INI ─► axi_noc_cips S00_INI ─► M01_INI ─► mc_ddr4_0 S01_INI ─► DIMM
                     (NMU inside slash pblock)   (tunnel)        (static crossbar)     (tunnel)
   reads a[i], b[i]  ◄──── data returns along the same path ────
   writes c[i]       ────►
```

**(4) Host polls DONE (same path as 2), then downloads c (same path as 1,
reversed).**

Key point: routes are **not** switched at runtime. The NoC compiler reads
every `CONFIG.CONNECTIONS {... read_bw {500} write_bw {500}}` property at
build time, computes static routes + QoS through the hardened network, and
bakes them into the PDI. `read_bw/write_bw` = requested bandwidth (MB/s) for
that source→destination pair, used for arbitration/QoS — not a hard limit
switch.

All DDR traffic — host DMA, every kernel port — funnels through the single live
door `M01_INI → S01_INI → MC_0`, measured at ~13.4 GB/s aggregate.

---

## 6. FELIX version of picture 2 (what is actually built)

```
 HOST (x86)
   │  PCIe Gen5 x8
   ▼
╔══ static_region ═════════════════════════════════════════════════════════════════════╗
║ ┌── aved ────────────────────┐        ┌── noc ───────────────────────────────────┐   ║
║ │ cips (PS + PMC + CPM5)     │        │ axi_noc_cips  4SI 2MI 7NMI 24NSI         │   ║
║ │   PF0 mgmt  50b4           │  4 SI  │   M01_INI ─► axi_noc_mc_ddr4_0 ─► DIMM   │   ║
║ │   PF1 QDMA  50b5           │──────► │   M04_INI ─► slash ctrl      (0x202)     │   ║
║ │   PF2 BAR   50b6           │◄────── │   M05_INI ─► service ctrl    (0x203)     │   ║
║ │ base_logic (no SMBus)      │M00_AXI │   S00-03_INI ◄─ slash DDR0-3             │   ║
║ │ clock_reset                │        │   S12,S20-23_INI ◄─ service layer        │   ║
║ └────────────────────────────┘        └──────────────────────────────────────────┘   ║
║                                                                                      ║
║ axi_noc_mc_ddr4_0: NUM_MCP=1, only S01_INI carries traffic, 32 GB                    ║
║ virt_noc  : 5 INI retimers, slash VIRT/HOST ports ─► service layer                   ║
║ axi_noc_1 : service-layer HOST relay ─► NOC_CPM_PCIE_0 ─► host RAM                   ║
╚══════════════════════════════════════════════════════════════════════════════════════╝
      ══ DFX boundary: every crossing is a NoC INI tunnel ══
┌── slash = USER REGION (70.5% of die) ──────┐  ┌── service_layer (10.3% of die) ────────┐
│ * YOUR HLS KERNELS LIVE HERE *             │  │ eth_0 self-test ─► sl2noc_0 ─► SL2NOC_0│
│ s_axi_control ◄─ S_AXILITE_INI (0x202)     │  │   ctrl: S_AXILITE_INI (0x203)          │
│ m_axi ─► ddr_noc_0..3 ─► M00..03_INI ─► DDR│  │ VIRT relay ×4: S_VIRT ─► M_VIRT ─► DDR │
│ m_axi ─► noc_virt_0x ─► SL_VIRT ─► (svc)   │  │ HOST relay ×1 ─► axi_noc_1 ─► host RAM │
│ m_axi ─► qdma_slave_bridge_noc ─► (svc)    │  │ no DCMAC, no QSFP, no user kernels     │
│ rebuilt by every v80++ link                │  │ never relinked on FELIX                │
└────────────────────────────────────────────┘  └────────────────────────────────────────┘
```

Differences vs V80, all intentional: 1 DDR4 controller instead of 2, no HBM
(so no 64 BLI pins, no dfx_decoupler), no DCMAC, only 1 of 8 `sl2noc`/`eth` pairs,
no SMBus in base_logic. `axi_noc_cips` keeps V80's port counts; unused ports
(M02/M03_INI, S13–S19_INI) are left dangling rather than renumbered
(`30_integrate.tcl`).

Direction for the upstream re-sync: because FELIX's service layer carries no user
traffic, upstream's **compute shell** (no service_layer; `slash` is the only RP)
is the natural template for the next FELIX shell. That would free the remaining
10.3% for kernels and drop 6 NMU512s. It would also remove `VIRT0..3`, which no
FELIX example uses.
