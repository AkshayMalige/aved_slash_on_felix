/**
 * The MIT License (MIT)
 * Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
 *
 * 04_test_felix -- one comprehensive FELIX platform test & benchmark, driving a
 * single 512-bit `mem_bw` kernel (modeled on the reference `perf` kernel):
 *
 *   [0] Device / PDI program time + platform info (BDF, kernel clock)
 *   [1] QDMA host<->card DATA CORRECTNESS  -- round-trip integrity across sizes
 *   [2] QDMA host<->card BANDWIDTH sweep   -- H2D / D2H, 1 MB .. 512 MB
 *   [3] Kernel<->DDR CORRECTNESS           -- write-pattern + read-accumulate
 *   [4] Kernel<->DDR BANDWIDTH             -- on-card write & read (512-bit port)
 *   [5] Kernel execution latency vs size
 *   [6] SUMMARY                            -- pass/fail ledger + headline numbers
 *
 *   mem_bw(mode, size, gmem0): mode 0 = write gmem0[i].low32=i; mode 1 = read +
 *   XOR-accumulate, write result to gmem0[0]. size = # of 512-bit (64 B) words.
 *
 * Usage: 04_test_felix <BDF> <vbin> [--quick]
 */
#include <iostream>
#include <iomanip>
#include <vector>
#include <string>
#include <cstdint>
#include <cstdlib>
#include <chrono>
#include <stdexcept>

#include <vrt/device.hpp>
#include <vrt/buffer.hpp>
#include <vrt/kernel.hpp>

using Clock = std::chrono::high_resolution_clock;
static inline double secs(Clock::time_point a, Clock::time_point b) {
    return std::chrono::duration<double>(b - a).count();
}
static inline uint32_t pat(size_t idx) {
    return static_cast<uint32_t>(idx * 2654435761u + 1013904223u);
}
static bool waitKernel(vrt::Kernel& k, double timeoutSec = 15.0) {
    const auto t0 = Clock::now();
    while ((k.read(0x00) & 0x2u) == 0u)
        if (secs(t0, Clock::now()) > timeoutSec) return false;
    return true;
}

static const size_t MB             = 1u << 20;
static const size_t U32_PER_WORD   = 16;   // 512 bits / 32
static const size_t BYTES_PER_WORD = 64;   // 512 bits / 8

struct Result { std::string name; bool pass; std::string note; };
static std::vector<Result> g_results;
static void record(const std::string& n, bool p, const std::string& note = "") {
    g_results.push_back({n, p, note});
}
static std::string sizeLabel(size_t bytes) {
    if (bytes >= MB)   return std::to_string(bytes / MB) + " MB";
    if (bytes >= 1024) return std::to_string(bytes / 1024) + " KB";
    return std::to_string(bytes) + " B";
}

int main(int argc, char** argv) {
    if (argc < 3) { std::cerr << "Usage: " << argv[0] << " <BDF> <vbin> [--quick]\n"; return 2; }
    const std::string bdf = argv[1], vbin = argv[2];
    const bool quick = (argc >= 4 && std::string(argv[3]) == "--quick");
    double bestH2D = 0.0, bestD2H = 0.0, ddrRead = 0.0, ddrWrite = 0.0;

    std::cout << std::unitbuf << std::fixed;
    std::cout << "\n========================================================\n";
    std::cout <<   "  04_test_felix -- FELIX platform full test & benchmark" << (quick ? "  [QUICK]" : "") << "\n";
    std::cout <<   "========================================================\n";

    try {
        // [0] Device + platform info
        std::cout << "\n[0] Device program + platform info\n-----------------------------------\n";
        auto t0 = Clock::now();
        vrt::Device device(bdf, vbin);
        auto t1 = Clock::now();
        std::cout << "  BDF                : " << device.getBdf() << "\n";
        std::cout << "  PDI program time   : " << std::setprecision(1) << secs(t0, t1) * 1e3 << " ms\n";
        uint64_t f = 0, fmax = 0;
        try { f = device.getFrequency(); } catch (...) {}
        try { fmax = device.getMaxFrequency(); } catch (...) {}
        if (f)    std::cout << "  Kernel clock       : " << std::setprecision(1) << (f / 1e6)    << " MHz\n";
        if (fmax) std::cout << "  Max clock          : " << std::setprecision(1) << (fmax / 1e6) << " MHz\n";
        auto ta = Clock::now();
        vrt::Kernel k(device, "mem_bw_0");
        auto tb = Clock::now();
        std::cout << "  Kernel attach      : " << std::setprecision(2) << secs(ta, tb) * 1e3 << " ms\n";
        record("device program", true, std::to_string(static_cast<long>(secs(t0, t1) * 1e3)) + " ms");

        // [1] QDMA correctness (round-trip)
        std::cout << "\n[1] QDMA host<->card DATA CORRECTNESS (round-trip)\n--------------------------------------------------\n";
        std::cout << "    fill host -> H2D -> wipe host -> D2H -> compare\n";
        std::vector<size_t> corrBytes = quick
            ? std::vector<size_t>{ 4 * 1024, 64 * 1024, 1 * MB, 16 * MB }
            : std::vector<size_t>{ 4 * 1024, 64 * 1024, 1 * MB, 16 * MB, 64 * MB, 256 * MB };
        for (size_t bytes : corrBytes) {
            const std::string label = sizeLabel(bytes);
            bool ok = false; std::string note;
            try {
                const size_t n = bytes / sizeof(uint32_t);
                vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
                for (size_t j = 0; j < n; j++) b[j] = pat(j);
                b.sync(vrt::SyncType::HOST_TO_DEVICE);
                for (size_t j = 0; j < n; j++) b[j] = 0xDEADBEEFu;
                b.sync(vrt::SyncType::DEVICE_TO_HOST);
                size_t bad = 0, firstBad = 0;
                for (size_t j = 0; j < n; j++) if (b[j] != pat(j)) { if (!bad) firstBad = j; bad++; }
                ok = (bad == 0);
                if (!ok) note = std::to_string(bad) + " mismatch, first word #" + std::to_string(firstBad);
            } catch (const std::exception& e) { note = std::string("EXC: ") + e.what(); }
            std::cout << "    " << std::left << std::setw(8) << label << std::right
                      << "   " << (ok ? "PASS" : ("FAIL  " + note)) << "\n";
            record("qdma-correctness " + label, ok, note);
        }

        // [2] QDMA bandwidth sweep
        std::cout << "\n[2] QDMA host<->card BANDWIDTH (best-of-" << (quick ? 3 : 5) << ")\n--------------------------------------------\n";
        const int bwIters = quick ? 3 : 5;
        std::vector<size_t> sweepMB = quick ? std::vector<size_t>{ 1, 16, 128 }
                                            : std::vector<size_t>{ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 };
        std::cout << "      " << std::setw(6) << "Size" << std::setw(16) << "H2D (host->card)"
                  << std::setw(16) << "D2H (card->host)" << "\n";
        for (size_t mb : sweepMB) {
            try {
                const size_t bytes = mb * MB, n = bytes / sizeof(uint32_t);
                vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
                for (size_t j = 0; j < n; j++) b[j] = pat(j);
                double bH = 0.0, bD = 0.0;
                for (int it = 0; it < bwIters; it++) {
                    auto s0 = Clock::now(); b.sync(vrt::SyncType::HOST_TO_DEVICE); auto s1 = Clock::now();
                    const double g = static_cast<double>(bytes) / secs(s0, s1) / 1e9; if (g > bH) bH = g;
                }
                for (int it = 0; it < bwIters; it++) {
                    auto s0 = Clock::now(); b.sync(vrt::SyncType::DEVICE_TO_HOST); auto s1 = Clock::now();
                    const double g = static_cast<double>(bytes) / secs(s0, s1) / 1e9; if (g > bD) bD = g;
                }
                if (bH > bestH2D) bestH2D = bH; if (bD > bestD2H) bestD2H = bD;
                std::cout << "      " << std::setw(4) << mb << " MB" << std::setprecision(2)
                          << std::setw(11) << bH << " GB/s" << std::setw(11) << bD << " GB/s\n";
            } catch (const std::exception& e) {
                std::cout << "      " << std::setw(4) << mb << " MB   FAILED: " << e.what() << "\n";
                record("qdma-bw " + std::to_string(mb) + "MB", false, e.what());
            }
        }

        // [3] Kernel<->DDR correctness
        std::cout << "\n[3] Kernel<->DDR CORRECTNESS\n----------------------------\n";
        {
            const size_t words = (quick ? 1 : 4) * MB / BYTES_PER_WORD;
            const size_t n = words * U32_PER_WORD;
            // (a) WRITE
            bool okW = false; std::string noteW;
            try {
                vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
                for (size_t j = 0; j < n; j++) b[j] = 0xA5A5A5A5u;
                b.sync(vrt::SyncType::HOST_TO_DEVICE);
                k.setArg(0, static_cast<uint32_t>(0));  // mode = write
                k.setArg(1, static_cast<uint32_t>(words));
                k.setArg(2, b);
                std::cout << "    running write (" << words << " words)..." << std::flush;
                k.start();
                if (!waitKernel(k)) throw std::runtime_error("mem_bw WRITE timeout (no ap_done in 15 s)");
                std::cout << " done\n";
                b.sync(vrt::SyncType::DEVICE_TO_HOST);
                size_t bad = 0, firstBad = 0;
                for (size_t i = 0; i < words; i++) {
                    if (b[i * U32_PER_WORD] != static_cast<uint32_t>(i)) { if (!bad) firstBad = i; bad++; continue; }
                    for (size_t kk = 1; kk < U32_PER_WORD; kk++)
                        if (b[i * U32_PER_WORD + kk] != 0u) { if (!bad) firstBad = i; bad++; break; }
                }
                okW = (bad == 0);
                if (!okW) noteW = std::to_string(bad) + " bad word(s), first #" + std::to_string(firstBad);
            } catch (const std::exception& e) { noteW = std::string("EXC: ") + e.what(); }
            std::cout << "    write-pattern   : " << (okW ? "PASS" : ("FAIL  " + noteW)) << "\n";
            record("kernel-ddr write", okW, noteW);
            // (b) READ (accumulator -> gmem0[0])
            bool okR = false; std::string noteR;
            try {
                vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
                for (size_t j = 0; j < n; j++) b[j] = pat(j);
                uint32_t expect[U32_PER_WORD] = {0};
                for (size_t i = 0; i < words; i++)
                    for (size_t kk = 0; kk < U32_PER_WORD; kk++)
                        expect[kk] ^= pat(i * U32_PER_WORD + kk);
                b.sync(vrt::SyncType::HOST_TO_DEVICE);
                k.setArg(0, static_cast<uint32_t>(1));  // mode = read
                k.setArg(1, static_cast<uint32_t>(words));
                k.setArg(2, b);
                std::cout << "    running read  (" << words << " words)..." << std::flush;
                k.start();
                if (!waitKernel(k)) throw std::runtime_error("mem_bw READ timeout (no ap_done in 15 s)");
                std::cout << " done\n";
                b.sync(vrt::SyncType::DEVICE_TO_HOST);
                size_t bad = 0;
                for (size_t kk = 0; kk < U32_PER_WORD; kk++) if (b[kk] != expect[kk]) bad++;
                okR = (bad == 0);
                if (!okR) noteR = std::to_string(bad) + "/16 accumulator lanes wrong";
            } catch (const std::exception& e) { noteR = std::string("EXC: ") + e.what(); }
            std::cout << "    read-accumulate : " << (okR ? "PASS" : ("FAIL  " + noteR)) << "\n";
            record("kernel-ddr read", okR, noteR);
        }

        // [4] Kernel<->DDR bandwidth (single 512-bit port)
        std::cout << "\n[4] Kernel<->DDR BANDWIDTH (on-card, 512-bit port, PCIe excluded)\n----------------------------------------------------------------\n";
        try {
            const size_t mb = quick ? 32 : 128;
            const size_t words = mb * MB / BYTES_PER_WORD;
            const size_t n = words * U32_PER_WORD;
            const int iters = quick ? 3 : 5;
            const double bytes = static_cast<double>(words) * BYTES_PER_WORD;
            vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
            for (size_t j = 0; j < n; j++) b[j] = pat(j);
            b.sync(vrt::SyncType::HOST_TO_DEVICE);
            std::cout << "    buffer: " << mb << " MB\n    running write..." << std::flush;
            for (int it = 0; it < iters; it++) {
                k.setArg(0, static_cast<uint32_t>(0)); k.setArg(1, static_cast<uint32_t>(words)); k.setArg(2, b);
                auto s0 = Clock::now(); k.start();
                if (!waitKernel(k)) throw std::runtime_error("write timeout");
                auto s1 = Clock::now();
                const double g = bytes / secs(s0, s1) / 1e9; if (g > ddrWrite) ddrWrite = g;
            }
            std::cout << " done\n    running read.... " << std::flush;
            for (int it = 0; it < iters; it++) {
                k.setArg(0, static_cast<uint32_t>(1)); k.setArg(1, static_cast<uint32_t>(words)); k.setArg(2, b);
                auto s0 = Clock::now(); k.start();
                if (!waitKernel(k)) throw std::runtime_error("read timeout");
                auto s1 = Clock::now();
                const double g = bytes / secs(s0, s1) / 1e9; if (g > ddrRead) ddrRead = g;
            }
            std::cout << " done\n";
            std::cout << "    Write : " << std::setprecision(2) << std::setw(7) << ddrWrite << " GB/s\n";
            std::cout << "    Read  : " << std::setprecision(2) << std::setw(7) << ddrRead  << " GB/s\n";
            record("ddr-bw write", ddrWrite > 0.0, std::to_string(ddrWrite) + " GB/s");
            record("ddr-bw read",  ddrRead  > 0.0, std::to_string(ddrRead)  + " GB/s");
        } catch (const std::exception& e) { std::cout << " FAILED: " << e.what() << "\n"; record("ddr-bw", false, e.what()); }

        // [5] Kernel latency vs size (read)
        std::cout << "\n[5] Kernel execution latency vs size (read)\n-------------------------------------------\n";
        std::cout << "      " << std::setw(6) << "Size" << std::setw(12) << "time" << std::setw(14) << "BW\n";
        std::vector<size_t> latMB = quick ? std::vector<size_t>{ 1, 16 } : std::vector<size_t>{ 1, 4, 16, 64, 256 };
        for (size_t mb : latMB) {
            try {
                const size_t words = mb * MB / BYTES_PER_WORD, n = words * U32_PER_WORD;
                vrt::Buffer<uint32_t> b(device, n, k.argMemoryConfig("gmem0"));
                for (size_t j = 0; j < n; j++) b[j] = pat(j);
                b.sync(vrt::SyncType::HOST_TO_DEVICE);
                k.setArg(0, static_cast<uint32_t>(1)); k.setArg(1, static_cast<uint32_t>(words)); k.setArg(2, b);
                double bestS = 1e30;
                for (int it = 0; it < (quick ? 2 : 3); it++) {
                    auto s0 = Clock::now(); k.start();
                    if (!waitKernel(k)) throw std::runtime_error("timeout at " + std::to_string(mb) + " MB");
                    auto s1 = Clock::now();
                    if (secs(s0, s1) < bestS) bestS = secs(s0, s1);
                }
                const double g = static_cast<double>(words * BYTES_PER_WORD) / bestS / 1e9;
                std::cout << "      " << std::setw(4) << mb << " MB" << std::setprecision(3)
                          << std::setw(9) << bestS * 1e3 << " ms" << std::setprecision(2) << std::setw(9) << g << " GB/s\n";
            } catch (const std::exception& e) {
                std::cout << "      " << std::setw(4) << mb << " MB   FAILED: " << e.what() << "\n";
            }
        }

        // [6] Summary
        std::cout << "\n========================== SUMMARY ==========================\n";
        size_t passN = 0, failN = 0;
        for (const auto& r : g_results) (r.pass ? passN : failN)++;
        std::cout << "  Correctness / checks : " << passN << " passed, " << failN << " failed\n";
        if (failN) {
            std::cout << "  FAILURES:\n";
            for (const auto& r : g_results) if (!r.pass) std::cout << "    - " << r.name << (r.note.empty() ? "" : ("  (" + r.note + ")")) << "\n";
        }
        std::cout << std::setprecision(2);
        std::cout << "  QDMA host->card peak : " << bestH2D  << " GB/s\n";
        std::cout << "  QDMA card->host peak : " << bestD2H  << " GB/s\n";
        std::cout << "  DDR kernel write     : " << ddrWrite << " GB/s\n";
        std::cout << "  DDR kernel read      : " << ddrRead  << " GB/s\n";
        std::cout << "  ---------------------------------------------------------\n";
        std::cout << "  Reference: DDR4-2666 single channel ~21.3 GB/s peak.\n";
        std::cout << "  VERDICT: " << (failN == 0 ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED (see above)") << "\n";
        std::cout << "=============================================================\n\n";
        device.cleanup();
        return failN == 0 ? 0 : 1;
    } catch (const std::exception& e) {
        std::cerr << "\nFATAL: " << e.what() << std::endl;
        return 1;
    }
}
