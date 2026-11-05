# The TPAD subsystem in Domain Pascal

The touchpad/tablet locator.

## Layout

One module, `tpad.pas` (map module name `TPAD`), headed `module tpad;`:

| section        | code size | routines |
|----------------|-----------|----------|
| OS_INIT_PROC   | 0xFC      | TPAD_$INIT (0xFA of code and a constant cell, the constant 1) |
| .TEXT          | 0x9C0     | TPAD_$DATA .. TPAD_$INQ_PUNCH_IMPACT |

Data: the map's TPAD data segment (0x180 bytes) in the default .DATA
section, between SIO's and ROUTE_UNWIRED's blocks; no map symbol inside
it, and no TPAD block in any other data section.  It holds module
variables, not statics (most objects are used by several routines, in
both code sections): the eight 0x2C-byte unit records
`tpad_$unit_configs` (+0x000, initialized in the image), then the
scalars `tpad_$cursor` (an `smd_$pos_t`, +0x160), `tpad_$last_clock`
.. `tpad_$re_origin_flag` (+0x164 .. +0x17E, zero).  Since the code and
data are in the default sections, the heading names none; TPAD_$INIT is
headed `[section(os_init_proc, os_init_data)]` and reaches the block by
its absolute address.  `tpad.pas`'s header has the details.

### The SAU4

The SAU4's TPAD is the same source.  The module is compiled with `-cpu
460` (the Makefile's CPU460_MODULES): TPAD_$DATA's six longword
multiplies are the DN460's extended instructions where the other SAUs
call M$MIS$LLW and M$MIS$LLL, so its .TEXT segment is 0x994 bytes.  The
data segment's bytes are the SAU2's and SAU5's.

### The SAU7

The SAU7's TPAD is the same source, and its code and data are the
SAU9's (.TEXT 0x998 bytes, OS_INIT_PROC 0xFC, data 0x180), the same
instructions at other addresses.

## Routines and their fragments

| routine                   | fragment |
|---------------------------|----------|
| TPAD_$INIT                | `init.pas` |
| TPAD_$DATA                | `data.pas` (0x602 bytes; one routine: no nested or module-local routine) |
| TPAD_$SET_MODE | `set_mode.pas` |
| TPAD_$SET_UNIT_MODE | `set_unit_mode.pas` |
| TPAD_$SET_CURSOR | `set_cursor.pas` |
| TPAD_$SET_UNIT_CURSOR | `set_unit_cursor.pas` |
| TPAD_$INQUIRE | `inquire.pas` |
| TPAD_$INQUIRE_UNIT | `inquire_unit.pas` |
| TPAD_$SET_UNIT            | `set_unit.pas` |
| TPAD_$RE_RANGE | `re_range.pas` |
| TPAD_$RE_RANGE_UNIT | `re_range_unit.pas` |
| TPAD_$INQ_DTYPE           | `inq_dtype.pas` |
| TPAD_$SET_PUNCH_IMPACT | `set_punch_impact.pas` |
| TPAD_$INQ_PUNCH_IMPACT | `inq_punch_impact.pas` |
| (data)                    | the `var` part of `tpad.pas` |

Every routine is global (a map symbol) and takes its arguments by
address (the default convention).  Each plain routine is a wrapper of
the `_UNIT` one after it: it passes `tpad_$unit` and its own slots on
(a forward call) with a status local it drops.  TPAD_$SET_PUNCH_IMPACT
and TPAD_$INQ_DTYPE are functions.  The foreign headings are in
`smd/smd.ins.pas` (SMD_$N_DEVICES, SMD_$INQ_DISP_INFO, SMD_$LOC_EVENT,
`smd_$pos_t`, `smd_$display_type_t`, `smd_disp_info_result_t`,
`smd_$illegal_unit`) and `time/time.ins.pas` (TIME_$CLOCK).

## Open items

The unit records' initial values: the image's .DATA block starts each
of the eight records with x_scale and y_scale 99, x_range and y_range
16#200, x_min and y_min 16#100, x_max_disp and y_max_disp 99 and
hysteresis 5 (`tpad.pas`).  These are file bytes of the RFC image, and
nothing at boot rewrites them before TPAD_$INIT: COLD_START maps the
loaded pages without copying or zeroing .DATA, and nothing else in the
image addresses the block.  So the original's records hold these values
from load time, and the Pascal initializes them.

Names, types, layout:

- Mode 2 is Apollo's `tpad_$rel_abs`; the status for a bad unit is
  Apollo's `smd_$illegal_unit`.
- The unit 1 TPAD_$INIT passes is a constant cell after its code.
- The scalars at +0x160 are separate module variables; the cursor's
  line and column are one `smd_$pos_t` (moved and pushed as one
  longword), as are the record's cursor_offset fields.
- SMD_$LOC_EVENT is a procedure here (no caller reads D0).
- `tpad_$data_packet_t` and `suma_sample_t` are one object (TERM's queue
  entry) with two types (TODO 1).

### TODO(pascal)

1. `tpad.ins.pas`: TERM_$ENQUEUE_TPAD passes a `suma_sample_t` to
   TPAD_$DATA's `tpad_$data_packet_t` formal; when OS_TERM_INIT is
   translated, the call needs this formal `univ` or one (variant) type
   for both readings.
2. `tpad.ins.pas`: `unused_2a`, the record's last two bytes, which
   nothing addresses (or natural record rounding).
3. All the routines that reach a unit record (`set_unit_mode.pas`,
   `set_unit_cursor.pas`, `inquire_unit.pas`, `re_range_unit.pas`,
   `set_punch_impact.pas`, `inq_punch_impact.pas`, `data.pas`,
   `init.pas`): 4 frame bytes no object explains, held by
   the stand-ins `unused_4` (the five `_UNIT` routines and
   TPAD_$SET_PUNCH_IMPACT), `unused_18` (TPAD_$DATA) and `unused_1c`
   (TPAD_$INIT).  A lead reads them as the `with` temporary's slot, not
   established outside TPAD; the stand-ins go if it is.
4. `init.pas`: the 6 frame bytes at the top (stand-ins `unused_4`,
   `unused_6`); the loop guard formed as a boolean and tested.
5. `data.pas`: which locals the source declared (ten and the stand-in,
   or twelve with two raw mouse deltas, which the operand order does
   not favor); `abs`'s compares and zero extensions;
   values computed apart and moved into register locals; the clamp's
   second read of the column; the signed index for `tpad_$unit`
   against the unsigned one for `unitp`.
6. Every unit check is read as a plain `or`/`and` with the call on the
   right; the operand order of `unitp > smd_$n_devices` is not seen.
