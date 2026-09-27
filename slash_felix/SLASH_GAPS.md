# SLASH capability gaps — found while porting F110 to FELIX

Companion to `BUGS_UPSTREAM.md`. That file records *defects*; this one records
*limitations and missing features* hit while porting a real third-party design
(ATLAS Phase-II Event Filter F110_s: 12 kernels, 15 CUs, 16 AXI-Stream links,
4 m_axi ports) into SLASH as example `05_f110`.

**Status 2026-08-07: F110 RUNS END-TO-END ON FELIX.** 32 CUs, 34 AXI-Stream links,
200 MHz, 0.36 ms. Both chains report the correct cluster count. **G2 was the cause** —
see §3a, and read the pragma warning in §3b before touching any FIFO.

---

## 1. Confirmed limitations (from code, before any build)

| # | Limitation | Evidence | Impact on F110 | Workaround |
|---|---|---|---|---|
| **G1** | **The linker consumes IP-XACT `component.xml` only. No `.xo` support.** Every SLASH example uses `flow_target=vivado` + `package.output.format=ip_catalog`; there is not one reference to `.xo` in `linker/src`. | `linker/src/parser/component_parser.py`; all `examples/*/hls/*.cfg` | All 12 pre-built F110 `.xo` are unusable. Every kernel must be re-synthesized under a different flow target — and that changes interface inference (see §2). | Re-synthesize. Mechanical but touches every kernel. **This is the single largest cost of the port.** |
| **G2** | **`stream_connect=` has no FIFO depth, no width conversion, no clock crossing, no broadcast** — it emits a bare `connect_bd_intf_net`. Real, but **NOT** proven to be F110's deadlock cause — adding FIFOs to all four cycle edges did not fix it (see §3a). | `linker/resources/slash.tcl:531-534`; `stream_ctx.py:81-86`; hardware run, see §3a | F110 has two feedback loops running on bare wires where Vitis had `:16`. A latent hazard, but disproven as the cause of the current hang. | Insert passthrough FIFO kernels on the cycle edges. **Feature request #1: `stream_connect=a.x:b.y:DEPTH` emitting an `axis_data_fifo`.** |
| **G3** | **One fabric clock for all kernels, set to the *minimum* `freqhz` across every `[clock]` block.** Per-kernel clocks are parsed but collapsed. | `emit/metadata/system_map_ctx.py:39-56`; `slash.tcl:342-345` | No conflict — F110 is uniformly 300 MHz — but the `[clock] krnl=` syntax implies a per-kernel capability that does not exist. | None needed here. **Documentation gap at minimum.** |
| **G4** | **250 MHz is the highest engageable clock**; 275 MHz+ silently fails to lock while the readback still reports success. | `BUGS_UPSTREAM.md` Bug 2; measured 2026-08-05 | F110 closed timing at 300 MHz with WNS **0.000** — zero margin. | **DECIDED 2026-08-06: target 200 MHz**, SLASH's own default (`system_map_ctx.py:32`). 33% below F110's 300 MHz, but it buys real timing margin for a design that closed with none, and the kernel region now spans the SLR cut. Revisit 250 MHz once it runs. |
| **G5** | **`Buffer::sync()` transfers the whole buffer.** No offset/length, although the vrtd layer beneath supports it. | `vrt/include/vrt/buffer.hpp:345-349` vs `allocator.hpp:160-161` | F110's 27 MB pixel output is always fully synced even when only a few clusters are produced. | **Feature request: expose the ranged sync that already exists one layer down.** |
| **G6** | **Only DDR0 and DDR1 are usable.** DDR2/DDR3 segfault the host. | `examples/04_test_felix/config.cfg:12-13` | F110's 4 m_axi ports must share 2 attach points. The linker auto-builds a SmartConnect reduction tree, so it works, but halves per-port bandwidth. | Accept, or fix DDR2/DDR3 (open task). |
| **G7** | **`Kernel::wait()` spin-polls `ap_done` with no timeout and no yield.** | `vrt/src/kernel.cpp:440` | A stalled 12-stage stream chain hangs the host forever instead of failing. Very likely during bring-up. | Copy `examples/04_test_felix/04_test_felix.cpp:48-53`'s `waitKernel()`. **Feature request: a timeout overload in VRT itself.** |
| **G8** | **~128 MB device buffer pool.** | `examples/02_ddr_bw/02_ddr_bw.cpp:42-44` | F110 needs ~59 MB across 4 buffers. Fits, but under half the pool. | Accept. |
| **G9** | **`vrt/include/vrt/streaming_buffer.hpp` is uncompilable** — it includes `api/device.hpp`, which does not exist, and calls methods absent from the public `vrt::Device`. It is installed anyway. | header itself | None (unused) — but it is shipped broken and will mislead anyone who tries it. | **Bug: fix or stop installing it.** |
| **G11** | **HLS renames ports that collide with reserved-ish words** (`input`→`input_r`, `output`→`output_r`, `in`→`in_r`, `out`→`out_r`); others are untouched. The name propagates into `stream_connect=`, `sp=`, AND host `setArg`/`argMemoryConfig`. | measured on 12 kernels, Stage 0/3 | **5 of F110's 17 stream links** name a renamed port. A transliterated `sc=` line fails; the linker's fuzzy matcher (`stream_ctx.py:31-45`) tries exact/lower/alnum and matches none of them. | Generate the config from `component.xml`, never by hand — see `examples/05_f110/gen_config.py`. **Feature request: extend the fuzzy matcher to strip a trailing `_r`.** |
| **G14** | **`flow_target=vivado` does not infer loop auto-rewind where `flow_target=vitis` does.** Vitis report: `loop auto-rewind flp (delay=0)`. Vivado report: `WARNING: [HLS 200-1990] ... can be improved with loop rewind inference if the loop bound can be asserted to execute at least once.` | `narrower` build logs, both flows | Affects 1 of 12 kernels (`narrower`), the only one that is `ap_ctrl_none` with a terminating loop. **Measured to be harmless here** — it still streams 616k words correctly — but it silently changes free-running kernel codegen. | Use `do { } while (...)` so the trip count is provably >= 1. **Documentation gap: flow-target differences are not enumerated anywhere.** |
| **G15** | **`vrt::Buffer` rejects allocations below ~4 KB** with `ERROR: Size too small for MediumBlockSuperblock` instead of rounding up. `MediumBlockSuperblock = BuddySuperblockBase<12,21>` => 4 KB granularity. | `vrt/include/vrt/allocator/allocator.hpp:357-360`; hit on hardware 2026-08-07 | Bites exactly when you shrink a test case to debug something — a 128-byte buffer is refused. The message does not state the minimum. | Pad the allocation and track the real element count separately. **Minor: round up, or say "minimum 4096 bytes" in the error.** |
| **G12** | **The config parser does not accept trailing comments on `sp=` or `stream_connect=` values.** Both do a bare `val.split(":")`; only whole-line `#`/`;` comments are stripped. | `config_parser.py:107,163` | Cost one link attempt. The error message is clear, so it fails loudly rather than silently. | Put comments on their own line. **Minor: strip inline comments before parsing.** |
| **G13** | **Vitis and SLASH disagree on default instance naming.** Vitis names a single unnamed CU `<type>_1`; SLASH names it `<type>_0` (`config_parser.py:78-82`). | — | Every `sc=` reference to a Vitis-defaulted name (e.g. `calculateClusterParameters_1`) would dangle. | Always give explicit names in `nk=`. **Documentation gap.** |
| **G10** | **No OpenCL/XRT compatibility layer.** Zero hits for `CL/cl`, `clCreateBuffer`, `xrt::device` in `vrt/`. | grep across `vrt/`, `examples/` | Any Alveo/Vitis design's host must be rewritten. For F110 this is small — 12 distinct API calls across 48 sites. | Rewrite. For F110 the OpenCL event DAG collapses cleanly to VRT's sync → start-all → wait-all, because `Kernel::start()` is non-blocking. |

---

## 2. Stage 0 results — HLS flow-target probes

**Question:** F110's kernels are built with `flow_target=vitis`, which *infers* interfaces.
SLASH requires `flow_target=vivado`, which does not. What survives?

Four kernels were chosen to cover every interface style in the design. All were
re-synthesized standalone with `flow_target=vivado` + `package.output.format=ip_catalog`
at `clock=4ns`, and the emitted `component.xml` inspected.

### 2a. The finding: `flow_target=vivado` infers nothing — but explicit pragmas fully restore it

**Unmodified sources fail.** Both `narrower` and `configurableLengthWideLoader` died with:

```
ERROR: [HLS 214-208] The ap_axis|ap_axiu|qdma_axis|hls::axis data types must only be used
       for AXI-Stream ports in the interface. 'output' is not an AXI-Stream and/or is not
       a port in the interface
ERROR: [HLS 200-1715] Encountered problem during source synthesis
```

i.e. `hls::stream<ap_axiu<N>>` defaults to `ap_fifo` under the Vivado flow, and HLS then
rejects the `ap_axiu` payload type. For the zero-pragma loader, the bare pointer also
silently degraded:

```
WARNING: [HLS 214-450] Ignore address on register port 'input'
```

— it became a **register port, not `m_axi`**. That is the dangerous failure mode: it is a
warning, not an error, and the same class of silent m_axi loss is already documented in
`examples/04_test_felix/hls/mem_bw.cpp:6-11` for the missing-`extern "C"` case.

**With explicit pragmas, everything comes back.** All four kernels then packaged cleanly:

| Probe | Kernel | Interface style exercised | Result |
|---|---|---|---|
| **P1** | `narrower` | `hls::stream<ap_axiu<512>>` → `<ap_axiu<64>>`, `ap_ctrl_none` | **PASS** — `input_r` axis 512b, `output_r` axis 64b |
| **P2** | `configurableLengthWideLoader` | **zero pragmas**; `const ap_uint<512>*` + axis + scalar | **PASS** — `m_axi_gmem` aximm, `s_axi_control` aximm, `output_r` axis 512b, `interrupt` |
| **P3** | `EDMWriter` | **`hls::burst_maxi`** (manual `write_request`/`write`/`write_response`) | **PASS** — `m_axi_gmem0` aximm, `wr_stream` axis 48b, `wr_data_stream` axis 512b |
| **P4** | `PixelEDMDecoder` | **`hls::stream<hls::vector<uint64_t,18>>`** = 1152-bit, dataflow, 2× replication | **PASS** — `s_edm_in` axis 640b, `s_block_out` axis **1152b** |

Pragmas added were the minimum to state what the Vitis flow had inferred, e.g. for the loader:

```cpp
#pragma HLS INTERFACE m_axi port=input offset=slave bundle=gmem
#pragma HLS INTERFACE mode=axis port=output
#pragma HLS INTERFACE s_axilite port=input  bundle=control
#pragma HLS INTERFACE s_axilite port=vSize  bundle=control
#pragma HLS INTERFACE s_axilite port=return bundle=control
```

### 2b. Unknowns resolved

| # | Unknown | Answer |
|---|---|---|
| **U1** | Do `hls::stream<ap_axiu<N>>` ports present as `BusType.AXIS`? | **Yes — but only with an explicit `#pragma HLS INTERFACE mode=axis`.** Without it, hard error 214-208. |
| **U2** | Do `hls::stream<struct>` / `hls::stream<hls::vector<...>>` present as AXIS? | **Yes.** 1152-bit `hls::vector<uint64_t,18>` became a clean 1152-bit AXIS port. |
| **U3** | Does a zero-pragma Vitis kernel still infer `m_axi` + `s_axilite`? | **No.** The pointer degrades to a register port with only a warning. Pragmas are mandatory. |
| **U4** | Does `hls::burst_maxi` work under `flow_target=vivado`? | **Yes.** `EDMWriter` packaged with `m_axi_gmem0` intact. This was the biggest single risk and it is gone. |
| **U5** | Is there a max AXIS width? | **Not at the HLS/IP-XACT level** — 1152 bits packaged fine. The BD/NoC-level answer still needs a link (Stage 1). |

### 2c. Gotcha worth recording

**HLS renames some stream ports with an `_r` suffix.** `input`/`output` became
`input_r`/`output_r` (they collide with reserved words), while `wr_stream`, `s_edm_in`,
`s_block_out` were left alone. `stream_connect=` lines must use the **actual
`component.xml` port name**, because the linker's fuzzy matcher (`stream_ctx.py:31-45`)
tries exact → lowercase → alnum-normalized, and `output` vs `output_r` matches none of
those. F110's original `sc=` lines say `pixelLoader.output:pixelNarrower.input`; the SLASH
equivalents will need `output_r`/`input_r`.

---

## 3. Stage 1 results — link + hardware

**Question:** does SLASH actually wire real F110 AXIS ports in the block design, and does
the resulting datapath work on silicon?

Built a 3-kernel spine from **genuine F110 sources** (patched only to state interfaces
explicitly) plus a 10-line terminator so the chain lands somewhere the host can read:

```
loader(DDR0) --512b axis--> narrower --64b axis--> sink(DDR1)
```

`narrower` is a footer-hunting state machine that terminates on `(word>>56)==0xcd`, so the
test data uses a top byte of `0x42`. It never triggers, `narrower` acts as a pure 512→64
gearbox, and `sink`'s output must therefore be a **word-for-word copy of the input** — a
real datapath check rather than a liveness check.

### Result: PASS

```
link exit=0 (16 min)      spine_hw.vbin 2.03 MB    ClockFrequency 200000000
slash.tcl:399  connect_bd_intf_net [get_bd_intf_pins loader/output_r] [... narrow/input_r]
slash.tcl:400  connect_bd_intf_net [get_bd_intf_pins narrow/output_r] [... sink/axis_in]

[0] device open, clock = 200.0 MHz
[3] loader done, sink done  (0.326 ms)
[4] datapath compare: 8192 / 8192 words correct
SPINE PASS
```

### What this settles

| Question | Answer |
|---|---|
| Does `stream_connect=` wire real F110 AXIS ports? | **Yes** — both links emitted as `connect_bd_intf_net`, synthesized, placed, routed |
| Do 2 `m_axi` ports bind to DDR0/DDR1? | **Yes** — `loader.m_axi_gmem→DDR0`, `sink.m_axi_gmem0→DDR1` in `system_map.xml` |
| Do `ap_ctrl_none` free-running kernels work? | **Yes.** `narrower` is instantiated and wired but **absent from `system_map.xml`** — no base address, no args, invisible to the host. Exactly the behaviour F110's 8 intermediate CUs need. |
| Does the data actually arrive intact? | **Yes** — 8192/8192 words byte-exact through two AXIS hops and a width conversion |
| Does 200 MHz engage? | **Yes** — `getFrequency()` reports 200.0 MHz |


### 3a. G2 CONFIRMED as the cause — cyclic/unbuffered streams deadlock

`stream_connect=` emits a bare `connect_bd_intf_net`. F110 specifies `:16` on fourteen
links and `:32` on two. Without that buffering the design **builds, routes, closes timing,
and then deadlocks** — with no diagnostic: `Kernel::wait()` simply never returns (G7).

| build | buffering | result |
|---|---|---|
| 15 CUs | none | hang |
| 19 CUs | 4 "FIFOs" on the cycle edges — **which contained no FIFO, see §3b** | hang |
| 32 CUs | 17 real depth-32 FIFOs, one per link | **RUNS: 0.36 ms, correct cluster counts** |

**Impact:** any HLS dataflow design relying on `sc=` FIFO depth — which is the norm, and
mandatory for feedback loops — cannot run on SLASH without one extra compute unit per
buffered link. F110 needed **17 extra CUs and 9 FIFO widths** to express what Vitis writes
as `:16`. This is feature request #1 and it is not cosmetic.

### 3b. WARNING: `#pragma HLS STREAM depth=` IS SILENTLY USELESS ON AXIS INTERFACE PORTS

This cost two full build+test cycles (~3 h). Recording it so nobody repeats it.

```cpp
void fifo(hls::stream<T>& in, hls::stream<T>& out) {     // WRONG - buffers NOTHING
#pragma HLS INTERFACE mode=axis port=in
#pragma HLS STREAM variable=in depth=32                  // <-- rejected
```
```
WARNING: [HLS 214-191] The stream pragma on function argument, in 'call' is unsupported
csynth report:  FIFO: -    Memory: -    Register: 1031
```
It is a **warning, not an error**, and the design builds and runs — as a one-word pipeline
register. Two "FIFO" experiments were therefore invalid, and G2 was wrongly written up here
as "ruled out".

Depth is only honoured on an **internal** stream, which needs `DATAFLOW` plus separate
producer/consumer processes:

```cpp
static void fifo_rd(hls::stream<T>& in, hls::stream<T>& buf) { while(true){ buf.write(in.read()); } }
static void fifo_wr(hls::stream<T>& buf, hls::stream<T>& out){ while(true){ out.write(buf.read()); } }

extern "C" void axis_fifoN(hls::stream<T>& in, hls::stream<T>& out) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE mode=axis port=in
#pragma HLS INTERFACE mode=axis port=out
#pragma HLS DATAFLOW
    static hls::stream<T> buf;
#pragma HLS STREAM variable=buf depth=32
    fifo_rd(in, buf); fifo_wr(buf, out);
}
```

**Always verify** — the generated RTL must contain a module named `*_w<WIDTH>_d<DEPTH>_*.v`:
```
axis_fifo1024_fifo_w1024_d32_A.v    DEPTH = 32   ADDR_WIDTH = 5
```
No such module => no FIFO, regardless of what the pragma says.

### 3c. Result

```
[3] pixelLoader done, stripLoader done, PixelEDMWriter done, StripEDMWriter done (0.36 ms)
[5] pixel: 91 non-zero words, header[0]=0x5     <- input has 15 hit words / 3 = 5 clusters
    strip: 96 non-zero words, header[0]=0x8     <- input has 16 hit words / 2 = 8 clusters
    ALL STRUCTURAL CHECKS PASSED
```
Both chains report the cluster count implied by their input. Physics correctness still
needs the reference output.

### G11 (new) — the `_r` suffix trap

HLS renames stream and pointer ports whose names collide with reserved-ish words:
`input`→`input_r`, `output`→`output_r`, `out`→`out_r`, while `axis_in`, `wr_stream`,
`s_edm_in`, `s_block_out` are left alone. This propagates into **three** places:
`stream_connect=` endpoints, `sp=` port names, and host-side `setArg`/`argMemoryConfig`
names in `system_map.xml`.

The linker's fuzzy matcher (`stream_ctx.py:31-45`) tries exact → lowercase →
alnum-normalized; `output` vs `output_r` matches none of them, so a transliterated
`sc=` line fails. **Every one of F110's 16 stream links and 4 `sp=` lines must be written
from the actual `component.xml`, not copied from `u250_hw.cfg`.** With 16 links this is a
realistic source of silent misconfiguration.

---

## 4. Assessment

**No hard blocker in the HLS half.** Every interface style F110 uses survives the move to
`flow_target=vivado` once the interfaces are stated explicitly. The `hls::burst_maxi` and
1152-bit-AXIS risks — the two that could have ended the port — are both clear.

Remaining cost is **mechanical**: add explicit interface pragmas to 12 kernels and rebuild.
The only design-level compromises are **G2** (lost stream FIFO depths, mitigable with
passthrough FIFO kernels) and **G4** (300 → 250 MHz, ~17% throughput).

Still unproven, and the subject of Stage 1: whether `stream_connect` actually links these
real ports in the BD, whether 1152-bit AXIS survives the block design, and whether the
SmartConnect tree handles 4 m_axi ports on 2 DDR attach points.

## 5. Feature requests, ranked

1. **`stream_connect=a.x:b.y:DEPTH`** emitting an `axis_data_fifo` (G2) — the only gap that
   forces a design change rather than a mechanical edit.
2. **Ranged `Buffer::sync(offset, len)`** (G5) — the capability already exists one layer down.
3. **`Kernel::wait(timeout)`** (G7) — every example already hand-rolls this.
4. **Accept `.xo` directly, or document that `flow_target=vivado` + explicit interface
   pragmas are mandatory** (G1) — the current silent-degradation failure mode is expensive
   to debug.
5. **Fix or stop installing `streaming_buffer.hpp`** (G9).
