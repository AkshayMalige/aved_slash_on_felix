# gen_slash_base.tcl -- one-shot generator for the FELIX linker resource
#   resources/abstract_shell/slash_base/slash_base.bd
#
# Builds the slash-partition BASE block design (boundary contract for the DFX
# reconfigurable partition) and exports it into the resources tree so the v80++
# linker can `import_files` it at link time. Run standalone:
#
#   vivado -mode batch -source gen_slash_base.tcl
#
# It uses base/iprepo for the custom IP (hbm_bandwidth self-test kernel). The
# baked-in interior is wiped and rebuilt per-kernel by resources/slash.tcl at
# link time -- only the boundary ports are load-bearing.

set here      [file dirname [file normalize [info script]]]
set res       [file join $here resources]
set iprepo    [file join $res base iprepo]
set recipe    [file join $res base scripts slash_base.tcl]
set out_dir   [file join $res abstract_shell slash_base]
set work      [file join $here .gen_slash_base]

file delete -force $work
file mkdir $work

create_project slash_base_gen $work -part xcvp1552-vsva3340-2MHP-e-S -force
set_property ip_repo_paths $iprepo [current_project]
update_ip_catalog -rebuild

# Build + validate the slash_base BD.
source $recipe

# Generate all targets so the exported BD carries its IP/synthesis products.
set bd_file [get_files slash_base.bd]
generate_target all [get_files $bd_file]

# Export: copy the whole bd/slash_base hierarchy (the .bd plus generated
# sources) into resources/abstract_shell/slash_base/.
set bd_src_dir [file dirname [file normalize $bd_file]]
file delete -force $out_dir
file mkdir [file dirname $out_dir]
file copy -force $bd_src_dir $out_dir

puts "GEN_SLASH_BASE_DONE: exported [file join $out_dir slash_base.bd]"
