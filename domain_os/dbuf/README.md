# The DBUF subsystem in Domain Pascal

The disk buffer cache.

## Layout

One module, `dbuf.pas`, `module dbuf;` (the map segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | DBUF, 0x770 bytes | DBUF_$GET_BLOCK, DBUF_$SET_BUFF (and its two cells), DBUF_$INVALIDATE, DBUF_$UPDATE_VOL, DBUF_$INIT | none |

Data: the map's DBUF data segment in .DATA, 0x920 bytes, all zero in the image, the
module's variables in `dbuf.pas`, with the map symbols DBUF (+0x10, the
entry array) and DBUF_$TROUBLE (+0x91C) `define`d among them:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `dbuf_$eventcount` | ec_$eventcount_t |
| +0x00C | `unused_0c` | integer32, never addressed (TODO) |
| +0x010 | `dbuf` (DBUF) | array[1..64] of dbuf_$entry_t, defined |
| +0x910 | `dbuf_spin_lock` | integer32 |
| +0x914 | `dbuf_$head` | dbuf_$entry_ptr_t |
| +0x918 | `dbuf_$waiters` | integer |
| +0x91A | `dbuf_$count` | integer |
| +0x91C | `dbuf_$trouble` (DBUF_$TROUBLE) | set of 0..15, defined |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| DBUF_$GET_BLOCK | `get_block.pas` |
| DBUF_$SET_BUFF | `set_buff.pas` (and its two constant cells) |
| DBUF_$INVALIDATE | `invalidate.pas` |
| DBUF_$UPDATE_VOL | `update_vol.pas` |
| DBUF_$INIT | `init.pas` |
| (data) | the module's variables in `dbuf.pas`; the status cells are constants (`dbuf.ins.pas`) |

All five routines are global (map symbols); none is nested and there is
no module-local routine.  DBUF_$GET_BLOCK's control is the structured
reading: the settle is the end of an `if ... else`, the search
the head of a `repeat ... until dbuf_$waiters <> 0`, retry the label of
the outer `repeat ... until false`; only `goto wait` (from the two lookup
loops) and the wait's `goto retry` remain.  The emitter's four-label
reading gives the same instructions.  Nothing in the image is a routine for
an entry's address or for filling the write header: those are inline in the
routines.

`dbuf.ins.pas` (from FM's translation, the headings of GET_BLOCK and
SET_BUFF kept as reviewed) now also has the flag constants, the status
cells' values, the entry (`e_` fields; its flags word a packed variant
record), the identity record (a variant: UID and hint, or 12 bytes), the
disk header, DBUF, DBUF_$TROUBLE and DBUF_BLKS, and the headings of
DBUF_$INVALIDATE and DBUF_$UPDATE_VOL (`val_param`) and DBUF_$INIT.

Changes to shared insert files:
- `disk/disk.ins.pas`: status_$storage_module_stopped, disk_$info_t,
  DISK_$WRITE and DISK_$READ (`val_param`, the header `univ`).
- `mmu/mmu.ins.pas`: MMU_$CACHE_INHIBIT_VA (hand assembly, `val_param`).

No conformance unit of `../domain-pascal/tests/conformance/` translates
a DBUF routine.  Two declare DBUF headings for their calls:
- `disk_get_block.pas` (DISK_$GET_BLOCK): `var uid`, `var status` and
  `val_param` for DBUF_$GET_BLOCK, where `dbuf.ins.pas` has `in uid` and
  `out status` (the reviewed heading): the same pushes, the same callee
  code.
- `cal_shutdown.pas` (CAL_$SHUTDOWN): DBUF_$SET_BUFF's first parameter
  `var buf: label_t` (by address, the label record), where
  `dbuf.ins.pas` has `buffer: univ_ptr` by value under `val_param`; the
  callee code is the same (the slot loaded and compared with e_data), the
  callers' pushes too.  Both units' DBUF_$GET_BLOCK results are pointer
  types of their own (univ_ptr, label_ptr), the tree's univ_ptr.

## Open items

DBUF is indexed from 1: the image's loops and the list's end read it
so.  The entry's flags byte and type byte are one packed word here, its
busy/dirty/volume bits fields.

### TODO(pascal)

- `dbuf.pas`: the entry array at +0x10, 4 bytes after the eventcount
  (stand-in `unused_0c`).
- `get_block.pas`: the result variable between e and token in the
  frame; busy and dirty tested through the flags word, and the volume
  stored unmasked.
