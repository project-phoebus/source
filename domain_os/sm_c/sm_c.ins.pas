{ sm_c/sm_c.ins.pas - SM_C (the second storage module controller's
  driver) constants, types, variables and routine headings, for the
  Domain Pascal tree.

  The SM_C module (sm_c/sm_c.pas) drives the storage module disks
  through the PBU's SM_C controller, on the SAUs whose kernel has the
  storage module drivers (the part smd_disk, base/config.ins.pas).  It
  uses the PBU page's command block SM_$CB in its own layout (the
  second variant of sm/sm.ins.pas's sm_$cb_t) and the PBU headings
  declared there.

  No customer insert file declares any of it; the layouts are the
  image's.  Include sm/sm.ins.pas and its prerequisites before it.
}

const
  { The controller's commands (c_cmd, +0x00), as the routines issue
    them: 16#51 write, 16#52 read, 16#53 format, 16#56, 16#59 and 16#5B
    the drive start's. }
  sm_c_cmd_write = 16#51;
  sm_c_cmd_read = 16#52;
  sm_c_cmd_format = 16#53;
  sm_c_cmd_restore = 16#56;
  sm_c_cmd_read_id = 16#59;
  sm_c_cmd_start = 16#5B;

  { The values written to the controller's command register (+0x44 of
    its register page): 16#80 go, 16#90 continue a chain, 16#50
    acknowledge, 16#10 clear. }
  sm_c_reg_go = 16#80;
  sm_c_reg_continue = 16#90;
  sm_c_reg_ack = 16#50;
  sm_c_reg_clear = 16#10;

  { The status codes sm_c_$check_status and SM_C_$DO_IO name (the
    controller's; what the others mean is not known). }
  sm_c_code_ecc = 30;                     { a correctable data error }
  sm_c_code_corrected = 19;               { corrected by the controller }

type
  { The controller's register page at PBU_SM_C_PAGE: the buffer's
    address bytes at +0x40..+0x43, the command register at +0x44, the
    probe byte at +0x45.  `[device]'. }
  sm_c_$page_t = [device] record
    unused_00: array[1..32] of integer;   { 0x00 }
    addr0: sm_$byte_t;                    { 0x40 }
    addr1: sm_$byte_t;                    { 0x41 }
    addr2: sm_$byte_t;                    { 0x42 }
    addr3: sm_$byte_t;                    { 0x43 }
    cmd: sm_$byte_t;                      { 0x44 }
    probe: sm_$byte_t;                    { 0x45 }
  end;

  { A word of the module's block read back as its low byte (+0x8A,
    +0x8C, +0x8E). }
  sm_c_$word_t = packed record
    case integer of
      1: (all: pinteger);
      2: (hi: sm_$byte_t;                 { bits 15..8 }
          lo: sm_$byte_t);                { bits 7..0 }
  end;

  { A physical address in bytes, for the controller's address bytes
    (b0 the most significant). }
  sm_c_$pa_t = record
    case integer of
      1: (all: integer32);
      2: (b0: sm_$byte_t;                 { 0x00 }
          b1: sm_$byte_t;                 { 0x01 }
          b2: sm_$byte_t;                 { 0x02 }
          b3: sm_$byte_t);                { 0x03 }
  end;

  { SM_FIX_ECC's ECC words (two words, from the command block's four
    ECC bytes). }
  sm_c_$ecc_words_t = record
    w0: pinteger;                         { 0x00 }
    w1: pinteger;                         { 0x02 }
  end;

var
  { PBU_SM_C_PAGE (map symbol of the I/O definitions, no `$'). }
  pbu_sm_c_page: extern sm_c_$page_t;

  { SM_ECC_BUF (map symbol of DISK_BUFFERS, no `$'): the page the ECC
    correction maps the request's page at; only its address is used. }
  sm_ecc_buf: extern char;

  { The markers of the module's wired range (map symbols):
    SM_C_$PROC_START (the module's first byte) and SM_C_$PROC_END
    (sm_c/m68k/end_addr.s); only their addresses are used. }
  sm_c_$proc_start: extern char;
  sm_c_$proc_end: extern char;

{ ---- The module's global routines (sm_c/sm_c.pas), in map order ---- }

{ SM_C_$INT: the interrupt routine PBU_$ACQUIRE_INT is given (SM_$INT's
  form); its result 1 or 3. }
function sm_c_$int: integer; extern;

{ SM_C_$CINIT: IO_$INIT calls it through the DCTE's csrsytr (WIN_$CINIT's
  and SM_$CINIT's heading). }
function sm_c_$cinit(var dcte: dcte_t): integer32; extern;

{ SM_C_$DINIT: the jump table's dinit (SM_$DINIT's heading). }
function sm_c_$dinit(unit: pinteger; ctlr: pinteger;
                     var num_blocks: integer32;
                     var sec_per_track: pinteger; var num_heads: pinteger;
                     out pvlabel_info: univ disk_$pvlabel_info_t;
                     out flags: pinteger): integer32;
  options(extern, val_param);

{ SM_C_$GET_STATS: the jump table's get_stats. }
procedure sm_c_$get_stats(cnum: integer; unit: pinteger;
                          out stats: univ disk_$stats_t);
  options(extern, val_param);

{ SM_C_$DO_IO: the jump table's do_io. }
procedure sm_c_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
  extern;

{ SM_C_$REVALIDATE: the jump table's revalidate, an empty procedure. }
procedure sm_c_$revalidate(in vol: disk_$volume_t); extern;

{ SM_C_$SPIN_DOWN: the jump table's spin_down. }
function sm_c_$spin_down(in ctlr: pinteger): integer; extern;

{ SM_FIX_ECC (hand-written, the map's SM_X_ASM segment; sm_c/sau5/
  sm_x_asm.s): reads its three arguments off the stack, addresses: the
  request's block header, the data page, the ECC words; it flips the
  bits the ECC words name in the header (offsets below 32) or the data
  (below 1056).  Its one caller, sm_c_$fix_ecc, pushes three
  addresses. }
procedure sm_fix_ecc(var header: disk_$info_t; var data: univ char;
                     in ecc: sm_c_$ecc_words_t);
  extern;
