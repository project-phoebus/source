{ time/time.pas - the TIME_ module, the clocks, the real-time queue and
  the timed waits.

  Image addresses:
    sau2  0x00E29198  TIME_ data (WIRED_DATA, 0x1628 bytes)
    sau4  0x0F82B84C  TIME_ data (WIRED_DATA, 0x1628 bytes)

  One compilation unit: the map's TIME_ code segments in WIRED_PROC
  (0x7A8 bytes, TIMER_$INIT .. TIME_$GET_ADJUST) and OS_INIT_PROC (0xE4
  bytes, TIME_$INIT), and its data segment in WIRED_DATA (0x1628
  bytes).  TIMER_$INIT is translated in timer/ and included here.

  The heading: `module time_, wired_proc, wired_data;'; TIME_$INIT is
  headed `[section(os_init_proc, os_init_data)]'.

  The data, 0x1628 bytes, all zero in the image:

    +0x0000  TIME_$CPU_LIMIT_DB    58 * 0x1C  defined
    +0x0658  TIME_$ITIMER_DB   2 * 58 * 0x1C  defined
    +0x1308  TIME_$VTQ             64 * 0xC   defined; the virtual-timer
                                              queues
    +0x1608  TIME_$RTEQ            0xC        defined; the real-time queue
    +0x1614  zero_interval         6          a one-shot element's interval

    +0x161A  (2 bytes: the next pointer's alignment)
    +0x161C  fast_clock_ec_handle  4          TIME_$GET_EC's handles
    +0x1620  clock_ec_handle       4
    +0x1624  TIME_$SYS_FREQ        4          defined; not referenced

  The routines live in one fragment file each (time/<name>.pas;
  timer/init.pas for TIMER_$INIT), included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/time/time.pas.  Check: tools/pascal_check.sh.
}
module time_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'di/di.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'sysbus/sysbus.ins.pas';
%include 'timer/timer.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
define
  time_$cpu_limit_db;                              { +0x0000, zero }
  time_$itimer_db;                                 { +0x0658, zero }
  time_$vtq;                                       { +0x1308, zero }
  time_$rteq;                                      { +0x1608, zero }

var
  zero_interval: time_$clock_t;                    { +0x1614, zero }
  fast_clock_ec_handle: ec2_$ptr_t;                { +0x161C, nil }
  clock_ec_handle: ec2_$ptr_t;                     { +0x1620, nil }

define
  time_$sys_freq;                                  { +0x1624, zero }

var
  { TIME_ASM's deferred-interrupt elements (above): another unit's
    variables, of di/di.ins.pas's type.  The names are the map's. }
  time_$di_vt: extern di_$q_elem_t;
  time_$di_rte: extern di_$q_elem_t;

define
  timer_$init;
  time_$rte_int;
  time_$vt_int;
  time_$advance_callback;
  time_$advance;
  time_$cancel;
  time_$wait;
  time_$wait2;
  time_$get_ec;
  time_$set_time_of_day;
  time_$adjust_time_of_day;
  time_$get_adjust;
  time_$init;

{ ---- WIRED_PROC ---- }
%include 'timer/init.pas';              { TIMER_$INIT }
%include 'time/rte_int.pas';            { TIME_$RTE_INT }
%include 'time/vt_int.pas';             { TIME_$VT_INT }
%include 'time/advance_callback.pas';   { TIME_$ADVANCE_CALLBACK }
%include 'time/advance.pas';            { TIME_$ADVANCE }
%include 'time/cancel.pas';             { TIME_$CANCEL }
%include 'time/wait.pas';               { TIME_$WAIT }
%include 'time/wait2.pas';              { TIME_$WAIT2 }
%include 'time/get_ec.pas';             { TIME_$GET_EC }
%include 'time/set_time_of_day.pas';    { TIME_$SET_TIME_OF_DAY }
%include 'time/adjust_time_of_day.pas'; { TIME_$ADJUST_TIME_OF_DAY }
%include 'time/get_adjust.pas';         { TIME_$GET_ADJUST }

{ ---- OS_INIT_PROC ---- }
%include 'time/init.pas';               { TIME_$INIT }
