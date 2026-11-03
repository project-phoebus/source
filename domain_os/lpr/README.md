# The LPR subsystem in Domain Pascal

The line printer driver.  Where it is configured out (the SR10.2 SAU2,
SAU5..SAU9 kernels) what is left is one routine, LPR_$RELEASE, and it is
**hand-written assembly**: the module LPR_ is empty there.  With
`lpr_driver` (`../base/config.ins.pas`) the driver of the parallel
printer port at LPR, translated from the SAU3 image: a module, LPR_,
and the hand-written LPR_ASM, whose interrupt routine sends the lines
queued in a circular buffer (`../cbuf/`) to the port.  The SAU4's
driver (`lpr_pbu_unit`) drives the PNA's port, the PBU's unit 6, in
`lpr.pas`'s other arm and each fragment's, with `sau4/lpr_asm.s`.

## Layout

Without the driver (the SAU2 map) two segments, both in .TEXT:

| segment | size | symbols | contents |
|---------|------|---------|----------|
| LPR_ASM | 4 | LPR_$PROC_START, LPR_$RELEASE (one address) | a bare return and a zero pad word |
| LPR_END_ADDR | 4 | LPR_$PROC_END (odd: the segment's start + 1) | zeros |

and two data symbols with no LPR data segment of their own,
LPR_$DATA_END and LPR_$DATA_START: markers only.

With the driver (the SAU3 map), module `lpr_` (the map segment's name),
`lpr.pas`:

| section | segment | routines and objects | attribute |
|---------|---------|----------------------|-----------|
| OS_INIT_PROC | LPR_, 0x5C bytes | LPR_$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT (default) | LPR_, 0x3C0 bytes | lpr_set_mode (at LPR_$PROC_START), LPR_$STATE, LPR_$WRITE, LPR_$ACQUIRE, LPR_$RELEASE | none |
| .DATA (default) | LPR_ data, 0x64 bytes | the wired pages, LPR_$BCB, the mode table, the state, the owner, LPR_$PRESENT | module variables |
| .DATA | LPR_ASM, 0x2F4 bytes | LPR_$MOVE_DATA, LPR_$INT, LPR_$DATA_MASK, LPR_$ENABLE_INT, LPR_$DISABLE_INT, the counters, LPR_$BUFFER | hand assembly, `sau3/lpr_asm.s` |

CBUF's code and LPR_END_ADDR follow LPR_'s .TEXT code, inside the
driver's wired range (LPR_$PROC_START .. LPR_$PROC_END, then
LPR_$DATA_START .. LPR_$DATA_END, three bytes into CBUF's block).

## Why LPR_ASM is hand assembly

- The segment's name ends in `_ASM`; it is code in a data section.
- Its routines have no frame and read their arguments off the stack;
  LPR_$INT is an interrupt entry that saves the scratch registers,
  switches to the interrupt stack and leaves through PROC1_$INT_EXIT.
- Without the driver, LPR_$RELEASE is a return padded with a **zero**
  word, where compiled modules end in the compiled module-end filler
  (MT_$RELEASE and CT_$RELEASE, the same configured-out return).
- LPR_END_ADDR is a marker segment of zeros, with an odd symbol.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| LPR_$INIT | `init.pas` |
| lpr_set_mode (at the map's LPR_$PROC_START) | `set_mode.pas` |
| LPR_$STATE | `state.pas` |
| LPR_$WRITE | `write.pas` |
| LPR_$ACQUIRE | `acquire.pas` |
| LPR_$RELEASE | `release.pas` (without the driver hand assembly, `m68k/release.s`) |
| LPR_$MOVE_DATA | none: hand assembly (`sau3/lpr_asm.s`) |
| LPR_$INT | none: hand assembly (`sau3/lpr_asm.s`) |
| LPR_$ENABLE_INT | none: hand assembly (`sau3/lpr_asm.s`) |
| LPR_$DISABLE_INT | none: hand assembly (`sau3/lpr_asm.s`) |
| (LPR_END_ADDR marker) | none: hand assembly (`m68k/end_addr.s`) |

`m68k/release.s` assembles to nothing with the driver (`.if
!lpr_driver`).  `m68k/release.s` and `m68k/end_addr.s` are
byte-identical with the SAU2 image (`make check-asm`); `sau3/lpr_asm.s`
was checked by assembling it and linking it at the segment's address,
byte-identical with the SAU3 image's 0x2F4 bytes.

`lpr.ins.pas` holds the statuses, the port's registers, the mode and
state records, LPR_ASM's symbols, the markers and the headings.

## Open items

- The SAU4's form (`lpr_pbu_unit`): LPR_$INIT, LPR_$STATE, LPR_$ACQUIRE
  arms of their own; LPR_$WRITE and LPR_$RELEASE the SAU3's bodies with
  PBU_$ENABLE_DEVICE and PBU_$RELEASE_INT for the enable routines; no
  lpr_set_mode; LPR_ASM `sau4/lpr_asm.s`.
