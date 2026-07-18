# build_project.tcl -- add constraints and set up the DFX configuration + impl
# run for the FELIX SLASH design. Mirrors SLASH resources/base/scripts/
# build_project.tcl. Run AFTER make_wrapper.tcl.
#
# Every value below is captured VERBATIM from the proven teste/dfx_build project
# so a fresh build reproduces it exactly:
#   top            = felix_cips_wrapper            (set in make_wrapper.tcl)
#   PR config      = config_1
#   partitions     = felix_cips_i/slash          : slash_inst_0
#                    felix_cips_i/service_layer  : service_layer_inst_0
#   impl strategy  = Vivado Advanced Implementation Defaults
#   constraints    = felix_slash_pinout.xdc, felix_pblock.xdc
#                    (USED_IN = synthesis implementation -- add_files default)
set here [file dirname [info script]]

# --- constraints: DDR/PCIe pinout + DFX pblock floorplan (order matches teste) ---
add_files -fileset constrs_1 -norecurse [list \
  [file normalize [file join $here .. constraints felix_slash_pinout.xdc]] \
  [file normalize [file join $here .. constraints felix_pblock.xdc]]]

# --- ensure BD output products exist (needed before defining the PR config) ---
generate_target all [get_files felix_cips.bd]

# --- DFX configuration: static + the two reconfigurable partitions ---
create_pr_configuration -name config_1 -partitions [list \
  felix_cips_i/slash:slash_inst_0 \
  felix_cips_i/service_layer:service_layer_inst_0]
set_property PR_CONFIGURATION config_1 [get_runs impl_1]
set_property strategy {Vivado Advanced Implementation Defaults} [get_runs impl_1]

# --- OPTIONAL: launch synth+impl to bitstream (leave commented; run manually or
#     uncomment for a fully-automated build like SLASH). ---
# launch_runs impl_1 -to_step write_device_image -jobs 8
# wait_on_run impl_1

puts "BUILD_PROJECT_DONE: top=[get_property top [current_fileset]] cfg=[get_property PR_CONFIGURATION [get_runs impl_1]] strategy=[get_property strategy [get_runs impl_1]]"
