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

**1a. Install kdump** (records a crash dump if the kernel panics):

```bash
sudo apt-get install -y linux-crashdump
```

If the "Should kexec-tools handle reboots?" dialog was answered wrong,
redo it and answer **Yes**:

```bash
sudo dpkg-reconfigure kexec-tools
sudo systemctl enable --now kdump-tools
kdump-config show          # want: "current state: ready to kdump"
```

**1b. Watch the kernel log on the server's own monitor.** You are sitting at
the server, so this replaces netconsole (which can't reach the MacBook — it's
on a different subnet). On the physical monitor:

```
Ctrl+Alt+F3                # switch to text console tty3
# log in, then:
sudo dmesg -w              # live kernel messages fill the screen
```

Leave that running during every crash test. The machine HANGS rather than
rebooting cleanly, so if the kernel prints a panic/oops as it dies it will be
sitting on this screen — **photograph it before pressing reset. That photo
can be the whole diagnosis.** (If the screen shows nothing at all when it
hangs, that too is a result: it points to a hard hardware/firmware hang, not
a kernel bug.)

**1c. Let Linux — not the BIOS — handle PCIe errors.** This can turn the
silent hang into a logged, survivable error:

```bash
sudo nano /etc/default/grub     # set: GRUB_CMDLINE_LINUX="pcie_ports=native"
sudo update-grub
# then reset the box (this server stalls on soft reboot; use the reset button)
```

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
sudo ipmitool sel clear
./scripts/diag/00_baseline.sh
```

Then on the server's monitor start the live kernel log (Step 1b):
`Ctrl+Alt+F3` → log in → `sudo dmesg -w`, and leave it up during the test.

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

1. Look at the **server's monitor** (the `dmesg -w` console from Step 1b) —
   photograph anything printed there before touching the reset button. A
   blank screen is also a result: it means a hard hardware/firmware hang,
   not a kernel panic.
2. Press the reset button.
3. When it comes back, run these **before** reprogramming the card or
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
→ reset → modprobe + sel clear + 00_baseline.sh + (monitor: dmesg -w on tty3)
→ run ONE test (step 5 or 6)
→ if crash: photo screen → reset → 10_after_crash.sh + jtag harvest → send diag_logs/
→ if pass:  next step
```

## What to send to Claude each time

Everything new under `diag_logs/`, especially:
- `jtag_baseline.txt` / `jtag_postcrash.txt` (PLM log + SBI registers)
- `*_postcrash/sel_after.txt` (the BMC's record of why the machine died)
- the photo of the server's monitor at crash time (or "screen was blank")
