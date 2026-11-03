{ smd/smd.ins.pas - the screen manager display driver (SMD_), for the
  Domain Pascal tree.

  Holds only what the Pascal files use.  Each heading follows how the
  image's callers pass the arguments and how the body reads them;
  Apollo's parameter names (the customer smdu.ins.pas of SR10.2) are
  cited where used. }

const
  { The status the TPAD routines return for a unit outside 1 ..
    SMD_$N_DEVICES, and SMD_$INQ_DISP_INFO's own.  Apollo's customer
    smdu.ins.pas of SR10.2 names it: `smd_$illegal_unit = 16#00130001 ;'
    (its text in stcode.db.10.2, OS / display driver: "invalid display
    unit number"). }
  smd_$illegal_unit = 16#00130001;

type
  { A screen position, as Apollo's customer smdu.ins.pas of SR10.2
    declares it: `smd_$pos_t = PACKED RECORD line: integer ; column:
    integer ; END ;' (Apollo's tpad.ins.pas cites it for its user
    routines' origin and new_crsr).  Two words, line at 0 and column at
    2.  The image moves it as one longword where a whole position is
    meant, as a 4-byte record is moved (TPAD_$SET_UNIT_CURSOR,
    TPAD_$SET_UNIT_MODE, TPAD_$INQUIRE_UNIT, and SMD_$LOC_EVENT's
    by-value argument in TPAD_$DATA); its fields as words (TPAD's column
    and line arithmetic). }
  smd_$pos_t = packed record
    line: integer;                        { 0x00 }
    column: integer;                      { 0x02 }
  end;

  { The display types, as Apollo's customer smdu.ins.pas of SR10.2
    declares them (`smd_$display_type_t = (smd_$none ... ,smd_$mono9);',
    with its comments).  The first word of SMD_$INQ_DISP_INFO's result is
    one: SMD_$INQ_DISP_INFO dispatches on it from 1, and TPAD_$INIT tests
    it against 0, smd_$none. }
  smd_$display_type_t = (smd_$none,        {  0 - none }
                         smd_$bw_15p,      {  1 - DN100 }
                         smd_$bw_19l,      {  2 - DN3xx/4xx }
                         smd_$color_display,  {  3 - DN6xx }
                         smd_$800_color,   {  4 - DN550/560 }
                         smd_$color2_display, {  5 - DN580 }
                         smd_$color3_display, {  6 - DN570 }
                         smd_$bw_14l,      {  7 - reserved }
                         smd_$color4_display, {  8 - DN3000C }
                         smd_$bw4_1280x1024,  {  9 - DN3000M }
                         smd_$color5_display, { 10 - meerkat }
                         smd_$bw5_1024x800,   { 11 - cougar1 }
                         smd_$color6_display, { 12 - matrox or meerkatIII }
                         smd_$color10_display, { 13 - fang }
                         smd_$color7_display,  { 14 - coyote }
                         smd_$mono9);      { 15 - Frodo built-in
                                             monochrome }

  { SMD_$INQ_DISP_INFO's result, 10 bytes (Apollo's inserts have no such
    record).  SMD_$INQ_DISP_INFO clears the ten bytes first, stores the
    type at 0, the two frame-buffer words at 2 and 4 as one longword
    constant, the visible width at 6 and height at
    8.  TPAD_$INIT reads the type, the width and the height.  The words
    are integer: each is only stored or decremented.  The four words
    after the type are one nested record, smd_$disp_dims_t, 8 bytes:
    ASKNODE_$INTERNET_INFO's request 16#55 copies them whole into its
    reply's display entry, the form of a record assignment.  The offsets
    are probed with dpc (dims at 2).  With `display_devices'
    (base/config.ins.pas) the record is 12 bytes: SMD_$INQ_DISP_INFO still
    clears the ten, then copies 12 from the device's routine vector, whose
    +0x70 holds one of these records (smd_internal.ins.pas
    smd_dev_vector_t), so a word at +0x0A nothing else reads. }
  smd_$disp_dims_t = record
    mem_width: integer;                   { 0x00: frame-buffer width }
    mem_height: integer;                  { 0x02: frame-buffer height }
    width: integer;                       { 0x04: visible width }
    height: integer;                      { 0x06: visible height }
  end;

  smd_disp_info_result_t = record
    display_type: smd_$display_type_t;    { 0x00 }
    dims: smd_$disp_dims_t;               { 0x02..0x09 }
%if display_devices %then
    word_0a: integer;                     { 0x0A }
%endif
  end;

  { A keyboard translation table: one character for each raw key code,
    0x100 bytes (the map's tables lie 0x100 apart: SMD_$GERMAN_KTT,
    SMD_$FRENCH_KTT, SMD_$NORWEGIAN_KTT and SMD_$SWEDISH_KTT (two map
    names at one address), SMD_$UK_KTT, SMD_$SWISS_KTT; SMD_$KTT ends
    where GPU_ASM's data starts).  kbd_$fetch_key indexes a table with a
    key as an unsigned word from displacement 0, and SMD_$KTT likewise,
    the result stored as the key: so the index is a char from chr(0) and
    the elements chars. }
  smd_$ktt_t = array[char] of char;
  smd_$ktt_ptr_t = ^smd_$ktt_t;

var
  { SMD_$KTT, MNK_$KTT_PTRS and MNK_$KTT_MAX: map symbols in SMD_WIRED's
    data segment of WIRED_DATA, the data of the hand-written SMD_WIRED
    code (hand assembly).  Another unit's variables, reached by their
    absolute addresses (kbd_$fetch_key, kbd_$set_type).
    - smd_$ktt: the US table.
    - mnk_$ktt_ptrs: eight longwords, one table per keyboard type (the
      map's SMD_$KTT, SMD_$GERMAN_KTT, SMD_$FRENCH_KTT, the
      Norwegian/Swedish table twice, SMD_$UK_KTT, SMD_$KTT again,
      SMD_$SWISS_KTT), 0x20 bytes up to MNK_$KTT_MAX; indexed from 0 by a
      sign-extended word scaled by 4.
    - mnk_$ktt_max: the word 7, compared signed with the index: integer.
    The names are the map's.  KBD (kbd/set_type.pas, kbd/fetch_key.pas)
    reads them; nothing in the translated code writes them. }
  smd_$ktt: extern smd_$ktt_t;
  mnk_$ktt_ptrs: extern array[0..7] of smd_$ktt_ptr_t;
  mnk_$ktt_max: extern integer;

{ SMD_$UNBLANK - note the activity time, and turn the video back on if the
  screen was blanked. }
procedure smd_$unblank; extern;

{ SMD_$LOC_EVENT - take a locator event into the event ring. }
procedure smd_$loc_event(event_type: boolean; unit: integer;
                         pos: smd_$pos_t; buttons: integer);
  options(extern, val_param);

{ SMD_$N_DEVICES - the number of the highest display unit present. }
function smd_$n_devices: integer; extern;

{ SMD_$INQ_DISP_INFO - inquire a display unit's type and sizes. }
procedure smd_$inq_disp_info(in unit: integer;
                             out info: smd_disp_info_result_t;
                             out status: status_$t); extern;

{ }

type
  { A window's limits, as Apollo's customer smdu.ins.pas of SR10.2
    declares them (`smd_$window_limits_t = PACKED RECORD xs: integer;
    xe: integer; ys: integer; ye: integer; END'), the argument of its
    smd_$clear_window_u.  DTTY_$INIT builds one in its frame for
    SMD_$CLEAR_WINDOW (through dtty_$clear_window): whole 16-bit fields,
    word aligned, the layout of a plain record. }
  smd_$window_limits_t = packed record
    xs: integer;                          { 0x00 }
    xe: integer;                          { 0x02 }
    ys: integer;                          { 0x04 }
    ye: integer;                          { 0x06 }
  end;

  { The display's memory as words (DISP1_MEM, a map symbol of the I/O
    definitions, with IODEFS at the same address).  DTTY_$INIT reads two
    status words in it by their absolute addresses: the words at +0x66
    and +0x1EBE6, elements 16#33 and 16#F5F3 from 0.  The bound, 128
    Kbytes, covers both; the map's next symbol is PEB_$M_CTRL_PAGE, so
    the symbol's object may be larger. }
  smd_$disp1_mem_t = array[0..65535] of pinteger;

var
  disp1_mem: extern smd_$disp1_mem_t;

{ SMD_$INQ_DISP_TYPE
  (smd/inq_disp_type.pas; Apollo's heading, smdu.ins.pas). }
function smd_$inq_disp_type(unit: integer): smd_$display_type_t; extern;

{ SMD_$ASSOC - associate a display unit with a process. }
procedure smd_$assoc(in unit: integer; in asid: pinteger;
                     out status: status_$t); extern;

{ SMD_$CLEAR_WINDOW (map symbol, in .DATA: a hand-written entry that
  jumps to the routine that does the work): the arguments stay on the
  stack for that routine.  dtty_$clear_window passes its window slot and
  its status: by address.  Apollo's smd_$clear_window_u takes `IN
  window_desc: smd_$window_limits_t; OUT status: status_$t'; the
  kernel's entry is taken to have the same. }
procedure smd_$clear_window(in window_desc: smd_$window_limits_t;
                            out status: status_$t); extern;

{ SMD_$COPY_FONT_TO_MD_HDM - copy the boot font into the monochrome
  display's hidden memory.  font_ptr is `var': with `display_devices'
  (base/config.ins.pas) the routine passes it on to the device by
  address; its one caller passes its own `var'. }
function smd_$copy_font_to_md_hdm(var font_ptr: univ_ptr;
                                  out status: status_$t): integer; extern;

{ }

{ SMD_$LITES (compiled, the last routine of SMD's WIRED_PROC segment,
  global): the body pushes its two word slots by value to the
  hand-written DISP_LITES (misc/m68k/disp_lites.s).  MEM_LITES pushes
  two words, by value, no pad: `val_param'. }
procedure smd_$lites(pattern: pinteger; y_pos: pinteger);
  options(extern, val_param);

{ }

const
  { Apollo's customer smdu.ins.pas of SR10.2 (`smd_$illegal_caller =
    16#00130004 ;', `smd_$unsupported_font_ver = 16#0013000B ;'), stored
    by SMD_$COPY_FONT_TO_MD_HDM. }
  smd_$illegal_caller = 16#00130004;
  smd_$unsupported_font_ver = 16#0013000B;

{ SMD_$PUTC - put a character on the display.  With `display_devices'
  (base/config.ins.pas) it passes a longword by address and the
  character on to every unit's device. }
%if display_devices %then
procedure smd_$putc(var arg_1: integer32; in c: integer); extern;
%else
procedure smd_$putc(in c: integer); extern;
%endif

{ SMD_$BUSY_WAIT - wait while the display is busy.  With
  `display_devices' the first argument is the unit. }
%if display_devices %then
procedure smd_$busy_wait(in unit: integer; out status: status_$t);
  extern;
%else
procedure smd_$busy_wait(in param1: integer32; out status: status_$t);
  extern;
%endif

%if display_devices %then
{ SMD_$FIFO_WAIT - wait for every unit's display FIFO. }
procedure smd_$fifo_wait; extern;

type
  { SMD_$TOUCH's request: the unit at +6, the words before it not read
    by the driver. }
  smd_touch_req_t = record
    unused_00: array[0..2] of integer;    { 0x00 }
    unit: integer;                        { 0x06 }
  end;

{ SMD_$TOUCH - have a unit's device touch its memory. }
function smd_$touch(var arg_1: integer32; in req: smd_touch_req_t;
                    out status: status_$t): integer32; extern;
%endif

{ SMD_$INIT - initialize the display driver at boot. }
procedure smd_$init; extern;

{ SMD_$INIT_BLINK - set up the cursor blink. }
procedure smd_$init_blink; extern;

{ SMD_$COLD_INIT and SMD_$INSTALL_DISP_MEM
  (smd/cold_init.pas, smd/install_disp_mem.pas). }
procedure smd_$cold_init; extern;
procedure smd_$install_disp_mem; extern;

{ SMD_$ACQ_DISPLAY - acquire the display lock of the caller's unit. }
function smd_$acq_display(in lock_data: integer): integer; extern;

{ SMD_$REL_DISPLAY - release the display lock of the caller's unit. }
procedure smd_$rel_display; extern;

{ }

const
  { Apollo's customer smdu.ins.pas of SR10.2 (`smd_$hdmt_unload_err =
    16#00130006 ;', `smd_$invalid_pos = 16#00130015 ;', `smd_$hdm_full =
    16#00130024 ;'), stored by SMD_$FREE_HDM and SMD_$ALLOC_HDM. }
  smd_$hdmt_unload_err = 16#00130006;
  smd_$invalid_pos = 16#00130015;
  smd_$hdm_full = 16#00130024;

{ SMD_$ALLOC_HDM - allocate space in hidden display memory. }
procedure smd_$alloc_hdm(need: integer; out pos: smd_$pos_t;
                         out status: status_$t); extern;

{ SMD_$FREE_HDM - return space to hidden display memory. }
procedure smd_$free_hdm(ret_size: integer; in pos: smd_$pos_t;
                        out status: status_$t); extern;

{ }

const
  { Three statuses of these routines, by Apollo's customer smdu.ins.pas of
    SR10.2: `smd_$font_not_loaded = 16#00130002 ;' (SMD_$UNLOAD_FONT,
    SMD_$WS_INIT), `smd_$font_table_full = 16#00130003 ;' (SMD_$LOAD_FONT)
    and `smd_$invalid_crsr_number = 16#00130023 ;' (smd_$cursor_op). }
  smd_$font_not_loaded = 16#00130002;
  smd_$font_table_full = 16#00130003;
  smd_$invalid_crsr_number = 16#00130023;

{ SMD_$UNLOAD_FONT - unload a font from hidden display memory. }
procedure smd_$unload_font(in font_id: pinteger; out status: status_$t);
  extern;

{ SMD_$INVERT_S - invert the current process's display. }
procedure smd_$invert_s(out status: status_$t); extern;

{ SMD_$DRAW_BOX - draw a box on the current process's display. }
procedure smd_$draw_box(in box_desc: smd_$window_limits_t;
                        out status: status_$t); extern;

{ SMD_$DISPLAY_CURSOR and SMD_$CLEAR_CURSOR
  (smd/display_cursor.pas, smd/clear_cursor.pas). }
procedure smd_$display_cursor(in cursor_num: integer; in pos: smd_$pos_t;
                              out status: status_$t); extern;
procedure smd_$clear_cursor(in cursor_num: integer; in pos: smd_$pos_t;
                            out status: status_$t); extern;

{ }

const
  { Apollo's smdu.ins.pas of SR10.2: `smd_$string_size = 120 ;' ("max #
    chars passed to write_str") and `smd_$invalid_buffer_size =
    16#0013000C ;'.  SMD_$INQ_KBD_TYPE stores the status, and its frame
    buffer is 0x78 bytes. }
  smd_$string_size = 120;
  smd_$invalid_buffer_size = 16#0013000C;

type
  { Apollo's smdu.ins.pas: `smd_$string_t = ARRAY [1..smd_$string_size]
    OF char ;' (its smd_$write_string_u's `IN str: UNIV smd_$string_t').
    SMD_$INQ_KBD_TYPE's frame buffer, 0x78 bytes, is indexed from 1, and
    the caller's buffer the same way. }
  smd_$string_t = array[1..smd_$string_size] of char;

{ SMD_$INQ_KBD_CURSOR - the current display's cursor position and
  visibility. }
function smd_$inq_kbd_cursor(out pos: smd_$pos_t;
                             out status: status_$t): boolean; extern;

{ SMD_$INQ_KBD_TYPE - the keyboard type string, through KBD. }
procedure smd_$inq_kbd_type(in buf_size: pinteger;
                            out buffer: univ smd_$string_t;
                            out length: pinteger;
                            out status: status_$t); extern;

{ SMD_$SET_KBD_TYPE - set the keyboard type, through KBD. }
procedure smd_$set_kbd_type(in kbd_type: univ smd_$string_t;
                            in length: pinteger;
                            out status: status_$t); extern;

{ SHOW_CURSOR - bring the displayed cursor up to date. }
procedure show_cursor(pos: smd_$pos_t; cursor_num: integer;
                      blocking: boolean); extern;

{ SMD_$ENABLE_TRACKING - turn locator tracking on. }
procedure smd_$enable_tracking(in window_id: integer; in param2: integer32;
                               out status: status_$t); extern;

{ SMD_$DISABLE_TRACKING - turn locator tracking off. }
procedure smd_$disable_tracking(in param1: integer32;
                                out status: status_$t); extern;

{ SMD_$SET_TP_REPORTING - set the touch pad's reporting mode. }
procedure smd_$set_tp_reporting(mode: integer; out status: status_$t);
  extern;

const
  { Apollo's customer smdu.ins.pas of SR10.2: `smd_$bad_tracking_rect =
    16#00130030 ;', `smd_$trkng_list_full = 16#00130031 ;'.
    SMD_$DEL_TRK_RECT stores the first, SMD_$CLR_AND_LOAD_TRK_RECT and
    SMD_$ADD_TRK_RECT the second. }
  smd_$bad_tracking_rect = 16#00130030;
  smd_$trkng_list_full = 16#00130031;

{ SMD_$CLR_TRK_RECT - empty the tracking list. }
procedure smd_$clr_trk_rect(out status: status_$t); extern;

{ SMD_$SET_CURSOR_POS
  (smd/set_cursor_pos.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$set_cursor_pos(in pos: smd_$pos_t; out status: status_$t);
  extern;

{ SMD_$SET_UNIT_CURSOR_POS - make a unit current and move its cursor. }
procedure smd_$set_unit_cursor_pos(in unit: pinteger; in pos: smd_$pos_t;
                                   out status: status_$t); extern;

{ SMD_$MOVE_KBD_CURSOR
  (smd/move_kbd_cursor.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$move_kbd_cursor(in pos: smd_$pos_t; out status: status_$t);
  extern;

{ SMD_$CLEAR_KBD_CURSOR
  (smd/clear_kbd_cursor.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$clear_kbd_cursor(out status: status_$t); extern;

{ }

{ SMD_$SET_TP_CURSOR
  (smd/set_tp_cursor.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$set_tp_cursor(in unit: integer; pos: smd_$pos_t;
                             buttons: integer); extern;

{ SMD_$STOP_TP_CURSOR
  (smd/stop_tp_cursor.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$stop_tp_cursor(unit: pinteger); extern;

{ }

{ SMD_$VIDEO_CTL - turn the calling process's display on or off. }
procedure smd_$video_ctl(in flags: boolean; out status: status_$t); extern;

{ SMD_$INQ_MM_BLT - whether the display can BLT to and from main memory. }
function smd_$inq_mm_blt(out status: status_$t): boolean; extern;

type
  { The first ten bytes of the event records SMD_$GET_UNIT_EVENT and
    SMD_$GET_IDM_EVENT return: the locator position and the event's time,
    as the queue entry holds them (smd/smd_internal.ins.pas
    smd_event_entry_t, +0x00 and +0x04).  SMD_$GET_UNIT_EVENT fills them
    from the entry field by field (the position, then the 6-byte clock
    as one record); SMD_$GET_IDM_EVENT copies the ten bytes from its unit
    record to its caller's as one block, the form of a record
    assignment, which two field assignments would not give.  So a record
    of its own in both.  Probed with dpc: pos
    +0, timestamp +4, 10 bytes. }
  smd_event_hdr_t = record
    pos: smd_$pos_t;                      { 0x00 }
    timestamp: time_$clock_t;             { 0x04 }
  end;

  { The event SMD_$GET_UNIT_EVENT returns, 14 bytes: the header (above),
    the unit at +0xA, and at +0xC the buttons as a word, or a character
    and its modifier byte by byte: a variant part as the queue entry's
    (ref 3.10.4).  The whole record is copied to the caller's as a block
    of 14 bytes.  SMD_$GET_IDM_EVENT reads +0xC as a word and as two
    bytes.  Probed with dpc: unit +0xA, button_or_char, char_code +0xC,
    modifier +0xD, 14 bytes. }
  smd_unit_event_t = record
    hdr: smd_event_hdr_t;                 { 0x00 }
    unit: integer;                        { 0x0A }
    case integer of
      0: (button_or_char: integer);       { 0x0C }
      1: (char_code: char;                { 0x0C }
          modifier: char);                { 0x0D }
  end;

  { The event SMD_$GET_IDM_EVENT returns, 12 bytes: the header at +0,
    copied whole (above), and at +0xA the buttons as a word, or the
    character and its modifier as bytes.  SMD_$COND_INPUT_U passes its
    frame's 12 bytes (its status below them).  Probed with dpc: data,
    char_code +0xA, modifier +0xB, 12 bytes. }
  smd_idm_event_t = record
    hdr: smd_event_hdr_t;                 { 0x00 }
    case integer of
      0: (data: integer);                 { 0x0A }
      1: (char_code: char;                { 0x0A }
          modifier: char);                { 0x0B }
  end;

{ SMD_$GET_IDM_EVENT - take the next event off the display's ring in the
  input device manager's form. }
procedure smd_$get_idm_event(out event_type: integer;
                             out idm_data: smd_idm_event_t;
                             out status: status_$t); extern;

{ SMD_$GET_UNIT_EVENT - take the next event off the display's event ring. }
procedure smd_$get_unit_event(out event_type: integer;
                              out event_data: smd_unit_event_t;
                              out status: status_$t); extern;

type
  { The display's mode register, as Apollo's customer smdu.ins.pas of
    SR10.2 declares it ("the Pascal template for the display hardware mode
    register": `smd_$display_modereg_t = PACKED RECORD blt: boolean;
    dummy: 0..63; noninterlace: boolean; from_mm: boolean; to_mm: boolean;
    ieof: boolean; idone: boolean; nonconform: boolean; decr: boolean;
    clrmode: boolean; dispon: boolean; END', with its comments: 8000 blt,
    7E00 the pad, 100 noninterlace, 80 from_mm, 40 to_mm, 20 ieof, 10
    idone, 8 nonconform, 4 decr, 2 clrmode, 1 dispon), one word, the
    fields from bit 15 down.  SMD_$BLT tests the mode word of its argument
    by these bits in the word's low byte (idone, from_mm by the byte's
    sign, to_mm, nonconform), its sign as blt, and builds the
    controller's word field by field (smd/blt.pas).  Probed with dpc: 2
    bytes. }
  smd_$display_modereg_t = packed record
    blt: boolean;                         { 8000 }
    dummy: 0..63;                         { 7E00 }
    noninterlace: boolean;                {  100 }
    from_mm: boolean;                     {   80 }
    to_mm: boolean;                       {   40 }
    ieof: boolean;                        {   20 }
    idone: boolean;                       {   10 }
    nonconform: boolean;                  {    8 }
    decr: boolean;                        {    4 }
    clrmode: boolean;                     {    2 }
    dispon: boolean;                      {    1 }
  end;

  { A BLT request, as Apollo's customer smdu.ins.pas of SR10.2 declares
    it (`smd_$blt_regs_t = PACKED RECORD mode: pinteger; cs: linteger;
    cd: linteger; ssy: pinteger; ssx: pinteger; sdy: pinteger; sdx:
    pinteger; esy: pinteger; esx: pinteger; edy: pinteger; edx: pinteger;
    END', the argument of its smd_$blt_u; its comments: mode register,
    control (source), control (dest), start source y/x, start destination
    y/x, end source y/x, end destination y/x), 0x1A bytes.  SMD_$BLT reads
    the mode at +0, cs at +2 whole, ssy and ssx at +0xA as one longword,
    sdy at +0xE and sdx at +0x10 (both also as one longword), edy at
    +0x16 and edx at +0x18.  The mode is Apollo's pinteger there; the
    kernel's routines read it as the mode register's record (above):
    smd/blt.pas's local of that type is assigned from it with a type
    transfer.  Probed with dpc: the offsets above, 0x1A bytes. }
  smd_$blt_regs_t = packed record
    mode: pinteger;                       { 0x00 }
    cs: linteger;                         { 0x02 }
    cd: linteger;                         { 0x06 }
    ssy: pinteger;                        { 0x0A }
    ssx: pinteger;                        { 0x0C }
    sdy: pinteger;                        { 0x0E }
    sdx: pinteger;                        { 0x10 }
    esy: pinteger;                        { 0x12 }
    esx: pinteger;                        { 0x14 }
    edy: pinteger;                        { 0x16 }
    edx: pinteger;                        { 0x18 }
  end;

{ SMD_$BLT - start a bit-block transfer on the current process's display.
  With `blt_main_memory' (base/config.ins.pas) the main-memory buffer's
  address and page count go on to SMD_$WIRE_MM; the other form reads
  neither. }
procedure smd_$blt(in blt_regs: smd_$blt_regs_t; in mm_va: integer32;
                   in mm_pages: pinteger; out status: status_$t); extern;

const
  { The status SMD_$BLT stores for a transfer the display cannot do.
    Apollo's customer smdu.ins.pas of SR10.2 names it:
    `smd_$not_implemented = 16#00130028 ;' (its text in stcode.db.10.2:
    "non-conforming and main memory blts not implemented", the three
    mode bits SMD_$BLT refuses). }
  smd_$not_implemented = 16#00130028;

  { The status SMD_$WIRE_MM stores for more pages than the display record
    holds (`blt_main_memory').  Apollo's customer smdu.ins.pas of SR10.2
    names it: `smd_$too_many_pages = 16#0013000A ;'. }
  smd_$too_many_pages = 16#0013000A;

  { The status the routines that draw into display memory return for a
    color display (`color_displays', base/config.ins.pas: SMD_$WS_INIT,
    SMD_$UTIL_INIT, SMD_$INVERT_S, SMD_$BLT, SMD_$SOFT_SCROLL,
    SMD_$EOF_WAIT on the SAU4..SAU6).  Apollo's customer smdu.ins.pas of
    SR10.2 names it: `smd_$not_on_color = 16#00130027 ;'. }
  smd_$not_on_color = 16#00130027;

const
  { Apollo's customer smdu.ins.pas of SR10.2: `smd_$max_event_data_size =
    32 ;' ("max # words in event data buffer"), the bound of the event
    data's signal arm (below). }
  smd_$max_event_data_size = 32;

type
  { An event's data words, the DM's request words or a unit number from
    +0 (SMD_$DM_COND_EVENT_WAIT): the signal arm of Apollo's
    smd_$event_data_t (customer smdu.ins.pas of SR10.2: `smd_$signal:
    (dbuf: ARRAY [1..smd_$max_event_data_size] OF pinteger)'), declared
    alone.  Apollo's record and its tag type smd_$event_t cannot be
    declared here: smd_$event_t's enumerator smd_$signal is the name of
    the map's routine SMD_$SIGNAL (Pascal identifiers ignore case), so
    the kernel's SMD unit did not have that enumeration in scope under
    that name.  The event codes are numbers in the code
    (smd/dm_cond_event_wait.pas, which gives smdu's names for them). }
  smd_event_dbuf_t = array[1..smd_$max_event_data_size] of pinteger;

{ SMD_$DM_COND_EVENT_WAIT
  (smd/dm_cond_event_wait.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$dm_cond_event_wait(out event_type: integer;
                                  out data: univ smd_event_dbuf_t;
                                  out data_size: pinteger;
                                  out status: status_$t); extern;

{ SMD_$SET_BLANK_TIMEOUT and SMD_$INQ_BLANK_TIMEOUT
  (smd/set_blank_timeout.pas, smd/inq_blank_timeout.pas). }
procedure smd_$set_blank_timeout(in param1: integer32;
                                 in timeout: time_$clock_t;
                                 out status: status_$t); extern;
procedure smd_$inq_blank_timeout(in param1: integer32;
                                 out timeout: time_$clock_t;
                                 out status: status_$t); extern;

{ }

const
  { SMD_$EOF_WAIT's status for a quit of the waiting process.  Apollo's
    customer smdu.ins.pas of SR10.2 names it: `smd_$quit_while_waiting =
    16#00130022 ;'. }
  smd_$quit_while_waiting = 16#00130022;

{ SMD_$EOF_WAIT - wait for the display's next end of frame, or a quit. }
procedure smd_$eof_wait(out status: status_$t); extern;

{ SMD_$WIRE_MM - wire main memory for display use.  With
  `blt_main_memory' (base/config.ins.pas) the buffer's address, its
  page count (compared unsigned) and the display unit, each read
  through its address; the other form reads none of them. }
procedure smd_$wire_mm(in va: integer32; in npages: pinteger;
                       in unit: pinteger;
                       out status: status_$t); extern;

{ SMD_$SEND_RESPONSE - answer a pending borrow request and wake the
  borrower. }
procedure smd_$send_response(in response: boolean); extern;

const
  { The statuses of SMD_$BORROW_DISPLAY and SMD_$RETURN_DISPLAY, with
    the names and values of Apollo's customer smdu.ins.pas of SR10.2:
    `smd_$borrow_error = 16#0013000E ;' (the crash status of
    SMD_$BORROW_DISPLAY, a cell after its code), `smd_$access_denied =
    16#00130010 ;', `smd_$not_borrowed = 16#00130012 ;'
    (SMD_$RETURN_DISPLAY), `smd_$already_borrowed = 16#00130014 ;',
    `smd_$not_mapped = 16#00130021 ;' (SMD_$RETURN_DISPLAY compares
    SMD_$UNMAP_DISPLAY_U's status with it). }
  smd_$borrow_error = 16#0013000E;
  smd_$access_denied = 16#00130010;
  smd_$not_borrowed = 16#00130012;
  smd_$already_borrowed = 16#00130014;
  smd_$not_mapped = 16#00130021;

{ SMD_$BORROW_DISPLAY
  (smd/borrow_display.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$borrow_display(in unit: integer; in full: boolean;
                              out status: status_$t); extern;

{ SMD_$RETURN_DISPLAY - give a borrowed display unit back. }
procedure smd_$return_display(in unit: integer;
                              out status: status_$t); extern;

{ SMD_$SET_DISP_UNIT - make a display unit the calling process's. }
procedure smd_$set_disp_unit(in unit: integer;
                             out status: status_$t); extern;

{ SMD_$INIT_STATE - put the caller's display back in its initial state. }
procedure smd_$init_state(out status: status_$t); extern;

{ SMD_$UNMAP_DISPLAY_U
  (smd/unmap_display_u.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$unmap_display_u(out status: status_$t); extern;

{ }

const
  { The statuses SMD_$BLT_U stores, as Apollo's customer smdu.ins.pas of
    SR10.2 names them: `smd_$invalid_blt_mode = 16#0013001A ;',
    `smd_$invalid_blt_ctl = 16#0013001B ;', `smd_$invalid_blt_coord =
    16#0013001E ;'. }
  smd_$invalid_blt_mode = 16#0013001A;
  smd_$invalid_blt_ctl = 16#0013001B;
  smd_$invalid_blt_coord = 16#0013001E;

{ SMD_$COND_INPUT_U
  (smd/cond_input_u.pas; Apollo's heading, smdu.ins.pas). }
function smd_$cond_input_u(out ch: char): boolean; extern;

{ smd_$is_valid_blt_ctl, SMD_$BLT_U - check a user's BLT request and start
  it. }
procedure smd_$blt_u(in blt_regs: smd_$blt_regs_t; out status: status_$t);
  extern;

{ SMD_$OP_WAIT_U - wait for the display's current scroll or BLT to end. }
procedure smd_$op_wait_u; extern;

{ }

const
  { The statuses of SMD_$LOAD_CRSR_BITMAP's size test and SMD_$GET_EC's
    otherwise part, as Apollo's customer smdu.ins.pas of SR10.2 names
    them: `smd_$invalid_displacement = 16#00130019 ;' and
    `smd_$invalid_key = 16#00130026 ;'. }
  smd_$invalid_displacement = 16#00130019;
  smd_$invalid_key = 16#00130026;

{ SMD_$SET_CLIP_WINDOW - set the display's clipping window. }
procedure smd_$set_clip_window(in clip_rect: smd_$window_limits_t;
                               out status: status_$t); extern;

{ SMD_$WRITE_STRING - write a string on the display, clipped to the
  display's limits. }
procedure smd_$write_string(pos: smd_$pos_t; in font_id: pinteger;
                            in str: univ smd_$string_t;
                            str_len: pinteger; in scroll_wait: boolean;
                            out status: status_$t); extern;

{ SMD_$BLINK_CURSOR_CALLBACK - the cursor-blink timer's routine. }
procedure smd_$blink_cursor_callback; extern;

{ }

type
  { The logo SMD_$DISPLAY_LOGO copies: 150 rows of 32 words.  The body
    reads element [row, col] off the pointer plus row * 64, at (col - 1)
    * 2 less 0x40: rows of 64 bytes from [1, 1]. }
  smd_logo_t = array[1..150] of array[1..32] of pinteger;
  smd_logo_ptr_t = ^smd_logo_t;

{ SMD_$CLEAR_SCREEN - clear the screen.  With `display_devices' it has
  no parameter: its callers (dtty_$clear_window, SMD_$SHUTDOWN) push
  none. }
%if display_devices %then
procedure smd_$clear_screen; extern;
%else
procedure smd_$clear_screen(out status: status_$t); extern;
%endif

{ SMD_$INQ_DISP_UID - inquire a display unit's UID. }
procedure smd_$inq_disp_uid(in unit: integer;
                            out uid: uid_$t;
                            out status: status_$t); extern;

{ SMD_$MAP_DISPLAY_MEMORY and SMD_$UNMAP_DISPLAY_MEMORY
  (smd/map_display_memory.pas, smd/unmap_display_memory.pas). }
%if display_devices %then
procedure smd_$map_display_memory(in unit: integer; in arg_2: integer32;
                                  in arg_3: integer32; out va: univ_ptr;
                                  out status: status_$t); extern;
procedure smd_$unmap_display_memory(in unit: integer; in arg_2: integer32;
                                    in arg_3: integer32; in va: univ_ptr;
                                    out status: status_$t); extern;
%else
procedure smd_$map_display_memory(in param1: integer32;
                                  in param2: integer32;
                                  in param3: integer32;
                                  in param4: integer32;
                                  out status: status_$t); extern;
procedure smd_$unmap_display_memory(in param1: integer32;
                                    in param2: integer32;
                                    in param3: integer32;
                                    in param4: integer32;
                                    out status: status_$t); extern;
%endif

{ SMD_$SHUTDOWN - shut the display driver down. }
procedure smd_$shutdown; extern;

%if display_devices %then
{ SMD_$DEVICE_INFO - ask a unit's device for information. }
procedure smd_$device_info(in unit: integer; in arg_1: integer32;
                           var arg_2: integer32; var arg_3: integer32;
                           out status: status_$t);
  extern;

{ SMD_$SHARE_DEVICE - ask a unit's device to share the display. }
procedure smd_$share_device(in unit: integer; in arg_1: integer;
                            out status: status_$t);
  extern;
%endif

{ SMD_$ASSOC_CSRS and SMD_$DISSOC (smd/assoc_csrs.pas, smd/dissoc.pas).
  With `display_devices' the first argument is the unit, read as a
  word, and SMD_$ASSOC_CSRS passes its second's address on to the
  device's assoc routine, which returns an address in it. }
%if display_devices %then
procedure smd_$assoc_csrs(in unit: integer; out va: univ_ptr;
                          out status: status_$t); extern;
procedure smd_$dissoc(in unit: integer; out status: status_$t); extern;
%else
procedure smd_$assoc_csrs(in param1: integer32;
                          in param2: integer32;
                          out status: status_$t); extern;
procedure smd_$dissoc(in param1: integer32;
                      out status: status_$t); extern;
%endif

%if display_devices %then
{ SMD_$SET_COLOR_TABLE - set a unit's color table. }
procedure smd_$set_color_table(in unit: integer; in arg_1: integer;
                               in arg_2: integer; var flag: boolean;
                               out status: status_$t);
  extern;
%endif

{ SMD_$ADD_DEVICE - add a display device as the next display unit
  (smd/add_device.pas; its caller MONO9_$IOINIT).  The device's count of
  special segments, an unsigned word, and its descriptor's address, by
  value; the driver keeps the descriptor and its routine vector (the
  descriptor's longword at 0x2C). }
procedure smd_$add_device(n_units: pinteger; dcte: univ_ptr);
  options(extern, val_param);

{ SMD_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure smd_$display_logo(in unit: integer;
                            in logo_data: smd_logo_ptr_t;
                            out status: status_$t); extern;

{ SMD_$FREE_ASID - release an address space's hold on the displays. }
procedure smd_$free_asid(asid: integer);
  options(extern, val_param);

%if gpu_driver %then
{ SMD_$GRAPHIC_DEVICE_ID (map symbol in SMD_WIRED's hand-written data,
  the SAU5 and SAU6): the graphics board's id word, which SMD_$INIT
  reads from the board (zero when there is none).  SMD_$INIT takes id 2
  as the DN580's color display (smd_$color2_display, DISPLAY3_$UID's
  memory) and id 1 as the DN570's (smd_$color3_display); OS_$INIT and
  OS_$SHUTDOWN compare it as a word. }
const
  smd_gdev_color3 = 1;
  smd_gdev_color2 = 2;
var
  smd_$graphic_device_id: extern integer;
%endif
