/**
 * The MIT License (MIT)
 * Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
 *
 * 03_qdma_bw -- measure host<->card PCIe/QDMA DMA throughput. A buffer is
 * allocated in card DDR; the host times buffer.sync() in each direction over a
 * sweep of transfer sizes and reports the best GB/s per direction.
 *
 * NOTE: because VRT buffers live in card DDR, H2D/D2H are bounded by
 * min(PCIe Gen5x8 ~28 GB/s, DDR ~21 GB/s) -> expect to approach the DDR ceiling,
 * not the raw PCIe peak. That convergence is itself the useful result.
 *
 * Usage: 03_qdma_bw <BDF> <vbin> [size_mb] [iters]
 *   size_mb : if given, test only this size; else sweep 1/4/16/64 MB.
 *   iters   : repetitions per size, best kept. Default 20.
 */
#include <iostream>
#include <vector>
#include <cstdint>
#include <cstdlib>
#include <chrono>
#include <iomanip>
#include <string>

#include <vrt/device.hpp>
#include <vrt/buffer.hpp>
#include <vrt/kernel.hpp>

using Clock = std::chrono::high_resolution_clock;
static inline double secondsBetween(Clock::time_point a, Clock::time_point b) {
    return std::chrono::duration<double>(b - a).count();
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <BDF> <vbin> [size_mb] [iters]\n"
                  << "  size_mb : test only this size; else sweep 1/4/16/64 MB\n"
                  << "  iters   : repetitions per size, best kept (default 20)\n";
        return 1;
    }
    const std::string bdf = argv[1];
    const std::string vbin = argv[2];
    std::vector<size_t> sizesMB;
    if (argc >= 4) sizesMB = { static_cast<size_t>(std::strtoul(argv[3], nullptr, 0)) };
    else sizesMB = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 };
    const int iters = (argc >= 5) ? std::atoi(argv[4]) : 20;

    try {
        std::cout << "QDMA host<->device bandwidth\n";
        std::cout << "Programming device..." << std::endl;
        vrt::Device device(bdf, vbin);
        vrt::Kernel k(device, "mem_bw_0");
        std::cout << "Programmed on " << device.getBdf() << "\n\n";

        std::cout << "    Size        H2D (host->card)      D2H (card->host)\n";
        std::cout << "   ------      ------------------    ------------------\n";
        std::cout << std::fixed;

        for (size_t mb : sizesMB) {
            try {
                const size_t bytes = mb << 20;
                const size_t n = bytes / sizeof(uint32_t);
                vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
                for (size_t j = 0; j < n; j++) b[j] = static_cast<uint32_t>(j);

                double bestH = 0.0;
                for (int it = 0; it < iters; it++) {
                    auto t0 = Clock::now();
                    b.sync(vrt::SyncType::HOST_TO_DEVICE);
                    auto t1 = Clock::now();
                    const double g = static_cast<double>(bytes) / secondsBetween(t0, t1) / 1e9;
                    if (g > bestH) bestH = g;
                }
                double bestD = 0.0;
                for (int it = 0; it < iters; it++) {
                    auto t0 = Clock::now();
                    b.sync(vrt::SyncType::DEVICE_TO_HOST);
                    auto t1 = Clock::now();
                    const double g = static_cast<double>(bytes) / secondsBetween(t0, t1) / 1e9;
                    if (g > bestD) bestD = g;
                }
                std::cout << "   " << std::setw(4) << mb << " MB      "
                          << std::setprecision(2) << std::setw(7) << bestH << " GB/s           "
                          << std::setw(7) << bestD << " GB/s\n";
            } catch (const std::exception& e) {
                // A scan must not abort on one failing size -- report it and keep going.
                std::cout << "   " << std::setw(4) << mb << " MB        FAILED: " << e.what() << "\n";
            }
        }

        std::cout << "\n  Host<->card QDMA bandwidth vs transfer size. Buffers live in card DDR,\n"
                  << "  so it is bounded by min(PCIe link, DDR ~21 GB/s). This card links at\n"
                  << "  Gen3 x8 (~7 GB/s, downgraded from Gen5) -> that is the practical QDMA ceiling.\n\n";
        device.cleanup();
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
