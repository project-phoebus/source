# The PCHIST subsystem in Domain Pascal

The PC histogram profiler (the system histogram and UNIX profil()).

## Layout

One module, `pchist.pas`, `module pchist, , wired_data;` (the map
segments' name; the default code section, WIRED_DATA as the data
section):

| section | code size | routines | attribute |
|---------|-----------|----------|-----------|
| WIRED_PROC | 0xD8 | PCHIST_$COUNT, PCHIST_$INTERRUPT | `[section(wired_proc, wired_data)]` |
| OS_INIT_PROC | 0x14 | PCHIST_$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | 0x650 | pchist_$enable_terminal, PCHIST_$UNIX_PROFIL_CNTL, _$UNIX_PROFIL_FORK, PCHIST_$CNTL (with pchist_$unwire_cleanup and pchist_$stop_profiling nested), PCHIST_$UNIX_PROFIL_ADDUPC | none (the heading's) |

Data:

- The map's PCHIST data segment in WIRED_DATA (0x128 bytes), the
  module's own block, through A5 in WIRED_PROC and in .TEXT
  (the .TEXT routines' data section is WIRED_DATA), absolute from
  PCHIST_$INIT:

  | offset | variable | type |
  |--------|----------|------|
  | +0x000 | `pchist_$lock` | ml_$exclusion_t (0x12) |
  | +0x012 | `unused_12` (stand-in, 6 bytes) | |
  | +0x018 | `pchist_$proc_bitmap` | packed array[1..64] of boolean |
  | +0x020 | PCHIST_$ADDR (defined) | array[1..64] of linteger |
  | +0x120 | `pchist_$sys_profiling_count` | integer |
  | +0x122 | `pchist_$proc_profiling_count` | integer |
  | +0x124 | `pchist_$histogram_enabled` | boolean |
  | +0x126 | PCHIST_$DOALIGN (defined) | boolean |

- PCHIST_UNWIRED_D (0x938 bytes), a load section with no module
  segment: an overlay section, `var (pchist_unwired_d)`,
  reached only by absolute address:

  | offset | variable | type |
  |--------|----------|------|
  | +0x000 | `pchist_$proc_data` | array[1..64] of pchist_$proc_t (0x14) |
  | +0x500 | `pchist_$wire_pages` | array[1..3] of integer32 |
  | +0x50C | `pchist_$histogram` | pchist_$histogram_t (0x42A) |
  | +0x936 | `pchist_$wired_count` | integer |

Every map symbol is a global.  pchist_$enable_terminal has
no map symbol and several callers: a top-level `internal` routine.
pchist_$unwire_cleanup (its link passed in A1: its sibling calls it)
and pchist_$stop_profiling (the dynamic link) are nested in
PCHIST_$CNTL.  None is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| PCHIST_$COUNT | `count.pas` |
| PCHIST_$INTERRUPT | `interrupt.pas` |
| PCHIST_$INIT | `init.pas` |
| pchist_$enable_terminal | `enable_terminal.pas` |
| PCHIST_$UNIX_PROFIL_CNTL | `unix_profil_cntl.pas` |
| PCHIST_$UNIX_PROFIL_FORK | `unix_profil_fork.pas` |
| pchist_$unwire_cleanup | `cntl.pas` (nested) |
| pchist_$stop_profiling | `cntl.pas` (nested) |
| PCHIST_$CNTL | `cntl.pas` |
| PCHIST_$UNIX_PROFIL_ADDUPC | `unix_profil_addupc.pas` |
| (data) | the blocks in `pchist.pas` |

## Insert files

- `pchist.ins.pas` (begun by SIO2681 with PCHIST_$INTERRUPT): the range
  and histogram records, the headings of the seven globals.
  `sio2681/sio2681.pas` still checks.
- `fim/fim.ins.pas`: FIM_$POP_SIGNAL, FIM_$DELIVER_TRACE_FAULT (hand
  assembly, headings from the calls).
- `proc2/proc2.ins.pas`: PROC2_$UPID_TO_UID.
- `term/term.ins.pas`: TERM_$PCHIST_ENABLE.
- Used as they are: ml, mst (MST_$WIRE_AREA), wp (WP_$UNWIRE), proc1,
  proc2 (PROC2_$GET_PID, _$SET_CLEANUP), term (TERM_$WRITE).

## Open items

The histogram record: the process filter is at +0x04 and the shift at
+0x08 (PCHIST_$CNTL stores them there, PCHIST_$COUNT reads them there);
+0x0A is never addressed.  The record is 0x42A bytes, which PCHIST_$CNTL
copies to its caller whole (0x10A longwords and a word), twice.

Layout facts:
- pchist_$proc_data is 1-based at the overlay section's start; the wire
  pages are 1-based at +0x500.
- PCHIST_$ADDR is a map symbol at +0x20 of the WIRED_DATA block,
  1-based; the 6 bytes after the 0x12-byte lock are not addressed.
- The bitmap is a packed array of booleans' layout (ref 3.11.4.2).
- pchist_$stop_profiling and pchist_$unwire_cleanup reach PCHIST_$CNTL's
  frame (cmd_ptr, i); none of the three module-local routines is a map
  symbol.
- The histogram's `doalign` at +0x02 is a boolean byte.
- PCHIST_$UNIX_PROFIL_ADDUPC masks the low part of pc - offset to 15
  bits (16#7FFF), as the image has it.

### TODO(pascal)

None.

## Named dispatch codes

pchist/pchist.ins.pas names PCHIST_$CNTL's commands (`pchist_$cntl_*`)
and PCHIST_$UNIX_PROFIL_CNTL's (`pchist_$profil_*`).
proc2/cleanup_handlers_internal passes
`pchist_$profil_disable`.
