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
#include <algorithm>
#include <cmath>
#include <cstring> // for std::memcpy
#include <cstdlib> // for std::atol
#include <iomanip>
#include <random>
#include <chrono>
#include <vector>

#include <vrt/utils/logger.hpp>
#include <vrt/device.hpp>
#include <vrt/buffer.hpp>
#include <vrt/kernel.hpp>

// ---- lightweight timing helpers -------------------------------------------
using Clock = std::chrono::high_resolution_clock;
// Seconds (double) between two time points.
static inline double secondsBetween(Clock::time_point a, Clock::time_point b) {
    return std::chrono::duration<double>(b - a).count();
}
// Print one "<label> : <ms> ms [ (<bytes> B, <rate>) ]" line.
static void printStat(const std::string& label, double seconds, size_t bytes = 0) {
    std::cout << "  " << std::left << std::setw(26) << label << std::right
              << std::fixed << std::setprecision(3) << std::setw(10) << (seconds * 1e3) << " ms";
    if (bytes > 0 && seconds > 0.0) {
        const double bps = static_cast<double>(bytes) / seconds;
        // Auto-scale (1 MB = 1e6 B): GB/s at/above 1 GB/s, else MB/s.
        if (bps >= 1e9) {
            std::cout << "   (" << bytes << " B, " << std::setprecision(3) << (bps / 1e9) << " GB/s)";
        } else {
            std::cout << "   (" << bytes << " B, " << std::setprecision(2) << (bps / 1e6) << " MB/s)";
        }
    }
    std::cout << std::endl;
}

int main(int argc, char* argv[]) {
    try {
        if (argc < 3) {
            std::cerr << "Usage: " << argv[0] << " <BDF> <vrtbin file> [num_elements]" << std::endl;
            return 1;
        }
        std::string bdf = argv[1];
        std::string vrtbinFile = argv[2];
        // Optional element count (default 1024). Larger sizes make the DMA transfer
        // rate meaningful; the kernel size arg is runtime, so this is safe.
        uint32_t size = 1024;
        if (argc >= 4) {
            long req = std::atol(argv[3]);
            if (req <= 0) { std::cerr << "num_elements must be > 0" << std::endl; return 1; }
            size = static_cast<uint32_t>(req);
        }
        const size_t bufBytes = static_cast<size_t>(size) * sizeof(float);

        vrt::utils::Logger::setLogLevel(vrt::utils::LogLevel::DEBUG);
        std::cout << "VRT Version: " << vrt::getVersion() << std::endl;
        std::cout << "Elements: " << size << "  (" << bufBytes << " bytes)" << std::endl;

        // ---- Phase 1: program the device (unpack vbin, DMA partial PDI, reset) ----
        std::cout << "Programming device (loading kernels)..." << std::endl;
        auto tProgStart = Clock::now();
        vrt::Device device(bdf, vrtbinFile);
        auto tProgEnd = Clock::now();
        const double tProgram = secondsBetween(tProgStart, tProgEnd);
        std::cout << "Kernels programmed on " << device.getBdf() << std::endl;

        vrt::Kernel accumulate(device, "accumulate_0");
        vrt::Kernel increment(device, "increment_0");
        vrt::Buffer<float> buffer(device, size, increment.argMemoryConfig("in"));
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<> dis(0.0, 1.0);

        float goldenModel = 0;
        std::vector<float> hostInput(size);
        std::cout << "Generating data...\n";
        for(uint32_t i = 0; i < size; i++) {
            buffer[i] = static_cast<float>(dis(gen));
            hostInput[i] = buffer[i];
            goldenModel += buffer[i] + 1;
        }

        // ---- Phase 2: host -> device DMA ----
        auto tH2dStart = Clock::now();
        buffer.sync(vrt::SyncType::HOST_TO_DEVICE);
        auto tH2dEnd = Clock::now();
        const double tH2d = secondsBetween(tH2dStart, tH2dEnd);
        std::cout << "DMA host->device finished" << std::endl;

        if (device.getPlatform() == vrt::Platform::SIMULATION) {
            buffer.sync(vrt::SyncType::DEVICE_TO_HOST);
            uint32_t mismatchCount = 0;
            uint32_t nanCount = 0;
            for (uint32_t i = 0; i < size; i++) {
                if (!std::isfinite(buffer[i])) {
                    nanCount++;
                }
                if (std::memcmp(&buffer[i], &hostInput[i], sizeof(float)) != 0) {
                    mismatchCount++;
                }
            }
            std::cout << "SIM pre-kernel memory roundtrip mismatches: " << mismatchCount
                      << ", NaNs: " << nanCount << std::endl;
            std::memcpy(buffer.get(), hostInput.data(), size * sizeof(float));
            buffer.sync(vrt::SyncType::HOST_TO_DEVICE);
        }

        // ---- Phase 3: kernel execution (dispatch both, wait for both) ----
        increment.setArg(0, size);
        increment.setArg(1, buffer);
        accumulate.setArg(0, size);
        auto tExecStart = Clock::now();
        increment.start();
        accumulate.start();
        increment.wait();
        accumulate.wait();
        auto tExecEnd = Clock::now();
        const double tExec = secondsBetween(tExecStart, tExecEnd);
        std::cout << "Kernel execution finished" << std::endl;

        uint32_t outCtrl = accumulate.read(0x1c);
        uint32_t val = accumulate.read(0x18);
        float floatVal;
        std::memcpy(&floatVal, &val, sizeof(float));
        const float absError = std::fabs(goldenModel - floatVal);
        constexpr float kAbsTolerance = 1e-3f;
        constexpr float kRelTolerance = 1e-6f;
        const float effectiveTolerance =
            std::max(kAbsTolerance, kRelTolerance * std::fabs(goldenModel));

        // ---- timing / throughput summary ----
        // H2D moves the input buffer; the kernel result is read back over AXI-Lite
        // registers (not a bulk DMA), so there is no D2H bulk transfer to rate here.
        std::cout << "\n==================== Performance ====================" << std::endl;
        printStat("Device/kernel program", tProgram);
        printStat("DMA host->device", tH2d, bufBytes);
        printStat("Kernel execution", tExec);
        printStat("Total (prog+H2D+exec)", tProgram + tH2d + tExec);
        std::cout << "====================================================\n" << std::endl;

        if ((outCtrl & 0x1u) == 0u) {
            std::cerr << "Test failed!" << std::endl;
            std::cout << "Output valid bit is not set (out_r_ctrl=0x" << std::hex << outCtrl
                      << ")" << std::dec << std::endl;
            std::cout << std::setprecision(10);
            std::cout << "Expected: " << goldenModel << std::endl;
            std::cout << "Got: " << floatVal << std::endl;
            std::cout << "Raw register value: 0x" << std::hex << val << std::dec << std::endl;
            device.cleanup();
            return 1;
        }
        if(!std::isfinite(floatVal)) {
            std::cerr << "Test failed! (NaN/Inf)" << std::endl;
            std::cout << "out_r_ctrl: 0x" << std::hex << outCtrl << std::dec << std::endl;
            std::cout << std::setprecision(10);
            std::cout << "Expected: " << goldenModel << std::endl;
            std::cout << "Got: " << floatVal << std::endl;
            std::cout << "Raw register value: 0x" << std::hex << val << std::dec << std::endl;
            device.cleanup();
            return 1;
        } else if(absError > effectiveTolerance) {
            std::cerr << "Test failed! (accuracy)" << std::endl;
            std::cout << "out_r_ctrl: 0x" << std::hex << outCtrl << std::dec << std::endl;
            std::cout << std::setprecision(10);
            std::cout << "Expected: " << goldenModel << std::endl;
            std::cout << "Got: " << floatVal << std::endl;
            std::cout << "Absolute error: " << absError
                      << " (effective tolerance " << effectiveTolerance
                      << ", abs " << kAbsTolerance
                      << ", rel " << kRelTolerance << ")"
                      << std::endl;
            device.cleanup();
            return 2;
        } else {
            std::cout << std::setprecision(10);
            std::cout << "Expected: " << goldenModel << std::endl;
            std::cout << "Got: " << floatVal << std::endl;
            std::cout << "Absolute error: " << absError
                      << " (effective tolerance " << effectiveTolerance
                      << ", abs " << kAbsTolerance
                      << ", rel " << kRelTolerance << ")"
                      << std::endl;
            std::cout << "Test passed!" << std::endl;
        }

        device.cleanup();

    } catch (const std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
