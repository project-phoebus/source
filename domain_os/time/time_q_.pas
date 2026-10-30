{ time/time_q_.pas - the TIME_Q_ module, the time queues.

  One compilation unit, one code segment, no data: the map's TIME_Q_
  code segment in WIRED_PROC (0x4F8 bytes, TIME_$Q_INIT ..
  TIME_$Q_SCAN_QUEUE, after three module-local routines).  The queues
  are the callers', passed by address.

  The heading names no section; every routine is headed
  `[section(wired_proc, wired_data)]'.

  The routines live in one fragment file each (time/q_*.pas), included
  below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/time/time_q_.pas.  Check: tools/pascal_check.sh.
}
module time_q_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'dxm/dxm.ins.pas';

define
  time_$q_init;
  time_$q_init_queue;
  time_$q_flush_queue;
  time_$q_reenter_elem;
  time_$q_enter_elem;
  time_$q_add_callback;
  time_$q_remove_elem;
  time_$q_scan_queue;

{ ---- WIRED_PROC ---- }
%include 'time/q_insert_sorted.pas';    { time_$q_insert_sorted }
%include 'time/q_remove_internal.pas';  { time_$q_remove_internal }
%include 'time/q_setup_timer.pas';      { time_$q_setup_timer }
%include 'time/q_init.pas';             { TIME_$Q_INIT }
%include 'time/q_init_queue.pas';       { TIME_$Q_INIT_QUEUE }
%include 'time/q_flush_queue.pas';      { TIME_$Q_FLUSH_QUEUE }
%include 'time/q_reenter_elem.pas';     { TIME_$Q_REENTER_ELEM }
%include 'time/q_enter_elem.pas';       { TIME_$Q_ENTER_ELEM }
%include 'time/q_add_callback.pas';     { TIME_$Q_ADD_CALLBACK }
%include 'time/q_remove_elem.pas';      { TIME_$Q_REMOVE_ELEM }
%include 'time/q_scan_queue.pas';       { TIME_$Q_SCAN_QUEUE }
