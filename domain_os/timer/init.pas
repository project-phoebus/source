{ TIMER_$INIT - program the hardware timers.

  Image addresses:
    sau2  0x00E16340  TIMER_$INIT
    sau8  0x03C17260  TIMER_$INIT
    sau9  0x3C418374  TIMER_$INIT

  - Installs the timer interrupt vector; the virtual and auxiliary
    counters are loaded with 16#FFFF, the real-time counter with its
    period.  Returns 0.
  - A fragment of the TIME_ module, not of a TIMER module: the map has
    TIMER_$INIT first in a TIME_ code segment in WIRED_PROC, so
    time/time.pas includes it.
  - With `timer_dcte' (base/config.ins.pas) it is TIMER_DCTE's
    initialization routine: the TIMER block is set up from
    TIME_$SYS_FREQ first, the real-time period is 4167, and the timer's
    three interrupts are enabled.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in)

  The frame holds the result variable (never addressed) and 8 bytes: on
  the SAU9 the top 4 are id, the interrupt id passed by value to
  SYSBUS_$ENABLE_DEVICE (unaddressed on the SAU2); the other 4 are held
  by the stand-in unused_8 (as in tpad/inquire_unit.pas,
  tty/k_flush_input.pas).  A `with' statement's temporary would explain
  them; that is not established.  Their order against the result
  variable is not seen. }

function timer_$init: integer32;
const
%if timer_dcte %then
  timer_$c_rte_period = 4167;
  timer_$c_rte_vector = 16#A9;
  timer_$c_vt_vector = 16#AA;
  timer_$c_aux_vector = 16#AB;
%else
  timer_$c_rte_period = 4166;
%endif
  timer_$c_index_aux = 3;
  timer_$c_index_vt = 2;
  timer_$c_disabled = 16#FFFF;
  timer_$c_index_rte = 1;
var
  id: io_$int_id_t;                       { the `timer_dcte' form's }
  unused_8: integer32;                    { stand-in, see TODO }
begin
  time_$set_vector;

%if timer_dcte %then
  with timer do begin
    clock_mhz := (time_$sys_freq + 500000) div 1000000 - 1;
    ctrl := 16#34;
    ctrl := 16#70;
    ctrl := 16#B0;
    reg_18 := 0;
  end;

%endif
  time_$wrt_timer(timer_$c_index_rte, timer_$c_rte_period);
  time_$wrt_timer(timer_$c_index_vt, timer_$c_disabled);
  time_$wrt_timer(timer_$c_index_aux, timer_$c_disabled);

%if timer_dcte %then
  id.vector := timer_$c_rte_vector;
  sysbus_$enable_device(id);
  id.vector := timer_$c_vt_vector;
  sysbus_$enable_device(id);
  id.vector := timer_$c_aux_vector;
  sysbus_$enable_device(id);
%else
  with timr do begin
    ctrl := 16#E0;
    reg_01 := 16#E1;
    ctrl := 16#E1;
    reg_01 := 16#E0;
  end;
%endif

  timer_$init := 0;
end;
