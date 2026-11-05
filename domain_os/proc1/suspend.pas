{ PROC1_$SUSPEND - suspend a process.

  Image addresses:
    sau2  0x00E147FA  PROC1_$SUSPEND
    sau4  0x0F81506E  PROC1_$SUSPEND
    sau6  0x78014FBA  PROC1_$SUSPEND
    sau7  0x3C416512  PROC1_$SUSPEND

  - With interrupts off PROC1_$TRY_TO_SUSPEND suspends the process or
    marks it, and the dispatcher runs (and sets the priority).
  - The result is whether the process is suspended now; true on the two
    error paths.

  Status stored:
    status_$ok: the process was suspended or marked
    status_$illegal_process_id: process_id is not 1..64
    status_$process_not_bound: its PCB is not bound
    status_$process_already_suspended: it is suspended or marked already
}

function proc1_$suspend(process_id: pinteger; out status_ret: status_$t): boolean;
var
  pcb: proc1_$pcb_ptr_t;
  f: proc1_$flags_t;
begin
  proc1_$suspend := true;
  if (process_id = 0) or else (process_id > 64) then begin
    status_ret.all := status_$illegal_process_id;
    return;
  end;

  pcb := pcbs[process_id];
  f := pcb^.flags;
  if not (proc1_flag_bound in f) then begin
    status_ret.all := status_$process_not_bound;
    return;
  end;

  if f * [proc1_flag_suspended, proc1_flag_defer_susp] <> [] then begin
    proc1_$suspend := proc1_flag_suspended in f;
    status_ret.all := status_$process_already_suspended;
    return;
  end;

  disable;
  proc1_$try_to_suspend(pcb^);
  proc1_$dispatch;
  proc1_$suspend := proc1_flag_suspended in pcb^.flags;
  status_ret.all := status_$ok;
end;
