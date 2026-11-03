# The CBUF subsystem in Domain Pascal

The circular buffer manager: a caller's array used as a ring of
variable-length blocks, written at one end and read and released at
the other.  The line printer driver (`../lpr/`) is its user.  Present
with `circular_buffers` (`../base/config.ins.pas`: the SAU3 and SAU4,
the same code); the other SR10.2 maps have no CBUF module, and there the
module is empty.

## Layout

One module, `cbuf.pas`, `module cbuf;` (the map segment's name):

| section | SAU3 segment | SAU4 segment | routines | attribute |
|---------|--------------|--------------|----------|-----------|
| .TEXT (default) | CBUF, 0x2E8 bytes | CBUF, 0x2E8 bytes | CBUF_$INIT_CB, CBUF_$ALLOCATE, CBUF_$MAKE_VISIBLE, CBUF_$READ_NEXT, CBUF_$RELEASE | none |
| .DATA (default) | CBUF data, 4 bytes | CBUF data, 4 bytes | cbuf_lock, the spin lock | module variable |

A buffer's control block (`cbuf_$cb_t`, 0x1C bytes) is the caller's:
LPR's is LPR_$BCB.  No routine is nested or module-local.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| CBUF_$INIT_CB | `init_cb.pas` |
| CBUF_$ALLOCATE | `allocate.pas` |
| CBUF_$MAKE_VISIBLE | `make_visible.pas` |
| CBUF_$READ_NEXT | `read_next.pas` |
| CBUF_$RELEASE | `release.pas` |

`cbuf.ins.pas` holds the statuses, the control block and the headings.

## Open items

None.  No TODO, no dpc gap.
