################################################################
# 05_fix_static.tcl -- static_region correctness fixes to match V80 SLASH
# Run AFTER 00 (felix_cips static_region), BEFORE 10/20/30.
#   1. Configure hw_discovery BAR-layout table (was UNCONFIGURED in the
#      felix baseline -> driver could not discover uuid/gcq).
#   2. Enable DDR ECC init-scrub (V80 has it; 72-bit ECC DDR needs it).
#   3. Add host->DDR REMAP on axi_noc_cips/S00_AXI (V80 has it).
################################################################
current_bd_design [get_bd_designs felix_cips]

# --- 1. hw_discovery BAR-layout table (verbatim from V80 top.tcl) ---
set_property -dict [list \
  CONFIG.C_CAP_BASE_ADDR {0x600} \
  CONFIG.C_INJECT_ENDPOINTS {0} \
  CONFIG.C_MANUAL {1} \
  CONFIG.C_NEXT_CAP_ADDR {0x000} \
  CONFIG.C_NUM_PFS {1} \
  CONFIG.C_PF0_BAR_INDEX {0} \
  CONFIG.C_PF0_ENDPOINT_NAMES {0} \
  CONFIG.C_PF0_ENTRY_ADDR_0 {0x000001001000} \
  CONFIG.C_PF0_ENTRY_ADDR_1 {0x000001010000} \
  CONFIG.C_PF0_ENTRY_ADDR_2 {0x000008000000} \
  CONFIG.C_PF0_ENTRY_BAR_0 {0} \
  CONFIG.C_PF0_ENTRY_BAR_1 {0} \
  CONFIG.C_PF0_ENTRY_BAR_2 {0} \
  CONFIG.C_PF0_ENTRY_MAJOR_VERSION_0 {1} \
  CONFIG.C_PF0_ENTRY_MAJOR_VERSION_1 {1} \
  CONFIG.C_PF0_ENTRY_MAJOR_VERSION_2 {1} \
  CONFIG.C_PF0_ENTRY_MINOR_VERSION_0 {0} \
  CONFIG.C_PF0_ENTRY_MINOR_VERSION_1 {2} \
  CONFIG.C_PF0_ENTRY_MINOR_VERSION_2 {0} \
  CONFIG.C_PF0_ENTRY_RSVD0_0 {0x0} \
  CONFIG.C_PF0_ENTRY_RSVD0_1 {0x0} \
  CONFIG.C_PF0_ENTRY_RSVD0_2 {0x0} \
  CONFIG.C_PF0_ENTRY_TYPE_0 {0x50} \
  CONFIG.C_PF0_ENTRY_TYPE_1 {0x54} \
  CONFIG.C_PF0_ENTRY_TYPE_2 {0x55} \
  CONFIG.C_PF0_ENTRY_VERSION_TYPE_0 {0x01} \
  CONFIG.C_PF0_ENTRY_VERSION_TYPE_1 {0x01} \
  CONFIG.C_PF0_ENTRY_VERSION_TYPE_2 {0x01} \
  CONFIG.C_PF0_HIGH_OFFSET {0x00000000} \
  CONFIG.C_PF0_LOW_OFFSET {0x0100000} \
  CONFIG.C_PF0_NUM_SLOTS_BAR_LAYOUT_TABLE {3} \
  CONFIG.C_PF0_S_AXI_ADDR_WIDTH {32} \
] [get_bd_cells static_region/aved/base_logic/hw_discovery]

# --- 2. DDR ECC init-scrub ---
set_property CONFIG.MC_INIT_MEM_USING_ECC_SCRUB {true} \
  [get_bd_cells static_region/noc/axi_noc_mc_ddr4_0]

# --- 2b. single-channel DDR consolidation (per SLASH developer) ---
# FELIX has ONE DDR channel, so collapse the DDR MC to a single NoC port and a
# single input path (S01_INI -> MC_0), and map it into the DDR_CH2 region so the
# DDR base is 0x600_0000_0000 -- matching where V80's main DDR lived (software
# compatibility). All host+kernel traffic reaches DDR via axi_noc_cips/M01_INI.
set_property CONFIG.NUM_MCP {1} [get_bd_cells static_region/noc/axi_noc_mc_ddr4_0]
set_property -dict [list CONFIG.CONNECTIONS {}] \
  [get_bd_intf_pins static_region/noc/axi_noc_mc_ddr4_0/S00_INI]
set_property -dict [list CONFIG.CONNECTIONS \
  {MC_0 {read_bw {800} write_bw {800} read_avg_burst {4} write_avg_burst {4} initial_boot {true}}}] \
  [get_bd_intf_pins static_region/noc/axi_noc_mc_ddr4_0/S01_INI]
set_property CONFIG.MC_CHAN_REGION1 {DDR_CH2} [get_bd_cells static_region/noc/axi_noc_mc_ddr4_0]

# --- 2c. re-point the PMC and RPU DDR routes at the surviving door -----------
# CRITICAL: step 2b above disconnected axi_noc_cips/M00_INI (it fed
# axi_noc_mc_ddr4_0/S00_INI, now unconnected). But 00_felix_cips_static_region.tcl
# leaves the two PS-side NoC masters still pointing at that dead port:
#
#   S02_AXI (CATEGORY ps_pmc) CONNECTIONS { M02_INI, M00_INI }  <- M00_INI dead
#   S03_AXI (CATEGORY ps_rpu) CONNECTIONS { M00_INI }           <- its ONLY route
#
# Leaving it that way costs us BOTH of the PS's paths to DDR, and breaks the AMC
# in two separate ways:
#
#   1. The PLM cannot load amc.elf. That ELF has a 21.5 MB segment at
#      0x4000_0000 (LOAD ... 0x1500fe0, same as V80's), which the PMC must write
#      to DDR *as a bus master* through the NoC. With no route it hangs ->
#      "ERROR: [Xicom 50-197] PDI programming failure: PLM stalled during
#      programming" + "DONE bit: LOW". Note the BASE PDI programs fine, because
#      it only writes configuration (CFI/NPI), never DDR.
#   2. Even if it loaded, the AMC could not reach its shared-memory window at
#      HAL_RPU_SHARED_MEMORY_BASE_ADDR 0x3800_0000 -> AMI reports
#      "AMC Shared Memory ... Magic number: 0x0" / "AMC GCQ service not ready".
#
# V80 maps DDR into BOTH PMC_NOC_AXI_0 and LPD_AXI_NOC_0 (verified in the built
# V80 project, install.prj/.../top/top.bd `addressing`). felix must too.
#
# initial_boot {true} on the PMC path matters: DDR has to be up before the PLM
# reaches the RPU subsystem image.
set_property -dict [list CONFIG.CONNECTIONS \
  {M02_INI {read_bw {500} write_bw {500} initial_boot {true}} \
   M01_INI {read_bw {500} write_bw {500} initial_boot {true}}}] \
  [get_bd_intf_pins static_region/noc/axi_noc_cips/S02_AXI]
set_property -dict [list CONFIG.CONNECTIONS \
  {M01_INI {read_bw {500} write_bw {500} initial_boot {true}}}] \
  [get_bd_intf_pins static_region/noc/axi_noc_cips/S03_AXI]

# --- 3. host->DDR REMAP on the QDMA data path (S00_AXI) ---
# Host BAR window (hw_discovery ENTRY_ADDR_2 = 0x0800_0000, i.e. incoming
# 0x201_0800_0000, 128M) -> low DDR 0x0_0380_0000, exactly matching V80. FELIX
# DOES have a low DDR region (C0_DDR_LOW0 @ 0x0), so V80's destination is valid.
# Only the door changes vs V80: after the single-channel consolidation the live
# DDR path is M01_INI (M00_INI was disconnected), so target M01_INI, dest kept
# at V80's 0x0_0380_0000.
set_property -dict [list \
  CONFIG.REMAPS {M01_INI {{0x20108000000 0x00038000000 0x08000000}}} \
] [get_bd_intf_pins static_region/noc/axi_noc_cips/S00_AXI]

puts "FIX_STATIC_DONE"
