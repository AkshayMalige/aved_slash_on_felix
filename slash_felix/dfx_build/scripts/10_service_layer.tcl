
create_bd_design service_layer
current_bd_design service_layer

create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0 S_AXILITE_INI
foreach i {0 1 2 3 4 5 6 7} { create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_${i} }
foreach i {00 01 02 03}     { create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0 S_VIRT_${i} }
foreach i {0 1 2 3}         { create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_VIRT_${i} }
create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0 S_QDMA_SLV_BRIDGE
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_QDMA_SLV_BRIDGE
create_bd_port -dir I -type clk service_clk
set_property CONFIG.FREQ_HZ 300000000 [get_bd_ports service_clk]
create_bd_port -dir I -type rst service_resetn

foreach i {0 1 2 3 4 5 6 7} {
    set sl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_${i}]
    set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {0} CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}} $sl
    set_property -dict {CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} CONFIG.DEST_IDS {} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}} [get_bd_intf_pins sl2noc_${i}/S00_AXI]
    set_property CONFIG.INI_STRATEGY {driver} [get_bd_intf_pins sl2noc_${i}/M00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins sl2noc_${i}/aclk0]
    connect_bd_intf_net [get_bd_intf_pins sl2noc_${i}/M00_INI] [get_bd_intf_ports SL2NOC_${i}]

    set eth [create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_${i}]
    connect_bd_intf_net [get_bd_intf_pins eth_${i}/m_axi_gmem0] [get_bd_intf_pins sl2noc_${i}/S00_AXI]
}

set n0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0]
set_property -dict {CONFIG.NUM_SI {0} CONFIG.NUM_MI {1} CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}} $n0
set_property -dict {CONFIG.APERTURES {{0x203_0000_0000 4M}} CONFIG.CATEGORY {pl}} [get_bd_intf_pins axi_noc_0/M00_AXI]
set_property -dict {CONFIG.INI_STRATEGY {load} CONFIG.CONNECTIONS {M00_AXI {read_bw {5} write_bw {5} read_avg_burst {4} write_avg_burst {4}}}} [get_bd_intf_pins axi_noc_0/S00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_0/aclk0]
connect_bd_intf_net [get_bd_intf_ports S_AXILITE_INI] [get_bd_intf_pins axi_noc_0/S00_INI]

set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0]
set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {8}} $sc
connect_bd_intf_net [get_bd_intf_pins axi_noc_0/M00_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
foreach i {0 1 2 3 4 5 6 7} {
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M0${i}_AXI] [get_bd_intf_pins eth_${i}/s_axi_control]
}

foreach i {0 1 2 3} {
    set vi [expr {$i+1}]
    set rn [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_${vi}]
    set_property -dict {CONFIG.NUM_SI {0} CONFIG.NUM_MI {1} CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}} $rn
    set_property -dict {CONFIG.APERTURES {{0x0 64G}} CONFIG.CATEGORY {pl}} [get_bd_intf_pins axi_noc_${vi}/M00_AXI]
    set_property -dict {CONFIG.INI_STRATEGY {load} CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}} [get_bd_intf_pins axi_noc_${vi}/S00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_${vi}/aclk0]
    set rsa [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_${i}_a]
    set pt  [create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 vpt_${i}]
    set_property CONFIG.AXI_DATA_WIDTH {128} $pt
    set rsb [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_${i}_b]
    set nv [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_${i}]
    set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {0} CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}} $nv
    set_property -dict {CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}} [get_bd_intf_pins noc_virt_${i}/S00_AXI]
    set_property CONFIG.INI_STRATEGY {driver} [get_bd_intf_pins noc_virt_${i}/M00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins noc_virt_${i}/aclk0]
    connect_bd_intf_net [get_bd_intf_ports S_VIRT_0${i}] [get_bd_intf_pins axi_noc_${vi}/S00_INI]
    connect_bd_intf_net [get_bd_intf_pins axi_noc_${vi}/M00_AXI] [get_bd_intf_pins vrs_${i}_a/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins vrs_${i}_a/M_AXI] [get_bd_intf_pins vpt_${i}/s_axi]
    connect_bd_intf_net [get_bd_intf_pins vpt_${i}/m_axi] [get_bd_intf_pins vrs_${i}_b/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins vrs_${i}_b/M_AXI] [get_bd_intf_pins noc_virt_${i}/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins noc_virt_${i}/M00_INI] [get_bd_intf_ports M_VIRT_${i}]
}

set n5 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_5]
set_property -dict {CONFIG.NUM_SI {0} CONFIG.NUM_MI {1} CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}} $n5
set_property -dict {CONFIG.APERTURES {{0x0 64G}} CONFIG.CATEGORY {pl}} [get_bd_intf_pins axi_noc_5/M00_AXI]
set_property -dict {CONFIG.INI_STRATEGY {load} CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}} [get_bd_intf_pins axi_noc_5/S00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_5/aclk0]
set qrsa [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 qrs_a]
set qpt  [create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 qpt]
set_property CONFIG.AXI_DATA_WIDTH {128} $qpt
set qrsb [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 qrs_b]
set nv4 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_4]
set_property -dict {CONFIG.NUM_SI {1} CONFIG.NUM_MI {0} CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}} $nv4
set_property -dict {CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}} [get_bd_intf_pins noc_virt_4/S00_AXI]
set_property CONFIG.INI_STRATEGY {driver} [get_bd_intf_pins noc_virt_4/M00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins noc_virt_4/aclk0]
connect_bd_intf_net [get_bd_intf_ports S_QDMA_SLV_BRIDGE] [get_bd_intf_pins axi_noc_5/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_5/M00_AXI] [get_bd_intf_pins qrs_a/S_AXI]
connect_bd_intf_net [get_bd_intf_pins qrs_a/M_AXI] [get_bd_intf_pins qpt/s_axi]
connect_bd_intf_net [get_bd_intf_pins qpt/m_axi] [get_bd_intf_pins qrs_b/S_AXI]
connect_bd_intf_net [get_bd_intf_pins qrs_b/M_AXI] [get_bd_intf_pins noc_virt_4/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins noc_virt_4/M00_INI] [get_bd_intf_ports M_QDMA_SLV_BRIDGE]

set clkpins {}
foreach c [get_bd_cells *] {
    foreach p [get_bd_pins -quiet $c/aclk*] { lappend clkpins $p }
    foreach p [get_bd_pins -quiet $c/ap_clk] { lappend clkpins $p }
    foreach p [get_bd_pins -quiet $c/aclk] { lappend clkpins $p }
}
connect_bd_net [get_bd_ports service_clk] {*}$clkpins
set rstpins {}
foreach c [get_bd_cells *] {
    foreach p [get_bd_pins -quiet $c/aresetn] { lappend rstpins $p }
    foreach p [get_bd_pins -quiet $c/ap_rst_n] { lappend rstpins $p }
}
connect_bd_net [get_bd_ports service_resetn] {*}$rstpins

save_bd_design
puts "SL_CELLS: [llength [get_bd_cells *]]"
validate_bd_design
puts "SERVICE_LAYER_VALIDATE_DONE"
