# SLASH / Versal NoC — Picture Book

Companion to `plan_070726.md`. Same facts, drawn instead of written.

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

So "`axi_noc_cips` = 4 SI / 2 MI / 7 NMI / 24 NSI" reads as:

```
                        axi_noc_cips (V80)
        4 entrances   ┌─────────────────────┐   7 tunnels out
   CIPS masters ────► │ S00..S03_AXI        │ ────► M00..M06_INI
                      │                     │       (to DDR4 x4, slash ctrl,
                      │      routing        │        service ctrl, clk regs)
        2 exits       │      crossbar       │   24 tunnels in
   mgmt slaves  ◄──── │ M00..M01_AXI        │ ◄──── S00..S23_INI
                      └─────────────────────┘       (from slash, HBM, SL2NOC,
                                                     M_VIRT)
```

---

## 2. The whole V80 design, one screen

```
 HOST (x86)
   │ PCIe Gen5 x8
   ▼
┌──────────────────────────────── STATIC REGION (never changes) ─────────────┐
│                                                                            │
│  ┌───────── aved ─────────┐         ┌──────────── noc ──────────────┐      │
│  │  cips (CPM5)           │         │                               │      │
│  │   PF0 mgmt   50b4      │ 4 AXI   │   axi_noc_cips                │      │
│  │   PF1 QDMA   50b5      ├────────►│   4SI 2MI 7NMI 24NSI          │      │
│  │   PF2 BAR    50b6      │  SI     │   (+HBM ctrl inside, V80 only)│      │
│  │                        │         │      │M00-03_INI              │      │
│  │  base_logic            │◄────────┤      ▼                        │      │
│  │   hw_discovery         │ M00_AXI │  axi_noc_mc_ddr4_0 ──► DRAM 0 │      │
│  │   uuid_rom             │ (mgmt)  │  axi_noc_mc_ddr4_1 ──► DRAM 1 │      │
│  │   gcq_m2r              │         └───────▲───────────▲──────────┘      │
│  │  clock_reset           │            NSI  │           │ NSI              │
│  └────────────────────────┘         tunnels │           │ tunnels          │
└─────────────────────────────────────────────┼───────────┼─────────────────┘
                                              │           │
        ══ DFX boundary (all crossings are INI tunnels) ══════════
                                              │           │
┌── service_layer (reconfigurable) ───────────┴──┐  ┌─────┴─ slash (reconfig.)─┐
│  SL2NOC_0..7   kernel→DDR sockets              │  │  kernel ctrl (AXI-Lite)  │
│  S/M_VIRT_0..3 runtime buffer paths            │  │  more kernel sockets     │
│  QDMA slave-bridge loopback                    │  │  (HBM sockets, V80 only) │
│  [DCMAC eth paths — V80 only]                  │  │                          │
│        ▲                                       │  │        ▲                 │
│        │ user HLS kernels plug in HERE         │  │        │ and HERE        │
└────────┴───────────────────────────────────────┘  └────────┴─────────────────┘
```

Static region = motherboard. service_layer + slash = the swappable card.

---

## 3. What the service layer is: a row of wall sockets

The shell is built *before* anyone knows what kernels will exist. So the
service layer provides fixed, pre-routed "sockets" the linker plugs kernels
into later:

```
            service_layer (inside)

   kernel plugs in here (left open in the shell!)
        │
        ▼  S00_AXI                                  M00_INI (tunnel)
   ┌─────────┐                                     to axi_noc_cips S12_INI
   │ sl2noc_0│ ────────────────────────────────────────────────► ... ► DDR4
   └─────────┘
   ┌─────────┐
   │ sl2noc_1│ ──► ...                              (8 identical sockets,
   └─────────┘                                       SL2NOC_0..7)
       ...

   VIRT path (x4)  — runtime buffer plumbing, pre-wired end to end:
   S_VIRT_0x ─►[noc]─►[reg_slice]─►[passthrough]─►[reg_slice]─►[noc]─► M_VIRT_x
   (tunnel in)          just pipeline stages, no logic          (tunnel out
                                                                 → DDR4)

   QDMA loopback  — same chain shape, one instance:
   S_QDMA_SLV_BRIDGE ─► ... ─► M_QDMA_SLV_BRIDGE ─► (tunnel) ─► back into CPM5
```

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

`v80++ link` edits only the reconfigurable containers:

```
   axi_noc_cips M04_INI ──tunnel──► slash/S_AXILITE_INI ─►[smartconnect]─┐
   (aperture 0x202_0000_0000)                                            │
                                                          s_axi_control ◄┘
   sl2noc_0/S00_AXI  ◄──────────────────────────────  vadd/m_axi_gmem
   (was left open — now plugged)
```

---

## 5. The four traffic flows of one vadd run

**(1) Host uploads buffers a,b  — `buffer.sync(HOST_TO_DEVICE)`, PF1/QDMA:**
```
host RAM ─► CPM5 QDMA ─► CPM_PCIE_NOC_0 ─► S00_AXI ─► M00_INI ─► ddr4 ─► DRAM
   (PCIe)      (in cips)                  (enter NoC)  (tunnel)   (MC)
```

**(2) Host programs + starts kernel — BAR write, PF2:**
```
host write ─► CPM_PCIE_NOC_1 ─► S01_AXI ─► M04_INI ─► slash ─► sc ─► s_axi_control
0x...202_xxxx                  (enter NoC)  (tunnel)                  a_ptr,b_ptr,
                                                                      c_ptr,n, START
```

**(3) Kernel computes — its own reads/writes:**
```
vadd/m_axi_gmem ─► sl2noc_0 S00_AXI ─► M00_INI ─► S12_INI ─► M02_INI ─► ddr4 ─► DRAM
                     (enter NoC)       (tunnel)  (axi_noc_cips) (tunnel)  (MC)
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

---

## 6. FELIX version of picture 2 (what you are building)

```
 HOST ── PCIe Gen5 x8 (GTYP banks 102-103)
   ▼
┌────────────────── static_region ───────────────────────────────┐
│ ┌── aved ──────────┐        ┌─────────────────────────┐        │
│ │ cips (CPM5 QDMA) │ 4 SI   │ axi_noc_cips            │        │
│ │ base_logic       ├───────►│ 4SI 1MI 2-3NMI 8-9NSI   │        │
│ │  (no SMBus)      │◄───────┤   no HBM keys           │        │
│ │ clock_reset      │ M00_AXI│   │ M00/M01_INI         │        │
│ └──────────────────┘        │   ▼                     │        │
│   NOC_CPM_PCIE_0 ◄─[axi_noc_qdma_ret]  axi_noc_ddr4   │        │
│   (QDMA loopback     ▲      │  (NUM_NSI=2) ──► DDR4   │        │
│    return — to add)  │      └───▲─────────────────────┘        │
└──────────────────────┼──────────┼──────────────────────────────┘
                       │INI       │INI ×8
┌── service_layer ─────┴──────────┴────────────────────┐
│ SL2NOC_0..7 (kernel sockets, S00_AXI left open)      │
│ S/M_VIRT_0..3                                        │
│ QDMA bridge chain                                    │
│ (no DCMAC, no dummy_noc, no QSFP — correct)          │
└──────────────────────────────────────────────────────┘
```

Differences vs V80, all intentional: 1 DDR4 controller instead of 2, no HBM
(so no 64 BLI pins, no dfx_decoupler), no DCMAC paths, no SMBus in
base_logic. Missing pieces = the boxes marked "to add" (QDMA loopback) plus
the wiring listed in plan_070726.md Phase A.
