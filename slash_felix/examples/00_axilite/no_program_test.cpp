/*
 * Diagnostic: exercise the QDMA data path WITHOUT programming the device.
 *
 * Splits the two things that `00_axilite` does at once:
 *   (a) DMA a partial PDI to the PMC boot stream (0x102100000)  <- the fatal step
 *   (b) DMA user data to/from DDR over a QDMA queue pair
 *
 * This test does ONLY (b): vrt::Device is constructed with program=false, so no
 * partial reconfiguration is triggered and nothing is written to the PMC.
 *
 *   - If this PASSES: QDMA/NoC/DDR are healthy and the fault is specific to the
 *     PMC boot-stream write or the partial reconfiguration it kicks off.
 *   - If this CRASHES the host too: the fault is in the QDMA/NoC data path
 *     itself, not in DFX-from-host.
 *
 * Requires the kernel already resident in the fabric (i.e. whatever the base PDI
 * placed in the slash partition) -- it does NOT start any kernel, it only moves
 * data, so it is safe against a base image whose slash region holds the
 * self-test IPs.
 *
 * Build: see CMakeLists.txt target `no_program_test`.
 * Run:   ./build/no_program_test 0000:01:00 axilite_hw.vbin
 */

#include <cstring>
#include <iostream>
#include <vector>

#include <vrt/buffer.hpp>
#include <vrt/device.hpp>
#include <vrt/utils/logger.hpp>

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <BDF> <vrtbin file>\n"
                  << "  BDF is board-level, e.g. 0000:01:00\n";
        return 1;
    }
    try {
        vrt::utils::Logger::setLogLevel(vrt::utils::LogLevel::DEBUG);
        std::cout << "VRT Version: " << vrt::getVersion() << std::endl;

        std::cout << "\n[1] Opening device with program=FALSE "
                     "(no PDI write, no reconfiguration)...\n";
        vrt::Device device(argv[1], argv[2], /*program=*/false);
        std::cout << "    device opened OK -- the PMC boot stream was never touched.\n";

        constexpr uint32_t kSize = 1024;
        std::cout << "\n[2] Allocating a " << kSize * sizeof(float)
                  << "-byte DDR buffer...\n";
        vrt::Buffer<float> buf(device, kSize, vrt::MemoryRangeType::DDR);
        std::cout << "    allocated.\n";

        std::vector<float> golden(kSize);
        for (uint32_t i = 0; i < kSize; i++) {
            golden[i] = static_cast<float>(i) * 1.5f;
            buf[i] = golden[i];
        }

        std::cout << "\n[3] HOST_TO_DEVICE DMA (QDMA -> NoC -> DDR)...\n";
        buf.sync(vrt::SyncType::HOST_TO_DEVICE);
        std::cout << "    write DMA completed.\n";

        std::memset(buf.get(), 0, kSize * sizeof(float));

        std::cout << "\n[4] DEVICE_TO_HOST DMA (DDR -> NoC -> QDMA)...\n";
        buf.sync(vrt::SyncType::DEVICE_TO_HOST);
        std::cout << "    read DMA completed.\n";

        std::cout << "\n[5] Verifying round-trip...\n";
        uint32_t bad = 0;
        for (uint32_t i = 0; i < kSize; i++) {
            if (std::memcmp(&buf[i], &golden[i], sizeof(float)) != 0) bad++;
        }
        if (bad) {
            std::cout << "    MISMATCHES: " << bad << "/" << kSize
                      << " -- DMA works but DDR data is wrong.\n";
        } else {
            std::cout << "    all " << kSize << " values match.\n";
        }

        device.cleanup();
        std::cout << "\nRESULT: QDMA data path is HEALTHY. The fault is specific to the\n"
                     "        PMC boot-stream write / partial reconfiguration.\n";
        return bad ? 2 : 0;

    } catch (const std::exception& e) {
        std::cerr << "\nException: " << e.what() << std::endl;
        std::cerr << "RESULT: failed before/without crashing the host -- see the message above\n"
                     "        and `journalctl -u vrtd -n 40`.\n";
        return 1;
    }
}
