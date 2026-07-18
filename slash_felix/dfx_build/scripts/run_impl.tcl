# run_impl.tcl -- run the downstream flow (synthesis -> implementation -> Versal
# device image) on the ALREADY-BUILT project, WITHOUT rebuilding the block design.
# Use this to iterate on impl after scripts/run_all.tcl has created the project.
#   vivado -mode batch -source scripts/run_impl.tcl
#
# All three stages are ENABLED by default (full flow to device image). Comment
# out the stages you don't want -- e.g. leave only STAGE 1 to synthesize only.
# A later stage pulls in the earlier ones, so STAGE 3 alone also does synth+impl.
# Adjust -jobs to your core count.
set here [file dirname [info script]]
open_project [file join $here .. proj felix_slash.xpr]

# ---- STAGE 1: synthesis (static top + slash/service_layer RMs) ----
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# ---- STAGE 2: implementation (place & route of config_1) ----
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# ---- STAGE 3: Versal device image (.pdi) + abstract shells ----
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1
open_run impl_1
set _od [get_property DIRECTORY [get_runs impl_1]]
write_abstract_shell -cell felix_cips_i/slash         -force [file join $_od abs_shell_slash.dcp]
write_abstract_shell -cell felix_cips_i/service_layer -force [file join $_od abs_shell_service_layer.dcp]

puts "RUN_IMPL_DONE"
puts "  device image (.pdi) + abstract shells in: $_od"
