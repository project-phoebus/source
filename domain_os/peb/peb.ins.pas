{ peb/peb.ins.pas - PEB_ (the floating-point board), for the Domain
  Pascal tree.

  Holds only what the Pascal files use.  No customer insert file
  declares these.  Include base/base.ins.pas and ec/ec.ins.pas before it
  (and fim/fim.ins.pas where status_$peb_interrupt is used).
}

const
  { The PEB manager's statuses, subsystem 16#24 (stcode.db.10.2 "OS / PEB
    manager": "fpu is hung", "PEB interrupt", "floating point overflow",
    "floating point underflow", "divide by zero", "floating point loss
    of significance", "floating point hardware error", "attempted use of
    unimplemented opcode", "wcs verify failed").
    status_$peb_interrupt, 16#00240002, is declared in fim/fim.ins.pas
    (for FIM_$BUILD_DF, which tests it), so the PEB modules include that
    file before this one. }
  status_$peb_fpu_is_hung              = 16#00240001;
  status_$peb_fp_overflow              = 16#00240003;
  status_$peb_fp_underflow             = 16#00240004;
  status_$peb_div_by_zero              = 16#00240005;
  status_$peb_fp_loss_of_significance  = 16#00240006;
  status_$peb_fp_hw_error              = 16#00240007;
  status_$peb_unimplemented_opcode     = 16#00240008;
  status_$peb_wcs_verify_failed        = 16#00240009;

  { The status PEB_$TOUCH and peb_$cleanup_internal give CRASH_SYSTEM
    when the board stays busy: "fpu is hung" with the fail bit, a
    constant cell after PEB_$TOUCH. }
  peb_fpu_is_hung_err                  = 16#80240001;

  { The members of PEB_$GET_INFO's word set (byte masks of the word's
    high byte, so member 8 + bit).  The last two are not understood. }
  peb_$info_wcs_loaded                 = 15;  { mask 0x80 }
  peb_$info_m68881_mode                = 14;  { mask 0x40 }
  peb_$info_savep_flag                 = 13;  { mask 0x20 }
  peb_$info_unknown_10                 = 12;  { mask 0x10 }
  peb_$info_unknown_08                 = 11;  { mask 0x08 }

type
  { The board's control word (PEB_CTL and its shadow
    PEB_$INFO.ctl_shadow): bit 15 busy, tested by its sign; bit 1 the
    WCS parity error; bits 4..9 the WCS page, merged as a packed field
    (peb_$write_wcs); bits 0, 2, 3 the enable, or-ed in as 16#D
    (PEB_$LOAD_WCS).  A packed record (ref 3.10.7: the first field the
    most significant bits) with the whole word as a second variant. }
  peb_$ctl_bits_t = packed record
    case integer of
      1: (unused_10: 0..63;               { bits 15..10 }
          wcs_page: 0..63;                { bits 9..4 }
          unused_00: 0..15);              { bits 3..0 }
      2: (all: integer);                  { the word }
  end;

  { A WCS entry, 8 bytes: peb_$write_wcs stores
    word0, word1, word2 at the entry's +0x800, +0x802, +0x804 off
    PEB_CTL. }
  peb_$wcs_entry_t = record
    word0: integer;                       { 0x00 }
    word1: integer;                       { 0x02 }
    word2: integer32;                     { 0x04 }
  end;

  { The microcode file's image as MST_$MAP maps it: the first WCS address,
    the entry count, then the entries, reached from +4 with a pointer
    stepped by 8 (PEB_$LOAD_WCS).  The bound fills the 64 KB mapped
    (16#10000, the length PEB_$LOAD_WCS passes). }
  peb_$wcs_header_t = record
    start_addr: integer;                  { 0x00 }
    entry_count: integer;                 { 0x02 }
    entries: array[0..8190] of peb_$wcs_entry_t;   { 0x04 }
  end;
  peb_$wcs_header_ptr_t = ^peb_$wcs_header_t;

  { The board's first and third pages from PEB_CTL: the control word,
    the byte at 0x3FC PEB_$LOAD_WCS reads, and the WCS window at 0x800
    (= PEB_$M_CS_PAGE), 128 entries, which peb_$write_wcs and
    peb_$read_wcs index from PEB_CTL's address.  The second page
    (0x400..0x7FF, PEB_$M_DCMD_PAGE) is not reached through this record.
    `[volatile]': the busy word is polled in loops; not `[device]':
    PEB_$INIT clears the word with a clear instruction, a store a
    `[device]' object never takes.
    The 0x403 bytes between reg_3fc and the WCS window are one char at
    0x3FD and an array from 0x3FE: a char array of 2 or more is word
    aligned in an unpacked record (the layout rules; ref 3.10.5.5), so one
    array at 0x3FD would be laid out at 0x3FE and move wcs to 0x802 (the
    record 0xC02 bytes).  Probed with dpc (an `addr' of every field through
    a pointer): ctl 0, reg_3fc 0x3FC, unused_3fd 0x3FD,
    unused_3fe 0x3FE, wcs 0x800, the record 0xC00 bytes. }
  peb_$ctl_t = [volatile] record
    ctl: peb_$ctl_bits_t;                 { 0x000 }
    unused_002: array[1..1018] of char; { 0x002 }
    reg_3fc: char;                        { 0x3FC }
    unused_3fd: char;                     { 0x3FD }
    unused_3fe: array[1..1026] of char; { 0x3FE }
    wcs: array[0..127] of peb_$wcs_entry_t;   { 0x800 }
  end;

  { An 8-byte floating-point register (two longwords, copied as a
    record, PEB_$LOAD_REGS). }
  peb_$dreg_t = record
    hi: integer32;                        { 0x00 }
    lo: integer32;                        { 0x04 }
  end;

  { The board's register page as a process sees it: the private mapping
    at 16#7000 (PEB_$TOUCH's MMU_$INSTALL_PRIVATE; PEB_$LOAD_REGS,
    _$UNLOAD_REGS, _$GET_STATUS use the address as a constant, no
    relocation) or the command page PEB_$M_DCMD_PAGE (PEB_$GET_STATUS).
    The offsets are the routines'; the eight-byte pairs are one field
    each. }
  peb_$regs_t = record
    unused_000: array[1..132] of char;  { 0x000 }
    ctrl_in: integer32;                   { 0x084 }
    unused_088: integer32;                { 0x088 }
    data_in: peb_$dreg_t;                 { 0x08C }
    data_out: peb_$dreg_t;                { 0x094 }
    unused_09c: array[1..88] of char;  { 0x09C }
    status: integer32;                    { 0x0F4 }
    unused_0f8: array[1..12] of char;     { 0x0F8 }
    ctrl_out: integer32;                  { 0x104 }
    unused_108: array[1..168] of char;  { 0x108 }
    stat_out: peb_$dreg_t;                { 0x1B0 }
    unused_1b8: array[1..24] of char;  { 0x1B8 }
    stat_in: peb_$dreg_t;                 { 0x1D0 }
    unused_1d8: integer32;                { 0x1D8 }
    misc: integer32;                      { 0x1DC }
    unused_1e0: array[1..544] of char; { 0x1E0 }
  end;
  peb_$regs_ptr_t = ^peb_$regs_t;

  { A process's saved board state, 0x1C bytes (the four data longwords
    as two registers): copied field by field by
    PEB_$LOAD_REGS, _$UNLOAD_REGS and PEB_$TOUCH, cleared as seven
    longwords by PEB_$INIT and peb_$cleanup_internal, a longword index
    from 4 by 4: the second variant, from 1. }
  peb_$fp_state_t = record
    case integer of
      1: (data1: peb_$dreg_t;             { 0x00 }
          data2: peb_$dreg_t;             { 0x08 }
          status_reg: integer32;          { 0x10 }
          ctrl_reg: integer32;            { 0x14 }
          instr_counter: integer32);      { 0x18 }
      2: (longs: array[1..7] of integer32);
  end;

  { PEB_$INFO, the PEB_PARITY data block (0x24 bytes, WIRED_DATA; zero
    in the image), one record: SMD reaches its byte +0x1A off the
    symbol, and the PEB routines its fields off A5 or the symbol.  The flags
    are booleans, 16#FF true.  0x22 bytes, the block rounded to 4 (as
    MAC_OS's, mac_os/mac_os.pas). }
  peb_$info_t = record
    unused_00: array[1..8] of char;       { 0x00: nothing addresses it }
    eventcount: ec_$eventcount_t;         { 0x08: EC_$INIT's }
    owner_pid: pinteger;                  { 0x14: PROC1_$CURRENT }
    owner_asid: integer;                  { 0x16: PROC1_$AS_ID }
    ctl_shadow: peb_$ctl_bits_t;          { 0x18 }
    installed: boolean;                   { 0x1A }
    wcs_loaded: boolean;                  { 0x1B }
    savep_flag: boolean;                  { 0x1C }
    flag_1d: boolean;                     { 0x1D: with `fpa_board' the
                                            accelerator answered }
    info_byte: char;                      { 0x1E: copied as a byte }
    mmu_installed: boolean;               { 0x1F }
    m68881_save_flag: boolean;            { 0x20 }
    flag_21: boolean;                     { 0x21 }
  end;

  { PEB_$GET_INFO's flag word, a word set (member k
    of a word set is bit k mod 8 of byte 1 - k div 8): cleared, then
    each member's bit set on its byte.  ASKNODE_$INTERNET_INFO stores
    the whole word. }
  peb_$info_bits_t = set of 0..15;

var
  { PEB_$INFO (map symbol, PEB_PARITY's WIRED_DATA block, above).
    Defined in peb/peb_parity.pas. }
  peb_$info: extern peb_$info_t;

  { M68881_EXISTS (map symbol without `$', a global; the
    whole PEB_UNWIRED data segment, .DATA): tested as a boolean
    (PEB_$INIT; FIM_$FSAVE's hand-written code reads its word,
    fim/m68k/fsave.s); zero in the image, nothing in the kernel writes
    it.  A boolean, the block rounded to 4.  Defined in
    peb/peb_unwired.pas. }
  m68881_exists: extern boolean;
%if peb_fpx or fpx_eco_check or fpa_board %then

  { FPX_EXISTS (map symbol without `$', a global; PEB_UNWIRED's .DATA
    block, its first byte, before M68881_EXISTS): set when the FPX
    floating-point accelerator is present; PEB_$INIT and OS_$INIT test
    it as a boolean (with `fpa_board' PEB_$INIT then probes the
    accelerator).  Zero in the image; nothing in the kernel writes it.
    Defined in peb/peb_unwired.pas. }
  fpx_exists: extern boolean;
%endif

  { PEB_$REGS (map symbol; the whole PEB_WIRED data segment, 0x658
    bytes, .DATA, which the map also labels PEB_$WIRED_DATA_START): the
    saved board state per address space, 58 of 0x1C bytes, from 0
    (PEB_$TOUCH indexes it by asid * 0x1C; PEB_$INIT clears 58 of them).
    Defined in peb/peb_wired.pas. }
  peb_$regs: extern array[0..57] of peb_$fp_state_t;

  { The module's markers (map symbols): PEB_$WIRED_PROC_START (PEB_$TOUCH's
    address, which the map gives both names) and PEB_$WIRED_PROC_END
    (inside the 4 zero bytes of the PEB_WIRED_END segment, no code),
    PEB_$WIRED_DATA_START (PEB_$REGS's) and PEB_$WIRED_DATA_END (one
    past the block, AUDIT_$DATA_START).  PEB_$LOAD_WCS passes their
    addresses to MST_$WIRE_AREA as cells.  Labels the build places, no
    objects of the modules, as NETLOG's (netlog/netlog.ins.pas): extern
    chars, of which only the address is used. }
  peb_$wired_proc_start: extern char;
  peb_$wired_proc_end: extern char;
  peb_$wired_data_start: extern char;
  peb_$wired_data_end: extern char;

  { PEB_CTL (map symbol of the I/O definitions, with PEB_$M_CTRL_PAGE,
    FPU_CTL and PEB at the same address): the board's control page,
    reached by its absolute address (another unit's object). }
  peb_ctl: extern peb_$ctl_t;

  { The board's three pages as MMU_$INSTALL maps them (map symbols,
    IODEFS): PEB_$M_CTRL_PAGE (PPN 16#2C), PEB_$M_DCMD_PAGE (16#2D),
    PEB_$M_CS_PAGE (16#2E), each pushed as its relocated address
    (PEB_$ASSOC).  The command page is also read as a register page
    (PEB_$GET_STATUS); the other two only by address (extern chars). }
  peb_$m_ctrl_page: extern char;
  peb_$m_dcmd_page: extern peb_$regs_t;
  peb_$m_cs_page: extern char;

  { The exception vectors PEB_$INIT and PEB_$LOAD_WCS's nested check
    store (the map's TRAP_PAGE data segment at 0, 0x400 bytes; no insert
    file of the tree declares the trap page, so it is declared here,
    where it is used, as sio6509/sio6509.ins.pas declares KEYBD_VEC):
    - PEB_VEC 0x70 (map symbol, with DISP1_VEC), stored by its relocated
      address;
    - TRAP_PAGE 0x0 (map symbol): the line-F vector 0x2C, which has no
      map symbol of its own, stored at a relocated address, so a
      symbol's address plus 0x2C: element 11 of the trap page's 256
      vectors. }
  peb_vec: extern univ_ptr;
  trap_page: extern array[0..255] of univ_ptr;

{ Routine headings, in map order.  The bodies repeat the full heading
  (ref 7.3.4, Method 2). }

{ PEB_$TEST_PARITY_ERR - report whether the board has a WCS parity error. }
procedure peb_$test_parity_err(out status: status_$t); extern;

{ PEB_$INT (hand assembly in the PEB_ASM data segment, 0x88 bytes,
  peb/m68k/int.s): the interrupt routine PEB_$INIT installs at PEB_VEC,
  only its address used. }
procedure peb_$int; extern;

{ PEB_$INIT - set the floating-point hardware up at boot. }
procedure peb_$init; extern;

{ PEB_$LOAD_WCS - set up the floating-point save area or load the board's
  microcode. }
procedure peb_$load_wcs; extern;

{ PEB_$ASSOC - make the current process the board's owner.
  PEB_$DISSOC - give the board's command page up. }
procedure peb_$assoc; extern;
procedure peb_$dissoc; extern;

{ PEB_$GET_STATUS - the status of the board's last exception. }
function peb_$get_status: integer32; extern;

{ PEB_$LOAD_REGS - load the board's registers from a saved state.
  PEB_$UNLOAD_REGS - save the board's registers. }
procedure peb_$load_regs(in state: peb_$fp_state_t); extern;
procedure peb_$unload_regs(out state: peb_$fp_state_t); extern;

{ PEB_$GET_FP - load the board with an address space's saved state.
  PEB_$PUT_FP - save the board's state for an address space. }
procedure peb_$get_fp(in asid: integer); extern;
procedure peb_$put_fp(in asid: integer); extern;

{ PEB_$TOUCH - give the board to the process that touched its page. }
function peb_$touch(in va: linteger): boolean; extern;

{ PEB_$GET_INFO - report the board's state flags. }
procedure peb_$get_info(out info: peb_$info_bits_t; out info_byte: char);
  extern;

{ PEB_$PROC_CLEANUP - the board's part of a process's end. }
procedure peb_$proc_cleanup; extern;
