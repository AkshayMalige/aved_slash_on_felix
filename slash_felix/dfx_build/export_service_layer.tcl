
################################################################
# This is a generated script based on design: service_layer
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
# source service_layer_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcvp1552-vsva3340-2MHP-e-S
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name service_layer

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
xilinx.com:ip:axi_register_slice:2.1\
user.org:user:axi4_full_passthrough:1.0\
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

  set SL2NOC_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_0 ]

  set SL2NOC_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_1 ]

  set SL2NOC_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_2 ]

  set SL2NOC_3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_3 ]

  set SL2NOC_4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_4 ]

  set SL2NOC_5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_5 ]

  set SL2NOC_6 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_6 ]

  set SL2NOC_7 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 SL2NOC_7 ]

  set S_VIRT_00 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S_VIRT_00 ]

  set S_VIRT_01 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S_VIRT_01 ]

  set S_VIRT_02 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S_VIRT_02 ]

  set S_VIRT_03 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S_VIRT_03 ]

  set M_VIRT_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_VIRT_0 ]

  set M_VIRT_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_VIRT_1 ]

  set M_VIRT_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_VIRT_2 ]

  set M_VIRT_3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_VIRT_3 ]

  set S_QDMA_SLV_BRIDGE [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S_QDMA_SLV_BRIDGE ]

  set M_QDMA_SLV_BRIDGE [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M_QDMA_SLV_BRIDGE ]


  # Create ports
  set service_clk [ create_bd_port -dir I -type clk -freq_hz 300000000 service_clk ]
  set service_resetn [ create_bd_port -dir I -type rst service_resetn ]

  # Create instance: sl2noc_0, and set properties
  set sl2noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_0 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_0


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_0/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_0/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_0/aclk0]

  # Create instance: eth_0, and set properties
  set eth_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_0 ]

  # Create instance: sl2noc_1, and set properties
  set sl2noc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_1 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_1


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_1/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_1/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_1/aclk0]

  # Create instance: eth_1, and set properties
  set eth_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_1 ]

  # Create instance: sl2noc_2, and set properties
  set sl2noc_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_2 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_2


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_2/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_2/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_2/aclk0]

  # Create instance: eth_2, and set properties
  set eth_2 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_2 ]

  # Create instance: sl2noc_3, and set properties
  set sl2noc_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_3 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_3


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_3/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_3/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_3/aclk0]

  # Create instance: eth_3, and set properties
  set eth_3 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_3 ]

  # Create instance: sl2noc_4, and set properties
  set sl2noc_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_4 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_4


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_4/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_4/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_4/aclk0]

  # Create instance: eth_4, and set properties
  set eth_4 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_4 ]

  # Create instance: sl2noc_5, and set properties
  set sl2noc_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_5 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_5


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_5/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_5/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_5/aclk0]

  # Create instance: eth_5, and set properties
  set eth_5 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_5 ]

  # Create instance: sl2noc_6, and set properties
  set sl2noc_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_6 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_6


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_6/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_6/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_6/aclk0]

  # Create instance: eth_6, and set properties
  set eth_6 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_6 ]

  # Create instance: sl2noc_7, and set properties
  set sl2noc_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 sl2noc_7 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $sl2noc_7


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /sl2noc_7/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {250} write_bw {250}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /sl2noc_7/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /sl2noc_7/aclk0]

  # Create instance: eth_7, and set properties
  set eth_7 [ create_bd_cell -type ip -vlnv xilinx.com:hls:hbm_bandwidth:1.0 eth_7 ]

  # Create instance: axi_noc_0, and set properties
  set axi_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_0


  set_property -dict [ list \
   CONFIG.APERTURES {{0x203_0000_0000 4M}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_0/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {5} write_bw {5} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_0/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_0/aclk0]

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {8} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_0


  # Create instance: axi_noc_1, and set properties
  set axi_noc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_1 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_1


  set_property -dict [ list \
   CONFIG.APERTURES {{0x202_0000_0000 1G}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_1/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_1/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_1/aclk0]

  # Create instance: vrs_0_a, and set properties
  set vrs_0_a [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_0_a ]

  # Create instance: vpt_0, and set properties
  set vpt_0 [ create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 vpt_0 ]
  set_property CONFIG.AXI_DATA_WIDTH {128} $vpt_0


  # Create instance: vrs_0_b, and set properties
  set vrs_0_b [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_0_b ]

  # Create instance: noc_virt_0, and set properties
  set noc_virt_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_0 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $noc_virt_0


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /noc_virt_0/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /noc_virt_0/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /noc_virt_0/aclk0]

  # Create instance: axi_noc_2, and set properties
  set axi_noc_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_2 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_2


  set_property -dict [ list \
   CONFIG.APERTURES {{0x202_8000_0000 1G}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_2/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_2/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_2/aclk0]

  # Create instance: vrs_1_a, and set properties
  set vrs_1_a [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_1_a ]

  # Create instance: vpt_1, and set properties
  set vpt_1 [ create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 vpt_1 ]
  set_property CONFIG.AXI_DATA_WIDTH {128} $vpt_1


  # Create instance: vrs_1_b, and set properties
  set vrs_1_b [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_1_b ]

  # Create instance: noc_virt_1, and set properties
  set noc_virt_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_1 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $noc_virt_1


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /noc_virt_1/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /noc_virt_1/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /noc_virt_1/aclk0]

  # Create instance: axi_noc_3, and set properties
  set axi_noc_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_3 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_3


  set_property -dict [ list \
   CONFIG.APERTURES {{0x203_8000_0000 1G}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_3/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_3/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_3/aclk0]

  # Create instance: vrs_2_a, and set properties
  set vrs_2_a [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_2_a ]

  # Create instance: vpt_2, and set properties
  set vpt_2 [ create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 vpt_2 ]
  set_property CONFIG.AXI_DATA_WIDTH {128} $vpt_2


  # Create instance: vrs_2_b, and set properties
  set vrs_2_b [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_2_b ]

  # Create instance: noc_virt_2, and set properties
  set noc_virt_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_2 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $noc_virt_2


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /noc_virt_2/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /noc_virt_2/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /noc_virt_2/aclk0]

  # Create instance: axi_noc_4, and set properties
  set axi_noc_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_4 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_4


  set_property -dict [ list \
   CONFIG.APERTURES {{0x204_0000_0000 1G}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_4/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_4/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_4/aclk0]

  # Create instance: vrs_3_a, and set properties
  set vrs_3_a [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_3_a ]

  # Create instance: vpt_3, and set properties
  set vpt_3 [ create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 vpt_3 ]
  set_property CONFIG.AXI_DATA_WIDTH {128} $vpt_3


  # Create instance: vrs_3_b, and set properties
  set vrs_3_b [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 vrs_3_b ]

  # Create instance: noc_virt_3, and set properties
  set noc_virt_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_3 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $noc_virt_3


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /noc_virt_3/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /noc_virt_3/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /noc_virt_3/aclk0]

  # Create instance: axi_noc_5, and set properties
  set axi_noc_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_5 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_5


  set_property -dict [ list \
   CONFIG.APERTURES {{0x204_8000_0000 1G}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /axi_noc_5/M00_AXI]

  set_property -dict [ list \
   CONFIG.INI_STRATEGY {load} \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /axi_noc_5/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /axi_noc_5/aclk0]

  # Create instance: qrs_a, and set properties
  set qrs_a [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 qrs_a ]

  # Create instance: qpt, and set properties
  set qpt [ create_bd_cell -type ip -vlnv user.org:user:axi4_full_passthrough:1.0 qpt ]
  set_property CONFIG.AXI_DATA_WIDTH {128} $qpt


  # Create instance: qrs_b, and set properties
  set qrs_b [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 qrs_b ]

  # Create instance: noc_virt_4, and set properties
  set noc_virt_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 noc_virt_4 ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {1} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {0} \
    CONFIG.NUM_SI {1} \
  ] $noc_virt_4


  set_property -dict [ list \
   CONFIG.INI_STRATEGY {driver} \
 ] [get_bd_intf_pins /noc_virt_4/M00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /noc_virt_4/S00_AXI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /noc_virt_4/aclk0]

  # Create interface connections
  connect_bd_intf_net -intf_net S_AXILITE_INI_1 [get_bd_intf_ports S_AXILITE_INI] [get_bd_intf_pins axi_noc_0/S00_INI]
  connect_bd_intf_net -intf_net S_QDMA_SLV_BRIDGE_1 [get_bd_intf_ports S_QDMA_SLV_BRIDGE] [get_bd_intf_pins axi_noc_5/S00_INI]
  connect_bd_intf_net -intf_net S_VIRT_00_1 [get_bd_intf_ports S_VIRT_00] [get_bd_intf_pins axi_noc_1/S00_INI]
  connect_bd_intf_net -intf_net S_VIRT_01_1 [get_bd_intf_ports S_VIRT_01] [get_bd_intf_pins axi_noc_2/S00_INI]
  connect_bd_intf_net -intf_net S_VIRT_02_1 [get_bd_intf_ports S_VIRT_02] [get_bd_intf_pins axi_noc_3/S00_INI]
  connect_bd_intf_net -intf_net S_VIRT_03_1 [get_bd_intf_ports S_VIRT_03] [get_bd_intf_pins axi_noc_4/S00_INI]
  connect_bd_intf_net -intf_net axi_noc_0_M00_AXI [get_bd_intf_pins axi_noc_0/M00_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_noc_1_M00_AXI [get_bd_intf_pins axi_noc_1/M00_AXI] [get_bd_intf_pins vrs_0_a/S_AXI]
  connect_bd_intf_net -intf_net axi_noc_2_M00_AXI [get_bd_intf_pins axi_noc_2/M00_AXI] [get_bd_intf_pins vrs_1_a/S_AXI]
  connect_bd_intf_net -intf_net axi_noc_3_M00_AXI [get_bd_intf_pins axi_noc_3/M00_AXI] [get_bd_intf_pins vrs_2_a/S_AXI]
  connect_bd_intf_net -intf_net axi_noc_4_M00_AXI [get_bd_intf_pins axi_noc_4/M00_AXI] [get_bd_intf_pins vrs_3_a/S_AXI]
  connect_bd_intf_net -intf_net axi_noc_5_M00_AXI [get_bd_intf_pins axi_noc_5/M00_AXI] [get_bd_intf_pins qrs_a/S_AXI]
  connect_bd_intf_net -intf_net eth_0_m_axi_gmem0 [get_bd_intf_pins eth_0/m_axi_gmem0] [get_bd_intf_pins sl2noc_0/S00_AXI]
  connect_bd_intf_net -intf_net eth_1_m_axi_gmem0 [get_bd_intf_pins eth_1/m_axi_gmem0] [get_bd_intf_pins sl2noc_1/S00_AXI]
  connect_bd_intf_net -intf_net eth_2_m_axi_gmem0 [get_bd_intf_pins eth_2/m_axi_gmem0] [get_bd_intf_pins sl2noc_2/S00_AXI]
  connect_bd_intf_net -intf_net eth_3_m_axi_gmem0 [get_bd_intf_pins eth_3/m_axi_gmem0] [get_bd_intf_pins sl2noc_3/S00_AXI]
  connect_bd_intf_net -intf_net eth_4_m_axi_gmem0 [get_bd_intf_pins eth_4/m_axi_gmem0] [get_bd_intf_pins sl2noc_4/S00_AXI]
  connect_bd_intf_net -intf_net eth_5_m_axi_gmem0 [get_bd_intf_pins eth_5/m_axi_gmem0] [get_bd_intf_pins sl2noc_5/S00_AXI]
  connect_bd_intf_net -intf_net eth_6_m_axi_gmem0 [get_bd_intf_pins eth_6/m_axi_gmem0] [get_bd_intf_pins sl2noc_6/S00_AXI]
  connect_bd_intf_net -intf_net eth_7_m_axi_gmem0 [get_bd_intf_pins eth_7/m_axi_gmem0] [get_bd_intf_pins sl2noc_7/S00_AXI]
  connect_bd_intf_net -intf_net noc_virt_0_M00_INI [get_bd_intf_pins noc_virt_0/M00_INI] [get_bd_intf_ports M_VIRT_0]
  connect_bd_intf_net -intf_net noc_virt_1_M00_INI [get_bd_intf_pins noc_virt_1/M00_INI] [get_bd_intf_ports M_VIRT_1]
  connect_bd_intf_net -intf_net noc_virt_2_M00_INI [get_bd_intf_pins noc_virt_2/M00_INI] [get_bd_intf_ports M_VIRT_2]
  connect_bd_intf_net -intf_net noc_virt_3_M00_INI [get_bd_intf_pins noc_virt_3/M00_INI] [get_bd_intf_ports M_VIRT_3]
  connect_bd_intf_net -intf_net noc_virt_4_M00_INI [get_bd_intf_pins noc_virt_4/M00_INI] [get_bd_intf_ports M_QDMA_SLV_BRIDGE]
  connect_bd_intf_net -intf_net qpt_m_axi [get_bd_intf_pins qpt/m_axi] [get_bd_intf_pins qrs_b/S_AXI]
  connect_bd_intf_net -intf_net qrs_a_M_AXI [get_bd_intf_pins qrs_a/M_AXI] [get_bd_intf_pins qpt/s_axi]
  connect_bd_intf_net -intf_net qrs_b_M_AXI [get_bd_intf_pins qrs_b/M_AXI] [get_bd_intf_pins noc_virt_4/S00_AXI]
  connect_bd_intf_net -intf_net sl2noc_0_M00_INI [get_bd_intf_pins sl2noc_0/M00_INI] [get_bd_intf_ports SL2NOC_0]
  connect_bd_intf_net -intf_net sl2noc_1_M00_INI [get_bd_intf_pins sl2noc_1/M00_INI] [get_bd_intf_ports SL2NOC_1]
  connect_bd_intf_net -intf_net sl2noc_2_M00_INI [get_bd_intf_pins sl2noc_2/M00_INI] [get_bd_intf_ports SL2NOC_2]
  connect_bd_intf_net -intf_net sl2noc_3_M00_INI [get_bd_intf_pins sl2noc_3/M00_INI] [get_bd_intf_ports SL2NOC_3]
  connect_bd_intf_net -intf_net sl2noc_4_M00_INI [get_bd_intf_pins sl2noc_4/M00_INI] [get_bd_intf_ports SL2NOC_4]
  connect_bd_intf_net -intf_net sl2noc_5_M00_INI [get_bd_intf_pins sl2noc_5/M00_INI] [get_bd_intf_ports SL2NOC_5]
  connect_bd_intf_net -intf_net sl2noc_6_M00_INI [get_bd_intf_pins sl2noc_6/M00_INI] [get_bd_intf_ports SL2NOC_6]
  connect_bd_intf_net -intf_net sl2noc_7_M00_INI [get_bd_intf_pins sl2noc_7/M00_INI] [get_bd_intf_ports SL2NOC_7]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins eth_0/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins eth_1/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M02_AXI [get_bd_intf_pins smartconnect_0/M02_AXI] [get_bd_intf_pins eth_2/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M03_AXI [get_bd_intf_pins smartconnect_0/M03_AXI] [get_bd_intf_pins eth_3/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M04_AXI [get_bd_intf_pins smartconnect_0/M04_AXI] [get_bd_intf_pins eth_4/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M05_AXI [get_bd_intf_pins smartconnect_0/M05_AXI] [get_bd_intf_pins eth_5/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M06_AXI [get_bd_intf_pins smartconnect_0/M06_AXI] [get_bd_intf_pins eth_6/s_axi_control]
  connect_bd_intf_net -intf_net smartconnect_0_M07_AXI [get_bd_intf_pins smartconnect_0/M07_AXI] [get_bd_intf_pins eth_7/s_axi_control]
  connect_bd_intf_net -intf_net vpt_0_m_axi [get_bd_intf_pins vpt_0/m_axi] [get_bd_intf_pins vrs_0_b/S_AXI]
  connect_bd_intf_net -intf_net vpt_1_m_axi [get_bd_intf_pins vpt_1/m_axi] [get_bd_intf_pins vrs_1_b/S_AXI]
  connect_bd_intf_net -intf_net vpt_2_m_axi [get_bd_intf_pins vpt_2/m_axi] [get_bd_intf_pins vrs_2_b/S_AXI]
  connect_bd_intf_net -intf_net vpt_3_m_axi [get_bd_intf_pins vpt_3/m_axi] [get_bd_intf_pins vrs_3_b/S_AXI]
  connect_bd_intf_net -intf_net vrs_0_a_M_AXI [get_bd_intf_pins vrs_0_a/M_AXI] [get_bd_intf_pins vpt_0/s_axi]
  connect_bd_intf_net -intf_net vrs_0_b_M_AXI [get_bd_intf_pins vrs_0_b/M_AXI] [get_bd_intf_pins noc_virt_0/S00_AXI]
  connect_bd_intf_net -intf_net vrs_1_a_M_AXI [get_bd_intf_pins vrs_1_a/M_AXI] [get_bd_intf_pins vpt_1/s_axi]
  connect_bd_intf_net -intf_net vrs_1_b_M_AXI [get_bd_intf_pins vrs_1_b/M_AXI] [get_bd_intf_pins noc_virt_1/S00_AXI]
  connect_bd_intf_net -intf_net vrs_2_a_M_AXI [get_bd_intf_pins vrs_2_a/M_AXI] [get_bd_intf_pins vpt_2/s_axi]
  connect_bd_intf_net -intf_net vrs_2_b_M_AXI [get_bd_intf_pins vrs_2_b/M_AXI] [get_bd_intf_pins noc_virt_2/S00_AXI]
  connect_bd_intf_net -intf_net vrs_3_a_M_AXI [get_bd_intf_pins vrs_3_a/M_AXI] [get_bd_intf_pins vpt_3/s_axi]
  connect_bd_intf_net -intf_net vrs_3_b_M_AXI [get_bd_intf_pins vrs_3_b/M_AXI] [get_bd_intf_pins noc_virt_3/S00_AXI]

  # Create port connections
  connect_bd_net -net service_clk_1  [get_bd_ports service_clk] \
  [get_bd_pins axi_noc_0/aclk0] \
  [get_bd_pins axi_noc_1/aclk0] \
  [get_bd_pins axi_noc_2/aclk0] \
  [get_bd_pins axi_noc_3/aclk0] \
  [get_bd_pins axi_noc_4/aclk0] \
  [get_bd_pins axi_noc_5/aclk0] \
  [get_bd_pins eth_0/ap_clk] \
  [get_bd_pins eth_1/ap_clk] \
  [get_bd_pins eth_2/ap_clk] \
  [get_bd_pins eth_3/ap_clk] \
  [get_bd_pins eth_4/ap_clk] \
  [get_bd_pins eth_5/ap_clk] \
  [get_bd_pins eth_6/ap_clk] \
  [get_bd_pins eth_7/ap_clk] \
  [get_bd_pins noc_virt_0/aclk0] \
  [get_bd_pins noc_virt_1/aclk0] \
  [get_bd_pins noc_virt_2/aclk0] \
  [get_bd_pins noc_virt_3/aclk0] \
  [get_bd_pins noc_virt_4/aclk0] \
  [get_bd_pins qpt/aclk] \
  [get_bd_pins qrs_a/aclk] \
  [get_bd_pins qrs_b/aclk] \
  [get_bd_pins sl2noc_0/aclk0] \
  [get_bd_pins sl2noc_1/aclk0] \
  [get_bd_pins sl2noc_2/aclk0] \
  [get_bd_pins sl2noc_3/aclk0] \
  [get_bd_pins sl2noc_4/aclk0] \
  [get_bd_pins sl2noc_5/aclk0] \
  [get_bd_pins sl2noc_6/aclk0] \
  [get_bd_pins sl2noc_7/aclk0] \
  [get_bd_pins smartconnect_0/aclk] \
  [get_bd_pins vpt_0/aclk] \
  [get_bd_pins vpt_1/aclk] \
  [get_bd_pins vpt_2/aclk] \
  [get_bd_pins vpt_3/aclk] \
  [get_bd_pins vrs_0_a/aclk] \
  [get_bd_pins vrs_0_b/aclk] \
  [get_bd_pins vrs_1_a/aclk] \
  [get_bd_pins vrs_1_b/aclk] \
  [get_bd_pins vrs_2_a/aclk] \
  [get_bd_pins vrs_2_b/aclk] \
  [get_bd_pins vrs_3_a/aclk] \
  [get_bd_pins vrs_3_b/aclk]
  connect_bd_net -net service_resetn_1  [get_bd_ports service_resetn] \
  [get_bd_pins eth_0/ap_rst_n] \
  [get_bd_pins eth_1/ap_rst_n] \
  [get_bd_pins eth_2/ap_rst_n] \
  [get_bd_pins eth_3/ap_rst_n] \
  [get_bd_pins eth_4/ap_rst_n] \
  [get_bd_pins eth_5/ap_rst_n] \
  [get_bd_pins eth_6/ap_rst_n] \
  [get_bd_pins eth_7/ap_rst_n] \
  [get_bd_pins qpt/aresetn] \
  [get_bd_pins qrs_a/aresetn] \
  [get_bd_pins qrs_b/aresetn] \
  [get_bd_pins smartconnect_0/aresetn] \
  [get_bd_pins vpt_0/aresetn] \
  [get_bd_pins vpt_1/aresetn] \
  [get_bd_pins vpt_2/aresetn] \
  [get_bd_pins vpt_3/aresetn] \
  [get_bd_pins vrs_0_a/aresetn] \
  [get_bd_pins vrs_0_b/aresetn] \
  [get_bd_pins vrs_1_a/aresetn] \
  [get_bd_pins vrs_1_b/aresetn] \
  [get_bd_pins vrs_2_a/aresetn] \
  [get_bd_pins vrs_2_b/aresetn] \
  [get_bd_pins vrs_3_a/aresetn] \
  [get_bd_pins vrs_3_b/aresetn]

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


