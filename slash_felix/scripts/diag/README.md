# Server-crash diagnostic — simple runbook

**The problem:** running `00_axilite` kills the whole server (hang, then a
manual reset is needed) at the moment vrtd DMAs the partial PDI to the PMC
(`0x102100000`). Nothing gets logged.

**The plan:** 3 possible causes, and one test for each. Run the steps in
order. Stop at the first test that fails — that's the root cause.

| Cause | Meaning | Which step finds it |
|---|---|---|
| A | The partial PDI itself is bad | Step 3 |
| B | QDMA DMA path is broken (any DMA would crash) | Step 5 |
| C | PMC's slave-boot port (SBI) is not ready to receive a PDI | Step 6 |

All output files go to `diag_logs/`. Send them to Claude after each step.

## Which BDF to pass to the examples

`lspci -d 10ee: -nn` shows 3 functions of the one card:

| BDF | ID | Role | Driver |
|---|---|---|---|
| `01:00.0` | 50b4 | management (VSEC/GCQ→AMC) | `ami` |
| `01:00.1` | 50b5 | QDMA (DMA engine) | `slash_qdma` |
| `01:00.2` | 50b6 | control (BARs, kernels) | `slash_ctl` |

The examples want the **board address, without a function number**:

```bash
./build/00_axilite       0000:01:00 axilite_hw.vbin
./build/no_program_test  0000:01:00 axilite_hw.vbin
```

Passing `01:00.1` or `01:00.2` still works — vrt strips the `.N` with a
warning ("use board address instead") and talks to all three functions via
vrtd anyway. So the crash is NOT caused by picking the "wrong" PF; there is
no wrong PF, only the cosmetic warning.

---

## Step 1 — one-time setup (do once, today)

```bash
# 1a. install kdump (records kernel panics, if that's what this is)
sudo apt-get install -y linux-crashdump

# 1b. netconsole: live kernel log to your MacBook, survives the crash.
#     On the MacBook first run (re-run it if it ever exits):
#         nc -ul 6666
#     Then on the server (repeat after EVERY boot, before a test):
sudo modprobe netconsole netconsole=@/,6666@<MACBOOK-IP>/

# 1c. let Linux (not the BIOS) handle PCIe errors - may stop the reboots
#     and log the error instead:
sudo nano /etc/default/grub     # set: GRUB_CMDLINE_LINUX="pcie_ports=native"
sudo update-grub
sudo reboot
```

# 1d. plug a monitor into the server (or use the one already attached) and
#     have it showing the console during every crash test. The machine HANGS
#     rather than cleanly rebooting, so any panic/NMI text that never reaches
#     the disk may still be sitting on that screen when it dies — photograph
#     it before pressing reset. That photo can be the whole diagnosis.
#     Tip: switch a spare TTY to kernel messages so panics land on screen:
#         Ctrl+Alt+F3, log in, run:  sudo dmesg -w

## Step 2 — build once, then STOP rebuilding

Do your clean build of fw + sw + drivers **one time**. Then:

```bash
./scripts/diag/00_baseline.sh
```

This records md5 checksums of the PDI/vbin. **Do not rebuild again during
the whole diagnosis** — every test must use identical files.

## Step 3 — test the partial PDI over JTAG (SAFE — cannot crash)

Program the card as you normally do (Vivado hw manager, `felix_slash_amc.pdi`).
Then, still over JTAG:

```bash
xsdb scripts/diag/20_jtag_harvest.tcl      | tee diag_logs/jtag_baseline.txt
xsdb scripts/diag/30_jtag_partial_load.tcl | tee diag_logs/jtag_partial.txt
```

The second script loads the SAME partial PDI the crash uses — but via JTAG,
no PCIe involved.

* Says **PARTIAL LOAD FAILED** → **Cause A found. STOP.** Send both files.
* Says **PARTIAL LOAD OK** → PDI is good. Continue to Step 4.

## Step 4 — reboot and baseline (your normal flow)

```bash
# this server stalls on soft reboot -- use the reset button as usual.
# after it comes back:
cd ~/VersalPrjs/felix/felix-xpfm-pcie/porting_slash/slash_felix
sudo modprobe slash; sudo modprobe ami
sudo modprobe netconsole netconsole=@/,6666@<LAPTOP-IP>/   # laptop: nc -ulk 6666
sudo ipmitool sel clear
./scripts/diag/00_baseline.sh
```

## Step 5 — first crash test: DMA to DDR only (may crash — that's the point)

```bash
cd examples/00_axilite
./build/no_program_test 0000:01:00 axilite_hw.vbin
```

This does the exact same kind of DMA as the crash, but into DDR instead of
the PMC.

* **Server reboots** → **Cause B found. STOP.** Do Step 7, send everything.
* **Test passes** → DMA is healthy. The problem is specific to the PMC
  target. Continue to Step 6.

## Step 6 — confirm Cause C (SBI not ready)

Send Claude `diag_logs/jtag_baseline.txt` from Step 3 (it contains the SBI
registers). Claude decodes them and gives you one `mwr` command to put the
SBI into the right mode over JTAG. Then run `00_axilite` once more:

* **Works** → root cause confirmed = Cause C. Fix gets baked into the flow.
* **Still crashes** → do Step 7; the collected files will say what's left.

## Step 7 — AFTER ANY CRASH: collect evidence (always, before anything else)

When it crashes, the machine will HANG (this server never finishes a soft
reboot anyway). In order:

1. Look at the **server's monitor** — photograph anything printed there
   before touching the reset button.
2. Check the **netconsole listener** on the MacBook — save its output
   (an empty capture is also a result: it means hardware/firmware hang,
   not a kernel panic).
3. Press the reset button.
4. When it comes back, run these **before** reprogramming the card or
   starting the next test:

```bash
./scripts/diag/10_after_crash.sh                 # host-side evidence (SEL, logs)
xsdb scripts/diag/20_jtag_harvest.tcl | tee diag_logs/jtag_postcrash.txt   # card-side
```

The card keeps its state through the crash — reprogramming it erases the
best evidence. JTAG harvest first, reprogram after.

---

## Cheat sheet — one full cycle

```
build once → 00_baseline.sh → JTAG program → jtag harvest + jtag partial test
→ reboot → modprobe + sel clear + netconsole + 00_baseline.sh
→ run ONE test (step 5 or 6)
→ if crash: 10_after_crash.sh + jtag harvest   → send diag_logs/ to Claude
→ if pass:  next step
```

## What to send to Claude each time

Everything new under `diag_logs/`, especially:
- `jtag_baseline.txt` / `jtag_postcrash.txt` (PLM log + SBI registers)
- `*_postcrash/sel_after.txt` (the BMC's record of why the machine died)
- whatever the netconsole listener on your laptop printed (or "nothing")
