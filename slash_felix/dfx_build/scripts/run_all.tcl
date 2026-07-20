set here [file dirname [info script]]
set iprepo [file normalize [file join $here .. .. iprepo]]
create_project felix_slash [file join $here .. proj] -part xcvp1552-vsva3340-2MHP-e-S -force
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild
source [file join $here 00_felix_cips_static_region.tcl]
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild
source [file join $here 05_fix_static.tcl]
source [file join $here 10_service_layer.tcl]
source [file join $here 20_slash.tcl]
source [file join $here 30_integrate.tcl]
source [file join $here make_wrapper.tcl]
source [file join $here build_project.tcl]
puts "=== FELIX SLASH DFX project build complete ==="

