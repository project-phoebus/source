{ pmap/pmap.pas - the PMAP_ module, the page purifier and working-set
  scanner.

  Image addresses:
    sau2  0x00E24D44  PMAP_ data (WIRED_DATA, 0x7A4 bytes)
    sau9  0x3C428544  PMAP_ data (WIRED_DATA, 0x7A4 bytes)

  One compilation unit: the map's PMAP_ code segments in WIRED_PROC
  (0x19E4 bytes, 0x1948 on the SAU9: PMAP_$FLUSH .. PMAP_$PURGE_WS and
  the module-local routines before them) and OS_INIT_PROC (0xD8 bytes,
  no symbol: pmap_$init_timers), and its PMAP_ data segment in
  WIRED_DATA.

  Why one unit: both code segments reach the one WIRED_DATA block, the
  WIRED_PROC routines through A5, pmap_$init_timers (headed
  `[section(os_init_proc, os_init_data)]') by the block's address.  The
  heading names the block's sections, `module pmap_, wired_proc,
  wired_data;'.

  The load section OS_PMAPS holds MMAP, the page-entry
  table (mmap/mmap.ins.pas), not PMAP_ data.  The segment map PMAP_
  reads and writes is AST_PMAPS (ast/ast.ins.pas ast_pmaps, in
  VM_TABLES).

  The data block, 0x7A4 bytes, zero but the values given, in its order:

    +0x000  pmap_$update_timer     0x1A  the update timer's queue element
    +0x01A  (6 bytes, unused_1a: a stand-in, see the TODO below)
    +0x020  pmap_$purifier_timer   0x1A  the purifier timer's element
    +0x03A  (6 bytes, unused_3a: a stand-in)
    +0x040  pmap_$ws_timer   64 * 0x1C   the working-set scan timers,
                                         indexed by process from 1

    +0x740  PMAP_$IDLE_INTERVAL      4   defined, 1596
    +0x744  PMAP_$T_PUR_SCANS        4   defined
    +0x748  PMAP_$PUR_R_CNT          4   defined
    +0x74C  PMAP_$PUR_L_CNT          4   defined

    +0x750  PMAP_$PAGES_EC         0xC   defined, self-linked
    +0x75C  PMAP_$R_PURIFIER_EC    0xC   defined, self-linked
    +0x768  PMAP_$L_PURIFIER_EC    0xC   defined, self-linked
    +0x774  MOUNT_LOCK            0x12   defined (no `$': a global),
                                         self-linked, f5 = -1
    +0x786  (2 bytes, unused_786: a stand-in)

    +0x788  PMAP_$SCAN_FRACT         2   defined, 1
    +0x78A  PMAP_$MID_THRESH         2   defined
    +0x78C  PMAP_$LOW_THRESH         2   defined
    +0x78E  PMAP_$WS_SCAN_DELTA      2   defined, 2
    +0x790  PMAP_$MIN_WS_INTERVAL    2   defined, 1
    +0x792  PMAP_$MAX_WS_INTERVAL    2   defined, 8

    +0x794  PMAP_$WS_INTERVAL        2   defined, 5
    +0x796  PMAP_$SHUTTING_DOWN_FLAG 1   defined
    +0x797  (1 byte: the next object's word alignment)
    +0x798  pmap_$short_wait_delay   6   5: PMAP_$PURIFIER_L's pause
    +0x79E  pmap_$ws_random_seed     2   16#4D: its generator's state
    +0x7A0  pmap_$current_slot       2   5: the purifier timer's next list

    +0x7A2  (2 bytes: the block's rounding to 4)

  The routines live in one fragment file each, included below in image
  order; PMAP_$FLUSH's two nested routines are in flush.pas.

  Build: dpc -I domain_os domain_os/pmap/pmap.pas.  Check:
  tools/pascal_check.sh.
}
module pmap_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'disk/disk.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'bat/bat.ins.pas';
%include 'area/area.ins.pas';
%include 'anon/anon.ins.pas';
%include 'log/log.ins.pas';
%include 'cal/cal.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'pmap/pmap_flush.ins.pas';

type
  { One element of pmap_$ws_timer: the queue element and 2 bytes, 0x1C
    (PMAP_$INIT_WS_SCAN's stride 28). }
  pmap_$ws_slot_t = record
    elem: time_$queue_elem_t;             { 0x00 }
    pad_1a: pinteger;                     { 0x1A }
  end;

  { The page numbers PMAP_$FLUSH collects for one batch write, 16
    longwords indexed from 1.  The bound is the batch's size, which
    PMAP_$FLUSH compares its count with. }
  pmap_$batch_t = array[1..16] of integer32;

  { (PMAP_$FLUSH's flags type pmap_$flush_flags_t is
    pmap/pmap_flush.ins.pas's.) }

{ (PMAP_$FLUSH's heading is pmap/pmap_flush.ins.pas's: pmap.ins.pas's
  includers disk/disk_vol.pas and proc1/proc1.pas do not include
  ast/ast.ins.pas, which it needs.) }

var
  { AST_$PMAP_IN_TRANS_EC (map symbol, in AST_'s data): the eventcount
    a page write in transit advances (pmap_$write_complete) and its
    waiters wait on (pmap_$wait_in_transit).  Declared here rather than
    in ast/ast.ins.pas, whose includers (osinfo/osinfo.pas,
    ../tmp/misc_ast_check) do not include ec/ec.ins.pas. }
  ast_$pmap_in_trans_ec: extern ec_$eventcount_t;

  { The PMAP_ block's eventcounts (map symbols, above): declared here, not
    in pmap/pmap.ins.pas, so that the insert needs no ec/ec.ins.pas
    (osinfo/osinfo.pas includes it without). }
  pmap_$pages_ec: extern ec_$eventcount_t;
  pmap_$r_purifier_ec: extern ec_$eventcount_t;
  pmap_$l_purifier_ec: extern ec_$eventcount_t;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
var
  pmap_$update_timer: time_$queue_elem_t;          { +0x000 }
  unused_1a: array[1..3] of integer;               { +0x01A: TODO }
  pmap_$purifier_timer: time_$queue_elem_t;        { +0x020 }
  unused_3a: array[1..3] of integer;               { +0x03A: TODO }
  pmap_$ws_timer: array[1..64] of pmap_$ws_slot_t; { +0x040 }

define
  pmap_$idle_interval := 1596;                     { +0x740 }
  pmap_$t_pur_scans;                               { +0x744 }
  pmap_$pur_r_cnt;                                 { +0x748 }
  pmap_$pur_l_cnt;                                 { +0x74C }
  pmap_$pages_ec := [value := 0,
                     waiter_list_head := addr(pmap_$pages_ec),
                     waiter_list_tail := addr(pmap_$pages_ec)];
                                                   { +0x750 }
  pmap_$r_purifier_ec := [value := 0,
                          waiter_list_head := addr(pmap_$r_purifier_ec),
                          waiter_list_tail := addr(pmap_$r_purifier_ec)];
                                                   { +0x75C }
  pmap_$l_purifier_ec := [value := 0,
                          waiter_list_head := addr(pmap_$l_purifier_ec),
                          waiter_list_tail := addr(pmap_$l_purifier_ec)];
                                                   { +0x768 }
  mount_lock := [f1 := 0, f2 := addr(mount_lock), f3 := addr(mount_lock),
                 f4 := 0, f5 := -1];               { +0x774 }

var
  unused_786: integer;                             { +0x786: TODO }

define
  pmap_$scan_fract := 1;                           { +0x788 }
  pmap_$mid_thresh;                                { +0x78A }
  pmap_$low_thresh;                                { +0x78C }
  pmap_$ws_scan_delta := 2;                        { +0x78E }
  pmap_$min_ws_interval := 1;                      { +0x790 }
  pmap_$max_ws_interval := 8;                      { +0x792 }
  pmap_$ws_interval := 5;                          { +0x794 }
  pmap_$shutting_down_flag;                        { +0x796 }

var
  pmap_$short_wait_delay: time_$clock_t := [high := 0, low := 5];
                                                   { +0x798 }
  pmap_$ws_random_seed: pinteger := 16#4D;         { +0x79E }
  pmap_$current_slot: pinteger := 5;               { +0x7A0 }

{ TODO(pascal) PMAP_'s three unaddressed gaps in the block

  +0x01A (6 bytes), +0x03A (6 bytes) and +0x786 (2 bytes) are never
  addressed; stand-ins hold their places.  An 8-byte alignment of
  objects of 8 bytes or more from the block's start would place the
  purifier timer at +0x20 and the timer array at +0x40, as here, but not
  the eventcounts at +0x75C and +0x768 nor MOUNT_LOCK at +0x774 (4 mod
  8), and it says nothing of +0x786.  The same open point as
  proc1/proc1.pas's three gaps. }

{ TODO(pascal) PMAP_'s frames against their locals

  Counting a module-local's reserved slot, each register-held local's
  slot and one 4-byte slot per `with', the SAU2 frames of
  pmap_$wait_in_transit, pmap_$update_seg_map, pmap_$flush_write_batch,
  PMAP_$WAKE_PURIFIER and PMAP_$PURGE_WS are exact;
  PMAP_$T_PURIF_CALLBACK's is exact without a slot for its `with'; the
  others (pmap_$write_complete, PMAP_$WS_SCAN_CALLBACK,
  PMAP_$INIT_WS_SCAN, pmap_$init_timers, PMAP_$FLUSH, pmap_$write_page,
  pmap_$fill_write_qblks, PMAP_$PURIFIER_L, PMAP_$PURIFIER_R) hold bytes
  their locals do not explain.  No stand-ins are declared. }

define
  pmap_$flush;
  pmap_$wake_purifier;
  pmap_$purifier_l;
  pmap_$purifier_r;
  pmap_$update_callback;
  pmap_$t_purif_callback;
  pmap_$ws_scan_callback;
  pmap_$init_ws_scan;
  pmap_$purge_ws;

{ Module-local routines called before their bodies.  (pmap_$write_page
  and pmap_$fill_write_qblks come before their callers in the image and
  here: their headings are in pmap/write_page.pas and
  pmap/fill_write_qblks.pas.) }

{ pmap_$init_timers (pmap/init_timers.pas): no arguments;
  PMAP_$PURIFIER_L calls it from WIRED_PROC. }
procedure pmap_$init_timers; forward; internal;

{ ---- WIRED_PROC ---- }
%include 'pmap/wait_in_transit.pas';       { pmap_$wait_in_transit }
%include 'pmap/write_complete.pas';        { pmap_$write_complete }
%include 'pmap/write_page.pas';            { pmap_$write_page }
%include 'pmap/fill_write_qblks.pas';      { pmap_$fill_write_qblks }
%include 'pmap/flush.pas';                 { PMAP_$FLUSH, its nested
                                             pmap_$update_seg_map and
                                             pmap_$flush_write_batch }
%include 'pmap/wake_purifier.pas';         { PMAP_$WAKE_PURIFIER }
%include 'pmap/purifier_l.pas';            { PMAP_$PURIFIER_L }
%include 'pmap/purifier_r.pas';            { PMAP_$PURIFIER_R }
%include 'pmap/update_callback.pas';       { PMAP_$UPDATE_CALLBACK }
%include 'pmap/t_purif_callback.pas';      { PMAP_$T_PURIF_CALLBACK }
%include 'pmap/ws_scan_callback.pas';      { PMAP_$WS_SCAN_CALLBACK }
%include 'pmap/init_ws_scan.pas';          { PMAP_$INIT_WS_SCAN }
%include 'pmap/purge_ws.pas';              { PMAP_$PURGE_WS }

{ ---- OS_INIT_PROC ---- }
%include 'pmap/init_timers.pas';           { pmap_$init_timers }
