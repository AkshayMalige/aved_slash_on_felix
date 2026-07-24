# Put the SBI (Slave Boot Interface) into AXI-slave mode and enable it, so the
# PMC can accept a PDI streamed from the host over PCIe/QDMA to 0x102100000.
#
# WHY: on this JTAG-booted card SLAVE_BOOT_SBI_CTRL (0xF1220004) reads 0x4 =
# INTERFACE=JTAG, ENABLE=0. Writing the partial PDI to the slave-boot stream in
# that state makes the AXI write fail -> CPM_NCR uncorrectable error -> PCIe
# endpoint dies -> host hangs. XLoader_SbiInit() in the PLM sources sets
# INTERFACE=AXI_SLAVE (0x8) | ENABLE (0x1) = 0x9 for the PCIe PDI source.
#
# RUN THIS LAST -- after the card is programmed AND after the host has rebooted
# and enumerated the card, immediately before running the example.
#
#   xsdb scripts/diag/40_sbi_axi_slave.tcl | tee diag_logs/sbi_fix.txt

puts "==== SBI -> AXI slave mode: [clock format [clock seconds]] ===="
connect
targets -set -nocase -filter {name =~ "*Versal*"}

puts "\n---- BEFORE ----"
puts "SBI_MODE (0xF1220000): [mrd -force -value 0xF1220000 1]"
puts "SBI_CTRL (0xF1220004): [mrd -force -value 0xF1220004 1]   (expect 00000004 = JTAG, disabled)"

puts "\n---- writing SBI_CTRL = 0x9 (INTERFACE=AXI_SLAVE | ENABLE) ----"
mwr -force 0xF1220004 0x9

puts "\n---- AFTER ----"
set after [mrd -force -value 0xF1220004 1]
puts "SBI_CTRL (0xF1220004): $after   (want 00000009)"

puts "\n---- PLM log (for reference) ----"
catch {puts [plm log]}

puts "\n==== done -- now run the example from the shell ===="
exit
