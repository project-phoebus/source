# The MEM subsystem in Domain Pascal

The memory parity-error statistics: the errors counted by memory board
and by page, and on the SAU9 the count of the boards.  On the SAU4
(`ecc_memory`, without `memory_parity`) the memory boards correct their
errors: MEM_$INIT finds their controllers and MEM_$ECCC_LOG logs and
counts the corrected errors instead; on the SAU6 (`ecc6_memory`) the
boards' own registers, MEM_$INIT and MEM_$ECCC6_LOG.

## Layout

One module, `mem.pas`, `module mem_, wired_proc, wired_data;` (the map
segments' name):

| section | code size | routines | attribute |
|---------|-----------|----------|-----------|
| WIRED_PROC | 0xB8 (SAU9 0x104, SAU8 0x250, SAU4 0x214, SAU6 0x198) | MEM_$INIT (SAU9, SAU8, SAU6, SAU4), MEM_$ECCC_LOG (SAU4), MEM_$ECCC6_LOG (SAU6), MEM_$PARITY_LOG (not the SAU4's; on the SAU2 0xB6 of code, then the module-end filler) | none (the heading's) |

Data: the map's MEM_ data segment in WIRED_DATA (0x5C bytes), two map
symbols, both `define`d variables of the module (ref 7.2.2, Method 2;
extern in `mem.ins.pas`):

| offset | variable | type | notes |
|--------|----------|------|-------|
| +0x00 | `mem_$size` (MEM_$SIZE) | integer32 | the memory's size in bytes, which the SAU9's MEM_$INIT reads; never addressed in the SAU2 image |
| +0x04 | `mem_$mem_rec` (MEM_$MEM_REC) | mem_$mem_rec_t, 0x56 bytes | initialized `[w_00 := 2, n_boards := 2]` (the SAU9's w_00 16#2B), the image's bytes; ASKNODE_$INTERNET_INFO copies it whole |
| +0x5A | (2 bytes) | | the block rounded to a longword, not an object |

With `ecc_memory` (the SAU4's 0x64 bytes) the module's own
`mem_board_slot` (4 words, each board's controller slot) comes first,
MEM_$SIZE at +0x08 and MEM_$MEM_REC at +0x0C (`[w_00 := 1]`).

The MEM_LITES code and data segments are another module, not part of
this subsystem.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MEM_$INIT | `init.pas` (SAU9 and SAU8, under `mem_ccr_board_size` and `mem_board_jumpers`) |
| MEM_$ECCC_LOG | `eccc_log.pas` (SAU4, `ecc_memory`; a `goto` to the controller's write after the board loop) |
| MEM_$ECCC6_LOG | `eccc6_log.pas` (SAU6, `ecc6_memory`; a boolean function, its result ignored by the ECC trap) |
| MEM_$PARITY_LOG | `parity_log.pas` (two `for` loops, `exit` and `return`; no nested or module-local routine) |
| (data) | the define statement of `mem.pas` |

`mem.ins.pas`: `mem_$byte_t`; `mem_$phys_addr_t`, the physical address
as a 4-byte record of two variants (the linteger, compared unsigned, and
its bytes: the SAU2's routine reads bits 21..16 as `byte_1 & 16#3F`);
`mem_$page_error_t` (18 bytes); `mem_$mem_rec_t` (0x56 bytes); the two
extern variables; the headings `procedure mem_$init; extern` and
`procedure mem_$parity_log(phys_addr: mem_$phys_addr_t);
options(extern, val_param)` (the caller pushes the longword; ref 5.5.7
passes the 4-byte record by value).  The packed-record reading (a 6-bit
field) was rejected: its longword variant could not be both 32 bits and
unsigned (ref Table 3-3).

`mmu/mmu.ins.pas`: MMU_CCR (`mmu_ccr`, the SAU9's MMU control
register), whose bit 3 gives the board size.

## The other SAUs' forms

The part (`base/config.ins.pas`) that changes MEM_ is
`mem_ccr_board_size` (SAU9):

- MEM_$INIT sets MEM_$MEM_REC's board count: MEM_$SIZE in MB divided by
  the board size, 4 MB when MMU_CCR's bit 3 is set, else 16 MB, rounded
  up (`init.pas`).  OS_$INIT calls it.
- MEM_$PARITY_LOG counts an error against board `address in MB div
  board size` from 0, and a page record matches the whole address, not
  bits 21..16 (`parity_log.pas`).
- MEM_$MEM_REC's first word is 16#2B.

`mem_board_jumpers` (SAU8; WIRED_PROC 0x250 bytes):

- MEM_$INIT sets the board count, 1 to 4, by a `case` on the memory
  configuration, bits 16#74 of the SIO DUART's input port (SIO, the
  2681's IPR; `init.pas`).
- MEM_$PARITY_LOG takes the board by a `case` on the same bits, each
  arm's limits on the address's MB above the first, and a page record
  matches the address's low 24 bits (`mem_$addr_bits_t`,
  `parity_log.pas`).
- MEM_$MEM_REC's second word is 0 (MEM_$INIT sets it).

`mem_jumpers_16mb` (SAU7, with `mem_board_jumpers`; WIRED_PROC 0x2AC
bytes): MEM_$INIT is the SAU8's; MEM_$PARITY_LOG takes the MB above 16
MB, its limits are four times the SAU8's, on a board with the physical
cache (ROADRUNNER) it takes the board from the configuration's halves
and address bit 2, and a page record matches the address's low 26 bits
(`mem_$addr_bits26_t`); MEM_$MEM_REC's first word is 16#2A, its second
0.

## The SAU6

With `ecc6_memory` each memory board has a 128-byte page of MEM with
its error registers: the status (+0), the control word (+2: bits 1..0
the reporting, 3 on and 2 quiet), the error address (+4) and a word at
+8.  MEM_$INIT probes the boards' pages from the first, up to two,
counts those that answer, adds 1 (the first) or 2 (the second) to
FIM_WIRED's MCSR_CONFIG, and turns each counted board's reporting on.
MEM_$ECCC6_LOG, called by FIM_WIRED's hand-written ECC handler with
the board, the word at +8, the error address and the status, logs the
four (type 7, 12 bytes), counts the error against the board, quiets the
board after 2000 and returns false then, and counts it against the
record of its page: the error address's bits 25..1 and the board, else
a free record or the one with the lowest count.  The SAU6's page
records hold the four registers' values (`mem_$page_error_t`'s
`ecc6_memory` form).  MEM_$MEM_REC's first word is 3, its second 0; no
MEM_$PARITY_LOG (no `memory_parity`).

## Open items

### Form and layout

- board_errors is `array[0..4]` from rec+4 on every SAU: the SAU9
  counts board 0 there, the SAU2 boards 1 and 2 (rec+6, rec+8); the
  upper bound 4 fills the record to page_errors, which the image does
  not settle.  ASKNODE_$INTERNET_INFO overwrites
  element 0 in its copy of the record with MMAP_$REAL_PAGES or 0.
- The 2 bytes at +0x5A of the block: read as the data block's rounding
  to a longword, not an object (0x5A rounded up to 4 is the map's 0x5C).

### TODO(pascal)

- `eccc_log.pas`: 4 frame bytes of the SAU4's frame unaccounted for (no
  stand-in).
