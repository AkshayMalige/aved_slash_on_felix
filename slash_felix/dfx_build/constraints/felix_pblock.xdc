
create_pblock pblock_slash
add_cells_to_pblock [get_pblocks pblock_slash] [get_cells -quiet [list felix_cips_i/slash]]
resize_pblock [get_pblocks pblock_slash] -add {CLOCKREGION_X0Y6:CLOCKREGION_X9Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_slash]

create_pblock pblock_serviclayer
add_cells_to_pblock [get_pblocks pblock_serviclayer] [get_cells -quiet [list felix_cips_i/service_layer]]
resize_pblock [get_pblocks pblock_serviclayer] -add {CLOCKREGION_X3Y1:CLOCKREGION_X9Y4}
set_property SNAPPING_MODE ON [get_pblocks pblock_serviclayer]
