# inject_boot_device_pcie.tcl -- arm the SBI for PCIe slave boot in the base PDI.
#
# ✅ ENABLED IN THE DEFAULT FLOW (run_impl.tcl calls this on every build).
# This is the PERMANENT fix for the host-side DFX crash: it arms the SBI in the
# base PDI so scripts/diag/40_sbi_axi_slave.tcl is no longer needed at runtime.
#
# HISTORY / CORRECTION (2026-07-25): an earlier session DISABLED this, blaming it
# for a `PLM Error Major 0x32B` (XLOADER_ERR_DEFERRED_CDO_PROCESS -- a deferred
# mask_poll mismatch) JTAG-program failure with DONE bit LOW. That was a
# MISATTRIBUTION. The 0x32B was a marginally-seated DDR DIMM: DDRMC0 DQS-gate
# calibration (F0_DQS_GATE_CAL) didn't complete, so the boot CDO's "DDR ready"
# mask_poll never asserted. Proof: (a) A/B PDIs differing ONLY by this directive
# both failed 0x32B identically; (b) the DDR/NoC/PMC config CDOs are byte-identical
# between the working and failing builds; (c) reseating the DIMM fixed 0x32B and
# JTAG programming succeeded. boot_device{pcie} is independent of DDR calibration.
# If JTAG programming ever fails 0x32B again, suspect the DDR DIMM/PDN margin
# (reseat, program cold), NOT this directive.
#
# WHY THIS EXISTS
# --------------
# The felix CIPS was ported from the VEK280 eval board (SD/JTAG boot, no
# host-streamed PDIs). As a result Vivado's write_device_image does NOT emit
# `boot_device { pcie }` in the generated base-image BIF -- whereas the V80 SLASH
# design (a host-programmable PCIe card) does. That one directive tells the PLM to
# bring up the Slave Boot Interface (SBI) in AXI-slave mode.
#
# Without it, on a JTAG-booted card SBI_CTRL (0xF1220004) stays 0x4 (JTAG,
# disabled). The first host DMA of a partial PDI to the slave-boot stream
# (0x102100000) then writes to a disabled interface -> CPM uncorrectable error ->
# PCIe endpoint dies -> the host hard-resets with nothing logged. (The manual
# workaround was scripts/diag/40_sbi_axi_slave.tcl writing SBI_CTRL = 0x9.)
#
# We could not locate a CIPS/PS_PMC_CONFIG property that makes write_device_image
# emit the directive (felix and V80 are boot-identical on every inspectable knob),
# so we inject it into the generated BIF and re-run bootgen. This reproduces V80's
# base PDI exactly and runs on every build, so it survives clean rebuilds.
#
# USAGE
#   set impl_dir <impl_1 dir>
#   source inject_boot_device_pcie.tcl   ;# uses $impl_dir
# or call:  inject_boot_device_pcie <impl_dir>

proc inject_boot_device_pcie {impl_dir} {
    set bif [file join $impl_dir felix_cips_wrapper.bif]
    set pdi [file join $impl_dir felix_cips_wrapper.pdi]

    if {![file exists $bif]} {
        return -code error "inject_boot_device_pcie: BIF not found: $bif (run write_device_image first)"
    }

    # --- read + inject (idempotent) ---
    set fh [open $bif r]; set lines [split [read $fh] "\n"]; close $fh

    # already present? (e.g. a future Vivado that emits it, or a re-run)
    foreach l $lines {
        if {[regexp {boot_device\s*\{\s*pcie\s*\}} $l]} {
            puts "INJECT_BOOT_DEVICE: already present in [file tail $bif] -- nothing to do"
            return 0
        }
    }

    set out {}; set in_master 0; set done 0
    foreach l $lines {
        lappend out $l
        if {[string trim $l] eq "bitstream_master:"} { set in_master 1 }
        # anchor: the master section's own id line ("id = 0x2"); insert right after
        if {$in_master && !$done && [regexp {^(\s*)id\s*=\s*0x2\s*$} $l -> indent]} {
            lappend out "${indent}boot_device { pcie }"
            set done 1
        }
    }
    if {!$done} {
        return -code error "inject_boot_device_pcie: could not find 'bitstream_master: ... id = 0x2' anchor in $bif -- BIF layout changed, inspect it before trusting the base PDI"
    }

    # back up the tool-generated BIF, then write the patched one in place
    file copy -force $bif "${bif}.orig"
    set fh [open $bif w]; puts -nonewline $fh [join $out "\n"]; close $fh
    puts "INJECT_BOOT_DEVICE: added 'boot_device { pcie }' to [file tail $bif] (orig saved as [file tail $bif].orig)"

    # --- regenerate the base PDI from the patched BIF ---
    # bootgen resolves the BIF's relative partition paths against CWD, so run it
    # from impl_dir. Match Vivado's own invocation (-arch versal -w).
    set cwd [pwd]
    cd $impl_dir
    if {[catch {exec bootgen -arch versal -image felix_cips_wrapper.bif -w -o felix_cips_wrapper.pdi} msg]} {
        cd $cwd
        return -code error "inject_boot_device_pcie: bootgen failed: $msg"
    }
    cd $cwd

    # --- verify the directive is really in the regenerated PDI ---
    if {[catch {exec bootgen -arch versal -read $pdi} rd]} {
        puts "INJECT_BOOT_DEVICE: WARNING could not read back $pdi to verify: $rd"
    } elseif {![regexp {boot_device\s*\[pcie\]} $rd]} {
        return -code error "inject_boot_device_pcie: regenerated PDI does NOT report boot_device\[pcie\] -- fix did not take"
    } else {
        puts "INJECT_BOOT_DEVICE: verified boot_device\[pcie\] present in regenerated felix_cips_wrapper.pdi"
    }
    return 0
}

# allow `source`-with-$impl_dir style invocation
if {[info exists impl_dir]} {
    inject_boot_device_pcie $impl_dir
}
