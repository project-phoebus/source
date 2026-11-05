{ PROC1_$BIND - bind a new process to a free PCB.

  Image addresses:
    sau2  0x00E14D1C  PROC1_$BIND
    sau4  0x0F815590  PROC1_$BIND
    sau6  0x780154A8  PROC1_$BIND
    sau7  0x3C416A00  PROC1_$BIND

  - Under the PROC1 create lock, the PCBs from pid 3 up are searched for
    one not bound.
  - The PCB starts suspended, with no locks and states 1..16; its stack
    is prepared for the first dispatch and its timeslice timer armed.
  - When no PCB is free the result is not assigned.

  Status stored:
    status_$ok: the process was bound
    status_$no_pcb_is_available: every PCB up to 64 is bound
}

{ TODO(pascal) PROC1_$BIND's cpu record and statistics as block copies

  The SAU2 image fills the PCB's cpu record (+0x4C, 8 bytes) by a byte
  loop from a constant of the record's size after the routine's code, as
  FLP_$DINIT's label record (the TODO(pascal) in flp/dinit.pas), and
  clears proc1_$stats[pid] by one indexed store and three through a
  stepped pointer.  Neither is a known form (the reference has no record
  constants).  The Pascal assigns the fields (the same values, other
  instructions). }

function proc1_$bind(entry: univ_ptr; initial_sp: univ_ptr;
                     stack_base: linteger; ws_param: integer;
                     out status_p: status_$t): pinteger;
var
  pid: pinteger;
  pcb: proc1_$pcb_ptr_t;
begin
  { a free PCB from 3 }
  ml_$lock(ml_$proc1_create_lock);
  pid := 3;
  while proc1_flag_bound in pcbs[pid]^.flags do begin
    pid := pid + 1;
    if pid > 64 then begin
      status_p.all := status_$no_pcb_is_available;
      ml_$unlock(ml_$proc1_create_lock);
      return;
    end;
  end;

  proc1_$bind := pid;
  status_p.all := status_$ok;
  os_stack_base[pid] := stack_base;
  pmap_$init_ws_scan(pid, ws_param);

  pcb := pcbs[pid];
  pcb^.resource_locks_word := 0;
  pcb^.inh_count := 1;
  pcb^.sw_bsr := 16;
  pcb^.cpu.total.high := 0;
  pcb^.cpu.total.low := 0;
  pcb^.cpu.state := 16;
  pcb^.asid := 0;
  proc1_$stats[pid].stat[1] := 0;
  proc1_$stats[pid].stat[2] := 0;
  proc1_$stats[pid].stat[3] := 0;
  proc1_$stats[pid].stat[4] := 0;
  pcb^.flags := [proc1_flag_suspended, proc1_flag_bound];
  pcb^.field_60 := 0;
  pcb^.field_64 := 0;

  ml_$unlock(ml_$proc1_create_lock);
  init_stack(pcb^, entry, initial_sp);
  proc1_$init_ts_timer(pid);
end;
