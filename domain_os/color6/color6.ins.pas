{ color6/color6.ins.pas - COLOR6 (the Matrox color display board)
  constants, types, variables and routine headings, for the Domain
  Pascal tree.

  The COLOR6 module (color6/color6.pas) and its descriptors and wired
  data (color6/color6_dcte.pas), on the SAUs with the driver
  (`color6_driver', base/config.ins.pas); the other SAUs' maps have no
  COLOR6 module, and both files compile to nothing there.  The routines
  are the display driver's (SMD_, `display_devices'): it calls them
  through the routine vector the descriptors point at, each with the
  descriptor's address first, and IO_$INIT calls COLOR6_$IOINIT as each
  descriptor's init routine.  Apollo's customer insert files of SR10.2
  name the display only in smdu.ins.pas (`smd_$color6_display', display
  type 12, "matrox or meerkatIII").  The board's registers are
  little-endian: the driver swaps the bytes of the words and longwords
  it exchanges with them (color6_swap16, color6_swap32).
  Include base/base.ins.pas, time/time.ins.pas, proc1/proc1.ins.pas,
  io/io.ins.pas and smd/smd.ins.pas before it.
}

%if color6_driver %then
const
  { The descriptors' kind and controller type (color6/color6_dcte.pas):
    kind-2 DCTEs without a name, of controller type 7. }
  color6_$dcte_kind = 2;
  color6_$dcte_ctype = 7;

  { The display memory object's length, 2 MB: MST_$MAP's and
    MST_$UNMAP's, and OS_$INSTALL_DISPLAY_ASTE's size. }
  color6_$memory_size = 2097152;

  { The board's four register pages as COLOR6_$ASSOC installs them at
    the process's special segment, 1024 bytes apart: the CSR page, the
    command FIFO and the two control pages (the requests' bus addresses
    over 1024, color6/color6_dcte.pas), and their protection, which
    MST_$MAP's mapping of the display memory has too. }
  color6_$csr_ppn = 16#318;
  color6_$fifo_ppn = 16#3500;
  color6_$ctl1_ppn = 16#3600;
  color6_$ctl2_ppn = 16#3680;
  color6_$page_size = 1024;
  color6_$user_prot = 6;

  { The display memory's lines as COLOR6's IOINIT probe clears them: 256
    bytes, 128 words. }
  color6_$line_words = 128;

  { The value the probe writes to the board's test register and reads
    back. }
  color6_$probe_value = 16#BEAD;

  { The page-select register's high bits, set with every page number. }
  color6_$page_sel_bits = 16#F8;

  { The command words COLOR6's FIFO takes: the board's setup (the probe)
    and a cursor's pattern (COLOR6_$SET_CRS_PAT). }
  color6_$cmd_setup = 16#48B0;
  color6_$cmd_cursor = 16#4FC0;

  { The logo COLOR6_$DISPLAY_LOGO copies, smd/smd.ins.pas's smd_logo_t:
    150 rows of 32 words. }
  color6_$logo_rows = 150;
  color6_$logo_words = 32;

type
  { A byte of the board: a register, a page number. }
  color6_$byte_t = [byte] 0..255;

  { The control and status word at +0x31E, a set of its bits: 13 set
    when the board takes a command, 12 when the FIFO is drained by
    waiting, 11 the drain's busy bit (set to start it), 3 and 4 cleared
    before the FIFO's count is read, 5 in the swapped word
    (COLOR6_$XOR_CURSOR).  The bits' names are the board's. }
  color6_$ctl_t = set of 0..15;

  { The board's registers, its four pages from the CSR page's address
    (io_$acquire_rec_t's csr.va of the CSR request): the CSR page, the
    command FIFO at +0x400, the control pages at +0x800 and +0xC00. }
  color6_$regs_t = [device] record
    unused_000: array[0..395] of integer;     { 0x000 }
    word_318: pinteger;                       { 0x318 }
    word_31a: pinteger;                       { 0x31A }
    fifo_count: pinteger;                     { 0x31C }
    ctl: color6_$ctl_t;                       { 0x31E }
    unused_320: array[0..65] of integer;      { 0x320 }
    busy: boolean;                            { 0x3A4 }
    unused_3a5: char;                         { 0x3A5 }
    page_cfg: pinteger;                       { 0x3A6 }
    cursor_x: pinteger;                       { 0x3A8 }
    cursor_y: pinteger;                       { 0x3AA }
    probe: pinteger;                          { 0x3AC }
    unused_3ae: array[0..1] of integer;       { 0x3AE }
    page_sel: color6_$byte_t;                 { 0x3B2 }
    unused_3b3: char;                         { 0x3B3 }
    unused_3b4: array[0..37] of integer;      { 0x3B4 }
    fifo: pinteger;                           { 0x400 }
    unused_402: array[0..513] of integer;     { 0x402 }
    board_id: pinteger;                       { 0x806 }
    unused_808: array[0..507] of integer;     { 0x808 }
    ctl_c00: integer32;                       { 0xC00 }
    video: pinteger;                          { 0xC04 }
  end;
  color6_$regs_ptr_t = ^color6_$regs_t;

  { The FIFO as a longword port (two of the setup command's and of a
    cursor command's operands). }
  color6_$fifo_long_ptr_t = ^integer32;

  { A word or a longword as its bytes (color6_swap16, color6_swap32). }
  color6_$bytes2_t = packed array[0..1] of char;
  color6_$bytes4_t = packed array[0..3] of char;

  { The display memory as the probe clears it: lines of 128 words from
    the memory's address. }
  color6_$memory_t = array[0..1023] of
                     array[0..color6_$line_words - 1] of pinteger;
  color6_$memory_ptr_t = ^color6_$memory_t;

  { An area of the driver's code or data, the start and end addresses
    SMD_$INIT unwires (smd/smd_internal.ins.pas smd_dev_area_t). }
  color6_$area_t = record
    start_va: univ_ptr;                   { 0x00 }
    end_va: univ_ptr;                     { 0x04 }
  end;
  color6_$areas_t = array[1..2] of color6_$area_t;
  color6_$areas_ptr_t = ^color6_$areas_t;

  { The display's routine vector and parameters, 0x84 bytes (the
    driver's smd_dev_vector_t; color4/color4.ins.pas color4_$hdm_t has
    the fields' meanings).  The cells are univ_ptr so that the routines'
    `addr' can fill them; the driver fills the nil ones from its own
    defaults.  disp_type is 12 (smdu.ins.pas's `smd_$color6_display'),
    the display memory's line 2048 bits, its lines 1024, the visible
    width and height 1280 by 1024. }
  color6_$hdm_t = record
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
    areas: color6_$areas_ptr_t;           { 0x80 }
  end;
  color6_$hdm_ptr_t = ^color6_$hdm_t;

  { A unit's state, 0x24 bytes, zero in the image:
    - display_uid, special_uid, special_seg: the display memory's UID,
      the special object's UID and its segment (the driver fills them
      when it adds the device: smd_dev_info_t);
    - regs, memory: the register pages' and the display memory's
      addresses (COLOR6_$IOINIT, from the requests);
    - owner, asid: the process and the address space the registers are
      associated with (COLOR6_$ASSOC, color6_release). }
  color6_$info_t = record
    display_uid: uid_$t;                  { 0x00 }
    special_uid: uid_$t;                  { 0x08 }
    special_seg: pinteger;                { 0x10 }
    unused_12: integer;                   { 0x12 }
    unused_14: integer32;                 { 0x14 }
    regs: color6_$regs_ptr_t;             { 0x18 }
    memory: integer32;                    { 0x1C }
    owner: pinteger;                      { 0x20 }
    asid: proc1_$asid_t;                  { 0x22 }
  end;
  color6_$info_ptr_t = ^color6_$info_t;

  { A unit's I/O map request (io/io.ins.pas io_$acquire_rec_t, 0x20
    bytes): the display memory's, whose first longword is the next
    request's address, the CSR page's (color6/color6_dcte.pas). }
  color6_$req_ptr_t = ^io_$acquire_rec_t;

  { A unit's descriptor, 0x40 bytes: io/io.ins.pas's dcte_t to the
    status, zeros to 0x2C, and the vector's, the unit's state's and the
    memory request's addresses at 0x2C, 0x30, 0x34.  The controller
    number is the board's page of the unit (color6_set_page). }
  color6_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    unused_14: array[1..6] of integer32;  { 0x14 }
    hdm: color6_$hdm_ptr_t;               { 0x2C }
    info: color6_$info_ptr_t;             { 0x30 }
    config: univ_ptr;                     { 0x34 }
    unused_38: integer32;                 { 0x38 }
    unused_3c: integer32;                 { 0x3C }
  end;
  color6_$dcte_ptr_t = ^color6_$dcte_t;

  { An address space's mapping of the register pages (COLOR6_$ASID_MAP's
    elements): the special segment's address and the units that use it. }
  color6_$asid_map_t = record
    va: univ_ptr;                         { 0x00 }
    count: integer;                       { 0x04 }
    unused_06: integer;                   { 0x06 }
  end;

  { What COLOR6_$DEVICE_INFO returns: the unit's page and whether a
    second unit was found on the board. }
  color6_$dev_info_t = record
    page: pinteger;                       { 0x00 }
    shared: boolean;                      { 0x02 }
  end;

  { A cursor's pattern, 0x28 bytes (SMD's smd_cursor_pattern_t). }
  color6_$cursor_pattern_t = record
    width: integer;                       { 0x00 }
    height: integer;                      { 0x02 }
    hot_x: integer;                       { 0x04 }
    hot_y_adj: integer;                   { 0x06 }
    bitmap: array[1..16] of pinteger;     { 0x08 }
  end;

  { A cursor's bitmap as COLOR6_$SET_CRS_PAT is given it, words indexed
    from 1. }
  color6_$bitmap_t = array[1..32] of pinteger;
  color6_$bitmap_ptr_t = ^color6_$bitmap_t;

  { The display's request state as COLOR6_$LOCK_DISPLAY and
    COLOR6_$BLINK_CURSOR see it (SMD's display record,
    smd_display_hw_t; color4/color4.ins.pas color4_$hw_t). }
  color6_$hw_t = record
    unused_00: integer;                   { 0x00 }
    lock_state: integer;                  { 0x02 }
    unused_04: array[2..24] of integer;   { 0x04 }
    cursor_pos: smd_$pos_t;               { 0x32 }
    cursor_number: pinteger;              { 0x36 }
    unused_38: array[28..38] of integer;  { 0x38 }
    disp_limits: smd_$window_limits_t;    { 0x4E }
  end;

  { The blink state COLOR6_$BLINK_CURSOR is given (SMD_TIME_$COM's
    layout): the boolean at 0x2, whether the cursor is painted. }
  color6_$blink_t = record
    unused_00: integer;                   { 0x00 }
    cursor_painted: boolean;              { 0x02 }
  end;

  { The characters COLOR6_$PUTC writes, indexed from 1. }
  color6_$chars_t = array[1..256] of char;

  { A line of the display memory as COLOR6_$DISPLAY_LOGO walks it, words
    indexed from 1 at a byte address it steps by the line's length. }
  color6_$row_t = array[1..1024] of pinteger;
  color6_$row_ptr_t = ^color6_$row_t;

var
  { SMD_$CURSOR_TABLE (map symbol, SMD_WIRED's hand-written data): the
    four cursor patterns, indexed by the cursor number. }
  smd_$cursor_table: extern array[0..3] of color6_$cursor_pattern_t;

{ ---- COLOR6's routines (color6/color6.pas) ---- }

{ COLOR6_$IOINIT - find and set up the COLOR6 board's unit at boot.  The
  descriptor's init routine (io/io.ins.pas's dcte_init_proc_t): the
  descriptor by address, the status in D0. }
function color6_$ioinit(var dcte: color6_$dcte_t): integer32; extern;

{ COLOR6_$INSTALL_DISP - make the display memory a canned object. }
procedure color6_$install_disp(dcte: color6_$dcte_ptr_t;
                               out status: status_$t);
  options(extern, val_param);

{ COLOR6_$CLEAR_SCREEN - clear the screen: nothing to do. }
procedure color6_$clear_screen(dcte: color6_$dcte_ptr_t);
  options(extern, val_param);

{ COLOR6_$VIDEO_CTL - turn the video on or off. }
procedure color6_$video_ctl(dcte: color6_$dcte_ptr_t; on: boolean);
  options(extern, val_param);

{ COLOR6_$REL_DISP - release the display after a request: nothing to
  do. }
procedure color6_$rel_disp(dcte: color6_$dcte_ptr_t; var hw: color6_$hw_t);
  options(extern, val_param);

{ COLOR6_$MAP_DISP - map the display memory into the current address
  space. }
procedure color6_$map_disp(dcte: color6_$dcte_ptr_t;
                           arg_2: integer32; arg_3: integer32;
                           out va: univ_ptr; out status: status_$t);
  options(extern, val_param);

{ COLOR6_$UNMAP_DISP - unmap the display memory. }
procedure color6_$unmap_disp(dcte: color6_$dcte_ptr_t;
                             arg_2: integer32; arg_3: integer32;
                             va: integer32; out status: status_$t);
  options(extern, val_param);

{ COLOR6_$SET_CRS_PAT - load a cursor's pattern into the board. }
procedure color6_$set_crs_pat(dcte: color6_$dcte_ptr_t; cnum: integer;
                              size: integer; hot_x: integer;
                              hot_y: integer;
                              bitmap: color6_$bitmap_ptr_t);
  options(extern, val_param);

{ COLOR6_$ASSOC - map the board's registers into the current process. }
procedure color6_$assoc(dcte: color6_$dcte_ptr_t; out va: univ_ptr;
                        out status: status_$t);
  options(extern, val_param);

{ COLOR6_$DISSOC - dissociate the board from the current process. }
procedure color6_$dissoc(dcte: color6_$dcte_ptr_t; out status: status_$t);
  options(extern, val_param);

{ COLOR6_$DEVICE_INFO - return the unit's page and the board's sharing. }
procedure color6_$device_info(dcte: color6_$dcte_ptr_t; arg_1: integer32;
                              out info: color6_$dev_info_t;
                              out length: integer32;
                              out status: status_$t);
  options(extern, val_param);

{ COLOR6_$DISPLAY_LOGO - copy the boot logo into display memory. }
procedure color6_$display_logo(dcte: color6_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(extern, val_param);

{ COLOR6_$START_WIRED_PROC - mark the start of the driver's wired code. }
procedure color6_$start_wired_proc; extern;

{ COLOR6_$BUSY_WAIT - wait until the board has taken its commands. }
procedure color6_$busy_wait(dcte: color6_$dcte_ptr_t;
                            out status: status_$t);
  options(extern, val_param);

{ COLOR6_$XOR_CURSOR - draw or remove the cursor. }
function color6_$xor_cursor(dcte: color6_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            remove: boolean; wait: boolean): boolean;
  options(extern, val_param);

{ COLOR6_$BLINK_CURSOR - blink the cursor once. }
procedure color6_$blink_cursor(dcte: color6_$dcte_ptr_t;
                               var blink: color6_$blink_t;
                               var hw: color6_$hw_t);
  options(extern, val_param);

{ COLOR6_$PUTC - write characters to the display TTY. }
procedure color6_$putc(dcte: color6_$dcte_ptr_t; in chars: color6_$chars_t;
                       count: integer);
  options(extern, val_param);

{ COLOR6_$LOCK_DISPLAY - claim the display for a request. }
function color6_$lock_display(dcte: color6_$dcte_ptr_t;
                              var hw: color6_$hw_t;
                              kind: integer): boolean;
  options(extern, val_param);

{ COLOR6_$END_WIRED_PROC - mark the end of the driver's wired code. }
procedure color6_$end_wired_proc; extern;
%endif
