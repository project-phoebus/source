{ sm_c/sm_c.pas - the SM_C module, the second storage module controller's
  disk driver.

  Image addresses:
    sau3  0x00E2CBE4  SM_C data (WIRED_DATA, 0x98 bytes)
    sau5  0x00E2F3B4  SM_C data (WIRED_DATA, 0x98 bytes)

  One compilation unit, one code segment and one data segment: on the
  SAU5 the map's SM_C code segment in .TEXT (0xD5C bytes: eight
  module-local routines and the seven globals) and its SM_C data
  segment in WIRED_DATA (0x98 bytes, no map symbol inside).  The heading
  names no code section and wired_data as the data section, PCHIST's
  form (pchist/pchist.pas, ref 7.1.1).

  Present on the SAUs whose kernel has the storage module drivers, the
  part smd_disk (base/config.ins.pas): the SR10.2 maps of the SAU3..SAU6
  have the SM_C segments, the others' none.  Elsewhere the module is
  empty: its whole body is conditional.  The SAU3's code is the SAU5's
  but for the I/O map entries: longwords with the long_iomap part, the
  first word of each entry's 4 bytes without it (pbu/pbu.ins.pas).  The
  SAU4's and SAU6's are their own.

  Not part of the module: the map's SM_X_ASM segment (SM_FIX_ECC, hand
  assembly, sm_c/m68k/sm_x_asm.s) and SM_C_END_ADDR
  (sm_c/m68k/end_addr.s); SM_$CB and SM_BLK_HDR, the PBU page's data
  (sm/sm.ins.pas).

  The block, 0x98 bytes, as the routines address it:

    +0x00  sm_c_jump_table   7 longwords: SM_C_$SPIN_DOWN, 0,
                             SM_C_$DINIT, SM_C_$REVALIDATE, SM_C_$DO_IO,
                             0, SM_C_$GET_STATS
    +0x1C  unused_1c         4 bytes nothing addresses (a stand-in)
    +0x20  sm_c_wired_pages  15 longwords from 1, MST_$WIRE_AREA's list
                             and MST_$WIRE's handle

    +0x5C  sm_c_dcte         the controller's DCTE
    +0x60  sm_c_pbu_info     PBU_$GET_PTR's pointer
    +0x64  sm_c_req          the current request (a chain)
    +0x68  sm_c_cb_ppn       the command block's page number
    +0x6C  sm_c_vol          the current volume
    +0x70  sm_c_hdr          the controller's header buffer (SM_BLK_HDR)

    +0x74  sm_c_alloc        PBU_$ALLOC's result
    +0x78  sm_c_iomap_entry  the I/O map entry of the transfers' page
    +0x7C  unused_7c         4 bytes nothing addresses (a stand-in)
    +0x80  unused_80         the word 1, nothing addresses (a stand-in)
    +0x82  sm_c_unit_count   16#3C00, DISK_$REGISTER's units
    +0x84  sm_c_unit         the unit of the last command

    +0x86  sm_c_alloc_count  2
    +0x88  sm_c_iomap_index  the allocation's page index
    +0x8A  sm_c_hdr_mid      the header buffer's address bytes, words
    +0x8C  sm_c_hdr_lo         read back as their low bytes
    +0x8E  sm_c_hdr_hi

    +0x90  sm_c_wired_count  the wired pages' count
    +0x92  sm_c_started      the controller set up (SM_C_$DINIT)
    +0x94  sm_c_wired        the driver wired (sm_c_$wire)

  The routines live in one fragment file each (sm_c/<name>.pas), in
  image order; none is called before its body.

  Check: tools/pascal_check.sh.
}
module sm_c, , wired_data;

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
%include 'sm_c/sm_c.ins.pas';
%include 'pbu/pbu.ins.pas';

%if smd_disk %then

{ TODO(pascal) the block's open words

  +0x1C, +0x7C and the word 1 at +0x80 are addressed by no routine.
  +0x1C is what 8-byte alignment of the jump table would leave (as in
  WIN_'s and SM's blocks); the other two are not explained.  Stand-ins
  keep the offsets and the image's bytes. }

var
  sm_c_jump_table: array[0..6] of univ_ptr :=   { +0x00 }
    [addr(sm_c_$spin_down), nil, addr(sm_c_$dinit),
     addr(sm_c_$revalidate), addr(sm_c_$do_io), nil,
     addr(sm_c_$get_stats)];
  unused_1c: integer32;                         { +0x1C: stand-in }
  sm_c_wired_pages: array[1..15] of integer32;  { +0x20 }
  sm_c_dcte: dcte_ptr_t;                        { +0x5C }
  sm_c_pbu_info: sm_$pbu_info_ptr_t;            { +0x60 }
  sm_c_req: disk_$io_req_ptr_t;                 { +0x64 }
  sm_c_cb_ppn: integer32;                       { +0x68 }
  sm_c_vol: ^disk_$volume_t;                    { +0x6C }
  sm_c_hdr: sm_$hdr_ptr_t;                      { +0x70 }
  sm_c_alloc: integer32;                        { +0x74 }
%if long_iomap %then
  sm_c_iomap_entry: ^integer32;                 { +0x78 }
%else
  sm_c_iomap_entry: ^pbu_$iomap_entry_t;        { +0x78 }
%endif
  unused_7c: integer32;                         { +0x7C: stand-in }
  unused_80: integer := 1;                      { +0x80: stand-in }
  sm_c_unit_count: pinteger := 16#3C00;         { +0x82 }
  sm_c_unit: pinteger;                          { +0x84 }
  sm_c_alloc_count: integer;                    { +0x86 }
  sm_c_iomap_index: integer;                    { +0x88 }
  sm_c_hdr_mid: sm_c_$word_t;                   { +0x8A }
  sm_c_hdr_lo: sm_c_$word_t;                    { +0x8C }
  sm_c_hdr_hi: sm_c_$word_t;                    { +0x8E }
  sm_c_wired_count: integer;                    { +0x90 }
  sm_c_started: boolean;                        { +0x92 }
  sm_c_wired: boolean;                          { +0x94 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  sm_c_$int;
  sm_c_$cinit;
  sm_c_$dinit;
  sm_c_$get_stats;
  sm_c_$do_io;
  sm_c_$revalidate;
  sm_c_$spin_down;

{ ---- .TEXT ---- }
%include 'sm_c/wire.pas';                 { sm_c_$wire          }
%include 'sm_c/fix_ecc.pas';              { sm_c_$fix_ecc       }
%include 'sm_c/check_status.pas';         { sm_c_$check_status  }
%include 'sm_c/command.pas';              { sm_c_$command       }
%include 'sm_c/int.pas';                  { SM_C_$INT           }
%include 'sm_c/start_drive.pas';          { sm_c_$start_drive   }
%include 'sm_c/cinit.pas';                { SM_C_$CINIT         }
%include 'sm_c/delay.pas';                { sm_c_$delay         }
%include 'sm_c/dinit.pas';                { SM_C_$DINIT         }
%include 'sm_c/reinit.pas';               { sm_c_$reinit        }
%include 'sm_c/format.pas';               { sm_c_$format        }
%include 'sm_c/get_stats.pas';            { SM_C_$GET_STATS     }
%include 'sm_c/do_io.pas';                { SM_C_$DO_IO         }
%include 'sm_c/revalidate.pas';           { SM_C_$REVALIDATE    }
%include 'sm_c/spin_down.pas';            { SM_C_$SPIN_DOWN     }

%endif
