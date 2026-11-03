{ smd/smd_internal.ins.pas - the SMD module's own declarations (the display
  driver's records, the overlay section SMD_$WIRED_DATA, the hand-written
  SMD_WIRED data and entries the compiled code reaches, and the SMD
  module's routine headings), for the Domain Pascal tree.

  A file of its own, not smd/smd.ins.pas: these declarations need
  ec/ec.ins.pas, ml/ml.ins.pas, time/time.ins.pas, proc1/proc1.ins.pas
  and smd/smd.ins.pas before it, and smd/smd.ins.pas's users (kbd, dtty,
  tpad, term, suma, misc) include it after base alone.  Only smd/smd.pas
  includes this file.

  Apollo's customer smdu.ins.pas of SR10.2 (sys/ins/smdu.ins.pas,
  "Display driver definitions - for users and display manager") declares
  some of the types the records use; those are copied here with its
  names and definitions and cited.  The records themselves are checked
  field by field against the image; Apollo's inserts have no kernel-side
  records. }

const
  { The number of display units: the bound of the unit records
    (smd_$wired_data_t) and of the display records (SMD_$DISPLAY_COM),
    the last unit smd_$validate_unit accepts, and the count of the unit
    loops (SMD_$INIT, SMD_$DM_COND_EVENT_WAIT, SMD_$FREE_ASID).  One on
    the SAU2, two with `two_display_units' (base/config.ins.pas), eight
    with `display_devices', where the units are the devices' and their
    count is in SMD_$WIRED_DATA (smd_$wired_data_t, below). }
%if display_devices %then
  smd_unit_count = 8;
%elseif two_display_units %then
  smd_unit_count = 2;
%else
  smd_unit_count = 1;
%endif

type
  { (From Apollo's smdu.ins.pas.)  The scroll direction: `smd_$direction_t
    = (smd_$up, smd_$down, smd_$left, smd_$right) ;', the type of
    smd_$soft_scroll_u's `IN direction'.  SMD_$SOFT_SCROLL stores its
    direction argument's word in the display record (scroll_dx, below);
    0..3 in this order of meaning: the content moves up for 0. }
  smd_$direction_t = (smd_$up, smd_$down, smd_$left, smd_$right);

  { (From Apollo's smdu.ins.pas.)  The display memory: `smd_$display_
    memory_t = ARRAY [0..1023] OF ARRAY [0..63] OF pinteger ;' and
    `smd_$display_memory_ptr_t = ^smd_$display_memory_t ;', the result of
    smd_$map_display_u.  The display unit record's display_base holds the
    map's DISP1_MEM (SMD_$INIT), and SMD_$DISPLAY_LOGO and SMD_$INVERT_S
    read it as a base pointer. }
  smd_$display_memory_t = array[0..1023] of array[0..63] of pinteger;
  smd_$display_memory_ptr_t = ^smd_$display_memory_t;

  { The display memory of a 2048-pixel-wide display seen as 1024 rows of
    128 words (256 bytes a row), the view SMD_$DISPLAY_LOGO writes through
    for display types 5 and 9 (smd_$color2_display, smd_$bw4_1280x1024):
    the element's address display_base + row * 256 + ..., against
    smd_$display_memory_t's 128-byte rows for the others.  0x40000 bytes,
    display_map_length's entry for types 5 and 9 (smd.pas).  Reached by a
    type transfer of the unit's display_base (smd/display_logo.pas). }
  smd_wide_memory_t = array[0..1023] of array[0..127] of pinteger;
  smd_wide_memory_ptr_t = ^smd_wide_memory_t;

  { (From Apollo's smdu.ins.pas.)  A cursor's bitmap, one word per raster
    line: `smd_$cursor_bitmap_t = ARRAY[1..16] OF pinteger;', the type of
    smd_$load_crsr_bitmap's `IN bitmap' and smd_$read_crsr_bitmap's `OUT
    bitmap'.  The cursor pattern's last 0x20 bytes (below). }
  smd_$cursor_bitmap_t = array[1..16] of pinteger;

  { (From Apollo's smdu.ins.pas.)  A DM request: `smd_$request_t = ARRAY
    [1..smd_$max_request_size] OF pinteger ;' with `smd_$max_request_size
    = 16 ;' ("max # words passed in req buf"), the request entry's
    parameters (below). }
  smd_$request_t = array[1..16] of pinteger;

  { (From Apollo's smdu.ins.pas.)  A font's header as the display manager
    builds it: `smd_$font_table_t = PACKED RECORD version: pinteger;
    image_offset: pinteger; chars_in_font ... max_down: pinteger;
    index_table: ARRAY [0..127] OF char; desc_table: ARRAY [1..127] OF
    smd_$v1_fdte_t; END;' with its descriptor entry `smd_$v1_fdte_t =
    PACKED RECORD left, right, up, down, width, x_pos: char; y_pos:
    pinteger; END;', and `smd_$font_table_ptr_t = ^smd_$font_table_t ;',
    the type of smd_$load_font_u's `IN table_ptr: UNIV smd_$font_table_
    ptr_t'.  The font entry's pointer (below) has this type; the header's
    layout: version 0x00, the thirteen words to 0x1A, the index table
    0x1A, the 8-byte descriptors from 0x9A. }
  smd_$v1_fdte_t = packed record
    left: char;                           { 0x00 }
    right: char;                          { 0x01 }
    up: char;                             { 0x02 }
    down: char;                           { 0x03 }
    width: char;                          { 0x04 }
    x_pos: char;                          { 0x05 }
    y_pos: pinteger;                      { 0x06 }
  end;

  smd_$font_table_t = packed record
    version: pinteger;                    { 0x00 }
    image_offset: pinteger;               { 0x02 }
    chars_in_font: pinteger;              { 0x04 }
    raster_lines: pinteger;               { 0x06 }
    image_size: pinteger;                 { 0x08 }
    max_height: pinteger;                 { 0x0A }
    max_width: pinteger;                  { 0x0C }
    v_spacing: pinteger;                  { 0x0E }
    h_spacing: pinteger;                  { 0x10 }
    space_size: pinteger;                 { 0x12 }
    max_right: pinteger;                  { 0x14 }
    max_up: pinteger;                     { 0x16 }
    max_down: pinteger;                   { 0x18 }
    index_table: array[0..127] of char;   { 0x1A }
    desc_table: array[1..127] of smd_$v1_fdte_t;  { 0x9A }
  end;

  smd_$font_table_ptr_t = ^smd_$font_table_t;

  { The display controller's registers as the compiled code reaches them:
    the one word at +0, through the unit record's ctrl_regs (SMD_$INIT
    stores the SAU2's DISP1).  SMD_$EOF_WAIT writes it,
    smd_$init_display_state likewise, and the hand-written scroll and BLT
    bodies start the BLT by storing it (smd/sau2/scroll.s, start_blt.s).
    No compiled code reads another offset of the block.  The bits are
    those of Apollo's smd_$display_modereg_t ("the Pascal template for the
    display hardware mode register", smdu.ins.pas: 8000 blt, 100
    noninterlace, 80 from_mm, 40 to_mm, 20 ieof, 10 idone, 8 nonconform,
    4 decr, 2 clrmode, 1 dispon); 16#21 is ieof and dispon.  The field is
    a word here; which type the routines' stores need is theirs to settle
. }
  smd_ctrl_regs_t = [device] record
    mode: pinteger;                       { 0x00 }
  end;
  smd_ctrl_regs_ptr_t = ^smd_ctrl_regs_t;

%if gpu_driver %then
  { The graphics board's control block (KOLOR_CTL, below) as SMD_$INIT
    reaches it: its address taken for TESTPAGE and stored as unit 1's
    ctrl_regs, and the board's id word at +2 read.  The COLOR2_ module's
    routines (color2/color2.pas) reach more of it: the command FIFO
    word at +0x3000 (with the words at +0x3002, +0x3004 and +0x3640 for
    the DN580's cursor load), the word at +0x7008 (its bit 15 cleared
    while waiting), the control word at +0x700C (member 3 the DN580's
    video, 2, 6 and 7 the graphics processor's interrupt: bits only set
    and cleared, word-wide, so a word and masks), the DN580's
    status at +0x700E (members 15 busy, 14 done, 7, and the field of
    members 1 and 2), the DN570's control at +0x7020 (written from
    COLOR3_$CR_CONTENTS), its status at +0x7030 (members 14, 13, 11 and
    10, and the low four bits) and the FIFO's free count at +0x7040.
    Word sets for the bit tests. }
  smd_kolor_ctl_t = [device] record
    mode: pinteger;                                   { 0x0000 }
    device_id: integer;                               { 0x0002 }
    unused_0004: array[2..6143] of pinteger;          { 0x0004 }
    fifo: pinteger;                                   { 0x3000 }
    fifo_3002: pinteger;                              { 0x3002 }
    fifo_3004: pinteger;                              { 0x3004 }
    unused_3006: array[6147..6943] of pinteger;       { 0x3006 }
    reg_3640: pinteger;                               { 0x3640 }
    unused_3642: array[6945..14339] of pinteger;      { 0x3642 }
    reg_7008: set of 0..15;                           { 0x7008 }
    unused_700a: pinteger;                            { 0x700A }
    ctl: set of 0..15;                                { 0x700C }
    status: set of 0..15;                             { 0x700E }
    unused_7010: array[14344..14351] of pinteger;     { 0x7010 }
    cr: pinteger;                                     { 0x7020 }
    unused_7022: array[14353..14359] of pinteger;     { 0x7022 }
    status_7030: set of 0..15;                        { 0x7030 }
    unused_7032: array[14361..14367] of pinteger;     { 0x7032 }
    fifo_count: pinteger;                             { 0x7040 }
  end;
%endif

%if color_board %then
  { The color board's supervisor page (COLOR_SUP, below) as SMD_$INIT
    reaches it: the command word at +0 (written 8, 9, 8, 14 in turn), the
    status word at +2 (its bit 13 waited on), and at +0xC2 a word whose
    bit 1 tells the 800-line board (smd_$800_color) from the other
    (smd_$color_display, with the control store's word); and the word at
    +0x90, which SMD_$COPY_FONT_TO_MD_HDM sets to 7 around its copy into
    the board's memory and clears after it.  Word sets for the bit tests
    (ref 3.9.3).  The COLOR_ module's routines (color/color.pas) reach
    the page too: the status's members 12 (the board ready), 13 (the
    instruction queue busy) and 7 (the color map busy), the words at
    +0x80 (its high nibble 16#F0 when the board takes a cursor), +0x90
    (COLOR_$LOAD_CRSR's flag), +0x98 (the color map's strobe), +0xA0
    (the interrupt control, a word set: member 1 the instruction queue's
    interrupt) and +0xA4 (the interrupt vector); the color map's entries overlay the
    page from +0x80, a longword each (the second variant, written through
    COLOR_$LOAD_MAP). }
  smd_color_sup_t = [device] record
    case integer of
      1: (command: pinteger;                      { 0x00 }
          status: set of 0..15;                   { 0x02 }
          unused_04: array[2..63] of pinteger;    { 0x04 }
          field_80: pinteger;                     { 0x80 }
          unused_82: array[65..71] of pinteger;   { 0x82 }
          field_90: pinteger;                     { 0x90 }
          unused_92: array[73..75] of pinteger;   { 0x92 }
          map_strobe: pinteger;                   { 0x98 }
          unused_9a: array[77..79] of pinteger;   { 0x9A }
          int_ctl: set of 0..15;                  { 0xA0 }
          unused_a2: pinteger;                    { 0xA2 }
          vector: pinteger;                       { 0xA4 }
          unused_a6: array[83..96] of pinteger;   { 0xA6 }
          config: set of 0..15);                  { 0xC2 }
      2: (unused_00: array[0..63] of pinteger;    { 0x00 }
          map: array[0..32] of integer32);        { 0x80 }
  end;
  smd_color_sup_ptr_t = ^smd_color_sup_t;

  { The color board's control store page (COLOR_CSTORE, below): words;
    SMD_$INIT reads the one at +6. }
  smd_color_cstore_t = [device] array[0..3] of pinteger;
%endif

  { A tracking rectangle, 8 bytes: two X words, then two Y words.
    SHOW_CURSOR's overlap test compares the Y coordinates with the words
    at +4 and +6 and the X with +0 and +2; smd_$reset_display_globals
    copies the keyboard cursor's rectangle into the first slot as two
    longwords.  The image's initial value at SMD block +0xC0 is 0, 16#3FFF,
    0, 16#3FFF.  The same layout as Apollo's smd_$window_limits_t (xs, xe,
    ys, ye); this file keeps a type of its own. }
  smd_track_rect_t = record
    x1: integer;                          { 0x00 }
    x2: integer;                          { 0x02 }
    y1: integer;                          { 0x04 }
    y2: integer;                          { 0x06 }
  end;

  { An event-queue entry, 16 bytes.  smd_$enqueue_event stores, for the
    entry at A5 + 0x72C + 16 * head: the position as one longword at +0,
    the time at +4 through TIME_$CLOCK (an `out' time_$clock_t of 6
    bytes, +4..+9: one time_$clock_t is what TIME_$CLOCK writes), the
    unit at +0xA (its first argument), the event type at +0xC (the
    second) and the buttons or character at +0xE (the fourth).  The word
    at +0xE is also two characters: smd_$poll_keyboard passes +0xE and
    +0xF to KBD_$GET_CHAR_AND_MODE's `out' char_out and mode_out, and
    tests the second byte alone; SMD_$GET_UNIT_EVENT reads the bytes one
    by one, and the word whole.  So a variant part (ref 3.10.4) with the
    word and the two chars. }
  smd_event_entry_t = record
    pos: smd_$pos_t;                      { 0x00 }
    timestamp: time_$clock_t;             { 0x04 }
    unit: integer;                        { 0x0A }
    event_type: integer;                  { 0x0C }
    case integer of
      0: (button_or_char: integer);       { 0x0E }
      1: (char_code: char;                { 0x0E }
          modifier: char);                { 0x0F }
  end;
  smd_event_entry_ptr_t = ^smd_event_entry_t;

  { A DM request, 0x24 bytes: the request type, the parameter count and
    the parameters.  The entries are 36 bytes apart (SMD_$SIGNAL,
    SMD_$DM_COND_EVENT_WAIT). }
  smd_request_entry_t = record
    request_type: integer;                { 0x00 }
    param_count: integer;                 { 0x02 }
    params: smd_$request_t;               { 0x04 }
  end;

  { The DM request ring, the map's SMD_REQUEST_QUEUE (SMD block +0x17F0):
    the two ring indices, then forty entries indexed from 1, the first at
    +0x17F4 = 0x17D0 + 36 (above).  The indices run 1..40 and wrap to 1
    (SMD_$SIGNAL, SMD_$DM_COND_EVENT_WAIT compare with 40); both are 1 in
    the image.  0x5A4 bytes, up to the sentinel at +0x1D94.  tail is the
    read index, head the write index. }
  smd_request_queue_t = record
    tail: integer;                        { 0x00 }
    head: integer;                        { 0x02 }
    entries: array[1..40] of smd_request_entry_t;  { 0x04 }
  end;

  { A loaded font, 8 bytes: the caller's font, nil when the slot is
    free, stored by SMD_$LOAD_FONT, and the font's place in hidden
    display memory, whose address SMD_$LOAD_FONT passes to SMD_$ALLOC_HDM
    and SMD_$UNLOAD_FONT to SMD_$FREE_HDM.  Apollo's smdu.ins.pas declares
    that argument an smd_$pos_t (smd_$alloc_hdm's `OUT pos: smd_$pos_t;',
    "resulting space", smd_$free_hdm's `IN pos'). }
  smd_font_entry_t = record
    font_va: smd_$font_table_ptr_t;       { 0x00 }
    hdm_pos: smd_$pos_t;                  { 0x04 }
  end;

  { A unit's font table: eight entries indexed from 1.  SMD_$INIT stores
    the address of the first entry, SMD block +0x1748, in the unit record,
    and SMD_$LOAD_FONT reaches entry i at that pointer + 8 * i - 8: an
    array from 1 through a pointer to its first element.  Apollo's
    smd_$font_table_t is the font header above. }
  smd_unit_fonts_t = array[1..8] of smd_font_entry_t;
  smd_unit_fonts_ptr_t = ^smd_unit_fonts_t;

  { A free block of hidden display memory, 4 bytes. }
  smd_hdm_block_t = record
    offset: integer;                      { 0x00 }
    size: integer;                        { 0x02 }
  end;

  { The hidden-display-memory free list, 0x66 bytes: the count, then 25
    blocks indexed from 1 at +2.  SMD_$ALLOC_HDM walks it with a pointer
    at list + 4 + 4 * (k - 1), reading the size at +0 and the offset at -2
    from it; SMD_$FREE_HDM bounds the count by 25.  The one list is SMD
    block +0x1788, whose address SMD_$INIT stores in the unit record. }
  smd_hdm_list_t = record
    count: integer;                       { 0x00 }
    blocks: array[1..25] of smd_hdm_block_t;  { 0x02 }
  end;
  smd_hdm_list_ptr_t = ^smd_hdm_list_t;

  { The display record's pending DM requests (+0x4C, below): member 15
    a borrow request, member 14 a return request, which
    SMD_$DM_COND_EVENT_WAIT reports as smd_$borrow_req and smd_$return_req
    and removes (SMD_$BORROW_DISPLAY sets member 15).  A word set (ref
    3.9.3: member k is bit k). }
  smd_hw_event_set_t = set of 0..15;

  { A display's state, 0x60 bytes: the record the unit record's hw
    points at, SMD_$DISPLAY_COM's one element (below).  The fields as
    the image reaches them, from SMD_$INIT's initialization and the
    other users:
    - +0x00 the display type: SMD_$INIT stores 2 when TESTPAGE's boolean
      is true and compares it with 1 and 2; SMD_$INQ_DISP_INFO copies it
      into its result's smd_$display_type_t;
    - +0x02 the lock state (cleared by SMD_$INIT; SMD_$LOCK_DISPLAY,
      smd/m68k/lock_display.s);
    - +0x04, +0x10 two eventcounts (EC_$INIT by SMD_$INIT);
    - +0x1C a longword (cleared; the hand-written BLT start copies op_ec's
      value into it, smd/sau2/start_blt.s);
    - +0x20 a byte (cleared; set by SMD_$ACQ_DISPLAY), +0x21 the byte
      after it (the hand-written code clears the word);
    - +0x22, +0x24 two words, stored as one longword constant by SMD_$INIT
      (+0x22 := 1, +0x24 := 0);
    - +0x26 the scroll window, 8 bytes, which SMD_$SOFT_SCROLL copies as
      two longwords from its window argument: Apollo's
      smd_$window_limits_t (smd_$soft_scroll_u's `IN window_desc');
    - +0x2E the displacement and +0x30 the direction (SMD_$SOFT_SCROLL:
      smd_$soft_scroll_u's `displacement: pinteger' and `direction:
      smd_$direction_t');
    - +0x32 the cursor position, moved as one longword (SHOW_CURSOR;
      cleared by smd_$reset_display_globals);
    - +0x36 the cursor number, +0x38 the cursor-visible boolean (both
      cleared by smd_$reset_display_globals), +0x3A a word, +0x3C the
      tracking flag, a boolean (cleared by SMD_$INIT; SMD_$BORROW_DISPLAY
      sets it: G9), +0x3E a byte (cleared by SMD_$INIT);
    - +0x40 the cursor eventcount (SMD_$INIT; SMD_$SEND_RESPONSE);
    - +0x4C the pending DM requests, a set of 0..15 (smd_hw_event_set_t
      above): cleared whole (SMD_$INIT), tested whole and by member, 14
      by a bit test and 15 by the sign of a copy, and each member removed
      by clearing its bit in the first byte (SMD_$DM_COND_EVENT_WAIT;
      G8);
    - +0x4E the display's limits, 8 bytes: min x, max x, min y, max y
      (SMD_$INIT: 0, 16#31F, 0, 16#3FF for type 1), passed whole by
      address to SMD_$XOR_CURSOR (SHOW_CURSOR, smd_$cursor_op), so a
      record: smd_$window_limits_t's layout (xs, xe, ys, ye);
    - +0x56 the clip window, the same four words (SMD_$SET_CLIP_WINDOW
      clamps them against the limits);
    - +0x5E a word (cleared by SMD_$INIT).
    Byte fields are boolean where the image sets them with a set
    instruction (field_20, cursor_visible), char where it only clears
    them. }
  smd_display_hw_t = record
    display_type: smd_$display_type_t;    { 0x00 }
    lock_state: integer;                  { 0x02 }
    lock_ec: ec_$eventcount_t;            { 0x04 }
    op_ec: ec_$eventcount_t;              { 0x10 }
    field_1c: integer32;                  { 0x1C }
    field_20: boolean;                    { 0x20 }
    field_21: char;                       { 0x21 }
    video_flags: integer;                 { 0x22 }
    field_24: integer;                    { 0x24 }
    scroll_window: smd_$window_limits_t;  { 0x26 }
    scroll_dy: integer;                   { 0x2E }
    scroll_dx: smd_$direction_t;          { 0x30 }
    cursor_pos: smd_$pos_t;               { 0x32 }
    cursor_number: integer;               { 0x36 }
    cursor_visible: boolean;              { 0x38 }
    pad_39: char;                         { 0x39 }
    field_3a: integer;                    { 0x3A }
    tracking_enabled: boolean;            { 0x3C }
    pad_3d: char;                         { 0x3D }
    field_3e: char;                       { 0x3E }
    pad_3f: char;                         { 0x3F }
    cursor_ec: ec_$eventcount_t;          { 0x40 }
    field_4c: smd_hw_event_set_t;         { 0x4C }
    disp_limits: smd_$window_limits_t;    { 0x4E }
    clip_window: smd_$window_limits_t;    { 0x56 }
    field_5e: integer;                    { 0x5E }
  end;
  smd_display_hw_ptr_t = ^smd_display_hw_t;

  { SMD_TIME_$COM's layout, 6 bytes: two booleans at +0 and +2 and a word
    at +4.  Compiled code reaches it by its address (SMD_$INIT_BLINK,
    smd_$reset_display_globals, SHOW_CURSOR, SMD_$BLINK_CURSOR_CALLBACK).
    The bytes at +1 and +3 are the record's pads (word rules would put
    the second boolean at +1); the record is hand-written data, whose
    layout this one only mirrors. }
  smd_time_com_t = record
    blink_enable: boolean;                { 0x00 }
    pad_01: char;                         { 0x01 }
    cursor_painted: boolean;              { 0x02 }
    pad_03: char;                         { 0x03 }
    blink_defer: integer;                 { 0x04 }
  end;

%if display_devices %then
  { With `display_devices' (base/config.ins.pas) the driver reaches each
    display through its device: the device's descriptor (an I/O DCTE,
    io/io.ins.pas's dcte_t up to +0x28) and, through it, the device's
    routine vector, which SMD_$ADD_DEVICE stores in the unit record.
    The descriptor as the driver reads it: the vector's address at +0x2C
    and the device's identity record's at +0x30 (MONO9_$UNIT,
    mono9/mono9_desc.pas, is one). }
  smd_dev_dcte_t = record
    unused_00: array[0..10] of integer32; { 0x00 }
    vector: univ_ptr;                     { 0x2C }
    info: univ_ptr;                       { 0x30 }
  end;
  smd_dev_dcte_ptr_t = ^smd_dev_dcte_t;

  { The device's identity, the first 0x12 bytes of its record (MONO9's
    mono9_$info_t): the UIDs of its display memory and of its special
    object, and the special segment.  SMD_$ADD_DEVICE fills them: the
    high longwords from DISPLAY1_$UID and SPECIAL_SEG_$UID, the low
    longwords the unit's number. }
  smd_dev_info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
  end;
  smd_dev_info_ptr_t = ^smd_dev_info_t;

  { An area of the device's code or data, the start and end addresses
    MST_$WIRE_AREA takes: SMD_$INIT unwires the device's areas. }
  smd_dev_area_t = record
    start_va: univ_ptr;                   { 0x00 }
    end_va: univ_ptr;                     { 0x04 }
  end;
  smd_dev_area_list_t = array[1..1] of smd_dev_area_t;
  smd_dev_area_list_ptr_t = ^smd_dev_area_list_t;

  { The routines of a device's vector: each takes the descriptor's
    address first, by value. }
  smd_dev_proc_t = ^procedure(dcte: univ_ptr); options(val_param);
  smd_dev_status_proc_t =
    ^procedure(dcte: univ_ptr; out status: status_$t);
    options(val_param);
  smd_dev_video_ctl_t = ^procedure(dcte: univ_ptr; on: boolean);
    options(val_param);
  smd_dev_lock_t =
    ^function(dcte: univ_ptr; var hw: smd_display_hw_t;
              kind: integer): boolean; options(val_param);
  smd_dev_blink_t =
    ^procedure(dcte: univ_ptr; var blink: smd_time_com_t;
               var hw: smd_display_hw_t); options(val_param);
  smd_dev_xor_cursor_t =
    ^function(dcte: univ_ptr; cursor_num: integer; pos: smd_$pos_t;
              in limits: smd_$window_limits_t; flag_1: boolean;
              flag_2: boolean): boolean; options(val_param);
  smd_dev_rel_t = ^procedure(dcte: univ_ptr; var hw: smd_display_hw_t);
    options(val_param);
  smd_dev_close_t = ^procedure(dcte: univ_ptr; asid: integer);
    options(val_param);
  smd_dev_load_crsr_t =
    ^procedure(dcte: univ_ptr; cnum: integer; size: integer;
               hot_x: integer; hot_y: integer;
               in bitmap: smd_$cursor_bitmap_t); options(val_param);
  smd_dev_copy_font_t =
    ^function(dcte: univ_ptr; var font_ptr: univ_ptr;
              out status: status_$t): integer; options(val_param);
  smd_dev_map_t =
    ^procedure(dcte: univ_ptr; arg_2: integer32; arg_3: integer32;
               out va: univ univ_ptr; out status: status_$t);
    options(val_param);
  smd_dev_unmap_t =
    ^procedure(dcte: univ_ptr; arg_2: integer32; arg_3: integer32;
               va: univ_ptr; out status: status_$t); options(val_param);
  smd_dev_lites_t =
    ^procedure(dcte: univ_ptr; pattern: pinteger; y_pos: pinteger);
    options(val_param);
  smd_dev_assoc_t =
    ^procedure(dcte: univ_ptr; var va: univ_ptr; out status: status_$t);
    options(val_param);
  smd_dev_putc_t =
    ^procedure(dcte: univ_ptr; var arg_1: integer32; c: integer);
    options(val_param);
  smd_dev_logo_t =
    ^procedure(dcte: univ_ptr; logo: smd_logo_ptr_t;
               out status: status_$t); options(val_param);
  smd_dev_set_color_table_t =
    ^procedure(dcte: univ_ptr; arg_1: integer; arg_2: integer;
               var flag: boolean; out status: status_$t);
    options(val_param);
  smd_dev_device_info_t =
    ^procedure(dcte: univ_ptr; arg_1: integer32; var arg_2: integer32;
               var arg_3: integer32; out status: status_$t);
    options(val_param);
  smd_dev_share_device_t =
    ^procedure(dcte: univ_ptr; arg_1: integer; out status: status_$t);
    options(val_param);
  smd_dev_touch_t =
    ^function(dcte: univ_ptr; var arg_1: integer32;
              out status: status_$t): integer32; options(val_param);

  { A device's routine vector as an array of cells (SMD_$ADD_DEVICE's
    walk; the defaults in SMD_$ADD_DEVICE's static). }
  smd_dev_cells_t = array[0..32] of univ_ptr;

  { A device's routine vector, 0x84 bytes (MONO9's mono9_$hdm_t is the
    device's side of it): 25 routines from +0x04, then the device's
    parameters.  SMD_$ADD_DEVICE fills each nil routine from the
    driver's defaults (the SMD_$NOP_ routines), walking them as cells; a
    nil default, the defaults' hw_uid, ends the walk.
    - field_00: 1 in MONO9's;
    - hw_uid, disp_type: the hardware's UID and the display type
      (SMD_$INIT copies disp_type into the display record);
    - line_bits, word_74, width, height: the display memory's line in
      bits, a word, and the visible width and height (SMD_$INIT sets the
      display's limits from width and height);
    - n_areas, areas: the device's areas, which SMD_$INIT unwires.
    The type and the four words from +0x70 with the word after them are
    the device's display information as SMD_$INQ_DISP_INFO returns it
    (smd.ins.pas smd_disp_info_result_t, 12 bytes with `display_devices'),
    which it copies whole: the third variant. }
  smd_dev_vector_t = record
    case integer of
      1: (field_00: integer32;                    { 0x00 }
          shutdown: smd_dev_proc_t;               { 0x04 }
          video_ctl: smd_dev_video_ctl_t;         { 0x08 }
          cold_init: smd_dev_proc_t;              { 0x0C }
          load_crsr: smd_dev_load_crsr_t;         { 0x10 }
          copy_font: smd_dev_copy_font_t;         { 0x14 }
          lock_display: smd_dev_lock_t;           { 0x18 }
          blink_cursor: smd_dev_blink_t;          { 0x1C }
          xor_cursor: smd_dev_xor_cursor_t;       { 0x20 }
          rel_display: smd_dev_rel_t;             { 0x24 }
          map: smd_dev_map_t;                     { 0x28 }
          unmap: smd_dev_unmap_t;                 { 0x2C }
          install_disp: smd_dev_status_proc_t;    { 0x30 }
          lites: smd_dev_lites_t;                 { 0x34 }
          assoc: smd_dev_assoc_t;                 { 0x38 }
          dissoc: smd_dev_status_proc_t;          { 0x3C }
          busy_wait: smd_dev_status_proc_t;       { 0x40 }
          clear_screen: smd_dev_proc_t;           { 0x44 }
          putc: smd_dev_putc_t;                   { 0x48 }
          display_logo: smd_dev_logo_t;           { 0x4C }
          set_color_table: smd_dev_set_color_table_t;  { 0x50 }
          device_info: smd_dev_device_info_t;     { 0x54 }
          share_device: smd_dev_share_device_t;   { 0x58 }
          fifo_wait: smd_dev_proc_t;              { 0x5C }
          touch: smd_dev_touch_t;                 { 0x60 }
          close: smd_dev_close_t;                 { 0x64 }
          hw_uid: uid_$t;                         { 0x68 }
          disp_type: smd_$display_type_t;         { 0x70 }
          line_bits: pinteger;                    { 0x72 }
          word_74: pinteger;                      { 0x74 }
          width: pinteger;                        { 0x76 }
          height: pinteger;                       { 0x78 }
          unused_7a: array[1..2] of integer;      { 0x7A }
          n_areas: integer;                       { 0x7E }
          areas: smd_dev_area_list_ptr_t);        { 0x80 }
      2: (cells: smd_dev_cells_t);
      3: (head_00: array[0..27] of integer32;    { 0x00 }
          info: smd_disp_info_result_t);         { 0x70 }
  end;
  smd_dev_vector_ptr_t = ^smd_dev_vector_t;

  { A version of each of the four cursors' patterns, indexed from 0 by
    the cursor number: the driver's in SMD_$WIRED_DATA (+0x8CC), and in
    each unit record the versions its device has loaded (+0x104).
    SHOW_CURSOR loads a cursor's pattern into the device when the two
    differ; SMD_$ASSOC, SMD_$SEND_RESPONSE and SMD_$RETURN_DISPLAY copy
    the driver's whole into the unit's. }
  smd_crsr_versions_t = array[0..3] of integer32;
%endif

  { A display unit's record, 0x10C bytes.  Every user forms a pointer
    0xF4 bytes into the record, at the overlay's start + unit * 0x10C
    (SMD_$INIT's loop steps it by 0x10C from the overlay's start), and
    reaches the fields at -0xF4 .. +0x17 from it: the unit array of the
    overlay (below), element u at +0x18 + 0x10C * (u - 1).  From the
    record's start:
    - +0x00 the display's record (SMD_$INIT stores SMD_$DISPLAY_COM's
      address);
    - +0x04 the owner and +0x06 the borrower, process numbers compared
      with PROC1_$AS_ID (SMD_$DM_COND_EVENT_WAIT, SMD_$FREE_ASID), cleared
      together by SMD_$INIT; +0x08 another (SMD_$SOFT_SCROLL stores
      PROC1_$AS_ID); +0x0A a word (cleared);
    - +0x0C the per-process mapped addresses, indexed by the process
      number from 0: SMD_$MAP_DISPLAY_U reads element asid at the
      pointer - 0xE8 + 4 * asid, and SMD_$INIT clears elements 1..57.
      One array over proc1_$asid_t (0..57, PROC1_$AS_ID's type) fills
      the 0xE8 bytes, element 0 at +0x0C, and no instruction reaches
      +0x0C other than as element 0;
    - +0xF4 the unit's font table (above), +0xF8 its free list (above);
    - +0xFC the controller's registers (SMD_$INIT stores DISP1, and
      passes the field's address to TESTPAGE);
    - +0x100 the display's UID, from DISPLAY1_$UID (SMD_$INIT copies it),
      passed by address to MST_$MAP (SMD_$MAP_DISPLAY_U);
    - +0x108 the display memory's base (SMD_$INIT stores DISP1_MEM).
    The pointers' types are this file's; the mapped addresses univ_ptr
    (what MST_$MAP returns, a longword the routines store and return).

    With `two_display_units' (base/config.ins.pas) the record is 0x110
    bytes: 4 bytes at +0x0C come before the mapped addresses, and every
    later field is 4 bytes on (the pointer the users form is 0xF8 bytes
    into the record, the hw field at -0xF8 from it; mapped_addresses
    +0x10, font_table +0xF8, hdm_list +0xFC, ctrl_regs +0x100,
    display_uid +0x104, display_base +0x10C).  The SAU5's code never
    reaches the 4 bytes; the SAU4's SMD_$INIT stores a word at +0x0C of
    each record (16#80 and 16#60), so a word, then 2 bytes nothing
    reaches.

    With `display_devices' the record is 0x114 bytes, the SAU2's to
    +0xFC, then the device's vector and descriptor (SMD_$ADD_DEVICE
    stores them; every call into the device reads them) and the cursor
    versions its device has at +0x104 (smd_crsr_versions_t, above).  The pointer the users
    form is 0xFC bytes into the record, at the vector. }
  smd_display_unit_t = record
    hw: smd_display_hw_ptr_t;             { 0x00 }
    owner_asid: proc1_$asid_t;            { 0x04 }
    borrowed_asid: proc1_$asid_t;         { 0x06 }
    field_08: proc1_$asid_t;              { 0x08 }
    field_0a: integer;                    { 0x0A }
%if two_display_units %then
    field_0c: integer;                    { 0x0C }
    unused_0e: integer;                   { 0x0E }
%endif
    mapped_addresses: array[proc1_$asid_t] of univ_ptr;  { 0x0C, 0x10 }
    font_table: smd_unit_fonts_ptr_t;     { 0xF4, 0xF8 }
    hdm_list: smd_hdm_list_ptr_t;         { 0xF8, 0xFC }
%if display_devices %then
    vector: smd_dev_vector_ptr_t;         { 0xFC }
    dcte: univ_ptr;                       { 0x100 }
    crsr_versions: smd_crsr_versions_t;   { 0x104 }
%else
    ctrl_regs: smd_ctrl_regs_ptr_t;       { 0xFC, 0x100 }
    display_uid: uid_$t;                  { 0x100, 0x104 }
    display_base: smd_$display_memory_ptr_t;  { 0x108, 0x10C }
%endif
  end;

  { The overlay section SMD_$WIRED_DATA's contents, 0x13C bytes.  The
    map has it as a data section with no module segment and no symbol
    inside; all zero in the image.  Only the SMD module's code addresses
    it (a byte search of the image finds 50 operands, all in the SMD
    routines), in the overlay's forms: the first eventcount's and the
    second's address pushed (EC_$INIT, SMD_$INIT), the section's address
    loaded for the unit records (above), the lock's address pushed
    (ML_$EXCLUSION_INIT, SMD_$INIT).
    - +0x000 ec_1: SMD_$SIGNAL waits on it when the request ring is full;
      SMD_$DM_COND_EVENT_WAIT advances it;
    - +0x00C ec_2: advanced by SMD_$SIGNAL, SMD_$BORROW_DISPLAY and
      SMD_$RETURN_DISPLAY; SMD_$GET_EC hands it out;
    - +0x018 the unit records, one (smd_$validate_unit accepts unit 1
      only);
    - +0x124 the tracking-rectangle lock, an ml_$exclusion_t (0x12 bytes);
    - +0x136 6 bytes nothing addresses (the TODO below).
    With `two_display_units' the section is 0x250 bytes: two unit
    records of 0x110 bytes from +0x018, the lock at +0x238, and again 6
    bytes nothing addresses after it, at +0x24A (the SAU5's code; the
    same TODO).  With `display_devices' it is 0x8E0 bytes: eight unit
    records of 0x114 bytes from +0x018, the lock at +0x8B8, the cursors'
    versions at +0x8CC (smd_crsr_versions_t, above), and the
    count of units at +0x8DC, which SMD_$ADD_DEVICE counts up and the
    unit loops run to (the SAU9's code); the words at +0x8CA and +0x8DE
    nothing addresses. }
  { TODO(pascal) 6 bytes at the end of SMD_$WIRED_DATA nothing addresses (stand-in unused_136)

    The section is 0x13C bytes; the objects the code reaches end at 0x136
    (the 0x12-byte exclusion lock at +0x124).  No operand in the image
    names the last 6 bytes (the byte search above).  Rounding the record
    to 4 or 8 bytes gives 0x138, short of 0x13C, and no other unit's code
    reaches the section whose contribution could be the larger one.  What
    the 6 bytes held (a variable no code uses, a larger declaration in
    another unit's copy of the overlay) is not known; the stand-in holds
    their place. }
  smd_$wired_data_t = record
    ec_1: ec_$eventcount_t;               { 0x000 }
    ec_2: ec_$eventcount_t;               { 0x00C }
    unit: array[1..smd_unit_count] of smd_display_unit_t;  { 0x018 }
    trk_rect_mutex: ml_$exclusion_t;      { 0x124, 0x238, 0x8B8 }
%if display_devices %then
    unused_8ca: integer;                  { 0x8CA }
    crsr_versions: smd_crsr_versions_t;   { 0x8CC }
    unit_count: integer;                  { 0x8DC }
    unused_8de: integer;                  { 0x8DE }
%else
    unused_136: array[0..5] of char;      { 0x136, 0x24A }
%endif
  end;

  { A cursor's pattern, 0x28 bytes: width, height, hot-spot x, height -
    hot-spot y - 1, the bitmap.  SMD_$LOAD_CRSR_BITMAP stores them through
    SMD_$CURSOR_PTABLE's entry, the words of the bitmap from +8.  The four
    patterns are SMD_$CURSOR_TABLE (hand-written data of SMD_WIRED, 0xA0
    bytes up to SMD_$CURSOR_PTABLE), which the compiled code reaches only
    through the pointers. }
  smd_cursor_pattern_t = record
    width: integer;                       { 0x00 }
    height: integer;                      { 0x02 }
    hot_x: integer;                       { 0x04 }
    hot_y_adj: integer;                   { 0x06 }
    bitmap: smd_$cursor_bitmap_t;         { 0x08 }
  end;
  smd_cursor_pattern_ptr_t = ^smd_cursor_pattern_t;

  { The parameter words SMD_$BLT hands the hand-written BLT start: 16
    bytes of its frame, passed by address (smd/sau2/start_blt.s: "8 BLT
    parameter words").  A record (settled by smd/blt.pas, G7), which
    SMD_$BLT fills field by field: the controller's mode word at +0,
    built bit by bit, so Apollo's mode register record (smd/smd.ins.pas
    smd_$display_modereg_t); the low 4 bits of the end destination x at
    +2; the request's ssy and ssx at +4 and +6 (two word fields, the
    stores merged); the two negated extents at +8 and +0xA; the request's
    sdy and sdx at +0xC and +0xE.  The hand-written body copies the words
    to the controller (start_blt.s).  The extents are integer (stored
    from `-1 - abs(...)', word results that are negative); the other
    words pinteger, as the request's.  Probed with dpc: the offsets
    above, 16 bytes. }
  smd_hw_blt_t = record
    control: smd_$display_modereg_t;      { 0x00 }
    bit_pos: pinteger;                    { 0x02 }
    field_04: pinteger;                   { 0x04 }
    field_06: pinteger;                   { 0x06 }
    y_extent: integer;                    { 0x08 }
    x_extent: integer;                    { 0x0A }
    y_start: pinteger;                    { 0x0C }
    x_start: pinteger;                    { 0x0E }
  end;

  { A unit's cursor-blink routine: called with no arguments through the
    module's table (SMD_$BLINK_CURSOR_CALLBACK). }
  smd_blink_func_t = ^procedure;

{ The overlay section SMD_$WIRED_DATA (above): ring/ringlog.ins.pas's form,
  the variable named after the section.  Not on the SAUs without the
  display driver (`display_driver'): the SAU3's map has no such section. }
%if display_driver %then
var (smd_$wired_data)
  smd_$wired_data: smd_$wired_data_t;
%endif

var
  { SMD_$DISPLAY_COM (map symbol in SMD_WIRED's hand-written data): the
    display records, one, indexed from 1 (smd_$validate_unit,
    SMD_$INQ_DISP_INFO), 0x60 bytes up to SMD_TIME_$COM.  The compiled
    code reaches it by its address (13 sites).  Two with
    `two_display_units' (the SAU5's 0xC0 bytes up to SMD_TIME_$COM;
    SMD_$INIT stores element 2's address in unit 2's record). }
  smd_$display_com: extern array[1..smd_unit_count] of smd_display_hw_t;

  { SMD_TIME_$COM (map symbol, SMD_WIRED's hand-written data, the 6 bytes
    up to MNK_$KTT_PTRS): the record above. }
  smd_time_$com: extern smd_time_com_t;

  { SMD_$CURSOR_PTABLE (map symbol, SMD_WIRED's hand-written data): four
    pointers to SMD_$CURSOR_TABLE's patterns, indexed from 0 by the
    cursor number scaled by 4 (SHOW_CURSOR, SMD_$LOAD_CRSR_BITMAP,
    SMD_$READ_CRSR_BITMAP), 0x10 bytes up to SMD_$DISPLAY_COM. }
  smd_$cursor_ptable: extern array[0..3] of smd_cursor_pattern_ptr_t;

  { DISPLAY1_$UID (map symbol in UID_LIST, the hand-written UID list):
    SMD_$INIT copies it into the unit record's display_uid (above). }
  { TODO(merge) move to uid/uid.ins.pas
    Not moved yet: os/os.pas, which includes uid/uid.ins.pas, declares
    its own copy (OS part 2b) and includes this file's public sibling
    only; a copy in uid.ins.pas would be declared twice there, and
    smd/smd.pas does not include uid/uid.ins.pas.  The move needs
    os/os.pas's copy removed and the include added to smd/smd.pas. }
  display1_$uid: extern uid_$t;

  { DISP1 (map symbol among the I/O definitions): the display
    controller's registers.  SMD_$INIT stores its address as unit 1's
    ctrl_regs. }
  disp1: extern smd_ctrl_regs_t;

%if two_display_units %then
  { The second display unit's objects (map symbols): DISPLAY2_$UID in
    UID_LIST, the hand-written UID list (TODO(merge) above, as
    DISPLAY1_$UID: uid/uid.ins.pas), DISP2 among the I/O definitions
    (the SAU5's at DISP1's address) and DISP2_MEM, the display memory
    (16#FA0000 on the SAU5).  SMD_$INIT stores their addresses, and
    copies the UID, into unit 2's record. }
  display2_$uid: extern uid_$t;
  disp2: extern smd_ctrl_regs_t;
  disp2_mem: extern smd_$disp1_mem_t;
%endif

%if gpu_driver %then
  { The graphics board's objects (map symbols; I/O definitions but
    DISPLAY3_$UID, UID_LIST's): KOLOR_CTL, the board's control block
    (16#F90000 on the SAU5), whose word at +2 is the board's id
    (SMD_$INIT probes the block with TESTPAGE and copies the word into
    SMD_$GRAPHIC_DEVICE_ID); DISP_MEM_2KX1K, the DN580's 2048-pixel-wide
    display memory (DISP2_MEM's address); DISPLAY3_$UID, that display's
    UID.  SMD_$INIT stores the block's and the memory's addresses in
    unit 1's record for the color displays (smd_kolor_ctl_t, above). }
  kolor_ctl: extern smd_kolor_ctl_t;
  disp_mem_2kx1k: extern smd_wide_memory_t;
  display3_$uid: extern uid_$t;
%endif

%if color_board %then
  { The color board's register pages (map symbols among the I/O
    definitions): COLOR_SUP (16#FF6000 on the SAU5) and COLOR_CSTORE
    (16#FF6800).  SMD_$INIT probes COLOR_SUP for unit 2, starts the
    board through its first word and reads COLOR_CSTORE's fourth word
    (smd_color_sup_t, above). }
  color_sup: extern smd_color_sup_t;
  color_cstore: extern smd_color_cstore_t;
%endif

{ DISP_LITES (map symbol, hand assembly in a data segment,
  misc/m68k/disp_lites.s): it reads the pattern word and the row word
  past its register save, two word slots by value; SMD_$LITES, its only
  caller, pushes them so.  `val_param'; the names are misc/sau2's
  (pattern, y as y_pos, SMD_$LITES's). }
{ TODO(merge) move to misc/misc.ins.pas }
procedure disp_lites(pattern: pinteger; y_pos: pinteger);
  options(extern, val_param);

{ Headings of the SMD_WIRED hand-written entries the compiled SMD code
  calls (no Pascal for their bodies, smd/sau2/*.s).  Each is written
  from its callers' pushes and the body's reading of the stack; the
  names are smd/sau2's. }

{ SMD_$LOCK_DISPLAY (map symbol; smd/m68k/lock_display.s): the body
  reads its two arguments off SP as addresses (the display record, its
  word at +2 tested and written; a word compared with 1), and returns a
  boolean byte.  Its callers push two addresses and test D0's byte
  (SHOW_CURSOR, with a constant cell 1; SMD_$ACQ_DISPLAY).  So the
  default convention, both by address, a boolean result.  The second
  argument is `in': SHOW_CURSOR passes a constant of the code.  The body
  also clears the word 0x24 bytes past the second argument when it moves
  the state from 3 to 4 (lock_display.s). }
function smd_$lock_display(in hw: smd_display_hw_t;
                           in lock_data: integer): boolean; extern;

{ SMD_$XOR_CURSOR (map symbol; smd/sau2/cursor_thunks.s): seven longword
  slots read off SP after its register save, the cursor number, the
  position, the limits, the display record and a flag by address, then
  the display memory's base and the register block by value.
  SHOW_CURSOR pushes the unit's ctrl_regs and display_base values, the
  true cell, the record, its limits, the block's cursor position and
  number; smd_$cursor_op pushes the same shape from its own slots and
  ignores D0.  Two longwords by value need `val_param' (ref 5.2, Table
  5-1); under it a 4-byte `in' goes by value, so the 4-byte position
  passed by address is `var', as is the word number passed by address
  (`var' takes the callers' variables and value slots); the flag, a
  constant cell at one caller, is `in univ' (passed by address under
  val_param, and it takes a constant); the 8-byte limits and the record
  go by address as `in'.  The body returns a boolean
  (cursor_thunks.s). }
function smd_$xor_cursor(var cursor_num: integer;
                         var cursor_pos: smd_$pos_t;
                         in bounds: smd_$window_limits_t;
                         in hw: smd_display_hw_t;
                         in erase_flag: univ boolean;
                         display_base: smd_$display_memory_ptr_t;
                         ctrl_regs: smd_ctrl_regs_ptr_t): boolean;
  options(extern, val_param);

{ SMD_$START_SCROLL and SMD_$CONTINUE_SCROLL (map symbols;
  smd/sau2/scroll.s): the bodies read the display record's address and
  the register block's past their A5 push, and write the record's state.
  SMD_$SOFT_SCROLL and SMD_$REL_DISPLAY push the unit's ctrl_regs value
  and the record; neither reads D0.  A longword by value: `val_param';
  the record by address, written: `var'. }
procedure smd_$start_scroll(var hw: smd_display_hw_t;
                            ctrl_regs: smd_ctrl_regs_ptr_t);
  options(extern, val_param);
procedure smd_$continue_scroll(var hw: smd_display_hw_t;
                               ctrl_regs: smd_ctrl_regs_ptr_t);
  options(extern, val_param);

{ SMD_$START_BLT (map symbol; smd/sau2/start_blt.s): the body reads the
  parameter words' address, the display record's address and the
  register block's, past its register save.  SMD_$BLT pushes the unit's
  ctrl_regs, the unit's hw pointer (held in a register) and its 16-byte
  frame record, and reads no D0.  Two pointers by value: `val_param';
  the 16 bytes by address as `in' (under val_param an `in' of more than
  4 bytes still goes by address, ref 5.2).  The record is smd_hw_blt_t
  (above), SMD_$BLT's frame record (G7).  With `blt_request_start'
  (base/config.ins.pas) SMD_$BLT pushes its request's address there
  instead: the record is the caller's smd_$blt_regs_t. }
%if blt_request_start %then
procedure smd_$start_blt(in blt_regs: smd_$blt_regs_t;
                         hw: smd_display_hw_ptr_t;
                         ctrl_regs: smd_ctrl_regs_ptr_t);
  options(extern, val_param);
%else
procedure smd_$start_blt(in params: smd_hw_blt_t;
                         hw: smd_display_hw_ptr_t;
                         ctrl_regs: smd_ctrl_regs_ptr_t);
  options(extern, val_param);
%endif

{ SMD_$INTERRUPT_INIT (map symbol; code in SMD_WIRED's data segment,
  hand assembly, smd/sau2/interrupt_init.s): reads no argument; SMD_$INIT
  calls it with nothing pushed, and reads no D0. }
procedure smd_$interrupt_init; extern;

{ SMD_$BLINK_CURSOR_1 (map symbol; smd/sau2/blink_cursor_1.s): unit 1's
  blink routine, called through the block's table with nothing pushed
  (smd_blink_func_t, above); the image's table holds its address (SMD
  block +0x1DA4). }
procedure smd_$blink_cursor_1; extern;

%if two_display_units %then
{ SMD_$BLINK_CURSOR_2 (map symbol, SMD_WIRED's hand-written code of the
  SAU4..SAU6): unit 2's blink routine, the block's table's second
  element (the SAU5's SMD block +0x1E54). }
procedure smd_$blink_cursor_2; extern;

{ SMD_$GET_DTYPE (map symbol in SMD_UTILS's hand-written data segment,
  the SAU4..SAU6: a stub that passes the segment's base and jumps to its
  body, as SMD_$COPY_FONT_TO_HDM's).  SMD_$INIT pushes a unit's
  ctrl_regs and then its display_base, two longwords by value, and
  stores D0's word as the display's type: `val_param', a function of
  smd_$display_type_t. }
function smd_$get_dtype(display_base: smd_$display_memory_ptr_t;
                        ctrl_regs: smd_ctrl_regs_ptr_t):
                        smd_$display_type_t;
  options(extern, val_param);
%endif

%if display_devices %then
{ The vector's defaults (map symbols; smd/nop*.pas), in map order: each
  has the heading of the vector routine it stands in for, the
  descriptor's address first, by value (`val_param'); SMD_$NOP1 and
  SMD_$NOP2 stand in for several. }

{ SMD_$NOP2 - the default for a device routine that takes only a status. }
procedure smd_$nop2(dcte: univ_ptr; out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_COPY - the default for a device's font copy into hidden memory. }
function smd_$nop_copy(dcte: univ_ptr; var font_ptr: univ_ptr;
                       out status: status_$t): integer;
  options(extern, val_param);

{ SMD_$NOP_BLINK - the default for a device's cursor blink: nothing. }
procedure smd_$nop_blink(dcte: univ_ptr; var blink: smd_time_com_t;
                         var hw: smd_display_hw_t);
  options(extern, val_param);

{ SMD_$NOP_XOR - the default for a device's cursor drawing. }
function smd_$nop_xor(dcte: univ_ptr; cursor_num: integer;
                      pos: smd_$pos_t;
                      in limits: smd_$window_limits_t;
                      flag_1: boolean; flag_2: boolean): boolean;
  options(extern, val_param);

{ SMD_$NOP_REL - the default for a device's display release: nothing. }
procedure smd_$nop_rel(dcte: univ_ptr; var hw: smd_display_hw_t);
  options(extern, val_param);

{ SMD_$NOP_LITE - the default for a device's lights: nothing. }
procedure smd_$nop_lite(dcte: univ_ptr; pattern: pinteger;
                        y_pos: pinteger);
  options(extern, val_param);

{ SMD_$NOP_PUT - the default for a device's character output: nothing. }
procedure smd_$nop_put(dcte: univ_ptr; var arg_1: integer32;
                       c: integer);
  options(extern, val_param);

{ SMD_$NOP_FIFOWAIT - the default for a device's FIFO wait: nothing. }
procedure smd_$nop_fifowait(dcte: univ_ptr);
  options(extern, val_param);

{ SMD_$NOP_TOUCH - the default for a device's touch of its memory. }
function smd_$nop_touch(dcte: univ_ptr; var arg_1: integer32;
                        out status: status_$t): integer32;
  options(extern, val_param);

{ SMD_$NOP1 - the default for a device routine that takes only its descriptor. }
procedure smd_$nop1(dcte: univ_ptr);
  options(extern, val_param);

{ SMD_$NOP_VIDEO - the default for a device's video control: nothing. }
procedure smd_$nop_video(dcte: univ_ptr; on: boolean);
  options(extern, val_param);

{ SMD_$NOP_CRSR - the default for a device's cursor pattern load: nothing. }
procedure smd_$nop_crsr(dcte: univ_ptr; cnum: integer; size: integer;
                        hot_x: integer; hot_y: integer;
                        in bitmap: smd_$cursor_bitmap_t);
  options(extern, val_param);

{ SMD_$NOP_LOCK - the default for a device's display lock. }
function smd_$nop_lock(dcte: univ_ptr; var hw: smd_display_hw_t;
                       kind: integer): boolean;
  options(extern, val_param);

{ SMD_$NOP_MAP - the default for a device's display memory map. }
procedure smd_$nop_map(dcte: univ_ptr; arg_2: integer32;
                       arg_3: integer32; out va: univ_ptr;
                       out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_UNMAP - the default for a device's display memory unmap. }
procedure smd_$nop_unmap(dcte: univ_ptr; arg_2: integer32;
                         arg_3: integer32; va: univ_ptr;
                         out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_ASSOC - the default for a device's association with a process. }
procedure smd_$nop_assoc(dcte: univ_ptr; out va: univ_ptr;
                         out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_LOGO - the default for a device's boot logo. }
procedure smd_$nop_logo(dcte: univ_ptr; logo: smd_logo_ptr_t;
                        out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_COLOR - the default for a device's color table. }
procedure smd_$nop_color(dcte: univ_ptr; arg_1: integer;
                         arg_2: integer; var flag: boolean;
                         out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_DEVINFO - the default for a device's information. }
procedure smd_$nop_devinfo(dcte: univ_ptr; arg_1: integer32;
                           var arg_2: integer32;
                           out arg_3: integer32;
                           out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_SHAREDEV - the default for a device's sharing. }
procedure smd_$nop_sharedev(dcte: univ_ptr; arg_1: integer;
                            out status: status_$t);
  options(extern, val_param);

{ SMD_$NOP_CLOSE - the default for a device's close for an address space: nothing. }
procedure smd_$nop_close(dcte: univ_ptr; asid: integer);
  options(extern, val_param);
%endif

{ The SMD module's own objects with map symbols (`define'd in
  smd/smd.pas): SMD_REQUEST_QUEUE (SMD block +0x17F0, the request ring
  above) and SMD_RESPONSE_VAL (+0x1D9A, the units' "borrow request
  answered" booleans, indexed from 1 by the unit, written by
  SMD_$SEND_RESPONSE and tested by SMD_$BORROW_DISPLAY; 2 bytes up to
  the word at +0x1D9C).  With `display_devices' the booleans are one for
  each of the eight units, 8 bytes at +0x17F0, before the request ring
  (+0x17F8).  The names are the map's (no `$'). }
var
  smd_request_queue: extern smd_request_queue_t;
%if display_devices %then
  smd_response_val: extern array[1..smd_unit_count] of boolean;
%else
  smd_response_val: extern array[1..2] of boolean;
%endif

type
  { A version-3 font's header, as far as the compiled code reads it (its
    version word at 0x00): the word at +0x42, the hidden display memory
    the font needs, which SMD_$LOAD_FONT passes to SMD_$ALLOC_HDM for a
    version-3 font and SMD_$UNLOAD_FONT to SMD_$FREE_HDM, where a
    version-1 font's raster_lines at +0x06 is passed (smd_$font_table_t
    above).  The words between are not read by these routines (SMD_UTILS
    reads the header's longwords at +0x28, +0x2C, +0x34 and +0x38: that
    module's fragments give them their fields). }
  smd_font_v3_t = packed record
    version: pinteger;                    { 0x00 }
    unused_02: array[1..32] of pinteger;  { 0x02..0x41 }
    hdm_size: pinteger;                   { 0x42 }
  end;
  smd_font_v3_ptr_t = ^smd_font_v3_t;

  { The drawing context SMD_$WS_INIT and SMD_$UTIL_INIT fill for the
    SMD_UTILS routines, 0x1A bytes (one layout for both).  The SMD_UTILS
    code keeps it in its frame and calls the two through the address
    cells of its data (smd_$write_str_clip's body for SMD_$WS_INIT,
    SMD_$CLEAR_WINDOW's for SMD_$UTIL_INIT), the font index stored first
    at +0x18 and the status read back at +0x10.  SMD_$WS_INIT writes
    +0x00, +0x08, +0x0C, +0x10, +0x14 and reads +0x18; SMD_$UTIL_INIT
    writes +0x04, +0x08, +0x0C, +0x10; SMD_$DRAW_BOX reads +0x04, +0x08,
    +0x0C and +0x10 of its own.  The font entry's position is moved as
    one longword: a smd_$pos_t. }
  smd_ws_ctx_t = record
    font_ptr: smd_$font_table_ptr_t;      { 0x00 }
    display_base: smd_$display_memory_ptr_t;  { 0x04 }
    ctrl_regs: smd_ctrl_regs_ptr_t;       { 0x08 }
    hw: smd_display_hw_ptr_t;             { 0x0C }
    status: status_$t;                    { 0x10 }
    font_hdm_pos: smd_$pos_t;             { 0x14 }
    font_index: integer;                  { 0x18 }
  end;

{ SMD_$LOAD_FONT - load a font into hidden display memory. }
function smd_$load_font(in table_ptr: univ smd_$font_table_ptr_t;
                        out status: status_$t): pinteger; extern;

{ SMD_$WS_INIT and SMD_$UTIL_INIT (smd/ws_init.pas, smd/util_init.pas). }
procedure smd_$ws_init(in out ctx: smd_ws_ctx_t); extern;
procedure smd_$util_init(out ctx: smd_ws_ctx_t); extern;

{ The SMD_UTILS entries the SMD module calls (smd/README.md:
  SMD_UTILS is the next map module; its bodies take no frame and read
  their arguments off SP, so each heading here is written from the
  callers' pushes and the bodies' reads of the stack, past their
  register saves).

  SMD_$COPY_FONT_TO_HDM (map symbol, a stub that jumps to SMD_UTILS's
  body): the body reads the display memory's base and the font's address
  as values and the position through its slot, never written.
  SMD_$LOAD_FONT pushes the font entry's hdm_pos, the font pointer, the
  unit's display_base.  Two longwords by value: `val_param'; the 4-byte
  position by address and only read: `in' and `univ' (a 4-byte `in'
  would go by value under val_param; ref 5.2, Table 5-1). }
procedure smd_$copy_font_to_hdm(display_base: smd_$display_memory_ptr_t;
                                font: smd_$font_table_ptr_t;
                                in hdm_pos: univ smd_$pos_t);
  options(extern, val_param);

{ SMD_$INVERT_DISP (map symbol, in SMD_UTILS's code): it inverts 16#1C00
  longwords of the display memory from base + 16#19000, the display
  memory's base by value, the second slot an address it never uses.
  SMD_$INVERT_S pushes the unit's display record and its display_base.
  A longword by value: `val_param'; the record (0x60 bytes) by address,
  not written: `in'. }
procedure smd_$invert_disp(display_base: smd_$display_memory_ptr_t;
                           in display_info: smd_display_hw_t);
  options(extern, val_param);

{ SMD_$HORIZ_LINE and SMD_$VERT_LINE (map symbols, stubs that jump to
  SMD_UTILS's bodies): the bodies take the first three slots as
  addresses of words they only read, the fifth as the BLT register
  block's address, which they write, the sixth as the address of a word
  they read, and load the fourth and seventh without using them.
  SMD_$DRAW_BOX pushes three words of its box, the context's
  display_base, ctrl_regs and hw by value, its control word by address.
  Three longwords by value: `val_param'; the four words by address and
  only read: `in' and `univ' (as above).  param4 and param7 are named by
  what the callers pass (display_base, hw). }
procedure smd_$horiz_line(in y: univ integer; in x1: univ integer;
                          in x2: univ integer;
                          display_base: smd_$display_memory_ptr_t;
                          hw_regs: smd_ctrl_regs_ptr_t;
                          in control: univ integer;
                          hw: smd_display_hw_ptr_t);
  options(extern, val_param);
procedure smd_$vert_line(in x: univ integer; in y1: univ integer;
                         in y2: univ integer;
                         display_base: smd_$display_memory_ptr_t;
                         hw_regs: smd_ctrl_regs_ptr_t;
                         in control: univ integer;
                         hw: smd_display_hw_ptr_t);
  options(extern, val_param);

type
  { The SMD block's bytes +0xDC and +0xDD (smd/smd.pas blank_flags): two
    booleans, stored and tested as bytes (SMD_$UNBLANK, the blink
    callback, smd_$reset_display_globals).  One unpacked record: a
    boolean may sit at an odd offset in one (ref 3.10.5.5), and every
    static object is word aligned (dpc's STATIC_MIN_ALIGN), so the byte
    at +0xDD belongs to the object at +0xDC.  Probed with dpc: the
    fields at 0 and 1, the record 2 bytes. }
  smd_blank_flags_t = record
    blank_enabled: boolean;               { 0x00 (+0xDC) }
    blank_pending: boolean;               { 0x01 (+0xDD) }
  end;

  { The SMD block's bytes +0x173C..+0x173F (smd/smd.pas flags_173c): a
    byte nothing addresses, then the three booleans
    smd_$reset_display_globals writes.  One unpacked record for the
    reason above (+0x173D is odd).  Probed with dpc: the fields at 0 ..
    3, the record 4 bytes. }
  smd_flags_173c_t = record
    unused_173c: char;                    { 0x00 (+0x173C) }
    field_173d: boolean;                  { 0x01 (+0x173D) }
    field_173e: boolean;                  { 0x02 (+0x173E) }
    field_173f: boolean;                  { 0x03 (+0x173F) }
  end;

type
  { The caller's tracking rectangles, the array the three routines below
    and smd_$add_trk_rects_internal reach through their by-address slot
    from element 1: element 1 at the slot's address, element `count' at
    -8 + 8 * count, elements 1 .. count stepped by 8
    (smd_$add_trk_rects_internal, SMD_$DEL_TRK_RECT).  The bound 200 is
    the module's own list's (tracking_rects, smd/smd.pas), to which no
    more rectangles can be added. }
  smd_track_rect_list_t = array[1..200] of smd_track_rect_t;

{ SMD_$CLR_AND_LOAD_TRK_RECT and SMD_$ADD_TRK_RECT
  (smd/clr_and_load_trk_rect.pas, smd/add_trk_rect.pas). }
procedure smd_$clr_and_load_trk_rect(in rects: univ smd_track_rect_list_t;
                                     in count: integer;
                                     out status: status_$t); extern;
procedure smd_$add_trk_rect(in rects: univ smd_track_rect_list_t;
                            in count: integer;
                            out status: status_$t); extern;

{ SMD_$DEL_TRK_RECT - remove rectangles from the tracking list. }
procedure smd_$del_trk_rect(in rects: univ smd_track_rect_list_t;
                            in count: integer;
                            out status: status_$t); extern;

{ SMD_$SIGNAL - queue a request for the display manager. }
procedure smd_$signal(in unit: integer; in request: univ smd_$request_t;
                      in count: pinteger; out status: status_$t); extern;

{ SMD_$SOFT_SCROLL - start a soft scroll of a window of the screen. }
procedure smd_$soft_scroll(in window_desc: smd_$window_limits_t;
                           in direction: smd_$direction_t;
                           in displacement: pinteger;
                           out status: status_$t); extern;

{ SMD_$MAP_DISPLAY_U
  (smd/map_display_u.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$map_display_u(
  out display_address: smd_$display_memory_ptr_t;
  out status: status_$t); extern;

var
  { OS_$SHUTDOWN_EC, a map symbol (with OS_DATA_WIRED) at the start of
    OS_WIRED_START's data segment of WIRED_DATA: 12 bytes, an
    eventcount.  SMD_$GET_EC registers it for its key 3, its address
    pushed to EC2_$REGISTER_EC1's by-value eventcount pointer: another
    unit's variable by its address.  Declared here, not in
    os/os.ins.pas, because that file needs no ec/ec.ins.pas and one of
    its users (disk/diskless_init.pas) does not include it; it can move
    there when its users include the EC insert file. }
  os_$shutdown_ec: extern ec_$eventcount_t;

{ SMD_$LOAD_CRSR_BITMAP
  (smd/load_crsr_bitmap.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$load_crsr_bitmap(in unit: integer; in cnum: integer;
                                in width: integer; in height: integer;
                                in xorg: integer; in yorg: integer;
                                in bitmap: smd_$cursor_bitmap_t;
                                out status: status_$t); extern;

{ SMD_$READ_CRSR_BITMAP
  (smd/read_crsr_bitmap.pas; Apollo's heading, smdu.ins.pas). }
procedure smd_$read_crsr_bitmap(in unit: integer; in cnum: integer;
                                out width: integer; out height: integer;
                                out xorg: integer; out yorg: integer;
                                out bitmap: smd_$cursor_bitmap_t;
                                out status: status_$t); extern;

{ SMD_$GET_EC - export one of the display's eventcounts to user space. }
procedure smd_$get_ec(in key: integer; out ecp: ec2_$ptr_t;
                      out status: status_$t); extern;

{ SMD_$WRITE_STR_CLIP (map symbol, in SMD_UTILS's data: a stub that jumps
  to SMD_UTILS's body smd_$write_str_clip_impl).  SMD_$WRITE_STRING
  pushes six addresses: its status, its scroll_wait slot, its str_len
  copy, its str and font_id slots, its pos copy.  The body reads the six
  slots off its frame: pos as a longword, font_id as a word, str's
  bytes, str_len as a word, scroll_wait by its sign, and writes the
  status; none of the first five is written: the default convention,
  `in', with Apollo's smd_$write_string_u's types and names.  Its result
  a word (the x past the string), which SMD_$WRITE_STRING does not read.
  The SVC table refers to it too. }
function smd_$write_str_clip(in pos: smd_$pos_t; in font_id: pinteger;
                             in str: univ smd_$string_t;
                             in str_len: pinteger;
                             in scroll_wait: boolean;
                             out status: status_$t): integer; extern;

{ ---- SMD_$GET_EC's keys, named. ----

  SMD_$GET_EC's key (its `case key of', 0..3): 0 and 1 are Apollo's
  smdu.ins.pas smd_$ec_key_t enumerators, smd_$input_ec and
  smd_$scroll_blt_ec (as constants: this tree's heading takes the key as
  a word); 2 and 3 have no Apollo name. }
const
  smd_$input_ec = 0;
  smd_$scroll_blt_ec = 1;
  smd_$ec_key_smd_ec2 = 2;
  smd_$ec_key_shutdown = 3;
{ ---- end of SMD_$GET_EC's keys ---- }

{ ---- SMD's event types, named. ----

  An event queue entry's type (+0x0C of the entry; SMD_$GET_UNIT_EVENT's
  `case entry^.event_type of'; SMD_$LOC_EVENT's and SMD_$POLL_KEYBOARD's
  stores) and the public event type SMD_$GET_UNIT_EVENT returns
  (SMD_$GET_IDM_EVENT's `case event_type of'; SMD_$DM_COND_EVENT_WAIT's
  and SMD_$COND_INPUT_U's stores and tests).  Apollo's smdu.ins.pas
  smd_$event_t is another code space (the user-level event wait's), so
  its names are not used here. }
const
  smd_$evtype_int_key_meta0 = 16#00;
  smd_$evtype_int_key_meta = 16#07;
  smd_$evtype_int_button_down = 16#08;
  smd_$evtype_int_special = 16#0B;
  smd_$evtype_int_key_normal = 16#0C;
  smd_$evtype_int_button_down2 = 16#0D;
  smd_$evtype_int_button_up = 16#0E;
  smd_$evtype_int_pointer_up = 16#0F;

  smd_$evtype_none = 0;
  smd_$evtype_button_down = 1;
  smd_$evtype_button_up = 2;
  smd_$evtype_keystroke = 3;
  smd_$evtype_special = 4;
  smd_$evtype_pointer_up = 5;

  { The user-level event type SMD_$DM_COND_EVENT_WAIT returns (its word
    stores): Apollo's smdu.ins.pas smd_$event_t, its enumerators'
    ordinals as constants (this tree's heading takes the type as a word,
    and the enumeration cannot be in scope: smd_$signal is also the
    routine SMD_$SIGNAL, smd/smd.ins.pas).  So 1 is smd_$signal_event
    here; the others are Apollo's. }
  smd_$input = 0;
  smd_$signal_event = 1;                  { new: Apollo's smd_$signal }
  smd_$scroll_blt_complete = 2;
  smd_$borrow_req = 3;
  smd_$return_req = 4;
  smd_$kbd_return_req = 5;
  smd_$keyswitch_off = 6;
  smd_$tpad_and_input = 7;
  smd_$tpad_data = 8;
  smd_$no_event = 9;
{ ---- end of SMD's event types ---- }
