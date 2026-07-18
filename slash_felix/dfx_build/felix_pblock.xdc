################################################################
# felix_pblock.xdc -- DFX floorplan for the FELIX SLASH port.
# Device xcvp1552: 2 SLRs (SLR0 = rows Y0-Y4, SLR1 = rows Y5-Y8).
#
#   pblock_slash        -> SLR1, X0Y6:X9Y7.
#       Deliberately OFF the SLR boundary: row Y5 is left FREE so the
#       static-driven reset felix_cips_i/slash/slash_resetn (its driver
#       sits at clock region X4Y4 in SLR0) has Laguna/SLL crossing sites
#       into SLR1. Occupying Y5 consumed all crossing sites and caused
#       [Route 35-3424] "no SLL nodes available in SLR Cut [0-1]".
#
#   pblock_serviclayer  -> SLR0, X3Y1:X9Y4.
#       Same SLR as the static shell, so it never crosses the boundary.
#
# Proven: implements + routes clean in teste/dfx_build. Cell names
# (felix_cips_i/slash, felix_cips_i/service_layer) are the wrapper-level
# reconfigurable-partition cells, so this is portable to a fresh build.
################################################################

create_pblock pblock_slash
add_cells_to_pblock [get_pblocks pblock_slash] [get_cells -quiet [list felix_cips_i/slash]]
resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X0Y6:CLOCKREGION_X9Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_slash]

create_pblock pblock_serviclayer
add_cells_to_pblock [get_pblocks pblock_serviclayer] [get_cells -quiet [list felix_cips_i/service_layer]]
resize_pblock [get_pblocks pblock_serviclayer] -add {CLOCKREGION_X3Y1:CLOCKREGION_X9Y4}
set_property SNAPPING_MODE ON [get_pblocks pblock_serviclayer]
