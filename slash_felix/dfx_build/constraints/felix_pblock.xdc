################################################################
# felix_pblock.xdc -- DFX floorplan for the FELIX SLASH port.
#
# Device xcvp1552, measured from the part database:
#   2 SLRs. SLR0 = clock-region rows Y0-Y4, SLR1 = rows Y5-Y8.
#   Fabric exists ONLY in rows Y1-Y7; rows Y0 and Y8 are hard block / NoC rows.
#   219,248 SLICE / 1,753,984 LUT / 7,392 DSP58 / 2,541 RAMB36 / 1,301 URAM288.
#   Per-row SLICE: Y1 30,544 | Y2 31,872 | Y3 31,872 | Y4 18,240 (half height)
#                  Y5 33,024 | Y6 37,632 | Y7 36,064
#
#   Immovable anchors: CPM5 (PCIe/QDMA) @ CR X0Y2, PS9 @ X0Y1 and X0Y5,
#   all four DDRMCs in row Y0 (the BOTTOM of the die), all 134 bonded IOBs and
#   both used GT quads in SLR0, all 13 MMCMs in row Y0.
#
#   NMU512/NSU512 (NoC master/slave units) exist ONLY in the four vertical-NoC
#   clock-region columns X1, X3, X5, X7 -- two per column per row, except row Y4
#   which has one. 52 of each on the device. This is the scarce resource that
#   actually sizes these pblocks, NOT logic.
#
# ---------------------------------------------------------------------------
# 2026-08-06 re-floorplan. What this replaced and why:
#
#   WAS: pblock_slash        = CLOCKREGION_X0Y6:X9Y7   ( 73,696 SLICE, 33.6%)
#        pblock_serviclayer  = CLOCKREGION_X3Y1:X9Y4   ( 84,992 SLICE, 38.8%)
#        row Y5              = nobody                  ( 33,024 SLICE, 15.1%)
#
#   Two defects, both measured from
#   dfx_build/proj/felix_slash.runs/impl_1/route_report_dfx_summary_0.rpt:
#
#   1. The service layer -- pure AXI/NoC plumbing, 2.18% LUT occupancy -- had
#      MORE fabric than the kernel partition. It was sized by NoC masters, not
#      logic: it needed 13 NMU512s (61.90% of the 21 in its pblock), and since
#      NMU512s live only in columns X1/X3/X5/X7 at two per row, reaching 13
#      forced the pblock across 3 columns x 4 rows. Eight of those 13 belonged
#      to sl2noc_0..7, feeding dead V80 DCMAC-era self-test kernels. Those are
#      now gone (see 10_service_layer.tcl), so the requirement is 6, and the
#      pblock fits in 2 columns x 2 rows.
#
#   2. Clock-region row Y5 was given to nobody, to let the static-driven
#      slash_resetn cross the SLR cut after [Route 35-3424] "no SLL nodes
#      available in SLR Cut [0-1]". That surrendered 15.1% of the die to route
#      ONE net -- the routed design used 1 SLL of 15,096 available. Row Y5 is
#      reclaimed here; clock-region COLUMN X0 of SLR1 is left to static instead,
#      which costs 5,264 SLICE (2.4%) rather than 33,024 (15.1%). X0Y5 has no
#      fabric at all and X0Y6/X0Y7 carry no DSP and no URAM, so it is the
#      cheapest corridor available.
#
#      If [Route 35-3424] returns, do NOT go back to donating row Y5. In order:
#        a) Put slash_resetn on a global buffer. Global routing crosses the SLR
#           cut on dedicated resources, not SLLs. clk_wizard_slash's output
#           already spans CLOCKREGION_X0Y1:X9Y7 that way
#           (route_report_dfx_summary_0.rpt:161-169), so it is proven on this
#           device, and the net drives 22,076 loads in the RP so a BUFG is
#           justified on fanout grounds alone. Edit clk_rst_shell in
#           00_felix_cips_static_region.tcl, beside the existing
#           slash_rst_pipe_slr0 (c_shift_ram:12.0).
#        b) V80-style sliver: cede only the bottom SLICE rows of Y5 to static
#           rather than the whole clock-region row. CR Y5 spans SLICE_*Y332 to
#           SLICE_*Y427, so giving up Y332-Y347 costs ~5,500 SLICE instead of
#           33,024. This is exactly the technique upstream V80 uses -- see
#           linker/resources/base/constraints/impl.xdc:24,
#           "SLICE_X244Y574:SLICE_X323Y574".
#
#   Resulting budget (PHASE A), after the BUFG_PS correction below:
#                        SLICE      %      DSP58     NMU512
#     pblock_slash       98,000   44.7%     3,408      22
#     pblock_serviclayer 22,560   10.3%       ~0        8   (6 used)
#     static (leftover)  98,688   45.0%                22   (4 used)
#
#   vs the baseline's slash 73,696 (33.6%) / 2,256 DSP / 16 NMU512 -- so +33%
#   fabric, +51% DSP and +37% NoC masters for kernels.
#
#   PHASE B, only after Phase A is verified on hardware, adds SLR0's right side.
#   Note it is NOT the single rectangle X4Y1:X9Y4 originally planned -- the
#   service layer now occupies X3..X5 of rows Y1-Y2, so Phase B goes around it:
#     resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X6Y1:CLOCKREGION_X9Y2}
#     resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X4Y3:CLOCKREGION_X9Y4}
#   giving 154,672 SLICE (70.5%), ~5,312 DSP58 (71.9%), 32 NMU512. The RP then
#   spans the SLR cut, so kernel logic can cross it -- watch per-kernel SLL usage
#   and timing closure. It also places kernels adjacent to the DDRMCs in row Y0
#   instead of at the far top of the die, which is worth measuring against the
#   8.39 GB/s single-port read ceiling.
#
#   Cell names (felix_cips_i/slash, felix_cips_i/service_layer) are the
#   wrapper-level reconfigurable-partition cells, so this is portable to a fresh
#   build.
################################################################

# ============================================================================
# BUFG_PS RULE -- read before editing any range below.
#
# BUFG_PS sites exist ONLY in clock-region column X1 (plus row Y8, which has no
# fabric).  Measured:
#     X1Y1 = 12 (BUFG_PS_X1Y0..Y11)    X1Y2 = 12 (X1Y12..Y23)
#     X1Y3 = 12 (X1Y24..Y35)           X1Y5 = 12 (X2Y36..Y47)
# and the device has TWO PS9 sites, BOTH used by the CIPS:
#     PS9_X0Y0 @ CR X0Y1     PS9_X0Y1 @ CR X0Y5
# A PS9 driving a BUFG_PS must land in the dedicated site pair, so the static
# CIPS needs column X1 at rows Y1/Y2/Y3 (for PS9_X0Y0) and row Y5 (for
# PS9_X0Y1).  NEITHER PBLOCK MAY TAKE THOSE.
#
# This is not theoretical -- the first attempt at this floorplan used
# pblock_serviclayer = X1Y1:X3Y2 and pblock_slash = X1Y5:X9Y7, and place_design
# died in Phase 1.3:
#     ERROR: [Place 30-861] Unroutable Placement! A PS instance and its load
#     BUFG_PS are not placed in a routable site pair.
#     PS9_inst (PS9.PMCRCLKCLK[3]) is locked to PS9_X0Y0
#     PL_CLK_3_BUFG (BUFG_PS.I) provisionally placed on BUFG_PS_X1Y34
#     ERROR: [Place 30-1960] I/O Clock placer failed
# (X1Y34 is in CR X1Y3 -- the placer had been pushed out of X1Y1/X1Y2 because
# the service layer had taken them.)  The X1Y5 case would have failed the same
# way for the second PS9; the build never got that far.
#
# Everything else the static clocking needs is in row Y0, which no pblock
# covers: BUFGCE (24/CR), BUFGCE_DIV, BUFGCTRL, MMCM (13), XPLL (26).
# BUFG_GT and DPLL are in columns X0 and X9; column X0 is left to static.
# ============================================================================

# ---- kernel partition: SLR1, minus clock-region column X0 (SLR-crossing
#      corridor) and minus X1Y5 (second PS9's BUFG_PS -- see rule above).
#      X1Y6 and X1Y7 ARE included: they contain no BUFG_PS.
create_pblock pblock_slash
add_cells_to_pblock [get_pblocks pblock_slash] [get_cells -quiet [list felix_cips_i/slash]]
resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X2Y5:CLOCKREGION_X9Y5}
resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X1Y6:CLOCKREGION_X9Y7}
# ---- PHASE B (2026-08-06): the right side of SLR0.
#      Phase A was verified on the card first -- 13 passed / 0 failed, 250.0 MHz,
#      DDR write 13.48/13.48 and read 8.39/13.73 GB/s, i.e. identical to the
#      pre-refloorplan baseline. Only after that was this added.
#
#      NOT the single rectangle X4Y1:X9Y4 originally planned: pblock_serviclayer
#      occupies X3..X5 of rows Y1-Y2 (it had to move off column X1 -- BUFG_PS
#      rule above), so Phase B routes around it as two ranges. Neither touches
#      column X1, so both PS9s keep their BUFG_PS sites.
#
#      Resulting slash budget: 154,672 SLICE (70.5%), ~5,312 DSP58 (71.9%),
#      32 NMU512. NMU accounting after this change:
#        static  = X1 rows Y1-Y4 (7) + X3 rows Y3-Y4 (3) = 10   (uses 4)
#        service = X3,X5 rows Y1-Y2                      =  8   (uses 6)
#        slash   = SLR1 (22) + X5 Y3-Y4 (3) + X7 Y1-Y4 (7) = 32
#
#      COST, measured: a bigger RP means a bigger partial bitstream. Phase A
#      already took PDI programming from 1588 ms to 3631 ms; expect ~5-6 s here.
#      Irrelevant if you load a kernel once and run, but it is a real penalty if
#      kernels are swapped often.
#
#      RISK: the RP now spans the SLR cut, so kernel logic can cross it. Watch
#      per-kernel SLL usage and timing closure in report_utilization_*.txt.
#      To fall back to Phase A, delete just these two lines and rerun run_impl.
resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X6Y1:CLOCKREGION_X9Y2}
resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X4Y3:CLOCKREGION_X9Y4}
set_property SNAPPING_MODE ON [get_pblocks pblock_slash]
set_property IS_SOFT FALSE [get_pblocks pblock_slash]

# ---- service layer: two vertical-NoC columns in SLR0, same SLR as the static
#      shell so it never crosses the boundary. X1 and X3 are chosen because they
#      are VNOC columns -- without one of those the pblock would contain zero
#      NMU512s and nothing could be placed. X0 is excluded: it carries PS9 and
#      CPM5 and belongs to static. Rows Y3/Y4 of X1/X3 are left to static, which
#      needs 4 NMU512 of its own for the CIPS<->NoC and DDR paths.
#
#      NoC occupancy here is 6 NMU512 / 6 NSU512 of 8 each = 75% (verified by
#      building this BD standalone). The previous floorplan ran at 13/21 = 62%,
#      so this is tighter. If the NoC compiler cannot place it, widen to
#      CLOCKREGION_X3Y1:X7Y2 (adds VNOC column X7 -> 12 NMU512) and correspondingly
#      shrink Phase B's SLR0 addition.
#      It starts at column X3, NOT X1: column X1 holds every BUFG_PS the static
#      CIPS needs -- see the BUFG_PS RULE above. The old working baseline started
#      at X3 for the same reason, though it did not say so.
create_pblock pblock_serviclayer
add_cells_to_pblock [get_pblocks pblock_serviclayer] [get_cells -quiet [list felix_cips_i/service_layer]]
resize_pblock [get_pblocks pblock_serviclayer] -add {CLOCKREGION_X3Y1:CLOCKREGION_X5Y2}
set_property SNAPPING_MODE ON [get_pblocks pblock_serviclayer]
set_property IS_SOFT FALSE [get_pblocks pblock_serviclayer]

# ---- NoC ID budget
# Upstream V80 pins this explicitly (impl.xdc:68-71: slash 31-48,
# service 49-63). FELIX deliberately does NOT, for now: Vivado's auto-assignment
# is pblock-size proportional, and since this change makes pblock_slash bigger
# and pblock_serviclayer much smaller, auto-assign moves in the direction we
# want without a hand-picked number that could be wrong by a build.
#
# The previous build auto-assigned serviclayer 8-39 and slash 40-63
# (impl_1/runme.log, "[Constraints 18-13216]"). After this change expect
# serviclayer to shrink and slash to grow. CHECK THAT LOG LINE after the build.
# If Phase B's kernel RMs ever run short of IDs -- a linked RM using most of the
# 38 NMU512s plus its NSUs could want ~40 -- pin them then, using the Phase A
# log as the starting point, e.g.:
#   set_property NOC_HIGH_ID_MIN  8 [get_pblocks pblock_serviclayer]
#   set_property NOC_HIGH_ID_MAX 21 [get_pblocks pblock_serviclayer]
#   set_property NOC_HIGH_ID_MIN 22 [get_pblocks pblock_slash]
#   set_property NOC_HIGH_ID_MAX 63 [get_pblocks pblock_slash]
