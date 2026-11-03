{ proc1/proc1.pas - the PROC1_ module, the level-1 process manager's
  compiled part.

  Image addresses:
    sau2  0x00E254E8  PROC1_ data (WIRED_DATA, 0xCC4 bytes)
    sau4  0x0F827984  PROC1_ data (WIRED_DATA, 0xCC4 bytes)

  One compilation unit, in two code sections and one data section: the
  map's PROC1_ code segments in WIRED_PROC (0xD88 bytes,
  PROC1_$TRY_TO_SUSPEND .. PROC1_$GET_ANY_CPU_USAGE, 26 map symbols,
  EC_$INIT and EC_$READ among them) and in OS_INIT_PROC (0xD0 bytes,
  PROC1_$INIT), and its PROC1_ data segment in WIRED_DATA (0xCC4 bytes),
  whose map symbols are PROC1_$STATS and PROC1_$TYPE.

  The hand-written PROC1_ASM data segment (the dispatcher, the ready
  list, the locks, the eventcount entries; proc1/m68k/*.s, ec/m68k/*.s,
  ml/m68k/*.s) is not part of this unit: its variables and entries are
  declared in proc1/proc1.ins.pas and ec/ec.ins.pas.

  Why one module: both code segments reach the one WIRED_DATA block,
  PROC1_$INIT by the block's address.  The heading is `module proc1_,
  wired_proc, wired_data;'; PROC1_$INIT is headed
  `[section(os_init_proc, os_init_data)]'.

  The data, 0xCC4 bytes, all zero in the image:

    +0x000  proc1_$loadav         3 * 4  the load averages
    +0x00C  (4 bytes, never addressed: unused_0c, a stand-in)
    +0x010  proc1_$loadav_elem    0x1A   the load-average timer element
    +0x02A  (6 bytes, never addressed: unused_2a, a stand-in)
    +0x030  proc1_$ts_elem      64 * 0x1C  the timeslice elements, by
                                         pid from 1

    +0x730  OS_STACK_BASE         65 * 4  defined; by pid from 0
    +0x834  (4 bytes, never addressed: unused_834, a stand-in)
    +0x838  PROC1_$STATS          64 * 0x10  defined

    +0xC38  proc1_$stack_free_list   4   the free 4 KB stacks
    +0xC3C  proc1_$stack_high_water  4
    +0xC40  proc1_$stack_low_water   4
    +0xC44  PROC1_$TYPE           64 * 2  defined

  The routines live in one fragment file each (proc1/<name>.pas;
  ec/init.pas and ec/read.pas for EC_$INIT and EC_$READ, which lie in
  this segment: ec/README.md), included below in image order.
  The module-local proc1_$clamp_priority, before PROC1_$SET_PRIORITY, is
  in clamp_priority.pas.

  Build: dpc -I domain_os domain_os/proc1/proc1.pas.  Check:
  tools/pascal_check.sh.
}
module proc1_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'ml/ml.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'proc1/proc1.ins.pas';

type
  { A timeslice element as PROC1_ reads it: time/time.ins.pas
    time_$queue_elem_t's layout, its datum (callback_arg) seen as two
    words, the pid in the low one. }
  proc1_$ts_view_t = record
    next: univ_ptr;                       { 0x00 }
    callback: univ_ptr;                   { 0x04 }
    datum_hi: pinteger;                   { 0x08 }
    pid: pinteger;                        { 0x0A }
    expire: time_$clock_t;                { 0x0C }
    flags: set of 0..15;                  { 0x12 }
    interval: time_$clock_t;              { 0x14 }
  end;
  proc1_$ts_view_ptr_t = ^proc1_$ts_view_t;

  { One element of proc1_$ts_elem: the queue element and 2 bytes, 0x1C
    (the stride 28, above). }
  proc1_$ts_slot_t = record
    elem: time_$queue_elem_t;             { 0x00 }
    pad_1a: pinteger;                     { 0x1A }
  end;

  { PROC1_$CREATE_P's longword argument as the body reads it, two words:
    the stack's size, passed to PROC1_$ALLOC_STACK, and the type.  See
    the TODO(pascal) in proc1/create_p.pas. }
  proc1_$create_args_t = record
    stack_size: pinteger;                 { 0x00 }
    proc_type: integer;                   { 0x02 }
  end;

  { A free stack's link word, the longword below the stack's top
    (PROC1_$FREE_STACK). }
  proc1_$stack_link_ptr_t = ^linteger;

var
  { PROC1_$SUSPEND_EC (map symbol in the hand-written PROC1_ASM): the
    eventcount advanced for every suspension.  Declared here, not in
    proc1/proc1.ins.pas, so that the insert needs no ec/ec.ins.pas. }
  proc1_$suspend_ec: extern ec_$eventcount_t;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  proc1_$loadav: proc1_$loadav_t;                  { +0x000, zero }
  unused_0c: integer32;                            { +0x00C, zero }
  proc1_$loadav_elem: time_$queue_elem_t;          { +0x010, zero }
  unused_2a: array[1..3] of integer;               { +0x02A, zero }
  proc1_$ts_elem: array[1..64] of proc1_$ts_slot_t;
                                                   { +0x030, zero }

define
  os_stack_base;                                   { +0x730, zero }

var
  unused_834: integer32;                           { +0x834, zero }

define
  proc1_$stats;                                    { +0x838, zero }

var
  proc1_$stack_free_list: linteger;                { +0xC38, zero }
  proc1_$stack_high_water: linteger;               { +0xC3C, zero }
  proc1_$stack_low_water: linteger;                { +0xC40, zero }

define
  proc1_$type;                                     { +0xC44, zero }

{ TODO(pascal) PROC1_'s three unaddressed gaps in the block

  +0x00C (4 bytes), +0x02A (6 bytes) and +0x834 (4 bytes) are never
  addressed; stand-ins hold their places.  An 8-byte alignment of
  objects of 8 bytes or more (a lead) explains all three (the next
  objects lie at multiples of 8), but not PROC1_$TYPE at +0xC44 (128
  bytes at 4 mod 8), which follows the low-water longword directly
  (MAC_OS's defined tables are not 8-aligned either, mac_os/mac_os.pas). }

{ TODO(pascal) PROC1_'s frames against their locals

  The SAU2 image's frames of PROC1_$SET_VT, _$SET_TS, _$TS_END_CALLBACK,
  _$LOADAV_CALLBACK, _$UNBIND, _$GET_INFO, _$ALLOC_STACK and _$GET_LIST
  are larger than their locals explain; the others are explained
  exactly.  No stand-ins are declared. }

define
  proc1_$try_to_suspend;
  proc1_$resume;
  proc1_$suspend;
  proc1_$suspendp;
  proc1_$tst_lock;
  proc1_$get_locks;
  proc1_$set_asid;
  proc1_$vt_int;
  proc1_$set_vt;
  proc1_$set_ts;
  proc1_$ts_end_callback;
  proc1_$get_loadav;
  proc1_$loadav_callback;
  proc1_$init_loadav;
  proc1_$bind;
  proc1_$unbind;
  proc1_$get_info;
  proc1_$alloc_stack;
  proc1_$free_stack;
  proc1_$create_p;
  ec_$init;
  ec_$read;
  proc1_$set_priority;
  proc1_$set_type;
  proc1_$get_type;
  proc1_$get_list;
  proc1_$get_any_cput;
  proc1_$get_any_cpu_usage;
  proc1_$init;

{ ---- WIRED_PROC ---- }
%include 'proc1/try_to_suspend.pas';        { PROC1_$TRY_TO_SUSPEND }
%include 'proc1/resume.pas';                { PROC1_$RESUME }
%include 'proc1/suspend.pas';               { PROC1_$SUSPEND }
%include 'proc1/suspendp.pas';              { PROC1_$SUSPENDP }
%include 'proc1/tst_lock.pas';              { PROC1_$TST_LOCK }
%include 'proc1/get_locks.pas';             { PROC1_$GET_LOCKS }
%include 'proc1/set_asid.pas';              { PROC1_$SET_ASID }
%include 'proc1/vt_int.pas';                { PROC1_$VT_INT }
%include 'proc1/set_vt.pas';                { PROC1_$SET_VT }
%include 'proc1/set_ts.pas';                { PROC1_$SET_TS }
%include 'proc1/ts_end_callback.pas';       { PROC1_$TS_END_CALLBACK }
%include 'proc1/init_ts_timer.pas';         { proc1_$init_ts_timer }
%include 'proc1/get_loadav.pas';            { PROC1_$GET_LOADAV }
%include 'proc1/loadav_callback.pas';       { PROC1_$LOADAV_CALLBACK }
%include 'proc1/init_loadav.pas';           { PROC1_$INIT_LOADAV }
%include 'proc1/bind.pas';                  { PROC1_$BIND }
%include 'proc1/unbind.pas';                { PROC1_$UNBIND }
%include 'proc1/get_info.pas';              { PROC1_$GET_INFO }
%include 'proc1/alloc_stack.pas';           { PROC1_$ALLOC_STACK }
%include 'proc1/free_stack.pas';            { PROC1_$FREE_STACK }
%include 'proc1/create_p.pas';              { PROC1_$CREATE_P }
%include 'ec/init.pas';                     { EC_$INIT }
%include 'ec/read.pas';                     { EC_$READ }
%include 'proc1/clamp_priority.pas';        { proc1_$clamp_priority }
%include 'proc1/set_priority.pas';          { PROC1_$SET_PRIORITY }
%include 'proc1/set_type.pas';              { PROC1_$SET_TYPE }
%include 'proc1/get_type.pas';              { PROC1_$GET_TYPE }
%include 'proc1/get_list.pas';              { PROC1_$GET_LIST }
%include 'proc1/get_any_cput.pas';          { PROC1_$GET_ANY_CPUT }
%include 'proc1/get_any_cpu_usage.pas';     { PROC1_$GET_ANY_CPU_USAGE }

{ ---- OS_INIT_PROC ---- }
%include 'proc1/init.pas';                  { PROC1_$INIT }
