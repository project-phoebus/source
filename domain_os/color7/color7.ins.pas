{ color7/color7.ins.pas - COLOR7 (the coyote color display) constants,
  types, variables and routine headings, for the Domain Pascal tree.

  The COLOR7 module (color7/color7.pas) and its descriptor and wired
  data (color7/color7_dcte.pas).  Where the driver is configured out
  (`color7_driver', base/config.ins.pas) what is left is the empty
  COLOR7_$WORTHLESS.  With the driver, the routines are the display
  driver's (SMD_, `display_devices'): it calls them through the routine
  vector the descriptor points at, each with the descriptor's address
  first, and IO_$INIT calls COLOR7_$IOINIT as the descriptor's init
  routine.  Apollo's customer insert files of SR10.2 name the display
  only in smdu.ins.pas (`smd_$color7_display', display type 14,
  "coyote").  The board is reached at fixed addresses: its registers
  from the address in COLOR7_STATIC (color7/color7.pas), its display
  memory at color7_$memory_va.  Include base/base.ins.pas,
  time/time.ins.pas, proc1/proc1.ins.pas, io/io.ins.pas and
  smd/smd.ins.pas before it.
}

%if color7_driver %then
const
  { The descriptor's kind and controller type (color7/color7_dcte.pas):
    a kind-2 DCTE without a name, of controller type 7. }
  color7_$dcte_kind = 2;
  color7_$dcte_ctype = 7;

  { Where the display memory is, the address COLOR7_$MAP_DISPLAY_MEMORY
    returns and the drawing routines write at (16#F8000000 as an
    integer32), and where the registers are (COLOR7_STATIC's regs,
    16#FC000000).  The memory's lines are 512 bytes. }
  color7_$memory_va = -134217728;
  color7_$regs_va = -67108864;
  color7_$line_bytes = 512;

  { The board's other register blocks' offsets from its address (the
    types after color7_$regs_t). }
  color7_$ports_offset = 16#50000;
  color7_$ctl_offset = 16#70000;
  color7_$status_offset = 16#1000000;
  color7_$rom_offset = 16#1800000;

  { The words of the identification ROM COLOR7_$IOINIT reads, as one
    longword: `COYO'. }
  color7_$board_id = 16#434F594F;

  { What COLOR7_$IOINIT writes to the control register, twice, and the
    mask of the bit (27) it then clears; the control register reads all
    ones until the board is up. }
  color7_$ctl_init_1 = 16#88040000;
  color7_$ctl_init_2 = 16#DC040000;
  color7_$ctl_reset_mask = 16#F7FFFFFF;
  color7_$ctl_not_ready = -1;

  { The control register's bits: 13 and 12 give the board's
    configuration (COLOR7_STATIC's config_13 and config_12), 10 is set
    while the color map's port is busy. }
  color7_$ctl_config_13 = 13;
  color7_$ctl_config_12 = 12;
  color7_$ctl_port_busy = 10;

  { The color map's ports (color7_write_reg's reg argument): the port's
    address at offset 0, its data at offsets 4, 8 and 12.  The ports
    from color7_$port_wait_first to color7_$port_wait_last are written
    only when the control register's busy bit is clear, polled up to
    color7_$port_polls times. }
  color7_$port_cursor = 16#00;
  color7_$port_10 = 16#10;
  color7_$port_20 = 16#20;
  color7_$port_30 = 16#30;
  color7_$port_timing = 16#40;
  color7_$port_50 = 16#50;
  color7_$port_60 = 16#60;
  color7_$port_70 = 16#70;
  color7_$port_wait_first = 16#40;
  color7_$port_wait_last = 16#70;
  color7_$port_polls = 10000;

  { The offsets of a port's registers. }
  color7_$port_addr = 0;
  color7_$port_data_4 = 4;
  color7_$port_data_8 = 8;
  color7_$port_data_c = 12;

  { The timing port's register COLOR7_$VIDEO_CTL sets, and its values
    (bit 3 the video enable). }
  color7_$timing_video = 16#9C;
  color7_$video_config_13 = 29;
  color7_$video_other = 13;
  color7_$video_on_mask = 16#FFFFFFF7;

  { The cursor's pattern as COLOR7_$XOR_CURSOR loads it: its 16 words
    as two bytes each with 6 zero bytes after, and 384 zero bytes;
    the cursor's position registers' offsets on each configuration, and
    the cursor commands (on and off). }
  color7_$cursor_rows = 16;
  color7_$cursor_row_pad = 6;
  color7_$cursor_pad = 384;
  color7_$cursor_margin = 32;
  color7_$cursor_x_config_13 = 113;
  color7_$cursor_x_other = 128;
  color7_$cursor_y_config_12 = 13;
  color7_$cursor_y_other = 21;
  color7_$cursor_cmd_on = 16#48;
  color7_$cursor_cmd_off = 8;

  { The polls: color7_wait_idle's of the drawing engine, COLOR7_$IOINIT's
    of the control register, and COLOR7_$BUSY_WAIT's, with a wait of 500
    ticks between them; the status COLOR7_$BUSY_WAIT stores when they
    run out. }
  color7_$idle_polls = 1000;
  color7_$ready_polls = 1000;
  color7_$busy_polls = 1500;
  color7_$busy_delay = 500;
  color7_$busy_timeout = 2;

  { The drawing engine's settings the drawing routines make (the
    registers of color7_$regs_t): the full-screen window, the operation
    words. }
  color7_$x_max = 1279;
  color7_$y_max = 1023;
  color7_$plane_all = 16#FFFFFF;
  color7_$op_216c = 16#1010111F;
  color7_$op_3070 = 16#101010;
  color7_$op_fill = 16#40203C00;
  color7_$op_copy = 16#10343C00;
  color7_$op_idle = 16#10203C00;

  { The logo COLOR7_$DISPLAY_LOGO copies, smd/smd.ins.pas's smd_logo_t:
    150 rows of 32 words, placed at word 24 of its line, the line from
    the screen's origin register less 981 or 973, plus 437; and what of
    each line it clears first, 16 longwords. }
  color7_$logo_rows = 150;
  color7_$logo_words = 32;
  color7_$logo_longs = 16;
  color7_$logo_word = 24;
  color7_$logo_line_config_12 = 981;
  color7_$logo_line_other = 973;
  color7_$logo_line_add = 437;
  color7_$memory_lines = 1024;

  { The lights COLOR7_$LITES draws: 16, each a column word of 16 lines,
    from word 3 of the line y_pos; every fourth one is 8 bytes from
    the one before, the others 4.  A light that is off is its frame:
    the word's two end bits. }
  color7_$lite_count = 16;
  color7_$lite_lines = 16;
  color7_$lite_offset = 6;
  color7_$lite_on = -1;
  color7_$lite_off = -32767;

  { The zero bytes COLOR7_$IOINIT gives the cursor port. }
  color7_$cursor_clear = 512;

  { The color map's ramp of COLOR7_$IOINIT on configuration 13: 16
    entries of ports 0x50, 0x60 and 0x70, and the last entry. }
  color7_$ramp_entries = 16;

type
  { A table entry of COLOR7_$IOINIT: a register's address and its value
    for a port. }
  color7_$port_set_t = record
    addr: integer32;                      { 0x00 }
    value: integer32;                     { 0x04 }
  end;

  { The control register at +0x70000: written as a longword, its bits
    read from a copy (member k is bit k). }
  color7_$ctl_t = record
    case integer of
      1: (all: integer32);
      2: (bits: set of 0..31);
  end;

  { The drawing engine's status at +0x1000000, read from a copy: two
    2-bit fields, both 0 when the engine is idle. }
  color7_$status_t = packed record
    unused_31_5: 0..134217727;            { bits 31..5 }
    queue: 0..3;                          { bits 4..3 }
    unused_2: 0..1;                       { bit 2 }
    busy: 0..3;                           { bits 1..0 }
  end;

  { The drawing engine's registers at COLOR7_STATIC's regs, the board's
    address, a `[device]' record, every register read and written at its
    width (their meanings are the board's; named by offset). }
  color7_$regs_t = [device] record
    unused_00000: array[0..55] of integer32;      { 0x000000 }
    reg_0e0: integer32;                           { 0x0000E0 }
    reg_0e4: integer32;                           { 0x0000E4 }
    reg_0e8: integer32;                           { 0x0000E8 }
    reg_0ec: integer32;                           { 0x0000EC }
    unused_000f0: array[0..4] of integer32;       { 0x0000F0 }
    reg_104: integer32;                           { 0x000104 }
    unused_00108: array[0..2] of integer32;       { 0x000108 }
    reg_114: integer32;                           { 0x000114 }
    unused_00118: array[0..11] of integer32;      { 0x000118 }
    reg_148: integer32;                           { 0x000148 }
    unused_0014c: integer32;                      { 0x00014C }
    reg_150: integer32;                           { 0x000150 }
    unused_00154: array[0..34] of integer32;      { 0x000154 }
    reg_1e0: integer32;                           { 0x0001E0 }
    unused_001e4: integer32;                      { 0x0001E4 }
    reg_1e8: integer32;                           { 0x0001E8 }
    unused_001ec: integer32;                      { 0x0001EC }
    reg_1f0: integer32;                           { 0x0001F0 }
    unused_001f4: array[0..2011] of integer32;    { 0x0001F4 }
    reg_2164: integer32;                          { 0x002164 }
    unused_02168: integer32;                      { 0x002168 }
    reg_216c: integer32;                          { 0x00216C }
    unused_02170: array[0..12] of integer32;      { 0x002170 }
    reg_21a4: integer32;                          { 0x0021A4 }
    unused_021a8: integer32;                      { 0x0021A8 }
    reg_21ac: integer32;                          { 0x0021AC }
    unused_021b0: array[0..14] of integer32;      { 0x0021B0 }
    reg_21ec: integer32;                          { 0x0021EC }
    unused_021f0: array[0..915] of integer32;     { 0x0021F0 }
    reg_3040: integer32;                          { 0x003040 }
    reg_3044: integer32;                          { 0x003044 }
    reg_3048: integer32;                          { 0x003048 }
    reg_304c: integer32;                          { 0x00304C }
    reg_3050: integer32;                          { 0x003050 }
    unused_03054: array[0..2] of integer32;       { 0x003054 }
    reg_3060: integer32;                          { 0x003060 }
    reg_3064: integer32;                          { 0x003064 }
    reg_3068: integer32;                          { 0x003068 }
    reg_306c: integer32;                          { 0x00306C }
    reg_3070: integer32;                          { 0x003070 }
  end;
  color7_$regs_ptr_t = ^color7_$regs_t;

  { The board's other register blocks, at fixed offsets from its
    address (color7_$ports_offset .. color7_$rom_offset), `[device]'
    records: the color map's ports, longwords indexed by their offset
    over 4 (color7_write_reg); the control register; the drawing
    engine's status; the identification ROM, whose words at +8 and +10
    COLOR7_$IOINIT reads. }
  color7_$ports_t = [device] record
    port: array[0..31] of integer32;      { 0x00 }
  end;
  color7_$ports_ptr_t = ^color7_$ports_t;
  color7_$ctl_reg_t = [device] record
    ctl: color7_$ctl_t;                   { 0x00 }
  end;
  color7_$ctl_reg_ptr_t = ^color7_$ctl_reg_t;
  color7_$status_reg_t = [device] record
    status: color7_$status_t;             { 0x00 }
  end;
  color7_$status_reg_ptr_t = ^color7_$status_reg_t;
  color7_$rom_t = [device] record
    unused_0: array[0..3] of pinteger;    { 0x00 }
    id: array[1..2] of pinteger;          { 0x08 }
  end;
  color7_$rom_ptr_t = ^color7_$rom_t;

  { The identification ROM's two words as COLOR7_$IOINIT reads them
    (TESTPAGE), and as the longword it compares. }
  color7_$id_t = record
    case integer of
      1: (w: array[1..2] of pinteger);
      2: (l: integer32);
  end;

  { The display memory as the drawing routines write it, at addresses
    formed from color7_$memory_va: a word (COLOR7_$LITES), and lines of
    512 bytes from a place in one, as longwords or words
    (COLOR7_$DISPLAY_LOGO). }
  color7_$word_ptr_t = ^integer;
  color7_$line_t = record
    case integer of
      1: (longs: array[1..128] of integer32);
      2: (words: array[1..256] of pinteger);
  end;
  color7_$lines_t = array[1..1024] of color7_$line_t;
  color7_$lines_ptr_t = ^color7_$lines_t;

  { An area of the driver's code or data, the start and end addresses
    SMD_$INIT unwires (smd/smd_internal.ins.pas smd_dev_area_t). }
  color7_$area_t = record
    start_va: univ_ptr;                   { 0x00 }
    end_va: univ_ptr;                     { 0x04 }
  end;
  color7_$areas_t = array[1..2] of color7_$area_t;
  color7_$areas_ptr_t = ^color7_$areas_t;

  { The display's routine vector and parameters, 0x84 bytes (the
    driver's smd_dev_vector_t, smd/smd_internal.ins.pas, which has the
    fields' meanings).  The cells are univ_ptr so that the routines'
    `addr' can fill them; the driver fills the nil ones from its own
    defaults.  disp_type is 14 (smdu.ins.pas's `smd_$color7_display'),
    the display memory's line 1280 bits, its lines 1024, the visible
    width and height 1280 by 1024. }
  color7_$hdm_t = record
    field_00: integer32;                  { 0x00 }
    shutdown: univ_ptr;                   { 0x04 }
    video_ctl: univ_ptr;                  { 0x08 }
    cold_init: univ_ptr;                  { 0x0C }
    load_crsr: univ_ptr;                  { 0x10 }
    copy_font: univ_ptr;                  { 0x14 }
    lock_display: univ_ptr;               { 0x18 }
    blink_cursor: univ_ptr;               { 0x1C }
    xor_cursor: univ_ptr;                 { 0x20 }
    rel_display: univ_ptr;                { 0x24 }
    map: univ_ptr;                        { 0x28 }
    unmap: univ_ptr;                      { 0x2C }
    install_disp: univ_ptr;               { 0x30 }
    lites: univ_ptr;                      { 0x34 }
    assoc: univ_ptr;                      { 0x38 }
    dissoc: univ_ptr;                     { 0x3C }
    busy_wait: univ_ptr;                  { 0x40 }
    clear_screen: univ_ptr;               { 0x44 }
    putc: univ_ptr;                       { 0x48 }
    display_logo: univ_ptr;               { 0x4C }
    set_color_table: univ_ptr;            { 0x50 }
    device_info: univ_ptr;                { 0x54 }
    slots_58: array[1..4] of univ_ptr;    { 0x58 }
    hw_uid: uid_$t;                       { 0x68 }
    disp_type: integer;                   { 0x70 }
    line_bits: pinteger;                  { 0x72 }
    word_74: pinteger;                    { 0x74 }
    width: pinteger;                      { 0x76 }
    height: pinteger;                     { 0x78 }
    unused_7a: array[1..2] of integer;    { 0x7A }
    n_areas: integer;                     { 0x7E }
    areas: color7_$areas_ptr_t;           { 0x80 }
  end;
  color7_$hdm_ptr_t = ^color7_$hdm_t;

  { The unit's state, 0x14 bytes, zero in the image: the display
    memory's UID, the special object's UID and its segment, which the
    driver fills when it adds the device (smd_dev_info_t).  COLOR7's
    own routines read none of it. }
  color7_$info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
    unused_12: integer;                   { 0x12 }
  end;
  color7_$info_ptr_t = ^color7_$info_t;

  { The unit's descriptor, 0x40 bytes: io/io.ins.pas's dcte_t to the
    status, zeros to 0x2C, and the vector's and the unit's state's
    addresses at 0x2C and 0x30. }
  color7_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    unused_14: array[1..6] of integer32;  { 0x14 }
    hdm: color7_$hdm_ptr_t;               { 0x2C }
    info: color7_$info_ptr_t;             { 0x30 }
    config: univ_ptr;                     { 0x34 }
    unused_38: integer32;                 { 0x38 }
    unused_3c: integer32;                 { 0x3C }
  end;
  color7_$dcte_ptr_t = ^color7_$dcte_t;

  { The driver's state, the overlay section COLOR7_STATIC's contents,
    0x10 bytes (color7/color7.pas):
    - regs: the registers' address;
    - lock: COLOR7_$LOCK_DISPLAY's and COLOR7_$LITES's spin lock;
    - cursor: the cursor whose pattern the board has, -1 for none
      (COLOR7_$XOR_CURSOR loads it, COLOR7_$LOAD_CRSR forgets it);
    - owner, asid: the process and the address space the registers are
      associated with (COLOR7_$ASSOC_CSRS, COLOR7_$DISSOC);
    - config_13, config_12: the control register's bits 13 and 12 at
      boot (COLOR7_$IOINIT): which of the board's two forms the driver
      sets up. }
  color7_$static_t = record
    regs: color7_$regs_ptr_t;             { 0x00 }
    lock: integer32;                      { 0x04 }
    cursor: integer;                      { 0x08 }
    owner: pinteger;                      { 0x0A }
    asid: proc1_$asid_t;                  { 0x0C }
    config_13: boolean;                   { 0x0E }
    config_12: boolean;                   { 0x0F }
  end;

  { A cursor's pattern, 0x28 bytes (SMD's smd_cursor_pattern_t). }
  color7_$cursor_pattern_t = record
    width: integer;                       { 0x00 }
    height: integer;                      { 0x02 }
    hot_x: integer;                       { 0x04 }
    hot_y_adj: integer;                   { 0x06 }
    bitmap: array[1..16] of pinteger;     { 0x08 }
  end;

  { The display's request state as COLOR7_$LOCK_DISPLAY and
    COLOR7_$BLINK_CURSOR see it (SMD's display record,
    smd_display_hw_t; color4/color4.ins.pas color4_$hw_t). }
  color7_$hw_t = record
    unused_00: integer;                   { 0x00 }
    lock_state: integer;                  { 0x02 }
    unused_04: array[2..24] of integer;   { 0x04 }
    cursor_pos: smd_$pos_t;               { 0x32 }
    cursor_number: pinteger;              { 0x36 }
    unused_38: array[28..38] of integer;  { 0x38 }
    disp_limits: smd_$window_limits_t;    { 0x4E }
  end;

  { The blink state COLOR7_$BLINK_CURSOR is given (SMD_TIME_$COM's
    layout): the boolean at 0x2, whether the cursor is painted. }
  color7_$blink_t = record
    unused_00: integer;                   { 0x00 }
    cursor_painted: boolean;              { 0x02 }
  end;

  { The characters COLOR7_$PUTC writes, indexed from 1. }
  color7_$chars_t = array[1..256] of char;

  { A cursor's bitmap as COLOR7_$LOAD_CRSR is given it. }
  color7_$bitmap_t = array[1..32] of pinteger;

var
  { SMD_$CURSOR_TABLE (map symbol, SMD_WIRED's hand-written data): the
    four cursor patterns, indexed by the cursor number. }
  smd_$cursor_table: extern array[0..3] of color7_$cursor_pattern_t;

{ ---- COLOR7's routines (color7/color7.pas) ---- }

{ COLOR7_$IOINIT - find and set up the COLOR7 board at boot.  The
  descriptor's init routine (io/io.ins.pas's dcte_init_proc_t): the
  descriptor by address, the status in D0. }
function color7_$ioinit(var dcte: color7_$dcte_t): integer32; extern;

{ COLOR7_$COLD_INIT - forget the registers' owner at cold start. }
procedure color7_$cold_init(dcte: color7_$dcte_ptr_t);
  options(extern, val_param);

{ COLOR7_$VIDEO_CTL - turn the video on or off. }
procedure color7_$video_ctl(dcte: color7_$dcte_ptr_t; on: boolean);
  options(extern, val_param);

{ COLOR7_$CLEAR_SCREEN - clear the screen. }
procedure color7_$clear_screen(dcte: color7_$dcte_ptr_t);
  options(extern, val_param);

{ COLOR7_$MAP_DISPLAY_MEMORY - give the display memory's address. }
procedure color7_$map_display_memory(dcte: color7_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     out va: univ_ptr;
                                     out status: status_$t);
  options(extern, val_param);

{ COLOR7_$ASSOC_CSRS - give the current process the board's registers. }
procedure color7_$assoc_csrs(dcte: color7_$dcte_ptr_t; out va: univ_ptr;
                             out status: status_$t);
  options(extern, val_param);

{ COLOR7_$DISSOC - dissociate the board from the current process. }
procedure color7_$dissoc(dcte: color7_$dcte_ptr_t; out status: status_$t);
  options(extern, val_param);

{ COLOR7_$PUTC - write characters to the display TTY. }
procedure color7_$putc(dcte: color7_$dcte_ptr_t; in chars: color7_$chars_t;
                       count: integer);
  options(extern, val_param);

{ COLOR7_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure color7_$display_logo(dcte: color7_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(extern, val_param);

{ COLOR7_$SHUTDOWN - give up the board at shutdown. }
procedure color7_$shutdown(dcte: color7_$dcte_ptr_t);
  options(extern, val_param);

{ COLOR7_$LOAD_CRSR - take a new cursor pattern. }
procedure color7_$load_crsr(dcte: color7_$dcte_ptr_t; cnum: integer;
                            size: integer; hot_x: integer; hot_y: integer;
                            in bitmap: color7_$bitmap_t);
  options(extern, val_param);

{ COLOR7_$START_WIRED_PROC - mark the start of the driver's wired code. }
procedure color7_$start_wired_proc; extern;

{ COLOR7_$COPY_FONT_MD_HDM - copy the font into the hidden display
  memory. }
function color7_$copy_font_md_hdm(dcte: color7_$dcte_ptr_t;
                                  var font_ptr: univ_ptr;
                                  out status: status_$t): integer;
  options(extern, val_param);

{ COLOR7_$LOCK_DISPLAY - claim the display for a request. }
function color7_$lock_display(dcte: color7_$dcte_ptr_t;
                              var hw: color7_$hw_t;
                              kind: integer): boolean;
  options(extern, val_param);

{ COLOR7_$XOR_CURSOR - draw or remove the cursor. }
function color7_$xor_cursor(dcte: color7_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            remove: boolean): boolean;
  options(extern, val_param);

{ COLOR7_$BLINK_CURSOR - blink the cursor once. }
procedure color7_$blink_cursor(dcte: color7_$dcte_ptr_t;
                               var blink: color7_$blink_t;
                               var hw: color7_$hw_t);
  options(extern, val_param);

{ COLOR7_$BUSY_WAIT - wait until the drawing engine is idle. }
procedure color7_$busy_wait(dcte: color7_$dcte_ptr_t;
                            out status: status_$t);
  options(extern, val_param);

{ COLOR7_$LITES - draw the lights. }
procedure color7_$lites(dcte: color7_$dcte_ptr_t; pattern: integer;
                        y_pos: integer);
  options(extern, val_param);

{ COLOR7_$END_WIRED_PROC - mark the end of the driver's wired code. }
procedure color7_$end_wired_proc; extern;
%else

{ COLOR7_$WORTHLESS - the empty procedure of a configured-out driver. }
procedure color7_$worthless; extern;
%endif
