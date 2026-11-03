{ smd/smd.pas - the SMD module, the screen manager's display driver.

  Image addresses:
    sau2  0x00E2E060  SMD data (WIRED_DATA, 0x1C bytes)
    sau2  0x00E3537C  SMD data (OS_INIT_DATA, 0x4 bytes)
    sau2  0x00E82B8C  SMD data (.DATA, 0x1DA8 bytes)
    sau2  0x00E85714  SMD data (DATA$, 0x4 bytes)
    sau4  0x0F831198  SMD data (WIRED_DATA, 0x1C bytes)
    sau4  0x0F838A70  SMD data (OS_INIT_DATA, 0x4 bytes)
    sau4  0x0F89135C  SMD data (.DATA, 0x1E58 bytes)
    sau4  0x0F893D5C  SMD data (DATA$, 0x4 bytes)
    sau5  0x00E2F374  SMD data (WIRED_DATA, 0x1C bytes)
    sau5  0x00E37B88  SMD data (OS_INIT_DATA, 0x4 bytes)
    sau5  0x00E89F04  SMD data (.DATA, 0x1E58 bytes)
    sau5  0x00E8DF40  SMD data (DATA$, 0x4 bytes)
    sau9  0x3C43346C  SMD data (WIRED_DATA, 0x1C bytes)
    sau9  0x3C43CF14  SMD data (OS_INIT_DATA, 0x88 bytes)
    sau9  0x3C49B310  SMD data (.DATA, 0x1DAC bytes)
    sau9  0x3C49E098  SMD data (DATA$, 0x4 bytes)

  One compilation unit, in five code sections and four data sections:
  the map's SMD code segments in WIRED_PROC (0x18C bytes), OS_INIT_PROC
  (0x1D8), .TEXT (0x2BF4, SMD_$ASSOC .. SMD_$DISPLAY_LOGO), PROCEDURE$
  (0x5C, smd_$reschedule_blink_timer) and PROC2_DELETE_PRO (0x6C,
  SMD_$FREE_ASID); its data segments in WIRED_DATA (0x1C), OS_INIT_DATA
  (4), .DATA (0x1DA8) and DATA$ (4).

  The overlay section SMD_$WIRED_DATA (0x13C bytes, no module segment in
  it) is declared in smd/smd_internal.ins.pas.  SMD_WIRED is hand
  assembly (smd/sau2/*.s), SMD_UTILS a map module of its own
  (smd/README.md).

  Why one module: smd_$reschedule_blink_timer, `internal', is called
  from OS_INIT_PROC and from .TEXT, and an internal routine can only be
  called from its own compilation unit (ref 5.2, 5.5.4).  The map gives
  every segment one module name, SMD.

  The heading: .TEXT and .DATA are the default sections (ref 7.1.1), so
  `module smd;'; the other code sections' routines name their partner
  data sections (ref 5.7.1): WIRED_PROC's wired_data, OS_INIT_PROC's
  os_init_data, PROCEDURE$'s wired_data (its static queue element,
  smd/reschedule_blink_timer.pas), PROC2_DELETE_PRO's data$.

  The data.  WIRED_DATA, 0x1C bytes, zero: smd_$reschedule_blink_timer's
  static blink_qelem (0x1A bytes) and the block's rounding.
  OS_INIT_DATA and DATA$, 4 bytes each, zero, hold no object of this
  unit (only their ends are loaded into A5).

  .DATA, 0x1DA8 bytes, the module variables in the block's order:

    +0x0000 display_map_length    0x48  by display type
    +0x0048 asid_to_unit          0x74  by PROC1_$AS_ID
    +0x00BC unused_bc             4     a stand-in (TODO)
    +0x00C0 kbd_cursor_track_rect 8
    +0x00C8 blank_time            4

    +0x00CC saved_cursor_pos      4
    +0x00D0 default_cursor_pos    4     SHOW_CURSOR's
    +0x00D4 cursor_button_state   2     SHOW_CURSOR's
    +0x00D6 last_button_state     2
    +0x00D8 blank_timeout         4

    +0x00DC blank_flags           2     blank_enabled (+0xDC) and
                                        blank_pending (+0xDD)
    +0x00DE tp_reporting          2
    +0x00E0 tracking_enabled      1
    +0x00E1                       1     (word alignment)
    +0x00E2 tp_cursor_timeout     2

    +0x00E4 tracking_cursor_num   2
    +0x00E6 tracking_rect_count   2
    +0x00E8 tracking_rects        0x640
    +0x0728 event_queue_head      2
    +0x072A event_queue_tail      2
    +0x072C event_queue           0x1000 16 bytes an entry

    +0x172C unused_172c           0x10  a stand-in (TODO)
    +0x173C flags_173c            4     unused_173c (a stand-in, TODO),
                                        field_173d, field_173e, field_173f
    +0x1740 unused_1740           4     a stand-in (TODO)
    +0x1744 cursor_pending_flag   1
    +0x1745                       1     (word alignment)

    +0x1746 unused_1746           2     a stand-in (TODO)
    +0x1748 unit_fonts            0x40  the unit record's font_table
    +0x1788 unit_hdm_list         0x66  the unit record's hdm_list
    +0x17EE unused_17ee           2     a stand-in (TODO)
    +0x17F0 smd_request_queue     0x5A4 defined (map SMD_REQUEST_QUEUE);
                                        tail and head 1, the entries zero

    +0x1D94 cursor_pos_sentinel   4     both words -1
    +0x1D98 default_unit          2     1
    +0x1D9A smd_response_val      2     defined (map SMD_RESPONSE_VAL)
    +0x1D9C previous_unit         2     -1; SHOW_CURSOR's
    +0x1D9E unit_change_count     2

    +0x1DA0 last_idm_button       2
    +0x1DA2 power_off_reported    1
    +0x1DA3                       1     (word alignment)
    +0x1DA4 blink_func            4     SMD_$BLINK_CURSOR_1's address,
                                        from 1 by default_unit

  With `two_display_units' (base/config.ins.pas; the SAU5's block,
  0x1E58 bytes) unit 1's font table and free list follow at +0x17F0, and
  every later variable is 0xA8 bytes on; unit_fonts and unit_hdm_list
  are unit 2's there, and blink_func has two elements (+0x1E50).

  With `display_devices' (the SAU9's block, 0x1DAC bytes) the layout is
  the SAU2's to +0x17F0; then the eight response booleans (+0x17F0), the
  request ring (+0x17F8), and every later variable 8 bytes on, with no
  blink routine table.  OS_INIT_DATA is 0x88 bytes there:
  SMD_$ADD_DEVICE's statics (smd/add_device.pas).

  Without `display_driver' (the SAU3, which has no display) the unit is
  seven stubs in three code sections, with no data: SMD_$LITES in
  WIRED_PROC (4 bytes); smd_$validate_unit, SMD_$INQ_DISP_TYPE,
  SMD_$N_DEVICES, SMD_$INQ_DISP_UID and SMD_$INQ_DISP_INFO in .TEXT
  (0x88 bytes); SMD_$FREE_ASID in PROC2_DELETE_PRO (4 bytes).

  These are module variables, not routine statics: most are used by
  several routines, and the block's order is not the routines'.  The two
  map symbols are defined here, in their places in the block.  Element
  1 of unit_fonts, smd_request_queue, smd_response_val and blink_func is
  at the address the image's code reaches.

  The routines live in one fragment file each (smd/<name>.pas), included
  below in image order within each section (smd/README.md has the
  table).

  Build: dpc -I domain_os domain_os/smd/smd.pas.  Check:
  tools/pascal_check.sh.
}
module smd;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mst/mst.ins.pas';
%include 'uid/uid.ins.pas';
%if blt_main_memory %then
%include 'pbu/pbu.ins.pas';
%endif
%include 'smd/smd.ins.pas';
%include 'tpad/tpad.ins.pas';
%include 'suma/suma.ins.pas';
%include 'kbd/kbd.ins.pas';
%include 'term/term.ins.pas';
%include 'color/color.ins.pas';
%include 'color2/color2.ins.pas';
%include 'smd/smd_internal.ins.pas';

{ The module's variables (ref 3.2.2 p. 3-4, 3.11.1: initial values of
  module variables), in the order of the .DATA block, and the global
  routines and the variables this module defines (ref 7.3.4 and 7.2.2,
  Method 2), in map order. }
%if display_driver %then
var
  { +0x0000: the length MST_$MAP and MST_$UNMAP are given for each
    display type, reached at displacement 0 with the type scaled by 4
    (SMD_$MAP_DISPLAY_U): indexed from 0.  Eighteen longwords, up to
    asid_to_unit (no code reaches past element 12). }
  display_map_length: array[0..17] of integer32 := [
    0, 16#20000, 16#20000, 16#20000, 16#20000, 16#40000, 16#20000,
    16#20000, 16#20000, 16#40000, 16#20000, 16#20000, 16#200000,
    0, 0, 0, 0, 0];
  { +0x0048: the display unit of each process, indexed from 0 by
    PROC1_$AS_ID as a word (SMD_$SEND_RESPONSE): proc1_$asid_t; words
    tested for zero and used as unit numbers: integer.  58 words, 0x74
    bytes, to +0xBC, all 1. }
  asid_to_unit: array[proc1_$asid_t] of integer := [* of 1];
  { +0x00BC: zero. }
  { TODO(pascal) bytes of the SMD block nothing addresses (stand-ins unused_bc, _172c, _173c, _1740, _1746, _17ee)

    No operand of the image reaches +0xBC..+0xBF, +0x172C..+0x173C,
    +0x1740..+0x1743, +0x1745..+0x1747 or +0x17EE..+0x17EF (the A5
    operands of the SMD code, the indexed forms' element ranges, and a
    byte search of the image for the block's addresses); all are zero in
    the image.  The stand-ins hold their places.  A lead: every object
    of 8 bytes or more here starts at a multiple of 8 from the block
    (+0x00, +0x48, +0xC0, +0xE8, +0x1748, +0x1788, +0x17F0) but
    event_queue at +0x72C; with that rule unused_bc, unused_1746 and
    unused_17ee are what alignment leaves before the next object, and
    would not be declared.  The 17 bytes at +0x172C (here unused_172c's
    16 and the record flags_173c's first byte, unused_173c) and the 4 at
    +0x1740 it does not explain.  +0x1745 needs no stand-in: a byte
    variable is followed by the word alignment of the next variable
    (each static object word aligned, dpc's STATIC_MIN_ALIGN).  The
    SAU5's block (`two_display_units') fits the rule too: its stand-ins
    unused_1896 (2 bytes before the request ring at +0x1898) and
    unused_1e4c (4 bytes before the 8-byte blink_func at +0x1E50) are
    what the alignment leaves.  Not settled. }
  unused_bc: integer32 := 0;
  { +0x00C0: the rectangle the keyboard cursor's bitmap hides the cursor
    behind, passed by address to the tracking-rectangle routines
    (SMD_$CLEAR_KBD_CURSOR, SMD_$LOAD_CRSR_BITMAP) and copied into the
    first tracking rectangle (smd_$reset_display_globals). }
  kbd_cursor_track_rect: smd_track_rect_t := [x1 := 0, x2 := 16#3FFF,
                                              y1 := 0, y2 := 16#3FFF];
  { +0x00C8: zero.  The clock's high longword when the screen was last
    active (SMD_$UNBLANK, SMD_$VIDEO_CTL, the blink callback copy
    TIME_$CLOCKH into it): time_$clockh_t. }
  blank_time: time_$clockh_t;
  { +0x00CC: zero.  The last locator position reported: a position moved
    whole (SMD_$SET_UNIT_CURSOR_POS, SMD_$LOC_EVENT) and cleared field by
    field (smd_$reset_display_globals): smd_$pos_t (smd/smd.ins.pas). }
  saved_cursor_pos: smd_$pos_t;
  { +0x00D0: zero.  The position of the cursor drawn (SHOW_CURSOR
    compares, stores and passes it). }
  default_cursor_pos: smd_$pos_t;
  { +0x00D4: zero.  The number of the cursor drawn (SHOW_CURSOR compares,
    stores and passes it). }
  cursor_button_state: integer;
  { +0x00D6: zero.  The last button state reported (SMD_$LOC_EVENT). }
  last_button_state: integer;
  { +0x00D8: zero.  The blanking time-out (SMD_$SET_BLANK_TIMEOUT stores
    it), and the blink callback's signed test of it plus blank_time
    against the clock: integer32. }
  blank_timeout: integer32;
  { +0x00DC, +0x00DD: zero.  Two booleans, blank_enabled and
    blank_pending, set and tested by sign.  One record,
    smd_blank_flags_t: every static object is word aligned
    (dpc's STATIC_MIN_ALIGN), so a byte at +0xDD is a field of an object
    that starts at +0xDC; as two variables blank_pending would be at
    +0xDE and every later variable 2 bytes on (probed with dpc, an
    `addr' of each variable: blank_pending 0xDE, tracking_rects 0xEA,
    ...; the layout rules). }
  blank_flags: smd_blank_flags_t;
  { +0x00DE: zero.  Set to 1 (smd_$reset_display_globals), tested
    (SMD_$LOC_EVENT). }
  tp_reporting: integer;
  { +0x00E0: zero.  Set by SMD_$ENABLE_TRACKING, cleared by
    SMD_$DISABLE_TRACKING.  +0x00E1 is the word alignment of the next
    word. }
  tracking_enabled: boolean;
  { +0x00E2: zero.  Set to -1, incremented and compared with 2 (the blink
    callback). }
  tp_cursor_timeout: integer;
  { +0x00E4: zero.  Stored by SMD_$ENABLE_TRACKING, passed by address as
    SHOW_CURSOR's cursor number (SMD_$LOC_EVENT). }
  tracking_cursor_num: integer;
  { +0x00E6: zero.  12 operands: cleared, incremented, decremented, added
    to (smd_$add_trk_rects_internal).  A non-negative subrange (G5):
    widened by zero where it meets other values in 32 bits, against a
    pinteger (smd_$add_trk_rects_internal) and against signed words
    (SMD_$DEL_TRK_RECT, against an integer index and a sign-extended
    count): an integer would be sign-extended.  Not pinteger:
    SHOW_CURSOR's `for' guard on it is the signed one, where a 0..65535
    bound is guarded by a test for zero first.  The bound 200 is
    tracking_rects' own (smd_$add_trk_rects_internal compares with 16#C8
    as a word and as a longword): a count of 0..200 rectangles; the
    source's exact bound is not known. }
  tracking_rect_count: 0..200;
  { +0x00E8: zero.  The tracking rectangles, indexed from 1: element 1
    at +0xE8 (smd_$reset_display_globals), element k at A5 + 0xE0 + 8 * k
    (smd_$add_trk_rects_internal; SHOW_CURSOR).  200 (0x640 bytes, up to
    the event queue's indices). }
  tracking_rects: array[1..200] of smd_track_rect_t;
  { +0x0728, +0x072A: zero.  The event ring's write and read indices,
    0..255 (smd_$enqueue_event masks the next index with 16#FF).
    pinteger (0..65535, Apollo's unsigned word): SMD_$LOC_EVENT widens
    the head by zero for `(event_queue_head + 255) mod 256', the mod
    through M$OIS$WLW; the head and the tail are compared as words with
    each other and with the next index (SMD_$LOC_EVENT,
    smd_$poll_keyboard), so the two and the next index have one type (an
    integer against a pinteger would be compared in 32 bits). }
  event_queue_head: pinteger;
  event_queue_tail: pinteger;
  { +0x072C: zero.  The event ring, indexed from 0 by the head scaled by
    16 (smd_$enqueue_event).  256 entries, 0x1000 bytes. }
  event_queue: array[0..255] of smd_event_entry_t;
  { +0x172C: 16 zero bytes (the TODO above). }
  unused_172c: array[0..15] of char;
  { +0x173C..+0x173F: zero.  A zero byte nothing addresses (the TODO
    above), then three booleans only smd_$reset_display_globals writes;
    no code reads them.  One record, smd_flags_173c_t, for the reason
    given at blank_flags: +0x173D is odd, so it is a field of an object
    that starts at +0x173C or before. }
  flags_173c: smd_flags_173c_t;
  { +0x1740: zero (the TODO above). }
  unused_1740: integer32;
  { +0x1744: zero.  Set, cleared and or'ed into (SHOW_CURSOR). }
  cursor_pending_flag: boolean;
  { +0x1745: zero, the word alignment of the next variable (a 3-char
    array here would be word aligned, at +0x1746, and push unit_fonts to
    +0x174A: probed with dpc).  +0x1746: zero (the TODO above). }
  unused_1746: integer;
  { +0x1748: zero.  Unit 1's font table, smd_internal.ins.pas
    smd_unit_fonts_t. }
  unit_fonts: smd_unit_fonts_t;
  { +0x1788: zero.  Unit 1's hidden-display-memory free list,
    smd_internal.ins.pas smd_hdm_list_t, 0x66 bytes. }
  unit_hdm_list: smd_hdm_list_t;
  { +0x17EE: zero (the TODO above). }
  unused_17ee: integer;
%if two_display_units %then
  { +0x17F0, +0x1830: zero.  With `two_display_units' unit 1's font
    table and free list (SMD_$INIT stores their addresses in unit 1's
    record, the two above in unit 2's): one more pair of the same types,
    up to the request ring.  +0x1896: zero, nothing addresses it (the
    TODO above: before an object that starts at a multiple of 8). }
  unit1_fonts: smd_unit_fonts_t;
  unit1_hdm_list: smd_hdm_list_t;
  unused_1896: integer;
%endif

%if display_devices %then
define
  { +0x17F0: zero.  The units' "borrow request answered" booleans, eight
    with `display_devices' (smd_internal.ins.pas). }
  smd_response_val;
%endif

define
  { +0x17F0 (+0x17F8 with `display_devices'): tail and head 1, then
    0x5A0 zero bytes: the DM request ring (smd_internal.ins.pas
    smd_request_queue_t). }
  smd_request_queue := [tail := 1, head := 1];

var
  { +0x1D94: the position that tells SHOW_CURSOR to use the display's
    own: SHOW_CURSOR compares its position argument with it; every
    caller in the module passes its address.  A position: both words
    -1. }
  cursor_pos_sentinel: smd_$pos_t := [line := -1, column := -1];
  { +0x1D98: the current display unit: 20 operands, read as a signed
    word (SMD_$INQ_KBD_CURSOR): integer. }
  default_unit: integer := 1;

%if not display_devices %then
define
  { +0x1D9A: zero.  The units' "borrow request answered" booleans
    (smd_internal.ins.pas). }
  smd_response_val;
%endif

%endif

define
  { The routines this module defines, in map order: every SMD map global
    (dpc refuses a `define' of a routine without a body in the unit, ref
    7.3.4 p. 7-11, so each was listed when its fragment was written).
    `display_devices' has the SMD_$NOP_ routines, SMD_$ADD_DEVICE,
    SMD_$FIFO_WAIT, SMD_$TOUCH, SMD_$DEVICE_INFO, SMD_$SHARE_DEVICE and
    SMD_$SET_COLOR_TABLE, and none of the font, drawing, BLT and scroll
    routines. }
%if display_devices %then
  smd_$nop2;
  smd_$nop_copy;
  smd_$nop_blink;
  smd_$nop_xor;
  smd_$nop_rel;
  smd_$nop_lite;
  smd_$nop_put;
  smd_$nop_fifowait;
  smd_$nop_touch;
%endif
%if display_driver %then
  smd_$copy_font_to_md_hdm;
  smd_$putc;
  smd_$busy_wait;
%endif
  smd_$lites;
%if display_devices %then
  smd_$fifo_wait;
  smd_$touch;
  smd_$add_device;
%endif
%if display_driver %then
  smd_$init;
  smd_$init_blink;
  smd_$cold_init;
  smd_$install_disp_mem;
%endif
%if display_devices %then
  smd_$nop1;
  smd_$nop_video;
  smd_$nop_crsr;
  smd_$nop_lock;
  smd_$nop_map;
  smd_$nop_unmap;
  smd_$nop_assoc;
  smd_$nop_logo;
  smd_$nop_color;
  smd_$nop_devinfo;
  smd_$nop_sharedev;
  smd_$nop_close;
%endif
%if display_driver %then
  smd_$assoc;
  smd_$alloc_hdm;
  smd_$free_hdm;
%endif
%if display_driver and not display_devices %then
  smd_$load_font;
  smd_$unload_font;
  smd_$invert_s;
%endif
  smd_$inq_disp_type;
%if display_driver and not display_devices %then
  smd_$ws_init;
  smd_$util_init;
  smd_$draw_box;
  smd_$display_cursor;
  smd_$clear_cursor;
%endif
%if display_driver %then
  smd_$inq_kbd_cursor;
  smd_$inq_kbd_type;
  smd_$set_kbd_type;
  show_cursor;
  smd_$enable_tracking;
  smd_$disable_tracking;
  smd_$set_tp_reporting;
  smd_$clr_and_load_trk_rect;
  smd_$add_trk_rect;
  smd_$del_trk_rect;
  smd_$clr_trk_rect;
  smd_$set_cursor_pos;
  smd_$set_unit_cursor_pos;
  smd_$move_kbd_cursor;
  smd_$clear_kbd_cursor;
  smd_$set_tp_cursor;
  smd_$loc_event;
  smd_$stop_tp_cursor;
  smd_$acq_display;
  smd_$rel_display;
%endif
%if display_driver and not display_devices %then
  smd_$blt;
  smd_$inq_mm_blt;
%endif
%if display_driver %then
  smd_$get_idm_event;
  smd_$get_unit_event;
  smd_$unblank;
  smd_$dm_cond_event_wait;
  smd_$set_blank_timeout;
  smd_$inq_blank_timeout;
  smd_$signal;
%endif
%if display_driver and not display_devices %then
  smd_$soft_scroll;
  smd_$eof_wait;
  smd_$wire_mm;
%endif
%if display_driver %then
  smd_$send_response;
  smd_$borrow_display;
  smd_$return_display;
  smd_$set_disp_unit;
  smd_$init_state;
  smd_$video_ctl;
  smd_$map_display_u;
  smd_$unmap_display_u;
%endif
%if display_driver and not display_devices %then
  smd_$cond_input_u;
  smd_$blt_u;
%endif
%if display_driver %then
  smd_$op_wait_u;
  smd_$load_crsr_bitmap;
  smd_$read_crsr_bitmap;
  smd_$get_ec;
%endif
%if display_driver and not display_devices %then
  smd_$set_clip_window;
  smd_$write_string;
%endif
%if display_driver %then
  smd_$blink_cursor_callback;
  smd_$clear_screen;
%endif
  smd_$n_devices;
  smd_$inq_disp_uid;
%if display_driver %then
  smd_$map_display_memory;
  smd_$unmap_display_memory;
  smd_$shutdown;
%endif
%if display_devices %then
  smd_$device_info;
  smd_$share_device;
%endif
%if display_driver %then
  smd_$assoc_csrs;
  smd_$dissoc;
%endif
  smd_$inq_disp_info;
%if display_devices %then
  smd_$set_color_table;
%endif
%if display_driver %then
  smd_$display_logo;
%endif
  smd_$free_asid;

%if display_driver %then
var
  { +0x1D9C: -1.  The unit the cursor was last shown on (SHOW_CURSOR). }
  previous_unit: integer := -1;
  { +0x1D9E: zero.  Incremented by SMD_$SET_UNIT_CURSOR_POS. }
  unit_change_count: integer;
  { +0x1DA0: zero.  Read and stored by SMD_$GET_IDM_EVENT. }
  last_idm_button: integer;
  { +0x1DA2: zero.  Tested and stored by SMD_$DM_COND_EVENT_WAIT.
    +0x1DA3 is the word alignment of the pointer after it. }
  power_off_reported: boolean;
%if display_devices %then
  { No blink routines here with `display_devices': the device's vector
    has its blink routine.  +0x1DA9..+0x1DAB: the block's rounding to
    4 bytes (0x1DAC). }
%elseif two_display_units %then
  { +0x1E4C: zero, nothing addresses it (the TODO above: blink_func,
    8 bytes here, starts at a multiple of 8). }
  unused_1e4c: integer32;
  { +0x1E50: the units' blink routines, indexed from 1 by the unit
    scaled by 4 at displacement 0x1E4C, two elements up to the block's
    end: SMD_$BLINK_CURSOR_1's and SMD_$BLINK_CURSOR_2's addresses. }
  blink_func: array[1..smd_unit_count] of smd_blink_func_t :=
    [addr(smd_$blink_cursor_1), addr(smd_$blink_cursor_2)];
%else
  { +0x1DA4: the units' blink routines, indexed from 1 by the unit
    scaled by 4 at displacement 0x1DA0, one element up to the block's
    end: SMD_$BLINK_CURSOR_1's address. }
  blink_func: array[1..smd_unit_count] of smd_blink_func_t :=
    [addr(smd_$blink_cursor_1)];
%endif
%endif

{ The module-local routines called before their bodies.

  smd_$reschedule_blink_timer (PROCEDURE$, no map symbol): called by
  SMD_$INIT_BLINK (OS_INIT_PROC) and SMD_$BLINK_CURSOR_CALLBACK (.TEXT),
  each with a longword pushed (a constant or a value); the body reads
  its slot as a longword by value: one 4-byte value parameter (by value
  under `internal', ref 5.2), integer32.  The body's attribute is
  `[section(procedure$, wired_data)]' (above). }
%if display_driver %then
{ body: smd/reschedule_blink_timer.pas }
procedure smd_$reschedule_blink_timer(interval: integer32);
  forward; internal;
%endif

%if display_devices %then
{ smd_$validate_unit (.TEXT, no map symbol): with `display_devices'
  SMD_$BUSY_WAIT (WIRED_PROC) calls it before its body. }
{ body: smd/validate_unit.pas }
function smd_$validate_unit(unit: integer): boolean;
  forward; internal;
%endif

{ ---- WIRED_PROC ---- }
%if display_driver %then
%if display_devices %then
%include 'smd/nop2.pas';                    { SMD_$NOP2          }
%include 'smd/nop_copy.pas';                { SMD_$NOP_COPY      }
%include 'smd/nop_blink.pas';               { SMD_$NOP_BLINK     }
%include 'smd/nop_xor.pas';                 { SMD_$NOP_XOR       }
%include 'smd/nop_rel.pas';                 { SMD_$NOP_REL       }
%include 'smd/nop_lite.pas';                { SMD_$NOP_LITE      }
%include 'smd/nop_put.pas';                 { SMD_$NOP_PUT       }
%include 'smd/nop_fifowait.pas';            { SMD_$NOP_FIFOWAIT  }
%include 'smd/nop_touch.pas';               { SMD_$NOP_TOUCH     }
%endif
%include 'smd/copy_font_to_md_hdm.pas';     { SMD_$COPY_FONT_TO_MD_HDM }
%include 'smd/putc.pas';                    { SMD_$PUTC          }
%include 'smd/busy_wait.pas';               { SMD_$BUSY_WAIT     }
%endif
%include 'smd/lites.pas';                   { SMD_$LITES         }
%if display_driver %then
%if display_devices %then
%include 'smd/fifo_wait.pas';               { SMD_$FIFO_WAIT     }
%include 'smd/touch.pas';                   { SMD_$TOUCH         }
%endif
%endif

{ ---- OS_INIT_PROC ---- }
%if display_driver %then
%if display_devices %then
%include 'smd/add_device.pas';              { SMD_$ADD_DEVICE    }
%endif
%include 'smd/init.pas';                    { SMD_$INIT          }
%include 'smd/init_blink.pas';              { SMD_$INIT_BLINK    }
%include 'smd/cold_init.pas';               { SMD_$COLD_INIT     }
%include 'smd/install_disp_mem.pas';        { SMD_$INSTALL_DISP_MEM }
%endif

{ ---- .TEXT ---- }
%include 'smd/validate_unit.pas';           { smd_$validate_unit }
%if display_driver %then
%if display_devices %then
%include 'smd/nop1.pas';                    { SMD_$NOP1          }
%include 'smd/nop_video.pas';               { SMD_$NOP_VIDEO     }
%include 'smd/nop_crsr.pas';                { SMD_$NOP_CRSR      }
%include 'smd/nop_lock.pas';                { SMD_$NOP_LOCK      }
%include 'smd/nop_map.pas';                 { SMD_$NOP_MAP       }
%include 'smd/nop_unmap.pas';               { SMD_$NOP_UNMAP     }
%include 'smd/nop_assoc.pas';               { SMD_$NOP_ASSOC     }
%include 'smd/nop_logo.pas';                { SMD_$NOP_LOGO      }
%include 'smd/nop_color.pas';               { SMD_$NOP_COLOR     }
%include 'smd/nop_devinfo.pas';             { SMD_$NOP_DEVINFO   }
%include 'smd/nop_sharedev.pas';            { SMD_$NOP_SHAREDEV  }
%include 'smd/nop_close.pas';               { SMD_$NOP_CLOSE     }
%endif
%include 'smd/reset_unit_display.pas';      { smd_$reset_unit_display }
%include 'smd/reset_display_globals.pas';   { smd_$reset_display_globals }
%include 'smd/assoc.pas';                   { SMD_$ASSOC         }
%include 'smd/alloc_hdm.pas';               { SMD_$ALLOC_HDM     }
%include 'smd/free_hdm.pas';                { SMD_$FREE_HDM      }
%if not display_devices %then
%include 'smd/load_font.pas';               { SMD_$LOAD_FONT     }
%include 'smd/unload_font.pas';             { SMD_$UNLOAD_FONT   }
%include 'smd/invert_s.pas';                { SMD_$INVERT_S      }
%endif
%endif
%include 'smd/inq_disp_type.pas';           { SMD_$INQ_DISP_TYPE }
%if display_driver %then
%if not display_devices %then
%include 'smd/ws_init.pas';                 { SMD_$WS_INIT       }
%include 'smd/util_init.pas';               { SMD_$UTIL_INIT     }
%include 'smd/draw_box.pas';                { SMD_$DRAW_BOX      }
%include 'smd/cursor_op.pas';               { smd_$cursor_op     }
%include 'smd/display_cursor.pas';          { SMD_$DISPLAY_CURSOR }
%include 'smd/clear_cursor.pas';            { SMD_$CLEAR_CURSOR  }
%endif
%include 'smd/inq_kbd_cursor.pas';          { SMD_$INQ_KBD_CURSOR }
%include 'smd/inq_kbd_type.pas';            { SMD_$INQ_KBD_TYPE  }
%include 'smd/set_kbd_type.pas';            { SMD_$SET_KBD_TYPE  }
%include 'smd/show_cursor.pas';             { SHOW_CURSOR        }
%include 'smd/enable_tracking.pas';         { SMD_$ENABLE_TRACKING }
%include 'smd/disable_tracking.pas';        { SMD_$DISABLE_TRACKING }
%include 'smd/set_tp_reporting.pas';        { SMD_$SET_TP_REPORTING }
%include 'smd/add_trk_rects_internal.pas';  { smd_$add_trk_rects_internal }
%include 'smd/clr_and_load_trk_rect.pas';   { SMD_$CLR_AND_LOAD_TRK_RECT }
%include 'smd/add_trk_rect.pas';            { SMD_$ADD_TRK_RECT  }
%include 'smd/del_trk_rect.pas';            { SMD_$DEL_TRK_RECT  }
%include 'smd/clr_trk_rect.pas';            { SMD_$CLR_TRK_RECT  }
%include 'smd/set_cursor_pos.pas';          { SMD_$SET_CURSOR_POS }
%include 'smd/set_unit_cursor_pos.pas';     { SMD_$SET_UNIT_CURSOR_POS }
%include 'smd/move_kbd_cursor.pas';         { SMD_$MOVE_KBD_CURSOR }
%include 'smd/clear_kbd_cursor.pas';        { SMD_$CLEAR_KBD_CURSOR }
%include 'smd/poll_keyboard.pas';           { smd_$poll_keyboard }
%include 'smd/enqueue_event.pas';           { smd_$enqueue_event }
%include 'smd/set_tp_cursor.pas';           { SMD_$SET_TP_CURSOR }
%include 'smd/loc_event.pas';               { SMD_$LOC_EVENT     }
%include 'smd/stop_tp_cursor.pas';          { SMD_$STOP_TP_CURSOR }
%include 'smd/acq_display.pas';             { SMD_$ACQ_DISPLAY   }
%include 'smd/rel_display.pas';             { SMD_$REL_DISPLAY   }
%if not display_devices %then
%include 'smd/blt.pas';                     { SMD_$BLT           }
%include 'smd/inq_mm_blt.pas';              { SMD_$INQ_MM_BLT    }
%endif
%include 'smd/get_idm_event.pas';           { SMD_$GET_IDM_EVENT }
%include 'smd/get_unit_event.pas';          { SMD_$GET_UNIT_EVENT }
%include 'smd/unblank.pas';                 { SMD_$UNBLANK       }
%include 'smd/dm_cond_event_wait.pas';      { SMD_$DM_COND_EVENT_WAIT }
%include 'smd/set_blank_timeout.pas';       { SMD_$SET_BLANK_TIMEOUT }
%include 'smd/inq_blank_timeout.pas';       { SMD_$INQ_BLANK_TIMEOUT }
%include 'smd/signal.pas';                  { SMD_$SIGNAL        }
%if not display_devices %then
%include 'smd/soft_scroll.pas';             { SMD_$SOFT_SCROLL   }
%include 'smd/eof_wait.pas';                { SMD_$EOF_WAIT      }
%include 'smd/wire_mm.pas';                 { SMD_$WIRE_MM       }
%endif
%include 'smd/send_response.pas';           { SMD_$SEND_RESPONSE }
%include 'smd/init_display_state.pas';      { smd_$init_display_state }
%include 'smd/borrow_display.pas';          { SMD_$BORROW_DISPLAY }
%include 'smd/return_display.pas';          { SMD_$RETURN_DISPLAY }
%include 'smd/set_disp_unit.pas';           { SMD_$SET_DISP_UNIT }
%include 'smd/init_state.pas';              { SMD_$INIT_STATE    }
%include 'smd/video_ctl.pas';               { SMD_$VIDEO_CTL     }
%include 'smd/map_display_u.pas';           { SMD_$MAP_DISPLAY_U }
%include 'smd/unmap_display_u.pas';         { SMD_$UNMAP_DISPLAY_U }
%if not display_devices %then
%include 'smd/cond_input_u.pas';            { SMD_$COND_INPUT_U  }
%include 'smd/is_valid_blt_ctl.pas';        { smd_$is_valid_blt_ctl }
%include 'smd/blt_u.pas';                   { SMD_$BLT_U }
%endif
%include 'smd/op_wait_u.pas';               { SMD_$OP_WAIT_U     }
%include 'smd/load_crsr_bitmap.pas';        { SMD_$LOAD_CRSR_BITMAP }
%include 'smd/read_crsr_bitmap.pas';        { SMD_$READ_CRSR_BITMAP }
%include 'smd/get_ec.pas';                  { SMD_$GET_EC        }
%if not display_devices %then
%include 'smd/set_clip_window.pas';         { SMD_$SET_CLIP_WINDOW }
%include 'smd/write_string.pas';            { SMD_$WRITE_STRING  }
%endif
%include 'smd/blink_cursor_callback.pas';   { SMD_$BLINK_CURSOR_CALLBACK }
%include 'smd/clear_screen.pas';            { SMD_$CLEAR_SCREEN  }
%endif
%include 'smd/n_devices.pas';               { SMD_$N_DEVICES     }
%include 'smd/inq_disp_uid.pas';            { SMD_$INQ_DISP_UID  }
%if display_driver %then
%include 'smd/map_display_memory.pas';      { SMD_$MAP_DISPLAY_MEMORY }
%include 'smd/unmap_display_memory.pas';    { SMD_$UNMAP_DISPLAY_MEMORY }
%include 'smd/shutdown.pas';                { SMD_$SHUTDOWN      }
%if display_devices %then
%include 'smd/device_info.pas';             { SMD_$DEVICE_INFO   }
%include 'smd/share_device.pas';            { SMD_$SHARE_DEVICE  }
%endif
%include 'smd/assoc_csrs.pas';              { SMD_$ASSOC_CSRS    }
%include 'smd/dissoc.pas';                  { SMD_$DISSOC        }
%endif
%include 'smd/inq_disp_info.pas';           { SMD_$INQ_DISP_INFO }
%if display_driver %then
%if display_devices %then
%include 'smd/set_color_table.pas';         { SMD_$SET_COLOR_TABLE }
%endif
%include 'smd/display_logo.pas';            { SMD_$DISPLAY_LOGO  }
%endif

{ ---- PROCEDURE$ ---- }
%if display_driver %then
%include 'smd/reschedule_blink_timer.pas';  { smd_$reschedule_blink_timer }
%endif

{ ---- PROC2_DELETE_PRO ---- }
%include 'smd/free_asid.pas';               { SMD_$FREE_ASID     }
