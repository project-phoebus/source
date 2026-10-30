# The FM subsystem in Domain Pascal

The file map's two routines, FM_$READ and FM_$WRITE.

## Layout

No module of its own.  The map has no FM segment: both routines are the
last two of the VTOC_ code segment (0x2364 bytes, .TEXT, after
VTOCE_$TRUNCATE), the VTOC_ module, whose data segment (0x688 bytes,
.DATA; OS_DISK_DATA, VTOC_CACH_HITS, VTOC_CACH_LOOKUPS) they reach
through A5.  VTOC_'s module file, `../vtoc/vtoc.pas`, includes the two
fragments last, in this order, and checks them in place.

| routine | size | section | fragment |
|---------|------|---------|----------|
| FM_$READ | 0x148 | .TEXT | `read.pas`: no attribute (the default section; VTOC_'s heading names none) |
| FM_$WRITE | 0x152 and the filler | .TEXT | `write.pas`: the same |

Both are global, `options(val_param)`: the block address (a 4-byte
packed record), the level (pinteger) and FM_$WRITE's write_now
(boolean) by value, the rest by address.  No nested or module-local
routine.  The fragments test three per-volume flag arrays of VTOC_'s
block (1-based arrays of booleans at +0x270, +0x278 and +0x280,
`vtoc_$cach_wp_flag`, `vtoc_$mounted`, `vtoc_$format`; vtoc_$format has
6 elements, the volume records' count; ../vtoc/README.md).
`fm_$entry_t` is indexed from 0 and `fm_$block_addr_t` has a
whole-longword variant `all` (VTOC_'s evidence, fm.ins.pas); read.pas's
zero fill runs over 0..31 accordingly.

## Insert files

- `fm.ins.pas`: the lock (16) and the release operations (8, 9, 11);
  `fm_$entry_t` (32 longwords); `fm_$block_addr_t`, a packed record of
  the 28-bit block number and the 4-bit entry index (the image reads
  the fields in the compiler's two forms for packed fields, which dpc
  reproduces); `fm_$file_ref_t` (a partial layout); the two headings.
- `vtoc/vtoc.ins.pas`: status_$vtoc_not_mounted; the file-map views of
  the two VTOCE formats and VTOC blocks; `fm_$buffer_t`, a buffer as the
  three views; `vtoc_$uid` (extern, map symbol).
- `dbuf/dbuf.ins.pas`: DBUF_$GET_BLOCK (a `val_param` function
  returning the buffer's address) and DBUF_$SET_BUFF, from their
  prologues and FM's pushes.
- `ml/ml.ins.pas`: ML_$LOCK and ML_$UNLOCK.

## Open items

### Source forms

- The exits to the unlock are the ends of an `if ... else if ... else`
  chain (each branch of the image lands on the unlock).
- FM_$WRITE has a record assignment in each part (the image has no slot
  for a pointer, and one part's copy is its own loop).  FM_$READ's `src`
  is a real local (its slot is in the frame, and one copy follows the
  chain).
- A VTOCE's direct addresses are reached as the field of the entry of
  the block: the blocks' header (8 and 4 bytes) plus the direct
  addresses' offset in a VTOCE (0xD0, 0x40): 0xD8 for the new format,
  0x44 for the old, from the block.
