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
# Only launch if not already complete -- launching a finished run errors in batch
# ("needs to be reset before launching"). This makes the script re-runnable after
# a partial reset (e.g. reset_run impl_1 alone).
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
} else {
    puts "STAGE 1: synth_1 already complete -- reusing"
}

# ---- STAGE 2: implementation (place & route of config_1) ----
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    launch_runs impl_1 -jobs 8
    wait_on_run impl_1
} else {
    puts "STAGE 2: impl_1 already complete -- reusing"
}

# ---- STAGE 3: Versal device image (.pdi) + abstract shells ----
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1
open_run impl_1
set _od [get_property DIRECTORY [get_runs impl_1]]

# --- arm the SBI for PCIe slave boot in the base PDI (host-side DFX) ---
# write_device_image does NOT emit `boot_device { pcie }` for the felix CIPS
# (ported from VEK280), so without this the host-streamed-PDI path leaves the SBI
# in JTAG mode and the first DFX write crashes the machine. This injects the
# directive and regenerates felix_cips_wrapper.pdi, arming it permanently so the
# runtime workaround (scripts/diag/40_sbi_axi_slave.tcl) is not needed.
# NOTE: an earlier note blamed this for a `PLM 0x32B` JTAG-program failure -- that
# was a MISATTRIBUTION; the real cause was a marginally-seated DDR DIMM (DQS-gate
# calibration). Reseating the DIMM fixed 0x32B; boot_device{pcie} is independent.
source [file join $here inject_boot_device_pcie.tcl]
inject_boot_device_pcie $_od


# --- abstract shells (linker RM place-context; abs_shell_slash.dcp is the file
#     the v80++ slash link path consumes as resources/abstract_shell/) ---
write_abstract_shell -cell felix_cips_i/slash         -force [file join $_od abs_shell_slash.dcp]
write_abstract_shell -cell felix_cips_i/service_layer -force [file join $_od abs_shell_service_layer.dcp]

# --- hardware platform XSA (firmware / install use; needs the full routed
#     design incl. bitstream). Deferred phase, but generated here so it comes
#     out of the same impl as the abstract shells. ---
write_hw_platform -fixed -include_bit -force [file join $_od felix_slash.xsa]

# --- routed static checkpoint with the RP cells black-boxed (deploy artifact
#     used to assemble the full base platform PDI). Do this LAST: it mutates the
#     in-memory design, so it must run after the abstract-shell / XSA exports. ---
update_design -black_box -cell felix_cips_i/slash
update_design -black_box -cell felix_cips_i/service_layer
write_checkpoint -force [file join $_od felix_cips_wrapper_routed_bb.dcp]

puts "RUN_IMPL_DONE"
puts "  device image (.pdi), abstract shells, XSA, routed_bb.dcp in: $_od"
