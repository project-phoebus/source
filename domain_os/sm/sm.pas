{ sm/sm.pas - the SM module, the storage module disk driver.

  Image addresses:
    sau3  0x00E83CD4  SM data (.DATA, 0x5C bytes)
    sau5  0x00E89A5C  SM data (.DATA, 0x5C bytes)

  One compilation unit, one code segment and one data segment: on the
  SAU5 the map's SM code segment in .TEXT (0xB1C bytes: eight
  module-local routines and SM_$INT .. SM_$SPIN_DOWN) and its SM data
  segment in .DATA (0x5C bytes; the map's SM_$DATA_START at its first
  byte).  Both are the default sections, so the heading names none.

  Present on the SAUs whose kernel has the storage module drivers, the
  part smd_disk (base/config.ins.pas): the SR10.2 maps of the SAU3..SAU6
  have the SM segments, the others' none.  Elsewhere the module is
  empty: its whole body is conditional.  The SAU3's code is the SAU5's
  but for the I/O map entries: longwords with the long_iomap part, the
  first word of each entry's 4 bytes without it (pbu/pbu.ins.pas).  The
  SAU4's and SAU6's are their own (the TODO(sau) in cinit.pas).

  Not part of the module: SM_$CB, SM_$CNT and SM_BLK_HDR, the PBU page's
  hand-written data (sm/sm.ins.pas); the map's SM_END_ADDR segment
  (sm/m68k/end_addr.s, on every SAU).

  The block, 0x5C bytes:

    +0x00  sm_jump_table   7 longwords: SM_$SPIN_DOWN, 0, SM_$DINIT,
                           SM_$REVALIDATE, SM_$DO_IO, 0, SM_$GET_STATS
                           (DISK_$REGISTER's table, disk/disk.ins.pas)
    +0x1C  unused_1c       4 bytes nothing addresses (a stand-in)
    +0x20  sm_wired_pages  ten longwords, MST_$WIRE_AREA's page list

    +0x48  sm_dcte         the controller's DCTE (SM_$CINIT)
    +0x4C  sm_pbu_info     PBU_$GET_PTR's pointer
    +0x50  sm_buf_ppn      the current request's page number
    +0x54  sm_cb_ppn       the command block's page number
    +0x58  sm_unit_count   16#1400, DISK_$REGISTER's units
    +0x5A  sm_wired_count  the wired pages' count

  The routines live in one fragment file each (sm/<name>.pas), in image
  order; the module-local routines called before their bodies have
  `forward' headings below.

  Check: tools/pascal_check.sh.
}
module sm;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'parity/parity.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'mst/mst.ins.pas';
%include 'io/io.ins.pas';
%include 'disk/disk.ins.pas';
%include 'win/win.ins.pas';
%include 'sm/sm.ins.pas';
%include 'pbu/pbu.ins.pas';

%if smd_disk %then

{ TODO(pascal) the block's open longword

  +0x1C is addressed by no routine: what an 8-byte alignment of the
  jump table (28 bytes) would leave before the page list, as WIN_'s
  block shows (win/win.pas).  A stand-in keeps the offsets. }

var
  sm_jump_table: array[0..6] of univ_ptr :=     { +0x00 }
    [addr(sm_$spin_down), nil, addr(sm_$dinit), addr(sm_$revalidate),
     addr(sm_$do_io), nil, addr(sm_$get_stats)];
  unused_1c: integer32;                         { +0x1C: stand-in }
  sm_wired_pages: array[0..9] of integer32;     { +0x20 }
  sm_dcte: dcte_ptr_t;                          { +0x48 }
  sm_pbu_info: sm_$pbu_info_ptr_t;              { +0x4C }
  sm_buf_ppn: integer32;                        { +0x50 }
  sm_cb_ppn: integer32;                         { +0x54 }
  sm_unit_count: pinteger := 16#1400;           { +0x58 }
  sm_wired_count: integer;                      { +0x5A }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  sm_$int;
  sm_$cinit;
  sm_$dinit;
  sm_$get_stats;
  sm_$do_io;
  sm_$revalidate;
  sm_$spin_down;

{ The module-local routines called before their bodies. }
{ body: sm/check_status.pas }
function sm_$check_status(unit: integer): integer32; forward; internal;
{ body: sm/command.pas }
function sm_$command(unit: integer; cmd: integer): integer32;
  forward; internal;
{ body: sm/seek.pas }
function sm_$seek(unit: integer; dcte: dcte_ptr_t; cyl: integer;
                  head: integer): integer32; forward; internal;

{ ---- .TEXT ---- }
%include 'sm/page_offset.pas';            { sm_$page_offset   }
%include 'sm/wait_ready.pas';             { sm_$wait_ready    }
%include 'sm/reset.pas';                  { sm_$reset         }
%include 'sm/wire.pas';                   { sm_$wire          }
%include 'sm/check_status.pas';           { sm_$check_status  }
%include 'sm/command.pas';                { sm_$command       }
%include 'sm/int.pas';                    { SM_$INT           }
%include 'sm/cinit.pas';                  { SM_$CINIT         }
%include 'sm/dinit.pas';                  { SM_$DINIT         }
%include 'sm/format.pas';                 { sm_$format        }
%include 'sm/get_stats.pas';              { SM_$GET_STATS     }
%include 'sm/do_io.pas';                  { SM_$DO_IO         }
%include 'sm/revalidate.pas';             { SM_$REVALIDATE    }
%include 'sm/seek.pas';                   { sm_$seek          }
%include 'sm/spin_down.pas';              { SM_$SPIN_DOWN     }

%endif
