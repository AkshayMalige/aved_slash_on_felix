set here [file dirname [info script]]
open_project [file join $here .. proj felix_slash.xpr]

launch_runs synth_1 -jobs 8
wait_on_run synth_1

launch_runs impl_1 -jobs 8
wait_on_run impl_1

launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1
open_run impl_1
set _od [get_property DIRECTORY [get_runs impl_1]]
write_abstract_shell -cell felix_cips_i/slash         -force [file join $_od abs_shell_slash.dcp]
write_abstract_shell -cell felix_cips_i/service_layer -force [file join $_od abs_shell_service_layer.dcp]

puts "RUN_IMPL_DONE"
puts "  device image (.pdi) + abstract shells in: $_od"
