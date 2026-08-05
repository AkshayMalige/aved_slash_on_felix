# Upstream SLASH bugs found during the FELIX port

Two independent defects in the **kernel clock** path. Both are in upstream SLASH code
that the FELIX port did not modify — verified byte-identical before investigation.
Together they mean **`[clock] freqhz=` in `config.cfg` does not control the kernel
clock**, and the API that would tell you so reports success either way.

| | Component | Status | Severity |
|---|---|---|---|
| **Bug 1** | `vrt/src/device.cpp` | fix included below, verified on hardware | High — `freqhz` is silently ignored |
| **Bug 2** | `vrt/vrtd/src/clock.c` | not fixed; workaround = stay ≤ 274 MHz | High — silent failure + misleading readback |

**Environment**

| | |
|---|---|
| Upstream reference | `SLASH` @ `f54ce39` (`v0.1.0-491-gf54ce39`) |
| Board | FELIX FLX-155, AMD Versal Premium `xcvp1552-vsva3340-2MHP-e-S` |
| Tools | Vivado / Vitis 2025.1 |
| Host | Ubuntu, kernel 6.8.0-136-generic, AMD EPYC 9354P |
| Clock reference | `prim_in_hz = 100000000` (from vrtd's own log) |

Neither bug is FELIX-specific: both are in shared `vrt` / `vrtd` code with no
board-conditional paths. A V80 user setting `freqhz` at or below 333.33 MHz hits Bug 1
identically.

---

## Bug 1 — `freqhz` at or below `CLOCK_MAX_FREQ` never programs the clock

**File:** `vrt/src/device.cpp:250-256`
**Constant:** `CLOCK_MAX_FREQ = 333333333` — `vrt/include/vrt/device.hpp:95`

### The code

```cpp
if (vrtdDevice.has_value()) {
    if (clockFreq > CLOCK_MAX_FREQ) {
        utils::Logger::log(utils::LogLevel::WARN, __PRETTY_FUNCTION__,
                   "Clock frequency {} exceeds maximum frequency {}", clockFreq, CLOCK_MAX_FREQ);
        vrtdDevice->setUserClockRate(static_cast<uint32_t>(CLOCK_MAX_FREQ));
    }
}
// no else — clockFreq is never used again
```

There is no `else`. The clock is programmed **only** when the request exceeds the cap.
Any `freqhz` at or below 333333333 — that is, every ordinary value — programs nothing.

### Why it went unnoticed

The only `freqhz` example shipped upstream uses `400000000`, deliberately *above* the
cap. That is the single case in which this branch fires, so the code appears to work.

### Impact

The value travels correctly all the way to the host and is then discarded on the last
instruction:

| Step | Works |
|---|---|
| `config.cfg` `[clock] freqhz=` | yes |
| Linker parses it (`linker/src/parser/config_parser.py:149`) | yes |
| Written to `system_map.xml` as `<ClockFrequency>`, clamped by post-P&R timing | yes |
| Packed into the `.vbin` | yes |
| Host reads it back into `Device::clockFreq` (`device.cpp:306`) | yes |
| Host programs the MMCM with it | **no** |

The consequence is worse than a slow default: **the clock becomes ambient state.**
Whatever rate the clk_wiz was last left at persists across partial reconfiguration and
process exit, and resets only on a power cycle. Two runs of the *same* `.vbin` with the
*same* host binary produce different performance depending on what last touched the
board.

Measured on one 512-bit AXI port against DDR4-2666:

| fabric clock | kernel→DDR write |
|---|---|
| 100 MHz (power-on default) | 6.40 GB/s |
| 250 MHz (`freqhz` honoured) | 13.46 GB/s |

A 2.1× difference, silently determined by history rather than by configuration.

### Reproducer

```bash
# any example whose config.cfg has freqhz <= 333333333
v80-smi debug clockwiz -d <bdf> --set 100000000 --region user
./build/<example> <bdf> <example>.vbin
v80-smi debug clockwiz -d <bdf> --get --region user
# observed: still 100000000 — the vbin's freqhz was never applied
```

### Suggested fix

```cpp
if (vrtdDevice.has_value() && clockFreq > 0) {
    if (clockFreq > CLOCK_MAX_FREQ) {
        utils::Logger::log(utils::LogLevel::WARN, __PRETTY_FUNCTION__,
                   "Clock frequency {} exceeds maximum frequency {}", clockFreq, CLOCK_MAX_FREQ);
        vrtdDevice->setUserClockRate(static_cast<uint32_t>(CLOCK_MAX_FREQ));
    } else {
        vrtdDevice->setUserClockRate(static_cast<uint32_t>(clockFreq));
    }
}
```

The `clockFreq > 0` guard matters: `parseSystemMap()` leaves it zero when
`system_map.xml` carries no `<ClockFrequency>`, and 0 Hz must never be programmed.

Verified on hardware: with this change a vbin declaring `freqhz=250000000` moves the
fabric from a forced 100 MHz to 250 MHz and write bandwidth goes 6.40 → 13.46 GB/s.

---

## Bug 2 — above ~274 MHz the clock driver reports success without programming the divider, and the readback confirms the lie

**File:** `vrt/vrtd/src/clock.c`
**Relevant functions:** `clock_driver_try_set_rate_hz` (~line 914),
`clock_driver_program_mdo_and_reconfig` (line 690), `clock_driver_get_rate_hz` (line 369)

Two defects that conceal one another.

### 2a — silent failure to program the output divider

Requesting any rate above ~274 MHz returns success, logs **zero** lock timeouts, and
leaves the fabric clock unchanged.

vrtd's own log for a **280 MHz** request — note the output-divider register `leaf0` is
identical before and after programming:

```
clock_driver: request_hz=280000000 trying candidate=1/50 m=168 d=5 o=12
              est_hz=280000000 diff_hz=0 predicted_divo=12 predicted_rate_hz=280000000
clock_driver[before_program]: fvco_hz=3600000000 rate_hz=100000000 ... leaf0=0x00001a00
clock_driver[after_program]:  fvco_hz=3360000000 rate_hz=280000000 ... leaf0=0x00001a00
clock_driver: set_rate request_hz=280000000 reported_hz=280000000 m=168 d=5 o=12 candidate=1/50
```

Contrast a **274 MHz** request, where the driver behaves correctly — it rejects two
candidates on lock timeout, accepts a third, and `leaf0` actually changes:

```
candidate=2/50 m=137 d=5 o=10  -> predicted_divo=9  predicted_rate_hz=304444444   (≠ request)
clock_driver: lock timeout request_hz=274000000 candidate=2/50
candidate=3/50 m=274 d=10 o=10
clock_driver: lock timeout request_hz=274000000 candidate=3/50
candidate=4/50 m=411 d=10 o=15 -> predicted_divo=15 predicted_rate_hz=274000000
clock_driver[before_program]: ... leaf0=0x00001b00
clock_driver[after_program]:  fvco_hz=4100000000 rate_hz=274000000 ... leaf0=0x0000bb00
clock_driver: set_rate request_hz=274000000 reported_hz=274000000 m=411 d=10 o=15 candidate=4/50
```

Two observations worth noting for whoever picks this up:

1. The failing candidates all carry `o=12`; the succeeding one `o=15`. Candidate 2 shows
   the driver computing `predicted_divo=9` from `o=10` and a `predicted_rate_hz` that
   does not match the request, yet still attempting it — so the raw-`o` → effective-divider
   encoding (`clock_driver_effective_divo_from_o`) looks worth auditing.
2. Nothing in the success path verifies that the divider register actually changed or
   that the achieved rate is near the requested one.

### 2b — `getUserClockRate()` reports the request, not the hardware

`clock_driver_get_rate_hz()` (line 369) recomputes `f_out = f_VCO / O_effective` from the
registers the driver *believes* it wrote. When 2a occurs the computation yields the
requested value, so:

- `vrt::Device::getFrequency()` returns the requested rate
- `v80-smi debug clockwiz --get` prints the requested rate
- an application has **no way** to discover the clock did not change

This is what makes 2a dangerous rather than merely annoying. Our test harness printed a
confident `Kernel clock (hw): 333.3 MHz` while the fabric ran at 100 MHz and delivered
exactly the 100 MHz bandwidth.

### Measured behaviour

Each target approached from a known 100 MHz baseline, 2 s settle, real clock measured
with a clock-bound II=1 kernel (4 B/element, far below any memory limit, so
`f = elements / second`; two sizes used so fixed start/stop overhead cancels).

| requested | readback claims | **actually measured** | engaged |
|---|---|---|---|
| 100 MHz | 100 | 100.01 | yes |
| 180 MHz | 180 | 180.00 | yes |
| 200 MHz | 200 | 200.00 | yes |
| 220 MHz | 220 | 220.00 | yes |
| 250 MHz | 250 | 250.00 | yes |
| 260 / 265 / 270 MHz | as asked | 260.00 / 265.00 / 270.00 | yes |
| 271 / 272 / 273 / 274 MHz | as asked | 271.02 / 271.98 / 273.00 / 273.99 | yes |
| **275 MHz** | 275 | **100.00** | **no** |
| **280 MHz** | 280 | **100.00** | **no** |
| **300 MHz** | 300 | **100.00** | **no** |
| **320 MHz** | 320 | **100.00** | **no** |
| **333.33 MHz** | 333.33 | **100.00** | **no** |

The boundary is sharp and reproducible: **274 MHz works, 275 MHz does not.** Below it
the clock is finely controllable — arbitrary values such as 180 or 273 MHz land exactly.

> Note for reproduction: an earlier sweep without a settle delay produced a misleading
> one-step-lagged table (each measurement returning the *previous* request). Allow ~2 s
> after `setFrequency()` and re-baseline to 100 MHz between targets, otherwise a value
> that failed to engage is indistinguishable from one still settling.

### Reproducer

```bash
for f in 250000000 274000000 275000000 280000000; do
  v80-smi debug clockwiz -d <bdf> --set 100000000 --region user; sleep 2
  v80-smi debug clockwiz -d <bdf> --set $f --region user; sleep 2
  echo "$f -> $(v80-smi debug clockwiz -d <bdf> --get --region user)"
done
# readback reports every value as applied.
# Timing a known-cycle-count kernel shows 250M and 274M engaged; 275M and 280M did not.
journalctl -u vrtd | grep -E "leaf0|set_rate|lock timeout"
```

### Suggested fixes

1. **Verify before reporting success.** After `clock_driver_program_mdo_and_reconfig()`,
   re-read the leaf divider register and confirm it changed and that the resulting rate
   is within tolerance of the request. Treat "no change" as a failed candidate and fall
   through to the next one, exactly as a lock timeout already does.
2. **Return the achieved rate, or an error.** If no candidate produces a rate within
   `min_err_hz`, `set_rate` should fail rather than return the request. Applications
   currently cannot distinguish success from silent failure.
3. **Audit `clock_driver_effective_divo_from_o()`.** Candidate 2 above derives
   `predicted_divo=9` from `o=10`, giving a `predicted_rate_hz` that plainly disagrees
   with the request, and the candidate is attempted regardless. Candidates whose
   predicted rate does not match the target should be filtered out during generation.

### Workaround

Keep `freqhz` at or below **274 MHz**. 250 MHz is a safe round value. Do not trust
`getFrequency()`; the only reliable verification is timing a kernel with a known cycle
count.

---

## Notes

- Both bugs were found while investigating why DDR bandwidth on FELIX was
  irreproducible between sessions. Bug 1 is the direct cause; Bug 2 obscured every
  attempt to confirm the fix.
- Bug 1's fix is applied locally and verified. Bug 2 is unfixed — the workaround is
  sufficient for FELIX because the platform's DDR saturates at ~250 MHz, but it will
  bite any compute-bound kernel wanting a higher clock.
- `vrt/src/device.cpp` and `vrt/vrtd/src/clock.c` were both confirmed byte-identical to
  upstream before this investigation, so neither defect originates in the FELIX port.
