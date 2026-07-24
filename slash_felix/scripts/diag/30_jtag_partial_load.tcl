# Phase-1 experiment: apply the vbin's partial PDI over JTAG (no PCIe involved).
# Prereq: card already programmed with felix_slash_amc.pdi (base) via Vivado HW
# manager, host does NOT need to be rebooted for this test.
#
#   PASS -> the partial PDI content is good; the fault is in the PCIe->SBI
#           transport (design_writer / QDMA / SBI mode).
#   FAIL -> the fault is in the partial PDI / DFX configuration itself;
#           the error message + plm log tells us which partition died.
#
# Run:  xsdb scripts/diag/30_jtag_partial_load.tcl | tee diag_logs/<ts>/jtag_partial.txt

set partial [file normalize [file join [file dirname [info script]] \
    ../../examples/00_axilite/axilite_hw.vbin.prj/images/top_i_slash_slash_axilite_hw_inst_0_partial.pdi]]
if {![file exists $partial]} { error "partial PDI not found: $partial" }
puts "partial PDI: $partial"

connect
targets -set -nocase -filter {name =~ "*Versal*"}

puts "\n---- plm log BEFORE partial load ----"
catch {puts [plm log]}

puts "\n---- loading partial PDI over JTAG ----"
if {[catch {device partial $partial} err]} {
    puts "PARTIAL LOAD FAILED: $err"
} else {
    puts "PARTIAL LOAD OK"
}

puts "\n---- plm log AFTER partial load ----"
catch {puts [plm log]}

puts "\n---- SLAVE_BOOT regs after ----"
catch {puts [mrd -force 0xF1220000 32]}
exit
