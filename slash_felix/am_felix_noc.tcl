################################################################
# am_felix_noc.tcl
# Adds axi_noc_cips and axi_noc_ddr4 to the BD.
# NO connections — wire them in Vivado GUI after.
#
# vivado -mode batch -source am_felix_noc.tcl
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
# axi_noc_cips
# NUM_SI=4   : S00..S03_AXI from CIPS (LPD, PMC, CPM0, CPM1)
# NUM_MI=1   : M00_AXI → management (base_logic)
# NUM_NSI=8  : S00..S07_INI from service layer SL2NOC_0..7
# NUM_NMI=1  : M00_INI → axi_noc_ddr4
# NUM_CLKS=6 : one per SI (×4) + one per MI (×1) + one for NSI (×1)
################################################################
set noc_cips [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_cips]
set_property -dict {
    CONFIG.NUM_SI   {4}
    CONFIG.NUM_MI   {1}
    CONFIG.NUM_NSI  {8}
    CONFIG.NUM_NMI  {1}
    CONFIG.NUM_CLKS {6}
} $noc_cips

# SI connection routing
set_property CONFIG.CONNECTIONS \
    {M00_INI {read_bw {128} write_bw {128}} M00_AXI {read_bw {5} write_bw {5}}} \
    [get_bd_intf_pins axi_noc_cips/S00_AXI]
set_property CONFIG.CONNECTIONS \
    {M00_INI {read_bw {128} write_bw {128}} M00_AXI {read_bw {5} write_bw {5}}} \
    [get_bd_intf_pins axi_noc_cips/S01_AXI]
set_property CONFIG.CONNECTIONS \
    {M00_INI {read_bw {500} write_bw {500}} M00_AXI {read_bw {5} write_bw {5}}} \
    [get_bd_intf_pins axi_noc_cips/S02_AXI]
set_property CONFIG.CONNECTIONS \
    {M00_INI {read_bw {500} write_bw {500}} M00_AXI {read_bw {5} write_bw {5}}} \
    [get_bd_intf_pins axi_noc_cips/S03_AXI]

# NSI connection routing
foreach idx {0 1 2 3 4 5 6 7} {
    set_property CONFIG.CONNECTIONS \
        {M00_INI {read_bw {500} write_bw {500}}} \
        [get_bd_intf_pins axi_noc_cips/S0${idx}_INI]
}

# MI aperture
set_property -dict {
    CONFIG.APERTURES {{0x203_0000_0000 128M}}
    CONFIG.CATEGORY  {pl}
} [get_bd_intf_pins axi_noc_cips/M00_AXI]

# Clock associations
set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins axi_noc_cips/aclk0]
set_property CONFIG.ASSOCIATED_BUSIF {S01_AXI} [get_bd_pins axi_noc_cips/aclk1]
set_property CONFIG.ASSOCIATED_BUSIF {S02_AXI} [get_bd_pins axi_noc_cips/aclk2]
set_property CONFIG.ASSOCIATED_BUSIF {S03_AXI} [get_bd_pins axi_noc_cips/aclk3]
set_property CONFIG.ASSOCIATED_BUSIF {M00_AXI} [get_bd_pins axi_noc_cips/aclk4]
set_property CONFIG.ASSOCIATED_BUSIF \
    {S00_INI:S01_INI:S02_INI:S03_INI:S04_INI:S05_INI:S06_INI:S07_INI} \
    [get_bd_pins axi_noc_cips/aclk5]

################################################################
# axi_noc_ddr4
# DDR4 controller: 72-bit ECC, DDR4-2666V, 200 MHz refclk
################################################################
set noc_ddr4 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_ddr4]
set_property -dict {
    CONFIG.NUM_SI       {0}
    CONFIG.NUM_MI       {0}
    CONFIG.NUM_NSI      {1}
    CONFIG.NUM_NMI      {0}
    CONFIG.NUM_CLKS     {0}
    CONFIG.CONTROLLERTYPE        {DDR4_SDRAM}
    CONFIG.MC_CHAN_REGION1       {DDR_LOW1}
    CONFIG.MC_DATAWIDTH          {72}
    CONFIG.MC_EN_INTR_RESP       {TRUE}
    CONFIG.MC_INPUTCLK0_PERIOD   {5000}
    CONFIG.MC_MEMORY_DEVICETYPE  {UDIMMs}
    CONFIG.MC_MEMORY_SPEEDGRADE  {DDR4-2666V(19-19-19)}
    CONFIG.MC_MEMORY_TIMEPERIOD0 {800}
    CONFIG.MC_RANK               {2}
    CONFIG.MC_ROWADDRESSWIDTH    {17}
} $noc_ddr4

set_property CONFIG.CONNECTIONS \
    {MC_0 {read_bw {1000} write_bw {1000}}} \
    [get_bd_intf_pins axi_noc_ddr4/S00_INI]

################################################################
save_bd_design
close_bd_design [get_bd_designs ${bd_name}]
close_project
puts "Done — axi_noc_cips and axi_noc_ddr4 added. Wire them in Vivado GUI."
