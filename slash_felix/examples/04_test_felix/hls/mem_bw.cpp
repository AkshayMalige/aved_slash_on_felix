/**
 * The MIT License (MIT)
 * Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
 *
 * mem_bw -- 512-bit DDR bandwidth kernel, modeled EXACTLY on the reference SLASH
 * `perf` kernel (examples/05_perf/hls/perf.cpp). The crucial detail our earlier
 * kernels lacked is **extern "C"** plus the explicit interface-pragma style
 * (offset=slave, bundle=control). Without extern "C" the top function name is
 * C++-mangled, the packaged kernel's interface names don't match what the linker
 * wires, and the m_axi port silently never connects to DDR (kernel runs, data
 * never lands). One 512-bit port at 333 MHz = 21.3 GB/s, saturating the DDR4
 * channel, so a single instance is enough.
 *
 *   mode == 0 : WRITE -- gmem0[i].low32 = i  over `size` 512-bit words.
 *   mode != 0 : READ  -- XOR-accumulate all words, write the accumulator to
 *                        gmem0[0] (sink; defeats DCE + lets the host verify).
 *   size      : number of 512-bit (64-byte) words.
 */
#include <ap_int.h>
#include <stdint.h>

#define DATA_WIDTH 512
typedef ap_uint<DATA_WIDTH> uint512_t;

extern "C" void mem_bw(ap_uint<32> mode, ap_uint<32> size, uint512_t* gmem0) {
#pragma HLS INTERFACE m_axi port=gmem0 offset=slave bundle=gmem0 \
    max_read_burst_length=64 max_write_burst_length=64
#pragma HLS INTERFACE s_axilite port=gmem0  bundle=control
#pragma HLS INTERFACE s_axilite port=mode   bundle=control
#pragma HLS INTERFACE s_axilite port=size   bundle=control
#pragma HLS INTERFACE s_axilite port=return bundle=control

    if (mode == 0) {
    write_loop:
        for (uint32_t i = 0; i < size; i++) {
#pragma HLS PIPELINE II=1
            uint512_t v = 0;
            v.range(31, 0) = i;
            gmem0[i] = v;
        }
    } else {
        uint512_t acc = 0;
    read_loop:
        for (uint32_t i = 0; i < size; i++) {
#pragma HLS PIPELINE II=1
            acc ^= gmem0[i];
        }
        gmem0[0] = acc; // sink
    }
}
