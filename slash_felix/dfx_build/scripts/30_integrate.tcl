################################################################
# 30_integrate.tcl -- instantiate slash + service_layer as BDC
# container cells in felix_cips and wire to static_region.
# Assumes felix_cips, service_layer, slash designs all exist in project.
################################################################
current_bd_design [get_bd_designs felix_cips]

# ---- delete the 13 top-level INI export ports so the static_region boundary
#      pins are free to connect to the BDC cells (they were exported off-chip
#      in the baseline as attachment stubs) ----
foreach p {M04_INI_0 M05_INI_0 S00_INI_1 S00_INI_3 S00_INI_4 S00_INI_5 S00_INI_6 S00_INI_7 M00_INI_0 M00_INI_1 M00_INI_2 M00_INI_3 M00_INI_4} {
    catch {delete_bd_objs [get_bd_intf_ports $p]}
}

# ---- expose noc INI boundary pins up to static_region boundary ----
#   S00_INI_0..S03_INI_0 = slash kernel->DDR data
#   S12_INI_0            = service_layer SL2NOC_0 (kernel data->DDR)
#   S20_INI_0..S23_INI_0 = service_layer M_VIRT
# (these are dangling inside static_region in the clean baseline)
#
# FELIX floorplan fix (2026-08-06): was S12_INI_0..S19_INI_0, one per
# service_layer SL2NOC port. Seven of those eight SL2NOC ports fed dead V80
# DCMAC-era self-test kernels and were costing this partition 7 NMU512 hard
# blocks -- see 10_service_layer.tcl. S13..S19 are left DANGLING inside
# static_region, exactly as the clean baseline has them; NUM_NSI on
# noc/axi_noc_cips is deliberately NOT reduced, because renumbering the S*_INI
# pins would break references throughout the 94k-line generated
# 00_felix_cips_static_region.tcl for no fabric saving. Unused NSI ports cost
# NoC IDs, which are budgeted explicitly via NOC_HIGH_ID_MIN/MAX in
# dfx_build/constraints/felix_pblock.xdc.
current_bd_instance /static_region
foreach p {S00_INI_0 S01_INI_0 S02_INI_0 S03_INI_0 \
           S12_INI_0 \
           S20_INI_0 S21_INI_0 S22_INI_0 S23_INI_0} {
    connect_bd_intf_net [get_bd_intf_pins noc/$p] \
        [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 $p]
}
current_bd_instance /

# ---- instantiate BDC container cells ----
create_bd_cell -type container -reference service_layer service_layer
create_bd_cell -type container -reference slash slash

# ---- wire slash ----
connect_bd_intf_net [get_bd_intf_pins static_region/M04_INI_0] [get_bd_intf_pins slash/S_AXILITE_INI]
connect_bd_intf_net [get_bd_intf_pins slash/M00_INI] [get_bd_intf_pins static_region/S00_INI_0]
connect_bd_intf_net [get_bd_intf_pins slash/M01_INI] [get_bd_intf_pins static_region/S01_INI_0]
connect_bd_intf_net [get_bd_intf_pins slash/M02_INI] [get_bd_intf_pins static_region/S02_INI_0]
connect_bd_intf_net [get_bd_intf_pins slash/M03_INI] [get_bd_intf_pins static_region/S03_INI_0]
connect_bd_intf_net [get_bd_intf_pins slash/SL_VIRT_00] [get_bd_intf_pins static_region/S00_INI1]
connect_bd_intf_net [get_bd_intf_pins slash/SL_VIRT_01] [get_bd_intf_pins static_region/S00_INI2]
connect_bd_intf_net [get_bd_intf_pins slash/SL_VIRT_02] [get_bd_intf_pins static_region/S00_INI3]
connect_bd_intf_net [get_bd_intf_pins slash/SL_VIRT_03] [get_bd_intf_pins static_region/S00_INI4]
connect_bd_intf_net [get_bd_intf_pins slash/QDMA_SLAVE_BRIDGE_0] [get_bd_intf_pins static_region/S00_INI5]

# ---- wire service_layer ----
connect_bd_intf_net [get_bd_intf_pins static_region/M05_INI_0] [get_bd_intf_pins service_layer/S_AXILITE_INI]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI]  [get_bd_intf_pins service_layer/S_VIRT_00]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI1] [get_bd_intf_pins service_layer/S_VIRT_01]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI2] [get_bd_intf_pins service_layer/S_VIRT_02]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI3] [get_bd_intf_pins service_layer/S_VIRT_03]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI4] [get_bd_intf_pins service_layer/S_QDMA_SLV_BRIDGE]
foreach i {0} {
    set s [expr {$i+12}]
    connect_bd_intf_net [get_bd_intf_pins static_region/S${s}_INI_0] [get_bd_intf_pins service_layer/SL2NOC_${i}]
}
connect_bd_intf_net [get_bd_intf_pins static_region/S20_INI_0] [get_bd_intf_pins service_layer/M_VIRT_0]
connect_bd_intf_net [get_bd_intf_pins static_region/S21_INI_0] [get_bd_intf_pins service_layer/M_VIRT_1]
connect_bd_intf_net [get_bd_intf_pins static_region/S22_INI_0] [get_bd_intf_pins service_layer/M_VIRT_2]
connect_bd_intf_net [get_bd_intf_pins static_region/S23_INI_0] [get_bd_intf_pins service_layer/M_VIRT_3]
connect_bd_intf_net [get_bd_intf_pins service_layer/M_QDMA_SLV_BRIDGE] [get_bd_intf_pins static_region/S00_INI6]

# ---- clocks / resets ----
connect_bd_net [get_bd_pins static_region/clk_out3]           [get_bd_pins slash/slash_clk]
connect_bd_net [get_bd_pins static_region/peripheral_aresetn2] [get_bd_pins slash/slash_resetn]
connect_bd_net [get_bd_pins static_region/clk_out2]           [get_bd_pins service_layer/service_clk]
connect_bd_net [get_bd_pins static_region/peripheral_aresetn1] [get_bd_pins service_layer/service_resetn]

# ---- remove dangling top-level ports that are NOT FELIX board signals.
#      The felix_cips base export left 9 static-region outputs exposed off-chip:
#        - 5 are pure dead-ends: eos_0, pl3_ref_clk_0, pl3_resetn_0,
#          resetn_pl_periph_0, clk_out1_2
#        - 4 (clk_out1_0/1, Q_0/1) sit on the nets that ALSO feed the slash /
#          service_layer clocks + resets connected just above; deleting the PORT
#          keeps those internal connections intact -- it only drops the redundant
#          off-chip export.
#      Leaving them makes write_device_image fail DRC NSTD-2 (undefined
#      IOSTANDARD, which CANNOT be waived) + UCIO-1 (no LOC). None are wired on
#      the FLX-155 board (0 hits in the board pinout), so they are removed. ----
foreach p {resetn_pl_periph_0 eos_0 clk_out1_0 clk_out1_1 clk_out1_2 Q_0 Q_1 pl3_resetn_0 pl3_ref_clk_0} {
    catch {delete_bd_objs [get_bd_ports $p]}
}

# ---- re-route kernel NSI ports to the real DDR path (M01_INI -> ddr4_0/S01_INI).
#      Baseline left them pointed at M02_INI/M03_INI, which are dead-ends
#      (leftover from V80's 2-DDR-controller design; FELIX has 1). Give real
#      bandwidth so the NoC compiler accepts the now-driven paths. ----
foreach pin {S00_INI S01_INI S02_INI S03_INI \
             S12_INI S13_INI S14_INI S15_INI S16_INI S17_INI S18_INI S19_INI \
             S20_INI S21_INI S22_INI S23_INI} {
    set_property -dict [list CONFIG.CONNECTIONS \
        {M01_INI {read_bw {100} write_bw {100}}}] \
        [get_bd_intf_pins static_region/noc/axi_noc_cips/$pin]
}
# ---- Option A bandwidth raise: the two ACTIVE kernel DDR ports (S00_INI=DDR0,
#      S01_INI=DDR1) get real bandwidth on the DDR door (M01_INI -> MC_1). The rest
#      stay minimal (unused / virt). Kept under MC_1's budget so the NoC solver fits. ----
foreach pin {S00_INI S01_INI} {
    set_property -dict [list CONFIG.CONNECTIONS \
        {M01_INI {read_bw {2500} write_bw {2500}}}] \
        [get_bd_intf_pins static_region/noc/axi_noc_cips/$pin]
}
# virt_noc retiming NoCs now carry slash SL_VIRT/QDMA traffic -> give bandwidth
foreach i {0 1 2 3 4} {
    set_property -dict [list CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}}] \
        [get_bd_intf_pins static_region/virt_noc/axi_noc_${i}/S00_INI]
}

# ---- host SI ports must reach DDR via M01_INI too (per SLASH developer),
#      since the single DDR channel is now fed only through M01_INI->S01_INI.
#      These are the exact CONNECTIONS the developer set on S00/S01_AXI. ----
set_property -dict [list CONFIG.CONNECTIONS {M02_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_INI {read_bw {500} write_bw {500} initial_boot {true}} M06_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}} M04_INI {read_bw {500} write_bw {500} initial_boot {true}} M05_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_AXI {read_bw {5} write_bw {5}} M00_INI {read_bw {5000} write_bw {5000} initial_boot {false}}}] \
    [get_bd_intf_pins static_region/noc/axi_noc_cips/S00_AXI]
set_property -dict [list CONFIG.CONNECTIONS {M01_INI {read_bw {500} write_bw {500} initial_boot {true}} M06_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}} M03_INI {read_bw {500} write_bw {500} initial_boot {true}} M04_INI {read_bw {500} write_bw {500} initial_boot {true}} M05_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_AXI {read_bw {5} write_bw {5}} M00_INI {read_bw {500} write_bw {500} initial_boot {true}}}] \
    [get_bd_intf_pins static_region/noc/axi_noc_cips/S01_AXI]
set_property -dict [list CONFIG.CATEGORY {ps_rpu}] \
    [get_bd_intf_pins static_region/noc/axi_noc_cips/S03_AXI]

save_bd_design
puts "TOP_CELLS: [get_bd_cells /*]"
assign_bd_address
puts "ASSIGN_DONE"

# ---- pin base_logic + clk-wizard addresses to the V80 SLASH layout so the
#      hw_discovery BAR table (configured in 05) matches the hardware, and
#      v80-smi set-frequency hits the right clk_wizard address ----
proc pin_seg {space segpat off rng} {
    set sp [get_bd_addr_spaces $space]
    foreach seg [get_bd_addr_segs -quiet -of_objects $sp -filter "NAME =~ $segpat"] {
        if {[catch {assign_bd_address -target_address_space $sp -offset $off -range $rng $seg -force} e]} {
            puts "PIN_WARN $space $segpat: $e"
        } else {
            puts "PIN_OK $segpat -> [get_property OFFSET $seg]"
        }
    }
}
foreach space {static_region/aved/cips/CPM_PCIE_NOC_0 static_region/aved/cips/CPM_PCIE_NOC_1} {
    pin_seg $space *hw_discovery*       0x0000020101000000 0x1000
    pin_seg $space *uuid_rom*           0x0000020101001000 0x1000
    pin_seg $space *gcq_m2r_S00*        0x0000020101010000 0x10000
    pin_seg $space *pdi_reset_gpio*     0x0000020101040000 0x10000
    pin_seg $space *clk_wizard_slash*   0x0000020400000000 0x10000
    pin_seg $space *clk_wizard_service* 0x0000020400010000 0x10000
}

# ---- DDR into the PMC and RPU address spaces (see 05_fix_static.tcl step 2c) --
# 05 re-pointed S02_AXI (ps_pmc) and S03_AXI (ps_rpu) at the live DDR door
# (M01_INI); the assign_bd_address above then finds DDR reachable from both and
# maps it automatically. Pin ONLY the low region, and only to guarantee it lands
# at 0x0 -- two firmware addresses are hard-coded into it:
#   * amc.elf's 21.5 MB LOAD segment at 0x4000_0000 (src/lscript.ld region
#     blp_axi_noc_mc_C0_DDR_LOW0x4, ORIGIN 0x40000000 LENGTH 0x3E800000). The PLM
#     writes this during boot; with no route: "PLM stalled during programming" /
#     DONE bit LOW.
#   * HAL_RPU_SHARED_MEMORY_BASE_ADDR 0x3800_0000 -- the AMC's runtime shared
#     memory; without it AMI reports "AMC GCQ service not ready".
# Both fit inside C0_DDR_LOW0 (0x0, 2G).
#
# Deliberately NOT pinning C0_DDR_CH2 (0x60_0000_0000): auto-assign already
# places it, nothing in the AMC uses it, and forcing it fails the LPD aperture
# (the R5 is 32-bit and cannot reach 0x60_0000_0000). V80 likewise maps CH2 into
# PMC_NOC_AXI_0 but NOT into LPD_AXI_NOC_0.
foreach space {static_region/aved/cips/PMC_NOC_AXI_0 static_region/aved/cips/LPD_AXI_NOC_0} {
    if {[llength [get_bd_addr_spaces -quiet $space]] == 0} {
        puts "PIN_WARN: address space $space not found -- PS-side DDR NOT mapped."
        continue
    }
    pin_seg $space *C0_DDR_LOW0* 0x00000000 0x80000000
}
puts "PIN_DONE"

# ---- verify the PS-side DDR route actually exists ---------------------------
# This is the exact gap that stalled the PLM on the first felix bring-up, so fail
# loudly at build time rather than discovering it again on the JTAG cable.
# Checks reachability AND that amc.elf's 0x4000_0000 load address really lands
# inside the mapped low region -- a segment at the wrong offset is just as fatal.
foreach space {static_region/aved/cips/PMC_NOC_AXI_0 static_region/aved/cips/LPD_AXI_NOC_0} {
    set sp [get_bd_addr_spaces -quiet $space]
    if {[llength $sp] == 0} {
        puts "ERROR: address space $space does not exist. The AMC will not load (PLM stall)."
        continue
    }
    set low [get_bd_addr_segs -quiet -of_objects $sp -filter {NAME =~ *C0_DDR_LOW0*}]
    if {[llength $low] == 0} {
        puts "ERROR: $space has NO C0_DDR_LOW0 segment. The AMC will not load (PLM stall)."
        continue
    }
    set off [get_property OFFSET [lindex $low 0]]
    set rng [get_property RANGE  [lindex $low 0]]
    # amc.elf: LOAD 0x40000000, MemSiz 0x1500fe0 (src/lscript.ld -> C0_DDR_LOW0)
    if {$off <= 0x40000000 && ($off + $rng) >= 0x41501000} {
        puts [format "DDR_OK %s C0_DDR_LOW0 @ 0x%llx range 0x%llx (covers amc.elf 0x40000000)" \
              $space $off $rng]
    } else {
        puts [format "ERROR: %s C0_DDR_LOW0 @ 0x%llx range 0x%llx does NOT cover amc.elf's 0x40000000 load." \
              $space $off $rng]
    }
}

validate_bd_design
puts "INTEGRATE_VALIDATE_DONE"

# ---- enable DFX on both BDC containers (mirrors enable_dfx_bdc.tcl) ----
set_property -dict [list CONFIG.ENABLE_DFX {true}]     [get_bd_cells slash]
set_property -dict [list CONFIG.ENABLE_DFX {true}]     [get_bd_cells service_layer]
set_property -dict [list CONFIG.LOCK_PROPAGATE {true}] [get_bd_cells slash]
set_property -dict [list CONFIG.LOCK_PROPAGATE {true}] [get_bd_cells service_layer]
save_bd_design
validate_bd_design
puts "DFX_VALIDATE_DONE"

# ---- export reproducible scripts for all three designs ----
set outdir [file dirname [info script]]
current_bd_design [get_bd_designs service_layer]
write_bd_tcl -force [file join $outdir export_service_layer.tcl]
current_bd_design [get_bd_designs slash]
write_bd_tcl -force [file join $outdir export_slash.tcl]
current_bd_design [get_bd_designs felix_cips]
write_bd_tcl -force [file join $outdir export_felix_cips_top.tcl]
puts "EXPORT_DONE"
