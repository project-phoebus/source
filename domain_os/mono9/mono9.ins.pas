{ mono9/mono9.ins.pas - MONO9_ (the DN2500 monochrome display) constants,
  types, variables and routine headings, for the Domain Pascal tree.

  The MONO9 module (mono9/mono9.pas), its descriptor (mono9/mono9_desc.pas)
  and its hand-written MONO9_ASM (mono9/sau9/mono9_asm.s), with the part
  mono9_display (base/config.ins.pas).  Apollo's customer insert files of
  SR10.2 name the display only in gpr.ins.pas (`gpr_$mono9_2kx1k',
  "1280x1k or 1kx800 monochrome").  The display driver that calls the
  routines (the SAU9's SMD_) is not translated: the records below are
  the parts of its interface that MONO9 itself reads and writes, with
  stand-ins elsewhere.  Include base/base.ins.pas, proc1/proc1.ins.pas
  and smd/smd.ins.pas before it.
}

const
  { The descriptor's kind and controller type (mono9/mono9_desc.pas):
    a kind-2 DCTE, the SAU9's DCTEs' form with a name, of controller type
    7. }
  mono9_$dcte_kind = 2;
  mono9_$dcte_ctype = 7;

  { The display memory object's length, 256 KB: MST_$MAP's and
    MST_$UNMAP's, and OS_$INSTALL_DISPLAY_ASTE's size. }
  mono9_$memory_size = 262144;

  { The two physical pages MONO9_$ASSOC installs at the process's
    special segment, 1024 bytes apart, and their protection. }
  mono9_$ctl_ppn_1 = 16#81;
  mono9_$ctl_ppn_2 = 16#82;
  mono9_$ctl_page_size = 1024;
  mono9_$ctl_prot = 6;

  { The display's two forms, which DISP_QUERY tells apart (0: the
    1024 by 800 one; 1: the 1280 by 1024 one; 2: no display). }
  mono9_$small_width = 1024;
  mono9_$small_height = 800;
  mono9_$no_display = 2;

  { The logo DISPLAY_LOGO copies, smd/smd.ins.pas's smd_logo_t: 150 rows
    of 32 words. }
  mono9_$logo_rows = 150;
  mono9_$logo_words = 32;

type
  { The display's routine vector and parameters, 0x84 bytes, the first
    record of MONO9_$WIRED_DATA.  The display driver reaches it through
    the descriptor's hdm field and calls the routines through it, each
    with the descriptor's address first.  The cells are univ_ptr, as
    io/dctes.pas's DCTE cells are, so that the routines' `addr' can fill
    them.  The driver fills the nil cells from its own defaults.
    - field_00: 1 in the image, read by no MONO9 routine;
    - hw_uid: a UID, read by no MONO9 routine;
    - disp_type: 15, gpr.ins.pas's `gpr_$mono9_2kx1k';
    - line_bits, width, height: the display memory's line in bits (2048)
      and the visible width and height (1280 by 1024, MONO9_$IOINIT's
      1024 by 800 for the small form); MONO9_$DISPLAY_LOGO centers the
      logo by them;
    - word_74: 1024 in the image, read by no MONO9 routine. }
  mono9_$hdm_t = record
    field_00: integer32;                  { 0x00 }
    slot_04: univ_ptr;                    { 0x04 }
    video_ctl: univ_ptr;                  { 0x08 }
    slot_0c: univ_ptr;                    { 0x0C }
    slot_10: univ_ptr;                    { 0x10 }
    copy_font_md_hdm: univ_ptr;           { 0x14 }
    lock_display: univ_ptr;               { 0x18 }
    blink_cursor: univ_ptr;               { 0x1C }
    xor_cursor: univ_ptr;                 { 0x20 }
    slot_24: univ_ptr;                    { 0x24 }
    map_disp: univ_ptr;                   { 0x28 }
    unmap_disp: univ_ptr;                 { 0x2C }
    install_disp: univ_ptr;               { 0x30 }
    slot_34: univ_ptr;                    { 0x34 }
    assoc: univ_ptr;                      { 0x38 }
    dissoc: univ_ptr;                     { 0x3C }
    slot_40: univ_ptr;                    { 0x40 }
    clear_screen: univ_ptr;               { 0x44 }
    slot_48: univ_ptr;                    { 0x48 }
    display_logo: univ_ptr;               { 0x4C }
    set_color_table: univ_ptr;            { 0x50 }
    slots_54: array[1..5] of univ_ptr;    { 0x54 }
    hw_uid: uid_$t;                       { 0x68 }
    disp_type: integer;                   { 0x70 }
    line_bits: pinteger;                  { 0x72 }
    word_74: pinteger;                    { 0x74 }
    width: pinteger;                      { 0x76 }
    height: pinteger;                     { 0x78 }
    unused_7a: array[1..5] of integer;    { 0x7A }
  end;
  mono9_$hdm_ptr_t = ^mono9_$hdm_t;

  { The display's state, 0x24 bytes, MONO9_$WIRED_DATA's second record,
    zero in the image:
    - display_uid, special_uid, special_seg: the display memory's UID,
      the special object's UID and its segment (the driver fills them
      when it adds the device);
    - memory_addr: the display memory's address (MONO9_$IOINIT copies it
      from the configuration);
    - asid, owner, special_va: the address space and the process the
      display is associated with, and where the special segment is
      mapped (MONO9_$ASSOC, MONO9_$DISSOC). }
  mono9_$info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
    unused_12: integer;                   { 0x12 }
    memory_addr: integer32;               { 0x14 }
    unused_18: integer32;                 { 0x18 }
    asid: proc1_$asid_t;                  { 0x1C }
    owner: pinteger;                      { 0x1E }
    special_va: univ_ptr;                 { 0x20 }
  end;
  mono9_$info_ptr_t = ^mono9_$info_t;

  { The display's configuration, 0x20 bytes, MONO9_$WIRED_DATA's third
    record: memory_addr, the display memory's address; the words after
    it are read by no MONO9 routine. }
  mono9_$config_t = record
    unused_00: integer32;                 { 0x00 }
    unused_04: integer32;                 { 0x04 }
    unused_08: integer32;                 { 0x08 }
    memory_addr: integer32;               { 0x0C }
    word_10: pinteger;                    { 0x10 }
    word_12: pinteger;                    { 0x12 }
    word_14: pinteger;                    { 0x14 }
    word_16: pinteger;                    { 0x16 }
    word_18: pinteger;                    { 0x18 }
    word_1a: pinteger;                    { 0x1A }
    unused_1c: integer32;                 { 0x1C }
  end;
  mono9_$config_ptr_t = ^mono9_$config_t;

  { The overlay section MONO9_$WIRED_DATA (the map's load section, 0xC8
    bytes, no module segment in it): the three records. }
  mono9_$wired_data_t = record
    hdm: mono9_$hdm_t;                    { 0x00 }
    info: mono9_$info_t;                  { 0x84 }
    config: mono9_$config_t;              { 0xA8 }
  end;

  { The display's descriptor, MONO9_$UNIT (mono9/mono9_desc.pas), 0x40
    bytes: io/io.ins.pas's dcte_t to the name, a kind-2 DCTE's 12 bytes
    of tag (a class character, then four characters at 0x1F), and the
    three records' addresses at 0x2C, 0x30, 0x34.  The init routine's
    cell is univ_ptr, as in io/dctes.pas. }
  mono9_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    name: array[1..8] of char;            { 0x14 }
    tag: array[1..12] of char;            { 0x1C }
    vector_ptr: integer32;                { 0x28 }
    hdm: mono9_$hdm_ptr_t;                { 0x2C }
    info: mono9_$info_ptr_t;              { 0x30 }
    config: mono9_$config_ptr_t;          { 0x34 }
    unused_38: integer32;                 { 0x38 }
    unused_3c: integer32;                 { 0x3C }
  end;
  mono9_$dcte_ptr_t = ^mono9_$dcte_t;

  { MONO9_$LOCK_DISPLAY's request: the word at 0x2, 0 while the display
    is free, which the routine sets to 5. }
  mono9_$lock_req_t = record
    unused_00: integer;                   { 0x00 }
    state: integer;                       { 0x02 }
  end;

  { MONO9_$BLINK_CURSOR's blink state: the boolean at 0x2 it toggles. }
  mono9_$blink_t = record
    unused_00: integer;                   { 0x00 }
    on: boolean;                          { 0x02 }
  end;

  { MONO9_$BLINK_CURSOR's cursor: its position at 0x32 and its number
    at 0x36, passed on to MONO9_$XOR_CURSOR. }
  mono9_$cursor_t = record
    unused_00: array[1..25] of integer;   { 0x00 }
    pos: smd_$pos_t;                      { 0x32 }
    cursor_num: integer;                  { 0x36 }
  end;

  { A display memory line as MONO9_$DISPLAY_LOGO writes the logo into
    it: 32 words. }
  mono9_$logo_line_t = array[1..mono9_$logo_words] of pinteger;
  mono9_$logo_line_ptr_t = ^mono9_$logo_line_t;

{ ---- The hand-written MONO9_ASM (mono9/sau9/mono9_asm.s) ---- }

{ DISP_QUERY (map symbol, without `$'): the display's form from the
  video controller's register; no arguments, the word in D0 (0, 1 or 2;
  MONO9_$IOINIT compares it with 2 unsigned). }
function disp_query: pinteger; extern;

{ MONO9_$VIDEO_CTL: the descriptor and a boolean by value off the stack;
  the boolean turns the video on (bit 3 of the controller's register at
  +0x4 set) or off. }
procedure mono9_$video_ctl(dcte: mono9_$dcte_ptr_t; on: boolean);
  options(extern, val_param);

{ MONO9_$SET_COLOR_TABLE: the descriptor, a longword it does not read,
  a boolean by address (nonzero keeps bit 4 of the controller's register
  at +0x400 set) and the status by address, which it clears. }
procedure mono9_$set_color_table(dcte: mono9_$dcte_ptr_t; arg_2: integer32;
                                 in flag: boolean; out status: status_$t);
  options(extern, val_param);

{ MONO9_$XOR_CURSOR: a longword it does not read (MONO9_$BLINK_CURSOR
  passes the state record's address, the driver the descriptor's), the
  cursor's number and its position by value; the cursor's pattern from
  SMD_$CURSOR_TABLE exclusive-or'ed into the display memory. }
procedure mono9_$xor_cursor(arg_1: univ_ptr; cursor_num: integer;
                            pos: smd_$pos_t);
  options(extern, val_param);

{ ---- MONO9's routines (mono9/mono9.pas) ---- }

{ MONO9_$LOCK_DISPLAY - claim the display for a request. }
function mono9_$lock_display(dcte: mono9_$dcte_ptr_t;
                             var req: mono9_$lock_req_t;
                             kind: integer): boolean;
  options(extern, val_param);

{ MONO9_$BLINK_CURSOR - blink the cursor once. }
procedure mono9_$blink_cursor(dcte: mono9_$dcte_ptr_t;
                              var blink: mono9_$blink_t;
                              var cursor: mono9_$cursor_t);
  options(extern, val_param);

{ MONO9_$IOINIT - initialize the display controller at boot.  The
  descriptor's init routine (io/io.ins.pas's dcte_init_proc_t): the
  descriptor by address, the status in D0. }
function mono9_$ioinit(var dcte: mono9_$dcte_t): integer32; extern;

{ MONO9_$INSTALL_DISP - make the display memory a canned object. }
procedure mono9_$install_disp(dcte: mono9_$dcte_ptr_t;
                              out status: status_$t);
  options(extern, val_param);

{ MONO9_$COPY_FONT_MD_HDM - copy a font to hidden display memory: this
  display has none. }
function mono9_$copy_font_md_hdm(dcte: mono9_$dcte_ptr_t;
                                 var font: integer32;
                                 out status: status_$t): integer32;
  options(extern, val_param);

{ MONO9_$CLEAR_SCREEN - clear the screen. }
procedure mono9_$clear_screen(dcte: mono9_$dcte_ptr_t);
  options(extern, val_param);

{ MONO9_$MAP_DISP - map the display memory into the current address
  space. }
procedure mono9_$map_disp(dcte: mono9_$dcte_ptr_t; arg_2: integer32;
                          arg_3: integer32; out va: univ_ptr;
                          out status: status_$t);
  options(extern, val_param);

{ MONO9_$UNMAP_DISP - unmap the display memory. }
procedure mono9_$unmap_disp(dcte: mono9_$dcte_ptr_t; arg_2: integer32;
                            arg_3: integer32; va: integer32;
                            out status: status_$t);
  options(extern, val_param);

{ MONO9_$ASSOC - associate the display with the current process. }
procedure mono9_$assoc(dcte: mono9_$dcte_ptr_t; out va: univ_ptr;
                       out status: status_$t);
  options(extern, val_param);

{ MONO9_$DISSOC - dissociate the display from the current process. }
procedure mono9_$dissoc(dcte: mono9_$dcte_ptr_t; out status: status_$t);
  options(extern, val_param);

{ MONO9_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure mono9_$display_logo(dcte: mono9_$dcte_ptr_t;
                              logo: smd_logo_ptr_t;
                              out status: status_$t);
  options(extern, val_param);
