# The SMD subsystem in Domain Pascal

The screen manager's display driver (the display units and their
association with processes, the hidden display memory and fonts, the
cursors and tracking rectangles, the locator and keyboard event queue,
the DM request ring, the BLT and scroll entries, the blink and blank
timers).

## Layout

The SAU2 map gives smd/'s code five map modules.  Only SMD is compiled
Pascal throughout:

| map module | segments | what | module file |
|------------|----------|------|-------------|
| SMD_WIRED | code in WIRED_PROC (0x1FC bytes); code and data in WIRED_DATA (0x5E0) | hand assembly: the cursor XOR/OR body and trampolines, the scroll and BLT bodies and trampolines, SMD_$LOCK_DISPLAY, SMD_$BIT_SET, SMD_$DISP1_INT, SMD_$BLINK_CURSOR_1/_CURSOR, SMD_$INTERRUPT_INIT; the data SMD_$CURSOR_TABLE, _$CURSOR_PTABLE, _$DISPLAY_COM, SMD_TIME_$COM, MNK_$KTT_PTRS, MNK_$KTT_MAX, SMD_$KTT, MATROX_$BOARD_INSTALLED | none: `sau2/*.s`; the data are `extern` in the insert files |
| SMD | code in WIRED_PROC (0x18C), OS_INIT_PROC (0x1D8), .TEXT (0x2BF4), PROCEDURE$ (0x5C), PROC2_DELETE_PRO (0x6C); data in .DATA (0x1DA8), WIRED_DATA (0x1C), OS_INIT_DATA (4), DATA$ (4) | the compiled driver, 89 routines | `smd.pas` |
| (overlay) | SMD_$WIRED_DATA, 0x13C bytes (a data section of its own, no module segment in it) | the overlay section SMD_$WIRED_DATA | `var (smd_$wired_data)` in the insert file |
| SMD_UTILS | code in .TEXT (0x508); .DATA (0x54C: the entries SMD_$COPY_FONT_TO_HDM, _$WRITE_STR_CLIP, _$CLEAR_WINDOW, _$HORIZ_LINE, _$VERT_LINE as stubs that pass the segment's base and jump to the bodies, a table of address cells, and the national keyboard tables SMD_$GERMAN_KTT .. SMD_$SWISS_KTT) | hand assembly (below) | none: `sau2/smd_utils.s` |
| GPU, DISP_LITES | other subsystems' (`gpu/`; `misc/m68k/disp_lites.s`) | | (theirs) |

### The SAU5

The SAU5's map has the same five modules, with other sizes: SMD_WIRED
code 0x69C and data 0x7C8 (SMD_$DISP2_INT, SMD_$BLINK_CURSOR_2,
SMD_$GRAPHIC_DEVICE_ID, COLOR3_$CR_CONTENTS besides the SAU2's
symbols), SMD in WIRED_PROC 0x310, OS_INIT_PROC 0x3B8, .TEXT 0x2EBC,
PROCEDURE$ 0x5C, PROC2_DELETE_PRO 0x8C, data .DATA 0x1E58 (the others
the SAU2's sizes), the overlay SMD_$WIRED_DATA 0x250, SMD_UTILS code
0x4C0 and data 0x5C8 (SMD_$GET_DTYPE besides the SAU2's).  The compiled
SMD module has the SAU2's routines in the SAU2's order; its SAU5 forms
are conditional arms inside the same fragments (base/config.ins.pas:
`two_display_units`, `color_displays`, `blt_request_start`, and the
reused `color_board` and `gpu_driver`):

- the data (`two_display_units`): two unit records of 0x110 bytes, two
  display records, unit 1's second font table and free list in the
  .DATA block, two blink routines (smd.pas, smd_internal.ins.pas);
- SMD_$INIT: the graphics board's probe and its two color displays, unit
  2's record, SMD_$GET_DTYPE for a controller that answers, the color
  board's probe for unit 2, the color types' limits;
- smd_$validate_unit, SMD_$N_DEVICES, SMD_$DM_COND_EVENT_WAIT,
  SMD_$FREE_ASID: two units; SMD_$ASSOC, SMD_$RETURN_DISPLAY: the other
  unit; SMD_$INQ_DISP_INFO: unit 1's answer from unit 2;
- smd_$reset_unit_display, SMD_$LOAD_CRSR_BITMAP: the cursors to the
  color boards; smd_$init_display_state, SMD_$VIDEO_CTL, SMD_$FREE_ASID,
  SMD_$RETURN_DISPLAY: the boards' drivers for the color types;
  SMD_$ALLOC_HDM, SMD_$FREE_HDM, SMD_$COPY_FONT_TO_MD_HDM: the color
  types' hidden memory;
- SMD_$WS_INIT, SMD_$UTIL_INIT, SMD_$INVERT_S, SMD_$BLT,
  SMD_$SOFT_SCROLL, SMD_$EOF_WAIT: smd_$not_on_color for the color types
  (`color_displays`);
- SMD_$BLT: the request passed to SMD_$START_BLT (`blt_request_start`).

The other routines are the SAU2's source; their SAU5 code differs only
by the data layout, the constant cells' places and register choice.
SMD_WIRED and SMD_UTILS are hand
assembly and other code on the SAU5.  SMD_WIRED is `sau5/*.s` and
three shared files, the SAU2's files' division with one difference: the
code segment is one file, `sau5/wired_proc.s` (the cursor body, which
drives the color displays too, and the scroll and BLT bodies), around
the SAU2's SMD_$LOCK_DISPLAY and SMD_$BIT_SET (`m68k/lock_display.s`,
`m68k/bit_set.s`), so its bodies stay in the code segment in the map's
order.  The data (`m68k/wired_data.s`) is the SAU2's with two `.if`
arms (`gpu_driver`, `two_display_units`).  The bodies reach the data
segment's cells at fixed displacements from its base, SMD_$DISP2_INT, so
the data segment's sections (`sau5/disp1_int.s` .. `m68k/wired_data.s`)
must be laid out
contiguously in the map's order.  The data segment's code reads the
SAU5 map's I/O names (DISP1, DISP2, DISP1_MEM, DISP2_MEM,
DISP_MEM_2KX1K, KOLOR_CTL, COLOR_SUP) as absolute symbols.  Every byte
is the SAU5 image's (assembled and linked at the image's addresses).
SMD_UTILS is `sau5/smd_utils.s`, the SAU2 file's shape: the drawing
bodies program the SAU5's BLT, SMD_$INVERT_DISP has a second form, and
the data segment adds SMD_$GET_DTYPE (its body there too: a bus-error
probe of the display memory, then a BLT test); the keyboard tables are
the SAU2's.  Every byte is the SAU5 image's.

### The SAU9 (`display_devices`)

The SAU9's map (and the SAU7's and SAU8's, the same module sizes but the
SAU7's SMD_$WIRED_DATA) has another driver: the units are display
devices, each a descriptor (an I/O DCTE, MONO9_$UNIT on the SAU9) whose
routine vector the driver calls for everything the SAU2's driver does
with its controller.  The part is `display_devices`
(base/config.ins.pas).  The map's pieces:

- SMD_WIRED is data only (0x4D8 bytes: the cursor table and pointers,
  eight display records in SMD_$DISPLAY_COM, SMD_TIME_$COM, the keyboard
  table pointers and SMD_$KTT); SMD_UTILS holds only the national
  keyboard tables (0x500 bytes).  Neither has code.
- SMD: WIRED_PROC 0x248 (the SMD_$NOP_ defaults that live there, then
  SMD_$COPY_FONT_TO_MD_HDM .. SMD_$TOUCH), OS_INIT_PROC 0x354
  (SMD_$ADD_DEVICE .. SMD_$INSTALL_DISP_MEM), .TEXT 0x25A4
  (smd_$validate_unit, the other SMD_$NOP_ defaults, then the SAU2's
  order without the font, drawing, BLT and scroll routines, with
  SMD_$DEVICE_INFO, SMD_$SHARE_DEVICE and SMD_$SET_COLOR_TABLE),
  PROCEDURE$ 0x5C, PROC2_DELETE_PRO 0xC4; data .DATA 0x1DAC, WIRED_DATA
  0x1C, OS_INIT_DATA 0x88 (SMD_$ADD_DEVICE's statics: the vector's
  defaults and the next special segment), DATA$ 4.
- The overlay SMD_$WIRED_DATA is 0x8E0 bytes: eight unit records of
  0x114 (the device's vector, descriptor and cursor versions after the
  SAU2's fields), the lock, the cursors' versions and the unit count.
- The .DATA block is the SAU2's to +0x17F0; SMD_RESPONSE_VAL (eight
  booleans) comes before SMD_REQUEST_QUEUE (+0x17F8), every later
  variable is 8 bytes on, and there is no blink routine table.

Absent under the part (their includes and `define`s are compiled out):
SMD_$LOAD_FONT, _$UNLOAD_FONT, _$INVERT_S, _$WS_INIT, _$UTIL_INIT,
_$DRAW_BOX, smd_$cursor_op, SMD_$DISPLAY_CURSOR, _$CLEAR_CURSOR,
_$BLT, _$INQ_MM_BLT, _$SOFT_SCROLL, _$EOF_WAIT, _$WIRE_MM,
_$COND_INPUT_U, smd_$is_valid_blt_ctl, SMD_$BLT_U, _$SET_CLIP_WINDOW,
_$WRITE_STRING, and all of SMD_WIRED's and SMD_UTILS's code.

The SAU9's state.  Every compiled SMD routine of the SAU9's map, and the
module-locals, has its `sau9' address row:
- arms under the part: the 27 routines only the part has
  (`add_device.pas`, `fifo_wait.pas`, `touch.pas`, `device_info.pas`,
  `share_device.pas`, `set_color_table.pas`, the 21 `nop*.pas`), and
  the routines that call the device or read its vector or the unit
  count: SMD_$INIT, SMD_$COLD_INIT, SMD_$INSTALL_DISP_MEM,
  SMD_$COPY_FONT_TO_MD_HDM, SMD_$PUTC, SMD_$BUSY_WAIT, SMD_$LITES,
  smd_$validate_unit, smd_$reset_unit_display, SMD_$ASSOC,
  SMD_$ALLOC_HDM and SMD_$FREE_HDM (the device types' hidden memory),
  SMD_$INQ_DISP_TYPE, SHOW_CURSOR, SMD_$ACQ_DISPLAY, SMD_$REL_DISPLAY,
  SMD_$DM_COND_EVENT_WAIT (no scroll or BLT event), SMD_$BORROW_DISPLAY
  (no clear), smd_$init_display_state, SMD_$RETURN_DISPLAY,
  SMD_$VIDEO_CTL, SMD_$MAP_DISPLAY_U, SMD_$UNMAP_DISPLAY_U,
  SMD_$LOAD_CRSR_BITMAP (the pattern's version), SMD_$BLINK_CURSOR_
  CALLBACK, SMD_$CLEAR_SCREEN, SMD_$N_DEVICES, SMD_$INQ_DISP_UID,
  SMD_$MAP_DISPLAY_MEMORY, SMD_$UNMAP_DISPLAY_MEMORY, SMD_$SHUTDOWN,
  SMD_$ASSOC_CSRS and SMD_$DISSOC (the device's), SMD_$INQ_DISP_INFO
  (the device's record, 12 bytes: smd.ins.pas smd_disp_info_result_t),
  SMD_$DISPLAY_LOGO, SMD_$FREE_ASID;
- the SAU2's source, the code differing only by the 68020 forms, the
  data layout and register choice: the others.
SMD_WIRED's data (the cursor table and pointers, SMD_$DISPLAY_COM,
SMD_TIME_$COM, the keyboard table pointers, SMD_$KTT) and SMD_UTILS's
keyboard tables have no SAU9 file yet (the TODO(sau) below).

### The SMD module

`smd.pas`, `module smd;`: the .TEXT/.DATA pair is the default (ref
7.1.1), and the .DATA block's objects are module variables shared by the
.TEXT routines, which load A5 with the block's start.  The other
sections:

| section | routines | attribute | data |
|---------|----------|-----------|------|
| WIRED_PROC | SMD_$COPY_FONT_TO_MD_HDM, _$PUTC, _$BUSY_WAIT, _$LITES | `[section(wired_proc, wired_data)]` | the WIRED_DATA block: A5 in SMD_$BUSY_WAIT and SMD_$LITES (always mode) |
| OS_INIT_PROC | SMD_$INIT, _$INIT_BLINK, _$COLD_INIT, _$INSTALL_DISP_MEM | `[section(os_init_proc, os_init_data)]` | the OS_INIT_DATA block |
| .TEXT | smd_$validate_unit .. SMD_$DISPLAY_LOGO | none (the heading's) | the .DATA block, through A5 |
| PROCEDURE$ | smd_$reschedule_blink_timer | `[section(procedure$, wired_data)]`: it loads A5 with the WIRED_DATA block and passes it as its time-queue element: the block is its static, so its data section is WIRED_DATA | (WIRED_DATA's: the static blink_qelem) |
| PROC2_DELETE_PRO | SMD_$FREE_ASID | `[section(proc2_delete_pro, data$)]`: A5 is the end of the 4-byte DATA$ block, not PROC2_DELETE_DAT's | the DATA$ block |

The module file tables every block's objects with their offsets and
users.  The data:

- .DATA (0x1DA8 bytes): module variables in the block's order (KBD's
  reasoning: most are shared, and the block's order is not the
  routines'), with the image's non-zero bytes as initial values:
  display_map_length (+0x0), asid_to_unit (+0x48, `[* of 1]`), the
  keyboard cursor's tracking rectangle (+0xC0), the blanking clock and
  time-out, the cursor and tracking words (+0xC8..+0xE6), the 200
  tracking rectangles (+0xE8), the event ring's indices and 256 entries
  (+0x728..+0x172B), three flags (+0x173D..+0x173F), the cursor-pending
  flag (+0x1744), unit 1's font table (+0x1748) and free list (+0x1788),
  the defined SMD_REQUEST_QUEUE (+0x17F0, `define ... := [tail := 1,
  head := 1]`), the position sentinel (+0x1D94, -1/-1), default_unit
  (+0x1D98, 1), the defined SMD_RESPONSE_VAL (+0x1D9A), previous_unit
  (+0x1D9C, -1), three single-routine words and flags, and the blink
  routine table (+0x1DA4, `addr(smd_$blink_cursor_1)`).  Five runs of
  bytes nothing addresses have stand-ins `unused_<offset>` (the TODO
  there).
- WIRED_DATA (0x1C bytes, zero): reached only by the A5 loads of
  SMD_$BUSY_WAIT, SMD_$LITES and smd_$reschedule_blink_timer; the last
  passes it to the time queue (a time queue element plus 2 bytes, the
  block rounded to 4).  It is smd_$reschedule_blink_timer's static
  blink_qelem, a time_$queue_elem_t (`reschedule_blink_timer.pas`).
- OS_INIT_DATA (4 bytes) and DATA$ (4 bytes), both zero: no operand
  names their bytes; SMD_$INIT_BLINK and SMD_$FREE_ASID load A5 with
  their ends.  No object of this unit.
- The overlay section SMD_$WIRED_DATA (0x13C bytes, zero): one record,
  `var (smd_$wired_data) smd_$wired_data: smd_$wired_data_t`
  (ring/ringlog.ins.pas's form): two eventcounts, the unit records
  `[1..1]` (0x10C each, at +0x18), the tracking-rectangle lock (+0x124)
  and 6 bytes nothing addresses (a stand-in and a TODO).  Only SMD's
  code reaches it (a byte search: 50 operands, all SMD's).

The routine `define`s: dpc refuses a `define` of a routine whose body is
not in the unit (ref 7.3.4), so each fragment's writer moved its names
into the `define` list; every SMD map global is in it.

### SMD_UTILS is hand assembly

The map's SMD_UTILS segments are not compiler output; the module gets no
Pascal, and `sau2/smd_utils.s` transcribes it (its header has the byte
evidence).  The signs:

- **Code in a D segment, data base PC-relative.**  The map globals
  SMD_$COPY_FONT_TO_HDM, _$WRITE_STR_CLIP, _$CLEAR_WINDOW, _$HORIZ_LINE
  and _$VERT_LINE are 10-byte stubs in the .DATA segment that form the
  segment's start PC-relative in A0 and jump to the bodies; the bodies
  copy it to A5 and call the SMD routines through the segment's address
  cells (SMD_$WS_INIT, SMD_$UTIL_INIT, SMD_$ACQ_DISPLAY,
  SMD_$REL_DISPLAY, SMD_$START_BLT).  Compiled code loads A5 with an
  absolute address and calls by absolute address.
- **No compiler frame.**  SMD_$COPY_FONT_TO_HDM's body, SMD_$INVERT_DISP,
  SMD_$HORIZ_LINE and SMD_$VERT_LINE have no frame and read their
  arguments off SP past the register save.  The two that have one put it
  after the register save and the A5 copy, an order compiled code does
  not use; one restores the frame before the registers.
- **Encodings.**  Compare, subtract, add, and, or with an immediate
  source in their non-immediate forms; compiled code uses the immediate
  forms.
- **Control flow a compiler does not produce.**  A branch on the flags
  of a store to memory; out-of-line code after the return reached by a
  branch back; busy-waits on a status word that branch to themselves;
  SMD_$VERT_LINE ending in a branch into SMD_$HORIZ_LINE's body; a loop
  whose exit falls into another loop with a reload; a result pushed and
  popped around a call.

The compiled SMD module calls these entries; their headings (written
from the call sites) are in `smd_internal.ins.pas` and `smd.ins.pas`.
The national keyboard tables are data of this hand-written segment, and
kbd/'s MNK_$KTT_PTRS (SMD_WIRED, also hand data) points at them.

## Routines and their fragments

Image order within each section.  Where two routines that share a
fragment are not adjacent in the image, the first one's fragment is
named after itself (kbd's convention).

| routine | fragment |
|---------|----------|
| SMD_$XOR_CURSOR, SMD_$OR_CURSOR | none: hand assembly (`sau2/cursor_thunks.s`) |
| SMD_$START_SCROLL, SMD_$CONTINUE_SCROLL | none: hand assembly (`sau2/scroll.s`) |
| SMD_$LOCK_DISPLAY | none: hand assembly (`m68k/lock_display.s`) |
| SMD_$BIT_SET | none: hand assembly (`m68k/bit_set.s`) |
| SMD_$START_BLT | none: hand assembly (`sau2/start_blt.s`) |
| SMD_$DISP1_INT | none: hand assembly (`sau2/disp1_int.s`) |
| SMD_$BLINK_CURSOR_1, SMD_$BLINK_CURSOR | none: hand assembly (`sau2/blink_cursor_1.s`) |
| SMD_$INTERRUPT_INIT | none: hand assembly (code in the SMD_WIRED data segment; `sau2/interrupt_init.s`) |
| (SMD_WIRED data) | none: hand assembly (`m68k/wired_data.s`) |
| SMD_$NOP2, SMD_$NOP_COPY, SMD_$NOP_BLINK, SMD_$NOP_XOR, SMD_$NOP_REL, SMD_$NOP_LITE, SMD_$NOP_PUT, SMD_$NOP_FIFOWAIT, SMD_$NOP_TOUCH (`display_devices`) | `nop2.pas`, `nop_copy.pas`, `nop_blink.pas`, `nop_xor.pas`, `nop_rel.pas`, `nop_lite.pas`, `nop_put.pas`, `nop_fifowait.pas`, `nop_touch.pas` |
| SMD_$COPY_FONT_TO_MD_HDM | `copy_font_to_md_hdm.pas` |
| SMD_$PUTC | `putc.pas` |
| SMD_$BUSY_WAIT | `busy_wait.pas` |
| SMD_$LITES | `lites.pas` |
| SMD_$FIFO_WAIT (`display_devices`) | `fifo_wait.pas` |
| SMD_$TOUCH (`display_devices`) | `touch.pas` |
| SMD_$ADD_DEVICE (`display_devices`) | `add_device.pas` |
| SMD_$INIT | `init.pas` |
| SMD_$INIT_BLINK | `init_blink.pas` |
| SMD_$COLD_INIT | `cold_init.pas` |
| SMD_$INSTALL_DISP_MEM | `install_disp_mem.pas` |
| smd_$validate_unit | `validate_unit.pas` |
| SMD_$NOP1, SMD_$NOP_VIDEO, SMD_$NOP_CRSR, SMD_$NOP_LOCK, SMD_$NOP_MAP, SMD_$NOP_UNMAP, SMD_$NOP_ASSOC, SMD_$NOP_LOGO, SMD_$NOP_COLOR, SMD_$NOP_DEVINFO, SMD_$NOP_SHAREDEV, SMD_$NOP_CLOSE (`display_devices`) | `nop1.pas`, `nop_video.pas`, `nop_crsr.pas`, `nop_lock.pas`, `nop_map.pas`, `nop_unmap.pas`, `nop_assoc.pas`, `nop_logo.pas`, `nop_color.pas`, `nop_devinfo.pas`, `nop_sharedev.pas`, `nop_close.pas` |
| smd_$reset_unit_display | `reset_unit_display.pas` |
| smd_$reset_display_globals | `reset_display_globals.pas` |
| SMD_$ASSOC | `assoc.pas` |
| SMD_$ALLOC_HDM | `alloc_hdm.pas` |
| SMD_$FREE_HDM | `free_hdm.pas` |
| SMD_$LOAD_FONT | `load_font.pas` |
| SMD_$UNLOAD_FONT | `unload_font.pas` |
| SMD_$INVERT_S | `invert_s.pas` |
| SMD_$INQ_DISP_TYPE | `inq_disp_type.pas` |
| SMD_$WS_INIT | `ws_init.pas` |
| SMD_$UTIL_INIT | `util_init.pas` |
| SMD_$DRAW_BOX | `draw_box.pas` |
| smd_$cursor_op | `cursor_op.pas` |
| SMD_$DISPLAY_CURSOR | `display_cursor.pas` |
| SMD_$CLEAR_CURSOR | `clear_cursor.pas` |
| SMD_$INQ_KBD_CURSOR | `inq_kbd_cursor.pas` |
| SMD_$INQ_KBD_TYPE | `inq_kbd_type.pas` |
| SMD_$SET_KBD_TYPE | `set_kbd_type.pas` |
| SHOW_CURSOR | `show_cursor.pas` |
| SMD_$ENABLE_TRACKING | `enable_tracking.pas` |
| SMD_$DISABLE_TRACKING | `disable_tracking.pas` |
| SMD_$SET_TP_REPORTING | `set_tp_reporting.pas` |
| smd_$add_trk_rects_internal | `add_trk_rects_internal.pas` |
| SMD_$CLR_AND_LOAD_TRK_RECT | `clr_and_load_trk_rect.pas` |
| SMD_$ADD_TRK_RECT | `add_trk_rect.pas` |
| SMD_$DEL_TRK_RECT | `del_trk_rect.pas` |
| SMD_$CLR_TRK_RECT | `clr_trk_rect.pas` |
| SMD_$SET_CURSOR_POS | `set_cursor_pos.pas` |
| SMD_$SET_UNIT_CURSOR_POS | `set_unit_cursor_pos.pas` |
| SMD_$MOVE_KBD_CURSOR | `move_kbd_cursor.pas` |
| SMD_$CLEAR_KBD_CURSOR | `clear_kbd_cursor.pas` |
| smd_$poll_keyboard | `poll_keyboard.pas` |
| smd_$enqueue_event | `enqueue_event.pas` |
| SMD_$SET_TP_CURSOR | `set_tp_cursor.pas` |
| SMD_$LOC_EVENT | `loc_event.pas` |
| SMD_$STOP_TP_CURSOR | `stop_tp_cursor.pas` |
| SMD_$ACQ_DISPLAY | `acq_display.pas` |
| SMD_$REL_DISPLAY | `rel_display.pas` |
| SMD_$BLT | `blt.pas` |
| SMD_$INQ_MM_BLT | `inq_mm_blt.pas` |
| SMD_$GET_IDM_EVENT | `get_idm_event.pas` |
| SMD_$GET_UNIT_EVENT | `get_unit_event.pas` |
| SMD_$UNBLANK | `unblank.pas` |
| SMD_$DM_COND_EVENT_WAIT | `dm_cond_event_wait.pas` |
| SMD_$SET_BLANK_TIMEOUT | `set_blank_timeout.pas` |
| SMD_$INQ_BLANK_TIMEOUT | `inq_blank_timeout.pas` |
| SMD_$SIGNAL | `signal.pas` |
| SMD_$SOFT_SCROLL | `soft_scroll.pas` |
| SMD_$EOF_WAIT | `eof_wait.pas` |
| SMD_$WIRE_MM | `wire_mm.pas` |
| SMD_$SEND_RESPONSE | `send_response.pas` |
| smd_$init_display_state | `init_display_state.pas` |
| SMD_$BORROW_DISPLAY | `borrow_display.pas` |
| SMD_$RETURN_DISPLAY | `return_display.pas` |
| SMD_$SET_DISP_UNIT | `set_disp_unit.pas` |
| SMD_$INIT_STATE | `init_state.pas` |
| SMD_$VIDEO_CTL | `video_ctl.pas` |
| SMD_$MAP_DISPLAY_U | `map_display_u.pas` |
| SMD_$UNMAP_DISPLAY_U | `unmap_display_u.pas` |
| SMD_$COND_INPUT_U | `cond_input_u.pas` |
| smd_$is_valid_blt_ctl | `is_valid_blt_ctl.pas` |
| SMD_$BLT_U | `blt_u.pas` |
| SMD_$OP_WAIT_U | `op_wait_u.pas` |
| SMD_$LOAD_CRSR_BITMAP | `load_crsr_bitmap.pas` |
| SMD_$READ_CRSR_BITMAP | `read_crsr_bitmap.pas` |
| SMD_$GET_EC | `get_ec.pas` |
| SMD_$SET_CLIP_WINDOW | `set_clip_window.pas` |
| SMD_$WRITE_STRING | `write_string.pas` |
| SMD_$BLINK_CURSOR_CALLBACK | `blink_cursor_callback.pas` |
| SMD_$CLEAR_SCREEN | `clear_screen.pas` |
| SMD_$N_DEVICES | `n_devices.pas` |
| SMD_$INQ_DISP_UID | `inq_disp_uid.pas` |
| SMD_$MAP_DISPLAY_MEMORY | `map_display_memory.pas` |
| SMD_$UNMAP_DISPLAY_MEMORY | `unmap_display_memory.pas` |
| SMD_$SHUTDOWN | `shutdown.pas` |
| SMD_$DEVICE_INFO (`display_devices`) | `device_info.pas` |
| SMD_$SHARE_DEVICE (`display_devices`) | `share_device.pas` |
| SMD_$ASSOC_CSRS | `assoc_csrs.pas` |
| SMD_$DISSOC | `dissoc.pas` |
| SMD_$INQ_DISP_INFO | `inq_disp_info.pas` |
| SMD_$SET_COLOR_TABLE (`display_devices`) | `set_color_table.pas` |
| SMD_$DISPLAY_LOGO | `display_logo.pas` |
| smd_$reschedule_blink_timer | `reschedule_blink_timer.pas` |
| SMD_$FREE_ASID | `free_asid.pas` |
| SMD_$COPY_FONT_TO_HDM, SMD_$INVERT_DISP, SMD_$WRITE_STR_CLIP, SMD_$CLEAR_WINDOW, SMD_$HORIZ_LINE, SMD_$VERT_LINE | none: hand assembly (SMD_UTILS; `sau2/smd_utils.s`) |
| (data) | the variables of `smd.pas`; the overlay in `smd_internal.ins.pas` |

## Insert files

- `smd_internal.ins.pas` (included only by `smd.pas`, after base, ec,
  ml, time, proc1 and smd.ins.pas): Apollo's smdu.ins.pas types the
  records need (smd_$direction_t, smd_$display_memory_t and its pointer,
  smd_$cursor_bitmap_t, smd_$request_t, smd_$font_table_t with
  smd_$v1_fdte_t and its pointer); the controller register block (a
  `[device]` record) and DISP1; the module's records (smd_track_rect_t,
  smd_event_entry_t, smd_request_queue_t, smd_unit_fonts_t,
  smd_hdm_list_t, smd_display_hw_t, smd_display_unit_t,
  smd_$wired_data_t and the others), each with its evidence; the overlay
  SMD_$WIRED_DATA; the hand-written SMD_WIRED data the compiled code
  reads (SMD_$DISPLAY_COM, SMD_TIME_$COM, SMD_$CURSOR_PTABLE; extern),
  DISPLAY1_$UID (UID_LIST's, `TODO(merge) move to uid/uid.ins.pas`) and
  OS_$SHUTDOWN_EC; the headings of the hand-written entries the compiled
  code calls (SMD_WIRED's and SMD_UTILS's, and DISP_LITES with its
  `TODO(merge) move to misc/misc.ins.pas`), each from its callers'
  pushes and its `.s` file's reading of the stack; the headings whose
  types are internal; the extern declarations of the two defined map
  variables.  A file of its own because these need ec, ml, time and
  proc1, and smd.ins.pas's users include it after base alone.
- `smd.ins.pas`: the types and headings other subsystems use (its users
  kbd, dtty, term, suma, tpad, misc), Apollo's statuses and records from
  smdu.ins.pas, and the headings of the routines whose types need only
  base and smd.ins.pas.
- Elsewhere: `../mmu/mmu.ins.pas` MMU_$POWER_OFF; `../time/time.ins.pas`
  TIME_$Q_ADD_CALLBACK's interval `in univ` (smd_$reschedule_blink_timer
  passes a 4-byte literal); `../kbd/kbd.ins.pas` KBD_$INQ_KBD_TYPE's
  type_len pinteger (SMD_$INQ_KBD_TYPE compares the variable it passes
  there unsigned).

### Layout fixes

The layout audit (in an unpacked record only char, boolean, `[byte]`
subranges and 1-char arrays sit at odd offsets; a record is at least 2
bytes; and every static object is word aligned), probed with dpc:
- `smd.pas`'s .DATA block: the booleans at +0xDD and +0x173D are fields
  of records (`blank_flags: smd_blank_flags_t`, `flags_173c:
  smd_flags_173c_t`), since as variables dpc word-aligns them and moves
  every later variable; +0x1745 is the alignment after a byte variable.
  Every variable is at its table offset (the block 0x1DA8 bytes).
- `smd_internal.ins.pas` and `smd.ins.pas`: every record's fields at
  their comment offsets and every size as declared.
- `../fim/fim.ins.pas` fim_$df_t (the flags and version one 2-byte
  packed record) and `../peb/peb.ins.pas` peb_$ctl_t (a char and a char
  array at 0x3FD, 0x3FE) were fixed by the same audit.

## The image's behavior

Facts about the image the code reproduces, which its names do not
tell:
- SMD_$INIT gives display type 1 the limits ye = 16#3FF, xe = 16#31F,
  type 2 ye = 16#31F, xe = 16#3FF.
- SMD_$COPY_FONT_TO_MD_HDM returns 0 in D0's word on every path (a
  function of integer; its one caller ignores the result).
- SMD_$FREE_HDM stores smd_$illegal_caller when the process has no
  unit, smd_$invalid_pos for a position outside the hidden memory,
  smd_$hdmt_unload_err for space overlapping a free block and for a full
  list, and status_$ok after a merge or an insertion; it forms and
  compares block_end = offset + size in 32 bits.
- smd_$add_trk_rects_internal adds the two counts in 32 bits and
  compares unsigned, so it refuses a count near 65536.
- smd_$add_trk_rects_internal reads the caller's first and last
  rectangle, and SMD_$DEL_TRK_RECT every one, into a local before taking
  the lock; the values are not used.
- SMD_$DEL_TRK_RECT's count is signed: neither loop runs for a count of
  16#8001..16#FFFF, and the final test widens the count by sign.  It
  tests the count and sets cursor_pending_flag inside the lock, and
  copies the last entry onto itself when the hole is the last.
- SMD_$BLINK_CURSOR_CALLBACK compares the time-out plus the blanking
  time with TIME_$CLOCKH signed.

## Open items

### TODO(pascal)

- `smd.pas`: five runs of the .DATA block nothing addresses (stand-ins
  unused_bc, unused_172c, unused_173c, unused_1740, unused_1746,
  unused_17ee).
- `smd_internal.ins.pas`: the 6 bytes at the end of SMD_$WIRED_DATA
  (stand-in unused_136).
- The frames not accounted (the image's frame larger than dpc's layout
  of the declared locals and `with` slots): `copy_font_to_md_hdm.pas`,
  `init.pas`, `reset_unit_display.pas`, `reset_display_globals.pas`,
  `assoc.pas`, `alloc_hdm.pas`, `free_hdm.pas`, `load_font.pas`,
  `invert_s.pas`, `draw_box.pas`, `cursor_op.pas`, `show_cursor.pas`,
  `add_trk_rects_internal.pas`, `del_trk_rect.pas`, `poll_keyboard.pas`,
  `blt.pas`, `dm_cond_event_wait.pas`, `signal.pas`, `soft_scroll.pas`,
  `eof_wait.pas`, `wire_mm.pas`, `send_response.pas`,
  `init_display_state.pas`, `borrow_display.pas`, `return_display.pas`,
  `video_ctl.pas`, `cond_input_u.pas`, `op_wait_u.pas`,
  `load_crsr_bitmap.pas`, `read_crsr_bitmap.pas`, `get_ec.pas`,
  `blink_cursor_callback.pas`, `write_string.pas` (the objects in
  another order), `display_logo.pas`, `free_asid.pas`; each fragment's
  TODO gives the bytes.  `invert_s.pas` also: the display record's
  address formed before the statements that precede the call.

### TODO(sau)

- The SAU5's hand assembly is written (`sau5/*.s`, above); the SAU5
  link still needs the I/O names it reads as absolute symbols (an
  `arch/m68k/sau5` iodefs, outside this subsystem).
- The SAU9's SMD_WIRED data segment (0x4D8 bytes) and SMD_UTILS
  segment (0x500 bytes, the national keyboard tables only) are not
  written: hand data, `sau9/*.s` or `.if' arms in `m68k/wired_data.s'
  and the SAU2's keyboard tables, checked against the image's bytes.

## Named dispatch codes

SMD_$ASSOC's discipline 1 is TERM's named constant term_$disc_
disable_alt (term/README.md); the code is unchanged.

smd/smd_internal.ins.pas's dispatch-code blocks name SMD_$GET_EC's keys
(`smd_$input_ec`, `smd_$scroll_blt_ec`: Apollo's smdu.ins.pas
smd_$ec_key_t; 2 and 3 have no Apollo name), the event queue's internal
and public event types (`smd_$evtype_int_*`, `smd_$evtype_*`) and
SMD_$DM_COND_EVENT_WAIT's user-level types (Apollo's smd_$event_t
ordinals, 1 as `smd_$signal_event` since smd_$signal is the routine).
Used in get_ec, get_unit_event, get_idm_event, poll_keyboard, loc_event,
cond_input_u, dm_cond_event_wait.  The lock states are left as numbers:
a state machine with arms 6 and 7 that has no names.
