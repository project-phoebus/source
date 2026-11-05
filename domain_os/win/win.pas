{ win/win.pas - the WIN_ module, the Winchester disk driver (on the SAU2
  the DN3xx's ANSI-command controller, on DMA channel 3).

  Image addresses:
    sau2  0x00E2B89C  WIN_ data (WIRED_DATA, 0x78 bytes)
    sau5  0x00E2C9D8  WIN_ data (WIRED_DATA, 0x78 bytes)
    sau6  0x7802ED98  WIN_ data (WIRED_DATA, 0xD54 bytes)
    sau7  0x3C4313BC  WIN_ data (WIRED_DATA, 0xECC bytes)
    sau8  0x03C2D830  WIN_ data (WIRED_DATA, 0x380 bytes)

  One compilation unit, `module win_, wired_proc, wired_data;': the
  map's WIN_ code segments in WIRED_PROC (the module-local routines,
  SEEK, WIN_$DO_IO .. WIN_$GET_STATS) and OS_INIT_PROC (WIN_$CINIT,
  headed `[section(os_init_proc, os_init_data)]'), and its data segment
  in WIRED_DATA (120 bytes).

  WIN_DCTE, the controller's DCTE, lies in the DCTES segment
  (io/dctes.pas); WIN_ECC_BUF is DISK_BUFFERS', WIN_VEC the disk vector.

  The data, declared below with each object's offset: the unit record,
  the jump table DISK_$REGISTER is given, the unit's eventcount,
  WIN_$CNT, the current request and status, and the driver's map
  symbols; three longwords nothing addresses are stand-ins (TODO below).

  The SAU5's WIN_ (`win_descriptor_ctlr', base/config.ins.pas) drives a
  controller that takes a list of transfer descriptors in its window:
  the same name, sections, jump table and block size, its own block
  layout after +0x58, and four routines of its own (ecc_correct.pas,
  command.pas, restore.pas, retry_data_check.pas).

  The SAU6's WIN_ (`win_descriptor_ctlr' with `win6_ct6_board' and
  `win_vectored_ctlr') holds the WIN6_ driver of the second board's
  controller beside the descriptor-list one: the WIN6_ globals and
  their module-local routines after WIN_$INT in WIRED_PROC (to
  WIN6_$ERROR_QUE, before WIN_$ERROR_QUE), WIN6_$CINIT after WIN_$CINIT
  in OS_INIT_PROC; its block (0xD54 bytes) has the WIN6_ variables
  first and between the descriptor-list driver's; WIN6_DCTE is its
  DCTE.

  The SAU8's WIN_ (`win_atbus_ctlr') is the WIN8_ driver of a
  controller on the AT bus: WIN_$SPIN_DOWN and WIN_$CINIT by their
  names, the five WIN8_ globals, five module-local routines of its own
  (wait_phase.pas, send_command.pas, check_status.pas,
  read_mfg_badspots.pas and its arm of format_track.pas), WIN_ASM's
  hand assembly (win/m68k/win_asm.s), and a block of its own (0x380
  bytes); WIN8_DCTE is its DCTE.

  The SAU7's WIN_ (`win_mailbox_ctlr' with `win_atbus_ctlr') holds the
  WIN7_ driver of up to two mailbox controllers beside the WIN8_ one:
  WIN7_$DINIT .. WIN7_$INT before WIN_$SPIN_DOWN in WIRED_PROC, with
  WIN_SETUP_IOPB, WIN_SETUP_MAILBOX and WIN_SEND_COMMAND and the
  module-local win7_$move_iopb (move_iopb.pas), and WIN7_$CINIT before
  WIN_$CINIT in OS_INIT_PROC; its block (0xECC bytes) has the WIN7_
  variables first and between the WIN8_ ones; WIN7_DCTE_0 and
  WIN7_DCTE_1 are its DCTEs.

  The routines live in one fragment file each (win/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/win/win.pas.  Check: tools/pascal_check.sh.

  With the part winchester_ctlr (base/config.ins.pas): the SAU9's map
  has no WIN_ module, and the module is empty there.
}
module win_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%if winchester_ctlr %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'dma/dma.ins.pas';
%include 'parity/parity.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'io/io.ins.pas';
%include 'disk/disk.ins.pas';
%if win_mailbox_ctlr or win6_ct6_board %then
%include 'proc1/proc1.ins.pas';
%endif
%if win_mailbox_ctlr %then
%include 'wp/wp.ins.pas';
%include 'iomap/iomap.ins.pas';
%endif
%if win_ring_disk_ctlr or win_vectored_ctlr %then
%include 'sysbus/sysbus.ins.pas';
%endif
%if win_ring_disk_ctlr or win_mailbox_ctlr %then
%include 'pbu/pbu.ins.pas';
%endif
%if win_ring_disk_ctlr %then
%include 'ring/ring.ins.pas';
%endif
%include 'win/win.ins.pas';

{ TODO(pascal) the block's three open longwords

  +0x0C, +0x2C and +0x3C are addressed by no routine and are what 8-byte
  alignment of the 8-byte-or-larger objects from the block's start would
  leave (the rule fits this block at all three places, the ring/disk
  form's block at +0x14, +0x34 and +0x44, and the mailbox form's at
  +0x04C, +0x05C, +0xDF4 and +0xE14).
  The Pascal declares stand-ins (unused_0c, unused_2c, unused_3c) so
  that dpc, which aligns data to at most 4, lays the block out as the
  image does.  If the alignment rule is confirmed, the stand-ins go. }

%if win_descriptor_ctlr %then
%if win6_ct6_board %then
{ With the second board's driver (`win6_ct6_board'; the SAU6's WIN_
  data segment, 0xD54 bytes): the WIN6_ logs, counts, drive records and
  start queue, then the descriptor-list driver's block with the WIN6_
  jump table after the unit record, the WIN6_ list and page after
  WIN_$CNT, WIN_$DT two longwords, and the WIN6_ words before
  win_config and booleans after win_stat. }
define
  win6_$int_ers;                                 { +0x000, zero }
  win6_$epbs;                                    { +0x050, zero }
  win6_$errors;                                  { +0x850, zero }

var
  win6_drives: array[0..1] of win6_$drive_t;     { +0x968, zero }

define
  rq;                                            { +0xB98, zero }

var
  win_units: array[0..0] of win_$unit_t;         { +0xC98, zero }
  unused_ca4: integer32;                         { +0xCA4, zero }
  win6_jump_table: array[0..6] of univ_ptr :=    { +0xCA8 }
    [addr(win_$spin_down), nil, addr(win6_$dinit), nil, addr(win6_$do_io),
     addr(win6_$error_que), addr(win_$get_stats)];
  unused_cc4: integer32;                         { +0xCC4, zero }
  win_jump_table: array[0..6] of univ_ptr :=     { +0xCC8 }
    [addr(win_$spin_down), nil, addr(win_$dinit), nil, addr(win_$do_io),
     addr(win_$error_que), addr(win_$get_stats)];
  unused_ce4: integer32;                         { +0xCE4, zero }
  win_unit_ec: array[0..0] of ec_$eventcount_t;  { +0xCE8, zero }
  unused_cf4: integer32;                         { +0xCF4, zero }

define
  win_$cnt;                                      { +0xCF8, zero }
  win6_$fixes;                                   { +0xD10, zero }

var
  win6_free_count: integer;                      { +0xD14, zero }
  win6_free_head: integer;                       { +0xD16, zero }
  win6_free_tail: integer;                       { +0xD18, zero }
  win6_page: win6_$page_ptr_t;                   { +0xD1C, zero }

define
  win_$fixes;                                    { +0xD20, zero }
  win_$restores;                                 { +0xD24, zero }

var
  win_cur_req: disk_$io_req_ptr_t;               { +0xD28, zero }
  win_total_blocks: integer32 := 1;              { +0xD2C: 1 }

define
  win_$dt;                                       { +0xD30, zero }
  win6_$int_erx;                                 { +0xD38, zero }
  win6_$epbx;                                    { +0xD3A, zero }
  win6_$retries := 10;                           { +0xD3C: 10 }

var
  win6_init_mode: integer;                       { +0xD3E, zero }

define
  rqnd;                                          { +0xD40, zero }
  rqst;                                          { +0xD42, zero }
  rqcnt;                                         { +0xD44, zero }

var
  win_config: pinteger;                          { +0xD46, zero }

define
  win_$timeout_st;                               { +0xD48, zero }

var
  win_err: integer;                              { +0xD4A, zero }
  win_stat: pinteger;                            { +0xD4C, zero }

define
  win6_$fix_eccc := true;                        { +0xD4E: true }
  ctl_bsy;                                       { +0xD50, zero }

define
  restore;
  seek;
  retry_data_check;
  win_$do_io;
  win_$dinit;
  win_$spin_down;
  win_$int;
  win6_$get_iopbs;
  win6_$rtn_iopbs;
  win6_$get_error_info;
  win6_$int;
  log_int_error;
  win6_$async_int;
  win6_$ctlr_int;
  win6_$dinit;
  win6_$do_io;
  win6_$error_que;
  win_$error_que;
  win_$get_stats;
  win_$cinit;
  win6_$cinit;
%else
{ The descriptor-list controller's block (`win_descriptor_ctlr'; the
  SAU5's WIN_ data segment, 0x78 bytes): the same first 0x58 bytes as
  the SAU2's, then the driver's own variables. }
var
  win_units: array[0..0] of win_$unit_t;         { +0x00, zero }
  unused_0c: integer32;                          { +0x0C, zero }
  win_jump_table: array[0..6] of univ_ptr :=     { +0x10 }
    [addr(win_$spin_down), nil, addr(win_$dinit), nil, addr(win_$do_io),
     addr(win_$error_que), addr(win_$get_stats)];
  unused_2c: integer32;                          { +0x2C, zero }
  win_unit_ec: array[0..0] of ec_$eventcount_t;  { +0x30, zero }
  unused_3c: integer32;                          { +0x3C, zero }

define
  win_$cnt;                                      { +0x40, zero }
  win_$fixes;                                    { +0x58, zero }
  win_$restores;                                 { +0x5C, zero }

var
  win_cur_req: disk_$io_req_ptr_t;               { +0x60, zero }
  win_total_blocks: integer32 := 1;              { +0x64: 1 }

define
  win_$dt;                                       { +0x68, zero }

var
  unused_6c: integer32;                          { +0x6C, zero }
  win_config: pinteger;                          { +0x70, zero }

define
  win_$timeout_st;                               { +0x72, zero }

var
  win_err: integer;                              { +0x74, zero }
  win_stat: pinteger;                            { +0x76, zero }

define
  restore;
  seek;
  retry_data_check;
  win_$do_io;
  win_$dinit;
  win_$spin_down;
  win_$int;
  win_$error_que;
  win_$get_stats;
  win_$cinit;
%endif

{ ---- WIRED_PROC ---- }
%include 'win/check_disk_status.pas';       { win_$check_disk_status     }
%include 'win/ecc_correct.pas';             { win_$ecc_correct           }
%include 'win/command.pas';                 { win_$command               }
%include 'win/restore.pas';                 { RESTORE                    }
%include 'win/format_track.pas';            { win_$format_track          }
%include 'win/seek.pas';                    { SEEK                       }
%include 'win/retry_data_check.pas';        { RETRY_DATA_CHECK           }
%include 'win/do_io.pas';                   { WIN_$DO_IO                 }
%include 'win/dinit.pas';                   { WIN_$DINIT                 }
%include 'win/spin_down.pas';               { WIN_$SPIN_DOWN             }
%include 'win/int.pas';                     { WIN_$INT                   }
%if win6_ct6_board %then
%include 'win/win6_get_iopbs.pas';          { WIN6_$GET_IOPBS            }
%include 'win/win6_rtn_iopbs.pas';          { WIN6_$RTN_IOPBS            }
%include 'win/epb_status.pas';              { win6_$epb_status           }
%include 'win/win6_get_error_info.pas';     { WIN6_$GET_ERROR_INFO       }
%include 'win/send_iopb.pas';               { win6_$send_iopb            }
%include 'win/win6_int.pas';                { WIN6_$INT                  }
%include 'win/log_int_error.pas';           { LOG_INT_ERROR              }
%include 'win/win6_async_int.pas';          { WIN6_$ASYNC_INT            }
%include 'win/win6_ctlr_int.pas';           { WIN6_$CTLR_INT             }
%include 'win/win6_dinit.pas';              { WIN6_$DINIT                }
%include 'win/win6_do_io.pas';              { WIN6_$DO_IO                }
%include 'win/win6_error_que.pas';          { WIN6_$ERROR_QUE            }
%endif
%include 'win/error_que.pas';               { WIN_$ERROR_QUE             }
%include 'win/get_stats.pas';               { WIN_$GET_STATS             }

{ ---- OS_INIT_PROC ---- }
%include 'win/cinit.pas';                   { WIN_$CINIT                 }
%if win6_ct6_board %then
%include 'win/win6_cinit.pas';              { WIN6_$CINIT                }
%endif
%elseif win_atbus_ctlr %then
{ TODO(pascal) the AT bus block's 704 bytes at +0x30

  Between the drives' statistics and the controllers' records the block
  has 704 bytes no routine addresses (the SAU7's WIN_ block has the same
  704 bytes between the same two objects, after its WIN7_ driver's
  data).  704 is twice 352; what the object was is not known.  The
  Pascal declares a stand-in, unused_030. }

{ TODO(pascal) the mailbox block's 56 bytes at +0x598

  Between win7_ctlrs and WIN_$CB the SAU7's block has 56 bytes no
  routine addresses, zero but for the word 16#420 at +0x5C4 (+0x2C of
  the object); a byte search finds no address inside them.  What the
  object was is not known.  The Pascal declares a stand-in, unused_598,
  with the image's initial value. }

{ The AT bus controller's block (`win_atbus_ctlr'; the SAU8's WIN_ data
  segment, 0x380 bytes), zero but for the jump table, the longword 1 at
  +0x36C and the unit word at +0x370.  With `win_mailbox_ctlr' (the
  SAU7's WIN_ data segment, 0xECC bytes) the WIN7_ driver's variables
  come first and between the AT bus driver's; the second column of
  offsets is that block's. }
var
%if win_mailbox_ctlr %then
  win7_bufs: array[1..16] of integer32;          {          +0x000, zero:
                                                   the windows' bus
                                                   addresses }
  win7_mbox_ec: ec_$eventcount_t;                {          +0x040, zero }
  unused_04c: integer32;                         {          +0x04C, zero }
  win7_init_ec: ec_$eventcount_t;                {          +0x050, zero }
  unused_05c: integer32;                         {          +0x05C, zero }
  win7_sg: array[0..27] of win7_$sector_slot_t;  {          +0x060, zero }
  win7_iopb_base: array[0..1] of integer32;      {          +0x098, zero:
                                                   the command blocks'
                                                   addresses }
  win7_infos: array[0..1] of array[0..17] of win7_$info_t;
                                                 {          +0x0A0, zero }
  win7_pages: win7_$ppn_list_t;                  {          +0x490, zero }
  win7_ppns: win7_$ppn_list_t;                   {          +0x510, zero }
  win7_ctlrs: array[0..1] of win7_$ctlr_ptr_t := {          +0x590 }
    [addr(win_$cb[0]), addr(win_$cb[1])];
  unused_598: array[0..27] of integer :=         {          +0x598: the
                                                   word 16#420 at +0x2C;
                                                   the TODO above }
    [22 of 0, 16#420, 5 of 0];

define
  win_$cb := [[dma_channel := 7], [dma_channel := 3]];
                                                 {          +0x5D0: the
                                                   DMA channels 7 and 3 }

var
%endif
  win_stats: array[0..1] of win_$stats_slot_t;   { +0x000,  +0xAD0, zero }
  unused_030: array[1..176] of integer32;        { +0x030,  +0xB00, zero:
                                                   the TODO above }
  win_units: array[0..1] of win_$unit_t;         { +0x2F0,  +0xDC0, zero }
%if win_mailbox_ctlr %then
  win7_jump_table: array[0..6] of univ_ptr :=    {          +0xDD8 }
    [addr(win_$spin_down), nil, addr(win7_$dinit), nil, addr(win7_$do_io),
     addr(win7_$error_que), addr(win7_$get_stats)];
  unused_df4: integer32;                         {          +0xDF4, zero }
%endif
  win_jump_table: array[0..6] of univ_ptr :=     { +0x308,  +0xDF8 }
    [addr(win_$spin_down), nil, addr(win8_$dinit), nil, addr(win8_$do_io),
     addr(win8_$error_que), addr(win8_$get_stats)];
  unused_324: integer32;                         { +0x324,  +0xE14, zero }
  win_unit_ec: array[0..1] of ec_$eventcount_t;  { +0x328,  +0xE18, zero }

define
  win_$cnt;                                      { +0x340,  +0xE30, zero }

var
%if win_mailbox_ctlr %then
  win7_map_base_2: integer32;                    {          +0xE48, zero:
                                                   the second mailbox
                                                   area's bus address }
  win7_map_base_1: integer32;                    {          +0xE4C, zero:
                                                   the first's }
  win7_map_total: integer32;                     {          +0xE50, zero }
  win7_map_size: integer32;                      {          +0xE54, zero }
  win7_cur_req: disk_$io_req_ptr_t;              {          +0xE58, zero }
  win7_window_base: integer32;                   {          +0xE5C, zero }
  win7_mbox_pa: integer32;                       {          +0xE60, zero }
  win7_map_left: integer32;                      {          +0xE64, zero }
%endif
  win_page_pmape: univ_ptr;                      { +0x358,  +0xE68, zero }
  win_hdr: univ_ptr;                             { +0x35C,  +0xE6C, zero }
  win_buf: univ_ptr;                             { +0x360,  +0xE70, zero }
  win_cmd: win_$cmd_t;                           { +0x364,  +0xE74, zero }
  win_total_blocks: integer32 := 1;              { +0x36C,  +0xE7C: 1 }
%if win_mailbox_ctlr %then
  win7_iopb_size: integer;                       {          +0xE80, zero }
  win7_mbox_areas: integer;                      {          +0xE82, zero }
  win7_mbox_size: integer;                       {          +0xE84, zero }
  win7_buf_index: integer;                       {          +0xE86, zero }
%endif
  win_unit_bits: integer := 16#2800;             { +0x370,  +0xE88:
                                                   members 13 and 11 }
  win_last_phase: integer;                       { +0x372,  +0xE8A, zero }
  win_last_status: integer;                      { +0x374,  +0xE8C, zero }
  win_sector_size: integer;                      { +0x376,  +0xE8E, zero }
  win_max_count: integer;                        { +0x378,  +0xE90, zero }
  win_count: integer;                            { +0x37A,  +0xE92, zero }
%if win_mailbox_ctlr %then
  win7_params_ok: boolean;                       {          +0xE94, zero }
  win7_first_cinit: boolean := true;             {          +0xE96 }
  win7_first_dinit: boolean := true;             {          +0xE98 }
%endif
  win_params_reported: boolean;                  { +0x37C,  +0xE9A, zero }
%if win_mailbox_ctlr %then
  win7_iopb_wait: time_$clock_t := [high := 0, low := 15];
                                                 {          +0xE9C }
  win7_delay_ea4: time_$clock_t := [high := 0, low := 15];
                                                 {          +0xEA4 }
  win7_cmd_wait: time_$clock_t := [high := 0, low := 65];
                                                 {          +0xEAC }
  win7_ready_wait: time_$clock_t := [high := 0, low := 20];
                                                 {          +0xEB4 }
  win7_delay_ebc: time_$clock_t := [high := 0, low := 50];
                                                 {          +0xEBC }
  win7_window_wait: time_$clock_t := [high := 0, low := 15];
                                                 {          +0xEC4 }
%endif

define
%if win_mailbox_ctlr %then
  win7_$dinit;
  win_setup_iopb;
  win_setup_mailbox;
  win_send_command;
  win7_$get_stats;
  win7_$do_io;
  win7_$error_que;
  win7_$int;
  win7_$cinit;
%endif
  win_$spin_down;
  win8_$do_io;
  win8_$dinit;
  win8_$int;
  win8_$error_que;
  win8_$get_stats;
  win_$cinit;

{ ---- WIRED_PROC ---- }
%if win_mailbox_ctlr %then
%include 'win/move_iopb.pas';               { win7_$move_iopb            }
%include 'win/win7_dinit.pas';              { WIN7_$DINIT                }
%include 'win/win_setup_iopb.pas';          { WIN_SETUP_IOPB             }
%include 'win/win_setup_mailbox.pas';       { WIN_SETUP_MAILBOX          }
%include 'win/win_send_command.pas';        { WIN_SEND_COMMAND           }
%include 'win/win7_get_stats.pas';          { WIN7_$GET_STATS            }
%include 'win/win7_do_io.pas';              { WIN7_$DO_IO                }
%include 'win/win7_error_que.pas';          { WIN7_$ERROR_QUE            }
%include 'win/win7_int.pas';                { WIN7_$INT                  }
%endif
%include 'win/spin_down.pas';               { WIN_$SPIN_DOWN             }
%include 'win/wait_phase.pas';              { win_$wait_phase            }
%include 'win/send_command.pas';            { win_$send_command          }
%include 'win/check_status.pas';            { win_$check_status          }
%include 'win/format_track.pas';            { win_$format_track          }
%include 'win/read_mfg_badspots.pas';       { win_$read_mfg_badspots     }
%include 'win/win8_do_io.pas';              { WIN8_$DO_IO                }
%include 'win/win8_dinit.pas';              { WIN8_$DINIT                }
%include 'win/win8_int.pas';                { WIN8_$INT                  }
%include 'win/win8_error_que.pas';          { WIN8_$ERROR_QUE            }
%include 'win/win8_get_stats.pas';          { WIN8_$GET_STATS            }

{ ---- OS_INIT_PROC ---- }
%if win_mailbox_ctlr %then
%include 'win/win7_cinit.pas';              { WIN7_$CINIT                }
%endif
%include 'win/cinit.pas';                   { WIN_$CINIT                 }
%elseif win_ring_disk_ctlr %then
{ The ring/disk controller's block (`win_ring_disk_ctlr'; the SAU4's
  WIN_ data segment, 0x80 bytes), zero but for the jump table and the
  longword 1 at +0x74: each drive's current cylinder, the unit record,
  the jump table DISK_$REGISTER is given, the unit's eventcount,
  WIN_$CNT, the current status, volume and request, the pointers to the
  two I/O map entries, the block count DISK_INIT is given when it is
  called from the driver, the drive last selected, the seek flag, and
  WIN_$STS.  The three open longwords at +0x14, +0x34 and +0x44 are the
  other forms' (the TODO above). }
var
  win_cyls: array[0..3] of pinteger;             { +0x00, zero }
  win_units: array[0..0] of win_$unit_t;         { +0x08, zero }
  unused_14: integer32;                          { +0x14, zero: above }
  win_jump_table: array[0..6] of univ_ptr :=     { +0x18 }
    [addr(win_$spin_down), nil, addr(win_$dinit), nil, addr(win_$do_io),
     addr(win_$error_que), addr(win_$get_stats)];
  unused_34: integer32;                          { +0x34, zero }
  win_unit_ec: array[0..0] of ec_$eventcount_t;  { +0x38, zero }
  unused_44: integer32;                          { +0x44, zero }

define
  win_$cnt;                                      { +0x48, zero }

var
  win_status: integer32;                         { +0x60, zero }
  win_dev_info: win_$vol_ptr_t;                  { +0x64, zero }
  win_cur_req: disk_$io_req_ptr_t;               { +0x68, zero }
  win_hdr_iomap: ^pinteger;                      { +0x6C, zero }
  win_data_iomap: ^pinteger;                     { +0x70, zero }
  win_total_blocks: integer32 := 1;              { +0x74: 1 }
  win_cur_drive: pinteger;                       { +0x78, zero }
  win_flag: boolean;                             { +0x7A, zero }

define
  win_$sts;                                      { +0x7C, zero }
  win_$do_io;
  disk_init;
  win_$spin_down;
  win_$int;
  win_$dinit;
  win_$error_que;
  win_$get_stats;
  win_$cinit;

{ ---- WIRED_PROC ---- }
%include 'win/seek.pas';                    { seek                       }
%include 'win/read_or_write_disk_record.pas';
                                            { read_or_write_disk_record  }
%include 'win/format_track.pas';            { win_$format_track          }
%include 'win/do_io.pas';                   { WIN_$DO_IO                 }
%include 'win/disk_init.pas';               { DISK_INIT                  }
%include 'win/spin_down.pas';               { WIN_$SPIN_DOWN             }
%include 'win/int.pas';                     { WIN_$INT                   }
%include 'win/dinit.pas';                   { WIN_$DINIT                 }
%include 'win/error_que.pas';               { WIN_$ERROR_QUE             }
%include 'win/get_stats.pas';               { WIN_$GET_STATS             }

{ ---- OS_INIT_PROC ---- }
%include 'win/cinit.pas';                   { WIN_$CINIT                 }
%else
{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
var
  win_units: array[0..0] of win_$unit_t;         { +0x00, zero }
  unused_0c: integer32;                          { +0x0C, zero: above }
  win_jump_table: array[0..6] of univ_ptr :=     { +0x10 }
    [addr(win_$spin_down), nil, addr(win_$dinit), nil, addr(win_$do_io),
     addr(win_$error_que), addr(win_$get_stats)];
  unused_2c: integer32;                          { +0x2C, zero }
  win_unit_ec: array[0..0] of ec_$eventcount_t;  { +0x30, zero }
  unused_3c: integer32;                          { +0x3C, zero }

define
  win_$cnt;                                      { +0x40, zero }

var
  win_status: integer32;                         { +0x58, zero }
  win_dev_info: win_$vol_ptr_t;                  { +0x5C, zero }
  win_cur_req: disk_$io_req_ptr_t;               { +0x60, zero }

define
  win_$kthunkd;                                  { +0x64, zero }

var
  win_total_blocks: integer32 := 1;              { +0x68: 1 }

define
  win_$attn;                                     { +0x6C, zero }
  win_$cstat;                                    { +0x6E, zero }
  win_$sense;                                    { +0x70, zero }

var
  win_cur_head: integer := -1;                   { +0x72: -1 }
  win_cur_cyl: integer := -1;                    { +0x74: -1 }
  win_flag: boolean;                             { +0x76, zero }

define
  seek;
  win_$do_io;
  disk_init;
  win_$spin_down;
  win_$int;
  win_$dinit;
  win_$error_que;
  win_$get_stats;
  win_$cinit;

{ ---- WIRED_PROC ---- }
%include 'win/wait_for_controller.pas';     { wait_for_controller        }
%include 'win/ansi_command.pas';            { win_$ansi_command          }
%include 'win/sense_general_status.pas';    { win_$sense_general_status  }
%include 'win/check_disk_status.pas';       { win_$check_disk_status     }
%include 'win/read_or_write_disk_record.pas';
                                            { read_or_write_disk_record  }
%include 'win/reinit_drive.pas';            { win_$reinit_drive          }
%include 'win/seek.pas';                    { SEEK                       }
%include 'win/format_track.pas';            { win_$format_track          }
%include 'win/do_io.pas';                   { WIN_$DO_IO                 }
%include 'win/disk_init.pas';               { DISK_INIT                  }
%include 'win/spin_down.pas';               { WIN_$SPIN_DOWN             }
%include 'win/int.pas';                     { WIN_$INT                   }
%include 'win/dinit.pas';                   { WIN_$DINIT                 }
%include 'win/error_que.pas';               { WIN_$ERROR_QUE             }
%include 'win/get_stats.pas';               { WIN_$GET_STATS             }

{ ---- OS_INIT_PROC ---- }
%include 'win/cinit.pas';                   { WIN_$CINIT                 }
%endif
%endif
