################################################################
# am_felix_service_layer.tcl
#
# Creates service_layer hierarchy with all internal connections
# matching the SLASH reference — no DCMAC, no HBM.
# External ports (SL2NOC, M_VIRT, S_VIRT, S_QDMA, M_QDMA,
# S_AXILITE_INI, service_clk, service_resetn) are left
# unconnected — wire to axi_noc_cips / cips in Vivado GUI.
#
# Run AFTER am_felix_noc.tcl.
# vivado -mode batch -source am_felix_service_layer.tcl
################################################################

set proj_dir [file normalize [file join [file dirname [info script]] myproj]]
set bd_name  "felix_cips"

open_project ${proj_dir}/project_1.xpr

set script_dir [file normalize [file dirname [info script]]]
set_property ip_repo_paths [file join $script_dir iprepo] [current_project]
update_ip_catalog -rebuild

open_bd_design [get_files ${bd_name}.bd]
current_bd_design ${bd_name}

################################################################
# Cleanup: remove flat IPs added by any previous run of this script
################################################################
foreach cell {
    axi_noc_sl_mgmt axi_noc_sl_virt1 axi_noc_sl_virt2 axi_noc_sl_virt3
    axi_noc_sl_virt4 axi_noc_sl_qdma noc_axilite_bridge
    axi_register_slice_sl0 axi_register_slice_sl1 axi_register_slice_sl2
    axi_register_slice_sl3 axi_register_slice_sl4 axi_register_slice_sl5
    axi_register_slice_sl6 axi_register_slice_sl7 axi_register_slice_sl8
    axi_register_slice_sl9
    axi4_full_passthrough_sl0 axi4_full_passthrough_sl1 axi4_full_passthrough_sl2
    axi4_full_passthrough_sl3 axi4_full_passthrough_sl4
    noc_virt_0 noc_virt_1 noc_virt_2 noc_virt_3 noc_virt_4
    sl2noc_0 sl2noc_1 sl2noc_2 sl2noc_3 sl2noc_4 sl2noc_5 sl2noc_6 sl2noc_7
    service_layer
} {
    if { [llength [get_bd_cells -quiet $cell]] > 0 } {
        delete_bd_objs [get_bd_cells $cell]
    }
}

################################################################
# Create service_layer hierarchy
################################################################
create_bd_cell -type hier service_layer
current_bd_instance service_layer

# ── External interface pins (left unconnected — wire in GUI) ──

# Management: receives INI from axi_noc_cips (via bridge NoC)
create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0  S_AXILITE_INI

# QDMA slave bridge
create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0  S_QDMA_SLV_BRIDGE
create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0  M_QDMA_SLV_BRIDGE

# Virtual memory (kernel ↔ DMA engine)
create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0  S_VIRT_00
create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0  S_VIRT_01
create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0  S_VIRT_02
create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:inimm_rtl:1.0  S_VIRT_03
create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0  M_VIRT_0
create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0  M_VIRT_1
create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0  M_VIRT_2
create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0  M_VIRT_3

# SL2NOC: 8 paths to axi_noc_cips NSI ports → DDR4 (kernel data)
foreach i {0 1 2 3 4 5 6 7} {
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_${i}
}

# Management AXI output: drives base_logic/s_axi_pcie_mgmt_slr0
create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0   M_AXILITE_MGMT

# Clock and reset
create_bd_pin -dir I -type clk service_clk
create_bd_pin -dir I -type rst service_resetn

# ── axi_noc_0: management path ──
# S_AXILITE_INI (INI slave) → M00_AXI (AXI master → base_logic)
set n0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_0]
set_property -dict {
    CONFIG.NUM_SI  {0} CONFIG.NUM_MI  {1}
    CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}
} $n0
set_property -dict {
    CONFIG.APERTURES {{0x203_0000_0000 128M}} CONFIG.CATEGORY {pl}
} [get_bd_intf_pins axi_noc_0/M00_AXI]
set_property -dict {
    CONFIG.INI_STRATEGY {load}
    CONFIG.CONNECTIONS  {M00_AXI {read_bw {5} write_bw {5} read_avg_burst {4} write_avg_burst {4}}}
} [get_bd_intf_pins axi_noc_0/S00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_0/aclk0]

# ── axi_noc_1..4: S_VIRT_00..03 receiver NoCs ──
foreach i {1 2 3 4} {
    set n [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_${i}]
    set_property -dict {
        CONFIG.NUM_SI  {0} CONFIG.NUM_MI  {1}
        CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}
    } $n
    set_property -dict [list \
        CONFIG.APERTURES {{0x208_0000_0000 32G}} CONFIG.CATEGORY {pl}] \
        [get_bd_intf_pins axi_noc_${i}/M00_AXI]
    set_property -dict {
        CONFIG.INI_STRATEGY {load}
        CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}
    } [get_bd_intf_pins axi_noc_${i}/S00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_${i}/aclk0]
}

# ── axi_noc_5: QDMA slave bridge receiver NoC ──
set n5 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_5]
set_property -dict {
    CONFIG.NUM_SI  {0} CONFIG.NUM_MI  {1}
    CONFIG.NUM_NSI {1} CONFIG.NUM_NMI {0} CONFIG.NUM_CLKS {1}
} $n5
set_property -dict [list \
    CONFIG.APERTURES {{0x208_0000_0000 32G}} CONFIG.CATEGORY {pl}] \
    [get_bd_intf_pins axi_noc_5/M00_AXI]
set_property -dict {
    CONFIG.INI_STRATEGY {load}
    CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}
} [get_bd_intf_pins axi_noc_5/S00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_5/aclk0]

# ── axi_register_slice_0..9 ──
foreach i {0 1 2 3 4 5 6 7 8 9} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice \
        axi_register_slice_${i}
}

# ── axi4_full_passthrough_0..4 ──
foreach i {0 1 2 3 4} {
    set pt [create_bd_cell -type ip \
        -vlnv user.org:user:axi4_full_passthrough:1.0 \
        axi4_full_passthrough_${i}]
    set_property CONFIG.AXI_DATA_WIDTH {128} $pt
}

# ── noc_virt_0..3: S_VIRT paths, AXI in → INI out → M_VIRT ──
foreach i {0 1 2 3} {
    set nv [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc noc_virt_${i}]
    set_property -dict {
        CONFIG.NUM_SI  {1} CONFIG.NUM_MI  {0}
        CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}
    } $nv
    set_property -dict {
        CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}}
        CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}
    } [get_bd_intf_pins noc_virt_${i}/S00_AXI]
    set_property CONFIG.INI_STRATEGY {driver} \
        [get_bd_intf_pins noc_virt_${i}/M00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
        [get_bd_pins noc_virt_${i}/aclk0]
}

# ── noc_virt_4: QDMA bridge path ──
set nv4 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc noc_virt_4]
set_property -dict {
    CONFIG.NUM_SI  {1} CONFIG.NUM_MI  {0}
    CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}
} $nv4
set_property -dict {
    CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}}
    CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}
} [get_bd_intf_pins noc_virt_4/S00_AXI]
set_property CONFIG.INI_STRATEGY {driver} \
    [get_bd_intf_pins noc_virt_4/M00_INI]
set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
    [get_bd_pins noc_virt_4/aclk0]

# ── sl2noc_0..7 ──
# S00_AXI: UNCONNECTED in static shell (kernel m_axi connected by v80++ link)
# M00_INI: connects to SL2NOC_x hierarchy port → axi_noc_cips NSI
foreach i {0 1 2 3 4 5 6 7} {
    set sl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc sl2noc_${i}]
    set_property -dict {
        CONFIG.NUM_SI  {1} CONFIG.NUM_MI  {0}
        CONFIG.NUM_NSI {0} CONFIG.NUM_NMI {1} CONFIG.NUM_CLKS {1}
    } $sl
    set_property -dict [list \
        CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
        CONFIG.DEST_IDS {} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {pl}] \
        [get_bd_intf_pins sl2noc_${i}/S00_AXI]
    set_property CONFIG.INI_STRATEGY {driver} \
        [get_bd_intf_pins sl2noc_${i}/M00_INI]
    set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
        [get_bd_pins sl2noc_${i}/aclk0]
}

# ════════════════════════════════════════════════════
# INTERNAL CONNECTIONS (matching SLASH reference)
# ════════════════════════════════════════════════════

# Management path
connect_bd_intf_net [get_bd_intf_pins S_AXILITE_INI] \
                    [get_bd_intf_pins axi_noc_0/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_0/M00_AXI] \
                    [get_bd_intf_pins M_AXILITE_MGMT]

# QDMA slave bridge path
connect_bd_intf_net [get_bd_intf_pins S_QDMA_SLV_BRIDGE] \
                    [get_bd_intf_pins axi_noc_5/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_5/M00_AXI] \
                    [get_bd_intf_pins axi_register_slice_8/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_8/M_AXI] \
                    [get_bd_intf_pins axi4_full_passthrough_4/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi4_full_passthrough_4/m_axi] \
                    [get_bd_intf_pins axi_register_slice_9/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_9/M_AXI] \
                    [get_bd_intf_pins noc_virt_4/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins noc_virt_4/M00_INI] \
                    [get_bd_intf_pins M_QDMA_SLV_BRIDGE]

# S_VIRT_00 → M_VIRT_0
connect_bd_intf_net [get_bd_intf_pins S_VIRT_00] \
                    [get_bd_intf_pins axi_noc_1/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_1/M00_AXI] \
                    [get_bd_intf_pins axi_register_slice_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_0/M_AXI] \
                    [get_bd_intf_pins axi4_full_passthrough_0/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi4_full_passthrough_0/m_axi] \
                    [get_bd_intf_pins axi_register_slice_1/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_1/M_AXI] \
                    [get_bd_intf_pins noc_virt_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins noc_virt_0/M00_INI] \
                    [get_bd_intf_pins M_VIRT_0]

# S_VIRT_01 → M_VIRT_1
connect_bd_intf_net [get_bd_intf_pins S_VIRT_01] \
                    [get_bd_intf_pins axi_noc_2/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_2/M00_AXI] \
                    [get_bd_intf_pins axi_register_slice_2/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_2/M_AXI] \
                    [get_bd_intf_pins axi4_full_passthrough_1/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi4_full_passthrough_1/m_axi] \
                    [get_bd_intf_pins axi_register_slice_3/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_3/M_AXI] \
                    [get_bd_intf_pins noc_virt_1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins noc_virt_1/M00_INI] \
                    [get_bd_intf_pins M_VIRT_1]

# S_VIRT_02 → M_VIRT_2
connect_bd_intf_net [get_bd_intf_pins S_VIRT_02] \
                    [get_bd_intf_pins axi_noc_3/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_3/M00_AXI] \
                    [get_bd_intf_pins axi_register_slice_4/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_4/M_AXI] \
                    [get_bd_intf_pins axi4_full_passthrough_2/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi4_full_passthrough_2/m_axi] \
                    [get_bd_intf_pins axi_register_slice_5/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_5/M_AXI] \
                    [get_bd_intf_pins noc_virt_2/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins noc_virt_2/M00_INI] \
                    [get_bd_intf_pins M_VIRT_2]

# S_VIRT_03 → M_VIRT_3
connect_bd_intf_net [get_bd_intf_pins S_VIRT_03] \
                    [get_bd_intf_pins axi_noc_4/S00_INI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_4/M00_AXI] \
                    [get_bd_intf_pins axi_register_slice_6/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_6/M_AXI] \
                    [get_bd_intf_pins axi4_full_passthrough_3/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi4_full_passthrough_3/m_axi] \
                    [get_bd_intf_pins axi_register_slice_7/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_register_slice_7/M_AXI] \
                    [get_bd_intf_pins noc_virt_3/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins noc_virt_3/M00_INI] \
                    [get_bd_intf_pins M_VIRT_3]

# sl2noc_0..7 M00_INI → SL2NOC ports
foreach i {0 1 2 3 4 5 6 7} {
    connect_bd_intf_net [get_bd_intf_pins sl2noc_${i}/M00_INI] \
                        [get_bd_intf_pins SL2NOC_${i}]
}

# ── Clock connections (all internal IPs share service_clk) ──
set clk [get_bd_pins service_clk]
connect_bd_net $clk \
    [get_bd_pins axi_noc_0/aclk0] \
    [get_bd_pins axi_noc_1/aclk0] \
    [get_bd_pins axi_noc_2/aclk0] \
    [get_bd_pins axi_noc_3/aclk0] \
    [get_bd_pins axi_noc_4/aclk0] \
    [get_bd_pins axi_noc_5/aclk0] \
    [get_bd_pins noc_virt_0/aclk0] \
    [get_bd_pins noc_virt_1/aclk0] \
    [get_bd_pins noc_virt_2/aclk0] \
    [get_bd_pins noc_virt_3/aclk0] \
    [get_bd_pins noc_virt_4/aclk0] \
    [get_bd_pins sl2noc_0/aclk0] \
    [get_bd_pins sl2noc_1/aclk0] \
    [get_bd_pins sl2noc_2/aclk0] \
    [get_bd_pins sl2noc_3/aclk0] \
    [get_bd_pins sl2noc_4/aclk0] \
    [get_bd_pins sl2noc_5/aclk0] \
    [get_bd_pins sl2noc_6/aclk0] \
    [get_bd_pins sl2noc_7/aclk0] \
    [get_bd_pins axi_register_slice_0/aclk] \
    [get_bd_pins axi_register_slice_1/aclk] \
    [get_bd_pins axi_register_slice_2/aclk] \
    [get_bd_pins axi_register_slice_3/aclk] \
    [get_bd_pins axi_register_slice_4/aclk] \
    [get_bd_pins axi_register_slice_5/aclk] \
    [get_bd_pins axi_register_slice_6/aclk] \
    [get_bd_pins axi_register_slice_7/aclk] \
    [get_bd_pins axi_register_slice_8/aclk] \
    [get_bd_pins axi_register_slice_9/aclk] \
    [get_bd_pins axi4_full_passthrough_0/aclk] \
    [get_bd_pins axi4_full_passthrough_1/aclk] \
    [get_bd_pins axi4_full_passthrough_2/aclk] \
    [get_bd_pins axi4_full_passthrough_3/aclk] \
    [get_bd_pins axi4_full_passthrough_4/aclk]

# ── Reset connections ──
set rst [get_bd_pins service_resetn]
connect_bd_net $rst \
    [get_bd_pins axi_register_slice_0/aresetn] \
    [get_bd_pins axi_register_slice_1/aresetn] \
    [get_bd_pins axi_register_slice_2/aresetn] \
    [get_bd_pins axi_register_slice_3/aresetn] \
    [get_bd_pins axi_register_slice_4/aresetn] \
    [get_bd_pins axi_register_slice_5/aresetn] \
    [get_bd_pins axi_register_slice_6/aresetn] \
    [get_bd_pins axi_register_slice_7/aresetn] \
    [get_bd_pins axi_register_slice_8/aresetn] \
    [get_bd_pins axi_register_slice_9/aresetn] \
    [get_bd_pins axi4_full_passthrough_0/aresetn] \
    [get_bd_pins axi4_full_passthrough_1/aresetn] \
    [get_bd_pins axi4_full_passthrough_2/aresetn] \
    [get_bd_pins axi4_full_passthrough_3/aresetn] \
    [get_bd_pins axi4_full_passthrough_4/aresetn]

current_bd_instance /

################################################################
save_bd_design
close_bd_design [get_bd_designs ${bd_name}]
close_project
puts "================================================================"
puts "service_layer hierarchy created with all internal connections."
puts ""
puts "Now connect in Vivado GUI (service_layer external ports):"
puts "  service_layer/service_clk    ← cips/pl2_ref_clk"
puts "  service_layer/service_resetn ← clock_reset/resetn_pcie_periph"
puts "  service_layer/SL2NOC_0..7   → axi_noc_cips/S00..S07_INI"
puts "  service_layer/S_AXILITE_INI ← axi_noc_cips/M00_AXI (via NoC bridge)"
puts "  service_layer/M_AXILITE_MGMT → base_logic/s_axi_pcie_mgmt_slr0"
puts "  service_layer/M_QDMA_SLV_BRIDGE → cips/NOC_CPM_PCIE_0"
puts "  CIPS NoC ports → axi_noc_cips/S00..S03_AXI"
puts "  axi_noc_cips/M00_INI → axi_noc_ddr4/S00_INI"
puts "================================================================"
