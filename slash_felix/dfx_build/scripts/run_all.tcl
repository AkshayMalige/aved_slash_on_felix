# run_all.tcl -- builds the complete FELIX SLASH DFX *project* from scratch:
#   static_region + slash (BDC) + service_layer (BDC), DFX-enabled, wrapper
#   generated, constraints added, and the DFX configuration + impl run set up.
#   After this the project is ready to synthesize/implement -- no manual GUI
#   steps (no "Create HDL Wrapper", no DFX Wizard).
# Usage:  vivado -mode batch -source scripts/run_all.tcl
# Layout: scripts/ (this + the 00..30 + make_wrapper + build_project),
#         constraints/ (pinout + pblock), ../iprepo (custom IP), ../proj (output).
set here [file dirname [info script]]
set iprepo [file normalize [file join $here .. .. iprepo]]
create_project felix_slash [file join $here .. proj] -part xcvp1552-vsva3340-2MHP-e-S -force
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild
source [file join $here 00_felix_cips_static_region.tcl]
# 00 already registers the real iprepo (../../iprepo from scripts/); re-assert it
# here as a safety net before building the BDC self-test kernels (10/20 need
# hbm_bandwidth from iprepo).
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild
source [file join $here 05_fix_static.tcl]
source [file join $here 10_service_layer.tcl]
source [file join $here 20_slash.tcl]
source [file join $here 30_integrate.tcl]
# generate the top wrapper programmatically + set it as top (no manual step)
source [file join $here make_wrapper.tcl]
# add constraints (pins + DFX floorplan) and set up the DFX configuration + run
source [file join $here build_project.tcl]
puts "=== FELIX SLASH DFX project build complete ==="

# ================================================================
# OPTIONAL DOWNSTREAM STAGES -- BUILD ONLY by default (all commented).
# Uncomment top-down for how far you want to go in ONE command:
#     build the project only .... run as-is (default)
#     + synthesis ............... uncomment STAGE 1
#     + implementation .......... uncomment STAGE 1 and 2
#     + Versal device image ..... uncomment STAGE 1, 2 and 3
# A later stage re-launches impl_1 and pulls in the earlier ones, so you
# can also just uncomment the furthest stage you need. To run these on an
# ALREADY-built project (no rebuild), use scripts/run_impl.tcl instead.
# Adjust -jobs to your core count.
# ================================================================

# ---- STAGE 1: synthesis (static top + slash/service_layer RMs) ----
# launch_runs synth_1 -jobs 8
# wait_on_run synth_1

# ---- STAGE 2: implementation (place & route of config_1) ----
# launch_runs impl_1 -jobs 8
# wait_on_run impl_1

# ---- STAGE 3: Versal device image (.pdi) + abstract shells ----
# launch_runs impl_1 -to_step write_device_image -jobs 8
# wait_on_run impl_1
# open_run impl_1
# set _od [get_property DIRECTORY [get_runs impl_1]]
# write_abstract_shell -cell felix_cips_i/slash         -force [file join $_od abs_shell_slash.dcp]
# write_abstract_shell -cell felix_cips_i/service_layer -force [file join $_od abs_shell_service_layer.dcp]
