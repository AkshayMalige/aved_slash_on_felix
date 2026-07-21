# FELIX SLASH — Concepts (plain-language reference)

How the card actually works: the parts, who does what, and the two very
different "programming" operations people confuse. Written to be readable
without FPGA background.

## The cast

| Name | What it is | Where it lives | Its job |
|---|---|---|---|
| **Host / your software** | your PC + `vrtd`, `ami_tool`, your app | outside the card | drives everything over PCIe |
| **QDMA** | the fast cargo mover | in the card | bulk data + delivering the swap file (big lane) |
| **GCQ** | a little message box | in the card | management chat with the caretaker (small lane) |
| **PMC** | the *installer* | built inside the big Versal chip | reads flash at boot; re-wires the fabric on request |
| **RPU / AMC** | the *caretaker* (AMC = the software on the RPU) | built inside the big Versal chip (Cortex-R5) | sensors, flash-writing, answering management messages |
| **FPGA fabric** | the *workbench* | the big Versal chip | runs your accelerator (kernel) |
| **Flash chip** | the *recipe book on a shelf* | a small separate chip on the card | permanent storage of the boot image |

Two processors people mix up:
- **PMC** = installer. Does *all* configuration/reconfiguration. Always involved in a swap.
- **RPU/AMC** = caretaker. Management only. **Not** involved in a swap.

## The big Versal chip forgets everything at power-off

At power-on it's blank. The **boot image** stored in the **flash chip** is copied
into it by the **PMC** to make it become the working design. The fabric config is
*volatile* — gone on power-off; the flash chip is *permanent*.

## Two different "writing" operations (the key confusion)

| | What changes | Permanent? | Who does it | When |
|---|---|---|---|---|
| **Kernel swap** | the **live fabric** (the workbench) | ❌ gone at power-off | **PMC** | every time you load a kernel |
| **Flashing** | the **flash chip** (the boot image) | ✅ survives power-off | **AMC** | rarely — to change what boots next time |

**A kernel swap never touches flash.** The PMC just re-wires live silicon.

## Kernel swap — step by step

1. **Your software (`vrtd`)** has the kernel as a partial-PDI file (from the `.vbin`).
2. **`vrtd` + QDMA** DMA it over PCIe to the mail-slot address `0x102100000`.
3. **The on-chip network** delivers it to the **PMC**.
4. **The PMC re-wires only the `slash` workbench** (partial reconfiguration) — the rest of the card keeps running.
5. **`vrtd` (`clock.c`)** sets the new kernel's clock speed (via the BAR4 window).
6. **`vrtd` (`reset.c`)** does a clean reset so the OS re-sees the card fresh.
7. **Your app** uses the new kernel.

Flash: untouched. AMC/GCQ: not involved (unless step 6 asks the AMC to do the reset).

**`reset.c` fires once per *swap*, never per *run*.** Loading a different kernel → one reset (a few seconds, the card blips out of PCIe and back). Running an already-loaded kernel → no reset, ever.

Why the reset is needed: re-wiring the fabric changes the hardware behind the card's
address windows, so the OS/PCIe hold a stale picture. The reset (Secondary Bus Reset +
hotplug rescan) makes the card cleanly "re-plug" so the driver re-reads the new layout.

## Flashing — step by step (rare, permanent)

1. **Your tool (`ami_tool`)** has a new full boot image to store.
2. It puts the (big) image in the **shared 128 MB memory area** and drops a short note in the **GCQ** message box: *"flash the image over there."*
3. **The GCQ rings the doorbell (interrupt)** → **the AMC wakes up.**
4. **The AMC reads the image from shared memory and writes it into the flash chip.**
5. **The AMC replies "done"** via the message box.
6. **Next power-on: the PMC reads the new image from flash.**

So: swap = **PMC re-wires live fabric** (now, temporary); flash = **AMC writes the flash chip** (for the *next* boot, permanent).

## What the AMC (caretaker) actually does

It mostly sleeps. Its life:
```
loop forever:
    sleep
    wake on: (a) GCQ doorbell → a management message arrived → handle it, reply
         or  (b) timer        → time to read the sensors → update the whiteboard
    sleep
```
- **Management (event-driven):** answers GCQ messages — device info, "flash this", "reboot".
- **Sensors (timer-driven):** every few seconds it reads the board's temperature/voltage/power chips over I2C and writes the latest values to a shared "whiteboard" the host can read anytime.
- It is **not** part of running or swapping a kernel.

## The GCQ mailbox — where it sits

The GCQ is the **management message box** between the host and the AMC. Only that.
- Host side reachable by the `ami` driver (PF0) @ `0x201_0101_0000`; AMC side reachable by the R5 @ LPD `0x8000_0000`; a doorbell interrupt wakes the AMC.
- Used for: flashing, sensors, device info, reboot. **Not** for kernel data or the swap.

**The clean split of the two lanes:**
- **QDMA** (big lane) → moves kernel data *and* the swap file to the PMC.
- **GCQ** (small lane) → management chat with the AMC.

That's why a **kernel swap uses only QDMA + the PMC** (no GCQ, no AMC), while
**flashing and sensors use GCQ + the AMC** (the PMC only re-reads flash at the next boot).

## One-breath recap

PMC = installer (does swaps, reads flash at boot). RPU/AMC = caretaker (management,
lives on the R5, loaded from the boot image). Swap = DMA the file to a mail-slot →
the PMC re-wires the live fabric → `clock.c` sets the speed → `reset.c` re-plugs the
card. Flashing = the AMC writes the permanent boot image into the flash chip. The GCQ
is the message box for talking to the caretaker; the kernel swap doesn't need it.
