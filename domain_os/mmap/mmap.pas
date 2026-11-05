{ mmap/mmap.pas - the MMAP_ module, the physical memory map and the working
  set lists.

  Image addresses:
    sau2  0x00E23284  MMAP_ data (WIRED_DATA, 0xAA8 bytes)
    sau4  0x0F82560C  MMAP_ data (WIRED_DATA, 0xAA8 bytes)
    sau6  0x78025DF4  MMAP_ data (WIRED_DATA, 0xAA8 bytes)
    sau7  0x3C42854C  MMAP_ data (WIRED_DATA, 0xAA8 bytes)
    sau8  0x03C24BFC  MMAP_ data (WIRED_DATA, 0xAA8 bytes)
    sau9  0x3C42619C  MMAP_ data (WIRED_DATA, 0xAA8 bytes)

  One compilation unit: the map's MMAP_ code segment in WIRED_PROC
  (0x14D8 bytes on the SAU2, 0x16A0 on the SAU9: the module-local
  routines, then MMAP_$SET_WS_PRI .. MMAP_$RECLAIM) and its data segment
  in WIRED_DATA (0xAA8 bytes).
  MMAP_$INIT and MMAP_$REMOTE_POOL are mmap/mmap_unwired.pas's.

  The heading: `module mmap_, wired_proc, wired_data;'.

  The data, 0xAA8 bytes (zero but the values set below):

    +0x000  mmap_$lock      the MMAP spin lock
    +0x004  MMAP_$HI_INDX .. +0x028 MMAP_$ALLOC_CNT, eleven longwords
    +0x02C  MMAP_$WSL       70 * 0x24, indexed by the list number
    +0xA04  MMAP_$MIN_RMT_POOL .. +0xA1C MMAP_$REAL_PAGES, seven longwords

    +0xA20  MMAP_$FORMAT        a word
    +0xA22  MMAP_$WSL_HI_MARK   a word
    +0xA24  MMAP_$WS_OWNER      64 words from 1
    +0xAA4  MMAP_$RMT_LIMIT     a longword

  The routines live in one fragment file each (mmap/<name>.pas),
  included below in image order; the four module-local routines
  (mmap_$add_to_wsl .. mmap_$trim_wsl) come first in the segment.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/mmap/mmap.pas.  Check: tools/pascal_check.sh.
}
module mmap_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mmap/mmap.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
var
  mmap_$lock: integer32;                         { +0x000, zero }

define
  mmap_$hi_indx := mmap_$last_ppn;               { +0x004 }
  mmap_$lo_indx := mmap_$first_ppn;              { +0x008 }
  mmap_$ws_remove;                               { +0x00C, zero }
  mmap_$reclaim_pur_cnt;                         { +0x010, zero }
  mmap_$reclaim_shar_cnt;                        { +0x014, zero }
  mmap_$ws_scan_cnt;                             { +0x018, zero }
  mmap_$ws_overflow;                             { +0x01C, zero }
  mmap_$steal_cnt;                               { +0x020, zero }
  mmap_$alloc_pages;                             { +0x024, zero }
  mmap_$alloc_cnt;                               { +0x028, zero }
  mmap_$wsl;                                     { +0x02C, zero }
  mmap_$min_rmt_pool := 66;                      { +0xA04 }
  mmap_$hppn := 1;                               { +0xA08 }
  mmap_$lppn := mmap_$lppn_seed;                 { +0xA0C }
  mmap_$pageable_pages_lower_limit := 66;        { +0xA10 }
  mmap_$pageable_pages;                          { +0xA14, zero }
  mmap_$remote_pages;                            { +0xA18, zero }
  mmap_$real_pages;                              { +0xA1C, zero }
  mmap_$format := 1;                             { +0xA20 }
  mmap_$wsl_hi_mark := 8;                        { +0xA22 }
  mmap_$ws_owner;                                { +0xA24, zero }
  mmap_$rmt_limit;                               { +0xAA4, zero }

define
  mmap_$set_ws_pri;
  mmap_$get_ws_siz;
  mmap_$get_ws_index;
  mmap_$set_ws_max;
  mmap_$free;
  mmap_$free_list;
  mmap_$free_remove;
  mmap_$impure_transfer;
  mmap_$unavail_remov;
  mmap_$avail;
  mmap_$wire;
  mmap_$unwire;
  mmap_$install_list;
  mmap_$install_pages;
  mmap_$free_pages;
  mmap_$release_pages;
  mmap_$purge;
  mmap_$free_wsl;
  mmap_$set_ws_index;
  mmap_$ws_scan;
  mmap_$get_impure;
  mmap_$alloc_pure;
  mmap_$alloc_free;
  mmap_$alloc_contig;
  mmap_$reclaim;

{ ---- WIRED_PROC ---- }
%include 'mmap/add_to_wsl.pas';          { mmap_$add_to_wsl }
%include 'mmap/add_pages_to_wsl.pas';    { mmap_$add_pages_to_wsl }
%include 'mmap/remove_from_wsl.pas';     { mmap_$remove_from_wsl }
%include 'mmap/trim_wsl.pas';            { mmap_$trim_wsl }
%include 'mmap/set_ws_pri.pas';          { MMAP_$SET_WS_PRI }
%include 'mmap/get_ws_siz.pas';          { MMAP_$GET_WS_SIZ }
%include 'mmap/get_ws_index.pas';        { MMAP_$GET_WS_INDEX }
%include 'mmap/set_ws_max.pas';          { MMAP_$SET_WS_MAX }
%include 'mmap/free.pas';                { MMAP_$FREE }
%include 'mmap/free_list.pas';           { MMAP_$FREE_LIST }
%include 'mmap/free_remove.pas';         { MMAP_$FREE_REMOVE }
%include 'mmap/impure_transfer.pas';     { MMAP_$IMPURE_TRANSFER }
%include 'mmap/unavail_remov.pas';       { MMAP_$UNAVAIL_REMOV }
%include 'mmap/avail.pas';               { MMAP_$AVAIL }
%include 'mmap/wire.pas';                { MMAP_$WIRE }
%include 'mmap/unwire.pas';              { MMAP_$UNWIRE }
%include 'mmap/install_list.pas';        { MMAP_$INSTALL_LIST }
%include 'mmap/install_pages.pas';       { MMAP_$INSTALL_PAGES }
%include 'mmap/free_pages.pas';          { MMAP_$FREE_PAGES }
%include 'mmap/release_pages.pas';       { MMAP_$RELEASE_PAGES }
%include 'mmap/purge.pas';               { MMAP_$PURGE }
%include 'mmap/free_wsl.pas';            { MMAP_$FREE_WSL }
%include 'mmap/set_ws_index.pas';        { MMAP_$SET_WS_INDEX }
%include 'mmap/ws_scan.pas';             { MMAP_$WS_SCAN, its nested
                                           mmap_$move_pages_to_wsl_type }
%include 'mmap/get_impure.pas';          { MMAP_$GET_IMPURE }
%include 'mmap/alloc_pages_from_wsl.pas';
                                         { mmap_$alloc_pages_from_wsl }
%include 'mmap/alloc_pure.pas';          { MMAP_$ALLOC_PURE }
%include 'mmap/alloc_free.pas';          { MMAP_$ALLOC_FREE }
%include 'mmap/alloc_contig.pas';        { MMAP_$ALLOC_CONTIG }
%include 'mmap/reclaim.pas';             { MMAP_$RECLAIM }
