{ color5/color5.ins.pas - COLOR5 (a color display board) constants,
  types, variables and routine headings, for the Domain Pascal tree.

  The COLOR5 module (color5/color5.pas) and its descriptors and wired
  data (color5/color5_dcte.pas).  Where the driver is configured out
  (`color5_driver', base/config.ins.pas) what is left is the empty
  COLOR5_$WORTHLESS.  With the driver, the routines are the display
  driver's (SMD_, `display_devices'): it calls them through the routine
  vector the descriptors point at, each with the descriptor's address
  first, and IO_$INIT calls COLOR5_$IOINIT as each descriptor's init
  routine.  Apollo's customer insert files of SR10.2 name the display
  only in smdu.ins.pas (`smd_$color5', display type 10).  The driver has
  COLOR4's shape (color4/color4.ins.pas); the records below are COLOR5's
  own, as COLOR4's are, with what COLOR5 reads and writes of the display
  driver's records.  Include base/base.ins.pas, proc1/proc1.ins.pas,
  io/io.ins.pas and smd/smd.ins.pas before it.
}

%if color5_driver %then
const
  { The descriptors' kind and controller type (color5/color5_dcte.pas):
    kind-2 DCTEs without a name, of controller type 7. }
  color5_$dcte_kind = 2;
  color5_$dcte_ctype = 7;

  { The display memory object's length, 128 KB: 1024 lines of 128
    bytes.  MST_$MAP's and OS_$INSTALL_DISPLAY_ASTE's size. }
  color5_$memory_size = 131072;

  { The display memory's lines as the driver walks them: 128 bytes, 64
    words. }
  color5_$line_words = 64;

  { The two physical pages COLOR5_$ASSOC_CSRS installs at the process's
    special segment (the CSR page and the next), 1024 bytes apart, and
    their protection; COLOR5_$COPY_FONT_MD_HDM's kernel mappings of the
    CSR pages and the display memory, and their protection. }
  color5_$page_size = 1024;
  color5_$user_prot = 6;
  color5_$kernel_prot = 22;

  { The display memory's pages, 128 of 1024 bytes. }
  color5_$memory_pages = 128;

  { The bus address of the CSR page of the unit that COLOR5_$IOINIT sets
    up and clears (COLOR5_$DCTE2's, color5/color5_dcte.pas). }
  color5_$setup_unit_csr = 16#3B0;

  { The repeated settings COLOR5_$IOINIT writes to the port at +0x401. }
  color5_$fill_count = 255;

  { The font area COLOR5_$COPY_FONT_MD_HDM copies to the hidden display
    memory: 39 lines of 14 words, placed at line 984, word 50. }
  color5_$font_lines = 39;
  color5_$font_words = 14;
  color5_$font_line = 984;
  color5_$font_word = 50;

  { The logo COLOR5_$DISPLAY_LOGO copies, smd/smd.ins.pas's smd_logo_t:
    150 rows of 32 words. }
  color5_$logo_rows = 150;
  color5_$logo_words = 32;

  { The lights COLOR5_$LIGHTS draws: 16, each a column word of 16 lines. }
  color5_$light_count = 16;
  color5_$light_lines = 16;

  { Where COLOR5_$XOR_CURSOR keeps what the cursor covers: the hidden
    display memory from line 968, at word 62 (column 992). }
  color5_$save_line = 968;
  color5_$save_word = 62;

type
  { The board's control and status word at +0x402 (a `[device]'
    record, read at its width): eight flags in its high byte, a port in
    its low byte (+0x403).  video_on is the video enable
    (COLOR5_$VIDEO_CTL); flag_10 set means the board is not to be drawn
    on (COLOR5_$XOR_CURSOR, COLOR5_$LIGHTS and COLOR5_$REL_DISP test
    it); the other flags' meanings are the board's. }
  color5_$ctl_t = packed record
    case integer of
      1: (flag_15: boolean;               { bit 15 }
          flag_14: boolean;               { bit 14 }
          flag_13: boolean;               { bit 13 }
          flag_12: boolean;               { bit 12 }
          flag_11: boolean;               { bit 11 }
          flag_10: boolean;               { bit 10 }
          flag_9: boolean;                { bit 9 }
          video_on: boolean;              { bit 8 }
          reg_403: 0..255);               { bits 7..0, +0x403 }
      2: (flags: 0..255;                  { bits 15..8, +0x402 }
          low: 0..255);                   { bits 7..0, +0x403 }
  end;

  { The board's identification word at +0 as COLOR5_$IOINIT reads it:
    flag_8, which COLOR5_$IOINIT waits to see clear, and in the low byte
    the board's display type. }
  color5_$board_t = packed record
    unused_15_9: 0..127;                  { bits 15..9 }
    flag_8: boolean;                      { bit 8 }
    id: 0..255;                           { bits 7..0, +0x001 }
  end;

  { A byte register of the board. }
  color5_$byte_t = [byte] 0..255;

  { The board's registers, the CSR pages (2 pages of 1024 bytes,
    io_$acquire_rec_t's csr.va): the mask word at +0 the drawing routines
    set before each write to the display memory (read, the board's
    identification), two words at +2 and +4, and from +0x400 byte
    registers. }
  color5_$regs_t = [device] record
    case integer of
      1: (mask: pinteger;                     { 0x000 }
          word_002: pinteger;                 { 0x002 }
          word_004: pinteger;                 { 0x004 }
          unused_006: array[3..511] of integer;  { 0x006 }
          reg_400: color5_$byte_t;            { 0x400 }
          reg_401: color5_$byte_t;            { 0x401 }
          ctl: color5_$ctl_t;                 { 0x402 }
          reg_404: color5_$byte_t;            { 0x404 }
          reg_405: color5_$byte_t;            { 0x405 }
          reg_406: color5_$byte_t;            { 0x406 }
          reg_407: color5_$byte_t);           { 0x407 }
      2: (board: color5_$board_t);            { 0x000 }
  end;
  color5_$regs_ptr_t = ^color5_$regs_t;

  { The display memory as the driver addresses it: 1024 lines of 64
    words from the memory's address. }
  color5_$memory_t = array[0..1023] of
                     array[0..color5_$line_words - 1] of pinteger;
  color5_$memory_ptr_t = ^color5_$memory_t;

  { One line of the display memory, COLOR5_$LIGHTS's view. }
  color5_$memory_line_t = array[0..color5_$line_words - 1] of pinteger;

  { An area of the driver's code or data, the start and end addresses
    SMD_$INIT unwires (smd/smd_internal.ins.pas smd_dev_area_t). }
  color5_$area_t = record
    start_va: univ_ptr;                   { 0x00 }
    end_va: univ_ptr;                     { 0x04 }
  end;
  color5_$areas_t = array[1..2] of color5_$area_t;
  color5_$areas_ptr_t = ^color5_$areas_t;

  { The display's routine vector and parameters, 0x84 bytes (the
    driver's smd_dev_vector_t), as color4/color4.ins.pas's
    color4_$hdm_t, with no SET_COLOR_TABLE:
    - hw_uid and the display type, 10 (smdu.ins.pas's `smd_$color5');
      COLOR5_$IOINIT compares the type's low byte (+0x71) with the
      board's identification byte, so the word is two bytes here;
    - line_bits, word_74, width, height: 1024, 1024, 1024 by 800;
    - n_areas, areas: the driver's wired data and code. }
  color5_$hdm_t = record
    field_00: integer32;                  { 0x00 }
    slot_04: univ_ptr;                    { 0x04 }
    video_ctl: univ_ptr;                  { 0x08 }
    slot_0c: univ_ptr;                    { 0x0C }
    slot_10: univ_ptr;                    { 0x10 }
    copy_font_md_hdm: univ_ptr;           { 0x14 }
    lock_display: univ_ptr;               { 0x18 }
    blink_cursor: univ_ptr;               { 0x1C }
    xor_cursor: univ_ptr;                 { 0x20 }
    rel_disp: univ_ptr;                   { 0x24 }
    map_display_memory: univ_ptr;         { 0x28 }
    unmap_display_memory: univ_ptr;       { 0x2C }
    install_disp_mem: univ_ptr;           { 0x30 }
    lights: univ_ptr;                     { 0x34 }
    assoc_csrs: univ_ptr;                 { 0x38 }
    dissoc: univ_ptr;                     { 0x3C }
    slot_40: univ_ptr;                    { 0x40 }
    clear_screen: univ_ptr;               { 0x44 }
    putc: univ_ptr;                       { 0x48 }
    display_logo: univ_ptr;               { 0x4C }
    slots_50: array[1..6] of univ_ptr;    { 0x50 }
    hw_uid: uid_$t;                       { 0x68 }
    disp_type_hi: color5_$byte_t;         { 0x70 }
    disp_type: color5_$byte_t;            { 0x71 }
    line_bits: pinteger;                  { 0x72 }
    word_74: pinteger;                    { 0x74 }
    width: pinteger;                      { 0x76 }
    height: pinteger;                     { 0x78 }
    unused_7a: array[1..2] of integer;    { 0x7A }
    n_areas: integer;                     { 0x7E }
    areas: color5_$areas_ptr_t;           { 0x80 }
  end;
  color5_$hdm_ptr_t = ^color5_$hdm_t;

  { A cursor's width and height, the first longword of its pattern,
    which COLOR5_$XOR_CURSOR keeps whole. }
  color5_$size_t = record
    width: integer;                       { 0x00 }
    height: integer;                      { 0x02 }
  end;

  { A unit's state, 0x38 bytes, zero in the image: color4/color4.ins.pas's
    color4_$info_t to 0x30, then where COLOR5_$XOR_CURSOR saved what the
    cursor covers (the column and line of the cursor's pattern, and its
    size; a height of 0 when nothing is saved). }
  color5_$info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
    unused_12: integer;                   { 0x12 }
    special_va: univ_ptr;                 { 0x14 }
    csr_ppn: integer32;                   { 0x18 }
    regs: color5_$regs_ptr_t;             { 0x1C }
    memory: integer32;                    { 0x20 }
    lock: integer32;                      { 0x24 }
    lights_lock: integer32;               { 0x28 }
    owner: pinteger;                      { 0x2C }
    asid: proc1_$asid_t;                  { 0x2E }
    saved_column: integer;                { 0x30 }
    saved_line: integer;                  { 0x32 }
    saved_size: color5_$size_t;           { 0x34 }
  end;
  color5_$info_ptr_t = ^color5_$info_t;

  { A unit's I/O map request (io/io.ins.pas io_$acquire_rec_t, 0x20
    bytes): each unit has one for its display memory and one for its CSR
    pages, whose first longword holds the memory request's address
    (COLOR5_$IOINIT maps and unmaps both; color5/color5_dcte.pas). }
  color5_$req_ptr_t = ^io_$acquire_rec_t;

  { A unit's descriptor, 0x40 bytes: io/io.ins.pas's dcte_t to the
    status, zeros to 0x2C, and the vector's, the unit's state's and its
    CSR request's addresses at 0x2C, 0x30, 0x34.  The init routine's cell
    is univ_ptr, as in io/dctes.pas. }
  color5_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    unused_14: array[1..6] of integer32;  { 0x14 }
    hdm: color5_$hdm_ptr_t;               { 0x2C }
    info: color5_$info_ptr_t;             { 0x30 }
    config: univ_ptr;                     { 0x34 }
    unused_38: integer32;                 { 0x38 }
    unused_3c: integer32;                 { 0x3C }
  end;
  color5_$dcte_ptr_t = ^color5_$dcte_t;

  { The fonts COLOR5_$COPY_FONT_MD_HDM is given by address: the font
    pointer (DTTY_$STD_FONT_P) and, after it, the 39 lines of 14 words
    it copies. }
  color5_$font_lines_t = array[0..color5_$font_lines - 1] of
                         array[0..color5_$font_words - 1] of pinteger;
  color5_$font_lines_ptr_t = ^color5_$font_lines_t;
  color5_$font_area_t = record
    font_p: univ_ptr;                     { 0x00 }
    lines: color5_$font_lines_t;          { 0x04 }
  end;

  { The characters COLOR5_$PUTC writes, indexed from 1. }
  color5_$chars_t = array[1..256] of char;

  { A longword seen as its two words: COLOR5_$XOR_CURSOR's masks. }
  color5_$mask_t = record
    case integer of
      1: (all: integer32);
      2: (hi: pinteger;
          lo: pinteger);
  end;

  { The display's request state as COLOR5_$LOCK_DISPLAY and
    COLOR5_$REL_DISP see it (SMD's display record, smd_display_hw_t): the
    lock state at 0x2, 0 while the display is free; the cursor's position
    at 0x32 and number at 0x36, and the display's limits at 0x4E
    (COLOR5_$BLINK_CURSOR). }
  color5_$hw_t = record
    unused_00: integer;                   { 0x00 }
    lock_state: integer;                  { 0x02 }
    unused_04: array[2..24] of integer;   { 0x04 }
    cursor_pos: smd_$pos_t;               { 0x32 }
    cursor_number: pinteger;              { 0x36 }
    unused_38: array[28..38] of integer;  { 0x38 }
    disp_limits: smd_$window_limits_t;    { 0x4E }
  end;

  { The blink state COLOR5_$BLINK_CURSOR is given (SMD_TIME_$COM's
    layout): the boolean at 0x2, whether the cursor is painted. }
  color5_$blink_t = record
    unused_00: integer;                   { 0x00 }
    cursor_painted: boolean;              { 0x02 }
  end;

  { A cursor's pattern, 0x28 bytes (SMD's smd_cursor_pattern_t): its
    size, hot-spot x, height - hot-spot y - 1, the bitmap of 16 words. }
  color5_$cursor_pattern_t = record
    size: color5_$size_t;                 { 0x00 }
    hot_x: integer;                       { 0x04 }
    hot_y_adj: integer;                   { 0x06 }
    bitmap: array[1..16] of pinteger;     { 0x08 }
  end;
  color5_$cursor_pattern_ptr_t = ^color5_$cursor_pattern_t;

  { The requests COLOR5_$IOINIT had IO_$MAP_CSR map, to be unmapped
    when it fails. }
  color5_$mapped_t = (color5_$csr_mapped, color5_$memory_mapped);
  color5_$mapped_set_t = set of color5_$mapped_t;

var
  { SMD_$CURSOR_TABLE (map symbol, SMD_WIRED's hand-written data): the
    four cursor patterns, indexed by the cursor number. }
  smd_$cursor_table: extern array[0..3] of color5_$cursor_pattern_t;

{ COLOR5_$END_WIRED_PROC: the end of the wired code (the map's first
  symbol of the section after COLOR5_WIRED_PROC); only its address is
  used (COLOR5_$WIRED_DATA's code area). }
procedure color5_$end_wired_proc; extern;

{ ---- COLOR5's routines (color5/color5.pas) ---- }

{ COLOR5_$IOINIT - find and set up a COLOR5 board at boot.  The
  descriptor's init routine (io/io.ins.pas's dcte_init_proc_t): the
  descriptor by address, the status in D0. }
function color5_$ioinit(var dcte: color5_$dcte_t): integer32; extern;

{ COLOR5_$INSTALL_DISP_MEM - make the display memory a canned object. }
procedure color5_$install_disp_mem(dcte: color5_$dcte_ptr_t;
                                   out status: status_$t);
  options(extern, val_param);

{ COLOR5_$CLEAR_SCREEN - clear the screen: nothing to do. }
procedure color5_$clear_screen(dcte: color5_$dcte_ptr_t);
  options(extern, val_param);

{ COLOR5_$VIDEO_CTL - turn the video on or off. }
procedure color5_$video_ctl(dcte: color5_$dcte_ptr_t; on: boolean);
  options(extern, val_param);

{ COLOR5_$REL_DISP - release the display after a request. }
procedure color5_$rel_disp(dcte: color5_$dcte_ptr_t;
                           var hw: color5_$hw_t);
  options(extern, val_param);

{ COLOR5_$MAP_DISPLAY_MEMORY - map the display memory into the current
  address space. }
procedure color5_$map_display_memory(dcte: color5_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     out va: univ_ptr;
                                     out status: status_$t);
  options(extern, val_param);

{ COLOR5_$UNMAP_DISPLAY_MEMORY - unmap the display memory. }
procedure color5_$unmap_display_memory(dcte: color5_$dcte_ptr_t;
                                       arg_2: integer32; arg_3: integer32;
                                       va: integer32;
                                       out status: status_$t);
  options(extern, val_param);

{ COLOR5_$ASSOC_CSRS - map the board's registers into the current
  process. }
procedure color5_$assoc_csrs(dcte: color5_$dcte_ptr_t; out va: univ_ptr;
                             out status: status_$t);
  options(extern, val_param);

{ COLOR5_$DISSOC - dissociate the board from the current process. }
procedure color5_$dissoc(dcte: color5_$dcte_ptr_t; out status: status_$t);
  options(extern, val_param);

{ COLOR5_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure color5_$display_logo(dcte: color5_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(extern, val_param);

{ COLOR5_$COPY_FONT_MD_HDM - copy the fonts to hidden display memory. }
function color5_$copy_font_md_hdm(dcte: color5_$dcte_ptr_t;
                                  var font: color5_$font_area_t;
                                  out status: status_$t): integer;
  options(extern, val_param);

{ COLOR5_$LOCK_DISPLAY - claim the display for a request. }
function color5_$lock_display(dcte: color5_$dcte_ptr_t;
                              var hw: color5_$hw_t;
                              kind: integer): boolean;
  options(extern, val_param);

{ COLOR5_$XOR_CURSOR - draw or remove the cursor. }
function color5_$xor_cursor(dcte: color5_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            restore: boolean): boolean;
  options(extern, val_param);

{ COLOR5_$BLINK_CURSOR - blink the cursor once. }
procedure color5_$blink_cursor(dcte: color5_$dcte_ptr_t;
                               var blink: color5_$blink_t;
                               var hw: color5_$hw_t);
  options(extern, val_param);

{ COLOR5_$PUTC - write characters to the display TTY. }
procedure color5_$putc(dcte: color5_$dcte_ptr_t; in chars: color5_$chars_t;
                       count: integer);
  options(extern, val_param);

{ COLOR5_$LIGHTS - draw the lights. }
procedure color5_$lights(dcte: color5_$dcte_ptr_t; pattern: integer;
                         y_pos: integer);
  options(extern, val_param);
%endif

{ COLOR5_$WORTHLESS (color5/worthless.pas): an empty procedure, with no
  parameters. }
%if not color5_driver %then
procedure color5_$worthless; extern;
%endif
