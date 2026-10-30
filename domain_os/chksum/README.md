# The CHKSUM subsystem in Domain Pascal

CHKSUM_$GET_CHKSUM, the page checksum, is **hand-written assembly** in
the SR10.2 SAU2 image, transcribed in `m68k/get_chksum.s`, so this
subsystem has no Pascal: no module file, no fragments. Its insert file,
`chksum.ins.pas`, holds the heading of the compiled CHKSUM module's
routine (below), which DISK_IO calls, and CHKSUM_$GET_CHKSUM's own
heading, for that routine.

## Layout

| segment | size, section | symbols | what |
|---------|---------------|---------|------|
| CHKSUM_ASM (code) | 0x14, WIRED_PROC | CHKSUM_$GET_CHKSUM | hand assembly: this subsystem |
| CHKSUM (code) | 0x84, WIRED_PROC (the SAU9's 0x50) | CHKSUM (no `$`; a map symbol, so a global) | compiled, not this subsystem's: its Pascal is `disk/chksum_page.pas` in the module file `disk/chksum.pas` |

No data segment.

## Why it is hand assembly

The signs of hand assembly (`m68k/get_chksum.s` has the listing):
- **Location.** The segment's name ends in `_ASM`.
- **No frame.** No `link`/`unlk`, no register save; the argument is
  read off the stack.
- **Encodings.** The `dbf` count is loaded with a word move of an
  immediate, where compiled code uses `moveq`.
- **Padding.** It ends with its return and no filler (the segment is
  exactly 0x14 bytes; the next segment, DMA_, follows at once), where
  the compiled CHKSUM segment before it ends with the module filler.

## For a Pascal caller

The one caller is the compiled CHKSUM module's routine (disk/
chksum_page.pas, in disk/chksum.pas), which pushes the page's address
by value, pops it after the call, and reads the word result in D0.  The
heading, in `chksum/chksum.ins.pas` beside CHKSUM's: `function
chksum_$get_chksum(va: univ_ptr): pinteger; options(extern, val_param)`
(the sum is modulo 2^16).  It was first written in disk/chksum.pas
under a TODO(merge) and moved here.
