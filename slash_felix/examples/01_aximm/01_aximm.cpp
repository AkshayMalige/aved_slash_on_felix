/**
 * The MIT License (MIT)
 * Copyright (c) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
 * NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include <iostream>
#include <cstring> // for std::memcpy
#include <cstdint>
#include <cstdlib> // for std::atol
#include <chrono>
#include <iomanip>

#include <fcntl.h>
#include <unistd.h>
#include <string>

#include <vrt/device.hpp>
#include <vrt/buffer.hpp>
#include <vrt/kernel.hpp>

// ---- lightweight timing helpers -------------------------------------------
using Clock = std::chrono::high_resolution_clock;
static inline double secondsBetween(Clock::time_point a, Clock::time_point b) {
    return std::chrono::duration<double>(b - a).count();
}
static void printStat(const std::string& label, double seconds, size_t bytes = 0) {
    std::cout << "  " << std::left << std::setw(26) << label << std::right
              << std::fixed << std::setprecision(3) << std::setw(10) << (seconds * 1e3) << " ms";
    if (bytes > 0 && seconds > 0.0) {
        const double bps = static_cast<double>(bytes) / seconds;
        if (bps >= 1e9) {
            std::cout << "   (" << bytes << " B, " << std::setprecision(3) << (bps / 1e9) << " GB/s)";
        } else {
            std::cout << "   (" << bytes << " B, " << std::setprecision(2) << (bps / 1e6) << " MB/s)";
        }
    }
    std::cout << std::endl;
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <BDF> <vrtbin file> [num_elements]" << std::endl;
        return 1;
    }
    std::string bdf = argv[1];
    std::string vrtbinFile = argv[2];
    uint32_t size = 1024;
    if (argc >= 4) {
        long req = std::atol(argv[3]);
        if (req <= 0) { std::cerr << "num_elements must be > 0" << std::endl; return 1; }
        size = static_cast<uint32_t>(req);
    }
    uint32_t m = 3;
    uint32_t n = 2;
    const size_t bufBytes = static_cast<size_t>(size) * sizeof(uint32_t);
    try {
        std::cout << "Elements: " << size << "  (" << bufBytes << " bytes per buffer)" << std::endl;

        // ---- Phase 1: program the device (unpack vbin, DMA partial PDI, reset) ----
        std::cout << "Programming device (loading kernels)..." << std::endl;
        auto tProgStart = Clock::now();
        vrt::Device device(bdf, vrtbinFile);
        auto tProgEnd = Clock::now();
        const double tProgram = secondsBetween(tProgStart, tProgEnd);
        std::cout << "Kernels programmed on " << device.getBdf() << std::endl;

        vrt::Kernel dma(device, "dma_0");
        vrt::Kernel offset(device, "offset_0");

        vrt::Buffer<uint32_t> in_buff(device, size, offset.argMemoryConfig("input"));
        vrt::Buffer<uint32_t> out_buff(device, size, dma.argMemoryConfig("out"));
        for(uint32_t i = 0; i < size; i++) {
            in_buff[i] = i;
        }

        // ---- Phase 2: host -> device DMA (input buffer) ----
        auto tH2dStart = Clock::now();
        in_buff.sync(vrt::SyncType::HOST_TO_DEVICE);
        auto tH2dEnd = Clock::now();
        const double tH2d = secondsBetween(tH2dStart, tH2dEnd);
        std::cout << "DMA host->device finished" << std::endl;

        // ---- Phase 3: kernel execution ----
        offset.setArg(0, size);
        offset.setArg(1, in_buff);
        offset.setArg(2, m);
        offset.setArg(3, n);
        dma.setArg(0, size);
        dma.setArg(1, out_buff);
        auto tExecStart = Clock::now();
        offset.start();
        dma.start();
        offset.wait();
        dma.wait();
        auto tExecEnd = Clock::now();
        const double tExec = secondsBetween(tExecStart, tExecEnd);
        std::cout << "Kernel execution finished" << std::endl;

        // ---- Phase 4: device -> host DMA (output buffer) ----
        auto tD2hStart = Clock::now();
        out_buff.sync(vrt::SyncType::DEVICE_TO_HOST);
        auto tD2hEnd = Clock::now();
        const double tD2h = secondsBetween(tD2hStart, tD2hEnd);
        std::cout << "DMA device->host finished" << std::endl;

        // ---- timing / throughput summary ----
        std::cout << "\n==================== Performance ====================" << std::endl;
        printStat("Device/kernel program", tProgram);
        printStat("DMA host->device", tH2d, bufBytes);
        printStat("Kernel execution", tExec);
        printStat("DMA device->host", tD2h, bufBytes);
        printStat("Total (prog+H2D+exec+D2H)", tProgram + tH2d + tExec + tD2h);
        std::cout << "====================================================\n" << std::endl;

        for(uint32_t i = 0; i < size; i++) {
            if(out_buff[i] != in_buff[i] * m + n) {
                std::cerr << "Test failed (accuracy)" << std::endl;
                std::cerr << "Error: " << i << " " << out_buff[i] << " " << in_buff[i] << std::endl;
                device.cleanup();
                return 2;
            }
        }
        std::cout << "Test passed" << std::endl;
        device.cleanup();
    } catch(const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
