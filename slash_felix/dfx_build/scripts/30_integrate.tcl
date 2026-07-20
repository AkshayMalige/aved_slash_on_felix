current_bd_design [get_bd_designs felix_cips]

foreach p {M04_INI_0 M05_INI_0 S00_INI_1 S00_INI_3 S00_INI_4 S00_INI_5 S00_INI_6 S00_INI_7 M00_INI_0 M00_INI_1 M00_INI_2 M00_INI_3 M00_INI_4} {
    catch {delete_bd_objs [get_bd_intf_ports $p]}
}

current_bd_instance /static_region
foreach p {S00_INI_0 S01_INI_0 S02_INI_0 S03_INI_0 \
           S12_INI_0 S13_INI_0 S14_INI_0 S15_INI_0 S16_INI_0 S17_INI_0 S18_INI_0 S19_INI_0 \
           S20_INI_0 S21_INI_0 S22_INI_0 S23_INI_0} {
    connect_bd_intf_net [get_bd_intf_pins noc/$p] \
        [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 $p]
}
current_bd_instance /

create_bd_cell -type container -reference service_layer service_layer
create_bd_cell -type container -reference slash slash

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

connect_bd_intf_net [get_bd_intf_pins static_region/M05_INI_0] [get_bd_intf_pins service_layer/S_AXILITE_INI]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI]  [get_bd_intf_pins service_layer/S_VIRT_00]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI1] [get_bd_intf_pins service_layer/S_VIRT_01]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI2] [get_bd_intf_pins service_layer/S_VIRT_02]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI3] [get_bd_intf_pins service_layer/S_VIRT_03]
connect_bd_intf_net [get_bd_intf_pins static_region/M00_INI4] [get_bd_intf_pins service_layer/S_QDMA_SLV_BRIDGE]
foreach i {0 1 2 3 4 5 6 7} {
    set s [expr {$i+12}]
    connect_bd_intf_net [get_bd_intf_pins static_region/S${s}_INI_0] [get_bd_intf_pins service_layer/SL2NOC_${i}]
}
connect_bd_intf_net [get_bd_intf_pins static_region/S20_INI_0] [get_bd_intf_pins service_layer/M_VIRT_0]
connect_bd_intf_net [get_bd_intf_pins static_region/S21_INI_0] [get_bd_intf_pins service_layer/M_VIRT_1]
connect_bd_intf_net [get_bd_intf_pins static_region/S22_INI_0] [get_bd_intf_pins service_layer/M_VIRT_2]
connect_bd_intf_net [get_bd_intf_pins static_region/S23_INI_0] [get_bd_intf_pins service_layer/M_VIRT_3]
connect_bd_intf_net [get_bd_intf_pins service_layer/M_QDMA_SLV_BRIDGE] [get_bd_intf_pins static_region/S00_INI6]

connect_bd_net [get_bd_pins static_region/clk_out3]           [get_bd_pins slash/slash_clk]
connect_bd_net [get_bd_pins static_region/peripheral_aresetn2] [get_bd_pins slash/slash_resetn]
connect_bd_net [get_bd_pins static_region/clk_out2]           [get_bd_pins service_layer/service_clk]
connect_bd_net [get_bd_pins static_region/peripheral_aresetn1] [get_bd_pins service_layer/service_resetn]

foreach p {resetn_pl_periph_0 eos_0 clk_out1_0 clk_out1_1 clk_out1_2 Q_0 Q_1 pl3_resetn_0 pl3_ref_clk_0} {
    catch {delete_bd_objs [get_bd_ports $p]}
}

foreach pin {S00_INI S01_INI S02_INI S03_INI \
             S12_INI S13_INI S14_INI S15_INI S16_INI S17_INI S18_INI S19_INI \
             S20_INI S21_INI S22_INI S23_INI} {
    set_property -dict [list CONFIG.CONNECTIONS \
        {M01_INI {read_bw {100} write_bw {100}}}] \
        [get_bd_intf_pins static_region/noc/axi_noc_cips/$pin]
}
foreach i {0 1 2 3 4} {
    set_property -dict [list CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}}] \
        [get_bd_intf_pins static_region/virt_noc/axi_noc_${i}/S00_INI]
}

set_property -dict [list CONFIG.CONNECTIONS {M02_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_INI {read_bw {500} write_bw {500} initial_boot {true}} M06_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}} M04_INI {read_bw {500} write_bw {500} initial_boot {true}} M05_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_AXI {read_bw {5} write_bw {5}} M00_INI {read_bw {128} write_bw {128} initial_boot {false}}}] \
    [get_bd_intf_pins static_region/noc/axi_noc_cips/S00_AXI]
set_property -dict [list CONFIG.CONNECTIONS {M01_INI {read_bw {500} write_bw {500} initial_boot {true}} M06_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}} M03_INI {read_bw {500} write_bw {500} initial_boot {true}} M04_INI {read_bw {500} write_bw {500} initial_boot {true}} M05_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_AXI {read_bw {5} write_bw {5}} M00_INI {read_bw {500} write_bw {500} initial_boot {true}}}] \
    [get_bd_intf_pins static_region/noc/axi_noc_cips/S01_AXI]
set_property -dict [list CONFIG.CATEGORY {ps_rpu}] \
    [get_bd_intf_pins static_region/noc/axi_noc_cips/S03_AXI]

save_bd_design
puts "TOP_CELLS: [get_bd_cells /*]"
assign_bd_address
puts "ASSIGN_DONE"

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
puts "PIN_DONE"

validate_bd_design
puts "INTEGRATE_VALIDATE_DONE"

set_property -dict [list CONFIG.ENABLE_DFX {true}]     [get_bd_cells slash]
set_property -dict [list CONFIG.ENABLE_DFX {true}]     [get_bd_cells service_layer]
set_property -dict [list CONFIG.LOCK_PROPAGATE {true}] [get_bd_cells slash]
set_property -dict [list CONFIG.LOCK_PROPAGATE {true}] [get_bd_cells service_layer]
save_bd_design
validate_bd_design
puts "DFX_VALIDATE_DONE"

set outdir [file dirname [info script]]
current_bd_design [get_bd_designs service_layer]
write_bd_tcl -force [file join $outdir export_service_layer.tcl]
current_bd_design [get_bd_designs slash]
write_bd_tcl -force [file join $outdir export_slash.tcl]
current_bd_design [get_bd_designs felix_cips]
write_bd_tcl -force [file join $outdir export_felix_cips_top.tcl]
puts "EXPORT_DONE"
