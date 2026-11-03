{ PROC1_$SUSPENDP - whether a process is suspended.

  Image addresses:
    sau2  0x00E14876  PROC1_$SUSPENDP
    sau4  0x0F8150EA  PROC1_$SUSPENDP

  - The result is true on the two error paths.

  Status stored:
    status_$ok: the result is the suspended flag
    status_$illegal_process_id: pid is not 1..64
    status_$process_not_bound: its PCB is not bound
}

function proc1_$suspendp(pid: pinteger; out status_ret: status_$t): boolean;
var
  pcb: proc1_$pcb_ptr_t;
begin
  proc1_$suspendp := true;
  if (pid = 0) or else (pid > 64) then begin
    status_ret.all := status_$illegal_process_id;
    return;
  end;

  pcb := pcbs[pid];
  if not (proc1_flag_bound in pcb^.flags) then begin
    status_ret.all := status_$process_not_bound;
    return;
  end;

  proc1_$suspendp := proc1_flag_suspended in pcb^.flags;
  status_ret.all := status_$ok;
end;
