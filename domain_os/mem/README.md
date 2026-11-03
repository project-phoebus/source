# The MEM subsystem in Domain Pascal

The memory parity-error statistics: the errors counted by memory board
and by page, and on the SAU9 the count of the boards.

## Layout

One module, `mem.pas`, `module mem_, wired_proc, wired_data;` (the map
segments' name):

| section | code size | routines | attribute |
|---------|-----------|----------|-----------|
| WIRED_PROC | 0xB8 (SAU9 0x104, SAU8 0x250) | MEM_$INIT (SAU9), MEM_$PARITY_LOG (on the SAU2 0xB6 of code, then the module-end filler) | none (the heading's) |

Data: the map's MEM_ data segment in WIRED_DATA (0x5C bytes), two map
symbols, both `define`d variables of the module (ref 7.2.2, Method 2;
extern in `mem.ins.pas`):

| offset | variable | type | notes |
|--------|----------|------|-------|
| +0x00 | `mem_$size` (MEM_$SIZE) | integer32 | the memory's size in bytes, which the SAU9's MEM_$INIT reads; never addressed in the SAU2 image |
| +0x04 | `mem_$mem_rec` (MEM_$MEM_REC) | mem_$mem_rec_t, 0x56 bytes | initialized `[w_00 := 2, n_boards := 2]` (the SAU9's w_00 16#2B), the image's bytes; ASKNODE_$INTERNET_INFO copies it whole |
| +0x5A | (2 bytes) | | the block rounded to a longword, not an object |

The MEM_LITES code and data segments are another module, not part of
this subsystem.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MEM_$INIT | `init.pas` (SAU9 and SAU8, under `mem_ccr_board_size` and `mem_board_jumpers`) |
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

The SAU4, SAU6 and SAU7 have MEM_ code of their own, not expressed (the
SAU7's is the SAU8's with ROADRUNNER arms, 4 MB limits and a 26-bit
page match).

## Open items

### Form and layout

- board_errors is `array[0..4]` from rec+4 on every SAU: the SAU9
  counts board 0 there, the SAU2 boards 1 and 2 (rec+6, rec+8); the
  upper bound 4 fills the record to page_errors, which the image does
  not settle.  ASKNODE_$INTERNET_INFO overwrites
  element 0 in its copy of the record with MMAP_$REAL_PAGES or 0.
- The 2 bytes at +0x5A of the block: read as the data block's rounding
  to a longword, not an object (0x5A rounded up to 4 is the map's 0x5C).
