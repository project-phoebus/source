{ time/time_unwired.pas - the TIME_UNWIRED module, the interval timers
  and the CPU time limit.

  One compilation unit, one code segment, no data: the map's
  TIME_UNWIRED code segment in .TEXT (0x6C0 bytes,
  TIME_$SET_ITIMER_REAL_CALLBACK .. TIME_$SET_CPU_LIMIT).  The databases
  and queues are TIME_'s (time/time.pas), reached by their addresses.
  The heading names no section.

  The routines live in one fragment file each (time/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/time/time_unwired.pas.  Check: tools/pascal_check.sh.
}
module time_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';

define
  time_$set_itimer_real_callback;
  time_$set_itimer_virt_callback;
  time_$set_cpu_limit_callback;
  time_$release;
  time_$set_itimer;
  time_$get_itimer;
  time_$set_cpu_limit;

{ ---- .TEXT ---- }
%include 'time/set_itimer_real_callback.pas';
                                        { TIME_$SET_ITIMER_REAL_CALLBACK }
%include 'time/set_itimer_virt_callback.pas';
                                        { TIME_$SET_ITIMER_VIRT_CALLBACK }
%include 'time/set_cpu_limit_callback.pas';
                                        { TIME_$SET_CPU_LIMIT_CALLBACK }
%include 'time/release.pas';            { TIME_$RELEASE }
%include 'time/clock_to_itimer.pas';    { time_$clock_to_itimer }
%include 'time/itimer_to_clock.pas';    { time_$itimer_to_clock }
%include 'time/get_itimer_internal.pas';{ time_$get_itimer_internal }
%include 'time/set_itimer_internal.pas';{ time_$set_itimer_internal }
%include 'time/set_itimer.pas';         { TIME_$SET_ITIMER }
%include 'time/get_itimer.pas';         { TIME_$GET_ITIMER }
%include 'time/set_cpu_limit.pas';      { TIME_$SET_CPU_LIMIT }
