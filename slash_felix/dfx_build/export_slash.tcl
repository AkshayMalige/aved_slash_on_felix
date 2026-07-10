
################################################################
# This is a generated script based on design: slash
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2025.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source slash_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcvp1552-vsva3340-2MHP-e-S
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name slash

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_noc:1.1\
xilinx.com:hls:hbm_bandwidth:1.0\
xilinx.com:ip:smartconnect:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set S_AXILITE_INI [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S_AXILITE_INI ]

  set M00_INI [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI ]

  set M01_INI [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M01_INI ]

  set M02_INI [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M02_INI ]

  set M03_INI [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M03_INI ]

  set SL_VIRT_00 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL_VIRT_00 ]

  set SL_VIRT_01 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL_VIRT_01 ]

  set SL_VIRT_02 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL_VIRT_02 ]

  set SL_VIRT_03 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL_VIRT_03 ]

  set QDMA_SLAVE_BRIDGE_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 QDMA_SLAVE_BRIDGE_0 ]


  # Create ports
  set slash_clk [ create_bd_port -dir I -type clk -freq_hz 200000000 slash_clk ]
  set slash_resetn [ create_bd_port -dir I -type rst slash_resetn ]

  # Create instance: ddr_noc_0, and set properties
  set ddr_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 ddr_noc_0 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $ddr_noc_0


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /ddr_noc_0/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /ddr_noc_0/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /ddr_noc_0/aclk0]

  # Create instance: ddr_bandwidth_0, and set properties
  set ddr_bandwidth_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 ddr_bandwidth_0 ]

  # Create instance: ddr_noc_1, and set properties
  set ddr_noc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 ddr_noc_1 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $ddr_noc_1


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /ddr_noc_1/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /ddr_noc_1/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /ddr_noc_1/aclk0]

  # Create instance: ddr_bandwidth_1, and set properties
  set ddr_bandwidth_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 ddr_bandwidth_1 ]

  # Create instance: ddr_noc_2, and set properties
  set ddr_noc_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 ddr_noc_2 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $ddr_noc_2


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /ddr_noc_2/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /ddr_noc_2/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /ddr_noc_2/aclk0]

  # Create instance: ddr_bandwidth_2, and set properties
  set ddr_bandwidth_2 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 ddr_bandwidth_2 ]

  # Create instance: ddr_noc_3, and set properties
  set ddr_noc_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 ddr_noc_3 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $ddr_noc_3


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /ddr_noc_3/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /ddr_noc_3/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /ddr_noc_3/aclk0]

  # Create instance: ddr_bandwidth_3, and set properties
  set ddr_bandwidth_3 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 ddr_bandwidth_3 ]

  # Create instance: virtnoc_0, and set properties
  set virtnoc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 virtnoc_0 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $virtnoc_0


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /virtnoc_0/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /virtnoc_0/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /virtnoc_0/aclk0]

  # Create instance: traffic_virt_0, and set properties
  set traffic_virt_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 traffic_virt_0 ]

  # Create instance: virtnoc_1, and set properties
  set virtnoc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 virtnoc_1 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $virtnoc_1


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /virtnoc_1/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /virtnoc_1/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /virtnoc_1/aclk0]

  # Create instance: traffic_virt_1, and set properties
  set traffic_virt_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 traffic_virt_1 ]

  # Create instance: virtnoc_2, and set properties
  set virtnoc_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 virtnoc_2 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $virtnoc_2


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /virtnoc_2/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /virtnoc_2/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /virtnoc_2/aclk0]

  # Create instance: traffic_virt_2, and set properties
  set traffic_virt_2 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 traffic_virt_2 ]

  # Create instance: virtnoc_3, and set properties
  set virtnoc_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 virtnoc_3 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $virtnoc_3


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /virtnoc_3/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /virtnoc_3/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /virtnoc_3/aclk0]

  # Create instance: traffic_virt_3, and set properties
  set traffic_virt_3 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 traffic_virt_3 ]

  # Create instance: virtnoc_4, and set properties
  set virtnoc_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 virtnoc_4 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $virtnoc_4


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /virtnoc_4/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /virtnoc_4/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /virtnoc_4/aclk0]

  # Create instance: traffic_virt_4, and set properties
  set traffic_virt_4 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 traffic_virt_4 ]

  # Create instance: axi_noc_ctrl, and set properties
  set axi_noc_ctrl [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_ctrl ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_ctrl


  set_property -dict [ list \
   CONFIG.APERTURES {{0x202_0000_0000 16M}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_ctrl/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {5} write_bw {5} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_ctrl/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_ctrl/aclk0]

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {9} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_0


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXILITE_INI_1 [get_bd_intf_ports S_AXILITE_INI] [get_bd_intf_pins axi_noc_ctrl/S00_INI]
  connect_bd_intf_net -intf_net axi_noc_ctrl_M00_AXI [get_bd_intf_pins axi_noc_ctrl/M00_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net ddr_bandwidth_0_m_axi_gmem0 [get_bd_intf_pins ddr_bandwidth_0/m_axi_gmem0] [get_bd_intf_pins ddr_noc_0/S00_AXI]
  connect_bd_intf_net -intf_net ddr_bandwidth_1_m_axi_gmem0 [get_bd_intf_pins ddr_bandwidth_1/m_axi_gmem0] [get_bd_intf_pins ddr_noc_1/S00_AXI]
  connect_bd_intf_net -intf_net ddr_bandwidth_2_m_axi_gmem0 [get_bd_intf_pins ddr_bandwidth_2/m_axi_gmem0] [get_bd_intf_pins ddr_noc_2/S00_AXI]
  connect_bd_intf_net -intf_net ddr_bandwidth_3_m_axi_gmem0 [get_bd_intf_pins ddr_bandwidth_3/m_axi_gmem0] [get_bd_intf_pins ddr_noc_3/S00_AXI]
  connect_bd_intf_net -intf_net ddr_noc_0_M00_INI [get_bd_intf_pins ddr_noc_0/M00_INI] [get_bd_intf_ports M00_INI]
  connect_bd_intf_net -intf_net ddr_noc_1_M00_INI [get_bd_intf_pins ddr_noc_1/M00_INI] [get_bd_intf_ports M01_INI]
  connect_bd_intf_net -intf_net ddr_noc_2_M00_INI [get_bd_intf_pins ddr_noc_2/M00_INI] [get_bd_intf_ports M02_INI]
  connect_bd_intf_net -intf_net ddr_noc_3_M00_INI [get_bd_intf_pins ddr_noc_3/M00_INI] [get_bd_intf_ports M03_INI]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins ddr_bandwidth_0/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins ddr_bandwidth_1/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M02_AXI [get_bd_intf_pins smartconnect_0/M02_AXI] [get_bd_intf_pins ddr_bandwidth_2/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M03_AXI [get_bd_intf_pins smartconnect_0/M03_AXI] [get_bd_intf_pins ddr_bandwidth_3/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M04_AXI [get_bd_intf_pins smartconnect_0/M04_AXI] [get_bd_intf_pins traffic_virt_0/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M05_AXI [get_bd_intf_pins smartconnect_0/M05_AXI] [get_bd_intf_pins traffic_virt_1/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M06_AXI [get_bd_intf_pins smartconnect_0/M06_AXI] [get_bd_intf_pins traffic_virt_2/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M07_AXI [get_bd_intf_pins smartconnect_0/M07_AXI] [get_bd_intf_pins traffic_virt_3/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M08_AXI [get_bd_intf_pins smartconnect_0/M08_AXI] [get_bd_intf_pins traffic_virt_4/s_axi_control]
  connect_bd_intf_net -intf_net traffic_virt_0_m_axi_gmem0 [get_bd_intf_pins traffic_virt_0/m_axi_gmem0] [get_bd_intf_pins virtnoc_0/S00_AXI]
  connect_bd_intf_net -intf_net traffic_virt_1_m_axi_gmem0 [get_bd_intf_pins traffic_virt_1/m_axi_gmem0] [get_bd_intf_pins virtnoc_1/S00_AXI]
  connect_bd_intf_net -intf_net traffic_virt_2_m_axi_gmem0 [get_bd_intf_pins traffic_virt_2/m_axi_gmem0] [get_bd_intf_pins virtnoc_2/S00_AXI]
  connect_bd_intf_net -intf_net traffic_virt_3_m_axi_gmem0 [get_bd_intf_pins traffic_virt_3/m_axi_gmem0] [get_bd_intf_pins virtnoc_3/S00_AXI]
  connect_bd_intf_net -intf_net traffic_virt_4_m_axi_gmem0 [get_bd_intf_pins traffic_virt_4/m_axi_gmem0] [get_bd_intf_pins virtnoc_4/S00_AXI]
  connect_bd_intf_net -intf_net virtnoc_0_M00_INI [get_bd_intf_pins virtnoc_0/M00_INI] [get_bd_intf_ports SL_VIRT_00]
  connect_bd_intf_net -intf_net virtnoc_1_M00_INI [get_bd_intf_pins virtnoc_1/M00_INI] [get_bd_intf_ports SL_VIRT_01]
  connect_bd_intf_net -intf_net virtnoc_2_M00_INI [get_bd_intf_pins virtnoc_2/M00_INI] [get_bd_intf_ports SL_VIRT_02]
  connect_bd_intf_net -intf_net virtnoc_3_M00_INI [get_bd_intf_pins virtnoc_3/M00_INI] [get_bd_intf_ports SL_VIRT_03]
  connect_bd_intf_net -intf_net virtnoc_4_M00_INI [get_bd_intf_pins virtnoc_4/M00_INI] [get_bd_intf_ports QDMA_SLAVE_BRIDGE_0]

  # Create port connections
  connect_bd_net -net slash_clk_1  [get_bd_ports slash_clk] \
  [get_bd_pins axi_noc_ctrl/aclk0] \
  [get_bd_pins ddr_bandwidth_0/ap_clk] \
  [get_bd_pins ddr_bandwidth_1/ap_clk] \
  [get_bd_pins ddr_bandwidth_2/ap_clk] \
  [get_bd_pins ddr_bandwidth_3/ap_clk] \
  [get_bd_pins ddr_noc_0/aclk0] \
  [get_bd_pins ddr_noc_1/aclk0] \
  [get_bd_pins ddr_noc_2/aclk0] \
  [get_bd_pins ddr_noc_3/aclk0] \
  [get_bd_pins smartconnect_0/aclk] \
  [get_bd_pins traffic_virt_0/ap_clk] \
  [get_bd_pins traffic_virt_1/ap_clk] \
  [get_bd_pins traffic_virt_2/ap_clk] \
  [get_bd_pins traffic_virt_3/ap_clk] \
  [get_bd_pins traffic_virt_4/ap_clk] \
  [get_bd_pins virtnoc_0/aclk0] \
  [get_bd_pins virtnoc_1/aclk0] \
  [get_bd_pins virtnoc_2/aclk0] \
  [get_bd_pins virtnoc_3/aclk0] \
  [get_bd_pins virtnoc_4/aclk0]
  connect_bd_net -net slash_resetn_1  [get_bd_ports slash_resetn] \
  [get_bd_pins ddr_bandwidth_0/ap_rst_n] \
  [get_bd_pins ddr_bandwidth_1/ap_rst_n] \
  [get_bd_pins ddr_bandwidth_2/ap_rst_n] \
  [get_bd_pins ddr_bandwidth_3/ap_rst_n] \
  [get_bd_pins smartconnect_0/aresetn] \
  [get_bd_pins traffic_virt_0/ap_rst_n] \
  [get_bd_pins traffic_virt_1/ap_rst_n] \
  [get_bd_pins traffic_virt_2/ap_rst_n] \
  [get_bd_pins traffic_virt_3/ap_rst_n] \
  [get_bd_pins traffic_virt_4/ap_rst_n]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


