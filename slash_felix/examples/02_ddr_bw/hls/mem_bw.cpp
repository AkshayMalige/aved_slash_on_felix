/**
 * The MIT License (MIT)
 * Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
 *
 * Wide (512-bit) DDR memory-bandwidth kernel.
 *   mode == 0 : READ  -- stream the whole buffer, XOR-accumulate, write one word
 *                        back at the end (a "sink" so the read loop is not
 *                        optimised away) -> pure read traffic.
 *   mode != 0 : WRITE -- stream a pattern over the whole buffer -> pure write traffic.
 *   size      : number of 512-bit words (each = 64 bytes) to move.
 *
 * One 512-bit m_axi port per instance; the linker maps it to a DDR bank (sp=).
 * Instantiate 4 of these on DDR0..DDR3 to saturate the single DDR4 channel.
 */
#include <ap_int.h>

void mem_bw(ap_uint<32> mode, ap_uint<32> size, ap_uint<512>* gmem0) {
#pragma HLS interface mode=s_axilite port=mode
#pragma HLS interface mode=s_axilite port=size
#pragma HLS interface m_axi bundle=gmem0 port=gmem0 \
    num_read_outstanding=32 num_write_outstanding=32 \
    max_read_burst_length=64 max_write_burst_length=64
#pragma HLS interface mode=s_axilite port=return

    if (mode == 0) {
        ap_uint<512> acc = 0;
    read_loop:
        for (ap_uint<32> i = 0; i < size; i++) {
#pragma HLS pipeline II=1
            acc ^= gmem0[i];
        }
        gmem0[0] = acc; // sink: keeps the read loop from being optimised away
    } else {
    write_loop:
        for (ap_uint<32> i = 0; i < size; i++) {
#pragma HLS pipeline II=1
            ap_uint<512> v = 0;
            v(31, 0) = i;
            gmem0[i] = v;
        }
    }
}
