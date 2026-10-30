# The MMU subsystem in Domain Pascal

The memory management unit's routines (page install and remove, the
reverse-map hash chains, address translation, the control registers) are
**hand-written assembly** in the SR10.2 SAU2 image: every MMU_ symbol
lies in the map's MMU_ASM data segment (WIRED_DATA, 0x5B8 bytes). So the
subsystem has no module file of its own and no fragment for any MMU_
routine. `mmu/m68k/*.s` holds the transcriptions.

The one piece of compiler output in mmu/ is `vtop_or_crash.pas`.  Its
routine, mmu_$vtop_or_crash, is a module-local routine of another map
module, MMAP_UNWIRED, and the fragment is included by that module's
file `../mmap/mmap_unwired.pas`; it lives in mmu/ because it wraps
MMU_$VTOP.

`mmu/mmu.ins.pas` holds the headings Pascal callers compile against.

## Layout

### MMU_ASM, hand assembly

The MMU_ASM segment, code and data mixed, by offset from its start:

| offset | symbol | what |
|--------|--------|------|
| +0x000 | MMU_$PID_PRIV | data, a word: the CSR's process-id/privilege bits (0 in the image) |
| +0x002 | M68020 | data, a word: nonzero on a 68020 (0 in the image, set at boot; `mmu.ins.pas` declares it, a boolean for its compiled readers) |
| +0x004 | (none) | data, a longword: VA_TO_PTT_OFFSET_MASK, 16#000FFC00 (MMU_$INIT stores 16#003FFC00 on a 68020) |
| +0x008 | (none) | data, a word: the VA shift, 3 |
| +0x00A | (none) | data, a word: the PTT shift, 8 |
| +0x00C | MMU_$INIT | code, 0x2C bytes |
| +0x038 | MMU_$REMOVE | code, 0x2E |
| +0x066 | MMU_$REMOVE_LIST | code, 0x3A |
| +0x0A0 | (none) | code, 0x6C: three register-called entries that fall through, mmu_$remove_internal (+0x0A0), mmu_$remove_pmape (+0x0AC), mmu_$unlink_from_hash (+0x0C8) |
| +0x10C | MMU_$REMOVE_VIRTUAL | code, 0xD4 |
| +0x1E0 | MMU_$REMOVE_ASID | code, 0x76 |
| +0x256 | MMU_$INSTALL_PRIVATE | code, 0x5C |
| +0x2B2 | MMU_$INSTALL_LIST | code, 0x6A |
| +0x31C | MMU_$INSTALL | code, 0x54 |
| +0x370 | (none) | code, 0x72: mmu_$installi, register-called by the three installers |
| +0x3E2 | MMU_$VTOP | code, 0xAA |
| +0x48C | MMU_$PTOV | code, 0x3C |
| +0x4C8 | MMU_$SET_CSR | code, 0x10 |
| +0x4D8 | MMU_$INSTALL_ASID | code, 0x26 |
| +0x4FE | MMU_$SET_PROT | code, 0x30 |
| +0x52E | MMU_$CLR_USED | code, 0x14 |
| +0x542 | MMU_$SYSTEM_REV | data, a longword (zero), written by MMU_$SET_SYSREV |
| +0x546 | MMU_$SET_SYSREV | code, 0x0E |
| +0x554 | MMU_$NORMAL_MODE | code, 0x0C |
| +0x560 | MMU_$POWER_OFF | code, 0x12 |
| +0x568 | MMU_$INIT_BSR | data inside MMU_$POWER_OFF: the immediate word of an instruction (0, patched by COLD_START) |
| +0x572 | MMU_$CACHE_INHIBIT_VA | code, an empty routine |
| +0x574 | MMU_$MCR_CHANGE | code, 0x32 |
| +0x5A6 | (none) | data, a word: the 68010 MCR shadow, 16#F000 |
| +0x5A8 | CACHE_$CLEAR | code, 0x0E: CACHE's, `cache/sau2/` (not this subsystem's) |
| +0x5B6 | CACHE_$FLUSH_VIRTUAL | code, an empty routine: CACHE's |

The map names only the first two words of the data run at the head;
the `.s` files reach the three cells after them as MMU_$PID_PRIV plus
an offset (`m68k/mmu_data.s`).  No Pascal declares MMU_$PID_PRIV, the
three unnamed cells, MMU_$INIT_BSR or the MCR shadow: no compiled
routine translated so far reads them (MMU_$SYSTEM_REV is declared for
ASKNODE).  MMU_$PTTX (OS_PMAPS) and the hardware pages MMU and PFT (the
IODEFS run) are outside MMU_ASM; `mmu.ins.pas` declares MMU and PFT for
PARITY.

### Why it is hand assembly

The signs of hand assembly (the `.s` files' byte listings show each):
- **Location.** Code inside a `D` segment whose name ends in `_ASM`,
  mixed with data cells (MMU_$SYSTEM_REV between MMU_$CLR_USED and
  MMU_$SET_SYSREV; the MCR shadow between MMU_$MCR_CHANGE and
  CACHE_$CLEAR).
- **No frame.** No `link`/`unlk` anywhere in the segment (a scan of its
  bytes): arguments read off SP (MMU_$SET_CSR, MMU_$REMOVE, MMU_$VTOP).
- **A5 and data PC-relative.** MMU_$INIT, MMU_$SET_CSR and
  MMU_$SET_SYSREV address the segment's data relative to the PC.
- **Register arguments and shared code.** mmu_$remove_internal, _pmape
  and _unlink_from_hash fall through into one another with their
  arguments in D1..D3, A2, A3 (`m68k/internal.s`); mmu_$installi takes
  D2, D4, A4 (`m68k/installi.s`).
- **SR saved on the stack** around the PTT accesses (MMU_$REMOVE), which
  compiled code never does.
- **Self-modifying code.** MMU_$INIT_BSR is an instruction's immediate;
  on a 68010 MMU_$INIT copies its own return instruction over
  CACHE_$CLEAR's first word.

### The other SAUs' MMU_ASM

`mmu/m68k/*.s` is the page frame table MMU of the SAU2, SAU3 and SAU5
(the same code on the three): each file's body is under `.if pft_mmu`
(base/config.ins.pas), so a SAU without that MMU assembles them to
nothing.  The SAU4 and SAU6..SAU9 each have an MMU_ASM of their own.

The SAU9's, `sau9/mmu_asm.s`, is the MC68030 PMMU's (WIRED_DATA, 0x634
bytes, the last 0x1C CACHE's): the data run MMU_$IMR_COPY, the CPU root
pointer image, MMU_$OS_PMAPS_PHADDR and MMU_$RARS_PHADDR (58 longwords);
the register-called mmu_$locate (a virtual address's segment descriptor
in SMAPS and page map entry, the interrupts masked), mmu_$invalidate,
mmu_$install_entry and mmu_$flush_va (no map symbols); and the map's
MMU_$INSTALL_SPECIAL, _$REMOVE_SPECIAL_SEG, _$REMOVE (a virtual
address), _$CACHE_INHIBIT_VA, _$INSTALL, _$VTOP, _$GET_PMAPE_ADDR,
_$SET_PMAPE, _$INSTALL_ASID, _$PAGE_WRITE_BIT, _$PURGE_TB (a branch to
MMU_$PURGE), _$PURGE (`pflusha`, then CACHE_$FLUSH_VIRTUAL),
_$SET_SEG_PROT, _$SYSTEM_REV (a longword), _$SET_SYSREV (an `rts`),
_$NORMAL_MODE, _$POWER_OFF (false) and _$MCR_CHANGE (the LED register).
CACHE_$CLEAR is the SAU2's code (`../cache/m68k/clear.s`);
CACHE_$FLUSH_VIRTUAL clears the data cache under `cacr_clear_data`
(`../cache/m68k/flush_virtual.s`).  The SAU9 has no MMU_$INIT in
MMU_ASM.

The build has no SAU9 target yet: the file was checked by assembling it
with `m68k-elf-as -m68030` with the two CACHE_ files (the SAU9
config.inc), linking at the map's address with the map's addresses for
the external symbols, and comparing the 0x634 bytes with the image's:
identical.

### MMAP_UNWIRED, compiled

The map's MMAP_UNWIRED code segment in OS_INIT_PROC (0x278 bytes); the
map has no MMAP_UNWIRED data segment.  The module's other code segment,
in .TEXT (0xC bytes), holds MMAP_$REMOTE_POOL: so .TEXT is the module's
default code section, and a heading that names no sections with
OS_INIT_PROC's routines attributed is the right form.  Its first
routine (0x32 bytes, no map symbol) is mmu_$vtop_or_crash, compiler
output (a frame, a register save, a call of MMU_$VTOP, a test of the
frame's status, a call of CRASH_SYSTEM).  It is module-local
(`internal`), not nested (no read through the static link), headed
`[section(os_init_proc, os_init_data)]` (the module has no variables,
as AS: as/as.pas).  Its one caller is MMAP_$INIT.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MMU_$INIT | none: hand assembly (`m68k/init.s`) |
| MMU_$REMOVE | none: hand assembly (`m68k/remove.s`) |
| MMU_$REMOVE_LIST | none: hand assembly (`m68k/remove_list.s`) |
| mmu_$remove_internal, mmu_$remove_pmape, mmu_$unlink_from_hash | none: hand assembly (`m68k/internal.s`; no map symbols) |
| MMU_$REMOVE_VIRTUAL | none: hand assembly (`m68k/remove_virtual.s`) |
| MMU_$REMOVE_ASID | none: hand assembly (`m68k/remove_asid.s`) |
| MMU_$INSTALL_PRIVATE | none: hand assembly (`m68k/install_private.s`) |
| MMU_$INSTALL_LIST | none: hand assembly (`m68k/install_list.s`) |
| MMU_$INSTALL | none: hand assembly (`m68k/install.s`) |
| mmu_$installi | none: hand assembly (`m68k/installi.s`; no map symbol) |
| MMU_$VTOP | none: hand assembly (`m68k/vtop.s`) |
| MMU_$PTOV | none: hand assembly (`m68k/ptov.s`) |
| MMU_$SET_CSR | none: hand assembly (`m68k/set_csr.s`) |
| MMU_$INSTALL_ASID | none: hand assembly (`m68k/install_asid.s`) |
| MMU_$SET_PROT | none: hand assembly (`m68k/set_prot.s`) |
| MMU_$CLR_USED | none: hand assembly (`m68k/clr_used.s`) |
| MMU_$SET_SYSREV | none: hand assembly (`m68k/set_sysrev.s`, which also holds the cell MMU_$SYSTEM_REV) |
| MMU_$NORMAL_MODE | none: hand assembly (`m68k/normal_mode.s`) |
| MMU_$POWER_OFF | none: hand assembly (`m68k/power_off.s`, which also holds MMU_$INIT_BSR) |
| MMU_$CACHE_INHIBIT_VA | none: hand assembly (`m68k/cache_inhibit_va.s`) |
| MMU_$MCR_CHANGE | none: hand assembly (`m68k/mcr_change.s`, which also holds the MCR shadow) |
| (data) | none: hand assembly (`m68k/mmu_data.s`, the MMU_ASM data run; MMU_$PTTX is OS_PMAPS's) |
| (SAU9) MMU_$INSTALL_SPECIAL .. MMU_$MCR_CHANGE, the data run and the local entries | none: hand assembly (`sau9/mmu_asm.s`) |
| mmu_$vtop_or_crash | `vtop_or_crash.pas`, a fragment of MMAP_UNWIRED (`../mmap/mmap_unwired.pas`) |

Every piece of MMU_ASM has its `sau2/*.s` file (CACHE_$CLEAR and
CACHE_$FLUSH_VIRTUAL are in `cache/sau2/`), the data cells inside the
code included.

## For a Pascal caller

`mmu/mmu.ins.pas` declares the MMU_ routines compiled callers use, the
variables M68020 and MMU_$SYSTEM_REV, and the hardware pages MMU and
PFT, each from its compiled callers' pushes or reads.  The hand-written
bodies agree with each heading (the `.s` files' stack offsets).  Other
MMU_ routines get their headings in `mmu.ins.pas` from their first
compiled caller's pushes, when that caller is translated (as for ML_:
ml/README.md).  The word-slot pairs of MMU_$INSTALL and
MMU_$INSTALL_PRIVATE (asid and protection in the low bytes of two word
slots, read as one longword) are noted in `mmu.ins.pas`.

## Open items

The SAU4 and SAU6..SAU9 headings: MMU_$REMOVE takes a virtual address
and a word there (the SAU9's reads only the address), where
`mmu.ins.pas` has the SAU2's page-number form; WIN_SCSI_, ETHERNET and
MST_UNWIRED declare the large-VM headings themselves (their TODOs).  A
`large_vm` arm in `mmu.ins.pas` waits for the one-argument callers'
SAU9 forms (about fifteen fragments of other subsystems compile for the
SAU9 with the SAU2 call today).

mmu_$installi is register-called (D2, A4, D4); `m68k/installi.s` and
`m68k/install.s` carry its TODO.
