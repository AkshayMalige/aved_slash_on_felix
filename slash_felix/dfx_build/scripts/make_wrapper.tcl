add_files -norecurse [make_wrapper -files [get_files felix_cips.bd] -top]
update_compile_order -fileset sources_1
set_property top felix_cips_wrapper [current_fileset]
puts "MAKE_WRAPPER_DONE: top = [get_property top [current_fileset]]"
