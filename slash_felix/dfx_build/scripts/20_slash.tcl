
create_bd_design slash
current_bd_design slash

create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0 S_AXILITE_INI
foreach i {0 1 2 3} { create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M0${i}_INI }
foreach i {00 01 02 03} { create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL_VIRT_${i} }
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 QDMA_SLAVE_BRIDGE_0
create_bd_port -dir I -type clk slash_clk
set_property CONFIG.FREQ_HZ 200000000 [get_bd_ports slash_clk]
create_bd_port -dir I -type rst slash_resetn

foreach i {0 1 2 3} {
    set dn [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 ddr_noc_${i}]
    set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {0} CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}} $dn
    set_property -dict {CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} CONFIG.DEST_IDS {} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}} [get_bd_intf_pins ddr_noc_${i}/S00_AXI]
    set_property CONFIG.INI_STRATEGY {driver} [get_bd_intf_pins ddr_noc_${i}/M00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins ddr_noc_${i}/aclk0]
    connect_bd_intf_net [get_bd_intf_pins ddr_noc_${i}/M00_INI] [get_bd_intf_ports M0${i}_INI]
    set k [create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 ddr_bandwidth_${i}]
    connect_bd_intf_net [get_bd_intf_pins ddr_bandwidth_${i}/m_axi_gmem0] [get_bd_intf_pins ddr_noc_${i}/S00_AXI]
}

set vdst(0) SL_VIRT_00
set vdst(1) SL_VIRT_01
set vdst(2) SL_VIRT_02
set vdst(3) SL_VIRT_03
set vdst(4) QDMA_SLAVE_BRIDGE_0
foreach i {0 1 2 3 4} {
    set vn [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 virtnoc_${i}]
    set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {0} CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}} $vn
    set_property -dict {CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} CONFIG.DEST_IDS {} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}} [get_bd_intf_pins virtnoc_${i}/S00_AXI]
    set_property CONFIG.INI_STRATEGY {driver} [get_bd_intf_pins virtnoc_${i}/M00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins virtnoc_${i}/aclk0]
    connect_bd_intf_net [get_bd_intf_pins virtnoc_${i}/M00_INI] [get_bd_intf_ports $vdst($i)]
    set k [create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 traffic_virt_${i}]
    connect_bd_intf_net [get_bd_intf_pins traffic_virt_${i}/m_axi_gmem0] [get_bd_intf_pins virtnoc_${i}/S00_AXI]
}

set nc [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_ctrl]
set_property -dict {CONFIG.NUM_SI {0} CONFIG.NUM_MI {1} CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}} $nc
set_property -dict {CONFIG.APERTURES {{0x202_0000_0000 16M}} CONFIG.CATEGORY {pl}} [get_bd_intf_pins axi_noc_ctrl/M00_AXI]
set_property -dict {CONFIG.INI_STRATEGY {load} CONFIG.CONNECTIONS {M00_AXI {read_bw {5} write_bw {5} read_avg_burst {4} write_avg_burst {4}}}} [get_bd_intf_pins axi_noc_ctrl/S00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_ctrl/aclk0]
connect_bd_intf_net [get_bd_intf_ports S_AXILITE_INI] [get_bd_intf_pins axi_noc_ctrl/S00_INI]

set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0]
set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {9}} $sc
connect_bd_intf_net [get_bd_intf_pins axi_noc_ctrl/M00_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
foreach i {0 1 2 3} { connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M0${i}_AXI] [get_bd_intf_pins ddr_bandwidth_${i}/s_axi_control] }
foreach i {0 1 2 3 4} { set m [expr {$i+4}]; connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M0${m}_AXI] [get_bd_intf_pins traffic_virt_${i}/s_axi_control] }

set clkpins {}
foreach c [get_bd_cells *] {
    foreach p [get_bd_pins -quiet $c/aclk0] { lappend clkpins $p }
    foreach p [get_bd_pins -quiet $c/aclk]  { lappend clkpins $p }
    foreach p [get_bd_pins -quiet $c/ap_clk] { lappend clkpins $p }
}
connect_bd_net [get_bd_ports slash_clk] {*}$clkpins
set rstpins {}
foreach c [get_bd_cells *] {
    foreach p [get_bd_pins -quiet $c/aresetn] { lappend rstpins $p }
    foreach p [get_bd_pins -quiet $c/ap_rst_n] { lappend rstpins $p }
}
connect_bd_net [get_bd_ports slash_resetn] {*}$rstpins

save_bd_design
puts "SLASH_CELLS: [llength [get_bd_cells *]]"
validate_bd_design
puts "SLASH_VALIDATE_DONE"
