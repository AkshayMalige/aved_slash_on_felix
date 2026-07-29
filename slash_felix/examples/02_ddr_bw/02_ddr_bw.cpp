/**
 * The MIT License (MIT)
 * Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
 *
 * 02_ddr_bw -- measure sustained DDR read/write bandwidth from the kernel side,
 * isolated from PCIe. Four 512-bit mem_bw kernels each stream their own DDR port
 * (DDR0..DDR3) into the single DDR4 channel. Only the on-card kernel execution is
 * timed (the host->card fill is done once, up front, and is NOT part of the number).
 *
 * Usage: 02_ddr_bw <BDF> <vbin> [words_per_port] [iters]
 *   words_per_port : 512-bit words (64 B each) per DDR port. Default 1048576 (=64 MB).
 *   iters          : repetitions; the best (fastest) run is reported. Default 5.
 */
#include <iostream>
#include <vector>
#include <memory>
#include <utility>
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
        std::cerr << "Usage: " << argv[0] << " <BDF> <vbin> [words_per_port] [iters]\n"
                  << "  words_per_port : 512-bit words per DDR port (default 1048576 = 64 MB)\n"
                  << "  iters          : repetitions, best time kept (default 5)\n";
        return 1;
    }
    const std::string bdf = argv[1];
    const std::string vbin = argv[2];
    // Default 16 MB/port (262144 x 512-bit words). Kept modest because vrtd currently
    // exposes only a small (~128 MB) device buffer pool; larger per-port sizes x NP
    // ports can exhaust it and (until vrt null-checks getPhysAddr) segfault.
    const uint32_t words = (argc >= 4) ? static_cast<uint32_t>(std::strtoul(argv[3], nullptr, 0)) : 262144u;
    const int iters = (argc >= 5) ? std::atoi(argv[4]) : 5;
    if (words == 0) { std::cerr << "words_per_port must be > 0\n"; return 1; }

    const int NP = 2;                         // 2 WIRED DDR ports (DDR0, DDR1); DDR2/3 unmapped on FELIX
    const size_t U32_PER_WORD = 16;           // 512 bits / 32
    const size_t bytesPerPort = static_cast<size_t>(words) * 64;
    const size_t totalBytes = bytesPerPort * NP;

    try {
        std::cout << "DDR bandwidth test: " << NP << " ports x " << words << " words = "
                  << (bytesPerPort >> 20) << " MB/port (" << (totalBytes >> 20)
                  << " MB total), iters=" << iters << "\n";
        std::cout << "Programming device..." << std::endl;
        vrt::Device device(bdf, vbin);
        std::cout << "Programmed on " << device.getBdf() << std::endl;

        std::vector<std::unique_ptr<vrt::Kernel>> k;
        for (int i = 0; i < NP; i++)
            k.push_back(std::make_unique<vrt::Kernel>(device, "mem_bw_" + std::to_string(i)));

        std::vector<std::unique_ptr<vrt::Buffer<uint32_t>>> buf;
        for (int i = 0; i < NP; i++)
            buf.push_back(std::make_unique<vrt::Buffer<uint32_t>>(
                device, static_cast<size_t>(words) * U32_PER_WORD, k[i]->argMemoryConfig("gmem0")));

        // Fill + push to card once. NOT part of the DDR measurement.
        for (int i = 0; i < NP; i++) {
            auto& b = *buf[i];
            for (size_t j = 0; j < static_cast<size_t>(words) * U32_PER_WORD; j++) b[j] = static_cast<uint32_t>(j);
            b.sync(vrt::SyncType::HOST_TO_DEVICE);
        }

        // Runs all NP kernels concurrently in the given mode, returns {best GB/s, best ms}.
        auto run = [&](uint32_t mode) -> std::pair<double, double> {
            double bestGbps = 0.0, bestMs = 0.0;
            for (int it = 0; it < iters; ++it) {
                for (int i = 0; i < NP; i++) {
                    k[i]->setArg(0, mode);
                    k[i]->setArg(1, words);
                    k[i]->setArg(2, *buf[i]);
                }
                auto t0 = Clock::now();
                for (int i = 0; i < NP; i++) k[i]->start();
                for (int i = 0; i < NP; i++) k[i]->wait();
                auto t1 = Clock::now();
                const double s = secondsBetween(t0, t1);
                const double gbps = static_cast<double>(totalBytes) / s / 1e9;
                if (gbps > bestGbps) { bestGbps = gbps; bestMs = s * 1e3; }
            }
            return {bestGbps, bestMs};
        };

        const auto rd = run(0);
        const auto wr = run(1);

        std::cout << "\n================ DDR bandwidth (kernel-time only) ================\n";
        std::cout << std::fixed;
        std::cout << "  Read   (" << NP << " ports): " << std::setprecision(2) << std::setw(7) << rd.first
                  << " GB/s   (" << std::setprecision(3) << rd.second << " ms)\n";
        std::cout << "  Write  (" << NP << " ports): " << std::setprecision(2) << std::setw(7) << wr.first
                  << " GB/s   (" << std::setprecision(3) << wr.second << " ms)\n";
        std::cout << "==================================================================\n";
        std::cout << "  DDR4-2666 single-channel theoretical peak ~21.3 GB/s (~15-18 realistic).\n";
        std::cout << "  If both numbers are ~1-4 GB/s, the static-region NoC QoS\n";
        std::cout << "  (read_bw/write_bw {250}) is throttling -> raise it and rebuild the base PDI.\n\n";

        device.cleanup();
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
