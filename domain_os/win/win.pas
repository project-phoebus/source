{ win/win.pas - the WIN_ module, the Winchester disk driver (on the SAU2
  the DN3xx's ANSI-command controller, on DMA channel 3).

  Image addresses:
    sau2  0x00E2B89C  WIN_ data (WIRED_DATA, 0x78 bytes)
    sau5  0x00E2C9D8  WIN_ data (WIRED_DATA, 0x78 bytes)
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

  The SAU8's WIN_ (`win_atbus_ctlr') is the WIN8_ driver of a
  controller on the AT bus: WIN_$SPIN_DOWN and WIN_$CINIT by their
  names, the five WIN8_ globals, five module-local routines of its own
  (wait_phase.pas, send_command.pas, check_status.pas,
  read_mfg_badspots.pas and its arm of format_track.pas), WIN_ASM's
  hand assembly (win/sau8/win_asm.s), and a block of its own (0x380
  bytes); WIN8_DCTE is its DCTE.

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
%include 'win/win.ins.pas';

{ TODO(sau) the WIN_ drivers of the SAUs not translated

  The SAU2's ANSI-command driver, the SAU5's descriptor-list driver and
  the SAU8's AT bus driver are written.  The SAU4's and SAU6's WIN_ code
  differs from all three (the catalog's families of WIN_$DO_IO, WIN_$INT
  and WIN_$DINIT; WIN_ code segments of 0xFB0 and 0x1C78 bytes); the
  SAU7's holds the WIN7_ driver beside the AT bus one (0x2DD4 bytes).
  Those SAUs build the SAU2's arm until each has its part. }

{ TODO(pascal) the block's three open longwords

  +0x0C, +0x2C and +0x3C are addressed by no routine and are what 8-byte
  alignment of the 8-byte-or-larger objects from the block's start would
  leave (the rule fits this block at all three places).
  The Pascal declares stand-ins (unused_0c, unused_2c, unused_3c) so
  that dpc, which aligns data to at most 4, lays the block out as the
  image does.  If the alignment rule is confirmed, the stand-ins go. }

%if win_descriptor_ctlr %then
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
%include 'win/error_que.pas';               { WIN_$ERROR_QUE             }
%include 'win/get_stats.pas';               { WIN_$GET_STATS             }

{ ---- OS_INIT_PROC ---- }
%include 'win/cinit.pas';                   { WIN_$CINIT                 }
%elseif win_atbus_ctlr %then
{ TODO(pascal) the AT bus block's 704 bytes at +0x30

  Between the drives' statistics and the controllers' records the block
  has 704 bytes no routine addresses (the SAU7's WIN_ block has the same
  704 bytes between the same two objects, after its WIN7_ driver's
  data).  704 is twice 352; what the object was is not known.  The
  Pascal declares a stand-in, unused_030. }

{ The AT bus controller's block (`win_atbus_ctlr'; the SAU8's WIN_ data
  segment, 0x380 bytes), zero but for the jump table, the longword 1 at
  +0x36C and the unit word at +0x370. }
var
  win_stats: array[0..1] of win_$stats_slot_t;   { +0x000, zero }
  unused_030: array[1..176] of integer32;        { +0x030, zero: the TODO
                                                   below }
  win_units: array[0..1] of win_$unit_t;         { +0x2F0, zero }
  win_jump_table: array[0..6] of univ_ptr :=     { +0x308 }
    [addr(win_$spin_down), nil, addr(win8_$dinit), nil, addr(win8_$do_io),
     addr(win8_$error_que), addr(win8_$get_stats)];
  unused_324: integer32;                         { +0x324, zero }
  win_unit_ec: array[0..1] of ec_$eventcount_t;  { +0x328, zero }

define
  win_$cnt;                                      { +0x340, zero }

var
  win_page_pmape: univ_ptr;                      { +0x358, zero }
  win_hdr: univ_ptr;                             { +0x35C, zero }
  win_buf: univ_ptr;                             { +0x360, zero }
  win_cmd: win_$cmd_t;                           { +0x364, zero }
  win_total_blocks: integer32 := 1;              { +0x36C: 1 }
  win_unit_bits: integer := 16#2800;             { +0x370: members 13
                                                   and 11 }
  win_last_phase: integer;                       { +0x372, zero }
  win_last_status: integer;                      { +0x374, zero }
  win_sector_size: integer;                      { +0x376, zero }
  win_max_count: integer;                        { +0x378, zero }
  win_count: integer;                            { +0x37A, zero }
  win_params_reported: boolean;                  { +0x37C, zero }

define
  win_$spin_down;
  win8_$do_io;
  win8_$dinit;
  win8_$int;
  win8_$error_que;
  win8_$get_stats;
  win_$cinit;

{ ---- WIRED_PROC ---- }
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
