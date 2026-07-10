
################################################################
# This is a generated script based on design: felix_cips
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
# source felix_cips_script.tcl


# The design that will be created by this Tcl script contains the following 
# block design container source references:
# service_layer, slash

# Please add the sources before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcvp1552-vsva3340-2MHP-e-S
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name felix_cips

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
xilinx.com:ip:clk_wizard:1.0\
xilinx.com:ip:versal_cips:3.4\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:inline_hdl:ilreduced_logic:1.0\
xilinx.com:ip:c_shift_ram:12.0\
xilinx.com:ip:hw_discovery:1.0\
xilinx.com:ip:shell_utils_uuid_rom:2.0\
xilinx.com:ip:cmd_queue:2.0\
xilinx.com:ip:util_reduced_logic:2.0\
xilinx.com:ip:util_vector_logic:2.0\
xilinx.com:ip:axi_gpio:2.0\
xilinx.com:ip:xlconcat:2.1\
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

##################################################################
# CHECK Block Design Container Sources
##################################################################
set bCheckSources 1
set list_bdc_active "service_layer, slash"

array set map_bdc_missing {}
set map_bdc_missing(ACTIVE) ""
set map_bdc_missing(BDC) ""

if { $bCheckSources == 1 } {
   set list_check_srcs "\ 
service_layer \
slash \
"

   common::send_gid_msg -ssname BD::TCL -id 2056 -severity "INFO" "Checking if the following sources for block design container exist in the project: $list_check_srcs .\n\n"

   foreach src $list_check_srcs {
      if { [can_resolve_reference $src] == 0 } {
         if { [lsearch $list_bdc_active $src] != -1 } {
            set map_bdc_missing(ACTIVE) "$map_bdc_missing(ACTIVE) $src"
         } else {
            set map_bdc_missing(BDC) "$map_bdc_missing(BDC) $src"
         }
      }
   }

   if { [llength $map_bdc_missing(ACTIVE)] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2057 -severity "ERROR" "The following source(s) of Active variants are not found in the project: $map_bdc_missing(ACTIVE)" }
      common::send_gid_msg -ssname BD::TCL -id 2060 -severity "INFO" "Please add source files for the missing source(s) above."
      set bCheckIPsPassed 0
   }
   if { [llength $map_bdc_missing(BDC)] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2059 -severity "WARNING" "The following source(s) of variants are not found in the project: $map_bdc_missing(BDC)" }
      common::send_gid_msg -ssname BD::TCL -id 2060 -severity "INFO" "Please add source files for the missing source(s) above."
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: pcie_mgmt_pdi_reset
proc create_hier_cell_pcie_mgmt_pdi_reset { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_pcie_mgmt_pdi_reset() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi


  # Create pins
  create_bd_pin -dir I -type rst resetn
  create_bd_pin -dir I -type clk clk
  create_bd_pin -dir I -from 0 -to 0 resetn_in

  # Create instance: and_0, and set properties
  set and_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 and_0 ]
  set_property CONFIG.C_SIZE {2} $and_0


  # Create instance: inv, and set properties
  set inv [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 inv ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $inv


  # Create instance: pcie_mgmt_pdi_reset_gpio, and set properties
  set pcie_mgmt_pdi_reset_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 pcie_mgmt_pdi_reset_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_INPUTS {0} \
    CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {1} \
    CONFIG.C_GPIO_WIDTH {1} \
    CONFIG.C_INTERRUPT_PRESENT {0} \
    CONFIG.C_IS_DUAL {1} \
  ] $pcie_mgmt_pdi_reset_gpio


  # Create instance: ccat, and set properties
  set ccat [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 ccat ]

  # Create interface connections
  connect_bd_intf_net -intf_net S_AXI_0_1 [get_bd_intf_pins s_axi] [get_bd_intf_pins pcie_mgmt_pdi_reset_gpio/S_AXI]

  # Create port connections
  connect_bd_net -net Op1_1_1  [get_bd_pins resetn_in] \
  [get_bd_pins inv/Op1]
  connect_bd_net -net axi_gpio_0_gpio_io_o  [get_bd_pins pcie_mgmt_pdi_reset_gpio/gpio_io_o] \
  [get_bd_pins ccat/In0]
  connect_bd_net -net s_axi_aclk_0_1  [get_bd_pins clk] \
  [get_bd_pins pcie_mgmt_pdi_reset_gpio/s_axi_aclk]
  connect_bd_net -net s_axi_aresetn_0_1  [get_bd_pins resetn] \
  [get_bd_pins pcie_mgmt_pdi_reset_gpio/s_axi_aresetn]
  connect_bd_net -net util_reduced_logic_0_Res  [get_bd_pins and_0/Res] \
  [get_bd_pins pcie_mgmt_pdi_reset_gpio/gpio2_io_i]
  connect_bd_net -net util_vector_logic_0_Res  [get_bd_pins inv/Res] \
  [get_bd_pins ccat/In1]
  connect_bd_net -net xlconcat_0_dout  [get_bd_pins ccat/dout] \
  [get_bd_pins and_0/Op1]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: clock_reset
proc create_hier_cell_clock_reset { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_clock_reset() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_pcie_mgmt_pdi_reset


  # Create pins
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_pl_periph
  create_bd_pin -dir O -from 0 -to 0 -type rst reset_pl_ic
  create_bd_pin -dir I -type clk clk_freerun
  create_bd_pin -dir O -type clk clk_usr_1
  create_bd_pin -dir O -type clk clk_usr_0
  create_bd_pin -dir I -type clk clk_pcie
  create_bd_pin -dir I -from 0 -to 0 dma_axi_aresetn
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_pcie_ic
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_pcie_periph
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_usr_0_ic
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_usr_0_periph
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_usr_1_ic
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_usr_1_periph
  create_bd_pin -dir I -type clk clk_pl
  create_bd_pin -dir I -type rst resetn_pl_axi

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]
  set_property CONFIG.C_EXT_RST_WIDTH {1} $proc_sys_reset_0


  # Create instance: pcie_mgmt_pdi_reset
  create_hier_cell_pcie_mgmt_pdi_reset $hier_obj pcie_mgmt_pdi_reset

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]
  set_property CONFIG.C_EXT_RST_WIDTH {1} $proc_sys_reset_1


  # Create instance: proc_sys_reset_2, and set properties
  set proc_sys_reset_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_2 ]
  set_property CONFIG.C_EXT_RST_WIDTH {1} $proc_sys_reset_2


  # Create instance: proc_sys_reset_3, and set properties
  set proc_sys_reset_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_3 ]
  set_property CONFIG.C_EXT_RST_WIDTH {1} $proc_sys_reset_3


  # Create instance: usr_clk_wiz, and set properties
  set usr_clk_wiz [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard:1.0 usr_clk_wiz ]
  set_property -dict [list \
    CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
    CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
    CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
    CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
    CONFIG.CLKOUT_PORT {clk_out1,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
    CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {300,500,100.000,100.000,100.000,100.000,100.000} \
    CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
    CONFIG.CLKOUT_USED {true,true,false,false,false,false,false} \
    CONFIG.USE_LOCKED {true} \
  ] $usr_clk_wiz


  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins s_axi_pcie_mgmt_pdi_reset] [get_bd_intf_pins pcie_mgmt_pdi_reset/s_axi]

  # Create port connections
  connect_bd_net -net Op1_1_1  [get_bd_pins dma_axi_aresetn] \
  [get_bd_pins pcie_mgmt_pdi_reset/resetn_in]
  connect_bd_net -net clk_in1_0_1  [get_bd_pins clk_freerun] \
  [get_bd_pins usr_clk_wiz/clk_in1]
  connect_bd_net -net clk_wizard_0_clk_out1  [get_bd_pins usr_clk_wiz/clk_out1] \
  [get_bd_pins clk_usr_0] \
  [get_bd_pins proc_sys_reset_3/slowest_sync_clk]
  connect_bd_net -net clk_wizard_0_clk_out2  [get_bd_pins usr_clk_wiz/clk_out2] \
  [get_bd_pins clk_usr_1] \
  [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net clk_wizard_0_locked  [get_bd_pins usr_clk_wiz/locked] \
  [get_bd_pins proc_sys_reset_3/dcm_locked] \
  [get_bd_pins proc_sys_reset_1/dcm_locked]
  connect_bd_net -net ext_reset_in_0_1  [get_bd_pins resetn_pl_axi] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_interconnect_aresetn  [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
  [get_bd_pins reset_pl_ic] \
  [get_bd_pins proc_sys_reset_2/ext_reset_in] \
  [get_bd_pins proc_sys_reset_3/ext_reset_in] \
  [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins resetn_pl_periph] \
  [get_bd_pins pcie_mgmt_pdi_reset/resetn]
  connect_bd_net -net proc_sys_reset_1_interconnect_aresetn  [get_bd_pins proc_sys_reset_1/interconnect_aresetn] \
  [get_bd_pins resetn_usr_1_ic]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn  [get_bd_pins proc_sys_reset_1/peripheral_aresetn] \
  [get_bd_pins resetn_usr_1_periph]
  connect_bd_net -net proc_sys_reset_2_interconnect_aresetn  [get_bd_pins proc_sys_reset_2/interconnect_aresetn] \
  [get_bd_pins resetn_pcie_ic]
  connect_bd_net -net proc_sys_reset_2_peripheral_aresetn  [get_bd_pins proc_sys_reset_2/peripheral_aresetn] \
  [get_bd_pins resetn_pcie_periph]
  connect_bd_net -net proc_sys_reset_3_interconnect_aresetn  [get_bd_pins proc_sys_reset_3/interconnect_aresetn] \
  [get_bd_pins resetn_usr_0_ic]
  connect_bd_net -net proc_sys_reset_3_peripheral_aresetn  [get_bd_pins proc_sys_reset_3/peripheral_aresetn] \
  [get_bd_pins resetn_usr_0_periph]
  connect_bd_net -net slowest_sync_clk_0_1  [get_bd_pins clk_pcie] \
  [get_bd_pins proc_sys_reset_2/slowest_sync_clk]
  connect_bd_net -net slowest_sync_clk_1_1  [get_bd_pins clk_pl] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
  [get_bd_pins pcie_mgmt_pdi_reset/clk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: base_logic
proc create_hier_cell_base_logic { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_base_logic() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_pcie_mgmt_pdi_reset

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_pcie_mgmt_slr0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:pcie3_cfg_ext_rtl:1.0 pcie_cfg_ext

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_rpu


  # Create pins
  create_bd_pin -dir I -type clk clk_pl
  create_bd_pin -dir I -type rst resetn_pl_ic
  create_bd_pin -dir I -type clk clk_pcie
  create_bd_pin -dir I -type rst resetn_pcie_periph
  create_bd_pin -dir O -type intr irq_gcq_m2r
  create_bd_pin -dir I -type rst resetn_pl_periph

  # Create instance: rpu_sc, and set properties
  set rpu_sc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 rpu_sc ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
  ] $rpu_sc


  # Create instance: pcie_slr0_mgmt_sc, and set properties
  set pcie_slr0_mgmt_sc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 pcie_slr0_mgmt_sc ]
  set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.NUM_SI {1} \
  ] $pcie_slr0_mgmt_sc


  # Create instance: hw_discovery, and set properties
  set hw_discovery [ create_bd_cell -type ip -vlnv xilinx.com:ip:hw_discovery:1.0 hw_discovery ]

  # Create instance: uuid_rom, and set properties
  set uuid_rom [ create_bd_cell -type ip -vlnv xilinx.com:ip:shell_utils_uuid_rom:2.0 uuid_rom ]

  # Create instance: gcq_m2r, and set properties
  set gcq_m2r [ create_bd_cell -type ip -vlnv xilinx.com:ip:cmd_queue:2.0 gcq_m2r ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins pcie_slr0_mgmt_sc/M03_AXI] [get_bd_intf_pins m_axi_pcie_mgmt_pdi_reset]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins pcie_slr0_mgmt_sc/S00_AXI] [get_bd_intf_pins s_axi_pcie_mgmt_slr0]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins hw_discovery/s_pcie4_cfg_ext] [get_bd_intf_pins pcie_cfg_ext]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins rpu_sc/S00_AXI] [get_bd_intf_pins s_axi_rpu]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins rpu_sc/M00_AXI] [get_bd_intf_pins gcq_m2r/S01_AXI]
  connect_bd_intf_net -intf_net smartconnect_1_M00_AXI [get_bd_intf_pins pcie_slr0_mgmt_sc/M00_AXI] [get_bd_intf_pins hw_discovery/s_axi_ctrl_pf0]
  connect_bd_intf_net -intf_net smartconnect_1_M01_AXI [get_bd_intf_pins pcie_slr0_mgmt_sc/M01_AXI] [get_bd_intf_pins uuid_rom/S_AXI]
  connect_bd_intf_net -intf_net smartconnect_1_M02_AXI [get_bd_intf_pins pcie_slr0_mgmt_sc/M02_AXI] [get_bd_intf_pins gcq_m2r/S00_AXI]

  # Create port connections
  connect_bd_net -net aclk_1_1  [get_bd_pins clk_pl] \
  [get_bd_pins pcie_slr0_mgmt_sc/aclk] \
  [get_bd_pins rpu_sc/aclk] \
  [get_bd_pins hw_discovery/aclk_ctrl] \
  [get_bd_pins uuid_rom/S_AXI_ACLK] \
  [get_bd_pins gcq_m2r/aclk]
  connect_bd_net -net aclk_pcie_0_1  [get_bd_pins clk_pcie] \
  [get_bd_pins hw_discovery/aclk_pcie]
  connect_bd_net -net aresetn_1_1  [get_bd_pins resetn_pl_ic] \
  [get_bd_pins pcie_slr0_mgmt_sc/aresetn] \
  [get_bd_pins rpu_sc/aresetn]
  connect_bd_net -net aresetn_ctrl_0_1  [get_bd_pins resetn_pl_periph] \
  [get_bd_pins hw_discovery/aresetn_ctrl] \
  [get_bd_pins uuid_rom/S_AXI_ARESETN] \
  [get_bd_pins gcq_m2r/aresetn]
  connect_bd_net -net aresetn_pcie_0_1  [get_bd_pins resetn_pcie_periph] \
  [get_bd_pins hw_discovery/aresetn_pcie]
  connect_bd_net -net cmd_queue_0_irq_sq  [get_bd_pins gcq_m2r/irq_sq] \
  [get_bd_pins irq_gcq_m2r]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: virt_noc
proc create_hier_cell_virt_noc { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_virt_noc() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI3

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI2

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI4

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI3

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI2

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI4


  # Create pins

  # Create instance: axi_noc_3, and set properties
  set axi_noc_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_3 ]
  set_property -dict [list \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_3


  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/virt_noc/axi_noc_3/S00_INI]

  # Create instance: axi_noc_4, and set properties
  set axi_noc_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_4 ]
  set_property -dict [list \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_4


  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/virt_noc/axi_noc_4/S00_INI]

  # Create instance: axi_noc_1, and set properties
  set axi_noc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_1


  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/virt_noc/axi_noc_1/S00_INI]

  # Create instance: axi_noc_2, and set properties
  set axi_noc_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_2 ]
  set_property -dict [list \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_2


  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/virt_noc/axi_noc_2/S00_INI]

  # Create instance: axi_noc_0, and set properties
  set axi_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_0


  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/virt_noc/axi_noc_0/S00_INI]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins axi_noc_0/S00_INI] [get_bd_intf_pins S00_INI]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins axi_noc_0/M00_INI] [get_bd_intf_pins M00_INI]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins axi_noc_3/S00_INI] [get_bd_intf_pins S00_INI3]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins axi_noc_2/S00_INI] [get_bd_intf_pins S00_INI2]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins axi_noc_1/S00_INI] [get_bd_intf_pins S00_INI1]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins axi_noc_4/S00_INI] [get_bd_intf_pins S00_INI4]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins axi_noc_3/M00_INI] [get_bd_intf_pins M00_INI3]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins axi_noc_2/M00_INI] [get_bd_intf_pins M00_INI2]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins axi_noc_1/M00_INI] [get_bd_intf_pins M00_INI1]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins axi_noc_4/M00_INI] [get_bd_intf_pins M00_INI4]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: clk_rst_shell
proc create_hier_cell_clk_rst_shell { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_clk_rst_shell() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI


  # Create pins
  create_bd_pin -dir O -from 0 -to 0 -type data service_arstn
  create_bd_pin -dir O -from 0 -to 0 -type data slash_arstn
  create_bd_pin -dir O -type clk slash_clk
  create_bd_pin -dir I -type clk pl0_ref_clk
  create_bd_pin -dir I -type rst aresetn
  create_bd_pin -dir O -type clk service_clk
  create_bd_pin -dir I -type clk refclk

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_0


  # Create instance: clk_wizard_service, and set properties
  set clk_wizard_service [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard:1.0 clk_wizard_service ]
  set_property -dict [list \
    CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
    CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
    CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
    CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
    CONFIG.CLKOUT_PORT {clk_out1,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
    CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {300.000,100.000,100.000,100.000,100.000,100.000,100.000} \
    CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
    CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
    CONFIG.USE_DYN_RECONFIG {true} \
  ] $clk_wizard_service


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: axi_noc_0, and set properties
  set axi_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
  set_property -dict [list \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_0


  set_property -dict [ list \
   CONFIG.APERTURES {{0x201_8000_0000 1G}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /static_region/clk_rst_shell/axi_noc_0/M00_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \
 ] [get_bd_intf_pins /static_region/clk_rst_shell/axi_noc_0/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /static_region/clk_rst_shell/axi_noc_0/aclk0]

  # Create instance: clk_wizard_slash, and set properties
  set clk_wizard_slash [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard:1.0 clk_wizard_slash ]
  set_property -dict [list \
    CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
    CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
    CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
    CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
    CONFIG.CLKOUT_PORT {clk_out1,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
    CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {200.000,100.000,100.000,100.000,100.000,100.000,100.000} \
    CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
    CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
    CONFIG.USE_DYN_RECONFIG {true} \
  ] $clk_wizard_slash


  # Create instance: service_rst_conv_in, and set properties
  set service_rst_conv_in [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilreduced_logic:1.0 service_rst_conv_in ]
  set_property -dict [list \
    CONFIG.C_OPERATION {or} \
    CONFIG.C_SIZE {1} \
  ] $service_rst_conv_in


  # Create instance: service_rst_pipe_slr0, and set properties
  set service_rst_pipe_slr0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_shift_ram:12.0 service_rst_pipe_slr0 ]
  set_property -dict [list \
    CONFIG.Depth {1} \
    CONFIG.Width {1} \
  ] $service_rst_pipe_slr0


  # Create instance: slash_rst_conv_in, and set properties
  set slash_rst_conv_in [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilreduced_logic:1.0 slash_rst_conv_in ]
  set_property -dict [list \
    CONFIG.C_OPERATION {or} \
    CONFIG.C_SIZE {1} \
  ] $slash_rst_conv_in


  # Create instance: slash_rst_pipe_slr0, and set properties
  set slash_rst_pipe_slr0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_shift_ram:12.0 slash_rst_pipe_slr0 ]
  set_property -dict [list \
    CONFIG.Depth {1} \
    CONFIG.Width {1} \
  ] $slash_rst_pipe_slr0


  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins axi_noc_0/S00_INI] [get_bd_intf_pins S00_INI]
  connect_bd_intf_net -intf_net axi_noc_1_M00_AXI [get_bd_intf_pins axi_noc_0/M00_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins clk_wizard_slash/s_axi_lite]
  connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins clk_wizard_service/s_axi_lite]

  # Create port connections
  connect_bd_net -net aclk0_1_1  [get_bd_pins pl0_ref_clk] \
  [get_bd_pins axi_noc_0/aclk0] \
  [get_bd_pins smartconnect_0/aclk] \
  [get_bd_pins clk_wizard_slash/s_axi_aclk] \
  [get_bd_pins clk_wizard_service/s_axi_aclk]
  connect_bd_net -net c_shift_ram_0_Q  [get_bd_pins service_rst_pipe_slr0/Q] \
  [get_bd_pins service_arstn]
  connect_bd_net -net clk_in1_0_1  [get_bd_pins refclk] \
  [get_bd_pins clk_wizard_slash/clk_in1] \
  [get_bd_pins clk_wizard_service/clk_in1]
  connect_bd_net -net clk_wizard_service_clk_out1  [get_bd_pins clk_wizard_service/clk_out1] \
  [get_bd_pins service_clk] \
  [get_bd_pins proc_sys_reset_1/slowest_sync_clk] \
  [get_bd_pins service_rst_pipe_slr0/CLK]
  connect_bd_net -net clk_wizard_service_locked  [get_bd_pins clk_wizard_service/locked] \
  [get_bd_pins proc_sys_reset_1/dcm_locked]
  connect_bd_net -net clk_wizard_slash_clk_out1  [get_bd_pins clk_wizard_slash/clk_out1] \
  [get_bd_pins slash_clk] \
  [get_bd_pins slash_rst_pipe_slr0/CLK] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net clk_wizard_slash_locked  [get_bd_pins clk_wizard_slash/locked] \
  [get_bd_pins proc_sys_reset_0/dcm_locked]
  connect_bd_net -net ext_reset_in_1_1  [get_bd_pins aresetn] \
  [get_bd_pins proc_sys_reset_1/ext_reset_in] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in] \
  [get_bd_pins smartconnect_0/aresetn] \
  [get_bd_pins clk_wizard_service/s_axi_aresetn] \
  [get_bd_pins clk_wizard_slash/s_axi_aresetn]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins slash_rst_conv_in/Op1]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn  [get_bd_pins proc_sys_reset_1/peripheral_aresetn] \
  [get_bd_pins service_rst_conv_in/Op1]
  connect_bd_net -net service_rst_conv_in_Res  [get_bd_pins service_rst_conv_in/Res] \
  [get_bd_pins service_rst_pipe_slr0/D]
  connect_bd_net -net slash_rst_conv_in_Res  [get_bd_pins slash_rst_conv_in/Res] \
  [get_bd_pins slash_rst_pipe_slr0/D]
  connect_bd_net -net slash_rst_pipe_slr0_Q  [get_bd_pins slash_rst_pipe_slr0/Q] \
  [get_bd_pins slash_arstn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: noc
proc create_hier_cell_noc { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_noc() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M01_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk0_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 CH0_DDR4_0_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M04_INI_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M05_INI_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M06_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S03_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S01_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S02_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S00_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S02_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S01_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S15_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S16_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S21_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S14_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S20_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S03_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S13_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S12_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S19_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S18_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S22_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S17_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S23_INI_0


  # Create pins
  create_bd_pin -dir I -type clk aclk4_0
  create_bd_pin -dir I -type clk aclk6_0
  create_bd_pin -dir I -type clk aclk5_0
  create_bd_pin -dir I -type clk aclk2_0
  create_bd_pin -dir I -type clk aclk3_0
  create_bd_pin -dir I -type clk aclk0_0
  create_bd_pin -dir I -type clk aclk1_0

  # Create instance: axi_noc_mc_ddr4_0, and set properties
  set axi_noc_mc_ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_mc_ddr4_0 ]
  set_property -dict [list \
    CONFIG.CONTROLLERTYPE {DDR4_SDRAM} \
    CONFIG.MC0_CONFIG_NUM {config14} \
    CONFIG.MC_CHAN_REGION1 {DDR_CH1_1} \
    CONFIG.MC_DATAWIDTH {72} \
    CONFIG.MC_EN_INTR_RESP {TRUE} \
    CONFIG.MC_INPUTCLK0_PERIOD {5000} \
    CONFIG.MC_MEMORY_DEVICETYPE {UDIMMs} \
    CONFIG.MC_MEMORY_SPEEDGRADE {DDR4-2666V(19-19-19)} \
    CONFIG.MC_MEMORY_TIMEPERIOD0 {800} \
    CONFIG.MC_RANK {1} \
    CONFIG.MC_ROWADDRESSWIDTH {17} \
    CONFIG.NUM_CLKS {0} \
    CONFIG.NUM_MC {1} \
    CONFIG.NUM_MCP {4} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {0} \
    CONFIG.NUM_NSI {2} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_mc_ddr4_0


  set_property -dict [ list \
   CONFIG.CONNECTIONS {MC_0 {read_bw {1000} write_bw {1000} initial_boot {false}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_mc_ddr4_0/S00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {MC_1 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_mc_ddr4_0/S01_INI]

  # Create instance: axi_noc_cips, and set properties
  set axi_noc_cips [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_cips ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {7} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_NMI {7} \
    CONFIG.NUM_NSI {24} \
    CONFIG.NUM_SI {4} \
    CONFIG.SI_SIDEBAND_PINS {} \
  ] $axi_noc_cips


  set_property -dict [ list \
   CONFIG.APERTURES {{0x201_0000_0000 32M}} \
   CONFIG.CATEGORY {pl} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/M00_AXI]

  set_property -dict [ list \
   CONFIG.CATEGORY {ps_pmc} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/M01_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M02_INI {read_bw {500} write_bw {500} initial_boot {true}} M06_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}} M04_INI {read_bw {500} write_bw {500} initial_boot {true}} M05_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_AXI {read_bw {5} write_bw {5}} M00_INI {read_bw {128} write_bw {128} initial_boot {false}}} \
   CONFIG.DEST_IDS {M01_AXI:0x1:M00_AXI:0x700} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {ps_pcie} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S00_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S00_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {500} write_bw {500} initial_boot {true}} M06_INI {read_bw {500} write_bw {500} initial_boot {true}} M01_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {true}} M03_INI {read_bw {500} write_bw {500} initial_boot {true}} M04_INI {read_bw {500} write_bw {500} initial_boot {true}} M05_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_AXI {read_bw {5} write_bw {5}}} \
   CONFIG.DEST_IDS {M01_AXI:0x1:M00_AXI:0x700} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {ps_pcie} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S01_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S01_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M02_INI {read_bw {500} write_bw {500} initial_boot {true}} M00_INI {read_bw {500} write_bw {500} initial_boot {false}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {ps_pmc} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S02_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S02_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500} initial_boot {false}}} \
   CONFIG.DEST_IDS {} \
   CONFIG.NOC_PARAMS {} \
   CONFIG.CATEGORY {ps_rpu} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S03_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S03_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S04_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S05_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S06_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S07_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S12_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S13_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S14_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S15_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S16_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S17_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S18_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S19_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S20_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S21_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S22_INI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M01_INI {read_bw {100} write_bw {100}}} \
 ] [get_bd_intf_pins /static_region/noc/axi_noc_cips/S23_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk0]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S01_AXI} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk1]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S02_AXI} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk2]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S03_AXI} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk3]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk4]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk5]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M01_AXI} \
 ] [get_bd_pins /static_region/noc/axi_noc_cips/aclk6]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins axi_noc_cips/M00_AXI] [get_bd_intf_pins M00_AXI_0]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins axi_noc_cips/M01_AXI] [get_bd_intf_pins M01_AXI_0]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins axi_noc_mc_ddr4_0/sys_clk0] [get_bd_intf_pins sys_clk0_0]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins axi_noc_mc_ddr4_0/CH0_DDR4_0] [get_bd_intf_pins CH0_DDR4_0_0]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins axi_noc_cips/M04_INI] [get_bd_intf_pins M04_INI_0]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins axi_noc_cips/M05_INI] [get_bd_intf_pins M05_INI_0]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins axi_noc_cips/M06_INI] [get_bd_intf_pins M06_INI_0]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins axi_noc_cips/S03_AXI] [get_bd_intf_pins S03_AXI_0]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins axi_noc_cips/S01_AXI] [get_bd_intf_pins S01_AXI_0]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins axi_noc_cips/S02_INI] [get_bd_intf_pins S02_INI_0]
  connect_bd_intf_net -intf_net Conn11 [get_bd_intf_pins axi_noc_cips/S00_AXI] [get_bd_intf_pins S00_AXI_0]
  connect_bd_intf_net -intf_net Conn12 [get_bd_intf_pins axi_noc_cips/S02_AXI] [get_bd_intf_pins S02_AXI_0]
  connect_bd_intf_net -intf_net Conn13 [get_bd_intf_pins axi_noc_cips/S00_INI] [get_bd_intf_pins S00_INI_0]
  connect_bd_intf_net -intf_net Conn14 [get_bd_intf_pins axi_noc_cips/S01_INI] [get_bd_intf_pins S01_INI_0]
  connect_bd_intf_net -intf_net Conn16 [get_bd_intf_pins axi_noc_cips/S15_INI] [get_bd_intf_pins S15_INI_0]
  connect_bd_intf_net -intf_net Conn17 [get_bd_intf_pins axi_noc_cips/S16_INI] [get_bd_intf_pins S16_INI_0]
  connect_bd_intf_net -intf_net Conn18 [get_bd_intf_pins axi_noc_cips/S21_INI] [get_bd_intf_pins S21_INI_0]
  connect_bd_intf_net -intf_net Conn19 [get_bd_intf_pins axi_noc_cips/S14_INI] [get_bd_intf_pins S14_INI_0]
  connect_bd_intf_net -intf_net Conn21 [get_bd_intf_pins axi_noc_cips/S20_INI] [get_bd_intf_pins S20_INI_0]
  connect_bd_intf_net -intf_net Conn22 [get_bd_intf_pins axi_noc_cips/S03_INI] [get_bd_intf_pins S03_INI_0]
  connect_bd_intf_net -intf_net Conn25 [get_bd_intf_pins axi_noc_cips/S13_INI] [get_bd_intf_pins S13_INI_0]
  connect_bd_intf_net -intf_net Conn27 [get_bd_intf_pins axi_noc_cips/S12_INI] [get_bd_intf_pins S12_INI_0]
  connect_bd_intf_net -intf_net Conn29 [get_bd_intf_pins axi_noc_cips/S19_INI] [get_bd_intf_pins S19_INI_0]
  connect_bd_intf_net -intf_net Conn31 [get_bd_intf_pins axi_noc_cips/S18_INI] [get_bd_intf_pins S18_INI_0]
  connect_bd_intf_net -intf_net Conn33 [get_bd_intf_pins axi_noc_cips/S22_INI] [get_bd_intf_pins S22_INI_0]
  connect_bd_intf_net -intf_net Conn34 [get_bd_intf_pins axi_noc_cips/S17_INI] [get_bd_intf_pins S17_INI_0]
  connect_bd_intf_net -intf_net Conn35 [get_bd_intf_pins axi_noc_cips/S23_INI] [get_bd_intf_pins S23_INI_0]
  connect_bd_intf_net -intf_net axi_noc_cips_M00_INI [get_bd_intf_pins axi_noc_cips/M00_INI] [get_bd_intf_pins axi_noc_mc_ddr4_0/S00_INI]
  connect_bd_intf_net -intf_net axi_noc_cips_M01_INI [get_bd_intf_pins axi_noc_cips/M01_INI] [get_bd_intf_pins axi_noc_mc_ddr4_0/S01_INI]

  # Create port connections
  connect_bd_net -net aclk0_0_1  [get_bd_pins aclk0_0] \
  [get_bd_pins axi_noc_cips/aclk0]
  connect_bd_net -net aclk1_0_1  [get_bd_pins aclk1_0] \
  [get_bd_pins axi_noc_cips/aclk1]
  connect_bd_net -net aclk2_0_1  [get_bd_pins aclk2_0] \
  [get_bd_pins axi_noc_cips/aclk2]
  connect_bd_net -net aclk3_0_1  [get_bd_pins aclk3_0] \
  [get_bd_pins axi_noc_cips/aclk3]
  connect_bd_net -net aclk4_0_1  [get_bd_pins aclk4_0] \
  [get_bd_pins axi_noc_cips/aclk4]
  connect_bd_net -net aclk5_0_1  [get_bd_pins aclk5_0] \
  [get_bd_pins axi_noc_cips/aclk5]
  connect_bd_net -net aclk6_0_1  [get_bd_pins aclk6_0] \
  [get_bd_pins axi_noc_cips/aclk6]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: aved
proc create_hier_cell_aved { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_aved() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 LPD_AXI_NOC_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 PMC_NOC_AXI_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 CPM_PCIE_NOC_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 CPM_PCIE_NOC_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 gt_pciea1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_pcie_mgmt_slr0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 NOC_PMC_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 NOC_CPM_PCIE_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_pcie_refclk


  # Create pins
  create_bd_pin -dir O -type clk pl3_ref_clk
  create_bd_pin -dir O -type rst pl3_resetn
  create_bd_pin -dir O -type clk lpd_axi_noc_clk
  create_bd_pin -dir O -type clk pmc_axi_noc_axi0_clk
  create_bd_pin -dir O -type clk noc_pmc_axi_axi0_clk
  create_bd_pin -dir O eos
  create_bd_pin -dir O -type clk noc_cpm_pcie_axi0_clk
  create_bd_pin -dir O -type clk cpm_pcie_noc_axi0_clk
  create_bd_pin -dir O -type clk cpm_pcie_noc_axi1_clk
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_pl_periph
  create_bd_pin -dir O pl0_resetn
  create_bd_pin -dir O pl0_ref_clk

  # Create instance: cips, and set properties
  set cips [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.4 cips ]
  set_property -dict [list \
    CONFIG.BOOT_MODE {Custom} \
    CONFIG.CPM_CONFIG { \
      CPM_PCIE0_MODES {None} \
      CPM_PCIE0_TANDEM {None} \
      CPM_PCIE1_ACS_CAP_ON {0} \
      CPM_PCIE1_ARI_CAP_ENABLED {1} \
      CPM_PCIE1_BRIDGE_AXI_SLAVE_IF {1} \
      CPM_PCIE1_CFG_EXT_IF {1} \
      CPM_PCIE1_CFG_VEND_ID {10ee} \
      CPM_PCIE1_COPY_PF0_QDMA_ENABLED {0} \
      CPM_PCIE1_EXT_PCIE_CFG_SPACE_ENABLED {Extended_Large} \
      CPM_PCIE1_FUNCTIONAL_MODE {QDMA} \
      CPM_PCIE1_MAX_LINK_SPEED {32.0_GT/s} \
      CPM_PCIE1_MODES {DMA} \
      CPM_PCIE1_MODE_SELECTION {Advanced} \
      CPM_PCIE1_MSI_X_OPTIONS {MSI-X_Internal} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_BASEADDR_0 {0x0000008000000000} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_BASEADDR_1 {0x0000008040000000} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_BASEADDR_2 {0x0000008080000000} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_BASEADDR_3 {0x00000080C0000000} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_BASEADDR_4 {0x0000008100000000} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_BASEADDR_5 {0x0000008140000000} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_HIGHADDR_0 {0x000000803FFFFFFFF} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_HIGHADDR_1 {0x000000807FFFFFFFF} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_HIGHADDR_2 {0x00000080BFFFFFFFF} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_HIGHADDR_3 {0x00000080FFFFFFFFF} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_HIGHADDR_4 {0x000000813FFFFFFFF} \
      CPM_PCIE1_PF0_AXIBAR2PCIE_HIGHADDR_5 {0x000000817FFFFFFFF} \
      CPM_PCIE1_PF0_BAR0_QDMA_64BIT {1} \
      CPM_PCIE1_PF0_BAR0_QDMA_ENABLED {1} \
      CPM_PCIE1_PF0_BAR0_QDMA_PREFETCHABLE {1} \
      CPM_PCIE1_PF0_BAR0_QDMA_SCALE {Megabytes} \
      CPM_PCIE1_PF0_BAR0_QDMA_SIZE {256} \
      CPM_PCIE1_PF0_BAR0_QDMA_TYPE {AXI_Bridge_Master} \
      CPM_PCIE1_PF0_BAR2_QDMA_64BIT {0} \
      CPM_PCIE1_PF0_BAR2_QDMA_ENABLED {0} \
      CPM_PCIE1_PF0_BAR2_QDMA_PREFETCHABLE {0} \
      CPM_PCIE1_PF0_BAR2_QDMA_SCALE {Kilobytes} \
      CPM_PCIE1_PF0_BAR2_QDMA_SIZE {4} \
      CPM_PCIE1_PF0_BAR2_QDMA_TYPE {AXI_Bridge_Master} \
      CPM_PCIE1_PF0_BASE_CLASS_VALUE {12} \
      CPM_PCIE1_PF0_CFG_DEV_ID {50b4} \
      CPM_PCIE1_PF0_CFG_SUBSYS_ID {000e} \
      CPM_PCIE1_PF0_DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE {0} \
      CPM_PCIE1_PF0_MSIX_CAP_TABLE_OFFSET {40} \
      CPM_PCIE1_PF0_MSIX_CAP_TABLE_SIZE {1} \
      CPM_PCIE1_PF0_MSIX_ENABLED {0} \
      CPM_PCIE1_PF0_PCIEBAR2AXIBAR_QDMA_0 {0x0000020100000000} \
      CPM_PCIE1_PF0_SUB_CLASS_VALUE {00} \
      CPM_PCIE1_PF1_BAR0_QDMA_64BIT {1} \
      CPM_PCIE1_PF1_BAR0_QDMA_ENABLED {1} \
      CPM_PCIE1_PF1_BAR0_QDMA_PREFETCHABLE {1} \
      CPM_PCIE1_PF1_BAR0_QDMA_SCALE {Kilobytes} \
      CPM_PCIE1_PF1_BAR0_QDMA_SIZE {512} \
      CPM_PCIE1_PF1_BAR0_QDMA_TYPE {DMA} \
      CPM_PCIE1_PF1_BAR2_QDMA_64BIT {0} \
      CPM_PCIE1_PF1_BAR2_QDMA_ENABLED {0} \
      CPM_PCIE1_PF1_BAR2_QDMA_PREFETCHABLE {0} \
      CPM_PCIE1_PF1_BAR2_QDMA_SCALE {Kilobytes} \
      CPM_PCIE1_PF1_BAR2_QDMA_SIZE {4} \
      CPM_PCIE1_PF1_BAR2_QDMA_TYPE {AXI_Bridge_Master} \
      CPM_PCIE1_PF1_BASE_CLASS_VALUE {12} \
      CPM_PCIE1_PF1_CFG_DEV_ID {50b5} \
      CPM_PCIE1_PF1_CFG_SUBSYS_ID {000e} \
      CPM_PCIE1_PF1_CFG_SUBSYS_VEND_ID {10EE} \
      CPM_PCIE1_PF1_MSIX_CAP_TABLE_OFFSET {50000} \
      CPM_PCIE1_PF1_MSIX_CAP_TABLE_SIZE {8} \
      CPM_PCIE1_PF1_MSIX_ENABLED {1} \
      CPM_PCIE1_PF1_PCIEBAR2AXIBAR_QDMA_2 {0x0000020200000000} \
      CPM_PCIE1_PF1_SUB_CLASS_VALUE {00} \
      CPM_PCIE1_PF2_BAR0_QDMA_64BIT {1} \
      CPM_PCIE1_PF2_BAR0_QDMA_SCALE {Megabytes} \
      CPM_PCIE1_PF2_BAR0_QDMA_SIZE {128} \
      CPM_PCIE1_PF2_BAR0_QDMA_TYPE {AXI_Bridge_Master} \
      CPM_PCIE1_PF2_BAR2_QDMA_64BIT {1} \
      CPM_PCIE1_PF2_BAR2_QDMA_ENABLED {1} \
      CPM_PCIE1_PF2_BAR2_QDMA_SCALE {Megabytes} \
      CPM_PCIE1_PF2_BAR2_QDMA_SIZE {128} \
      CPM_PCIE1_PF2_BAR2_QDMA_TYPE {AXI_Bridge_Master} \
      CPM_PCIE1_PF2_BAR3_QDMA_ENABLED {0} \
      CPM_PCIE1_PF2_BAR3_QDMA_SIZE {4} \
      CPM_PCIE1_PF2_BAR4_QDMA_64BIT {1} \
      CPM_PCIE1_PF2_BAR4_QDMA_ENABLED {1} \
      CPM_PCIE1_PF2_BAR4_QDMA_SIZE {512} \
      CPM_PCIE1_PF2_BASE_CLASS_VALUE {12} \
      CPM_PCIE1_PF2_CFG_DEV_ID {50b6} \
      CPM_PCIE1_PF2_CFG_SUBSYS_ID {000e} \
      CPM_PCIE1_PF2_CFG_SUBSYS_VEND_ID {10EE} \
      CPM_PCIE1_PF2_PCIEBAR2AXIBAR_QDMA_0 {0x0000020200000000} \
      CPM_PCIE1_PF2_PCIEBAR2AXIBAR_QDMA_2 {0x0000020300000000} \
      CPM_PCIE1_PF2_PCIEBAR2AXIBAR_QDMA_4 {0x0000020400000000} \
      CPM_PCIE1_PF2_USE_CLASS_CODE_LOOKUP_ASSISTANT {0} \
      CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
      CPM_PCIE1_TL_PF_ENABLE_REG {3} \
    } \
    CONFIG.DEVICE_INTEGRITY_MODE {Custom} \
    CONFIG.IO_CONFIG_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      BOOT_MODE {Custom} \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Custom} \
      DESIGN_MODE {1} \
      DEVICE_INTEGRITY_MODE {Custom} \
      IO_CONFIG_MODE {Custom} \
      PCIE_APERTURES_DUAL_ENABLE {0} \
      PCIE_APERTURES_SINGLE_ENABLE {1} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_CRP_PL1_REF_CTRL_FREQMHZ {33.33} \
      PMC_CRP_PL2_REF_CTRL_FREQMHZ {250} \
      PMC_CRP_PL3_REF_CTRL_FREQMHZ {100} \
      PMC_GLITCH_CONFIG {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.80}} \
      PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_SD0_DATA_TRANSFER_MODE {8Bit} \
      PMC_SD0_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x00} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x1E} {CLK_50_DDR_OTAP_DLY 0x5} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x5} {ENABLE 1} {IO\
{PMC_MIO 13 .. 25}}} \
      PMC_SD0_SLOT_TYPE {eMMC} \
      PMC_USE_NOC_PMC_AXI0 {1} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {Custom} \
      PS_ENET0_MDIO {{ENABLE 0} {IO {PMC_MIO 50 .. 51}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 26 .. 37}}} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI3_MASTER {R5_0} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI4_MASTER {R5_0} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI5_MASTER {R5_1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_GEN_IPI6_MASTER {R5_1} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 2 .. 3}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 1}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 0} {CH11 0} {CH12 0} {CH13 0} {CH14 0} {CH15 0} {CH2 0} {CH3 0} {CH4 0} {CH5 0} {CH6 0} {CH7 0} {CH8 0} {CH9 0}} \
      PS_M_AXI_LPD_DATA_WIDTH {32} \
      PS_NUM_FABRIC_RESETS {4} \
      PS_PCIE1_PERIPHERAL_ENABLE {0} \
      PS_PCIE2_PERIPHERAL_ENABLE {1} \
      PS_PCIE_EP_RESET1_IO {PMC_MIO 24} \
      PS_PCIE_EP_RESET2_IO {PMC_MIO 25} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_SPI0 {{GRP_SS0_ENABLE 1} {GRP_SS0_IO {PMC_MIO 29}} {GRP_SS1_ENABLE 0} {GRP_SS1_IO {PMC_MIO 14}} {GRP_SS2_ENABLE 0} {GRP_SS2_IO {PMC_MIO 13}} {PERIPHERAL_ENABLE 1} {PERIPHERAL_IO {PMC_MIO 26 ..\
31}}} \
      PS_TTC0_PERIPHERAL_ENABLE {1} \
      PS_TTC1_PERIPHERAL_ENABLE {1} \
      PS_TTC2_PERIPHERAL_ENABLE {1} \
      PS_TTC3_PERIPHERAL_ENABLE {1} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_UART1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {1} \
      PS_USE_PMCPL_CLK2 {1} \
      PS_USE_PMCPL_CLK3 {1} \
      PS_USE_STARTUP {1} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_MEAS0 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCCAUX_202} {SUPPLY_NUM 52}} \
      SMON_MEAS1 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCCAUX_203} {SUPPLY_NUM 53}} \
      SMON_MEAS10 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVTT_202} {SUPPLY_NUM 47}} \
      SMON_MEAS11 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVTT_203} {SUPPLY_NUM 48}} \
      SMON_MEAS12 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVTT_204} {SUPPLY_NUM 49}} \
      SMON_MEAS13 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVTT_205} {SUPPLY_NUM 50}} \
      SMON_MEAS14 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVTT_206} {SUPPLY_NUM 51}} \
      SMON_MEAS15 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_102} {SUPPLY_NUM 57}} \
      SMON_MEAS16 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_103} {SUPPLY_NUM 58}} \
      SMON_MEAS17 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_104} {SUPPLY_NUM 59}} \
      SMON_MEAS18 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_105} {SUPPLY_NUM 60}} \
      SMON_MEAS19 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_106} {SUPPLY_NUM 61}} \
      SMON_MEAS2 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCCAUX_204} {SUPPLY_NUM 54}} \
      SMON_MEAS24 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_200} {SUPPLY_NUM 62}} \
      SMON_MEAS25 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_201} {SUPPLY_NUM 63}} \
      SMON_MEAS3 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCCAUX_205} {SUPPLY_NUM 55}} \
      SMON_MEAS32 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_102} {SUPPLY_NUM 40}} \
      SMON_MEAS33 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_103} {SUPPLY_NUM 41}} \
      SMON_MEAS34 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_104} {SUPPLY_NUM 42}} \
      SMON_MEAS35 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_105} {SUPPLY_NUM 43}} \
      SMON_MEAS36 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_106} {SUPPLY_NUM 44}} \
      SMON_MEAS4 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCCAUX_206} {SUPPLY_NUM 56}} \
      SMON_MEAS41 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_200} {SUPPLY_NUM 45}} \
      SMON_MEAS42 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_201} {SUPPLY_NUM 46}} \
      SMON_MEAS49 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_102} {SUPPLY_NUM 28}} \
      SMON_MEAS5 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCC_202} {SUPPLY_NUM 35}} \
      SMON_MEAS50 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_103} {SUPPLY_NUM 29}} \
      SMON_MEAS51 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_104} {SUPPLY_NUM 30}} \
      SMON_MEAS52 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_105} {SUPPLY_NUM 31}} \
      SMON_MEAS53 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_106} {SUPPLY_NUM 32}} \
      SMON_MEAS58 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_200} {SUPPLY_NUM 33}} \
      SMON_MEAS59 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_201} {SUPPLY_NUM 34}} \
      SMON_MEAS6 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCC_203} {SUPPLY_NUM 36}} \
      SMON_MEAS66 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX} {SUPPLY_NUM 7}} \
      SMON_MEAS67 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX_PMC} {SUPPLY_NUM 8}} \
      SMON_MEAS68 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX_SMON} {SUPPLY_NUM 9}} \
      SMON_MEAS69 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCINT} {SUPPLY_NUM 6}} \
      SMON_MEAS7 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCC_204} {SUPPLY_NUM 37}} \
      SMON_MEAS70 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_500} {SUPPLY_NUM 11}} \
      SMON_MEAS71 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_501} {SUPPLY_NUM 12}} \
      SMON_MEAS72 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_502} {SUPPLY_NUM 13}} \
      SMON_MEAS73 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_503} {SUPPLY_NUM 14}} \
      SMON_MEAS74 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_700} {SUPPLY_NUM 15}} \
      SMON_MEAS75 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_701} {SUPPLY_NUM 16}} \
      SMON_MEAS76 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_702} {SUPPLY_NUM 17}} \
      SMON_MEAS77 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_703} {SUPPLY_NUM 18}} \
      SMON_MEAS78 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_704} {SUPPLY_NUM 19}} \
      SMON_MEAS79 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_705} {SUPPLY_NUM 20}} \
      SMON_MEAS8 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCC_205} {SUPPLY_NUM 38}} \
      SMON_MEAS80 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_706} {SUPPLY_NUM 21}} \
      SMON_MEAS81 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_707} {SUPPLY_NUM 22}} \
      SMON_MEAS82 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_708} {SUPPLY_NUM 23}} \
      SMON_MEAS83 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_709} {SUPPLY_NUM 24}} \
      SMON_MEAS84 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_710} {SUPPLY_NUM 25}} \
      SMON_MEAS85 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_711} {SUPPLY_NUM 26}} \
      SMON_MEAS86 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_712} {SUPPLY_NUM 27}} \
      SMON_MEAS87 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 0} {MODE {2 V unipolar}} {NAME VCC_BATT} {SUPPLY_NUM 0}} \
      SMON_MEAS88 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PMC} {SUPPLY_NUM 1}} \
      SMON_MEAS89 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PSFP} {SUPPLY_NUM 2}} \
      SMON_MEAS9 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTM_AVCC_206} {SUPPLY_NUM 39}} \
      SMON_MEAS90 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PSLP} {SUPPLY_NUM 3}} \
      SMON_MEAS91 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_RAM} {SUPPLY_NUM 4}} \
      SMON_MEAS92 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_SOC} {SUPPLY_NUM 5}} \
      SMON_MEAS93 {{ALARM_ENABLE 0} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {1 V unipolar}} {NAME VP_VN} {SUPPLY_NUM 10}} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
    CONFIG.PS_PMC_CONFIG_APPLIED {1} \
  ] $cips


  # Create instance: base_logic
  create_hier_cell_base_logic $hier_obj base_logic

  # Create instance: clock_reset
  create_hier_cell_clock_reset $hier_obj clock_reset

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins cips/NOC_PMC_AXI_0] [get_bd_intf_pins NOC_PMC_AXI_0]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins cips/NOC_CPM_PCIE_0] [get_bd_intf_pins NOC_CPM_PCIE_0]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins cips/gt_refclk1] [get_bd_intf_pins gt_pcie_refclk]
  connect_bd_intf_net -intf_net S00_AXI_1_1 [get_bd_intf_pins s_axi_pcie_mgmt_slr0] [get_bd_intf_pins base_logic/s_axi_pcie_mgmt_slr0]
  connect_bd_intf_net -intf_net base_logic_m_axi_pcie_mgmt_pdi_reset [get_bd_intf_pins base_logic/m_axi_pcie_mgmt_pdi_reset] [get_bd_intf_pins clock_reset/s_axi_pcie_mgmt_pdi_reset]
  connect_bd_intf_net -intf_net cips_CPM_PCIE_NOC_0 [get_bd_intf_pins CPM_PCIE_NOC_0] [get_bd_intf_pins cips/CPM_PCIE_NOC_0]
  connect_bd_intf_net -intf_net cips_CPM_PCIE_NOC_1 [get_bd_intf_pins CPM_PCIE_NOC_1] [get_bd_intf_pins cips/CPM_PCIE_NOC_1]
  connect_bd_intf_net -intf_net cips_LPD_AXI_NOC_0 [get_bd_intf_pins LPD_AXI_NOC_0] [get_bd_intf_pins cips/LPD_AXI_NOC_0]
  connect_bd_intf_net -intf_net cips_M_AXI_LPD [get_bd_intf_pins cips/M_AXI_LPD] [get_bd_intf_pins base_logic/s_axi_rpu]
  connect_bd_intf_net -intf_net cips_PCIE1_GT [get_bd_intf_pins gt_pciea1] [get_bd_intf_pins cips/PCIE1_GT]
  connect_bd_intf_net -intf_net cips_PMC_NOC_AXI_0 [get_bd_intf_pins PMC_NOC_AXI_0] [get_bd_intf_pins cips/PMC_NOC_AXI_0]
  connect_bd_intf_net -intf_net cips_pcie1_cfg_ext [get_bd_intf_pins cips/pcie1_cfg_ext] [get_bd_intf_pins base_logic/pcie_cfg_ext]

  # Create port connections
  connect_bd_net -net base_logic_irq_gcq_m2r  [get_bd_pins base_logic/irq_gcq_m2r] \
  [get_bd_pins cips/pl_ps_irq0]
  connect_bd_net -net cips_cpm_pcie_noc_axi0_clk  [get_bd_pins cips/cpm_pcie_noc_axi0_clk] \
  [get_bd_pins cpm_pcie_noc_axi0_clk]
  connect_bd_net -net cips_cpm_pcie_noc_axi1_clk  [get_bd_pins cips/cpm_pcie_noc_axi1_clk] \
  [get_bd_pins cpm_pcie_noc_axi1_clk]
  connect_bd_net -net cips_eos  [get_bd_pins cips/eos] \
  [get_bd_pins eos]
  connect_bd_net -net cips_lpd_axi_noc_clk  [get_bd_pins cips/lpd_axi_noc_clk] \
  [get_bd_pins lpd_axi_noc_clk]
  connect_bd_net -net cips_noc_cpm_pcie_axi0_clk  [get_bd_pins cips/noc_cpm_pcie_axi0_clk] \
  [get_bd_pins noc_cpm_pcie_axi0_clk]
  connect_bd_net -net cips_noc_pmc_axi_axi0_clk  [get_bd_pins cips/noc_pmc_axi_axi0_clk] \
  [get_bd_pins noc_pmc_axi_axi0_clk]
  connect_bd_net -net cips_pl0_ref_clk  [get_bd_pins cips/pl0_ref_clk] \
  [get_bd_pins clock_reset/clk_pl] \
  [get_bd_pins cips/m_axi_lpd_aclk] \
  [get_bd_pins base_logic/clk_pl] \
  [get_bd_pins pl0_ref_clk]
  connect_bd_net -net cips_pl0_resetn  [get_bd_pins cips/pl0_resetn] \
  [get_bd_pins clock_reset/resetn_pl_axi] \
  [get_bd_pins pl0_resetn]
  connect_bd_net -net cips_pl1_ref_clk  [get_bd_pins cips/pl1_ref_clk] \
  [get_bd_pins clock_reset/clk_freerun]
  connect_bd_net -net cips_pl3_ref_clk  [get_bd_pins cips/pl3_ref_clk] \
  [get_bd_pins pl3_ref_clk]
  connect_bd_net -net cips_pl3_resetn  [get_bd_pins cips/pl3_resetn] \
  [get_bd_pins pl3_resetn]
  connect_bd_net -net cips_pmc_axi_noc_axi0_clk  [get_bd_pins cips/pmc_axi_noc_axi0_clk] \
  [get_bd_pins pmc_axi_noc_axi0_clk]
  connect_bd_net -net clk_pcie_1  [get_bd_pins cips/pl2_ref_clk] \
  [get_bd_pins clock_reset/clk_pcie] \
  [get_bd_pins cips/dma1_intrfc_clk] \
  [get_bd_pins base_logic/clk_pcie]
  connect_bd_net -net clock_reset_peripheral_aresetn_0  [get_bd_pins clock_reset/resetn_pl_periph] \
  [get_bd_pins resetn_pl_periph] \
  [get_bd_pins base_logic/resetn_pl_periph]
  connect_bd_net -net clock_reset_reset_pl_ic  [get_bd_pins clock_reset/reset_pl_ic] \
  [get_bd_pins base_logic/resetn_pl_ic]
  connect_bd_net -net clock_reset_resetn_pcie_ic  [get_bd_pins clock_reset/resetn_pcie_ic] \
  [get_bd_pins cips/dma1_intrfc_resetn]
  connect_bd_net -net clock_reset_resetn_pcie_periph  [get_bd_pins clock_reset/resetn_pcie_periph] \
  [get_bd_pins base_logic/resetn_pcie_periph]
  connect_bd_net -net dma_axi_aresetn_1  [get_bd_pins cips/dma1_axi_aresetn] \
  [get_bd_pins clock_reset/dma_axi_aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: static_region
proc create_hier_cell_static_region { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_static_region() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 gt_pciea1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_pcie_refclk

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 CH0_DDR4_0_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M04_INI_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M05_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI6

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk0_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI2

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI3

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI4

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI5

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI2

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI3

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:inimm_rtl:1.0 M00_INI4

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S00_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S01_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S02_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S03_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S12_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S13_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S14_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S15_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S16_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S17_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S18_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S19_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S20_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S21_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S22_INI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:inimm_rtl:1.0 S23_INI_0


  # Create pins
  create_bd_pin -dir O -type clk pl3_ref_clk
  create_bd_pin -dir O -type rst pl3_resetn
  create_bd_pin -dir O eos_0
  create_bd_pin -dir O -from 0 -to 0 -type data peripheral_aresetn1
  create_bd_pin -dir O -from 0 -to 0 -type data peripheral_aresetn2
  create_bd_pin -dir O -type clk clk_out3
  create_bd_pin -dir O -type clk clk_out2
  create_bd_pin -dir O pl0_ref_clk
  create_bd_pin -dir O -type clk clk_out1
  create_bd_pin -dir O -from 0 -to 0 -type rst resetn_pl_periph_0

  # Create instance: aved
  create_hier_cell_aved $hier_obj aved

  # Create instance: noc
  create_hier_cell_noc $hier_obj noc

  # Create instance: axi_noc_1, and set properties
  set axi_noc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_1 ]
  set_property -dict [list \
    CONFIG.MI_SIDEBAND_PINS {} \
    CONFIG.NUM_CLKS {2} \
    CONFIG.NUM_NSI {1} \
    CONFIG.NUM_SI {0} \
  ] $axi_noc_1


  set_property -dict [ list \
   CONFIG.CATEGORY {ps_pcie} \
 ] [get_bd_intf_pins /static_region/axi_noc_1/M00_AXI]

  set_property -dict [ list \
   CONFIG.CONNECTIONS {M00_AXI {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4} initial_boot {false}}} \
 ] [get_bd_intf_pins /static_region/axi_noc_1/S00_INI]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {} \
 ] [get_bd_pins /static_region/axi_noc_1/aclk0]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M00_AXI} \
 ] [get_bd_pins /static_region/axi_noc_1/aclk1]

  # Create instance: clk_rst_shell
  create_hier_cell_clk_rst_shell $hier_obj clk_rst_shell

  # Create instance: clk_wizard_0, and set properties
  set clk_wizard_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard:1.0 clk_wizard_0 ]
  set_property -dict [list \
    CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
    CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
    CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
    CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
    CONFIG.CLKOUT_PORT {clk_out1,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
    CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {400.000,100.000,100.000,100.000,100.000,100.000,100.000} \
    CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
    CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
  ] $clk_wizard_0


  # Create instance: virt_noc
  create_hier_cell_virt_noc $hier_obj virt_noc

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins axi_noc_1/S00_INI] [get_bd_intf_pins S00_INI6]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins noc/sys_clk0_0] [get_bd_intf_pins sys_clk0_0]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins aved/gt_pcie_refclk] [get_bd_intf_pins gt_pcie_refclk]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins virt_noc/S00_INI] [get_bd_intf_pins S00_INI1]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins virt_noc/M00_INI] [get_bd_intf_pins M00_INI]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins noc/CH0_DDR4_0_0] [get_bd_intf_pins CH0_DDR4_0_0]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins noc/M04_INI_0] [get_bd_intf_pins M04_INI_0]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins noc/M05_INI_0] [get_bd_intf_pins M05_INI_0]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins virt_noc/S00_INI3] [get_bd_intf_pins S00_INI2]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins virt_noc/S00_INI2] [get_bd_intf_pins S00_INI3]
  connect_bd_intf_net -intf_net Conn11 [get_bd_intf_pins virt_noc/S00_INI1] [get_bd_intf_pins S00_INI4]
  connect_bd_intf_net -intf_net Conn12 [get_bd_intf_pins virt_noc/S00_INI4] [get_bd_intf_pins S00_INI5]
  connect_bd_intf_net -intf_net Conn13 [get_bd_intf_pins virt_noc/M00_INI3] [get_bd_intf_pins M00_INI1]
  connect_bd_intf_net -intf_net Conn14 [get_bd_intf_pins virt_noc/M00_INI2] [get_bd_intf_pins M00_INI2]
  connect_bd_intf_net -intf_net Conn15 [get_bd_intf_pins virt_noc/M00_INI1] [get_bd_intf_pins M00_INI3]
  connect_bd_intf_net -intf_net Conn16 [get_bd_intf_pins virt_noc/M00_INI4] [get_bd_intf_pins M00_INI4]
  connect_bd_intf_net -intf_net NOC_PMC_AXI_0_1 [get_bd_intf_pins aved/NOC_PMC_AXI_0] [get_bd_intf_pins noc/M01_AXI_0]
  connect_bd_intf_net -intf_net S00_AXI_0_1 [get_bd_intf_pins noc/S00_AXI_0] [get_bd_intf_pins aved/CPM_PCIE_NOC_0]
  connect_bd_intf_net -intf_net S00_INI_0_1 [get_bd_intf_pins noc/S00_INI_0] [get_bd_intf_pins S00_INI_0]
  connect_bd_intf_net -intf_net S01_AXI_0_1 [get_bd_intf_pins noc/S01_AXI_0] [get_bd_intf_pins aved/CPM_PCIE_NOC_1]
  connect_bd_intf_net -intf_net S01_INI_0_1 [get_bd_intf_pins noc/S01_INI_0] [get_bd_intf_pins S01_INI_0]
  connect_bd_intf_net -intf_net S02_INI_0_1 [get_bd_intf_pins noc/S02_INI_0] [get_bd_intf_pins S02_INI_0]
  connect_bd_intf_net -intf_net S03_AXI_0_1 [get_bd_intf_pins noc/S03_AXI_0] [get_bd_intf_pins aved/LPD_AXI_NOC_0]
  connect_bd_intf_net -intf_net S03_INI_0_1 [get_bd_intf_pins noc/S03_INI_0] [get_bd_intf_pins S03_INI_0]
  connect_bd_intf_net -intf_net S12_INI_0_1 [get_bd_intf_pins noc/S12_INI_0] [get_bd_intf_pins S12_INI_0]
  connect_bd_intf_net -intf_net S13_INI_0_1 [get_bd_intf_pins noc/S13_INI_0] [get_bd_intf_pins S13_INI_0]
  connect_bd_intf_net -intf_net S14_INI_0_1 [get_bd_intf_pins noc/S14_INI_0] [get_bd_intf_pins S14_INI_0]
  connect_bd_intf_net -intf_net S15_INI_0_1 [get_bd_intf_pins noc/S15_INI_0] [get_bd_intf_pins S15_INI_0]
  connect_bd_intf_net -intf_net S16_INI_0_1 [get_bd_intf_pins noc/S16_INI_0] [get_bd_intf_pins S16_INI_0]
  connect_bd_intf_net -intf_net S17_INI_0_1 [get_bd_intf_pins noc/S17_INI_0] [get_bd_intf_pins S17_INI_0]
  connect_bd_intf_net -intf_net S18_INI_0_1 [get_bd_intf_pins noc/S18_INI_0] [get_bd_intf_pins S18_INI_0]
  connect_bd_intf_net -intf_net S19_INI_0_1 [get_bd_intf_pins noc/S19_INI_0] [get_bd_intf_pins S19_INI_0]
  connect_bd_intf_net -intf_net S20_INI_0_1 [get_bd_intf_pins noc/S20_INI_0] [get_bd_intf_pins S20_INI_0]
  connect_bd_intf_net -intf_net S21_INI_0_1 [get_bd_intf_pins noc/S21_INI_0] [get_bd_intf_pins S21_INI_0]
  connect_bd_intf_net -intf_net S22_INI_0_1 [get_bd_intf_pins noc/S22_INI_0] [get_bd_intf_pins S22_INI_0]
  connect_bd_intf_net -intf_net S23_INI_0_1 [get_bd_intf_pins noc/S23_INI_0] [get_bd_intf_pins S23_INI_0]
  connect_bd_intf_net -intf_net aved_PMC_NOC_AXI_0 [get_bd_intf_pins aved/PMC_NOC_AXI_0] [get_bd_intf_pins noc/S02_AXI_0]
  connect_bd_intf_net -intf_net axi_noc_0_M00_AXI [get_bd_intf_pins axi_noc_1/M00_AXI] [get_bd_intf_pins aved/NOC_CPM_PCIE_0]
  connect_bd_intf_net -intf_net cips_PCIE1_GT [get_bd_intf_pins gt_pciea1] [get_bd_intf_pins aved/gt_pciea1]
  connect_bd_intf_net -intf_net noc_M00_AXI_0 [get_bd_intf_pins noc/M00_AXI_0] [get_bd_intf_pins aved/s_axi_pcie_mgmt_slr0]
  connect_bd_intf_net -intf_net noc_M06_INI_0 [get_bd_intf_pins noc/M06_INI_0] [get_bd_intf_pins clk_rst_shell/S00_INI]

  # Create port connections
  connect_bd_net -net aved_cpm_pcie_noc_axi1_clk  [get_bd_pins aved/cpm_pcie_noc_axi1_clk] \
  [get_bd_pins noc/aclk1_0]
  connect_bd_net -net aved_lpd_axi_noc_clk  [get_bd_pins aved/lpd_axi_noc_clk] \
  [get_bd_pins noc/aclk3_0]
  connect_bd_net -net aved_noc_pmc_axi_axi0_clk  [get_bd_pins aved/noc_pmc_axi_axi0_clk] \
  [get_bd_pins noc/aclk6_0]
  connect_bd_net -net aved_pl0_ref_clk  [get_bd_pins aved/pl0_ref_clk] \
  [get_bd_pins noc/aclk0_0] \
  [get_bd_pins clk_rst_shell/pl0_ref_clk] \
  [get_bd_pins pl0_ref_clk]
  connect_bd_net -net aved_pl0_resetn  [get_bd_pins aved/pl0_resetn] \
  [get_bd_pins clk_rst_shell/aresetn]
  connect_bd_net -net aved_pmc_axi_noc_axi0_clk  [get_bd_pins aved/pmc_axi_noc_axi0_clk] \
  [get_bd_pins noc/aclk2_0]
  connect_bd_net -net aved_resetn_pl_periph  [get_bd_pins aved/resetn_pl_periph] \
  [get_bd_pins resetn_pl_periph_0]
  connect_bd_net -net cips_cpm_pcie_noc_axi0_clk  [get_bd_pins aved/cpm_pcie_noc_axi0_clk] \
  [get_bd_pins axi_noc_1/aclk0] \
  [get_bd_pins noc/aclk4_0]
  connect_bd_net -net cips_eos  [get_bd_pins aved/eos] \
  [get_bd_pins eos_0]
  connect_bd_net -net cips_noc_cpm_pcie_axi0_clk  [get_bd_pins aved/noc_cpm_pcie_axi0_clk] \
  [get_bd_pins axi_noc_1/aclk1]
  connect_bd_net -net cips_pl3_ref_clk  [get_bd_pins aved/pl3_ref_clk] \
  [get_bd_pins pl3_ref_clk] \
  [get_bd_pins clk_rst_shell/refclk] \
  [get_bd_pins clk_wizard_0/clk_in1]
  connect_bd_net -net cips_pl3_resetn  [get_bd_pins aved/pl3_resetn] \
  [get_bd_pins pl3_resetn]
  connect_bd_net -net clk_rst_shell_Q_0  [get_bd_pins clk_rst_shell/service_arstn] \
  [get_bd_pins peripheral_aresetn1]
  connect_bd_net -net clk_rst_shell_Q_1  [get_bd_pins clk_rst_shell/slash_arstn] \
  [get_bd_pins peripheral_aresetn2]
  connect_bd_net -net clk_rst_shell_clk_out1_0  [get_bd_pins clk_rst_shell/slash_clk] \
  [get_bd_pins clk_out3]
  connect_bd_net -net clk_rst_shell_clk_out1_1  [get_bd_pins clk_rst_shell/service_clk] \
  [get_bd_pins clk_out2]
  connect_bd_net -net clk_wizard_0_clk_out1  [get_bd_pins clk_wizard_0/clk_out1] \
  [get_bd_pins clk_out1] \
  [get_bd_pins noc/aclk5_0]

  # Restore current instance
  current_bd_instance $oldCurInst
}


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

  set_property -dict [list \
  SRC_RM_MAP./slash.slash {slash_inst_0} \
  SRC_RM_MAP./service_layer.service_layer {service_layer_inst_0} \
] [get_bd_designs $design_name]


  # Create interface ports
  set PCIE1_GT_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 PCIE1_GT_0 ]

  set gt_refclk1_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk1_0 ]

  set CH0_DDR4_0_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 CH0_DDR4_0_0 ]

  set sys_clk0_0_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk0_0_0 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $sys_clk0_0_0


  # Create ports
  set pl3_ref_clk_0 [ create_bd_port -dir O -type clk pl3_ref_clk_0 ]
  set pl3_resetn_0 [ create_bd_port -dir O -type rst pl3_resetn_0 ]
  set eos_0 [ create_bd_port -dir O eos_0 ]
  set Q_0 [ create_bd_port -dir O -from 0 -to 0 -type data Q_0 ]
  set Q_1 [ create_bd_port -dir O -from 0 -to 0 -type data Q_1 ]
  set clk_out1_0 [ create_bd_port -dir O -type clk clk_out1_0 ]
  set clk_out1_1 [ create_bd_port -dir O -type clk clk_out1_1 ]
  set clk_out1_2 [ create_bd_port -dir O -type clk clk_out1_2 ]
  set resetn_pl_periph_0 [ create_bd_port -dir O -from 0 -to 0 -type rst resetn_pl_periph_0 ]

  # Create instance: static_region
  create_hier_cell_static_region [current_bd_instance .] static_region

  # Create instance: service_layer, and set properties
  set service_layer [ create_bd_cell -type container -reference service_layer service_layer ]
  set_property -dict [list \
    CONFIG.ACTIVE_SIM_BD {service_layer.bd} \
    CONFIG.ACTIVE_SYNTH_BD {service_layer.bd} \
    CONFIG.ENABLE_DFX {true} \
    CONFIG.LIST_SIM_BD {service_layer.bd} \
    CONFIG.LIST_SYNTH_BD {service_layer.bd} \
    CONFIG.LOCK_PROPAGATE {true} \
  ] $service_layer


  set_property SELECTED_SIM_MODEL rtl  $service_layer

  # Create instance: slash, and set properties
  set slash [ create_bd_cell -type container -reference slash slash ]
  set_property -dict [list \
    CONFIG.ACTIVE_SIM_BD {slash.bd} \
    CONFIG.ACTIVE_SYNTH_BD {slash.bd} \
    CONFIG.ENABLE_DFX {true} \
    CONFIG.LIST_SIM_BD {slash.bd} \
    CONFIG.LIST_SYNTH_BD {slash.bd} \
    CONFIG.LOCK_PROPAGATE {true} \
  ] $slash


  set_property SELECTED_SIM_MODEL rtl  $slash

  # Create interface connections
  connect_bd_intf_net -intf_net S00_INI_1_1 [get_bd_intf_pins service_layer/M_QDMA_SLV_BRIDGE] [get_bd_intf_pins static_region/S00_INI6]
  connect_bd_intf_net -intf_net S00_INI_3_1 [get_bd_intf_pins slash/SL_VIRT_00] [get_bd_intf_pins static_region/S00_INI1]
  connect_bd_intf_net -intf_net S00_INI_4_1 [get_bd_intf_pins slash/SL_VIRT_01] [get_bd_intf_pins static_region/S00_INI2]
  connect_bd_intf_net -intf_net S00_INI_5_1 [get_bd_intf_pins slash/SL_VIRT_02] [get_bd_intf_pins static_region/S00_INI3]
  connect_bd_intf_net -intf_net S00_INI_6_1 [get_bd_intf_pins slash/SL_VIRT_03] [get_bd_intf_pins static_region/S00_INI4]
  connect_bd_intf_net -intf_net S00_INI_7_1 [get_bd_intf_pins slash/QDMA_SLAVE_BRIDGE_0] [get_bd_intf_pins static_region/S00_INI5]
  connect_bd_intf_net -intf_net S12_INI_0_1 [get_bd_intf_pins static_region/S12_INI_0] [get_bd_intf_pins service_layer/SL2NOC_0]
  connect_bd_intf_net -intf_net S13_INI_0_1 [get_bd_intf_pins static_region/S13_INI_0] [get_bd_intf_pins service_layer/SL2NOC_1]
  connect_bd_intf_net -intf_net S14_INI_0_1 [get_bd_intf_pins static_region/S14_INI_0] [get_bd_intf_pins service_layer/SL2NOC_2]
  connect_bd_intf_net -intf_net S15_INI_0_1 [get_bd_intf_pins static_region/S15_INI_0] [get_bd_intf_pins service_layer/SL2NOC_3]
  connect_bd_intf_net -intf_net S16_INI_0_1 [get_bd_intf_pins static_region/S16_INI_0] [get_bd_intf_pins service_layer/SL2NOC_4]
  connect_bd_intf_net -intf_net S17_INI_0_1 [get_bd_intf_pins static_region/S17_INI_0] [get_bd_intf_pins service_layer/SL2NOC_5]
  connect_bd_intf_net -intf_net S18_INI_0_1 [get_bd_intf_pins static_region/S18_INI_0] [get_bd_intf_pins service_layer/SL2NOC_6]
  connect_bd_intf_net -intf_net S19_INI_0_1 [get_bd_intf_pins static_region/S19_INI_0] [get_bd_intf_pins service_layer/SL2NOC_7]
  connect_bd_intf_net -intf_net S20_INI_0_1 [get_bd_intf_pins static_region/S20_INI_0] [get_bd_intf_pins service_layer/M_VIRT_0]
  connect_bd_intf_net -intf_net S21_INI_0_1 [get_bd_intf_pins static_region/S21_INI_0] [get_bd_intf_pins service_layer/M_VIRT_1]
  connect_bd_intf_net -intf_net S22_INI_0_1 [get_bd_intf_pins static_region/S22_INI_0] [get_bd_intf_pins service_layer/M_VIRT_2]
  connect_bd_intf_net -intf_net S23_INI_0_1 [get_bd_intf_pins static_region/S23_INI_0] [get_bd_intf_pins service_layer/M_VIRT_3]
  connect_bd_intf_net -intf_net cips_PCIE1_GT [get_bd_intf_ports PCIE1_GT_0] [get_bd_intf_pins static_region/gt_pciea1]
  connect_bd_intf_net -intf_net gt_refclk1_0_1 [get_bd_intf_ports gt_refclk1_0] [get_bd_intf_pins static_region/gt_pcie_refclk]
  connect_bd_intf_net -intf_net slash_M00_INI [get_bd_intf_pins slash/M00_INI] [get_bd_intf_pins static_region/S00_INI_0]
  connect_bd_intf_net -intf_net slash_M01_INI [get_bd_intf_pins slash/M01_INI] [get_bd_intf_pins static_region/S01_INI_0]
  connect_bd_intf_net -intf_net slash_M02_INI [get_bd_intf_pins slash/M02_INI] [get_bd_intf_pins static_region/S02_INI_0]
  connect_bd_intf_net -intf_net slash_M03_INI [get_bd_intf_pins slash/M03_INI] [get_bd_intf_pins static_region/S03_INI_0]
  connect_bd_intf_net -intf_net static_region_CH0_DDR4_0_0 [get_bd_intf_ports CH0_DDR4_0_0] [get_bd_intf_pins static_region/CH0_DDR4_0_0]
  connect_bd_intf_net -intf_net static_region_M00_INI_0 [get_bd_intf_pins service_layer/S_VIRT_00] [get_bd_intf_pins static_region/M00_INI]
  connect_bd_intf_net -intf_net static_region_M00_INI_1 [get_bd_intf_pins service_layer/S_VIRT_01] [get_bd_intf_pins static_region/M00_INI1]
  connect_bd_intf_net -intf_net static_region_M00_INI_2 [get_bd_intf_pins service_layer/S_VIRT_02] [get_bd_intf_pins static_region/M00_INI2]
  connect_bd_intf_net -intf_net static_region_M00_INI_3 [get_bd_intf_pins service_layer/S_VIRT_03] [get_bd_intf_pins static_region/M00_INI3]
  connect_bd_intf_net -intf_net static_region_M00_INI_4 [get_bd_intf_pins service_layer/S_QDMA_SLV_BRIDGE] [get_bd_intf_pins static_region/M00_INI4]
  connect_bd_intf_net -intf_net static_region_M04_INI_0 [get_bd_intf_pins slash/S_AXILITE_INI] [get_bd_intf_pins static_region/M04_INI_0]
  connect_bd_intf_net -intf_net static_region_M05_INI_0 [get_bd_intf_pins service_layer/S_AXILITE_INI] [get_bd_intf_pins static_region/M05_INI_0]
  connect_bd_intf_net -intf_net sys_clk0_0_0_1 [get_bd_intf_ports sys_clk0_0_0] [get_bd_intf_pins static_region/sys_clk0_0]

  # Create port connections
  connect_bd_net -net cips_eos  [get_bd_pins static_region/eos_0] \
  [get_bd_ports eos_0]
  connect_bd_net -net cips_pl3_ref_clk  [get_bd_pins static_region/pl3_ref_clk] \
  [get_bd_ports pl3_ref_clk_0]
  connect_bd_net -net cips_pl3_resetn  [get_bd_pins static_region/pl3_resetn] \
  [get_bd_ports pl3_resetn_0]
  connect_bd_net -net static_region_Q_0  [get_bd_pins static_region/peripheral_aresetn1] \
  [get_bd_ports Q_0] \
  [get_bd_pins service_layer/service_resetn]
  connect_bd_net -net static_region_Q_1  [get_bd_pins static_region/peripheral_aresetn2] \
  [get_bd_ports Q_1] \
  [get_bd_pins slash/slash_resetn]
  connect_bd_net -net static_region_clk_out1_0  [get_bd_pins static_region/clk_out3] \
  [get_bd_ports clk_out1_0] \
  [get_bd_pins slash/slash_clk]
  connect_bd_net -net static_region_clk_out1_1  [get_bd_pins static_region/clk_out2] \
  [get_bd_ports clk_out1_1] \
  [get_bd_pins service_layer/service_clk]
  connect_bd_net -net static_region_clk_out1_2  [get_bd_pins static_region/clk_out1] \
  [get_bd_ports clk_out1_2]
  connect_bd_net -net static_region_resetn_pl_periph_0  [get_bd_pins static_region/resetn_pl_periph_0] \
  [get_bd_ports resetn_pl_periph_0]

  # Create address segments
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_0/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_0/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_1/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_1/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_2/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_2/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_3/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_3/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_4/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_4/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_5/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_5/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_6/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_6/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/eth_7/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/eth_7/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0xE0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces service_layer/qpt/m_axi] [get_bd_addr_segs static_region/aved/cips/NOC_CPM_PCIE_0/pspmc_0_psv_noc_pcie_0] -force
  assign_bd_address -offset 0x000600000000 -range 0x000200000000 -target_address_space [get_bd_addr_spaces service_layer/qpt/m_axi] [get_bd_addr_segs static_region/aved/cips/NOC_CPM_PCIE_0/pspmc_0_psv_noc_pcie_1] -force
  assign_bd_address -offset 0x008000000000 -range 0x004000000000 -target_address_space [get_bd_addr_spaces service_layer/qpt/m_axi] [get_bd_addr_segs static_region/aved/cips/NOC_CPM_PCIE_0/pspmc_0_psv_noc_pcie_2] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_0/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_0/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_1/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_1/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_2/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_2/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_3/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces service_layer/vpt_3/m_axi] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_0/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_0/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_1/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_1/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_2/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_2/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_3/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces slash/ddr_bandwidth_3/Data_m_axi_gmem0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S00_INI/C0_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S00_INI/C0_DDR_LOW0] -force
  assign_bd_address -offset 0xFFA80000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_0] -force
  assign_bd_address -offset 0xFFA90000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_1] -force
  assign_bd_address -offset 0xFFAA0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_2] -force
  assign_bd_address -offset 0xFFAB0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_3] -force
  assign_bd_address -offset 0xFFAC0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_4] -force
  assign_bd_address -offset 0xFFAD0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_5] -force
  assign_bd_address -offset 0xFFAE0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_6] -force
  assign_bd_address -offset 0xFFAF0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_7] -force
  assign_bd_address -offset 0x000100800000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_0] -force
  assign_bd_address -offset 0x000100D10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_cti] -force
  assign_bd_address -offset 0x000100D00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_dbg] -force
  assign_bd_address -offset 0x000100D30000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_etm] -force
  assign_bd_address -offset 0x000100D20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_pmu] -force
  assign_bd_address -offset 0x000100D50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_cti] -force
  assign_bd_address -offset 0x000100D40000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_dbg] -force
  assign_bd_address -offset 0x000100D70000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_etm] -force
  assign_bd_address -offset 0x000100D60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_pmu] -force
  assign_bd_address -offset 0x000100CA0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_cti] -force
  assign_bd_address -offset 0x000100C60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_ela] -force
  assign_bd_address -offset 0x000100C30000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_etf] -force
  assign_bd_address -offset 0x000100C20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_fun] -force
  assign_bd_address -offset 0x000100F80000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_atm] -force
  assign_bd_address -offset 0x000100FA0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_cti2a] -force
  assign_bd_address -offset 0x000100FD0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_cti2d] -force
  assign_bd_address -offset 0x000100F40000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2a] -force
  assign_bd_address -offset 0x000100F50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2b] -force
  assign_bd_address -offset 0x000100F60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2c] -force
  assign_bd_address -offset 0x000100F70000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2d] -force
  assign_bd_address -offset 0x000100F20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_fun] -force
  assign_bd_address -offset 0x000100F00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_rom] -force
  assign_bd_address -offset 0x000100B80000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_atm] -force
  assign_bd_address -offset 0x000100BB0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_cti1b] -force
  assign_bd_address -offset 0x000100BC0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_cti1c] -force
  assign_bd_address -offset 0x000100BD0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_cti1d] -force
  assign_bd_address -offset 0x000100B70000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_stm] -force
  assign_bd_address -offset 0x000100980000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_lpd_atm] -force
  assign_bd_address -offset 0x0001009D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_lpd_cti] -force
  assign_bd_address -offset 0x0001008D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_pmc_cti] -force
  assign_bd_address -offset 0x000100A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_r50_cti] -force
  assign_bd_address -offset 0x000100A50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_r51_cti] -force
  assign_bd_address -offset 0xFC000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_cpm] -force
  assign_bd_address -offset 0xFF5E0000 -range 0x00300000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_crl_0] -force
  assign_bd_address -offset 0x000101260000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_crp_0] -force
  assign_bd_address -offset 0xFF020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_i2c_0] -force
  assign_bd_address -offset 0xFF030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_i2c_1] -force
  assign_bd_address -offset 0xFF360000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_3] -force
  assign_bd_address -offset 0xFF370000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_4] -force
  assign_bd_address -offset 0xFF380000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_5] -force
  assign_bd_address -offset 0xFF3A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_6] -force
  assign_bd_address -offset 0xFF320000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_pmc] -force
  assign_bd_address -offset 0xFF390000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_pmc_nobuf] -force
  assign_bd_address -offset 0xFF310000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_psm] -force
  assign_bd_address -offset 0xFF9B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_afi_0] -force
  assign_bd_address -offset 0xFF0A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_iou_secure_slcr_0] -force
  assign_bd_address -offset 0xFF080000 -range 0x00020000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_iou_slcr_0] -force
  assign_bd_address -offset 0xFF410000 -range 0x00100000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_slcr_0] -force
  assign_bd_address -offset 0xFF510000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_slcr_secure_0] -force
  assign_bd_address -offset 0xFF990000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_xppu_0] -force
  assign_bd_address -offset 0xFF960000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ocm_ctrl] -force
  assign_bd_address -offset 0xFFFC0000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ocm_ram_0] -force
  assign_bd_address -offset 0xFF980000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ocm_xmpu_0] -force
  assign_bd_address -offset 0x0001011E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_aes] -force
  assign_bd_address -offset 0x0001011F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_bbram_ctrl] -force
  assign_bd_address -offset 0x0001012D0000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_cfi_cframe_0] -force
  assign_bd_address -offset 0x0001012B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_cfu_apb_0] -force
  assign_bd_address -offset 0x0001011C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_dma_0] -force
  assign_bd_address -offset 0x0001011D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_dma_1] -force
  assign_bd_address -offset 0x000101250000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_efuse_cache] -force
  assign_bd_address -offset 0x000101240000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_efuse_ctrl] -force
  assign_bd_address -offset 0x000101110000 -range 0x00050000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_global_0] -force
  assign_bd_address -offset 0x000100280000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_iomodule_0] -force
  assign_bd_address -offset 0x000101010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ospi_0] -force
  assign_bd_address -offset 0x000100310000 -range 0x00008000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ppu1_mdm_0] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_qspi_ospi_flash_0] -force
  assign_bd_address -offset 0x000102000000 -range 0x00020000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram] -force
  assign_bd_address -offset 0x000100240000 -range 0x00020000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram_data_cntlr] -force
  assign_bd_address -offset 0x000100200000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram_instr_cntlr] -force
  assign_bd_address -offset 0x000106000000 -range 0x02000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram_npi] -force
  assign_bd_address -offset 0x000101200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_rsa] -force
  assign_bd_address -offset 0x0001012A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_rtc_0] -force
  assign_bd_address -offset 0x000101040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_sd_0] -force
  assign_bd_address -offset 0x000101210000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_sha] -force
  assign_bd_address -offset 0x000101220000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_slave_boot] -force
  assign_bd_address -offset 0x000102100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_slave_boot_stream] -force
  assign_bd_address -offset 0x000101270000 -range 0x00030000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_sysmon_0] -force
  assign_bd_address -offset 0x000100083000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_tmr_inject_0] -force
  assign_bd_address -offset 0x000100283000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_tmr_manager_0] -force
  assign_bd_address -offset 0x000101230000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_trng] -force
  assign_bd_address -offset 0x0001012F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_xmpu_0] -force
  assign_bd_address -offset 0x000101310000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_xppu_0] -force
  assign_bd_address -offset 0x000101300000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_xppu_npi_0] -force
  assign_bd_address -offset 0xFFC90000 -range 0x0000F000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_psm_global_reg] -force
  assign_bd_address -offset 0xFFE90000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_r5_1_atcm_global] -force
  assign_bd_address -offset 0xFFEB0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_r5_1_btcm_global] -force
  assign_bd_address -offset 0xFFE00000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_r5_tcm_ram_global] -force
  assign_bd_address -offset 0xFF9A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_rpu_0] -force
  assign_bd_address -offset 0xFF000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_sbsauart_0] -force
  assign_bd_address -offset 0xFF010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_sbsauart_1] -force
  assign_bd_address -offset 0xFF130000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_scntr_0] -force
  assign_bd_address -offset 0xFF140000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_scntrs_0] -force
  assign_bd_address -offset 0xFF040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_spi_0] -force
  assign_bd_address -offset 0xFF0E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_0] -force
  assign_bd_address -offset 0xFF0F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_1] -force
  assign_bd_address -offset 0xFF100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_2] -force
  assign_bd_address -offset 0xFF110000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_3] -force
  assign_bd_address -offset 0x020180000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/clk_rst_shell/clk_wizard_service/s_axi_lite/Reg] -force
  assign_bd_address -offset 0x020180010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/clk_rst_shell/clk_wizard_slash/s_axi_lite/Reg] -force
  assign_bd_address -offset 0x020200000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/ddr_bandwidth_0/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/ddr_bandwidth_1/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/ddr_bandwidth_2/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/ddr_bandwidth_3/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_0/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_1/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_2/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_3/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_4/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_5/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_6/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs service_layer/eth_7/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020100000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/base_logic/gcq_m2r/S00_AXI/S00_AXI_Reg] -force
  assign_bd_address -offset 0x020101000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/base_logic/hw_discovery/s_axi_ctrl_pf0/reg0] -force
  assign_bd_address -offset 0x020100010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/clock_reset/pcie_mgmt_pdi_reset/pcie_mgmt_pdi_reset_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x020200040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/traffic_virt_0/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/traffic_virt_1/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/traffic_virt_2/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/traffic_virt_3/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200080000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs slash/traffic_virt_4/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020100020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/base_logic/uuid_rom/S_AXI/reg0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S01_INI/C1_DDR_LOW0] -force
  assign_bd_address -offset 0xFFA80000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_0] -force
  assign_bd_address -offset 0xFFA90000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_1] -force
  assign_bd_address -offset 0xFFAA0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_2] -force
  assign_bd_address -offset 0xFFAB0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_3] -force
  assign_bd_address -offset 0xFFAC0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_4] -force
  assign_bd_address -offset 0xFFAD0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_5] -force
  assign_bd_address -offset 0xFFAE0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_6] -force
  assign_bd_address -offset 0xFFAF0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_adma_7] -force
  assign_bd_address -offset 0x000100800000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_0] -force
  assign_bd_address -offset 0x000100D10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_cti] -force
  assign_bd_address -offset 0x000100D00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_dbg] -force
  assign_bd_address -offset 0x000100D30000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_etm] -force
  assign_bd_address -offset 0x000100D20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a720_pmu] -force
  assign_bd_address -offset 0x000100D50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_cti] -force
  assign_bd_address -offset 0x000100D40000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_dbg] -force
  assign_bd_address -offset 0x000100D70000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_etm] -force
  assign_bd_address -offset 0x000100D60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_a721_pmu] -force
  assign_bd_address -offset 0x000100CA0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_cti] -force
  assign_bd_address -offset 0x000100C60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_ela] -force
  assign_bd_address -offset 0x000100C30000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_etf] -force
  assign_bd_address -offset 0x000100C20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_apu_fun] -force
  assign_bd_address -offset 0x000100F80000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_atm] -force
  assign_bd_address -offset 0x000100FA0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_cti2a] -force
  assign_bd_address -offset 0x000100FD0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_cti2d] -force
  assign_bd_address -offset 0x000100F40000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2a] -force
  assign_bd_address -offset 0x000100F50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2b] -force
  assign_bd_address -offset 0x000100F60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2c] -force
  assign_bd_address -offset 0x000100F70000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_ela2d] -force
  assign_bd_address -offset 0x000100F20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_fun] -force
  assign_bd_address -offset 0x000100F00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_cpm_rom] -force
  assign_bd_address -offset 0x000100B80000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_atm] -force
  assign_bd_address -offset 0x000100BB0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_cti1b] -force
  assign_bd_address -offset 0x000100BC0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_cti1c] -force
  assign_bd_address -offset 0x000100BD0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_cti1d] -force
  assign_bd_address -offset 0x000100B70000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_fpd_stm] -force
  assign_bd_address -offset 0x000100980000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_lpd_atm] -force
  assign_bd_address -offset 0x0001009D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_lpd_cti] -force
  assign_bd_address -offset 0x0001008D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_pmc_cti] -force
  assign_bd_address -offset 0x000100A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_r50_cti] -force
  assign_bd_address -offset 0x000100A50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_coresight_r51_cti] -force
  assign_bd_address -offset 0xFC000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_cpm] -force
  assign_bd_address -offset 0xFF5E0000 -range 0x00300000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_crl_0] -force
  assign_bd_address -offset 0x000101260000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_crp_0] -force
  assign_bd_address -offset 0xFF020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_i2c_0] -force
  assign_bd_address -offset 0xFF030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_i2c_1] -force
  assign_bd_address -offset 0xFF360000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_3] -force
  assign_bd_address -offset 0xFF370000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_4] -force
  assign_bd_address -offset 0xFF380000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_5] -force
  assign_bd_address -offset 0xFF3A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_6] -force
  assign_bd_address -offset 0xFF320000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_pmc] -force
  assign_bd_address -offset 0xFF390000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_pmc_nobuf] -force
  assign_bd_address -offset 0xFF310000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ipi_psm] -force
  assign_bd_address -offset 0xFF9B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_afi_0] -force
  assign_bd_address -offset 0xFF0A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_iou_secure_slcr_0] -force
  assign_bd_address -offset 0xFF080000 -range 0x00020000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_iou_slcr_0] -force
  assign_bd_address -offset 0xFF410000 -range 0x00100000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_slcr_0] -force
  assign_bd_address -offset 0xFF510000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_slcr_secure_0] -force
  assign_bd_address -offset 0xFF990000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_lpd_xppu_0] -force
  assign_bd_address -offset 0xFF960000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ocm_ctrl] -force
  assign_bd_address -offset 0xFFFC0000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ocm_ram_0] -force
  assign_bd_address -offset 0xFF980000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ocm_xmpu_0] -force
  assign_bd_address -offset 0x0001011E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_aes] -force
  assign_bd_address -offset 0x0001011F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_bbram_ctrl] -force
  assign_bd_address -offset 0x0001012D0000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_cfi_cframe_0] -force
  assign_bd_address -offset 0x0001012B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_cfu_apb_0] -force
  assign_bd_address -offset 0x0001011C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_dma_0] -force
  assign_bd_address -offset 0x0001011D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_dma_1] -force
  assign_bd_address -offset 0x000101250000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_efuse_cache] -force
  assign_bd_address -offset 0x000101240000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_efuse_ctrl] -force
  assign_bd_address -offset 0x000101110000 -range 0x00050000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_global_0] -force
  assign_bd_address -offset 0x000100280000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_iomodule_0] -force
  assign_bd_address -offset 0x000101010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ospi_0] -force
  assign_bd_address -offset 0x000100310000 -range 0x00008000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ppu1_mdm_0] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_qspi_ospi_flash_0] -force
  assign_bd_address -offset 0x000102000000 -range 0x00020000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram] -force
  assign_bd_address -offset 0x000100240000 -range 0x00020000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram_data_cntlr] -force
  assign_bd_address -offset 0x000100200000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram_instr_cntlr] -force
  assign_bd_address -offset 0x000106000000 -range 0x02000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_ram_npi] -force
  assign_bd_address -offset 0x000101200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_rsa] -force
  assign_bd_address -offset 0x0001012A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_rtc_0] -force
  assign_bd_address -offset 0x000101040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_sd_0] -force
  assign_bd_address -offset 0x000101210000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_sha] -force
  assign_bd_address -offset 0x000101220000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_slave_boot] -force
  assign_bd_address -offset 0x000102100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_slave_boot_stream] -force
  assign_bd_address -offset 0x000101270000 -range 0x00030000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_sysmon_0] -force
  assign_bd_address -offset 0x000100083000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_tmr_inject_0] -force
  assign_bd_address -offset 0x000100283000 -range 0x00001000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_tmr_manager_0] -force
  assign_bd_address -offset 0x000101230000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_trng] -force
  assign_bd_address -offset 0x0001012F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_xmpu_0] -force
  assign_bd_address -offset 0x000101310000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_xppu_0] -force
  assign_bd_address -offset 0x000101300000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_pmc_xppu_npi_0] -force
  assign_bd_address -offset 0xFFC90000 -range 0x0000F000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_psm_global_reg] -force
  assign_bd_address -offset 0xFFE90000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_r5_1_atcm_global] -force
  assign_bd_address -offset 0xFFEB0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_r5_1_btcm_global] -force
  assign_bd_address -offset 0xFFE00000 -range 0x00040000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_r5_tcm_ram_global] -force
  assign_bd_address -offset 0xFF9A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_rpu_0] -force
  assign_bd_address -offset 0xFF000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_sbsauart_0] -force
  assign_bd_address -offset 0xFF010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_sbsauart_1] -force
  assign_bd_address -offset 0xFF130000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_scntr_0] -force
  assign_bd_address -offset 0xFF140000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_scntrs_0] -force
  assign_bd_address -offset 0xFF040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_spi_0] -force
  assign_bd_address -offset 0xFF0E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_0] -force
  assign_bd_address -offset 0xFF0F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_1] -force
  assign_bd_address -offset 0xFF100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_2] -force
  assign_bd_address -offset 0xFF110000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_ttc_3] -force
  assign_bd_address -offset 0x020180000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/clk_rst_shell/clk_wizard_service/s_axi_lite/Reg] -force
  assign_bd_address -offset 0x020180010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/clk_rst_shell/clk_wizard_slash/s_axi_lite/Reg] -force
  assign_bd_address -offset 0x020200000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/ddr_bandwidth_0/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/ddr_bandwidth_1/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/ddr_bandwidth_2/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/ddr_bandwidth_3/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_0/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_1/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_2/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_3/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_4/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_5/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_6/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020300070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs service_layer/eth_7/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020100000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/base_logic/gcq_m2r/S00_AXI/S00_AXI_Reg] -force
  assign_bd_address -offset 0x020101000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/base_logic/hw_discovery/s_axi_ctrl_pf0/reg0] -force
  assign_bd_address -offset 0x020100010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/clock_reset/pcie_mgmt_pdi_reset/pcie_mgmt_pdi_reset_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x020200040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/traffic_virt_0/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/traffic_virt_1/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/traffic_virt_2/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/traffic_virt_3/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020200080000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs slash/traffic_virt_4/s_axi_control/Reg] -force
  assign_bd_address -offset 0x020100020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/base_logic/uuid_rom/S_AXI/reg0] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/LPD_AXI_NOC_0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S00_INI/C0_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/LPD_AXI_NOC_0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S00_INI/C0_DDR_LOW0] -force
  assign_bd_address -offset 0x80000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/M_AXI_LPD] [get_bd_addr_segs static_region/aved/base_logic/gcq_m2r/S01_AXI/S01_AXI_Reg] -force
  assign_bd_address -offset 0x058000000000 -range 0x000380000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/PMC_NOC_AXI_0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S00_INI/C0_DDR_CH1_1] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces static_region/aved/cips/PMC_NOC_AXI_0] [get_bd_addr_segs static_region/noc/axi_noc_mc_ddr4_0/S00_INI/C0_DDR_LOW0] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -offset 0x020200000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces slash/traffic_virt_0/Data_m_axi_gmem0] [get_bd_addr_segs service_layer/vpt_0/s_axi/reg0]
  exclude_bd_addr_seg -offset 0x020280000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces slash/traffic_virt_1/Data_m_axi_gmem0] [get_bd_addr_segs service_layer/vpt_1/s_axi/reg0]
  exclude_bd_addr_seg -offset 0x020380000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces slash/traffic_virt_2/Data_m_axi_gmem0] [get_bd_addr_segs service_layer/vpt_2/s_axi/reg0]
  exclude_bd_addr_seg -offset 0x020400000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces slash/traffic_virt_3/Data_m_axi_gmem0] [get_bd_addr_segs service_layer/vpt_3/s_axi/reg0]
  exclude_bd_addr_seg -offset 0x020480000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces slash/traffic_virt_4/Data_m_axi_gmem0] [get_bd_addr_segs service_layer/qpt/s_axi/reg0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_apu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_crf_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_afi_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_afi_2]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_cci_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_gpv_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_maincci_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_slave_xmpu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_slcr_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_slcr_secure_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_smmu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_0] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_smmutcu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_apu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_crf_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_afi_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_afi_2]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_cci_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_gpv_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_maincci_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_slave_xmpu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_slcr_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_slcr_secure_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_smmu_0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces static_region/aved/cips/CPM_PCIE_NOC_1] [get_bd_addr_segs static_region/aved/cips/NOC_PMC_AXI_0/pspmc_0_psv_fpd_smmutcu_0]


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


