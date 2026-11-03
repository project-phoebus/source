{ mono/mono.ins.pas - MONO (a monochrome display board) constants, types,
  variables and routine headings, for the Domain Pascal tree.

  The MONO module (mono/mono.pas) and its descriptors and wired data
  (mono/mono_dcte.pas), with the part mono_driver (base/config.ins.pas).
  The routines are the display driver's (SMD_, `display_devices'): it
  calls them through the routine vectors the descriptors point at, each
  with the descriptor's address first, and IO_$INIT calls MONO_$IOINIT as
  each descriptor's init routine.  Two display forms share the board:
  the 1024 by 800 one (display type 11, smdu.ins.pas's
  `smd_$bw5_1024x800') and the 1280 by 1024 one (type 9,
  `smd_$bw4_1280x1024', "DN3000M"), each with its vector.  The driver has
  COLOR4's shape (color4/color4.ins.pas); the records below are MONO's
  own, with what MONO reads and writes of the display driver's records.
  Include base/base.ins.pas, proc1/proc1.ins.pas, io/io.ins.pas and
  smd/smd.ins.pas before it.
}

%if mono_driver %then
const
  { The descriptors' kind and controller type (mono/mono_dcte.pas):
    kind-2 DCTEs without a name, of controller type 7. }
  mono_$dcte_kind = 2;
  mono_$dcte_ctype = 7;

  { The display types of the two forms (smdu.ins.pas). }
  mono_$big_display = 9;                  { smd_$bw4_1280x1024 }
  mono_$small_display = 11;               { smd_$bw5_1024x800 }

  { The two physical pages MONO_$ASSOC_CSRS installs at the process's
    special segment (the CSR page and the next), 1024 bytes apart, and
    their protection; MONO_$COPY_FONT_MD_HDM's kernel mappings of the CSR
    pages and the display memory, and their protection. }
  mono_$page_size = 1024;
  mono_$user_prot = 6;
  mono_$kernel_prot = 22;

  { What MONO_$IOINIT writes to the display memory's first longword and
    reads back to see the memory there. }
  mono_$memory_probe = 16#DEAD0000;

  { The font area MONO_$COPY_FONT_MD_HDM copies to the hidden display
    memory: 39 lines of 14 words, placed at line 1, word 80 on the big
    form, at line 984, word 50 on the small one. }
  mono_$font_lines = 39;
  mono_$font_words = 14;
  mono_$big_font_line = 1;
  mono_$big_font_word = 80;
  mono_$small_font_line = 984;
  mono_$small_font_word = 50;

  { The logo MONO_$DISPLAY_LOGO copies, smd/smd.ins.pas's smd_logo_t: 150
    rows of 32 words. }
  mono_$logo_rows = 150;
  mono_$logo_words = 32;

  { The lights MONO_$LIGHTS draws: 16, each a column word of 16 lines. }
  mono_$light_count = 16;
  mono_$light_lines = 16;

type
  { The board's control and status word at +0x402 (a `[device]'
    record, read at its width): eight flags in its high byte, a byte
    register in its low byte (+0x403).  video_on is the video enable
    (MONO_$VIDEO_CTL); flag_10 set means the board is not to be drawn on
    (MONO_$XOR_CURSOR, MONO_$LIGHTS and MONO_$REL_DISP test it); flag_15
    clear means the lights are drawn inverted, flag_14 selects the
    display memory's upper half for MONO_$LIGHTS; the other flags'
    meanings are the board's. }
  mono_$ctl_t = packed record
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

  { The byte register at +0x404: a 2-bit mode in its top bits
    (MONO_$XOR_CURSOR keeps and restores it), or the byte whole. }
  mono_$reg_404_t = packed record
    case integer of
      1: (mode: 0..3;                     { bits 7..6 }
          rest: 0..63);                   { bits 5..0 }
      2: (all: 0..255);
  end;

  { The board's identification word at +0 as MONO_$IOINIT reads it: in
    the low byte the board's display type. }
  mono_$board_t = packed record
    unused_15_8: 0..255;                  { bits 15..8 }
    id: 0..255;                           { bits 7..0, +0x001 }
  end;

  { A byte register of the board. }
  mono_$byte_t = [byte] 0..255;

  { The board's registers, the CSR pages (2 pages of 1024 bytes,
    io_$acquire_rec_t's csr.va): the mask word at +0 the drawing routines
    set before each write to the display memory (read, the board's
    identification), two words at +2 and +4, and from +0x400 byte
    registers. }
  mono_$regs_t = [device] record
    case integer of
      1: (mask: pinteger;                     { 0x000 }
          word_002: pinteger;                 { 0x002 }
          word_004: pinteger;                 { 0x004 }
          unused_006: array[3..511] of integer;  { 0x006 }
          reg_400: mono_$byte_t;              { 0x400 }
          reg_401: mono_$byte_t;              { 0x401 }
          ctl: mono_$ctl_t;                   { 0x402 }
          reg_404: mono_$reg_404_t;           { 0x404 }
          reg_405: mono_$byte_t;              { 0x405 }
          reg_406: mono_$byte_t);             { 0x406 }
      2: (board: mono_$board_t);              { 0x000 }
  end;
  mono_$regs_ptr_t = ^mono_$regs_t;

  { A display memory line as the driver writes it, through its address:
    the words from where a write starts. }
  mono_$line_t = array[0..1023] of pinteger;
  mono_$line_ptr_t = ^mono_$line_t;

  { The display memory's first longword, as MONO_$IOINIT probes it. }
  mono_$probe_ptr_t = ^integer32;

  { An area of the driver's code or data, the start and end addresses
    SMD_$INIT unwires (smd/smd_internal.ins.pas smd_dev_area_t). }
  mono_$area_t = record
    start_va: univ_ptr;                   { 0x00 }
    end_va: univ_ptr;                     { 0x04 }
  end;
  mono_$areas_t = array[1..2] of mono_$area_t;
  mono_$areas_ptr_t = ^mono_$areas_t;

  { A display form's routine vector and parameters, 0x84 bytes (the
    driver's smd_dev_vector_t), as color4/color4.ins.pas's color4_$hdm_t,
    with no SET_COLOR_TABLE:
    - hw_uid and the display type (9 or 11);
    - line_bits, word_74, width, height: the display memory's line in
      bits and its lines (2048 by 1024 for the big form, 1024 by 1024 for
      the small), and the visible width and height (1280 by 1024, 1024 by
      800); the routines size the display memory by line_bits * word_74;
    - n_areas, areas: the driver's wired data and code. }
  mono_$hdm_t = record
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
    disp_type: integer;                   { 0x70 }
    line_bits: pinteger;                  { 0x72 }
    word_74: pinteger;                    { 0x74 }
    width: pinteger;                      { 0x76 }
    height: pinteger;                     { 0x78 }
    unused_7a: array[1..2] of integer;    { 0x7A }
    n_areas: integer;                     { 0x7E }
    areas: mono_$areas_ptr_t;             { 0x80 }
  end;
  mono_$hdm_ptr_t = ^mono_$hdm_t;

  { A unit's state, 0x38 bytes, zero in the image: color4/color4.ins.pas's
    color4_$info_t to 0x30, then where MONO_$XOR_CURSOR last drew the
    cursor (its column and line) and whether it is drawn there. }
  mono_$info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
    unused_12: integer;                   { 0x12 }
    special_va: univ_ptr;                 { 0x14 }
    csr_ppn: integer32;                   { 0x18 }
    regs: mono_$regs_ptr_t;               { 0x1C }
    memory: integer32;                    { 0x20 }
    lock: integer32;                      { 0x24 }
    lights_lock: integer32;               { 0x28 }
    owner: pinteger;                      { 0x2C }
    asid: proc1_$asid_t;                  { 0x2E }
    drawn_column: integer;                { 0x30 }
    drawn_line: integer;                  { 0x32 }
    drawn: boolean;                       { 0x34 }
    unused_35: char;                      { 0x35 }
    unused_36: integer;                   { 0x36 }
  end;
  mono_$info_ptr_t = ^mono_$info_t;

  { A unit's I/O map request (io/io.ins.pas io_$acquire_rec_t, 0x20
    bytes): each unit has one for its display memory, which the DCTE
    names and whose first longword holds the address of the CSR pages'
    request (MONO_$IOINIT maps and unmaps both; mono/mono_dcte.pas). }
  mono_$req_ptr_t = ^io_$acquire_rec_t;

  { A unit's descriptor, 0x40 bytes: io/io.ins.pas's dcte_t to the
    status, zeros to 0x2C, and the vector's, the unit's state's and its
    memory request's addresses at 0x2C, 0x30, 0x34.  The init routine's
    cell is univ_ptr, as in io/dctes.pas. }
  mono_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    unused_14: array[1..6] of integer32;  { 0x14 }
    hdm: mono_$hdm_ptr_t;                 { 0x2C }
    info: mono_$info_ptr_t;               { 0x30 }
    config: univ_ptr;                     { 0x34 }
    unused_38: integer32;                 { 0x38 }
    unused_3c: integer32;                 { 0x3C }
  end;
  mono_$dcte_ptr_t = ^mono_$dcte_t;

  { The fonts MONO_$COPY_FONT_MD_HDM is given by address: the font
    pointer (DTTY_$STD_FONT_P) and, after it, the 39 lines of 14 words
    it copies. }
  mono_$font_lines_t = array[0..mono_$font_lines - 1] of
                       array[0..mono_$font_words - 1] of pinteger;
  mono_$font_lines_ptr_t = ^mono_$font_lines_t;
  mono_$font_area_t = record
    font_p: univ_ptr;                     { 0x00 }
    lines: mono_$font_lines_t;            { 0x04 }
  end;

  { The characters MONO_$PUTC writes, indexed from 1. }
  mono_$chars_t = array[1..256] of char;

  { A longword seen as its two words: MONO_$XOR_CURSOR's masks. }
  mono_$mask_t = record
    case integer of
      1: (all: integer32);
      2: (hi: pinteger;
          lo: pinteger);
  end;

  { The display's request state as MONO_$LOCK_DISPLAY and MONO_$REL_DISP
    see it (SMD's display record, smd_display_hw_t): the lock state at
    0x2, 0 while the display is free; the cursor's position at 0x32 and
    number at 0x36, and the display's limits at 0x4E
    (MONO_$BLINK_CURSOR). }
  mono_$hw_t = record
    unused_00: integer;                   { 0x00 }
    lock_state: integer;                  { 0x02 }
    unused_04: array[2..24] of integer;   { 0x04 }
    cursor_pos: smd_$pos_t;               { 0x32 }
    cursor_number: pinteger;              { 0x36 }
    unused_38: array[28..38] of integer;  { 0x38 }
    disp_limits: smd_$window_limits_t;    { 0x4E }
  end;

  { The blink state MONO_$BLINK_CURSOR is given (SMD_TIME_$COM's
    layout): the boolean at 0x2, whether the cursor is painted. }
  mono_$blink_t = record
    unused_00: integer;                   { 0x00 }
    cursor_painted: boolean;              { 0x02 }
  end;

  { A cursor's pattern, 0x28 bytes (SMD's smd_cursor_pattern_t): width,
    height, hot-spot x, height - hot-spot y - 1, the bitmap of 16 words. }
  mono_$cursor_pattern_t = record
    width: integer;                       { 0x00 }
    height: integer;                      { 0x02 }
    hot_x: integer;                       { 0x04 }
    hot_y_adj: integer;                   { 0x06 }
    bitmap: array[1..16] of pinteger;     { 0x08 }
  end;
  mono_$cursor_pattern_ptr_t = ^mono_$cursor_pattern_t;

  { The requests MONO_$IOINIT had IO_$MAP_CSR map, to be unmapped when
    it fails. }
  mono_$mapped_t = (mono_$csr_mapped, mono_$memory_mapped);
  mono_$mapped_set_t = set of mono_$mapped_t;

var
  { SMD_$CURSOR_TABLE (map symbol, SMD_WIRED's hand-written data): the
    four cursor patterns, indexed by the cursor number. }
  smd_$cursor_table: extern array[0..3] of mono_$cursor_pattern_t;

{ ---- MONO's routines (mono/mono.pas) ---- }

{ MONO_$IOINIT - find and set up a MONO board at boot.  The descriptor's
  init routine (io/io.ins.pas's dcte_init_proc_t): the descriptor by
  address, the status in D0. }
function mono_$ioinit(var dcte: mono_$dcte_t): integer32; extern;

{ MONO_$INSTALL_DISP_MEM - make the display memory a canned object. }
procedure mono_$install_disp_mem(dcte: mono_$dcte_ptr_t;
                                 out status: status_$t);
  options(extern, val_param);

{ MONO_$CLEAR_SCREEN - clear the screen: nothing to do. }
procedure mono_$clear_screen(dcte: mono_$dcte_ptr_t);
  options(extern, val_param);

{ MONO_$VIDEO_CTL - turn the video on or off. }
procedure mono_$video_ctl(dcte: mono_$dcte_ptr_t; on: boolean);
  options(extern, val_param);

{ MONO_$REL_DISP - release the display after a request. }
procedure mono_$rel_disp(dcte: mono_$dcte_ptr_t; var hw: mono_$hw_t);
  options(extern, val_param);

{ MONO_$MAP_DISPLAY_MEMORY - map the display memory into the current
  address space. }
procedure mono_$map_display_memory(dcte: mono_$dcte_ptr_t;
                                   arg_2: integer32; arg_3: integer32;
                                   out va: univ_ptr;
                                   out status: status_$t);
  options(extern, val_param);

{ MONO_$UNMAP_DISPLAY_MEMORY - unmap the display memory. }
procedure mono_$unmap_display_memory(dcte: mono_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     va: integer32;
                                     out status: status_$t);
  options(extern, val_param);

{ MONO_$ASSOC_CSRS - map the board's registers into the current process. }
procedure mono_$assoc_csrs(dcte: mono_$dcte_ptr_t; out va: univ_ptr;
                           out status: status_$t);
  options(extern, val_param);

{ MONO_$DISSOC - dissociate the board from the current process. }
procedure mono_$dissoc(dcte: mono_$dcte_ptr_t; out status: status_$t);
  options(extern, val_param);

{ MONO_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure mono_$display_logo(dcte: mono_$dcte_ptr_t; logo: smd_logo_ptr_t;
                             out status: status_$t);
  options(extern, val_param);

{ MONO_$COPY_FONT_MD_HDM - copy the fonts to hidden display memory. }
function mono_$copy_font_md_hdm(dcte: mono_$dcte_ptr_t;
                                var font: mono_$font_area_t;
                                out status: status_$t): integer;
  options(extern, val_param);

{ MONO_$LOCK_DISPLAY - claim the display for a request. }
function mono_$lock_display(dcte: mono_$dcte_ptr_t; var hw: mono_$hw_t;
                            kind: integer): boolean;
  options(extern, val_param);

{ MONO_$XOR_CURSOR - draw or remove the cursor. }
function mono_$xor_cursor(dcte: mono_$dcte_ptr_t; cursor_num: pinteger;
                          pos: smd_$pos_t;
                          in limits: smd_$window_limits_t;
                          restore: boolean): boolean;
  options(extern, val_param);

{ MONO_$BLINK_CURSOR - blink the cursor once. }
procedure mono_$blink_cursor(dcte: mono_$dcte_ptr_t;
                             var blink: mono_$blink_t;
                             var hw: mono_$hw_t);
  options(extern, val_param);

{ MONO_$PUTC - write characters to the display TTY. }
procedure mono_$putc(dcte: mono_$dcte_ptr_t; in chars: mono_$chars_t;
                     count: integer);
  options(extern, val_param);

{ MONO_$LIGHTS - draw the lights. }
procedure mono_$lights(dcte: mono_$dcte_ptr_t; pattern: integer;
                       y_pos: integer);
  options(extern, val_param);

{ MONO_$END_WIRED_PROC - the end of the wired code: an empty procedure,
  the last of MONO_WIRED_PROC; only its address is used
  (MONO_$WIRED_DATA's code area). }
procedure mono_$end_wired_proc; extern;
%endif
