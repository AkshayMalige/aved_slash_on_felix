# run_all.tcl -- builds the complete FELIX SLASH DFX design from scratch:
#   static_region + slash (BDC) + service_layer (BDC), DFX-enabled.
# Usage:  vivado -mode batch -source run_all.tcl
# Requires iprepo/ (with hbm_bandwidth) beside this script's parent.
set here [file dirname [info script]]
set iprepo [file normalize [file join $here .. iprepo]]
create_project felix_slash [file join $here proj] -part xcvp1552-vsva3340-2MHP-e-S -force
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild
source [file join $here 00_felix_cips_static_region.tcl]
# 00 (the felix_cips write_bd_tcl export) resets ip_repo_paths to a path
# relative to itself (dfx_build/iprepo, which does not exist) -- restore the
# real iprepo (which has hbm_bandwidth) before building the BDC self-test kernels.
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild
source [file join $here 10_service_layer.tcl]
source [file join $here 20_slash.tcl]
source [file join $here 30_integrate.tcl]
puts "=== FELIX SLASH DFX build complete ==="
