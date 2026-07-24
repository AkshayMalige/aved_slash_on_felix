# Card-side evidence harvest over JTAG. Safe: read-only.
# Run:  xsdb scripts/diag/20_jtag_harvest.tcl | tee diag_logs/<ts>/jtag_harvest.txt
# Run it (a) right after JTAG programming (baseline), and (b) right after a
# crash-reboot BEFORE reprogramming (post-mortem of what the PLM/SBI saw).

puts "==== jtag_harvest: [clock format [clock seconds]] ===="
connect

# --- PLM log (RTCA). This is the single most valuable card-side artifact:
#     shows whether the PLM ever noticed SBI data / started a PDI load / errored.
targets -set -nocase -filter {name =~ "*Versal*"}
puts "\n---- plm log ----"
if {[catch {puts [plm log]} err]} {
    puts "plm log unavailable in this xsdb: $err"
    puts "(fallback: we will read the RTCA log buffer manually -- report this)"
}

# --- SLAVE_BOOT (SBI) register block, local PMC view 0xF1220000.
#     Tells us what mode the SBI is in and whether any stream data arrived.
puts "\n---- SLAVE_BOOT regs @0xF1220000 (SBI_MODE/CTRL/STATUS...) ----"
if {[catch {puts [mrd -force 0xF1220000 32]} err]} { puts "mrd failed: $err" }

# --- PMC_GLOBAL boot status + multiboot
puts "\n---- PMC_GLOBAL @0xF1110000 (16 words) ----"
if {[catch {puts [mrd -force 0xF1110000 16]} err]} { puts "mrd failed: $err" }

# --- CRP reset reason (did the PMC ever reset?)
puts "\n---- CRP RESET_REASON @0xF1260220 ----"
if {[catch {puts [mrd -force 0xF1260220 1]} err]} { puts "mrd failed: $err" }

# --- JTAG-visible device status (DONE, error flags)
puts "\n---- device status ----"
if {[catch {puts [device status jtag_status]} err]} { puts "device status failed: $err" }

puts "\n==== harvest done ===="
exit
