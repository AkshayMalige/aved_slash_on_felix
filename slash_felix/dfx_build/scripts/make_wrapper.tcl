# make_wrapper.tcl -- generate the felix_cips top wrapper programmatically and
# set it as the design top. Mirrors SLASH resources/base/scripts/make_wrapper.tcl.
# Run AFTER the BD is built + DFX-enabled (30_integrate). The wrapper is
# regenerated from the BD every build, so it never has to be created by hand and
# can never drift out of sync with the block design -- do NOT check a wrapper
# HDL file into git.
add_files -norecurse [make_wrapper -files [get_files felix_cips.bd] -top]
update_compile_order -fileset sources_1
set_property top felix_cips_wrapper [current_fileset]
puts "MAKE_WRAPPER_DONE: top = [get_property top [current_fileset]]"
