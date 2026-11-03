{ color4/color4.ins.pas - COLOR4 (a color display board) constants,
  types, variables and routine headings, for the Domain Pascal tree.

  The COLOR4 module (color4/color4.pas), its descriptors and wired data
  (color4/color4_dcte.pas) and the hand-written COLOR4_ASM
  (color4/m68k/color4_asm.s).  Where the driver is configured out
  (`color4_driver', base/config.ins.pas) what is left is the empty
  COLOR4_$WORTHLESS.  With the driver, the routines are the display
  driver's (SMD_, `display_devices'): it calls them through the routine
  vector the descriptors point at, each with the descriptor's address
  first, and IO_$INIT calls COLOR4_$IOINIT as each descriptor's init
  routine.  Apollo's customer insert files of SR10.2 name the display
  only in smdu.ins.pas (`smd_$color4', display type 8, "DN3000C").
  The display driver's records are SMD's (smd/smd_internal.ins.pas, which
  cannot be included beside os/os.ins.pas): the ones below are what
  COLOR4 itself reads and writes of them, with stand-ins between.
  Include base/base.ins.pas, proc1/proc1.ins.pas, io/io.ins.pas and
  smd/smd.ins.pas before it.
}

%if color4_driver %then
const
  { The descriptors' kind and controller type (color4/color4_dcte.pas):
    kind-2 DCTEs without a name, of controller type 7. }
  color4_$dcte_kind = 2;
  color4_$dcte_ctype = 7;

  { The display memory object's length, 128 KB: 1024 lines of 128
    bytes.  MST_$MAP's and MST_$UNMAP's, and OS_$INSTALL_DISPLAY_ASTE's
    size. }
  color4_$memory_size = 131072;

  { The display memory's lines as the driver walks them: 128 bytes, 64
    words. }
  color4_$line_words = 64;

  { The two physical pages COLOR4_$ASSOC_CSRS installs at the process's
    special segment (the CSR page and the next), 1024 bytes apart, and
    their protection; COLOR4_$COPY_FONT_MD_HDM's kernel mappings of the
    CSR pages and the display memory, and their protection. }
  color4_$page_size = 1024;
  color4_$user_prot = 6;
  color4_$kernel_prot = 22;

  { The display memory's pages, 128 of 1024 bytes. }
  color4_$memory_pages = 128;

  { The bus address of the CSR page of the unit that COLOR4_$IOINIT
    gives its extra register settings and its lookup table's ramp
    (COLOR4_$UNIT_2's, color4/color4_dcte.pas). }
  color4_$lut_unit_csr = 16#3B0;

  { What COLOR4_$IOINIT writes to the display memory's first longword
    and reads back to see the memory there. }
  color4_$memory_probe = 16#DEAD0000;

  { The lookup table's entries COLOR4_$IOINIT fills with its ramp. }
  color4_$lut_entries = 16;

  { The font area COLOR4_$COPY_FONT_MD_HDM copies to the hidden display
    memory: 39 lines of 14 words, placed at line 984, word 50. }
  color4_$font_lines = 39;
  color4_$font_words = 14;
  color4_$font_line = 984;
  color4_$font_word = 50;

  { The logo COLOR4_$DISPLAY_LOGO copies, smd/smd.ins.pas's smd_logo_t:
    150 rows of 32 words. }
  color4_$logo_rows = 150;
  color4_$logo_words = 32;

  { The lights COLOR4_$LITES draws: 16, each a column word of 16 lines. }
  color4_$lite_count = 16;
  color4_$lite_lines = 16;

  { Where COLOR4_$XOR_CURSOR keeps what the cursor covers: the hidden
    display memory at line 968, column 992. }
  color4_$save_line = 968;
  color4_$save_column = 992;

type
  { The board's control and status word at +0x402 (a `[device]'
    record, read at its width): eight flags in its high byte, the
    lookup table's green port in its low byte (+0x403).  video_on is
    the video enable (COLOR4_$VIDEO_CTL); flag_10 set means the board
    is not to be drawn on (COLOR4_$XOR_CURSOR, COLOR4_$LITES and
    COLOR4_$REL_DISP test it); the other flags' meanings are the
    board's. }
  color4_$ctl_t = packed record
    case integer of
      1: (flag_15: boolean;               { bit 15 }
          flag_14: boolean;               { bit 14 }
          flag_13: boolean;               { bit 13 }
          flag_12: boolean;               { bit 12 }
          flag_11: boolean;               { bit 11 }
          flag_10: boolean;               { bit 10 }
          flag_9: boolean;                { bit 9 }
          video_on: boolean;              { bit 8 }
          lut_green: 0..255);             { bits 7..0, +0x403 }
      2: (flags: 0..255;                  { bits 15..8, +0x402 }
          green: 0..255);                 { bits 7..0, +0x403 }
  end;

  { The board's identification word at +0 as COLOR4_$IOINIT reads it:
    flag_8 set once the lookup table can be loaded, and in the low byte
    the board's display type. }
  color4_$board_t = packed record
    unused_15_9: 0..127;                  { bits 15..9 }
    flag_8: boolean;                      { bit 8 }
    id: 0..255;                           { bits 7..0, +0x001 }
  end;

  { A byte register of the board. }
  color4_$byte_t = [byte] 0..255;

  { The board's registers, the CSR pages (2 pages of 1024 bytes,
    io_$acquire_rec_t's csr.va): the mask word at +0 the drawing routines
    set before each write to the display memory (read, the board's
    identification), two words at +2 and +4, and from +0x400 byte
    registers, the lookup table's red and blue ports at +0x401 and +0x405
    (COLOR4_$LOAD_LUT, COLOR4_$IOINIT). }
  color4_$regs_t = [device] record
    case integer of
      1: (mask: pinteger;                     { 0x000 }
          word_002: pinteger;                 { 0x002 }
          word_004: pinteger;                 { 0x004 }
          unused_006: array[3..511] of integer;  { 0x006 }
          reg_400: color4_$byte_t;            { 0x400 }
          lut_red: color4_$byte_t;            { 0x401 }
          ctl: color4_$ctl_t;                 { 0x402 }
          reg_404: color4_$byte_t;            { 0x404 }
          lut_blue: color4_$byte_t;           { 0x405 }
          reg_406: color4_$byte_t);           { 0x406 }
      2: (board: color4_$board_t);            { 0x000 }
  end;
  color4_$regs_ptr_t = ^color4_$regs_t;

  { The display memory as the driver addresses it: 1024 lines of 64
    words from the memory's address (smd/smd_internal.ins.pas's
    smd_$display_memory_t). }
  color4_$memory_t = array[0..1023] of
                     array[0..color4_$line_words - 1] of pinteger;
  color4_$memory_ptr_t = ^color4_$memory_t;

  { One line of the display memory, COLOR4_$LITES's view. }
  color4_$memory_line_t = array[0..color4_$line_words - 1] of pinteger;

  { The display memory's first longword, as COLOR4_$IOINIT probes it. }
  color4_$probe_ptr_t = ^integer32;

  { An area of the driver's code or data, the start and end addresses
    SMD_$INIT unwires (smd/smd_internal.ins.pas smd_dev_area_t). }
  color4_$area_t = record
    start_va: univ_ptr;                   { 0x00 }
    end_va: univ_ptr;                     { 0x04 }
  end;
  color4_$areas_t = array[1..2] of color4_$area_t;
  color4_$areas_ptr_t = ^color4_$areas_t;

  { The display's routine vector and parameters, 0x84 bytes (the
    driver's smd_dev_vector_t).  The cells are univ_ptr, as
    io/dctes.pas's DCTE cells are, so that the routines' `addr' can fill
    them; the driver fills the nil ones from its own defaults.
    - field_00: 1 in the image;
    - hw_uid, disp_type: a UID and the display type, 8 (smdu.ins.pas's
      `smd_$color4');
    - line_bits, word_74, width, height: the display memory's line in
      bits (1024: 128 bytes), its lines (1024), and the visible width and
      height (1024 by 800); COLOR4_$IOINIT clears line_bits by word_74,
      COLOR4_$DISPLAY_LOGO centers the logo by width and height;
    - n_areas, areas: the driver's wired data and code (COLOR4_$WIRED_DATA's
      first record), which SMD_$INIT unwires. }
  color4_$hdm_t = record
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
    lites: univ_ptr;                      { 0x34 }
    assoc_csrs: univ_ptr;                 { 0x38 }
    dissoc: univ_ptr;                     { 0x3C }
    slot_40: univ_ptr;                    { 0x40 }
    clear_screen: univ_ptr;               { 0x44 }
    putc: univ_ptr;                       { 0x48 }
    display_logo: univ_ptr;               { 0x4C }
    set_color_table: univ_ptr;            { 0x50 }
    slots_54: array[1..5] of univ_ptr;    { 0x54 }
    hw_uid: uid_$t;                       { 0x68 }
    disp_type: integer;                   { 0x70 }
    line_bits: pinteger;                  { 0x72 }
    word_74: pinteger;                    { 0x74 }
    width: pinteger;                      { 0x76 }
    height: pinteger;                     { 0x78 }
    unused_7a: array[1..2] of integer;    { 0x7A }
    n_areas: integer;                     { 0x7E }
    areas: color4_$areas_ptr_t;           { 0x80 }
  end;
  color4_$hdm_ptr_t = ^color4_$hdm_t;

  { A unit's state, 0x30 bytes, zero in the image:
    - display_uid, special_uid, special_seg: the display memory's UID,
      the special object's UID and its segment (the driver fills them
      when it adds the device: smd_dev_info_t);
    - special_va: where the special segment is mapped (COLOR4_$ASSOC_CSRS);
    - csr_ppn: the CSR page's physical page (COLOR4_$IOINIT, from the
      bus address);
    - regs, memory: the CSR pages' and the display memory's addresses
      (COLOR4_$IOINIT, from the requests);
    - lock, lites_lock: spin locks of the display memory's mappings and of
      the lights;
    - owner, asid: the process and the address space the CSRs are
      associated with (COLOR4_$ASSOC_CSRS, COLOR4_$DISSOC). }
  color4_$info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
    unused_12: integer;                   { 0x12 }
    special_va: univ_ptr;                 { 0x14 }
    csr_ppn: integer32;                   { 0x18 }
    regs: color4_$regs_ptr_t;             { 0x1C }
    memory: integer32;                    { 0x20 }
    lock: integer32;                      { 0x24 }
    lites_lock: integer32;                { 0x28 }
    owner: pinteger;                      { 0x2C }
    asid: proc1_$asid_t;                  { 0x2E }
  end;
  color4_$info_ptr_t = ^color4_$info_t;

  { A unit's I/O map request (io/io.ins.pas io_$acquire_rec_t, 0x20
    bytes): each unit has one for its CSR pages and one for its display
    memory, whose first longword holds the CSR request's address
    (COLOR4_$IOINIT maps and unmaps both; color4/color4_dcte.pas). }
  color4_$req_ptr_t = ^io_$acquire_rec_t;

  { A unit's descriptor, 0x40 bytes: io/io.ins.pas's dcte_t to the
    status, zeros to 0x2C (a kind-2 DCTE's name and tag, unused here),
    and the vector's, the unit's state's and its memory request's
    addresses at 0x2C, 0x30, 0x34.  The init routine's cell is univ_ptr,
    as in io/dctes.pas. }
  color4_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    unused_14: array[1..6] of integer32;  { 0x14 }
    hdm: color4_$hdm_ptr_t;               { 0x2C }
    info: color4_$info_ptr_t;             { 0x30 }
    config: univ_ptr;                     { 0x34 }
    unused_38: integer32;                 { 0x38 }
    unused_3c: integer32;                 { 0x3C }
  end;
  color4_$dcte_ptr_t = ^color4_$dcte_t;

  { The fonts COLOR4_$COPY_FONT_MD_HDM is given by address: the font
    pointer (DTTY_$STD_FONT_P) and, after it, the 39 lines of 14 words
    it copies. }
  color4_$font_area_t = record
    font_p: univ_ptr;                     { 0x00 }
    lines: array[0..color4_$font_lines - 1] of
           array[0..color4_$font_words - 1] of pinteger;  { 0x04 }
  end;
  color4_$font_lines_ptr_t = ^color4_$font_lines_t;
  color4_$font_lines_t = array[0..color4_$font_lines - 1] of
                         array[0..color4_$font_words - 1] of pinteger;

  { The lookup table's entries COLOR4_$SET_COLOR_TABLE passes on: 4 bytes
    each, red, green, blue and one unused (color4/m68k/color4_asm.s). }
  color4_$color_t = array[0..3] of char;
  color4_$color_table_t = array[0..15] of color4_$color_t;

  { The characters COLOR4_$PUTC writes, indexed from 1. }
  color4_$chars_t = array[1..256] of char;

  { The display's request state as COLOR4_$LOCK_DISPLAY and
    COLOR4_$REL_DISP see it (SMD's display record, smd_display_hw_t): the
    lock state at 0x2, 0 while the display is free; the cursor's position
    at 0x32 and number at 0x36, and the display's limits at 0x4E
    (COLOR4_$BLINK_CURSOR). }
  color4_$hw_t = record
    unused_00: integer;                   { 0x00 }
    lock_state: integer;                  { 0x02 }
    unused_04: array[2..24] of integer;   { 0x04 }
    cursor_pos: smd_$pos_t;               { 0x32 }
    cursor_number: pinteger;              { 0x36 }
    unused_38: array[28..38] of integer;  { 0x38 }
    disp_limits: smd_$window_limits_t;    { 0x4E }
  end;

  { The blink state COLOR4_$BLINK_CURSOR is given (SMD_TIME_$COM's
    layout): the boolean at 0x2, whether the cursor is painted. }
  color4_$blink_t = record
    unused_00: integer;                   { 0x00 }
    cursor_painted: boolean;              { 0x02 }
  end;

  { A cursor's pattern, 0x28 bytes (SMD's smd_cursor_pattern_t): width,
    height, hot-spot x, height - hot-spot y - 1, the bitmap of 16 words. }
  color4_$cursor_pattern_t = record
    width: integer;                       { 0x00 }
    height: integer;                      { 0x02 }
    hot_x: integer;                       { 0x04 }
    hot_y_adj: integer;                   { 0x06 }
    bitmap: array[1..16] of pinteger;     { 0x08 }
  end;

  { The requests COLOR4_$IOINIT had IO_$MAP_CSR map, to be unmapped
    when it fails. }
  color4_$mapped_t = (color4_$csr_mapped, color4_$memory_mapped);
  color4_$mapped_set_t = set of color4_$mapped_t;

  { COLOR4_$IOINIT's ramp for the lookup table: 16 entries of one byte. }
  color4_$ramp_t = array[0..color4_$lut_entries - 1] of color4_$byte_t;

  { A longword seen as its two words: COLOR4_$XOR_CURSOR's masks. }
  color4_$mask_t = record
    case integer of
      1: (all: integer32);
      2: (hi: pinteger;
          lo: pinteger);
  end;

var
  { SMD_$CURSOR_TABLE (map symbol, SMD_WIRED's hand-written data): the
    four cursor patterns, indexed by the cursor number. }
  smd_$cursor_table: extern array[0..3] of color4_$cursor_pattern_t;

{ ---- The hand-written COLOR4_ASM (color4/m68k/color4_asm.s) ---- }

{ COLOR4_$LOAD_LUT: the registers, the first entry and the count (words),
  the entries by address and the status by address, which it clears. }
procedure color4_$load_lut(regs: color4_$regs_ptr_t; first: integer;
                           count: integer;
                           in colors: color4_$color_table_t;
                           out status: status_$t);
  options(extern, val_param);

{ COLOR4_$END_WIRED_PROC: the marker word at the end of the wired code;
  only its address is used (COLOR4_$WIRED_DATA's code area). }
procedure color4_$end_wired_proc; extern;

{ ---- COLOR4's routines (color4/color4.pas) ---- }

{ COLOR4_$IOINIT - find and set up a COLOR4 board at boot.  The
  descriptor's init routine (io/io.ins.pas's dcte_init_proc_t): the
  descriptor by address, the status in D0. }
function color4_$ioinit(var dcte: color4_$dcte_t): integer32; extern;

{ COLOR4_$INSTALL_DISP_MEM - make the display memory a canned object. }
procedure color4_$install_disp_mem(dcte: color4_$dcte_ptr_t;
                                   out status: status_$t);
  options(extern, val_param);

{ COLOR4_$CLEAR_SCREEN - clear the screen: nothing to do. }
procedure color4_$clear_screen(dcte: color4_$dcte_ptr_t);
  options(extern, val_param);

{ COLOR4_$VIDEO_CTL - turn the video on or off. }
procedure color4_$video_ctl(dcte: color4_$dcte_ptr_t; on: boolean);
  options(extern, val_param);

{ COLOR4_$REL_DISP - release the display after a request. }
procedure color4_$rel_disp(dcte: color4_$dcte_ptr_t;
                           var hw: color4_$hw_t);
  options(extern, val_param);

{ COLOR4_$MAP_DISPLAY_MEMORY - map the display memory into the current
  address space. }
procedure color4_$map_display_memory(dcte: color4_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     out va: univ_ptr;
                                     out status: status_$t);
  options(extern, val_param);

{ COLOR4_$UNMAP_DISPLAY_MEMORY - unmap the display memory. }
procedure color4_$unmap_display_memory(dcte: color4_$dcte_ptr_t;
                                       arg_2: integer32; arg_3: integer32;
                                       va: integer32;
                                       out status: status_$t);
  options(extern, val_param);

{ COLOR4_$ASSOC_CSRS - map the board's registers into the current
  process. }
procedure color4_$assoc_csrs(dcte: color4_$dcte_ptr_t; out va: univ_ptr;
                             out status: status_$t);
  options(extern, val_param);

{ COLOR4_$DISSOC - dissociate the board from the current process. }
procedure color4_$dissoc(dcte: color4_$dcte_ptr_t; out status: status_$t);
  options(extern, val_param);

{ COLOR4_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure color4_$display_logo(dcte: color4_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(extern, val_param);

{ COLOR4_$SET_COLOR_TABLE - load entries of the color lookup table. }
procedure color4_$set_color_table(dcte: color4_$dcte_ptr_t;
                                  first: integer; count: integer;
                                  in colors: color4_$color_table_t;
                                  out status: status_$t);
  options(extern, val_param);

{ COLOR4_$COPY_FONT_MD_HDM - copy the fonts to hidden display memory. }
function color4_$copy_font_md_hdm(dcte: color4_$dcte_ptr_t;
                                  var font: color4_$font_area_t;
                                  out status: status_$t): integer;
  options(extern, val_param);

{ COLOR4_$LOCK_DISPLAY - claim the display for a request. }
function color4_$lock_display(dcte: color4_$dcte_ptr_t;
                              var hw: color4_$hw_t;
                              kind: integer): boolean;
  options(extern, val_param);

{ COLOR4_$XOR_CURSOR - draw or remove the cursor. }
function color4_$xor_cursor(dcte: color4_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            restore: boolean): boolean;
  options(extern, val_param);

{ COLOR4_$BLINK_CURSOR - blink the cursor once. }
procedure color4_$blink_cursor(dcte: color4_$dcte_ptr_t;
                               var blink: color4_$blink_t;
                               var hw: color4_$hw_t);
  options(extern, val_param);

{ COLOR4_$PUTC - write characters to the display TTY. }
procedure color4_$putc(dcte: color4_$dcte_ptr_t; in chars: color4_$chars_t;
                       count: integer);
  options(extern, val_param);

{ COLOR4_$LITES - draw the lights. }
procedure color4_$lites(dcte: color4_$dcte_ptr_t; pattern: integer;
                        y_pos: integer);
  options(extern, val_param);
%endif

{ COLOR4_$WORTHLESS - the empty procedure of a configured-out driver. }
%if not color4_driver %then
procedure color4_$worthless; extern;
%endif
